import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { normalizeAd,username,money,schedule,fingerprint,TikTokError } from '../api/_lib/tiktok/contract.js';
import { tiktokClient,readiness,verifyIdentity,publicVideo,listVideos,preflight,stageParameters,reconcileStage,observe,reportSpend,reportMetrics,unlinkAdvertiser } from '../api/_lib/tiktok/provider.js';
import { runWorker } from '../api/_lib/tiktok/worker.js';
import { createTikTokHandler,publicAccount } from '../api/_lib/tiktok/handler.js';

const now=Date.parse('2026-10-23T10:00:00Z'),at=new Date(now).toISOString();
const uid='10000000-0000-4000-8000-000000000001',aid='20000000-0000-4000-8000-000000000002',jid='30000000-0000-4000-8000-000000000003';
const ad=()=>normalizeAd({title:'Direct message',goal:'messages',message_destination:'direct_message',tiktok_account_id:aid,tiktok_item_id:'555',category:'other',age_groups:['all'],gender:'all',location:'iraq',device_type:'all',
  customer_note:'',daily_budget:10,days:1,payment_method:'app_balance',start_date:null,start_time:null,start_immediately:true},{now});
const account=()=>({id:aid,user_id:uid,status:'CONNECTED',requested_username:'Our.Store',verified_username:'our.store',identity_id:'222',identity_type:'BC_AUTH_TT',business_center_id:'333',identity_authorized_bc_id:'333',asset_id:'444',advertiser_id:'111',
  available_status:'AVAILABLE',can_pull_video:true,can_manage_message:true,message_ads_eligible:true,last_verified_at:at,access_token_env:'TIKTOK_TEST_TOKEN',
  owner_binding_proof:{verified:true,reference:'mock-correlated-authorization',method:'PROVIDER_CORRELATED_AUTHORIZATION',proxo_user_id:uid,identity_id:'222',asset_id:'444',business_center_id:'333',advertiser_id:'111',verified_username:'Our.Store',verified_at:at},
  capabilities:{api_version:'v1.3',flow:'UPGRADED_SMART_PLUS_DM',evidence_reference:'private-advertiser-test-42',verified_at:at,conversation_allowlisted:true,adgroup_identity_allowlisted:true,
    iraq_conversation_verified:true,targeting_country:'IQ',iraq_location_id:'888',manual_targeting_verified:true,dm_receiving_verified:true,auto_message_id:'666',auto_message_verified_at:at,
    budget:{currency:'USD',mode:'BUDGET_MODE_TOTAL',minimum_minor:2000,verified_at:at},spend_guard_verified:true,advertiser_timezone:'Asia/Baghdad'}});
const video=(id='555',status='ITEM_STATUS_HESITATE_RECOMMEND')=>({item_type:'VIDEO',item_id:id,status,text:'public video',video_info:{duration:12,poster_url:'https://cdn.example.com/poster',url:'https://cdn.example.com/preview'}});
function fixture({calls=[],identityOverride={},videoOverride={},musicStatus='WITH_FULL_AUTHORIZATION',linked=true,welcomeStatus='PASS'}={}) {
  return async(path,params,method='GET')=>{
    calls.push({path,params,method});
    switch(path) {
      case 'identity/info/':return {identity_info:{identity_id:'222',identity_type:'BC_AUTH_TT',identity_authorized_bc_id:'333',username:'Our.Store',available_status:'AVAILABLE',is_gpppa:false,can_pull_video:true,can_manage_message:true,...identityOverride}};
      case 'bc/asset/advertiser/assigned/':return {list:linked?[{advertiser_id:'111'}]:[],page_info:{total_page:1}};
      case 'bc/asset/get/':return {list:params.asset_type==='TT_ACCOUNT'?[{asset_id:'444',asset_type:'TT_ACCOUNT',tt_account_roles:['POST','DIRECT_MESSAGE']}]:[{asset_id:'111',asset_type:'ADVERTISER',advertiser_role:'OPERATOR'}],page_info:{total_page:1}};
      case 'advertiser/info/':return {list:[{advertiser_id:'111',currency:'USD',timezone:'Asia/Baghdad',display_timezone:'Asia/Baghdad'}]};
      case 'identity/video/info/':return {video_detail:{...video(),...videoOverride}};
      case 'identity/video/get/':return {video_list:[video(),video('556','STATUS_ONLY_FRIEND_SEE'),video('557','ITEM_STATUS_ONLY_AUTHOR_SEE')],has_more:true,cursor:'999'};
      case 'identity/music/authorization/':return {music_authorization:[{item_id:params.item_id,music_status:musicStatus}]};
      case 'tool/language/':return {languages:[{name:'English',code:'en'},{name:'Turkish',code:'verified_tr_code'}]};
      case 'tool/region/':return {region_info:[{location_id:'888',region_code:'IQ',level:'COUNTRY'}]};
      case 'tool/targeting/info/':return {targeting_tag_list:[{targeting_type:'GEO',status_info:{status:'ENABLED'},geo:{geo_id:'888',region_code:'IQ',geo_type:'COUNTRY'}}]};
      case 'creative/auto_message/get/':return {list:[{auto_message_id:'666',auto_message_type:'WELCOME_MESSAGE',audit_status:welcomeStatus}]};
      default:throw Error(`unexpected ${path}`);
    }
  };
}
async function job() {
  const a=ad(),acc=account(),evidence=await preflight(fixture(),acc,a,{now});
  return {id:jid,lease_token:uid,ad:a,account:acc,evidence,provider_ids:{},stages:{},start_at:at,end_at:new Date(now+86400000).toISOString(),spend_stop_threshold_usd:9.5};
}

