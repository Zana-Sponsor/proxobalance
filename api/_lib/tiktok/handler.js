import { timingSafeEqual } from 'node:crypto';
import { readJson,json } from '../security.js';
import { backend } from '../../meta-ads.js';
import { TikTokError,fail,uuid,normalizeAd,fingerprint,fresh } from './contract.js';
import { clientFor,readiness,listVideos,preflight } from './provider.js';
import { runWorker } from './worker.js';
import { oauthConfig,startAuthorization,completeAuthorization,publicConnection,runOAuthTokenWorker } from './oauth.js';
import { runActivationWorker } from './activation.js';

const exact=(v,keys)=>v&&typeof v==='object'&&!Array.isArray(v)&&Object.keys(v).every(k=>keys.includes(k));
function workerAuth(req,env) {
  const expected=env.TIKTOK_DM_WORKER_SECRET,header=String(req.headers?.authorization||''),provided=header.replace(/^Bearer\s+/i,'');
  if(typeof expected!=='string'||expected.length<32)fail('TIKTOK_WORKER_NOT_CONFIGURED',{status:503});
  return /^Bearer\s+/i.test(header)&&Buffer.byteLength(expected)===Buffer.byteLength(provided)&&timingSafeEqual(Buffer.from(expected),Buffer.from(provided));
}
export function publicAccount(account,{now=Date.now()}={}) {
  const keys=['id','requested_username','verified_username','display_name','profile_image_url','available_status','can_pull_video','can_manage_message','can_push_video','message_ads_eligible','status','last_verified_at','connected_at','disconnected_at'];
  const result=Object.fromEntries(keys.filter(k=>account[k]!==undefined).map(k=>[k,account[k]]));
  result.dm_ready=false;
  try {readiness(account,{now});result.dm_ready=account.status==='CONNECTED'&&account.available_status==='AVAILABLE'&&account.can_pull_video===true&&account.can_manage_message===true&&account.message_ads_eligible===true&&fresh(account.last_verified_at,now);}catch(error){result.error_code=error.code||'TIKTOK_NOT_READY';}
  return result;
}
export function createTikTokHandler({env=process.env,fetchImpl=fetch,db,now=Date.now,workerImpl=runWorker,preflightImpl=preflight,videosImpl=listVideos}={}) {
  return async(req,res)=>{
    try {
      const op=String(req.query?.op||new URL(req.url,'https://local.invalid').searchParams.get('op')||'');
      const api=db||backend({env,fetchImpl,serviceName:'pa_tiktok_dm_service',errorPrefix:'TIKTOK'});
      if(op==='oauth-callback'&&req.method==='GET') {
        res.setHeader('Cache-Control','no-store');res.setHeader('Referrer-Policy','no-referrer');
        return json(res,200,await completeAuthorization(api.service,req,{env,fetchImpl,now:now()}));
      }
      if(req.method!=='POST'){res.setHeader('Allow','POST');return json(res,405,{ok:false,error:'METHOD_NOT_ALLOWED',code:'METHOD_NOT_ALLOWED'});}
      if(['worker-oauth-refresh','worker-oauth-revoke'].includes(op)) {
        if(!workerAuth(req,env))fail('UNAUTHORIZED',{status:401});if(!exact(await readJson(req,1024),[]))fail('INVALID_INPUT');
        return json(res,200,await runOAuthTokenWorker(op.slice('worker-oauth-'.length),{service:api.service,env,fetchImpl,now}));
      }
      if(op==='worker-activate') {
        if(!workerAuth(req,env))fail('UNAUTHORIZED',{status:401});if(!exact(await readJson(req,1024),[]))fail('INVALID_INPUT');
        return json(res,200,await runActivationWorker({service:api.service,env,fetchImpl,now}));
      }
      if(['account-connect','account-videos','account-disconnect','create','budget','status','reconcile','refund'].some(kind=>op===`worker-${kind}`)) {
        if(!workerAuth(req,env))fail('UNAUTHORIZED',{status:401});
        if(!exact(await readJson(req,1024),[]))fail('INVALID_INPUT');
        return json(res,200,await workerImpl(op.slice(7),{service:api.service,env,fetchImpl,now}));
      }
      if(!['accounts','connect-start','connect-status','connect-revoke','activation-approve','videos','disconnect','seen','quote','submit'].includes(op))fail('NOT_FOUND',{status:404});
      const user=await api.authenticate(req);if(!uuid(user?.id))fail('UNAUTHORIZED',{status:401});
      const body=await readJson(req,32768);
      const call=(action,{id=null,payload={}}={})=>api.service(action,{userId:user.id,id,payload});
      if(op==='accounts') {
        if(!exact(body,[]))fail('INVALID_INPUT');
        const result=await call('list_accounts');const rows=Array.isArray(result)?result:result?.accounts;
        if(!Array.isArray(rows))fail('TIKTOK_BACKEND_RESPONSE_INVALID',{status:503});
        const pending=result?.pending_request;
        return json(res,200,{ok:true,accounts:rows.map(a=>publicAccount(a,{now:now()})),pending_request:pending?publicConnection(pending,{config:oauthConfig(env),includeAuthorization:true}):null});
      }
      if(op==='seen'){if(!exact(body,[]))fail('INVALID_INPUT');return json(res,200,await call('seen'));}
      if(op==='connect-start') {
        if(!exact(body,['username','idempotency_key'])||!uuid(body.idempotency_key))fail('INVALID_INPUT');
        return json(res,200,await startAuthorization(api.service,user.id,body,{env,now:now()}));
      }
      if(op==='connect-status') {
        if(!exact(body,['request_id'])||!uuid(body.request_id))fail('INVALID_INPUT');
        const request=await call('oauth_status',{id:body.request_id});
        return json(res,200,publicConnection(request,{config:oauthConfig(env),includeAuthorization:true}));
      }
      if(op==='connect-revoke') {
        if(!exact(body,['request_id'])||!uuid(body.request_id))fail('INVALID_INPUT');
        await call('oauth_revoke',{id:body.request_id});return json(res,200,{ok:true,status:'REVOKING'});
      }
      if(op==='activation-approve') {
        if(!exact(body,['job_id','approval_id','reason'])||!uuid(body.job_id)||!uuid(body.approval_id)||typeof body.reason!=='string'||body.reason.trim().length<8||body.reason.length>500)fail('INVALID_INPUT');
        return json(res,200,await api.user(req,'pa_tiktok_dm_approve_activation',{p_job_id:body.job_id,p_approval_id:body.approval_id,p_reason:body.reason.trim()}));
      }
      if(op==='disconnect') {
        if(!exact(body,['account_id','idempotency_key'])||!uuid(body.account_id)||!uuid(body.idempotency_key))fail('INVALID_INPUT');
        return json(res,200,await call('disconnect',{id:body.account_id,payload:{idempotency_key:body.idempotency_key}}));
      }
      if(op==='videos') {
        if(!exact(body,['account_id','cursor'])||!uuid(body.account_id))fail('INVALID_INPUT');
        await call('gate');
        const result=await call('account',{id:body.account_id});const account=result?.account||result;
        const response=await videosImpl(clientFor(account,{env,fetchImpl}),account,{cursor:body.cursor,now:now()});
        // The cache is private, user/identity scoped, time bounded and never
        // substitutes for selected-post validation during quote and creation.
        await call('cache_videos',{id:account.id,payload:response});
        return json(res,200,response);
      }
      if(op==='quote') {
        if(!exact(body,['ad','promo_id','promo_code'])||body.promo_id!=null&&!uuid(body.promo_id)||body.promo_code!=null&&(typeof body.promo_code!=='string'||body.promo_code.length>120))fail('INVALID_INPUT');
        const ad=normalizeAd(body.ad,{now:now()});await call('gate');
        const result=await call('account',{id:ad.tiktok_account_id});const account=result?.account||result;
        const evidence=await preflightImpl(clientFor(account,{env,fetchImpl}),account,ad,{now:now()});
        const quoted=await call('store_quote',{payload:{ad,config_hash:fingerprint(ad),evidence,promo_id:body.promo_id||null,promo_code:body.promo_code||null}});
        return json(res,200,{...quoted,ad,normalizedad:ad});
      }
      if(!exact(body,['submission_id','ad','quote_id','expected_cost_usd','expected_price_iqd','promo_id','promo_code','payment_transaction_id'])||
          !uuid(body.submission_id)||!uuid(body.quote_id)||!Number.isFinite(body.expected_cost_usd)||body.expected_cost_usd<0||
          !Number.isSafeInteger(body.expected_price_iqd)||body.expected_price_iqd<0||body.payment_transaction_id!=null&&!uuid(body.payment_transaction_id)||body.promo_id!=null&&!uuid(body.promo_id)||
          body.promo_code!=null&&(typeof body.promo_code!=='string'||body.promo_code.length>120))fail('INVALID_INPUT');
      const ad=normalizeAd(body.ad,{now:now(),recovering:true});
      // Existing submission RPC recovers before gate/expiry and performs the
      // only atomic wallet mutation and existing-outbox insertion.
      return json(res,200,await api.user(req,'pa_submit_ad',{p_submission_id:body.submission_id,p_ad:{...ad,tiktok_quote_id:body.quote_id,
        ...(body.payment_transaction_id?{payment_transaction_id:body.payment_transaction_id}:{})},p_expected_cost_usd:body.expected_cost_usd,
        p_expected_price_iqd:body.expected_price_iqd,p_promo_id:body.promo_id||null,p_promo_code:body.promo_code||null}));
    } catch(error) {
      const status=error instanceof TikTokError?error.status:error.status===413?413:error instanceof SyntaxError?400:503;
      const code=error instanceof TikTokError?error.code:error.status===413?'PAYLOAD_TOO_LARGE':error instanceof SyntaxError?'INVALID_INPUT':'TIKTOK_BACKEND_UNAVAILABLE';
      return json(res,status,{ok:false,error:code,code,uncertain:error instanceof TikTokError?error.uncertain:status>=500,retryable:error instanceof TikTokError?error.retryable:status>=500});
    }
  };
}
export default createTikTokHandler();
