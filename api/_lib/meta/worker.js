import { MetaError, fail, fingerprint } from './contract.js';
import { graphClient, preflight, providerParameters, createStage, reconcileStage, observeChain } from './provider.js';

const stages=['campaign','adset','creative','ad'];
const safeCode = error => error instanceof MetaError ? error.code : 'META_WORKER_INTERNAL_ERROR';
const isInflight = stage => stage?.state==='inflight' || stage?.status==='inflight';
function graphFor(connection,{env,fetchImpl}) {
  const ref=connection?.access_token_env;
  if(typeof ref!=='string'||!/^META_[A-Z0-9_]{1,100}$/.test(ref)) fail('META_ACCESS_TOKEN_REFERENCE_INVALID',{status:503});
  return graphClient({token:env[ref],appSecret:env.META_APP_SECRET,fetchImpl});
}
function identity(evidence) {
  const {page,post,whatsapp,account,tuple,targeting,destination_type}=evidence;
  return {page,post,whatsapp,account,tuple,targeting,destination_type};
}

// Each invocation claims at most one lease. Retries of an HTTP worker trigger
// cannot independently create an object because the intent is committed first.
export async function runWorker(kind,{service,env=process.env,fetchImpl=fetch,now=Date.now,graphFactory}={}) {
  if(!['create','status','reconcile'].includes(kind)) fail('INVALID_WORKER_KIND');
  const job=await service('claim',{payload:{kind}});
  if(!job?.id) return {ok:true,processed:0,status:'idle'};
  const call=(action,payload={})=>service(action,{id:job.id,token:job.lease_token,payload});
  let graph;
  try {
    if(kind==='reconcile'&&(job.terminal_failure||job.status==='refund_pending')&&!Object.keys(job.provider_ids||{}).length&&!Object.values(job.stages||{}).some(isInflight)) {
      await call('refund',{reason:'META_TERMINAL_FAILURE_NO_PROVIDER_OBJECTS'});
      return {ok:true,processed:1,status:'refunded'};
    }
    graph=graphFactory?graphFactory(job.connection):graphFor(job.connection,{env,fetchImpl});
    job.provider_ids ||= {};
    job.stages ||= {};
    if(kind==='create') {
      // Any unconfirmed POST is reconciled before another creation attempt.
      if(Object.values(job.stages).some(isInflight)) {
        await call('finish',{status:'reconcile',error_code:'PROVIDER_OUTCOME_UNKNOWN'});
        return {ok:true,processed:1,status:'reconcile',error_code:'PROVIDER_OUTCOME_UNKNOWN'};
      }
      const fresh=await preflight(job.configuration,job.connection,{graph,fetchImpl,now:now()});
      if(fingerprint(identity(fresh))!==fingerprint(identity(job.evidence))) fail('PREFLIGHT_EVIDENCE_CHANGED');
      for(const stage of stages) {
        if(job.provider_ids[stage]) continue;
        const params=providerParameters(stage,job,fresh);
        const requestHash=fingerprint(params);
        // SQL checks the gate/lease again and refuses an existing intent.
        await call('intent',{stage,request_hash:requestHash});
        job.stages[stage]={state:'inflight',request_hash:requestHash};
        let providerId;
        try { providerId=await createStage(graph,stage,job,fresh); }
        catch(error) {
          if(error instanceof MetaError && !error.uncertain && !error.retryable) {
            await call('reject',{stage,request_hash:requestHash,error_code:safeCode(error)});
            job.stages[stage]={state:'rejected',request_hash:requestHash};
          }
          throw error;
        }
        // Failure saving a known ID still leaves the committed intent. Do not
        // recreate; its deterministic name lets the reconciler recover it.
        await call('complete',{stage,provider_id:providerId,request_hash:requestHash});
        job.provider_ids[stage]=providerId;
        job.stages[stage]={state:'complete',request_hash:requestHash};
      }
      const observation=await observeChain(graph,job,{now:now()});
      await call('observe',observation);
      if(!observation.chain_paused || observation.spend_minor!==null&&observation.spend_minor!==0) fail('PROVIDER_PAUSED_STATE_NOT_CONFIRMED',{uncertain:true,status:409});
      await call('finish',{status:'paused'});
      return {ok:true,processed:1,status:'paused'};
    }
    if(kind==='reconcile') {
      for(const stage of stages) {
        const intent=job.stages[stage];
        if(!isInflight(intent)) continue;
        const requestHash=fingerprint(providerParameters(stage,job,job.evidence));
        if(requestHash!==intent.request_hash) fail('PROVIDER_INTENT_HASH_MISMATCH',{uncertain:true,status:409});
        const providerId=await reconcileStage(graph,stage,job,job.evidence);
        await call('complete',{stage,provider_id:providerId,request_hash:requestHash,reconciled:true});
        job.provider_ids[stage]=providerId;
        job.stages[stage]={state:'complete',request_hash:requestHash};
      }
    }
    const observation=await observeChain(graph,job,{now:now()});
    await call('observe',observation);
    if((job.status==='refund_pending' || job.terminal_failure || observation.terminal_failure || Object.values(job.stages).some(s=>s?.state==='rejected')) &&
        !Object.values(job.stages).some(isInflight) && observation.spend_minor===0 &&
        (observation.chain_paused || !Object.keys(job.provider_ids).length)) {
      await call('refund',{reason:'META_TERMINAL_FAILURE_NO_DELIVERY'});
      return {ok:true,processed:1,status:'refunded'};
    }
    const complete=stages.every(stage=>job.provider_ids[stage]);
    await call('finish',{status:complete&&observation.chain_paused?'paused':'reconcile',error_code:complete?null:'PROVIDER_CHAIN_INCOMPLETE'});
    return {ok:true,processed:1,status:kind==='status'?'observed':'reconcile'};
  } catch(error) {
    const code=safeCode(error);
    // Even a polling error cannot manufacture a terminal failure or zero spend.
    // All uncertain outcomes retain their committed stage and debit.
    const definitive=kind==='create'&&error instanceof MetaError&&!error.uncertain&&!error.retryable&&
      !['META_DISABLED','META_NOT_ALLOWED','META_CONNECTION_REQUIRED','META_CONNECTION_VERIFICATION_REQUIRED'].includes(code)&&
      !Object.values(job.stages||{}).some(isInflight);
    await call('finish',{status:'reconcile',error_code:code,...(definitive?{terminal_failure:true}:{})}).catch(()=>{});
    return {ok:true,processed:1,status:'reconcile',error_code:code};
  }
}

export { graphFor };
