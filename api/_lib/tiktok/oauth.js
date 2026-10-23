import { createHash,randomBytes,createCipheriv,createDecipheriv } from 'node:crypto';
import { fail,TikTokError,username,uuid } from './contract.js';

const ORIGIN='https://business-api.tiktok.com/open_api/v1.3/';
const REQUIRED_SCOPES=['user.info.basic','user.info.username'];
const hash=value=>createHash('sha256').update(value).digest('hex');
const secret=value=>typeof value==='string'&&value.length>0&&value.length<=16384;
const stateContext=row=>`tiktok:state:${row.user_id}:${row.idempotency_key}`;
const tokenContext=row=>`tiktok:oauth:${row.user_id}:${row.id}`;
export function oauthConfig(env=process.env) {
  const appId=env.TIKTOK_OAUTH_CLIENT_ID,appSecret=env.TIKTOK_OAUTH_CLIENT_SECRET,kid=env.TIKTOK_OAUTH_KEY_ID;
  let authorization,redirect,key;
  try {authorization=new URL(env.TIKTOK_OAUTH_AUTHORIZATION_URL);redirect=new URL(env.TIKTOK_OAUTH_REDIRECT_URI);key=Buffer.from(env.TIKTOK_OAUTH_ENCRYPTION_KEY||'','base64url');}catch{fail('TIKTOK_OAUTH_NOT_CONFIGURED',{status:503});}
  if(!/^\d{1,40}$/.test(appId||'')||!secret(appSecret)||!/^[-a-zA-Z0-9_]{1,40}$/.test(kid||'')||key.length!==32||key.toString('base64url')!==env.TIKTOK_OAUTH_ENCRYPTION_KEY||
    authorization.origin!=='https://www.tiktok.com'||!/^\/v2\/auth\/authorize\/?$/.test(authorization.pathname)||authorization.username||authorization.password||authorization.hash||
    redirect.protocol!=='https:'||redirect.username||redirect.password||redirect.port||redirect.search||redirect.hash||!redirect.pathname.endsWith('/')||
    /^(?:localhost|127\.|10\.|192\.168\.|169\.254\.|\[)/.test(redirect.hostname)||
    authorization.searchParams.get('client_key')!==appId||authorization.searchParams.get('redirect_uri')!==redirect.href)
    fail('TIKTOK_OAUTH_NOT_CONFIGURED',{status:503});
  return {appId,appSecret,kid,key,authorization,redirect};
}
export function encryptPrivate(value,context,config) {
  const iv=randomBytes(12),cipher=createCipheriv('aes-256-gcm',config.key,iv);cipher.setAAD(Buffer.from(context));
  const encrypted=Buffer.concat([cipher.update(JSON.stringify(value),'utf8'),cipher.final()]);
  return {v:1,kid:config.kid,iv:iv.toString('base64url'),tag:cipher.getAuthTag().toString('base64url'),ciphertext:encrypted.toString('base64url')};
}
export function decryptPrivate(envelope,context,config) {
  try {
    if(envelope?.v!==1||envelope.kid!==config.kid||!['iv','tag','ciphertext'].every(k=>typeof envelope[k]==='string'&&/^[A-Za-z0-9_-]+$/.test(envelope[k])))throw Error();
    const iv=Buffer.from(envelope.iv,'base64url'),tag=Buffer.from(envelope.tag,'base64url');if(iv.length!==12||tag.length!==16)throw Error();
    const cipher=createDecipheriv('aes-256-gcm',config.key,iv);cipher.setAAD(Buffer.from(context));cipher.setAuthTag(tag);
    return JSON.parse(Buffer.concat([cipher.update(Buffer.from(envelope.ciphertext,'base64url')),cipher.final()]).toString('utf8'));
  } catch {fail('TIKTOK_PRIVATE_CREDENTIAL_INVALID',{status:503});}
}
export function publicConnection(row,{config,includeAuthorization=false}={}) {
  const result={ok:true,id:row.id,request_id:row.id,requested_username:row.requested_username,status:row.status,
    authorized_username:row.authorized_username||null,expires_at:row.expires_at,error_code:row.error_code||null};
  // OAuth is complete; the app must not describe an unproved Marketing/BC join
  // as a connected advertising identity.
  if(row.status==='VERIFIED_UNLINKED'){result.status='UNAVAILABLE';result.error_code='TIKTOK_IDENTITY_JOIN_UNVERIFIED';}
  if(includeAuthorization&&row.status==='PENDING') {
    const {state}=decryptPrivate(row.state_ciphertext,stateContext(row),config);
    if(typeof state!=='string'||! /^[A-Za-z0-9_-]{43}$/.test(state))fail('TIKTOK_PRIVATE_CREDENTIAL_INVALID',{status:503});
    const url=new URL(config.authorization);url.searchParams.set('state',state);url.searchParams.set('disable_auto_auth','1');result.authorization_url=url.href;
  }
  return result;
}
export async function startAuthorization(service,userId,input,{env=process.env,now=Date.now()}={}) {
  const config=oauthConfig(env),requested=username(input.username);if(!uuid(userId)||!uuid(input.idempotency_key))fail('INVALID_INPUT');
  const state=randomBytes(32).toString('base64url'),basis={user_id:userId,idempotency_key:input.idempotency_key};
  const row=await service('oauth_start',{userId,id:input.idempotency_key,payload:{requested_username:requested,state_hash:hash(state),
    state_ciphertext:encryptPrivate({state},stateContext(basis),config),app_id:config.appId,redirect_uri:config.redirect.href,expires_at:new Date(now+10*60000).toISOString()}});
  if(row.app_id!==config.appId||row.redirect_uri!==config.redirect.href)fail('TIKTOK_OAUTH_CONFIGURATION_CHANGED',{status:409});
  return publicConnection(row,{config,includeAuthorization:true});
}
export async function oauthRequest(path,params,{config,token,fetchImpl=fetch}={}) {
  if(!['tt_user/oauth2/token/','tt_user/oauth2/refresh_token/','tt_user/oauth2/revoke/','tt_user/token_info/get/','business/get/'].includes(path))fail('INVALID_PROVIDER_PATH');
  const read=path==='business/get/',url=new URL(path,ORIGIN);if(read)for(const[k,v]of Object.entries(params))url.searchParams.set(k,typeof v==='object'?JSON.stringify(v):v);
  let response,body;
  try {response=await fetchImpl(url,{method:read?'GET':'POST',redirect:'error',signal:AbortSignal.timeout(12000),headers:{...(token?{'Access-Token':token}:{}),...(!read?{'Content-Type':'application/json'}:{})},...(!read?{body:JSON.stringify(params)}:{})});body=await response.json();}
  catch {fail('TIKTOK_OAUTH_OUTCOME_UNKNOWN',{status:503,uncertain:!read,retryable:true});}
  if(!response.ok||body?.code!==0)fail(response.status>=500||response.status===429?'TIKTOK_OAUTH_UNAVAILABLE':'TIKTOK_AUTHORIZATION_REJECTED',{status:response.status>=500||response.status===429?503:409,uncertain:response.status>=500&&!read,retryable:response.status>=500||response.status===429});
  if(!body.data||typeof body.data!=='object')fail('TIKTOK_OAUTH_RESPONSE_INVALID',{status:503,uncertain:!read});
  return {data:body.data,request_id:typeof body.request_id==='string'?body.request_id:null};
}
function credentialPayload(data,row,config,now) {
  if(!secret(data.access_token)||!secret(data.refresh_token)||!secret(data.open_id)||data.token_type!=='Bearer'||typeof data.scope!=='string'||
    !Number.isFinite(data.expires_in)||data.expires_in<=0||data.expires_in>86400||!Number.isFinite(data.refresh_token_expires_in)||data.refresh_token_expires_in<=0||data.refresh_token_expires_in>366*86400)
    fail('TIKTOK_OAUTH_RESPONSE_INVALID',{status:503,uncertain:true});
  return {open_id:data.open_id,scope:[...new Set(data.scope.split(',').map(s=>s.trim()).filter(Boolean))].sort(),
    credential_ciphertext:encryptPrivate({access_token:data.access_token,refresh_token:data.refresh_token,open_id:data.open_id},tokenContext(row),config),
    access_expires_at:new Date(now+data.expires_in*1000).toISOString(),refresh_expires_at:new Date(now+data.refresh_token_expires_in*1000).toISOString()};
}
export async function completeAuthorization(service,req,{env=process.env,fetchImpl=fetch,now=Date.now()}={}) {
  const config=oauthConfig(env),url=new URL(req.url,`https://${req.headers?.host||'invalid'}`);
  if(url.origin!==config.redirect.origin||url.searchParams.getAll('state').length!==1||url.searchParams.getAll('auth_code').length>1||url.searchParams.getAll('error').length>1)fail('TIKTOK_CALLBACK_INVALID',{status:400});
  const state=url.searchParams.get('state');if(!/^[A-Za-z0-9_-]{43}$/.test(state||''))fail('TIKTOK_CALLBACK_INVALID',{status:400});
  const row=await service('oauth_claim',{payload:{state_hash:hash(state)}});
  const call=(action,payload)=>service(action,{id:row.id,token:row.lease_token,payload});
  let exchanged;
  try {
    if(row.app_id!==config.appId||row.redirect_uri!==config.redirect.href)fail('TIKTOK_OAUTH_CONFIGURATION_CHANGED',{status:409});
    if(url.searchParams.has('error')){await call('oauth_fail',{status:'REJECTED',error_code:'TIKTOK_AUTHORIZATION_REJECTED'});return {ok:false,status:'REJECTED',error_code:'TIKTOK_AUTHORIZATION_REJECTED'};}
    const authCode=url.searchParams.get('auth_code');if(!secret(authCode))fail('TIKTOK_CALLBACK_INVALID',{status:400});
    exchanged=await oauthRequest('tt_user/oauth2/token/',{client_id:config.appId,client_secret:config.appSecret,grant_type:'authorization_code',auth_code:authCode,redirect_uri:config.redirect.href},{config,fetchImpl});
    const credentials=credentialPayload(exchanged.data,row,config,now),token=exchanged.data.access_token;
    // Durably retain the encrypted grant immediately. Lost downstream reads
    // cannot cause another exchange of this one-use authorization code.
    await call('oauth_complete',{...credentials,status:'VERIFYING',evidence:{app_id:config.appId,request_ids:{exchange:exchanged.request_id},verified_at:new Date(now).toISOString()}});
    const info=await oauthRequest('tt_user/token_info/get/',{app_id:config.appId,access_token:token},{config,fetchImpl});
    if(info.data.app_id!==config.appId||info.data.creator_id!==credentials.open_id)fail('TIKTOK_OAUTH_IDENTITY_MISMATCH',{status:409});
    const scopes=typeof info.data.scope==='string'?info.data.scope.split(',').map(s=>s.trim()):[];
    if(!REQUIRED_SCOPES.every(s=>scopes.includes(s)&&credentials.scope.includes(s))) {
      await call('oauth_complete',{...credentials,status:'MISSING_PERMISSION',error_code:'TIKTOK_OAUTH_SCOPE_MISSING'});
      return {ok:false,status:'MISSING_PERMISSION',error_code:'TIKTOK_OAUTH_SCOPE_MISSING'};
    }
    const profile=await oauthRequest('business/get/',{business_id:credentials.open_id,fields:['username','display_name','profile_image']},{config,token,fetchImpl});
    const authorized=username(profile.data.username),matched=authorized===username(row.requested_username);
    const completed=await call('oauth_complete',{...credentials,status:matched?'VERIFIED_UNLINKED':'USERNAME_MISMATCH',authorized_username:authorized,
      error_code:matched?'TIKTOK_IDENTITY_JOIN_UNVERIFIED':'TIKTOK_USERNAME_MISMATCH',evidence:{app_id:config.appId,request_ids:{exchange:exchanged.request_id,
        token_info:info.request_id,profile:profile.request_id},token_creator_id:info.data.creator_id,profile_username:authorized,verified_at:new Date(now).toISOString()}});
    return publicConnection(completed?.id?completed:{...row,status:matched?'VERIFIED_UNLINKED':'USERNAME_MISMATCH',authorized_username:authorized});
  } catch(error) {
    await call('oauth_fail',{status:'UNAVAILABLE',error_code:error instanceof TikTokError?error.code:'TIKTOK_OAUTH_UNAVAILABLE',grant_exchanged:!!exchanged}).catch(()=>{});
    throw error;
  }
}
export async function runOAuthTokenWorker(kind,{service,env=process.env,fetchImpl=fetch,now=Date.now}={}) {
  if(!['refresh','revoke'].includes(kind))fail('INVALID_WORKER_KIND');
  const config=oauthConfig(env),row=await service('oauth_token_claim',{payload:{kind}});if(!row?.id)return {ok:true,processed:0,status:'idle'};
  const call=payload=>service('oauth_token_complete',{id:row.id,token:row.lease_token,payload});
  try {
    if(row.app_id!==config.appId)fail('TIKTOK_OAUTH_CONFIGURATION_CHANGED');
    const tokens=decryptPrivate(row.credential_ciphertext,tokenContext(row),config);
    if(kind==='revoke') {
      const result=await oauthRequest('tt_user/oauth2/revoke/',{client_id:config.appId,client_secret:config.appSecret,access_token:tokens.access_token},{config,fetchImpl});
      await call({status:'REVOKED',provider_request_id:result.request_id});return {ok:true,processed:1,status:'revoked'};
    }
    const result=await oauthRequest('tt_user/oauth2/refresh_token/',{client_id:config.appId,client_secret:config.appSecret,grant_type:'refresh_token',refresh_token:tokens.refresh_token},{config,fetchImpl});
    if(result.data.open_id!==row.open_id)fail('TIKTOK_OAUTH_IDENTITY_MISMATCH');
    const stored=await call({...credentialPayload(result.data,row,config,now()),status:'REFRESHED',provider_request_id:result.request_id});
    if(stored?.status==='MISSING_PERMISSION'||stored?.grant_status==='REVOKING')return {ok:true,processed:1,status:'reconcile',error_code:stored.status==='MISSING_PERMISSION'?'TIKTOK_OAUTH_SCOPE_MISSING':'TIKTOK_OAUTH_REVOKE_REQUESTED'};
    return {ok:true,processed:1,status:'refreshed'};
  } catch(error) {await call({status:'RECONCILE',error_code:error instanceof TikTokError?error.code:'TIKTOK_OAUTH_UNAVAILABLE'}).catch(()=>{});return {ok:true,processed:1,status:'reconcile',error_code:error instanceof TikTokError?error.code:'TIKTOK_OAUTH_UNAVAILABLE'};}
}
