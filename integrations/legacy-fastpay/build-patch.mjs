/** Offline patch/export builder. Never imports, activates or executes n8n. */
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {prepareFastPayPatch,applyReviewedPatch} from '../legacy-isolation/prepare-patches.mjs';
import {legacyCheckoutContract} from './checkout-contract.mjs';
import {legacyProviderContract} from './contracts.mjs';
import {patchVerification} from './verification-patch.mjs';

const clone=v=>structuredClone(v),hash=v=>createHash('sha256').update(JSON.stringify(v)).digest('hex');
const edge=node=>({node,type:'main',index:0});
const main=(...names)=>({main:names.map(name=>[edge(name)])});
const pointer=v=>v.replace(/~/g,'~0').replace(/\//g,'~1');
const checkout=`(${legacyCheckoutContract.toString()})()`;
const provider=`(${legacyProviderContract.toString()})()`;
const cfg=`${checkout}.config($vars, false)`;
const sqlUrl=path=>`={{ ${cfg}.supabaseUrl + ${JSON.stringify(path)} }}`;
const body=code=>`={{ ${code} }}`;
const credential={httpCustomAuth:{id:null,name:'UNCONFIGURED — Proxo legacy FastPay Supabase service'}};
const responseOptions={timeout:15000,redirect:{redirect:{followRedirects:false}},response:{response:{fullResponse:true,neverError:true,responseFormat:'text'}}};
function find(w,name){const all=w.nodes.filter(n=>n.name===name);assert.equal(all.length,1,`Expected one reviewed node ${name}`);return all[0];}
function add(w,name,type,parameters,extra={}){
  assert(!w.nodes.some(n=>n.name===name),`Duplicate node ${name}`);
  const n={id:`legacy-durable-${hash(name).slice(0,24)}`,name,type:`n8n-nodes-base.${type}`,typeVersion:{code:2,httpRequest:4.2,if:2.2,respondToWebhook:1.1,webhook:2}[type]||1,position:[1800,7000+w.nodes.length*30],parameters,...extra};w.nodes.push(n);return n;
}
function code(w,name,jsCode){return add(w,name,'code',{jsCode});}
function condition(w,name,expression){return add(w,name,'if',{conditions:{options:{caseSensitive:true,typeValidation:'strict',version:2},conditions:[{id:hash(name).slice(0,16),leftValue:expression,rightValue:true,operator:{type:'boolean',operation:'true'}}],combinator:'and'},options:{}});}
function rpc(w,name,request){return add(w,name,'httpRequest',{method:'POST',url:sqlUrl('/rest/v1/rpc/pa_legacy_fastpay_checkout'),authentication:'genericCredentialType',genericAuthType:'httpCustomAuth',sendHeaders:true,headerParameters:{parameters:[{name:'Content-Type',value:'application/json'},{name:'Accept',value:'application/json'}]},sendBody:true,specifyBody:'json',jsonBody:request,options:clone(responseOptions)},{credentials:clone(credential),retryOnFail:false,onError:'stopWorkflow'});}
function replaceCode(w,name,jsCode){const n=find(w,name);n.type='n8n-nodes-base.code';n.typeVersion=2;n.parameters={jsCode};}
function strictIf(w,name,expression){const n=find(w,name);n.parameters={conditions:{options:{caseSensitive:true,typeValidation:'strict',version:2},conditions:[{id:hash(name).slice(0,16),leftValue:expression,rightValue:true,operator:{type:'boolean',operation:'true'}}],combinator:'and'},options:{}};}
function readBody(owner,order){return body(`({p_action:'read',p_user_id:${owner},p_order_id:${order},p_payload:{}})`);}

export function patchCheckout(source) {
  const w=clone(source);
  assert.deepEqual(w.connections['FastPay Config']?.main?.[0],[edge('Generate QR')],'Checkout route drifted');
  assert.deepEqual(w.connections['QR Success?']?.main?.[0],[edge('Create Pending Transaction (Supabase)')],'QR persistence route drifted');
  assert.deepEqual(w.connections['Resolve Checkout Amount']?.main?.[0],[edge('FastPay Config')],'Resolved quote route drifted');
  // The existing quote branch and owner lookup stay before this boundary.
  replaceCode(w,'FastPay Config',`const cfg=${cfg}; const c=$('Resolve Checkout Amount').item.json;
const checkout={...c,expiresIn:10}; const request=${checkout}.preparePayload(checkout,cfg);
return [{json:{...checkout,...cfg,request}}];`);
  rpc(w,'Legacy Reserve Checkout',body(`$('FastPay Config').item.json.request`));
  code(w,'Legacy Dispatch Verified',`const c=$('FastPay Config').item.json; return [{json:${checkout}.dispatch($input.item.json,c,c)}];`);
  condition(w,'Legacy Dispatch Allowed?',body('$json.createAuthorized === true'));
  code(w,'Legacy Restore Dispatch',`const b=$input.item.json;if(b.createAuthorized!==true)throw new Error('LEGACY_FASTPAY_DISPATCH_REQUIRED');
return [{json:{...b,billAmount:b.amountIqd}}];`);
  add(w,'Respond Legacy Checkout Recovery','respondToWebhook',{respondWith:'json',responseBody:body(`${checkout}.publicResult($json)`),options:{responseCode:200}});
  w.connections['FastPay Config']=main('Legacy Reserve Checkout');
  w.connections['Legacy Reserve Checkout']=main('Legacy Dispatch Verified');
  w.connections['Legacy Dispatch Verified']=main('Legacy Dispatch Allowed?');
  w.connections['Legacy Dispatch Allowed?']=main('Legacy Restore Dispatch','Respond Legacy Checkout Recovery');
  w.connections['Legacy Restore Dispatch']=main('Generate QR');
  const qr=find(w,'Generate QR');qr.parameters.options=clone(responseOptions);qr.retryOnFail=false;qr.onError='stopWorkflow';
  // Preserve the provider's reviewed field names, but source all money and
  // identity from the durable authorization rather than the webhook body.
  qr.parameters.jsonBody=body(`({orderId:$json.orderId,billAmount:$json.amountIqd,currency:$json.currency,successUrl:$json.successUrl,cancelUrl:$json.cancelUrl,callbackUrl:$json.callbackUrl,expiresIn:$json.expiresIn})`);
  replaceCode(w,'Parse QR Response',`try { return [{json:${provider}.qr($input.item.json,$('Legacy Dispatch Verified').item.json)}]; }
catch {return [{json:{ok:false,code:'FASTPAY_QR_UNVERIFIED'}}];}`);
  strictIf(w,'QR Success?',body('$json.ok === true'));
  const save=find(w,'Create Pending Transaction (Supabase)');save.parameters={...save.parameters,url:sqlUrl('/rest/v1/rpc/pa_legacy_fastpay_checkout'),jsonBody:body(`({p_action:'qr_created',p_user_id:$('Legacy Dispatch Verified').item.json.userId,p_order_id:$('Legacy Dispatch Verified').item.json.orderId,p_payload:{request_hash:$('Legacy Dispatch Verified').item.json.requestHash,qr_url:$json.qrUrl,qr_text:$json.qrText}})`),options:clone(responseOptions)};
  save.retryOnFail=false;save.onError='stopWorkflow';delete save.maxTries;delete save.waitBetweenTries;
  save.notes='Attach verified QR to the original reserved receipt. Never recreates or refreshes the checkout.';
  code(w,'Legacy Saved Checkout',`const b=$('Legacy Dispatch Verified').item.json;return [{json:${checkout}.binding($input.item.json,b,b)}];`);
  w.connections[save.name]=main('Legacy Saved Checkout');w.connections['Legacy Saved Checkout']=main('Transaction Saved?');
  strictIf(w,'Transaction Saved?',body('$json.tx.ok === true'));
  find(w,'Respond QR Success').parameters.responseBody=body(`${checkout}.publicResult($json)`);
  rpc(w,'Legacy QR Outcome Unknown',body(`({p_action:'unknown',p_user_id:$('Legacy Dispatch Verified').item.json.userId,p_order_id:$('Legacy Dispatch Verified').item.json.orderId,p_payload:{request_hash:$('Legacy Dispatch Verified').item.json.requestHash,error_code:'FASTPAY_QR_UNVERIFIED'}})`));
  w.connections['QR Success?'].main[1]=[edge('Legacy QR Outcome Unknown')];w.connections['Legacy QR Outcome Unknown']=main('Respond QR Error');
  find(w,'Respond QR Error').parameters.responseBody=body(`({success:false,recoveryRequired:true,code:'FASTPAY_QR_UNVERIFIED'})`);

  // Every reconciliation call reads the same frozen environment/merchant first.
  // Unknown pre-journal receipts cannot silently inherit current credentials.
  code(w,'Legacy IPN Identity',`const a=$input.all().flatMap(i=>Array.isArray(i.json)?i.json:[i.json]).filter(r=>r&&r.id);
const orderId=$('Extract IPN Data').item.json.merchant_order_id;
if(a.length!==1||a[0].fastpay_order_id!==orderId)return [{json:{found:false}}];
return [{json:{found:true,userId:a[0].user_id,orderId,transactionId:a[0].id}}];`);
  condition(w,'Legacy IPN Row Found?',body('$json.found === true'));
  rpc(w,'Legacy IPN Read',readBody(`$('Legacy IPN Identity').item.json.userId`,`$('Legacy IPN Identity').item.json.orderId`));
  code(w,'Legacy IPN Binding',`return [{json:${checkout}.binding($input.item.json,$('Legacy IPN Identity').item.json,${cfg},false)}];`);
  // The immutable guard must run before a database lookup/provider request.
  w.connections['Legacy IPN Allowed?'].main[0]=[edge('Get Transaction (Supabase)')];
  find(w,'Get Transaction (Supabase)').alwaysOutputData=true;
  w.connections['Get Transaction (Supabase)']=main('Legacy IPN Identity');
  w.connections['Legacy IPN Identity']=main('Legacy IPN Row Found?');
  w.connections['Legacy IPN Row Found?']=main('Legacy IPN Read','Ack IPN (Not Matched)');
  w.connections['Legacy IPN Read']=main('Legacy IPN Binding');w.connections['Legacy IPN Binding']=main('FastPay Config2');
  w.connections['Validate Payment']=main('Compare & Decide');
  rpc(w,'Legacy Poll Read',readBody(`$('Loop Orders').item.json.user_id`,`$('Loop Orders').item.json.fastpay_order_id`));
  code(w,'Legacy Poll Binding',`try {const r=$('Loop Orders').item.json;return [{json:${checkout}.binding($input.item.json,{userId:r.user_id,orderId:r.fastpay_order_id,transactionId:r.id,amountIqd:r.gateway_amount},${cfg})}];}
catch {return [{json:{found:false,code:'LEGACY_FASTPAY_BINDING_UNAVAILABLE'}}];}`);
  condition(w,'Legacy Poll Binding OK?',body('$json.found === true'));
  w.connections['Legacy Poll Restore Item']=main('Legacy Poll Read');w.connections['Legacy Poll Read']=main('Legacy Poll Binding');
  w.connections['Legacy Poll Binding']=main('Legacy Poll Binding OK?');w.connections['Legacy Poll Binding OK?']=main('FastPay Config3','Loop Orders');
  const app=find(w,'Get App Payment (Supabase)');
  app.parameters={method:'POST',url:sqlUrl('/rest/v1/rpc/pa_legacy_fastpay_checkout'),authentication:'genericCredentialType',genericAuthType:'httpCustomAuth',sendHeaders:true,headerParameters:{parameters:[{name:'Content-Type',value:'application/json'},{name:'Accept',value:'application/json'}]},sendBody:true,specifyBody:'json',jsonBody:readBody(`$('Verify Status User').item.json.id`,`$('Validate Status Request').item.json.orderId`),options:clone(responseOptions)};
  app.retryOnFail=false;app.onError='stopWorkflow';
  replaceCode(w,'Normalize App Payment',`return [{json:${checkout}.binding($input.item.json,{userId:$('Verify Status User').item.json.id,orderId:$('Validate Status Request').item.json.orderId},${cfg},false)}];`);
  for(const [name,binding] of [['FastPay Config2','Legacy IPN Binding'],['FastPay Config3','Legacy Poll Binding'],['FastPay App Status Config','Normalize App Payment']])
    replaceCode(w,name,`const b=$(${JSON.stringify(binding)}).item.json;return [{json:{baseUrl:b.baseUrl,orderId:b.orderId}}];`);
  replaceCode(w,'Extract IPN Data',`const raw=$input.item.json.body||$input.item.json;const b=typeof raw==='string'?JSON.parse(raw):raw;
if(!b||typeof b.merchant_order_id!=='string'||!/^[A-Za-z0-9_-]{8,32}$/.test(b.merchant_order_id))throw new Error('INVALID_IPN_HINT');
return [{json:{merchant_order_id:b.merchant_order_id}}];`);
  // Keep all old routes on the explicitly selected database and disable HTTP
  // redirect/retry surprises. An unknown status never reaches provider credit.
  for(const n of w.nodes){
    if(n.type!=='n8n-nodes-base.httpRequest')continue;
    const url=n.parameters.url;
    if(typeof url==='string'&&url.startsWith('https://cojchkwssmasiejcgvbk.supabase.co/'))n.parameters.url=sqlUrl(url.slice('https://cojchkwssmasiejcgvbk.supabase.co'.length));
    if(typeof url==='string'&&url.includes('$env.PROXO_SUPABASE_URL'))n.parameters.url=sqlUrl('/rest/v1/rpc/pa_legacy_fastpay_guard');
    if(n.name.endsWith('Order Guard'))n.credentials=clone(credential);
    n.parameters.options={...n.parameters.options,timeout:15000,redirect:{redirect:{followRedirects:false}}};
    n.retryOnFail=false;n.onError='stopWorkflow';delete n.maxTries;delete n.waitBetweenTries;
  }
  // Auth endpoint responses keep their existing JSON shape, with HTTP failures
  // rejected by the transport instead of being accepted as user objects.
  for(const name of ['Verify App User','Verify Status User']){
    const n=find(w,name);n.parameters.options.response={response:{neverError:false,responseFormat:'json'}};
  }
  // A single unavailable/historical item must not abandon the rest of a batch.
  // Its failed binding returns to Loop Orders without contacting the provider.
  find(w,'Legacy Poll Read').onError='continueRegularOutput';
  find(w,'Legacy Poll Order Guard').onError='continueRegularOutput';
  const pollGuard=find(w,'Legacy Poll Guard Valid');
  pollGuard.parameters.jsCode=`try {${pollGuard.parameters.jsCode}} catch {
return [{json:{ok:false,legacy_allowed:false,immutable_ad_payment:false,code:'LEGACY_FASTPAY_GUARD_UNAVAILABLE'}}];
}`;
  return w;
}

export function prepareDurablePatch(source) {
  const isolated=applyReviewedPatch(source,prepareFastPayPatch(source));
  const patched=patchCheckout(isolated);patchVerification(patched);
  const operations=[];
  for(let i=0;i<source.nodes.length;i++){
    assert.equal(source.nodes[i].name,patched.nodes[i].name,'Original node order changed');
    if(JSON.stringify(source.nodes[i])!==JSON.stringify(patched.nodes[i])){
      const original=source.nodes[i],updated=patched.nodes[i];
      operations.push({op:'test',path:`/nodes/${i}/name`,value:original.name});
      for(const key of new Set([...Object.keys(original),...Object.keys(updated)])){
        if(key==='credentials'||key==='name'||JSON.stringify(original[key])===JSON.stringify(updated[key]))continue;
        // Omitted retry metadata is inert after retryOnFail=false. Retain it in
        // the RFC6902 patch rather than use unsupported removal operations.
        if(updated[key]===undefined)continue;
        operations.push({op:original[key]===undefined?'add':'replace',path:`/nodes/${i}/${pointer(key)}`,value:clone(updated[key])});
      }
    }
  }
  for(const n of patched.nodes.slice(source.nodes.length))operations.push({op:'add',path:'/nodes/-',value:clone(n)});
  for(const [name,connection] of Object.entries(patched.connections))if(JSON.stringify(source.connections[name])!==JSON.stringify(connection))operations.push({op:source.connections[name]?'replace':'add',path:`/connections/${pointer(name)}`,value:clone(connection)});
  const patch={kind:'legacy-fastpay-durable-checkout-and-verification',source_name:source.name,source_sha256:hash(source),source_active:source.active,
    apply_to:'Offline review only. Drain old executions and configure an isolated sandbox before any import.',changes_activation:false,operations};
  const verified=applyReviewedPatch(source,patch);
  assert.equal(verified.active,source.active);
  return patch;
}

export function inactiveSandboxWorkflow(patched) {
  const w=clone(patched);
  for(const key of ['id','versionId','activeVersionId','meta','pinData','staticData','tags','createdAt','updatedAt','versionCounter','triggerCount','shared'])delete w[key];
  w.name='Proxo legacy FastPay durable sandbox — INACTIVE';w.active=false;
  w.settings={executionOrder:'v1',saveDataSuccessExecution:'none',saveDataErrorExecution:'none',saveManualExecutions:false,saveExecutionProgress:false};
  for(const n of w.nodes){
    delete n.webhookId;delete n.credentials;delete n.notes;delete n.notesInFlow;
    // Every configuration expression is validated in sandbox-only mode.
    n.parameters=JSON.parse(JSON.stringify(n.parameters).replaceAll('.config($vars, false)','.config($vars, true)'));
    if(n.type==='n8n-nodes-base.stickyNote')n.parameters={content:'Offline sandbox draft. Configure isolated database, merchant credentials and callback before controlled testing. Never use production credentials.'};
    if(n.type==='n8n-nodes-base.telegram'||/refund/i.test(n.name))n.disabled=true;
    if(n.type==='n8n-nodes-base.telegram')n.parameters={chatId:'UNCONFIGURED',text:'Disabled sandbox notification',additionalFields:{}};
    if(n.type==='n8n-nodes-base.webhook'&&typeof n.parameters.path==='string')n.parameters.path=n.parameters.path.replace(/^fastpay\//,'proxo-fastpay-staging/');
    if(n.name==='FastPay Config4'){
      const values=n.parameters.assignments?.assignments||[];for(const a of values)if(a.name==='baseUrl')a.value='=https://staging-qr.fast-pay.iq';
    }
    const type=n.parameters.genericAuthType||(n.parameters.authentication==='headerAuth'?'httpHeaderAuth':null);
    if(type){
      const scope=/refund/i.test(n.name)?'disabled refund':n.type==='n8n-nodes-base.webhook'?'disabled webhook':/auth\/v1\/user/.test(n.parameters.url||'')?'Supabase publishable key':/vending\//.test(n.parameters.url||'')?'sandbox merchant':'Supabase service';
      n.credentials={[type]:{id:null,name:`UNCONFIGURED — Proxo legacy FastPay ${scope}`}};
    }
  }
  for(const route of ['success','cancel']){
    const from=`Sandbox ${route} Return`,to=`Sandbox ${route} Acknowledgment`;
    add(w,from,'webhook',{httpMethod:'GET',path:`proxo-fastpay-staging/${route}`,responseMode:'responseNode',options:{}});
    add(w,to,'respondToWebhook',{respondWith:'text',responseBody:'Return to Proxo to check your payment. This redirect does not confirm payment.',options:{responseCode:200}});
    w.connections[from]=main(to);
  }
  // Explicit markers prevent n8n from automatically selecting a credential.
  const text=JSON.stringify(w);
  assert(!/"id":"[^"\s]+","name":"UNCONFIGURED/.test(text));
  return w;
}

if(process.argv[1]===fileURLToPath(import.meta.url)){
  const [input,output,...extra]=process.argv.slice(2);assert(input&&output&&!extra.length,'Usage: build-patch.mjs SNAPSHOT_JSON OUTPUT_DIRECTORY');
  const source=JSON.parse(await fs.readFile(input,'utf8'));
  const patch=prepareDurablePatch(source),draft=inactiveSandboxWorkflow(applyReviewedPatch(source,patch));
  await fs.mkdir(output,{recursive:true});
  await fs.writeFile(`${output}/reviewed-durable-patch.json`,JSON.stringify({live_mutations:false,patch},null,2)+'\n');
  await fs.writeFile(`${output}/proxo_fastpay_durable_sandbox.json`,JSON.stringify(draft,null,2)+'\n');
  console.log(`Prepared ${draft.nodes.length} inactive sandbox nodes; no live workflow or payment request.`);
}
