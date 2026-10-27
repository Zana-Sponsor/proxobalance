import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {legacyCheckoutContract} from '../integrations/legacy-fastpay/checkout-contract.mjs';
import {configureSandboxWorkflow,sandboxPublicConfiguration} from '../integrations/legacy-fastpay/build-patch.mjs';

const contract=legacyCheckoutContract();
const vars={PROXO_LEGACY_FASTPAY_ENVIRONMENT:'production',PROXO_LEGACY_FASTPAY_SUPABASE_URL:'https://abcdefghijklmnopqrst.supabase.co',PROXO_LEGACY_FASTPAY_PUBLIC_ORIGIN:'https://email.proxopages.com',PROXO_LEGACY_FASTPAY_MERCHANT_REFERENCE:'fixture-store'};
const config=contract.config(vars,true);
const user='11111111-1111-4111-8111-111111111111',tx='22222222-2222-4222-8222-222222222222';
const input={orderId:'PX123456789',userId:user,billAmount:10000,currency:'IQD',purpose:'wallet_deposit',note:'fixture',expiresIn:10};
const receipt={ok:true,create_authorized:true,must_reconcile:false,transaction_id:tx,user_id:user,order_id:input.orderId,amount_iqd:10000,currency:'IQD',wallet_credited:false,status:'pending',gateway_status:'CREATED',journaled:true,environment:'sandbox',merchant_reference:'fixture-store',request_hash:'a'.repeat(64),qr_url:null,qr_text:null,expires_at:new Date(Date.now()+600000).toISOString()};
const response=body=>({statusCode:200,body:JSON.stringify(body)});
const plain=v=>JSON.parse(JSON.stringify(v));
const publicConfiguration={supabaseUrl:vars.PROXO_LEGACY_FASTPAY_SUPABASE_URL,publicOrigin:vars.PROXO_LEGACY_FASTPAY_PUBLIC_ORIGIN,merchantReference:vars.PROXO_LEGACY_FASTPAY_MERCHANT_REFERENCE};
const template=()=>JSON.parse(fs.readFileSync(new URL('../integrations/legacy-fastpay/proxo_fastpay_durable_sandbox.json',import.meta.url),'utf8'));
const draft=()=>configureSandboxWorkflow(template(),publicConfiguration);
const node=(w,name)=>{const n=w.nodes.find(n=>n.name===name);assert(n,name);return n;};
const expr=(value,scope)=>vm.runInNewContext(`(${value.slice(3,-2).trim()})`,scope);
const run=(w,name,value,refs={})=>plain(vm.runInNewContext(`(function(){${node(w,name).parameters.jsCode}})()`,{$vars:vars,$input:{item:{json:value},all:()=>[{json:value}]},$:name=>({item:{json:refs[name]}})}))[0].json;

test('sandbox configuration rejects the main database and pins dedicated sandbox callbacks and returns',()=>{
  assert.equal(config.environment,'sandbox');assert.equal(config.baseUrl,'https://staging-qr.fast-pay.iq');
  for(const [key,suffix] of [['callbackUrl','ipn'],['successUrl','success'],['cancelUrl','cancel']])assert.equal(config[key],`https://email.proxopages.com/webhook/proxo-fastpay-staging/${suffix}`);
  for(const url of ['https://cojchkwssmasiejcgvbk.supabase.co','https://staging.internal','http://abcdefghijklmnopqrst.supabase.co','https://abcdefghijklmnopqrst.supabase.co:443','https://evil.example.com'])
    assert.throws(()=>contract.config({...vars,PROXO_LEGACY_FASTPAY_SUPABASE_URL:url},true));
  assert.throws(()=>contract.config({...vars,PROXO_LEGACY_FASTPAY_MERCHANT_REFERENCE:''},true));
  assert.throws(()=>contract.config({...vars,PROXO_LEGACY_FASTPAY_PUBLIC_ORIGIN:'https://www.proxobalance.app'},true));
});

