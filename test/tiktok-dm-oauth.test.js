import test from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes,createHash } from 'node:crypto';
import { oauthConfig,encryptPrivate,decryptPrivate,startAuthorization,completeAuthorization,publicConnection,runOAuthTokenWorker } from '../api/_lib/tiktok/oauth.js';
const uid='10000000-0000-4000-8000-000000000001',id='20000000-0000-4000-8000-000000000002',idem='30000000-0000-4000-8000-000000000003';
const now=Date.parse('2026-10-23T10:00:00Z'),redirect='https://staging.example.com/api/tiktok-dm/callback/';
const env=()=>({TIKTOK_OAUTH_CLIENT_ID:'12345',TIKTOK_OAUTH_CLIENT_SECRET:'fixture-private-app-secret',TIKTOK_OAUTH_KEY_ID:'test-key-v1',TIKTOK_OAUTH_ENCRYPTION_KEY:randomBytes(32).toString('base64url'),
  TIKTOK_OAUTH_REDIRECT_URI:redirect,TIKTOK_OAUTH_AUTHORIZATION_URL:`https://www.tiktok.com/v2/auth/authorize/?client_key=12345&redirect_uri=${encodeURIComponent(redirect)}&scope=user.info.basic,user.info.username&response_type=code`});
function store(){let row;const events=[];return {events,get row(){return row;},service:async(action,{userId,id:requestedId,token,payload}={})=>{
  events.push({action,payload});
  if(action==='oauth_start'){if(!row)row={...payload,id,user_id:userId,idempotency_key:requestedId,status:'PENDING'};return structuredClone(row);}
  if(action==='oauth_claim'){if(!row||row.state_hash!==payload.state_hash||row.status!=='PENDING')throw Object.assign(Error(),{code:'TIKTOK_OAUTH_REPLAY'});row.status='VERIFYING';row.lease_token=idem;return structuredClone(row);}
  if(action==='oauth_complete'){assert.equal(token,idem);Object.assign(row,payload);return structuredClone(row);}
  if(action==='oauth_fail'){Object.assign(row,payload);return structuredClone(row);}
  return {ok:true};
}};}
const tokenData=()=>({access_token:'fixture-private-user-token',refresh_token:'fixture-private-refresh-token',open_id:'app-scoped-owner-id',token_type:'Bearer',scope:'user.info.basic,user.info.username',expires_in:86400,refresh_token_expires_in:31536000});
function provider({username='Our.Store',scope='user.info.basic,user.info.username',creatorId='app-scoped-owner-id',calls=[],failProfile=false}={}){return async(url,options)=>{
  url=new URL(url);calls.push({path:url.pathname,method:options.method,body:options.body});assert.equal(url.origin,'https://business-api.tiktok.com');assert.equal(options.redirect,'error');
  let data;if(url.pathname.endsWith('/tt_user/oauth2/token/'))data=tokenData();
  else if(url.pathname.endsWith('/tt_user/token_info/get/'))data={app_id:'12345',creator_id:creatorId,scope};
  else if(url.pathname.endsWith('/business/get/')){if(failProfile)throw Error('private network diagnostic');assert.equal(url.searchParams.get('business_id'),'app-scoped-owner-id');data={username,display_name:'Our Store'};}
  else if(url.pathname.endsWith('/tt_user/oauth2/refresh_token/'))data=tokenData();
  else if(url.pathname.endsWith('/tt_user/oauth2/revoke/'))data={};else throw Error(url.pathname);
  return new Response(JSON.stringify({code:0,request_id:`provider-${calls.length}`,data}));
};}
async function begin(db,environment){return startAuthorization(db.service,uid,{username:'Our.Store',idempotency_key:idem},{env:environment,now});}
function callback(start,extra='auth_code=one-use-code'){const state=new URL(start.authorization_url).searchParams.get('state');return {headers:{host:'staging.example.com'},url:`/api/tiktok-dm/callback/?${extra}&state=${state}`};}

test('OAuth configuration pins official authorization, registered HTTPS callback and strong private encryption',()=>{
  const e=env(),c=oauthConfig(e);assert.equal(c.key.length,32);
  for(const change of [{TIKTOK_OAUTH_AUTHORIZATION_URL:e.TIKTOK_OAUTH_AUTHORIZATION_URL.replace('www.tiktok.com','evil.invalid')},{TIKTOK_OAUTH_REDIRECT_URI:'http://staging.example.com/callback/'},{TIKTOK_OAUTH_ENCRYPTION_KEY:'short'}])assert.throws(()=>oauthConfig({...e,...change}),{code:'TIKTOK_OAUTH_NOT_CONFIGURED'});
  const encrypted=encryptPrivate({access_token:'secret'},'owner:request',c);assert(!JSON.stringify(encrypted).includes('secret'));assert.deepEqual(decryptPrivate(encrypted,'owner:request',c),{access_token:'secret'});
  assert.throws(()=>decryptPrivate(encrypted,'different-owner',c),{code:'TIKTOK_PRIVATE_CREDENTIAL_INVALID'});
  assert.throws(()=>decryptPrivate({...encrypted,tag:randomBytes(16).toString('base64url')},'owner:request',c),{code:'TIKTOK_PRIVATE_CREDENTIAL_INVALID'});
});

test('start persists unpredictable hashed state and idempotent retry returns same real provider authorization',async()=>{
  const db=store(),e=env(),a=await begin(db,e),b=await begin(db,e);assert.equal(a.authorization_url,b.authorization_url);
  const state=new URL(a.authorization_url).searchParams.get('state');assert.equal(state.length,43);assert.equal(db.row.state_hash,createHash('sha256').update(state).digest('hex'));
  assert.equal(db.row.requested_username,'our.store');assert.equal(new URL(a.authorization_url).searchParams.get('disable_auto_auth'),'1');assert(!JSON.stringify(db.row).includes(state));
  assert(!JSON.stringify(a).includes('ciphertext'));assert(!JSON.stringify(a).includes(e.TIKTOK_OAUTH_CLIENT_SECRET));
});

