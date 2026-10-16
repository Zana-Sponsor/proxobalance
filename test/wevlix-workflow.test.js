import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import * as c from '../integrations/wevlix/contracts.mjs';

const workflow=JSON.parse(readFileSync(new URL('../integrations/wevlix/proxo-wevlix.json',import.meta.url)));
const configuredWorkflow=JSON.parse(readFileSync(new URL('../integrations/wevlix/proxo-wevlix-configured.json',import.meta.url)));
const uuid='11111111-1111-4111-8111-111111111111';
const reserve={statusCode:200,body:{success:true,otp_id:uuid,code:'001234',send_count:1,
  expires_at:'2026-10-16T00:05:00Z',reused:false,client_message_id:`proxo-otp-${uuid}-1`}};
const delivery={statusCode:202,body:{success:true,data:{messageId:'message-12345678',status:'queued'}}};
function expression(source,json,seen) {
  const read=name=>({item:{json:seen.get(name)}});
  return Function('$json','$',`return (${source.replace(/^=\{\{\s*/,'').replace(/\s*\}\}$/,'')});`)(json,read);
}
// Execute the actual exported Code, IF, HTTP expressions and response nodes;
// all HTTP is intercepted. No Wevlix, Supabase or real recipients are used.
function run(start,input,replies,target=workflow) {
  let name=start,json=input;const seen=new Map(),calls=[];
  for(let step=0;step<50;step++){
    const n=target.nodes.find(n=>n.name===name);assert.ok(n,name);
    let branch=0;
    if(n.type.endsWith('.code'))json=Function('$json','$',n.parameters.jsCode)(json,
      name=>({item:{json:seen.get(name)}})).json;
    if(n.type.endsWith('.if'))branch=json.proceed===true?0:1;
    if(n.type.endsWith('.httpRequest')){
      const body=n.parameters.jsonBody?expression(n.parameters.jsonBody,json,seen):undefined;
      calls.push({name,body});assert.ok(name in replies,`unexpected outbound call ${name}`);
      json=replies[name];
    }
    seen.set(name,json);
    if(n.type.endsWith('.respondToWebhook'))return {status:expression(n.parameters.options.responseCode,json,seen),
      body:expression(n.parameters.responseBody,json,seen),calls};
    name=target.connections[name]?.main[branch]?.[0]?.node;assert.ok(name,'unconnected branch');
  }
  throw Error('workflow did not terminate');
}
test('Iraqi phone input and unsupported purpose validation',()=>{
  for(const value of ['07501234567','٠٧٥٠١٢٣٤٥٦٧','+9647501234567','009647501234567'])assert.equal(c.normalizePhone(value),'+9647501234567');
  for(const value of ['https://evil.invalid','+1 555 555 5555',null,'75012345678'])assert.equal(c.normalizePhone(value),null);
  assert.equal(c.sendInput({phone:'7501234567',purpose:'marketing'}).httpStatus,400);
});
test('database denial, timeout and missing code never reach the paid provider',()=>{
  for(const response of [{statusCode:200,body:{success:false,error:'rate_limited',retry_after_seconds:60}},
    {statusCode:500,body:{secret:'must-not-leak'}},{error:'network failure'},
    {...reserve,body:{...reserve.body,code:undefined}}]){
    const r=run('Send webhook',{body:{phone:'7501234567'}},{'Reserve OTP':response});
    assert.equal(r.body.success,false);assert.equal(r.calls.length,1);
    assert.doesNotMatch(JSON.stringify(r.body),/secret|code|001234/);
  }
});
test('OTP flow pins the supplied authentication UUID and persists before success',()=>{
  const r=run('Send webhook',{body:{phone:'07501234567',purpose:'signup',clientMessageId:'untrusted'}},
    {'Reserve OTP':reserve,'Send OTP template':delivery,'Record delivery':{statusCode:200,body:{success:true}}});
  assert.equal(r.status,200);assert.equal(r.body.success,true);
  const payload=r.calls[1].body;assert.equal(payload.templateId,c.templates.otp);
  assert.equal(payload.to,'+9647501234567');assert.equal(payload.components[0].parameters[0].text,'001234');
  assert.equal(payload.components[1].parameters[0].text,'001234');
  assert.equal(payload.clientMessageId,reserve.body.client_message_id);
  assert.deepEqual(r.calls[2].body,{p_otp_id:uuid,p_send_count:1,p_message_id:'message-12345678',p_status:'queued'});
  assert.doesNotMatch(JSON.stringify(r.body),/001234|otp_id|components/);
});
test('delivery or storage failures cannot claim success or leak provider data',()=>{
  const failed=run('Send webhook',{body:{phone:'7501234567'}},{'Reserve OTP':reserve,
    'Send OTP template':{statusCode:403,body:{error:'SECRET upstream detail'}}});
  assert.equal(failed.body.success,false);assert.equal(failed.calls.length,2);
  assert.doesNotMatch(JSON.stringify(failed.body),/SECRET/);
  const store=run('Send webhook',{body:{phone:'7501234567'}},{'Reserve OTP':reserve,'Send OTP template':delivery,
    'Record delivery':{statusCode:500,body:{success:false}}});
  assert.equal(store.status,503);assert.equal(store.body.success,false);
});
test('raw verifier requires verified=true; success=true alone is insufficient',()=>{
  for(const verified of [false,true]){
    const r=run('Verify webhook',{body:{phone:'7501234567',code:'001234',purpose:'signup'}},
      {'Verify code':{statusCode:200,body:{success:true,data:{verified}}}});
    assert.equal(r.body.success,verified);assert.equal(r.calls[0].body.p_purpose,'signup');
  }
});
test('status output is allowlisted and cannot echo OTPs or personal data',()=>{
  const r=run('Status webhook',{query:{messageId:'message-12345678'}},
    {'Read delivery':{statusCode:200,body:{data:{status:'delivered',code:'001234',to:'+9647501234567'}}}});
  assert.deepEqual(r.body,{success:true,status:'delivered'});
});
test('account utility template needs a fresh requested signup; uses named customer_name',()=>{
  const request={userId:uuid,event:'account_created',confirmationRequested:true};
  assert.equal(c.accountInput({...request,confirmationRequested:false}).proceed,false);
  const now=Date.parse('2026-10-16T00:00:00Z');
  const user={id:uuid,phone:'9647501234567',phone_confirmed_at:'2026-10-16T00:00:00Z',
    created_at:'2026-10-16T00:00:00Z',user_metadata:{full_name:'Fixture User'}};
  const p=c.accountPayload({statusCode:200,body:user},request,now);
  assert.equal(p.payload.templateId,c.templates.account);
  assert.equal(p.payload.components[0].parameters[0].parameter_name,'customer_name');
  assert.equal(c.accountPayload({statusCode:200,body:user},request,now+3600000).proceed,false);
});
test('private endpoints and secrets are not exported as public capabilities',()=>{
  assert.equal(workflow.active,false);
  for(const n of workflow.nodes.filter(n=>n.type.endsWith('.webhook')&&n.name!=='Send webhook')){
    assert.equal(n.parameters.authentication,'headerAuth');assert.ok(n.credentials.httpHeaderAuth);
  }
  assert.equal(workflow.settings.saveDataSuccessExecution,'none');
  assert.doesNotMatch(JSON.stringify(workflow),/wvlx_[A-Za-z0-9]|eyJ[A-Za-z0-9_-]+\./);
});
test('configured import resolves every URL with no Variables and preserves OTP security',()=>{
  const expected={
    'Reserve OTP':'https://cojchkwssmasiejcgvbk.supabase.co/rest/v1/rpc/get_or_generate_otp_whatsapp',
    'Record delivery':'https://cojchkwssmasiejcgvbk.supabase.co/rest/v1/rpc/pa_finish_whatsapp_otp_send',
    'Verify code':'https://cojchkwssmasiejcgvbk.supabase.co/rest/v1/rpc/pa_verify_whatsapp_otp',
    'Read new account':`https://cojchkwssmasiejcgvbk.supabase.co/auth/v1/admin/users/${uuid}`,
    'Send OTP template':'https://api.wevlix.com/v1/messages/template',
    'Send account template':'https://api.wevlix.com/v1/messages/template',
    'Read delivery':'https://api.wevlix.com/v1/messages/message-12345678',
  };
  for(const n of configuredWorkflow.nodes.filter(n=>n.type.endsWith('.httpRequest'))){
    const raw=n.parameters.url;
    const resolved=raw.startsWith('={{')?expression(raw,{userId:uuid,messageId:'message-12345678'},new Map()):raw;
    assert.equal(resolved,expected[n.name]);
    assert.deepEqual(n.credentials,workflow.nodes.find(old=>old.name===n.name).credentials);
  }
  assert.equal(configuredWorkflow.active,false);
  assert.deepEqual(configuredWorkflow.settings,workflow.settings);
  assert.doesNotMatch(JSON.stringify(configuredWorkflow),/\$vars|wvlx_[A-Za-z0-9]|eyJ[A-Za-z0-9_-]+\./);
  const input={body:{phone:'07501234567',purpose:'login'}};
  const replies={'Reserve OTP':reserve,'Send OTP template':delivery,'Record delivery':{statusCode:200,body:{success:true}}};
  assert.deepEqual(run('Send webhook',input,replies,configuredWorkflow),run('Send webhook',input,replies));
  const stopped=run('Send webhook',input,{'Reserve OTP':{error:'database denied'}},configuredWorkflow);
  assert.equal(stopped.calls.length,1);
  assert.equal(stopped.body.success,false);
});