test('unconfigured sandbox uses no paid Variables feature and fails closed before external requests',()=>{
  const w=template();
  assert.doesNotMatch(JSON.stringify(w),/\$(?:vars|env)\b/);
  assert.throws(()=>run(w,'FastPay Config',{}, {'Resolve Checkout Amount':input}),/LEGACY_FASTPAY_ORIGIN_INVALID/);
  assert.throws(()=>expr(node(w,'Legacy Reserve Checkout').parameters.url,{}),/LEGACY_FASTPAY_ORIGIN_INVALID/);
  assert.deepEqual(sandboxPublicConfiguration(),{PROXO_LEGACY_FASTPAY_SUPABASE_URL:'',PROXO_LEGACY_FASTPAY_PUBLIC_ORIGIN:'https://email.proxopages.com',PROXO_LEGACY_FASTPAY_MERCHANT_REFERENCE:''});
});

test('compile-time public configuration rejects secrets, production targets and incomplete files',()=>{
  for(const invalid of [null,[],{}, {...publicConfiguration,storePassword:'not-a-real-secret'},
    {...publicConfiguration,supabaseUrl:'https://cojchkwssmasiejcgvbk.supabase.co'},
    {...publicConfiguration,publicOrigin:'https://www.proxobalance.app'},
    {...publicConfiguration,merchantReference:''},
    {...publicConfiguration,merchantReference:'/* END_PROXO_FASTPAY_PUBLIC_CONFIG */'}])
    assert.throws(()=>configureSandboxWorkflow(template(),invalid));
  assert.throws(()=>configureSandboxWorkflow({...template(),active:true},publicConfiguration));
  const a=draft(),b=configureSandboxWorkflow(a,publicConfiguration);
  assert.deepEqual(a,b);
  const configured=run(a,'FastPay Config',{body:{supabaseUrl:'https://cojchkwssmasiejcgvbk.supabase.co',merchantReference:'forged'}},{'Resolve Checkout Amount':input});
  assert.equal(configured.supabaseUrl,publicConfiguration.supabaseUrl);
  assert.equal(configured.merchantReference,publicConfiguration.merchantReference);
});

test('reservation binds original owner/order/money and freezes only reviewed request fields',()=>{
  const value=contract.preparePayload(input,config);
  assert.deepEqual(Object.keys(value.p_payload).sort(),['amount_iqd','callback_url','cancel_url','currency','environment','expires_in','merchant_reference','note','purpose','success_url']);
  assert.equal(value.p_user_id,user);assert.equal(value.p_order_id,input.orderId);assert.equal(value.p_payload.amount_iqd,10000);
  for(const bad of [{orderId:'AP'+'a'.repeat(28)},{userId:'attacker'},{billAmount:NaN},{currency:'USD'},{expiresIn:2},{expiresIn:16},{purpose:'forged'}])
    assert.throws(()=>contract.preparePayload({...input,...bad},config));
});

test('only exact first durable authorization can dispatch and resumed attempts keep the original identity',()=>{
  assert.equal(contract.dispatch(response(receipt),input,config).createAuthorized,true);
  const recovered=contract.dispatch(response({...receipt,create_authorized:false,must_reconcile:true}),input,config);
  assert.equal(recovered.createAuthorized,false);assert.equal(recovered.orderId,input.orderId);
  for(const bad of [{create_authorized:'true'},{user_id:tx},{order_id:'PXother999'},{amount_iqd:20000},{environment:'production'},{merchant_reference:'changed'},{request_hash:null},{journaled:false},{wallet_credited:true},{gateway_status:'DECLINED'},{expires_at:'bad'},{qr_text:'pay-me'}])
    assert.throws(()=>contract.dispatch(response({...receipt,...bad}),input,config));
  for(const statusCode of [201,302,409,429,500])assert.throws(()=>contract.dispatch({...response(receipt),statusCode},input,config));
});