test('callback consumes state, exchanges once, verifies provider app/owner/profile and retains immutable join blocker',async()=>{
  const db=store(),e=env(),start=await begin(db,e),calls=[];
  const result=await completeAuthorization(db.service,callback(start),{env:e,fetchImpl:provider({calls}),now});
  assert.equal(result.status,'UNAVAILABLE');assert.equal(result.authorized_username,'our.store');assert.equal(result.error_code,'TIKTOK_IDENTITY_JOIN_UNVERIFIED');
  assert.equal(db.row.status,'VERIFIED_UNLINKED');assert.equal(db.row.evidence.token_creator_id,db.row.open_id);assert.equal(db.events.filter(v=>v.action==='oauth_complete').length,2);
  assert.equal(calls.length,3);assert(!JSON.stringify(result).includes('token'));assert(!JSON.stringify(db.row).includes('fixture-private-user-token'));
  await assert.rejects(completeAuthorization(db.service,callback(start),{env:e,fetchImpl:provider({calls}),now}),{code:'TIKTOK_OAUTH_REPLAY'});assert.equal(calls.length,3);
});

test('wrong callback host, duplicate state and forged state never reach provider exchange',async()=>{
  const db=store(),e=env(),start=await begin(db,e);let calls=0;const request=callback(start);
  for(const bad of [{...request,headers:{host:'evil.invalid'}},{...request,url:request.url+'&state=extra'},{...request,url:request.url.replace(/state=.*/,'state=bad')}])
    await assert.rejects(completeAuthorization(db.service,bad,{env:e,fetchImpl:async()=>{calls++;},now}));
  assert.equal(calls,0);assert.equal(db.row.status,'PENDING');
});

test('provider verified username mismatch and insufficient granted scope never create a connected identity',async()=>{
  for(const [options,expected]of [[{username:'Other.Owner'},'USERNAME_MISMATCH'],[{scope:'user.info.basic'},'MISSING_PERMISSION']]){
    const db=store(),e=env(),start=await begin(db,e);const r=await completeAuthorization(db.service,callback(start),{env:e,fetchImpl:provider(options),now});
    assert.equal(r.status,expected);assert.equal(db.row.status,expected);assert(db.row.credential_ciphertext);assert.notEqual(db.row.status,'CONNECTED');
  }
});

test('failed downstream read retains encrypted grant and never re-exchanges one-use code',async()=>{
  const db=store(),e=env(),start=await begin(db,e),calls=[];
  await assert.rejects(completeAuthorization(db.service,callback(start),{env:e,fetchImpl:provider({calls,failProfile:true}),now}),{code:'TIKTOK_OAUTH_OUTCOME_UNKNOWN'});
  assert(db.row.credential_ciphertext);assert.equal(db.row.status,'UNAVAILABLE');assert(db.events.find(x=>x.action==='oauth_fail').payload.grant_exchanged);
  await assert.rejects(completeAuthorization(db.service,callback(start),{env:e,fetchImpl:provider({calls}),now}));assert.equal(calls.filter(c=>c.path.endsWith('/oauth2/token/')).length,1);
});

test('refresh/revoke workers use leased encrypted grants, preserve same owner and expose no token',async()=>{
  const e=env(),config=oauthConfig(e),row={id,user_id:uid,app_id:'12345',open_id:'app-scoped-owner-id',lease_token:idem};
  row.credential_ciphertext=encryptPrivate(tokenData(),`tiktok:oauth:${uid}:${id}`,config);
  for(const kind of ['refresh','revoke']){
    const events=[],calls=[];const result=await runOAuthTokenWorker(kind,{env:e,now:()=>now,fetchImpl:provider({calls}),service:async(action,args)=>{events.push({action,...args});return action==='oauth_token_claim'?row:{ok:true};}});
    assert.equal(result.status,kind==='refresh'?'refreshed':'revoked');assert.equal(calls.length,1);assert.equal(events[1].token,idem);assert(!JSON.stringify(result).includes('fixture-private'));
  }
});

test('scope loss retains the rotated credential before reporting queued revocation',async()=>{
  const e=env(),config=oauthConfig(e),row={id,user_id:uid,app_id:'12345',open_id:'app-scoped-owner-id',lease_token:idem};
  row.credential_ciphertext=encryptPrivate(tokenData(),`tiktok:oauth:${uid}:${id}`,config);
  let stored;
  const result=await runOAuthTokenWorker('refresh',{env:e,now:()=>now,fetchImpl:async()=>new Response(JSON.stringify({code:0,request_id:'refresh-scope-change',data:{...tokenData(),access_token:'rotated-private-token',scope:'user.info.basic'}})),
    service:async(action,args)=>{if(action==='oauth_token_claim')return row;stored=args.payload;return {ok:true,status:'MISSING_PERMISSION',grant_status:'REVOKING'};}});
  assert.equal(result.status,'reconcile');assert.equal(result.error_code,'TIKTOK_OAUTH_SCOPE_MISSING');
  assert.equal(stored.status,'REFRESHED');assert.deepEqual(stored.scope,['user.info.basic']);
  assert.equal(decryptPrivate(stored.credential_ciphertext,`tiktok:oauth:${uid}:${id}`,config).access_token,'rotated-private-token');
  assert(!JSON.stringify(result).includes('rotated-private-token'));
});
