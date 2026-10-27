import test from 'node:test';
import assert from 'node:assert/strict';
import { runActivationWorker,activationParameters } from '../api/_lib/tiktok/activation.js';
import { fingerprint,TikTokError } from '../api/_lib/tiktok/contract.js';
import { stageParameters } from '../api/_lib/tiktok/provider.js';

const now=Date.parse('2026-10-23T10:00:00Z');
const id='10000000-0000-4000-8000-000000000001',approval='20000000-0000-4000-8000-000000000002';
function job(){return {id,lease_token:approval,activation_approval:{id:approval},activation_stages:{},activation_can_mutate:true,
  account:{},ad:{goal:'messages',message_destination:'direct_message'},start_at:new Date(now-60000).toISOString(),end_at:new Date(now+86400000).toISOString(),
  evidence:{identity:{advertiser_id:'111',identity_type:'TT_USER',identity_id:'222'},account_id:id,flow:'UPGRADED_SMART_PLUS_DM',item_id:'555',targeting:{location_ids:['888']},declared_budget_usd:20,auto_message_id:'666'},provider_ids:{campaign:'701',adgroup:'702',ad:'703'}};}
function harness(j,{unknownStage,denyIntent,wrongParent=false,changedCreative=false}={}) {
  const events=[],state={campaign:'DISABLE',adgroup:'DISABLE',ad:'DISABLE'};
  const service=async(action,{payload}={})=>{
    events.push({action,payload});if(action==='claim')return structuredClone(j);
    if(action==='activation_intent'){
      if(denyIntent)throw new TikTokError('TIKTOK_ACTIVATION_DISABLED');
      j.activation_stages[payload.stage]={state:'inflight',request_hash:payload.request_hash};
    }
    if(action==='activation_complete')j.activation_stages[payload.stage]={state:'complete',request_hash:payload.request_hash};
    if(action==='activation_reconcile')j.activation_stages[payload.stage]={state:'retryable',request_hash:payload.request_hash};
    return {ok:true};
  };
  const api=async(path,params,method='GET')=>{
    events.push({path,params,method});
    if(path==='report/integrated/get/')return {list:[{dimensions:{adgroup_id:'702'},metrics:{spend:'0'}}]};
    const stage=path.split('/')[1];
    if(method==='POST'){
      assert.equal(j.activation_stages[stage].state,'inflight');assert.equal(params.operation_status,'ENABLE');
      state[stage]='ENABLE';if(unknownStage===stage)throw new TikTokError('TIKTOK_OUTCOME_UNKNOWN',{uncertain:true});return {};
    }
    const key=stage==='ad'?'smart_plus_ad_id':`${stage}_id`;
    return {list:[{...stageParameters(stage,j),[key]:j.provider_ids[stage],advertiser_id:'111',campaign_id:wrongParent&&stage!=='campaign'?'999':'701',
      ...(stage==='ad'?{adgroup_id:'702',...(changedCreative?{creative_list:[]}:{})}:{}),operation_status:state[stage],secondary_status:stage==='ad'?'AD_STATUS_DELIVERY_OK':undefined}]};
  };
  return {events,state,service,clientFactory:()=>api,env:{TIKTOK_DM_ACTIVATION_ENABLED:'true'},now:()=>now,preflightImpl:async()=>j.evidence};
}

test('activation remains off by default and requires both backend approval and independent mutation gate',async()=>{
  for(const variation of ['environment','database','approval']){
    const j=job(),h=harness(j);if(variation==='environment')h.env={};if(variation==='database')j.activation_can_mutate=false;if(variation==='approval')j.activation_approval=null;
    const result=await runActivationWorker(h);assert(['blocked','reconcile'].includes(result.status));
    assert(!h.events.some(e=>e.method==='POST'||e.action==='activation_intent'));
  }
});

test('approval-bound activation commits each intent, enables child before parent and verifies exact readback',async()=>{
  const j=job(),h=harness(j);const result=await runActivationWorker(h);assert.equal(result.status,'activated');
  assert.deepEqual(h.events.filter(e=>e.method==='POST').map(e=>e.path),['smart_plus/ad/status/update/','smart_plus/adgroup/status/update/','smart_plus/campaign/status/update/']);
  for(const stage of ['ad','adgroup','campaign']){
    const intent=h.events.findIndex(e=>e.action==='activation_intent'&&e.payload.stage===stage),post=h.events.findIndex(e=>e.method==='POST'&&e.path===`smart_plus/${stage}/status/update/`),done=h.events.findIndex(e=>e.action==='activation_complete'&&e.payload.stage===stage);
    assert(intent<post&&post<done);assert.equal(h.events[done].payload.provider_id,j.provider_ids[stage]);
  }
  assert.equal(h.events.find(e=>e.action==='observe').payload.operation_status,'ENABLE');
  assert(!h.events.some(e=>e.action==='refund'));
});

test('unknown enable is reconciled by exact ID after gates switch off without duplicate enable',async()=>{
  const j=job(),h=harness(j,{unknownStage:'ad'});assert.equal((await runActivationWorker(h)).status,'reconcile');
  assert.equal(j.activation_stages.ad.state,'inflight');assert.equal(h.events.filter(e=>e.method==='POST').length,1);
  h.env={};j.activation_can_mutate=false;const result=await runActivationWorker(h);assert.equal(result.status,'blocked');
  assert.equal(j.activation_stages.ad.state,'complete');assert.equal(h.events.filter(e=>e.method==='POST').length,1);
  assert(h.events.some(e=>e.action==='activation_complete'&&e.payload.reconciled===true));
});

test('known disabled reconciliation durably authorizes only the same subsequent request and never infers success',async()=>{
  const j=job();j.activation_stages.ad={state:'inflight',request_hash:fingerprint(activationParameters('ad',j))};
  const h=harness(j);h.env={};assert.equal((await runActivationWorker(h)).status,'blocked');assert.equal(j.activation_stages.ad.state,'retryable');
  const e=h.events.find(e=>e.action==='activation_reconcile');assert.equal(e.payload.operation_status,'DISABLE');assert(e.payload.reconciled);
  assert(!h.events.some(e=>e.method==='POST'));
});

test('failed durable intent, mismatched chain, changed preflight and unowned enable prevent provider mutation',async()=>{
  for(const variation of ['intent','parent','preflight','unexpected','expired','creative']){
    const j=job(),h=harness(j,{denyIntent:variation==='intent',wrongParent:variation==='parent',changedCreative:variation==='creative'});
    if(variation==='preflight')h.preflightImpl=async()=>({...j.evidence,item_id:'666'});
    if(variation==='unexpected')h.state.ad='ENABLE';
    if(variation==='expired')j.end_at=new Date(now-1).toISOString();
    const result=await runActivationWorker(h);assert.equal(result.status,'reconcile');assert(!h.events.some(e=>e.method==='POST'));
  }
});
