import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

const routes={
  proxo_tiktok_account_connect:['worker-account-connect'],
  proxo_tiktok_account_videos:['worker-account-videos'],
  proxo_tiktok_account_disconnect:['worker-account-disconnect'],
  proxo_tiktok_conversation_fulfill:['worker-create'],
  proxo_tiktok_conversation_spend_guard:['worker-budget'],
  proxo_tiktok_status_metrics_sync:['worker-status','worker-reconcile','worker-refund'],
};
const workflows=Object.fromEntries(Object.keys(routes).map(name=>[name,
  JSON.parse(readFileSync(new URL(`../integrations/tiktok-dm/${name}.json`,import.meta.url),'utf8'))]));
const success=(status='idle',extra={})=>({statusCode:200,headers:{authorization:'must-not-leak'},
  body:JSON.stringify({ok:true,processed:0,status,...extra})});

// Execute the exported nodes and expressions with intercepted HTTP transport.
function run(name,replies,{origin='https://backend.example',input={},trigger='Controlled manual test'}={}){
  const workflow=workflows[name],seen=new Map(),calls=[];
  const read=key=>({item:{json:seen.get(key)}});
  let cursor=trigger,json=input;
  try{
    for(let i=0;i<30;i++){
      const node=workflow.nodes.find(n=>n.name===cursor);assert.ok(node,cursor);
      if(node.type==='n8n-nodes-base.code')json=Function('$json','$vars','$',node.parameters.jsCode)(json,
        {PROXO_TIKTOK_DM_BACKEND_ORIGIN:origin},read).json;
      if(node.type==='n8n-nodes-base.httpRequest'){
        const url=Function('$json','$',`return (${node.parameters.url.slice(3,-2)});`)(json,read);
        const operation=new URL(url).searchParams.get('op');
        calls.push({url,operation,method:node.parameters.method,body:JSON.parse(node.parameters.jsonBody)});
        assert.ok(operation in replies,`Unexpected operation: ${operation}`);
        json=replies[operation];
      }
      seen.set(cursor,json);
      cursor=workflow.connections[cursor]?.main[0]?.[0]?.node;
      if(!cursor)return {result:json,calls};
    }
    throw new Error('Workflow exceeded finite traversal bound');
  }catch(error){return {error:error.message,calls};}
}

test('Six required TikTok exports are inactive, credential-only and have complete finite connections',()=>{
  assert.equal(Object.keys(workflows).length,6);
  for(const workflow of Object.values(workflows)){
    const names=new Set(workflow.nodes.map(n=>n.name));
    assert.equal(names.size,workflow.nodes.length);
    assert.equal(workflow.active,false);assert.deepEqual(workflow.pinData,{});
    assert.equal(workflow.settings.saveDataErrorExecution,'none');
    assert.equal(workflow.settings.saveDataSuccessExecution,'none');
    assert.equal(workflow.settings.saveManualExecutions,false);
    assert.equal(workflow.settings.saveExecutionProgress,false);
    for(const [from,connection] of Object.entries(workflow.connections)){
      assert.ok(names.has(from));
      for(const output of connection.main)for(const edge of output)assert.ok(names.has(edge.node));
    }
    for(const node of workflow.nodes.filter(n=>n.type==='n8n-nodes-base.httpRequest')){
      assert.deepEqual(node.credentials,{httpHeaderAuth:{name:'Proxo TikTok DM worker'}});
      assert.equal(node.parameters.authentication,'genericCredentialType');
      assert.equal(node.parameters.genericAuthType,'httpHeaderAuth');
      assert.equal(node.parameters.options.redirect.redirect.followRedirects,false);
      assert.equal(node.parameters.options.response.response.neverError,true);
      assert.equal(node.parameters.options.response.response.responseFormat,'text');
      assert.equal(node.retryOnFail,true);assert.equal(node.maxTries,3);
    }
    assert.doesNotMatch(JSON.stringify(workflow),/eyJ[A-Za-z0-9_-]+\.|Bearer\s+[A-Za-z0-9._-]+|Access-Token/);
  }
});

test('Every actual workflow calls only its fixed backend operations and discards caller payment/identity input',()=>{
  for(const [name,operations] of Object.entries(routes)){
    const replies=Object.fromEntries(operations.map(op=>[op,success()]));
    for(const trigger of ['Scheduled poll','Controlled manual test']){
      const output=run(name,replies,{trigger,input:{op:'activate',user_id:'other',amount:123,
        refund_eligible_at:'yesterday',authorization_url:'https://attacker.example',item_id:'unverified'}});
      assert.equal(output.error,undefined);
      assert.deepEqual(output.calls.map(c=>c.operation),operations);
      for(const call of output.calls){
        assert.equal(call.url,`https://backend.example/api/tiktok-dm?op=${call.operation}`);
        assert.equal(call.method,'POST');assert.deepEqual(call.body,{});
      }
      assert.deepEqual(output.result,{ok:true,processed:0,status:'idle'});
    }
  }
  const creationRoutes=Object.entries(routes).filter(([,ops])=>ops.includes('worker-create'));
  assert.deepEqual(creationRoutes.map(([name])=>name),['proxo_tiktok_conversation_fulfill']);
});