test('Direct Message contract rejects manual branch fields, keeps budget, canonical sets and Baghdad instants',()=>{
  assert.equal(username(' @Our.Store '),'our.store');assert.throws(()=>username('name/other'),{code:'TIKTOK_USERNAME_INVALID'});
  assert.throws(()=>normalizeAd({...ad(),video_code:'manual'},{now}),{code:'INVALID_INPUT'});
  assert.throws(()=>normalizeAd({...ad(),message_destination:'external_contact'},{now}),{code:'TIKTOK_CONVERSATION_ONLY'});
  assert.throws(()=>normalizeAd({...ad(),daily_budget:2},{now}),{code:'INVALID_BUDGET'});
  const scheduled=normalizeAd({...ad(),start_immediately:false,start_date:'2026-10-24',start_time:'14:00'},{now});
  assert.equal(schedule(scheduled).start_at,'2026-10-24T11:00:00.000Z');assert.equal(schedule(scheduled).end_at,'2026-10-25T11:00:00.000Z');
  assert.deepEqual(money(ad(),2000),{proxo_total_budget_minor:1000,tiktok_declared_budget_minor:2000,spend_stop_threshold_minor:950});
  assert.throws(()=>normalizeAd({...scheduled,start_date:'2026-02-31'},{now,recovering:true}),{code:'INVALID_SCHEDULE'});
});

test('generic QR/list-diff cannot bind owners; account readiness requires exact approved tuple and ownership',async()=>{
  const a=account();
  assert.throws(()=>readiness({...a,owner_binding_proof:{verified:true,reference:'qr-log-id'}}),{code:'TIKTOK_OWNER_BINDING_UNVERIFIED'});
  assert.throws(()=>readiness({...a,owner_binding_proof:{...a.owner_binding_proof,method:'INDEPENDENT_OWNER_VERIFICATION'}},{now}),{code:'TIKTOK_OWNER_BINDING_UNVERIFIED'});
  assert.throws(()=>readiness({...a,capabilities:{...a.capabilities,iraq_conversation_verified:false}},{now}),{code:'TIKTOK_IRAQ_CONVERSATION_UNAVAILABLE'});
  assert.throws(()=>readiness({...a,capabilities:{...a.capabilities,flow:'MANUAL_CLICK'}},{now}),{code:'TIKTOK_CONVERSATION_TUPLE_NOT_VERIFIED'});
  await assert.rejects(verifyIdentity(fixture({identityOverride:{username:'other.store'}}),a,{now}),{code:'TIKTOK_USERNAME_MISMATCH'});
  await assert.rejects(verifyIdentity(fixture({identityOverride:{identity_authorized_bc_id:'999'}}),a,{now}),{code:'TIKTOK_BC_RELATION_INVALID'});
  await assert.rejects(verifyIdentity(fixture({linked:false}),a,{now}),{code:'TIKTOK_ADVERTISER_NOT_LINKED'});
  await assert.rejects(verifyIdentity(fixture({identityOverride:{can_manage_message:false}}),a,{now}),{code:'TIKTOK_MESSAGE_PERMISSION_MISSING'});
  assert.equal(publicAccount(a,{now}).dm_ready,true);
  const blocked=publicAccount({...a,capabilities:{}},{now});assert.equal(blocked.dm_ready,false);assert(!('capabilities' in blocked));assert(!('access_token_env' in blocked));assert(!('owner_binding_proof' in blocked));
});

