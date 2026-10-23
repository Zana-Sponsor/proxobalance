import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const workflows=['create','status_sync','reconcile_refund'].map(key=>({key,
  flow:JSON.parse(readFileSync(new URL(`../integrations/meta/proxo_meta_ads_${key}.json`,import.meta.url),'utf8'))}));
const operations={create:'worker-create',status_sync:'worker-status',reconcile_refund:'worker-reconcile'};
const code=(node,json,vars={})=>Function('$json','$vars',node.parameters.jsCode)(json,vars).json;
const node=(flow,name)=>flow.nodes.find(n=>n.name===name);

test('Meta polling exports are inactive, connected, credential-only and persist no execution payloads',()=>{
  for(const {flow} of workflows){
    const names=new Set(flow.nodes.map(n=>n.name));
    assert.equal(names.size,flow.nodes.length);
    assert.equal(flow.active,false);
    assert.deepEqual(flow.pinData,{});
    assert.equal(flow.settings.saveDataErrorExecution,'none');
    assert.equal(flow.settings.saveDataSuccessExecution,'none');
    assert.equal(flow.settings.saveManualExecutions,false);
    assert.equal(flow.settings.saveExecutionProgress,false);
    for(const [source,connection] of Object.entries(flow.connections)){
      assert.ok(names.has(source));
      for(const output of connection.main)for(const edge of output)assert.ok(names.has(edge.node));
    }
    for(const start of ['Scheduled poll','Controlled manual test']){
      const seen=new Set();let cursor=start;
      while(cursor){assert.ok(!seen.has(cursor),'No workflow-level retry cycle');seen.add(cursor);
        cursor=flow.connections[cursor]?.main[0]?.[0]?.node;}
      assert.ok(seen.has('Call authenticated worker'));
      assert.ok(seen.has('Check sanitized result'));
    }
    const http=node(flow,'Call authenticated worker');
    assert.deepEqual(http.credentials,{httpHeaderAuth:{name:'Proxo Meta worker'}});
    assert.equal(http.parameters.authentication,'genericCredentialType');
    assert.equal(http.parameters.genericAuthType,'httpHeaderAuth');
    assert.equal(http.parameters.options.redirect.redirect.followRedirects,false);
    assert.equal(http.parameters.options.response.response.neverError,true);
    assert.equal(http.parameters.options.response.response.responseFormat,'text');
    assert.equal(http.retryOnFail,true);assert.equal(http.maxTries,3);
    assert.doesNotMatch(JSON.stringify(flow),/eyJ[A-Za-z0-9_-]+\.|EAAB[A-Za-z0-9]+|Bearer\s+[A-Za-z0-9._-]+/);
  }
});

test('Actual exported configuration discards event input and calls fixed worker operations',()=>{
  for(const {key,flow} of workflows){
    const config=node(flow,'Validate backend configuration');
    const untrusted={url:'https://attacker.example',op:'activate',user_id:'other',amount:999,
      configuration:{payment_method:'WALLET'},authorization:'must-not-forward'};
    const request=code(config,untrusted,{PROXO_META_BACKEND_ORIGIN:'https://backend.example'});
    assert.deepEqual(request,{url:`https://backend.example/api/meta-ads?op=${operations[key]}`});
    const http=node(flow,'Call authenticated worker');
    const url=Function('$json',`return (${http.parameters.url.slice(3,-2)});`)(request);
    assert.equal(url,request.url);
    assert.equal(http.parameters.method,'POST');
    assert.deepEqual(JSON.parse(http.parameters.jsonBody),{});
  }
});

test('Missing, credential-bearing and local backend destinations fail before the HTTP node',()=>{
  const config=node(workflows[0].flow,'Validate backend configuration');
  for(const origin of [undefined,'','http://backend.example','https://127.0.0.1',
    'https://localhost','https://api.internal','https://api.local','https://user:pass@backend.example',
    'https://backend.example/path','https://backend.example?token=secret','https://backend.example#fragment'])
    assert.throws(()=>code(config,{}, {PROXO_META_BACKEND_ORIGIN:origin}),/META_BACKEND_ORIGIN_NOT_CONFIGURED/);
});

test('Worker results expose only allowlisted state and never HTTP headers, order records or diagnostics',()=>{
  for(const {flow} of workflows){
    const check=node(flow,'Check sanitized result');
    for(const status of ['idle','paused','observed','reconcile','refunded']){
      const json={statusCode:200,headers:{authorization:'secret'},body:{ok:true,processed:1,status,
        error_code:'ASSET_PERMISSION_MISSING',provider_error:'secret',configuration:{access_token:'secret'}}};
      assert.deepEqual(code(check,json),{ok:true,processed:1,status,error_code:'ASSET_PERMISSION_MISSING'});
      assert.deepEqual(code(check,{...json,body:JSON.stringify(json.body)}),code(check,json));
    }
    const result=code(check,{statusCode:200,body:{ok:true,processed:0,status:'idle',error_code:'raw secret details'}});
    assert.deepEqual(result,{ok:true,processed:0,status:'idle'});
  }
});

test('Unauthorized, transient, malformed and transport failures terminate with sanitized errors',()=>{
  for(const {flow} of workflows){
    const check=node(flow,'Check sanitized result');
    for(const [response,expected] of [
      [{error:{message:'secret upstream diagnostics'}},'META_WORKER_TRANSPORT_UNAVAILABLE'],
      [{statusCode:401,body:{error:'secret'}},'META_WORKER_AUTHORIZATION_FAILED'],
      [{statusCode:401,body:'<html>unauthorized</html>'},'META_WORKER_AUTHORIZATION_FAILED'],
      [{statusCode:403,body:{error:'secret'}},'META_WORKER_AUTHORIZATION_FAILED'],
      [{statusCode:429,body:{error:'secret'}},'META_WORKER_TEMPORARILY_UNAVAILABLE'],
      [{statusCode:503,body:{error:'secret'}},'META_WORKER_TEMPORARILY_UNAVAILABLE'],
      [{statusCode:422,body:{error:'secret'}},'META_WORKER_REQUEST_REJECTED'],
      [{statusCode:302,body:{}},'META_WORKER_REQUEST_REJECTED'],
      [{statusCode:200,body:{ok:false,processed:1,status:'paused'}},'META_WORKER_INVALID_RESPONSE'],
      [{statusCode:200,body:'not JSON'},'META_WORKER_INVALID_RESPONSE'],
      [{statusCode:200,body:{ok:true,processed:1,status:'ACTIVE'}},'META_WORKER_INVALID_RESPONSE'],
      [{statusCode:200,body:{ok:true,processed:2,status:'paused'}},'META_WORKER_INVALID_RESPONSE'],
    ])assert.throws(()=>code(check,response),error=>error.message===expected);
  }
});