test('Unconfigured/local/credential-bearing origins stop before account or financial workers',()=>{
  for(const name of Object.keys(workflows))for(const origin of ['',null,'http://backend.example',
    'https://127.0.0.1','https://localhost','https://api.internal','https://api.local',
    'https://user:secret@backend.example','https://backend.example/path',
    'https://backend.example?token=secret','https://backend.example#fragment']){
    const output=run(name,{}, {origin});
    assert.equal(output.error,'TIKTOK_DM_BACKEND_ORIGIN_NOT_CONFIGURED');
    assert.deepEqual(output.calls,[]);
  }
});

test('Unsupported authorization correlation stays blocked without leaking or fabricating a QR',()=>{
  const output=run('proxo_tiktok_account_connect',{'worker-account-connect':success('blocked',{
    error_code:'TIKTOK_AUTH_CORRELATION_UNAVAILABLE',authorization_url:'secret',request_id:'provider-log-only',
    identity:{access_token:'secret',username:'unverified'}})});
  assert.equal(output.error,undefined);
  assert.deepEqual(output.result,{ok:true,processed:0,status:'blocked',error_code:'TIKTOK_AUTH_CORRELATION_UNAVAILABLE'});
  assert.doesNotMatch(JSON.stringify(output.result),/secret|authorization_url|identity|request_id/);
});

test('Status, uncertain-outcome reconciliation and final refund run in fixed order with no supplied money or clock',()=>{
  const output=run('proxo_tiktok_status_metrics_sync',{
    'worker-status':success('observed'),
    'worker-reconcile':success('reconcile'),
    'worker-refund':success('blocked',{error_code:'FINAL_SPEND_NOT_READY'}),
  });
  assert.equal(output.error,undefined);
  assert.deepEqual(output.calls.map(c=>c.operation),['worker-status','worker-reconcile','worker-refund']);
  assert.ok(output.calls.every(c=>Object.keys(c.body).length===0));
  assert.deepEqual(output.result,{ok:true,processed:0,status:'blocked',error_code:'FINAL_SPEND_NOT_READY'});
});

test('HTTP and malformed-response failures stop subsequent reconciliation/refund with sanitized errors',()=>{
  const cases=[
    [{error:{message:'secret transport detail'}},'TIKTOK_DM_WORKER_TRANSPORT_UNAVAILABLE'],
    [{statusCode:401,body:'<html>Unauthorized</html>'},'TIKTOK_DM_WORKER_AUTHORIZATION_FAILED'],
    [{statusCode:403,body:'secret'},'TIKTOK_DM_WORKER_AUTHORIZATION_FAILED'],
    [{statusCode:429,body:'secret'},'TIKTOK_DM_WORKER_TEMPORARILY_UNAVAILABLE'],
    [{statusCode:503,body:'secret'},'TIKTOK_DM_WORKER_TEMPORARILY_UNAVAILABLE'],
    [{statusCode:422,body:'secret'},'TIKTOK_DM_WORKER_REQUEST_REJECTED'],
    [{statusCode:302,body:'secret'},'TIKTOK_DM_WORKER_REQUEST_REJECTED'],
    [{statusCode:200,body:'not JSON'},'TIKTOK_DM_WORKER_INVALID_RESPONSE'],
    [success('ENABLE'),'TIKTOK_DM_WORKER_INVALID_RESPONSE'],
    [success('paused',{ok:false}),'TIKTOK_DM_WORKER_INVALID_RESPONSE'],
    [success('paused',{processed:2}),'TIKTOK_DM_WORKER_INVALID_RESPONSE'],
  ];
  for(const [response,error] of cases){
    let output=run('proxo_tiktok_status_metrics_sync',{'worker-status':response});
    assert.equal(output.error,error);assert.equal(output.calls.length,1);
    output=run('proxo_tiktok_status_metrics_sync',{'worker-status':success('observed'),'worker-reconcile':response});
    assert.equal(output.error,error);assert.equal(output.calls.length,2);
    assert.ok(!output.calls.some(c=>c.operation==='worker-refund'));
  }
});