test('public-only video pagination and music eligibility use documented fields; no fake publish timestamps',async()=>{
  const calls=[],result=await listVideos(fixture({calls}),account(),{cursor:'123',now});
  assert.equal(result.videos.length,1);assert.equal(result.next_cursor,'999');assert.equal(result.videos[0].item_id,'555');assert.equal(result.videos[0].published_at,null);
  assert.equal(result.videos[0].status,'ITEM_STATUS_HESITATE_RECOMMEND');assert.equal(result.videos[0].ad_eligible,true);
  assert.equal(calls.find(c=>c.path==='identity/video/get/').params.cursor,'123');
  assert.equal(publicVideo(video('1','PUBLIC'),account()),null);assert.equal(publicVideo({...video(),item_type:'CAROUSEL'},account()),null);
  assert.equal((await listVideos(fixture({musicStatus:'AUTHORIZATION_MISSING'}),account(),{now})).videos.length,0);
  await assert.rejects(listVideos(fixture(),account(),{cursor:'https://evil.invalid',now}),{code:'TIKTOK_CURSOR_INVALID'});
});

test('quote preflight revalidates selected public video, music, welcome and exact Iraq/Kurdistan targeting',async()=>{
  const calls=[],a=ad();const e=await preflight(fixture({calls}),account(),{...a,location:'kurdistan'},{now});
  assert.deepEqual(e.targeting.location_ids,['888']);assert.deepEqual(e.targeting.languages,['en','verified_tr_code']);
  assert(!e.targeting.age_groups.includes('AGE_13_17'));assert.equal(e.declared_budget_usd,20);assert.equal(e.proxo_total_budget_minor,1000);
  assert(calls.every(c=>c.method==='GET'));
  assert.equal((await preflight(fixture(),account(),a,{now})).targeting.languages,undefined);
  await assert.rejects(preflight(fixture({videoOverride:{status:'ITEM_STATUS_ONLY_AUTHOR_SEE'}}),account(),a,{now}),{code:'TIKTOK_VIDEO_NOT_PUBLIC_OR_AVAILABLE'});
  await assert.rejects(preflight(fixture({welcomeStatus:'REJECTED'}),account(),a,{now}),{code:'TIKTOK_WELCOME_MESSAGE_UNAVAILABLE'});
  await assert.rejects(preflight(fixture({musicStatus:'AUTHORIZATION_MISSING'}),account(),a,{now}),{code:'TIKTOK_VIDEO_MUSIC_INELIGIBLE'});
});

test('live geo capability must expose enabled Iraq for the exact messaging placement tuple',async()=>{
  for(const variation of ['country','disabled','identifier']){
    const api=fixture();
    await assert.rejects(preflight(async(path,params,method)=>{
      if(path==='tool/region/'&&variation==='country')return {region_info:[{location_id:'888',region_code:'US',level:'COUNTRY'}]};
      if(path==='tool/targeting/info/')return {targeting_tag_list:[{targeting_type:'GEO',status_info:{status:variation==='disabled'?'DISABLED':'ENABLED'},geo:{geo_id:variation==='identifier'?'999':'888',region_code:'IQ',geo_type:'COUNTRY'}}]};
      return api(path,params,method);
    },account(),ad(),{now}),{code:'TIKTOK_IRAQ_TARGETING_UNAVAILABLE'});
  }
});

