import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { spawn } from 'node:child_process';
import { request as httpRequest } from 'node:http';
import { fileURLToPath } from 'node:url';

const root=fileURLToPath(new URL('../',import.meta.url));
const callback='https://callback.example/api/tiktok-dm/callback/';
const state='a'.repeat(43);

test('Vercel routes the registered OAuth callback through the existing advertising function',()=>{
  const config=JSON.parse(readFileSync(new URL('../vercel.json',import.meta.url),'utf8'));
  assert.deepEqual(config.redirects.find(r=>r.source==='/api/tiktok-dm/callback'),
    {source:'/api/tiktok-dm/callback',destination:'/api/tiktok-dm/callback/',permanent:true});
  assert.deepEqual(config.rewrites.find(r=>r.source==='/api/tiktok-dm/callback/'),
    {source:'/api/tiktok-dm/callback/',destination:'/api/meta-ads?platform=tiktok&op=oauth-callback'});
  assert.equal(config.trailingSlash,undefined,'callback normalization must not change unrelated routes');
});

test('real Express callback preserves query, fixes operation, rejects duplicates and normalizes slash',async t=>{
  // Only the process-local RPC transport is mocked. Load the actual server,
  // dispatcher and OAuth handler; fail if they attempt any provider network.
  const bootstrap=`
    import { Server } from 'node:http';
    import { createHash } from 'node:crypto';
    const listen=Server.prototype.listen;
    Server.prototype.listen=function(...args){
      args[0]=0;this.once('listening',()=>console.log('ROUTE_PORT:'+this.address().port));
      return listen.apply(this,args);
    };
    globalThis.fetch=async(url,options)=>{
      if(String(url)!=='https://database.example/rest/v1/rpc/pa_tiktok_dm_service')throw Error('Unexpected network');
      const body=JSON.parse(options.body);
      if(body.p_action==='oauth_claim'&&body.p_payload.state_hash===createHash('sha256').update('a'.repeat(43)).digest('hex'))
        return Response.json({id:'11111111-1111-4111-8111-111111111111',lease_token:'fixture-lease',app_id:'123',redirect_uri:${JSON.stringify(callback)}});
      if(body.p_action==='oauth_fail'&&body.p_payload.error_code==='TIKTOK_AUTHORIZATION_REJECTED')return Response.json({ok:true});
      throw Error('Unexpected RPC');
    };
    await import('./server.js');
  `;
  const child=spawn(process.execPath,['--input-type=module','-e',bootstrap],{cwd:root,env:{
    PATH:process.env.PATH,PORT:'0',PROXO_SUPABASE_URL:'https://database.example',
    PROXO_SUPABASE_SERVICE_ROLE_KEY:'fixture-key',TIKTOK_OAUTH_CLIENT_ID:'123',
    TIKTOK_OAUTH_CLIENT_SECRET:'fixture-secret',TIKTOK_OAUTH_KEY_ID:'fixture',
    TIKTOK_OAUTH_ENCRYPTION_KEY:Buffer.alloc(32,1).toString('base64url'),
    TIKTOK_OAUTH_REDIRECT_URI:callback,
    TIKTOK_OAUTH_AUTHORIZATION_URL:'https://www.tiktok.com/v2/auth/authorize/?client_key=123&redirect_uri='+encodeURIComponent(callback)
  },stdio:['ignore','pipe','pipe']});
  t.after(()=>{child.kill();});
  const port=await new Promise((resolve,reject)=>{
    const timeout=setTimeout(()=>reject(Error('Routing fixture startup timed out')),10000);
    let output='';
    child.stdout.on('data',chunk=>{output+=chunk;const match=/ROUTE_PORT:(\d+)/.exec(output);if(match){clearTimeout(timeout);resolve(Number(match[1]));}});
    child.once('error',error=>{clearTimeout(timeout);reject(error);});
    child.once('exit',code=>{clearTimeout(timeout);reject(Error('Routing fixture exited '+code));});
  });
  const request=(path,options={})=>new Promise((resolve,reject)=>{
    const req=httpRequest({hostname:'127.0.0.1',port,path,...options,headers:{host:'callback.example',...options.headers},
      signal:AbortSignal.timeout(5000)},res=>{
      const chunks=[];res.on('data',chunk=>chunks.push(chunk));res.on('end',()=>resolve(new Response(Buffer.concat(chunks),{status:res.statusCode,headers:res.headers})));
    });
    req.on('error',reject);req.end();
  });
  const query=`?state=${state}&error=access_denied&error_description=User%20declined&op=submit&platform=meta`;
  const redirect=await request('/api/tiktok-dm/callback'+query);
  assert.equal(redirect.status,308);
  assert.equal(redirect.headers.get('location'),'/api/tiktok-dm/callback/'+query);
  assert.equal(redirect.headers.get('referrer-policy'),'no-referrer');
  const response=await request('/api/tiktok-dm/callback/'+query);
  assert.equal(response.status,200);
  assert.equal(response.headers.get('cache-control'),'no-store');
  assert.equal(response.headers.get('referrer-policy'),'no-referrer');
  assert.deepEqual(await response.json(),{ok:false,status:'REJECTED',error_code:'TIKTOK_AUTHORIZATION_REJECTED'});
  const duplicate=await request('/api/tiktok-dm/callback/'+query+'&state='+state);
  assert.equal(duplicate.status,400);
  assert.equal((await duplicate.json()).code,'TIKTOK_CALLBACK_INVALID');
  assert.equal((await request('/api/tiktok-dm/callback/',{method:'POST'})).status,404);
  assert.equal((await request('/api/tiktok-dm/callback/unrelated')).status,404);
});
