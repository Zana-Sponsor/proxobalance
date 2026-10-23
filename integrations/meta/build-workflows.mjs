import {writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';

// Public origin only. Authentication is bound through n8n Credentials after import.
const suppliedOrigin=process.argv[2];
const validOrigin=value=>typeof value==='string'
  && /^https:\/\/(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$/.test(value)
  && !/\.(?:localhost|local|internal|invalid|test)$/.test(value);
if(process.argv.length>3 || (suppliedOrigin&&!validOrigin(suppliedOrigin)))
  throw new Error('Usage: node integrations/meta/build-workflows.mjs [https://public-backend-origin]');

const configSource=suppliedOrigin?JSON.stringify(suppliedOrigin):'$vars.PROXO_META_BACKEND_ORIGIN';
const workflows=[
  {key:'create',name:'Proxo Meta — create paused ads',op:'worker-create',minutes:1,
    description:'Claim one funded, eligible Meta order; recheck preflight and build a paused chain. No paid activation.'},
  {key:'status_sync',name:'Proxo Meta — status sync',op:'worker-status',minutes:5,
    description:'Observe provider review and delivery state for persisted Meta object IDs. Polling errors are not terminal failures.'},
  {key:'reconcile_refund',name:'Proxo Meta — reconcile and compensate',op:'worker-reconcile',minutes:2,
    description:'Reconcile unknown or partial outcomes and dispatch proven-safe compensation through the authenticated backend.'},
];

const resultCode=`// Keep only the application worker contract; never return raw headers or diagnostics.
const response=$json;
if(!response || response.error || !Number.isInteger(response.statusCode))
  throw new Error('META_WORKER_TRANSPORT_UNAVAILABLE');
if(response.statusCode===401 || response.statusCode===403)
  throw new Error('META_WORKER_AUTHORIZATION_FAILED');
if(response.statusCode===429 || response.statusCode>=500)
  throw new Error('META_WORKER_TEMPORARILY_UNAVAILABLE');
if(response.statusCode<200 || response.statusCode>=300)
  throw new Error('META_WORKER_REQUEST_REJECTED');
let body=response.body;
if(typeof body==='string') {
  try { body=JSON.parse(body); }
  catch { throw new Error('META_WORKER_INVALID_RESPONSE'); }
}
if(!body || body.ok!==true || ![0,1].includes(body.processed)
  || !['idle','paused','observed','reconcile','refunded'].includes(body.status))
  throw new Error('META_WORKER_INVALID_RESPONSE');
const result={ok:true,processed:body.processed,status:body.status};
if(typeof body.error_code==='string' && /^[A-Z][A-Z0-9_]{0,79}$/.test(body.error_code))
  result.error_code=body.error_code;
return {json:result};`;

for(const item of workflows){
  const configurationCode=`// Ignore trigger payloads. Orders and money are loaded by the authenticated backend.
const origin=${configSource};
if(typeof origin!=='string'
  || !/^https:\\/\\/(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$/.test(origin)
  || /\\.(?:localhost|local|internal|invalid|test)$/.test(origin))
  throw new Error('META_BACKEND_ORIGIN_NOT_CONFIGURED');
return {json:{url:origin+${JSON.stringify('/api/meta-ads?op='+item.op)}}};`;
  const nodes=[
    {id:`meta-${item.key}-schedule`,name:'Scheduled poll',type:'n8n-nodes-base.scheduleTrigger',typeVersion:1.2,
      position:[0,0],parameters:{rule:{interval:[{field:'minutes',minutesInterval:item.minutes}]}},
      notes:'Inactive until staged verification and the owner’s release rules allow activation.'},
    {id:`meta-${item.key}-manual`,name:'Controlled manual test',type:'n8n-nodes-base.manualTrigger',typeVersion:1,
      position:[0,200],parameters:{}},
    {id:`meta-${item.key}-configuration`,name:'Validate backend configuration',type:'n8n-nodes-base.code',typeVersion:2,
      position:[260,100],parameters:{mode:'runOnceForEachItem',jsCode:configurationCode}},
    {id:`meta-${item.key}-worker`,name:'Call authenticated worker',type:'n8n-nodes-base.httpRequest',typeVersion:4.2,
      position:[520,100],parameters:{method:'POST',url:'={{ $json.url }}',
        authentication:'genericCredentialType',genericAuthType:'httpHeaderAuth',
        sendBody:true,specifyBody:'json',jsonBody:'{}',
        options:{timeout:60000,redirect:{redirect:{followRedirects:false}},
          response:{response:{fullResponse:true,neverError:true,responseFormat:'text'}}}},
      credentials:{httpHeaderAuth:{name:'Proxo Meta worker'}},
      retryOnFail:true,maxTries:3,waitBetweenTries:5000,onError:'continueRegularOutput',
      notes:'Retries cover transport failures only. HTTP errors reach the sanitized result check. Durable leases and stage retries belong to the backend.'},
    {id:`meta-${item.key}-result`,name:'Check sanitized result',type:'n8n-nodes-base.code',typeVersion:2,
      position:[780,100],parameters:{mode:'runOnceForEachItem',jsCode:resultCode}},
  ];
  const edge=to=>({main:[[{node:to,type:'main',index:0}]]});
  const workflow={name:item.name,nodes,connections:{
    'Scheduled poll':edge('Validate backend configuration'),
    'Controlled manual test':edge('Validate backend configuration'),
    'Validate backend configuration':edge('Call authenticated worker'),
    'Call authenticated worker':edge('Check sanitized result'),
  },active:false,settings:{executionOrder:'v1',timezone:'Asia/Baghdad',executionTimeout:240,
    saveDataErrorExecution:'none',saveDataSuccessExecution:'none',saveManualExecutions:false,
    saveExecutionProgress:false},pinData:{},tags:[],meta:{templateCredsSetupCompleted:false},
    description:item.description};
  const path=fileURLToPath(new URL(`./proxo_meta_ads_${item.key}.json`,import.meta.url));
  writeFileSync(path,JSON.stringify(workflow,null,2)+'\n');
  console.log(`Wrote inactive ${item.key} workflow (${nodes.length} nodes).`);
}