test('real report metrics retain provider-supported counts only and never invent unavailable values',async()=>{
  const j=await job();j.provider_ids={campaign:'701',adgroup:'702',ad:'703'};let query;
  const report=await reportMetrics(async(path,params)=>{assert.equal(path,'report/integrated/get/');query=params;return {list:[{dimensions:{adgroup_id:'702'},metrics:{spend:'1.2345',impressions:'12',clicks:'0.00',video_play_actions:'8',reach:null,conversion:'unknown'}}]};},j);
  assert.deepEqual(query.metrics,['spend','impressions','clicks','video_play_actions','reach','conversion']);assert.equal(query.query_lifetime,true);
  assert.deepEqual(report,{spend_usd:1.2345,metrics:{impressions:12,clicks:0,video_views:8}});
  await assert.rejects(reportMetrics(async()=>({list:[{dimensions:{adgroup_id:'999'},metrics:{spend:'0'}}]}),j),{code:'TIKTOK_SPEND_NOT_AVAILABLE'});
});

test('Smart+ builders create only disabled Conversation entities and preserve native existing identity/item',async()=>{
  const j=await job();j.provider_ids={campaign:'701',adgroup:'702'};
  const c=stageParameters('campaign',j),g=stageParameters('adgroup',j),a=stageParameters('ad',j);
  for(const p of [c,g,a])assert.equal(p.operation_status,'DISABLE');
  assert.equal(c.budget_optimize_on,false);assert.equal(g.optimization_goal,'CONVERSATION');assert.equal(g.budget,20);assert.equal(g.billing_event,'OCPM');
  assert.equal(g.schedule_start_time,'2026-10-23 10:00:00');assert.equal(g.schedule_end_time,'2026-10-24 10:00:00');
  assert.equal(g.identity_authorized_bc_id,'333');assert.deepEqual(g.placements,['PLACEMENT_TIKTOK']);
  assert.equal(a.creative_list[0].creative_info.tiktok_item_id,'555');assert.equal(a.creative_list[0].creative_info.identity_id,'222');assert.equal(a.auto_message_list[0].auto_message_id,'666');
  assert.equal(a.call_to_action_list[0].call_to_action,'SEND_MESSAGE');assert.equal(a.request_id,undefined);assert(BigInt(c.request_id)<2n**63n);
});

