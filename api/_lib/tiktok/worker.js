import { TikTokError,fail,fingerprint,fresh } from './contract.js';
import { clientFor,listVideos,unlinkAdvertiser,preflight,stageParameters,createStage,reconcileStage,readStage,observe,pauseGroup } from './provider.js';

const stages=['campaign','adgroup','ad'];
const inflight=job=>Object.values(job.stages||{}).some(s=>s.state==='inflight');
const safeCode=error=>error instanceof TikTokError?error.code:'TIKTOK_WORKER_UNAVAILABLE';
function stableEvidence(e) {
  return Object.fromEntries(['account_id','flow','identity','verified_username','item_id','targeting','auto_message_id','advertiser_timezone','declared_budget_usd','proxo_total_budget_minor','spend_stop_threshold_minor'].map(k=>[k,e[k]]));
}
export function settlementProof(job,observation,{now=Date.now()}={}) {
  // Reporting has no finality flag. A stable pair of samples is necessary but
  // insufficient: require an independently verified provider settlement record
  // for this exact ad group and amount. No client can submit this evidence.
  const proof=job.account?.capabilities?.settled_reports?.find(p=>p.verified===true&&p.source==='PROVIDER_SETTLEMENT_EXPORT'&&
    p.adgroup_id===job.provider_ids.adgroup&&typeof p.reference==='string'&&p.reference.trim()&&
    (typeof p.final_spend_usd==='number'||typeof p.final_spend_usd==='string'&&/^\d+(?:\.\d{1,6})?$/.test(p.final_spend_usd))&&
    Number.isFinite(Number(p.final_spend_usd))&&Number(p.final_spend_usd)===observation.spend_usd&&Date.parse(p.settled_at)>=Date.parse(job.refund_eligible_at)&&fresh(p.settled_at,now,7*86400000));
  return proof?{settlement_verified:true,settlement_reference:proof.reference,settlement_source:proof.source}:{settlement_verified:false};
}
export async function runWorker(kind,{service,env=process.env,fetchImpl=fetch,now=Date.now,clientFactory,preflightImpl=preflight}={}) {
  if(!['account-connect','account-videos','account-disconnect','create','budget','status','reconcile','refund'].includes(kind))fail('INVALID_WORKER_KIND');
  if(kind==='account-connect')return {ok:true,processed:0,status:'blocked',error_code:'TIKTOK_AUTH_CORRELATION_UNAVAILABLE'};
  const job=await service('claim',{payload:{kind}});
  if(!job?.id)return {ok:true,processed:0,status:'idle'};
  const call=(action,payload={})=>service(action,{id:job.id,token:job.lease_token,payload});
  const account=job.account||job;
  try {
    if(kind==='reconcile'&&job.terminal_failure&&!Object.keys(job.provider_ids||{}).length&&!inflight(job)) {
      await call('refund',{reason:'TIKTOK_REJECTED_BEFORE_CREATION'});return {ok:true,processed:1,status:'refunded'};
    }
    const api=clientFactory?clientFactory(account):clientFor(account,{env,fetchImpl});
    if(kind==='account-videos') {
      const response=await listVideos(api,account,{now:now()});
      await call('cache_videos',response);await call('finish_account',{status:'videos_ready'});
      return {ok:true,processed:1,status:'videos_ready'};
    }
    if(kind==='account-disconnect') {
      await unlinkAdvertiser(api,account);
      await call('disconnect_complete',{advertiser_unlinked:true});
      return {ok:true,processed:1,status:'disconnected'};
    }
    job.provider_ids||={};job.stages||={};
    if(kind==='create') {
      if(inflight(job))fail('TIKTOK_OUTCOME_UNKNOWN',{uncertain:true,status:409});
      if(job.ad?.goal!=='messages'||job.ad?.message_destination!=='direct_message')fail('TIKTOK_CONVERSATION_ONLY');
      if(!Number.isFinite(Date.parse(job.start_at))||Date.parse(job.end_at)<=now()||Date.parse(job.end_at)-Date.parse(job.start_at)!==job.ad.days*86400000)fail('TIKTOK_ACCEPTED_SCHEDULE_INVALID');
      const verified=await preflightImpl(api,account,job.ad,{now:now(),acceptedStart:job.start_at});
      if(fingerprint(stableEvidence(verified))!==fingerprint(stableEvidence(job.evidence)))fail('TIKTOK_PREFLIGHT_CHANGED');
      for(const stage of stages) {
        if(job.provider_ids[stage])continue;
        const requestHash=fingerprint(stageParameters(stage,job));
        await call('intent',{stage,request_hash:requestHash});
        job.stages[stage]={state:'inflight',request_hash:requestHash};
        let id;
        try {id=await createStage(api,stage,job);}
        catch(error) {
          if(error instanceof TikTokError&&!error.uncertain&&!error.retryable) {
            await call('reject',{stage,request_hash:requestHash,error_code:safeCode(error)});
            job.stages[stage]={state:'rejected',request_hash:requestHash};
          }
          throw error;
        }
        await call('complete',{stage,provider_id:id,request_hash:requestHash});
        job.provider_ids[stage]=id;job.stages[stage]={state:'complete',request_hash:requestHash};
      }
      for(const stage of stages) {
        const object=await readStage(api,stage,job);
        if(object.operation_status!=='DISABLE')fail('TIKTOK_DISABLED_CREATION_NOT_CONFIRMED',{uncertain:true,status:409});
      }
      await call('finish',{status:'paused',creation_paused_verified:true});
      return {ok:true,processed:1,status:'paused'};
    }
    if(kind==='reconcile') {
      for(const stage of stages) {
        const intent=job.stages[stage];if(intent?.state!=='inflight')continue;
        const requestHash=fingerprint(stageParameters(stage,job));
        if(requestHash!==intent.request_hash)fail('TIKTOK_INTENT_HASH_MISMATCH',{uncertain:true,status:409});
        const id=await reconcileStage(api,stage,job);
        await call('complete',{stage,provider_id:id,request_hash:requestHash,reconciled:true});
        job.provider_ids[stage]=id;job.stages[stage]={state:'complete',request_hash:requestHash};
      }
      if(job.terminal_failure&&!Object.keys(job.provider_ids).length&&!inflight(job)) {
        await call('refund',{reason:'TIKTOK_REJECTED_BEFORE_CREATION'});return {ok:true,processed:1,status:'refunded'};
      }
      if(!stages.every(s=>job.provider_ids[s])&&!job.terminal_failure) {
        await call('finish',{status:'pending',error_code:'TIKTOK_CHAIN_RECONCILED'});return {ok:true,processed:1,status:'reconcile'};
      }
      if(job.terminal_failure&&!job.provider_ids.ad&&!inflight(job)) {
        // A campaign/group-only chain with no ambiguous ad intent cannot have
        // delivered an ad from this submission. Verify every existing ancestor
        // is disabled; record structural proof, not an invented report value.
        for(const stage of ['campaign','adgroup'])if(job.provider_ids[stage]) {
          if((await readStage(api,stage,job)).operation_status!=='DISABLE')fail('TIKTOK_PARTIAL_CHAIN_NOT_PAUSED',{uncertain:true,status:409});
        }
        await call('observe',{operation_status:'DISABLE',secondary_status:'',spend_usd:0,spend_source:'NO_DELIVERABLE_AD_CHAIN',
          provider_observed_at:new Date(now()).toISOString(),provider_ad_id:null,provider_adgroup_id:job.provider_ids.adgroup||null,
          paused:true,chain_paused:true,no_ad_created:true,terminal:true,metrics:{}});
        await call('refund',{reason:'TIKTOK_REJECTED_BEFORE_AD_CREATION'});return {ok:true,processed:1,status:'refunded'};
      }
    }
    if(kind==='refund'&&(!job.refund_eligible_at||Date.parse(job.refund_eligible_at)>now()))fail('REFUND_WAITING_PERIOD');
    let observation=await observe(api,job,{now:now(),allowMissingSpend:true});
    let observedResult=await call('observe',observation),stopped=false;
    const threshold=Number(job.spend_stop_threshold_usd);
    if(!Number.isFinite(threshold)||threshold<=0)fail('TIKTOK_STOP_THRESHOLD_INVALID');
    const atEnd=Date.parse(job.end_at)<=now(),atLimit=observation.spend_usd!==null&&observation.spend_usd>=threshold;
    const failureStop=!!job.provider_ids.ad&&(job.terminal_failure||
      ['ADGROUP_STATUS_AUDIT_DENY','AD_STATUS_AUDIT_DENY','AD_STATUS_PRIVACY_POLICY_REJECTED'].includes(observation.secondary_status));
    // Every worker with a fresh observation enforces the spend/end guard. A
    // frequent status worker therefore cannot starve a separate budget claim.
    if(job.stop_intent||failureStop||atEnd||atLimit) {
      if(!job.stop_intent)await call('stop_intent',{reason:failureStop?'provider_failure':atLimit?'budget_limit':'scheduled_end'});
      if(observation.raw_statuses?.adgroup?.operation_status!=='DISABLE') {
        await pauseGroup(api,job);
        observation=await observe(api,job,{now:now(),allowMissingSpend:true});
      }
      if(observation.raw_statuses?.adgroup?.operation_status!=='DISABLE')fail('TIKTOK_STOP_UNCONFIRMED',{uncertain:true,status:409});
      // Also recover a successful pause whose DB acknowledgment was lost. This
      // is idempotent, and does not rePOST when the group is already disabled.
      observedResult=await call('pause_complete',observation);stopped=true;
    }
    if(observation.spend_usd===null) {
      // Missing reporting must not prevent a trusted stop, and is never zero
      // delivery or final-spend evidence. Keep financial reconciliation pending.
      await call('finish',{status:'reconcile',error_code:'TIKTOK_SPEND_NOT_AVAILABLE'});
      return {ok:true,processed:1,status:'reconcile',error_code:'TIKTOK_SPEND_NOT_AVAILABLE'};
    }
    if(job.terminal_failure&&!job.provider_ids.ad&&!inflight(job)&&observation.chain_paused&&observation.spend_usd===0) {
      // SQL derives and links the refund; this request never supplies an amount.
      await call('refund',{reason:'TIKTOK_REJECTED_WITH_CONFIRMED_ZERO_DELIVERY'});return {ok:true,processed:1,status:'refunded'};
    }
    const finalDue=job.refund_eligible_at&&Date.parse(job.refund_eligible_at)<=now()&&
      (['completed','rejected'].includes(job.canonical_status)||['completed','rejected'].includes(observedResult?.status)||stopped);
    // Final-spend work shares the existing outbox. Running it on any eligible
    // observation prevents status polling from starving reconciliation/refund.
    if(kind==='refund'||finalDue) {
      const result=await call('final_observe',{...observation,...settlementProof(job,observation,{now:now()})});
      if(result?.settled===true){await call('refund',{reason:'TIKTOK_CONFIRMED_UNUSED_BUDGET'});return {ok:true,processed:1,status:'refunded'};}
      await call('finish',{status:'completed',error_code:'FINAL_REPORT_SETTLEMENT_PENDING'});
      return {ok:true,processed:1,status:'reconcile',error_code:'FINAL_REPORT_SETTLEMENT_PENDING'};
    }
    await call('finish',{status:'completed'});
    return {ok:true,processed:1,status:stopped||kind==='budget'?'guarded':'observed'};
  } catch(error) {
    const code=safeCode(error);
    if(kind.startsWith('account-'))await call('finish_account',{status:'reconcile',error_code:code}).catch(()=>{});
    else {
      const terminal=kind==='create'&&error instanceof TikTokError&&!error.uncertain&&!error.retryable&&!inflight(job)&&!['TIKTOK_DM_DISABLED','STALE_LEASE'].includes(code);
      await call('finish',{status:'reconcile',error_code:code,...(terminal?{terminal_failure:true}:{})}).catch(()=>{});
    }
    return {ok:true,processed:1,status:'reconcile',error_code:code};
  }
}
