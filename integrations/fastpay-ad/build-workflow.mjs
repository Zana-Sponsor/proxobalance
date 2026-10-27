import {writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';

// Only a public origin may be embedded; authentication lives in n8n Credentials.
const suppliedOrigin=process.argv[2];
const validOrigin=value=>typeof value==='string'
  && /^https:\/\/(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$/.test(value)
  && !/\.(?:localhost|local|internal|invalid|test)$/.test(value);
if(process.argv.length>3 || (suppliedOrigin&&!validOrigin(suppliedOrigin)))
  throw new Error('Usage: node integrations/fastpay-ad/build-workflow.mjs [https://public-backend-origin]');
const source=suppliedOrigin?JSON.stringify(suppliedOrigin):'$vars.PROXO_AD_PAYMENTS_BACKEND_ORIGIN';
const configurationCode=`// Polling cannot select a customer, attempt, amount or verification result.
const origin=${source};
if(typeof origin!=='string'
  || !/^https:\\/\\/(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$/.test(origin)
  || /\\.(?:localhost|local|internal|invalid|test)$/.test(origin))
  throw new Error('FASTPAY_AD_BACKEND_ORIGIN_NOT_CONFIGURED');
return {json:{origin}};`;
const resultCode=`// No gateway response, customer record, transaction ID or credential is retained.
const response=$json;
if(!response || response.error || !Number.isInteger(response.statusCode))
  throw new Error('FASTPAY_AD_WORKER_TRANSPORT_UNAVAILABLE');
if(response.statusCode===401 || response.statusCode===403)
  throw new Error('FASTPAY_AD_WORKER_AUTHORIZATION_FAILED');
if(response.statusCode===429 || response.statusCode>=500)
  throw new Error('FASTPAY_AD_WORKER_TEMPORARILY_UNAVAILABLE');
if(response.statusCode<200 || response.statusCode>=300)
  throw new Error('FASTPAY_AD_WORKER_REQUEST_REJECTED');
let body=response.body;
if(typeof body==='string'){
  try{body=JSON.parse(body);}catch{throw new Error('FASTPAY_AD_WORKER_INVALID_RESPONSE');}
}
if(!body || body.ok!==true || ![0,1].includes(body.processed)
  || !['idle','pending','funded','compensated','reconcile'].includes(body.status))
  throw new Error('FASTPAY_AD_WORKER_INVALID_RESPONSE');
const result={ok:true,processed:body.processed,status:body.status};
if(typeof body.error_code==='string' && /^[A-Z][A-Z0-9_]{0,99}$/.test(body.error_code))result.error_code=body.error_code;
return {json:result};`;
const nodes=[
  {id:'fastpay-ad-reconcile-schedule',name:'Scheduled poll',type:'n8n-nodes-base.scheduleTrigger',typeVersion:1.2,
    position:[0,0],parameters:{rule:{interval:[{field:'minutes',minutesInterval:1}]}},
    notes:'Keep inactive until private backend configuration and controlled verification are complete.'},
  {id:'fastpay-ad-reconcile-manual',name:'Controlled manual test',type:'n8n-nodes-base.manualTrigger',typeVersion:1,
    position:[0,200],parameters:{}},
  {id:'fastpay-ad-reconcile-config',name:'Validate backend configuration',type:'n8n-nodes-base.code',typeVersion:2,
    position:[240,100],parameters:{mode:'runOnceForEachItem',jsCode:configurationCode}},
  {id:'fastpay-ad-reconcile-http',name:'Poll trusted payment reconciliation',type:'n8n-nodes-base.httpRequest',typeVersion:4.2,
    position:[480,100],parameters:{method:'POST',
      url:"={{ $('Validate backend configuration').item.json.origin + '/api/meta-ads?platform=payments&op=worker-reconcile' }}",
      authentication:'genericCredentialType',genericAuthType:'httpHeaderAuth',sendBody:true,specifyBody:'json',jsonBody:'{}',
      options:{timeout:60000,redirect:{redirect:{followRedirects:false}},
        response:{response:{fullResponse:true,neverError:true,responseFormat:'text'}}}},
    credentials:{httpHeaderAuth:{id:null,name:'UNCONFIGURED — Proxo FastPay ad worker'}},retryOnFail:true,maxTries:3,waitBetweenTries:5000,onError:'continueRegularOutput',
    notes:'Only transport failures retry. The backend claims a durable lease, independently verifies FastPay, and commits payment idempotently. It never creates a QR here.'},
  {id:'fastpay-ad-reconcile-check',name:'Check reconciliation result',type:'n8n-nodes-base.code',typeVersion:2,
    position:[720,100],parameters:{mode:'runOnceForEachItem',jsCode:resultCode}},
];
const edge=node=>({main:[[{node,type:'main',index:0}]]});
const workflow={name:'Proxo FastPay — immutable ad payment reconciliation',active:false,nodes,
  connections:{'Scheduled poll':edge('Validate backend configuration'),'Controlled manual test':edge('Validate backend configuration'),
    'Validate backend configuration':edge('Poll trusted payment reconciliation'),'Poll trusted payment reconciliation':edge('Check reconciliation result')},
  settings:{executionOrder:'v1',timezone:'Asia/Baghdad',executionTimeout:240,saveDataErrorExecution:'none',
    saveDataSuccessExecution:'none',saveManualExecutions:false,saveExecutionProgress:false},
  pinData:{},tags:[],meta:{templateCredsSetupCompleted:false},
  description:'Reconcile persisted immutable Meta/TikTok FastPay attempts through a private backend. No caller-supplied verification, QR creation, gateway refund or provider activation.'};
writeFileSync(fileURLToPath(new URL('./proxo_fastpay_ad_reconcile.json',import.meta.url)),JSON.stringify(workflow,null,2)+'\n');
console.log('Wrote inactive proxo_fastpay_ad_reconcile.json (5 nodes).');