test('TikTok transport pins fixed origin/version, authenticates header, and preserves uncertain write outcomes',async()=>{
  const calls=[],api=tiktokClient({token:'never-in-url',fetchImpl:async(url,options)=>{calls.push({url:String(url),options});return new Response(JSON.stringify({code:0,data:{identity_info:{}}}));}});
  await api('identity/info/',{identity_id:'222'});assert.match(calls[0].url,/business-api.tiktok.com\/open_api\/v1.3\/identity\/info\//);assert(!calls[0].url.includes('never-in-url'));
  assert.equal(calls[0].options.headers['Access-Token'],'never-in-url');assert.equal(calls[0].options.redirect,'error');
  await assert.rejects(api('../ssrf/',{}),{code:'INVALID_PROVIDER_PATH'});
  const unavailable=tiktokClient({token:'x',fetchImpl:async()=>{throw Error('raw private failure');}});
  await assert.rejects(unavailable('smart_plus/ad/create/',{},'POST'),e=>e.code==='TIKTOK_OUTCOME_UNKNOWN'&&e.uncertain);
  await assert.rejects(unavailable('identity/info/'),e=>e.code==='TIKTOK_UNAVAILABLE'&&!e.uncertain);
});

test('worker commits intent before POST and never blindly retries an unknown create',async()=>{
  const j=await job(),events=[];let posts=0;
  const service=async(action,{payload}={})=>{events.push(action);if(action==='claim')return structuredClone(j);if(action==='intent')j.stages[payload.stage]={state:'inflight',request_hash:payload.request_hash};return {ok:true};};
  const api=async(path,p,method)=>{assert.equal(method,'POST');assert.equal(events.at(-1),'intent');posts++;throw new TikTokError('TIKTOK_OUTCOME_UNKNOWN',{uncertain:true});};
  const deps={service,clientFactory:()=>api,preflightImpl:async()=>j.evidence,now:()=>now};
  assert.equal((await runWorker('create',deps)).status,'reconcile');assert.equal(posts,1);assert.equal(j.stages.campaign.state,'inflight');
  await runWorker('create',deps);assert.equal(posts,1);assert(!events.includes('refund'));assert(!events.includes('reject'));
});

test('account worker maintains real OAuth grants, prioritizing revoke without fabricating a connected identity',async()=>{
  const calls=[];const result=await runWorker('account-connect',{oauthTokenWorkerImpl:async kind=>{calls.push(kind);return {ok:true,processed:0,status:'idle'};}});
  assert.equal(result.status,'idle');assert.deepEqual(calls,['revoke','refresh']);assert.equal(result.authorization_url,undefined);
});

test('never-created terminal job refunds safely even when provider credentials are unavailable',async()=>{
  const j=await job();j.terminal_failure=true;j.account.access_token_env=null;const events=[];
  const result=await runWorker('reconcile',{env:{},service:async action=>{events.push(action);return action==='claim'?j:{ok:true};}});
  assert.equal(result.status,'refunded');assert.deepEqual(events,['claim','refund']);
});

function providerState(j,{spend='9.50',campaignStatus='ENABLE',groupStatus='ENABLE',adStatus='ENABLE',adSecondaryStatus,groupSecondaryStatus,reportError,emptyReport=false}={}) {
  const base={advertiser_id:'111',campaign_id:'701',adgroup_id:'702'};
  return async(path,params,method)=>{
    if(path==='report/integrated/get/'){if(reportError)throw reportError;return {list:emptyReport?[]:[{dimensions:{adgroup_id:'702'},metrics:{spend}}]};}
    if(path==='smart_plus/campaign/get/')return {list:[{...base,operation_status:campaignStatus,secondary_status:'CAMPAIGN_STATUS_ENABLE'}]};
    if(path==='smart_plus/adgroup/get/')return {list:[{...base,operation_status:groupStatus,secondary_status:groupSecondaryStatus||(groupStatus==='DISABLE'?'ADGROUP_STATUS_DISABLE':'ADGROUP_STATUS_DELIVERY_OK')}]};
    if(path==='smart_plus/ad/get/')return {list:[{...base,smart_plus_ad_id:'703',operation_status:adStatus,secondary_status:adSecondaryStatus||(adStatus==='DISABLE'?'AD_STATUS_DISABLE':'AD_STATUS_DELIVERY_OK')}]};
    if(path==='smart_plus/adgroup/status/update/'){assert.equal(method,'POST');assert.equal(params.operation_status,'DISABLE');groupStatus='DISABLE';return {};}
    throw Error(path);
  };
}

test('95 percent guard records stop intent, disables and reads back before completion without new charge',async()=>{
  const j=await job();j.provider_ids={campaign:'701',adgroup:'702',ad:'703'};const events=[];
  const service=async(action,{payload}={})=>{events.push({action,payload});return action==='claim'?j:{ok:true};};
  const result=await runWorker('budget',{service,clientFactory:()=>providerState(j),now:()=>now});
  assert.equal(result.status,'guarded');assert.equal(events.find(e=>e.action==='stop_intent').payload.reason,'budget_limit');
  assert(events.find(e=>e.action==='pause_complete').payload.paused);assert(!events.some(e=>['refund','intent'].includes(e.action)));
});

test('status considers disabled ancestors/ad; reporting errors and empty data never imply zero',async()=>{
  const j=await job();j.provider_ids={campaign:'701',adgroup:'702',ad:'703'};
  assert.equal((await observe(providerState(j,{adStatus:'DISABLE'}),j,{now})).operation_status,'DISABLE');
  assert.equal((await observe(providerState(j,{campaignStatus:'DISABLE'}),j,{now})).operation_status,'DISABLE');
  await assert.rejects(reportSpend(async()=>({list:[]}),j),{code:'TIKTOK_SPEND_NOT_AVAILABLE'});
  const events=[];
  await runWorker('status',{service:async action=>{events.push(action);return action==='claim'?j:{ok:true};},clientFactory:()=>async()=>{throw new TikTokError('TIKTOK_UNAVAILABLE',{retryable:true});},now:()=>now});
  assert(!events.includes('observe'));assert(!events.includes('refund'));
});

test('actual provider UTC timestamps are retained separately from fetch time and older snapshots cannot replace them',async()=>{
  const j=await job();j.provider_ids={campaign:'701',adgroup:'702',ad:'703'};const base=providerState(j);
  const api=async(path,params,method)=>{const result=await base(path,params,method);if(path.startsWith('smart_plus/'))Object.assign(result.list[0],{create_time:'2026-10-22 09:00:00',modify_time:'2026-10-23 09:59:00'});return result;};
  const observed=await observe(api,j,{now});assert.equal(observed.raw_statuses.ad.modify_time,'2026-10-23T09:59:00.000Z');assert.equal(observed.provider_observed_at,at);
  j.observation={raw_statuses:{ad:{modify_time:'2026-10-23T10:00:00.000Z'}}};
  await assert.rejects(observe(api,j,{now}),{code:'TIKTOK_STALE_PROVIDER_OBSERVATION'});
});

test('a known ad with terminal failure and current zero report cannot bypass final-settlement waiting',async()=>{
  const j=await job();j.provider_ids={campaign:'701',adgroup:'702',ad:'703'};j.terminal_failure=true;const events=[];
  await runWorker('reconcile',{service:async(action)=>{events.push(action);return action==='claim'?j:{ok:true};},
    clientFactory:()=>providerState(j,{spend:'0',campaignStatus:'DISABLE',groupStatus:'DISABLE',adStatus:'DISABLE'}),now:()=>now});
  assert(!events.includes('refund'));assert(!events.includes('final_observe'));
});

test('known-ad failure or explicit audit rejection disables delivery and starts financial waiting without early refund',async()=>{
  for(const options of [{terminal_failure:true},{adSecondaryStatus:'AD_STATUS_AUDIT_DENY'},{adSecondaryStatus:'AD_STATUS_PRIVACY_POLICY_REJECTED'},{groupSecondaryStatus:'ADGROUP_STATUS_AUDIT_DENY'}]) {
    const j=await job();j.provider_ids={campaign:'701',adgroup:'702',ad:'703'};j.terminal_failure=options.terminal_failure===true;
    const events=[];let posts=0;const api=providerState(j,{spend:'0',...options});
    const result=await runWorker('reconcile',{service:async(action,{payload}={})=>{events.push({action,payload});return action==='claim'?j:{ok:true,status:'rejected'};},
      clientFactory:()=>async(path,params,method)=>{if(method==='POST')posts++;return api(path,params,method);},now:()=>now});
    assert.equal(result.status,'guarded');assert.equal(posts,1);
    assert.equal(events.find(e=>e.action==='stop_intent').payload.reason,'provider_failure');
    assert.equal(events.find(e=>e.action==='pause_complete').payload.raw_statuses.adgroup.operation_status,'DISABLE');
    assert(!events.some(e=>['refund','final_observe'].includes(e.action)));
  }
});

test('missing spend cannot block trusted end, persisted stop, terminal failure or observed group rejection',async()=>{
  for(const options of [{dueEnd:true},{stop_intent:{reason:'budget_limit'}},{terminal_failure:true},{groupSecondaryStatus:'ADGROUP_STATUS_AUDIT_DENY'}]) {
    for(const missing of [{emptyReport:true},{reportError:new TikTokError('TIKTOK_UNAVAILABLE',{retryable:true})}]) {
      const j=await job();j.provider_ids={campaign:'701',adgroup:'702',ad:'703'};Object.assign(j,options);if(options.dueEnd)j.end_at=new Date(now-1).toISOString();
      const events=[];let posts=0;const api=providerState(j,{...options,...missing});
      const result=await runWorker('status',{service:async(action,{payload}={})=>{events.push({action,payload});return action==='claim'?j:{ok:true};},
        clientFactory:()=>async(path,params,method)=>{if(method==='POST')posts++;return api(path,params,method);},now:()=>now});
      assert.equal(posts,1);assert.equal(result.error_code,'TIKTOK_SPEND_NOT_AVAILABLE');
      const stopped=events.find(e=>e.action==='pause_complete').payload;
      assert.equal(stopped.raw_statuses.adgroup.operation_status,'DISABLE');assert.equal(stopped.spend_usd,null);assert.deepEqual(stopped.metrics,{});
      assert(!events.some(e=>['refund','final_observe'].includes(e.action)));
    }
  }
});

test('rejected known ad with confirmed failure stop reaches settlement after the required waiting period',async()=>{
  const j=await job();j.provider_ids={campaign:'701',adgroup:'702',ad:'703'};j.terminal_failure=true;j.canonical_status='rejected';
  j.stop_intent={reason:'provider_failure'};j.refund_eligible_at=new Date(now-1000).toISOString();
  j.account.capabilities.settled_reports=[{verified:true,source:'PROVIDER_SETTLEMENT_EXPORT',reference:'rejected-final',adgroup_id:'702',final_spend_usd:0,settled_at:at}];
  const events=[];let posts=0;const api=providerState(j,{spend:'0',groupStatus:'DISABLE',adSecondaryStatus:'AD_STATUS_PRIVACY_POLICY_REJECTED'});
  const result=await runWorker('reconcile',{service:async(action,{payload}={})=>{events.push({action,payload});return action==='claim'?j:{ok:true,status:'rejected'};},
    settlementCollectorImpl:async()=>({source:'TIKTOK_OFFLINE_REPORT_CANDIDATE',settlement_verified:false}),
    clientFactory:()=>async(path,params,method)=>{if(method==='POST')posts++;return api(path,params,method);},now:()=>now});
  assert.equal(posts,0);assert.equal(result.status,'reconcile');
  assert(!events.some(e=>e.action==='stop_intent'));
  assert(events.some(e=>e.action==='ingest_report_candidate'));assert(!events.some(e=>['refund','final_observe'].includes(e.action)));
});

test('partial campaign-only failure proves disabled ancestors before compensating without fake provider report',async()=>{
  const j=await job();j.provider_ids={campaign:'701'};j.terminal_failure=true;const events=[];
  const result=await runWorker('reconcile',{service:async(action,{payload}={})=>{events.push({action,payload});return action==='claim'?j:{ok:true};},
    clientFactory:()=>async(path)=>{assert.equal(path,'smart_plus/campaign/get/');return {list:[{advertiser_id:'111',campaign_id:'701',operation_status:'DISABLE'}]};},now:()=>now});
  assert.equal(result.status,'refunded');assert.equal(events.find(e=>e.action==='observe').payload.spend_source,'NO_DELIVERABLE_AD_CHAIN');assert(events.some(e=>e.action==='refund'));
});

test('manual settlement capability flags cannot authorize refunds; candidate and immutable record lookup remain required',async()=>{
  const j=await job();j.provider_ids={campaign:'701',adgroup:'702',ad:'703'};j.refund_eligible_at=new Date(now-60000).toISOString();j.stop_intent={reason:'budget_limit'};
  j.account.capabilities.settled_reports=[{verified:true,source:'PROVIDER_SETTLEMENT_EXPORT',reference:'settlement1',adgroup_id:'702',final_spend_usd:9.9,settled_at:at}];
  const events=[];
  const result=await runWorker('refund',{service:async(action,{payload}={})=>{events.push({action,payload});return action==='claim'?j:{ok:true};},
    settlementCollectorImpl:async()=>({source:'TIKTOK_OFFLINE_REPORT_CANDIDATE',settlement_verified:false}),
    clientFactory:()=>providerState(j,{spend:'9.90',groupStatus:'DISABLE'}),now:()=>now});
  assert.equal(result.status,'reconcile');assert(events.some(e=>e.action==='settlement_lookup'));assert(!events.some(e=>['refund','final_observe'].includes(e.action)));assert(events.some(e=>e.action==='pause_complete'));
  j.refund_eligible_at=new Date(now+1000).toISOString();events.length=0;
  await runWorker('refund',{service:async action=>{events.push({action});return action==='claim'?j:{ok:true};},clientFactory:()=>providerState(j),now:()=>now});
  assert(!events.some(e=>e.action==='refund'||e.action==='final_observe'));
});

test('status worker enforces threshold and recovers a lost pause acknowledgment without repeat POST or refund starvation',async()=>{
  const j=await job();j.provider_ids={campaign:'701',adgroup:'702',ad:'703'};
  const events=[];let posts=0;
  const base=providerState(j,{groupStatus:'DISABLE',spend:'9.90'});j.stop_intent={reason:'budget_limit'};
  j.refund_eligible_at=new Date(now-1000).toISOString();j.canonical_status='completed';
  j.account.capabilities.settled_reports=[{verified:true,source:'PROVIDER_SETTLEMENT_EXPORT',reference:'settlement',adgroup_id:'702',final_spend_usd:9.9,settled_at:at}];
  const result=await runWorker('status',{service:async(action)=>{events.push(action);return action==='claim'?j:action==='pause_complete'?{ok:true,status:'completed'}:action==='settlement_lookup'?{ok:true,settlement_verified:true,settlement_record_id:aid}:action==='final_observe'?{ok:true,settled:true}:{ok:true};},
    settlementCollectorImpl:async()=>({source:'TIKTOK_OFFLINE_REPORT_CANDIDATE',settlement_verified:false}),
    clientFactory:()=>async(p,q,m)=>{if(m==='POST')posts++;return base(p,q,m);},now:()=>now});
  assert.equal(posts,0);assert(events.includes('pause_complete'));assert(events.includes('final_observe'));assert(events.includes('refund'));assert.equal(result.status,'refunded');
});

test('disconnect only removes intended advertiser after durable request and verified read-back',async()=>{
  const a=account();let linked=true;const calls=[];
  const api=async(path,params,method)=>{calls.push({path,params,method});if(path==='bc/asset/advertiser/unassign/'){linked=false;return {};}return {list:linked?[{advertiser_id:'111'}]:[],page_info:{total_page:1}};};
  await assert.rejects(unlinkAdvertiser(api,a),{code:'TIKTOK_DISCONNECT_INTENT_REQUIRED'});
  await unlinkAdvertiser(api,{...a,status:'REVOKING'});assert.equal(calls.filter(c=>c.method==='POST').length,1);assert(!calls.some(c=>c.path.includes('tt_account/unlink')));
  await unlinkAdvertiser(api,{...a,status:'REVOKING'});assert.equal(calls.filter(c=>c.method==='POST').length,1);
});

test('isolated HTTP API authenticates and masks private proof; quote readonly and zero-cost submit recovery uses existing RPC',async t=>{
  const events=[],a=account(),draft=ad(),env={TIKTOK_TEST_TOKEN:'not-secret-fixture'};
  const db={authenticate:async req=>req.headers.authorization==='Bearer jwt'?{id:uid}:null,
    service:async(action,args)=>{events.push({action,args});return action==='list_accounts'?{accounts:[a]}:action==='account'?{account:a}:action==='store_quote'?{ok:true,quote_id:jid,cost_usd:0}:{ok:true,enabled:true};},
    user:async(req,name,payload)=>{events.push({action:name,payload});return {ok:true,ad_id:aid};}};
  const server=createServer(createTikTokHandler({db,env,now:()=>now,preflightImpl:async()=>({authorized:true,ready:true,account_id:aid,declared_budget_usd:20})}));
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));t.after(()=>new Promise(resolve=>server.close(resolve)));
  const url=`http://127.0.0.1:${server.address().port}/api/tiktok-dm`;
  const post=async(op,body,token='jwt')=>{const r=await fetch(`${url}?op=${op}`,{method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:JSON.stringify(body)});return {status:r.status,body:await r.json()};};
  assert.equal((await post('accounts',{},'bad')).status,401);assert.equal(events.length,0);
  const accounts=await post('accounts',{});assert.equal(accounts.body.accounts[0].dm_ready,true);assert(!JSON.stringify(accounts.body).includes('owner_binding_proof'));assert(!JSON.stringify(accounts.body).includes('access_token_env'));
  const connect=await post('connect-start',{username:'Our.Store',idempotency_key:uid});assert.equal(connect.status,503);assert.equal(connect.body.code,'TIKTOK_OAUTH_NOT_CONFIGURED');assert.equal(connect.body.authorization_url,undefined);
  events.length=0;assert.equal((await post('quote',{ad:draft})).status,200);assert.deepEqual(events.map(e=>e.action),['gate','account','store_quote']);
  events.length=0;assert.equal((await post('submit',{submission_id:uid,ad:draft,quote_id:jid,expected_cost_usd:0,expected_price_iqd:0})).status,200);assert.deepEqual(events.map(e=>e.action),['pa_submit_ad']);
  assert.equal(events[0].payload.p_ad.tiktok_quote_id,jid);assert.equal(events[0].payload.p_expected_cost_usd,0);
});