test('historical rows cannot silently inherit current merchant credentials and paid readback requires exact ledger fields',()=>{
  const expected={orderId:input.orderId,userId:user};
  assert.throws(()=>contract.binding(response({...receipt,create_authorized:false,must_reconcile:true,journaled:false,environment:null,merchant_reference:null,request_hash:null}),expected,config,false));
  const paid=contract.binding(response({...receipt,create_authorized:false,must_reconcile:false,status:'approved',gateway_status:'PAID',wallet_credited:true}),expected,config,false);
  assert.equal(contract.publicResult(paid).paid,true);assert.equal(contract.publicResult(paid).transactionId,tx);
  assert.equal(JSON.stringify(contract.publicResult(paid)).includes('fixture-store'),false);
});

test('generated checkout executes reservation before QR and replay takes only the recovery branch',()=>{
  const w=draft(),c=run(w,'FastPay Config',{}, {'Resolve Checkout Amount':input});
  const request=plain(expr(node(w,'Legacy Reserve Checkout').parameters.jsonBody,{$:()=>({item:{json:c}})}));
  assert.equal(request.p_action,'prepare');assert.equal(request.p_user_id,user);
  const authorized=run(w,'Legacy Dispatch Verified',response(receipt),{'FastPay Config':c});
  assert.equal(expr(node(w,'Legacy Dispatch Allowed?').parameters.conditions.conditions[0].leftValue,{$json:authorized}),true);
  const restored=run(w,'Legacy Restore Dispatch',authorized);
  const qr=plain(expr(node(w,'Generate QR').parameters.jsonBody,{$json:restored}));
  assert.equal(qr.orderId,input.orderId);assert.equal(qr.billAmount,10000);assert.equal(qr.callbackUrl,config.callbackUrl);
  const recovered=run(w,'Legacy Dispatch Verified',response({...receipt,create_authorized:false,must_reconcile:true}),{'FastPay Config':c});
  assert.equal(expr(node(w,'Legacy Dispatch Allowed?').parameters.conditions.conditions[0].leftValue,{$json:recovered}),false);
  assert.equal(w.connections['Legacy Dispatch Allowed?'].main[1][0].node,'Respond Legacy Checkout Recovery');
  const saved=plain(expr(node(w,'Create Pending Transaction (Supabase)').parameters.jsonBody,{$json:{qrUrl:'https://staging-qr.fast-pay.iq/q',qrText:'qr'},$:()=>({item:{json:authorized}})}));
  assert.equal(saved.p_action,'qr_created');assert.equal(saved.p_payload.request_hash,'a'.repeat(64));assert(!('p_amount' in saved));
});

test('generated graph requires isolation, durable intent and independent paid validation',()=>{
  const w=draft();
  function reachable(start,target,removed){const queue=[start],seen=new Set();while(queue.length){const n=queue.shift();if(n===removed||seen.has(n))continue;if(n===target)return true;seen.add(n);for(const out of w.connections[n]?.main||[])for(const next of out)queue.push(next.node);}return false;}
  for(const required of ['Legacy Checkout Order Guard','Legacy Reserve Checkout','Legacy Dispatch Verified','Legacy Dispatch Allowed?'])
    assert.equal(reachable('Order Create Webhook','Generate QR',required),false,required);
  for(const [start,target,required] of [['Get Status','Mark PAID from Poll (Supabase)','Legacy Poll Validation OK?'],['Check FastPay From App','Mark PAID From App (Supabase)','Legacy App Validation OK?'],['IPN Webhook','Mark PAID + Credit Wallet + Notify (Supabase)','Compare & Decide']])
    assert.equal(reachable(start,target,required),false,required);
  for(const name of ['Checkout','IPN','Poll','App Status','Refund'])assert(node(w,`Legacy ${name} Order Guard`));
  for(const n of w.nodes)if(n.type==='n8n-nodes-base.code')assert.doesNotThrow(()=>new vm.Script(`(function(){${n.parameters.jsCode}})`),n.name);
});

