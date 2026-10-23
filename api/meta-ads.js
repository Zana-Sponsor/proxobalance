import { timingSafeEqual } from 'node:crypto';
import { verifyBearer, readJson, json } from './_lib/security.js';
import { MetaError, fail, normalizeConfiguration, fingerprint, unavailableForecast } from './_lib/meta/contract.js';
import { preflight } from './_lib/meta/provider.js';
import { runWorker, graphFor } from './_lib/meta/worker.js';

const uuid=value=>typeof value==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
const allowedBody=(body,keys)=>body&&typeof body==='object'&&!Array.isArray(body)&&Object.keys(body).every(k=>keys.includes(k));
function configuration(env) {
  const base=String(env.PROXO_SUPABASE_URL||'').replace(/\/$/,'');
  const key=env.PROXO_SUPABASE_SERVICE_ROLE_KEY;
  if(!/^https:\/\/[^/?#]+$/.test(base)||!key) fail('META_BACKEND_NOT_CONFIGURED',{status:503});
  return {base,key};
}
export function backend({env=process.env,fetchImpl=fetch,serviceName='pa_meta_service',errorPrefix='META'}={}) {
  const config=configuration(env);
  async function rpc(name,payload,token) {
    let response,data;
    try {
      response=await fetchImpl(`${config.base}/rest/v1/rpc/${name}`,{method:'POST',signal:AbortSignal.timeout(12000),
        headers:{apikey:config.key,Authorization:`Bearer ${token||config.key}`,'Content-Type':'application/json'},body:JSON.stringify(payload)});
      data=await response.json();
    } catch { fail(`${errorPrefix}_BACKEND_UNAVAILABLE`,{uncertain:true,retryable:true,status:503}); }
    if(!response.ok) {
      // Postgres raises only stable error codes. Never return provider/SQL detail.
      const code=/^[A-Z][A-Z0-9_]{2,100}$/.test(data?.message||'')?data.message:`${errorPrefix}_BACKEND_UNAVAILABLE`;
      const unknown=code===`${errorPrefix}_BACKEND_UNAVAILABLE`||response.status>=500;
      fail(code,{uncertain:unknown,retryable:unknown,status:unknown?503:response.status===401?401:422});
    }
    if(data?.ok===false) fail(/^[A-Z][A-Z0-9_]{2,100}$/.test(data.code||'')?data.code:'META_BACKEND_REJECTED',
      {status:data.code==='IDEMPOTENCY_CONFLICT'?409:422,uncertain:data.code==='PROVIDER_OUTCOME_UNKNOWN'});
    return data;
  }
  return {authenticate:req=>verifyBearer(req,config),
    service:async(action,{userId=null,id=null,token=null,payload={}}={})=>{
      const result=await rpc(serviceName,{p_action:action,p_user_id:userId,p_id:id,p_token:token,p_payload:payload});
      if(action==='gate'&&result?.enabled!==true) fail(`${errorPrefix}_DISABLED`);
      return action==='connection'?result?.connection:result;
    },
    user:(req,name,payload)=>rpc(name,payload,String(req.headers?.authorization||'').replace(/^Bearer\s+/i,''))};
}
function workerAuthorized(req,env) {
  const expected=env.META_WORKER_SECRET,header=String(req.headers?.authorization||''),provided=header.replace(/^Bearer\s+/i,'');
  if(typeof expected!=='string'||expected.length<32) fail('META_WORKER_NOT_CONFIGURED',{status:503});
  return /^Bearer\s+/i.test(header)&&Buffer.byteLength(provided)===Buffer.byteLength(expected)&&timingSafeEqual(Buffer.from(provided),Buffer.from(expected));
}

export function createMetaHandler({env=process.env,fetchImpl=fetch,db,now=Date.now,preflightImpl=preflight,workerImpl=runWorker}={}) {
  return async function metaAds(req,res) {
    try {
      if(req.method!=='POST') { res.setHeader('Allow','POST'); return json(res,405,{ok:false,error:'METHOD_NOT_ALLOWED'}); }
      const op=String(req.query?.op||new URL(req.url,'https://local.invalid').searchParams.get('op')||'');
      const api=db||backend({env,fetchImpl});
      if(op==='refund') {
        if(!workerAuthorized(req,env)) fail('UNAUTHORIZED',{status:401});
        const body=await readJson(req,2048);
        if(!allowedBody(body,['user_id','order_id','amount','reason'])||!uuid(body.user_id)||!uuid(body.order_id)||
            typeof body.amount!=='number'||!Number.isFinite(body.amount)||body.amount<=0||
            typeof body.reason!=='string'||body.reason.length<1||body.reason.length>200) fail('INVALID_REFUND_REQUEST');
        return json(res,200,await api.service('refund',{userId:body.user_id,id:body.order_id,payload:{expected_amount:body.amount,reason:body.reason}}));
      }
      if(['worker-create','worker-status','worker-reconcile'].includes(op)) {
        if(!workerAuthorized(req,env)) fail('UNAUTHORIZED',{status:401});
        const body=await readJson(req,1024);
        if(!allowedBody(body,[])) fail('INVALID_INPUT');
        return json(res,200,await workerImpl(op.slice(7),{service:api.service,env,fetchImpl,now}));
      }
      if(!['quote','submit'].includes(op)) fail('NOT_FOUND',{status:404});
      const user=await api.authenticate(req);
      if(!uuid(user?.id)) fail('UNAUTHORIZED',{status:401});
      const body=await readJson(req,32768);
      if(op==='quote') {
        if(!allowedBody(body,['configuration'])) fail('INVALID_INPUT');
        const config=normalizeConfiguration(body.configuration,{now:now()});
        await api.service('gate',{userId:user.id});
        const connection=await api.service('connection',{userId:user.id});
        const graph=graphFor(connection,{env,fetchImpl});
        const evidence=await preflightImpl(config,connection,{graph,fetchImpl,now:now()});
        const quote=await api.service('store_quote',{userId:user.id,payload:{configuration:config,config_hash:fingerprint(config),evidence,forecast:unavailableForecast()}});
        return json(res,200,{...quote,configuration:config});
      }
      if(!allowedBody(body,['submission_id','configuration','quote_id','expected_total_iqd','expected_total_minor','payment_transaction_id']) ||
          !uuid(body.submission_id)||!uuid(body.quote_id)||!Number.isSafeInteger(body.expected_total_iqd)||body.expected_total_iqd<0||
          !Number.isSafeInteger(body.expected_total_minor)||body.expected_total_minor<1||
          body.payment_transaction_id!=null&&!uuid(body.payment_transaction_id)) fail('INVALID_INPUT');
      // The authenticated SQL transaction resolves an existing submission FIRST,
      // before quote expiry, the gate, rate limit or another wallet mutation.
      // Recovery must allow an originally valid schedule that is now in the past.
      const config=normalizeConfiguration(body.configuration,{now:now(),recovering:true});
      const accepted=await api.user(req,'pa_meta_accept',{p_submission_id:body.submission_id,p_quote_id:body.quote_id,
        p_configuration:config,p_expected_total_minor:body.expected_total_minor,p_expected_total_iqd:body.expected_total_iqd,
        p_payment_transaction_id:body.payment_transaction_id||null});
      return json(res,200,accepted);
    } catch(error) {
      const status=error instanceof MetaError?error.status:error.status===413?413:error instanceof SyntaxError?400:503;
      const code=error instanceof MetaError?error.code:error.status===413?'PAYLOAD_TOO_LARGE':error instanceof SyntaxError?'INVALID_INPUT':'META_BACKEND_UNAVAILABLE';
      return json(res,status,{ok:false,error:code,code,uncertain:error instanceof MetaError?error.uncertain:status>=500,retryable:error instanceof MetaError?error.retryable:status>=500});
    }
  };
}

const metaHandler=createMetaHandler();
export default async function advertisingDispatcher(req,res) {
  const platform=String(req.query?.platform||new URL(req.url,'https://local.invalid').searchParams.get('platform')||'');
  if(platform==='tiktok')return (await import('./_lib/tiktok/handler.js')).default(req,res);
  if(platform==='payments')return (await import('./_lib/payments/handler.js')).default(req,res);
  return metaHandler(req,res);
}
