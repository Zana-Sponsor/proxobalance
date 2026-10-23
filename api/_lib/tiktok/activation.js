import { fail,TikTokError,fingerprint,uuid,numeric } from './contract.js';
import { clientFor,preflight,readStage,observe,stageParameters } from './provider.js';

const order=['ad','adgroup','campaign'];
const stableEvidence=e=>Object.fromEntries(['account_id','flow','identity','verified_username','item_id','targeting','auto_message_id','advertiser_timezone','declared_budget_usd','proxo_total_budget_minor','spend_stop_threshold_minor'].map(k=>[k,e[k]]));
export function activationParameters(stage,job) {
  const key={campaign:'campaign_ids',adgroup:'adgroup_ids',ad:'smart_plus_ad_ids'}[stage];
  if(!key||!numeric(job.provider_ids?.[stage])||!numeric(job.evidence?.identity?.advertiser_id))fail('TIKTOK_ACTIVATION_SNAPSHOT_INVALID');
  return {advertiser_id:job.evidence.identity.advertiser_id,[key]:[job.provider_ids[stage]],operation_status:'ENABLE'};
}
function verifyCreatedSnapshot(stage,actual,job) {
  // A matching ID does not prove that the provider's target, budget, creative
  // or destination still matches the approved submission. Omitted or changed
  // semantic fields require investigation before enabling any delivery.
  for(const [key,value]of Object.entries(stageParameters(stage,job))) {
    if(key==='request_id'||key==='operation_status')continue;
    if(actual[key]===undefined||value===undefined||fingerprint(actual[key])!==fingerprint(value))fail('TIKTOK_ACTIVATION_SNAPSHOT_CHANGED',{uncertain:true,status:409});
  }
}
export async function runActivationWorker({service,env=process.env,fetchImpl=fetch,now=Date.now,clientFactory,preflightImpl=preflight}={}) {
  // Claims may return an uncertain prior intent with mutation disabled. Such a
  // claim must remain readable even after the operator turns every gate OFF.
  const job=await service('claim',{payload:{kind:'activate'}});if(!job?.id)return {ok:true,processed:0,status:'idle'};
  const call=(action,payload={})=>service(action,{id:job.id,token:job.lease_token,payload});
  try {
    if(!job.activation_approval||!uuid(job.activation_approval.id||job.activation_approval.approval_id))fail('TIKTOK_ACTIVATION_APPROVAL_REQUIRED');
    const api=clientFactory?clientFactory(job.account):clientFor(job.account,{env,fetchImpl});
    job.activation_stages||={};
    for(const stage of order) {
      const intent=job.activation_stages[stage];if(intent?.state!=='inflight')continue;
      const expected=fingerprint(activationParameters(stage,job));if(intent.request_hash!==expected)fail('TIKTOK_ACTIVATION_INTENT_MISMATCH',{uncertain:true,status:409});
      const actual=await readStage(api,stage,job),proof={stage,provider_id:job.provider_ids[stage],operation_status:actual.operation_status,
        request_hash:expected,reconciled:true,provider_observed_at:new Date(now()).toISOString()};
      if(actual.operation_status==='ENABLE') {await call('activation_complete',proof);job.activation_stages[stage]={state:'complete',request_hash:expected};}
      else if(actual.operation_status==='DISABLE') {await call('activation_reconcile',proof);job.activation_stages[stage]={state:'retryable',request_hash:expected};}
      else fail('TIKTOK_ACTIVATION_OUTCOME_UNKNOWN',{uncertain:true,status:409});
    }
    if(env.TIKTOK_DM_ACTIVATION_ENABLED!=='true'||job.activation_can_mutate!==true) {
      await call('finish',{status:'completed',error_code:'TIKTOK_ACTIVATION_DISABLED'});
      return {ok:true,processed:1,status:'blocked',error_code:'TIKTOK_ACTIVATION_DISABLED'};
    }
    if(job.ad?.goal!=='messages'||job.ad?.message_destination!=='direct_message'||!Number.isFinite(Date.parse(job.end_at))||Date.parse(job.end_at)<=now())fail('TIKTOK_ACTIVATION_SNAPSHOT_INVALID');
    const verified=await preflightImpl(api,job.account,job.ad,{now:now(),acceptedStart:job.start_at});
    if(fingerprint(stableEvidence(verified))!==fingerprint(stableEvidence(job.evidence)))fail('TIKTOK_PREFLIGHT_CHANGED');
    const chain=await Promise.all(order.map(stage=>readStage(api,stage,job)));
    order.forEach((stage,index)=>verifyCreatedSnapshot(stage,chain[index],job));
    // Enable the campaign last: partial work keeps delivery disabled through
    // the parent until every durable approval and child readback succeeds.
    for(const stage of order) {
      const actual=await readStage(api,stage,job),intent=job.activation_stages[stage];
      verifyCreatedSnapshot(stage,actual,job);
      if(intent?.state==='complete') {if(actual.operation_status!=='ENABLE')fail('TIKTOK_ACTIVATION_STATE_CHANGED',{uncertain:true,status:409});continue;}
      if(actual.operation_status!=='DISABLE')fail('TIKTOK_UNEXPECTED_PROVIDER_ACTIVATION',{uncertain:true,status:409});
      if(Date.parse(job.end_at)<=now())fail('TIKTOK_ACCEPTED_SCHEDULE_INVALID');
      const params=activationParameters(stage,job),requestHash=fingerprint(params);
      await call('activation_intent',{stage,request_hash:requestHash});
      job.activation_stages[stage]={state:'inflight',request_hash:requestHash};
      await api(`smart_plus/${stage}/status/update/`,params,'POST');
      const after=await readStage(api,stage,job);if(after.operation_status!=='ENABLE')fail('TIKTOK_ACTIVATION_UNCONFIRMED',{uncertain:true,status:409});
      await call('activation_complete',{stage,provider_id:job.provider_ids[stage],operation_status:'ENABLE',request_hash:requestHash,provider_observed_at:new Date(now()).toISOString()});
      job.activation_stages[stage]={state:'complete',request_hash:requestHash};
    }
    await call('observe',await observe(api,job,{now:now(),allowMissingSpend:true}));
    await call('finish',{status:'completed'});return {ok:true,processed:1,status:'activated'};
  } catch(error) {
    const code=error instanceof TikTokError?error.code:'TIKTOK_ACTIVATION_UNAVAILABLE';
    await call('finish',{status:'reconcile',error_code:code}).catch(()=>{});
    return {ok:true,processed:1,status:'reconcile',error_code:code};
  }
}
