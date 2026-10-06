import assert from 'node:assert/strict';
import test from 'node:test';
process.env.SUPABASE_SERVICE_ROLE_KEY='fixture-service-key';
const security=await import('../api/_lib/security.js');
function response(){return {statusCode:0,headers:{},setHeader(k,v){this.headers[k]=v;},end(value){this.body=value;}};}
test('direct requests ignore spoofed IP headers; trusted Vercel requests use the platform IP',()=>{
 process.env.TRUSTED_PROXY='direct';delete process.env.VERCEL;
 assert.equal(security.realClientIp({socket:{remoteAddress:'198.51.100.7'},headers:{'x-forwarded-for':'203.0.113.2'}}),'198.51.100.7');
 process.env.VERCEL='1';process.env.TRUSTED_PROXY='vercel';
 assert.equal(security.realClientIp({headers:{'x-vercel-forwarded-for':'198.51.100.8','x-forwarded-for':'203.0.113.2'}}),'198.51.100.8');
 delete process.env.VERCEL;process.env.TRUSTED_PROXY='direct';
});
test('a banned API request returns a blocked redirect before auth or the handler runs',async()=>{
 const old=globalThis.fetch;let ran=false,auth=false;
 globalThis.fetch=async url=>({ok:true,text:async()=>JSON.stringify(String(url).includes('ex_ip_check')?[{banned:true,reason:'fixture'}]:null)});
 try{
  const handler=security.withSecurity(async()=>{ran=true;},{methods:['GET'],resolveUser:async()=>{auth=true;}});
  const res=response();await handler({method:'GET',url:'/api/access',headers:{},socket:{remoteAddress:'198.51.100.8'}},res);
  assert.equal(res.statusCode,403);assert.equal(JSON.parse(res.body).redirect,'/ip-blocked.html');assert.equal(ran,false);assert.equal(auth,false);
 }finally{globalThis.fetch=old;}
});
test('blocked HTML explains the ban and uses the established support address',()=>{
 const res=response();security.blockedResponse({url:'/'},res);
 assert.equal(res.statusCode,403);assert.ok(res.headers['Content-Type'].startsWith('text/html'));
 assert.match(res.body,/ئایپی ئامێرەکەت بلۆک کراوە/);assert.match(res.body,/https:\/\/t.me\/proxo_exchange/);
});
test('security data is restricted to super admins, including legacy full admins',async()=>{
 const old=globalThis.fetch;
 try{for(const role of ['admin','super_admin']){
  globalThis.fetch=async()=>({ok:true,text:async()=>JSON.stringify([{is_admin:true,is_banned:false,role,staff_permissions:null}])});
  assert.equal(await security.isSecurityAdmin('fixture'),role==='super_admin');
 }}finally{globalThis.fetch=old;}
});