test('an unavailable poll item skips provider calls and the next bound item remains reconcilable',()=>{
  const w=draft(),row={user_id:user,fastpay_order_id:input.orderId,id:tx,gateway_amount:10000};
  assert.equal(node(w,'Legacy Poll Order Guard').onError,'continueRegularOutput');
  for(const invalid of [{error:'timeout'},{},{ok:true,legacy_allowed:true,immutable_ad_payment:true,code:'LEGACY_ALLOWED'}]){
    const failed=run(w,'Legacy Poll Guard Valid',invalid);
    assert.equal(failed.legacy_allowed,false);
    assert.equal(w.connections['Legacy Poll Allowed?'].main[1][0].node,'Loop Orders');
  }
  const allowed=run(w,'Legacy Poll Guard Valid',{ok:true,legacy_allowed:true,immutable_ad_payment:false,code:'LEGACY_ALLOWED'});
  assert.equal(allowed.legacy_allowed,true);
  assert.equal(w.connections['Legacy Poll Allowed?'].main[0][0].node,'Legacy Poll Restore Item');
  assert.equal(node(w,'Legacy Poll Read').onError,'continueRegularOutput');
  for(const invalid of [{error:'timeout'},response({...receipt,journaled:false,environment:null,merchant_reference:null}),response({...receipt,amount_iqd:20000})]){
    const failed=run(w,'Legacy Poll Binding',invalid,{'Loop Orders':row});
    assert.equal(failed.found,false);
    const accepted=expr(node(w,'Legacy Poll Binding OK?').parameters.conditions.conditions[0].leftValue,{$json:failed});
    assert.equal(accepted,false);assert.equal(w.connections['Legacy Poll Binding OK?'].main[1][0].node,'Loop Orders');
  }
  const next=run(w,'Legacy Poll Binding',response({...receipt,create_authorized:false,must_reconcile:true}),{'Loop Orders':row});
  assert.equal(next.found,true);assert.equal(w.connections['Legacy Poll Binding OK?'].main[0][0].node,'FastPay Config3');
});

test('inactive export has isolated targets, unbound credentials and disabled refund/notification routes',()=>{
  const w=draft();assert.equal(w.active,false);
  for(const key of ['id','versionId','activeVersionId','meta','pinData','staticData','tags'])assert.equal(w[key],undefined);
  assert.equal(w.settings.saveDataSuccessExecution,'none');assert.equal(w.settings.saveDataErrorExecution,'none');assert.equal(w.settings.saveManualExecutions,false);
  for(const n of w.nodes){
    for(const c of Object.values(n.credentials||{})){assert.equal(c.id,null);assert.match(c.name,/^UNCONFIGURED — /);}
    if(n.type==='n8n-nodes-base.telegram'){assert.equal(n.disabled,true);assert.equal(n.parameters.chatId,'UNCONFIGURED');}
    if(/refund/i.test(n.name))assert.equal(n.disabled,true,n.name);
    if(n.type==='n8n-nodes-base.webhook')assert.match(n.parameters.path,/^proxo-fastpay-staging\//);
    if(n.type==='n8n-nodes-base.httpRequest'){
      assert.equal(n.parameters.options.redirect.redirect.followRedirects,false,n.name);assert.equal(n.retryOnFail,false,n.name);
      if(n.parameters.url.includes('.supabaseUrl')){
        const url=expr(n.parameters.url,{});assert.match(url,/^https:\/\/abcdefghijklmnopqrst\.supabase\.co\//,n.name);
        assert.equal(expr(n.parameters.url,{$vars:{...vars,PROXO_LEGACY_FASTPAY_SUPABASE_URL:'https://cojchkwssmasiejcgvbk.supabase.co'}}),url,n.name+' must ignore runtime Variables');
      }
    }
  }
  for(const route of ['success','cancel'])assert(node(w,`Sandbox ${route} Return`));
});
