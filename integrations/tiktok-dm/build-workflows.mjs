import {writeFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';

// Only a public backend origin may be embedded. Authentication remains in Credentials.
const suppliedOrigin=process.argv[2];
const validOrigin=value=>typeof value==='string'
  && /^https:\/\/(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$/.test(value)
  && !/\.(?:localhost|local|internal|invalid|test)$/.test(value);
if(process.argv.length>3 || (suppliedOrigin&&!validOrigin(suppliedOrigin)))
  throw new Error('Usage: node integrations/tiktok-dm/build-workflows.mjs [https://public-backend-origin]');

const configurationSource=suppliedOrigin?JSON.stringify(suppliedOrigin):'$vars.PROXO_TIKTOK_DM_BACKEND_ORIGIN';
const definitions=[
  {file:'proxo_tiktok_account_connect',name:'Proxo TikTok — account connection',minutes:2,
    operations:['worker-account-connect'],description:'Process persisted owner-bound connection requests. Unsupported authorization correlation returns a blocked result; no fabricated QR or verified identity.'},
  {file:'proxo_tiktok_account_videos',name:'Proxo TikTok — account videos',minutes:15,
    operations:['worker-account-videos'],description:'Refresh due server-owned verified identity video caches through authenticated backend reads; no caller-selected identity.'},
  {file:'proxo_tiktok_account_disconnect',name:'Proxo TikTok — account disconnection',minutes:1,
    operations:['worker-account-disconnect'],description:'Claim only persisted owner-authorized disconnect requests, reconcile official advertiser unlink, and preserve history.'},
  {file:'proxo_tiktok_conversation_fulfill',name:'Proxo TikTok — Conversation fulfillment',minutes:1,
    operations:['worker-create'],description:'Claim only funded tiktok_conversation_auto jobs. Verify account, item, targeting, spend guard and pricing before constructing a paused provider chain.'},
  {file:'proxo_tiktok_conversation_spend_guard',name:'Proxo TikTok — Conversation spend guard',minutes:1,
    operations:['worker-budget'],description:'Observe authoritative spend and enforce the stored 95% early-stop policy through the backend. Never reactivate or charge an overrun.'},
  {file:'proxo_tiktok_status_metrics_sync',name:'Proxo TikTok — status, metrics and final reconciliation',minutes:2,
    operations:['worker-status','worker-reconcile','worker-refund'],description:'Sync provider state, reconcile partial/unknown outcomes, then process eligible final-spend refunds. The server enforces the two-hour minimum and authoritative settled spend.'},
];

const configurationCode=`// Scheduled input cannot select a user, identity, order, spend or refund amount.
const origin=${configurationSource};
if(typeof origin!=='string'
  || !/^https:\\/\\/(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$/.test(origin)
  || /\\.(?:localhost|local|internal|invalid|test)$/.test(origin))
  throw new Error('TIKTOK_DM_BACKEND_ORIGIN_NOT_CONFIGURED');
return {json:{origin}};`;

const resultCode=`// Do not return authorization URLs, provider payloads, headers or customer records.
const response=$json;
if(!response || response.error || !Number.isInteger(response.statusCode))
  throw new Error('TIKTOK_DM_WORKER_TRANSPORT_UNAVAILABLE');
if(response.statusCode===401 || response.statusCode===403)
  throw new Error('TIKTOK_DM_WORKER_AUTHORIZATION_FAILED');
if(response.statusCode===429 || response.statusCode>=500)
  throw new Error('TIKTOK_DM_WORKER_TEMPORARILY_UNAVAILABLE');
if(response.statusCode<200 || response.statusCode>=300)
  throw new Error('TIKTOK_DM_WORKER_REQUEST_REJECTED');
let body=response.body;
if(typeof body==='string') {
  try { body=JSON.parse(body); }
  catch { throw new Error('TIKTOK_DM_WORKER_INVALID_RESPONSE'); }
}
if(!body || body.ok!==true || ![0,1].includes(body.processed)
  || !['idle','blocked','paused','observed','reconcile','refunded','connected','disconnected','videos_ready','guarded','refreshed','revoked'].includes(body.status))
  throw new Error('TIKTOK_DM_WORKER_INVALID_RESPONSE');
const result={ok:true,processed:body.processed,status:body.status};
if(typeof body.error_code==='string' && /^[A-Z][A-Z0-9_]{0,99}$/.test(body.error_code))
  result.error_code=body.error_code;
return {json:result};`;

const edge=to=>({main:[[{node:to,type:'main',index:0}]]});
for(const definition of definitions){
  const nodes=[
    {id:`${definition.file}-schedule`,name:'Scheduled poll',type:'n8n-nodes-base.scheduleTrigger',typeVersion:1.2,
      position:[0,0],parameters:{rule:{interval:[{field:'minutes',minutesInterval:definition.minutes}]}},
      notes:'Keep inactive until target configuration and controlled verification are complete.'},
    {id:`${definition.file}-manual`,name:'Controlled manual test',type:'n8n-nodes-base.manualTrigger',typeVersion:1,
      position:[0,200],parameters:{}},
    {id:`${definition.file}-configuration`,name:'Validate backend configuration',type:'n8n-nodes-base.code',typeVersion:2,
      position:[240,100],parameters:{mode:'runOnceForEachItem',jsCode:configurationCode}},
  ];
  const connections={
    'Scheduled poll':edge('Validate backend configuration'),
    'Controlled manual test':edge('Validate backend configuration'),
  };
  let previous='Validate backend configuration';
  definition.operations.forEach((operation,index)=>{
    const operationName=operation.replace(/^worker-/,'');
    const requestName=`Poll trusted ${operationName} worker`;
    const resultName=`Check ${operationName} result`;
    const x=480+index*480;
    nodes.push({id:`${definition.file}-${operation}`,name:requestName,type:'n8n-nodes-base.httpRequest',typeVersion:4.2,
      position:[x,100],parameters:{method:'POST',
        url:`={{ $('Validate backend configuration').item.json.origin + ${JSON.stringify('/api/tiktok-dm?op='+operation)} }}`,
        authentication:'genericCredentialType',genericAuthType:'httpHeaderAuth',
        sendBody:true,specifyBody:'json',jsonBody:'{}',
        options:{timeout:60000,redirect:{redirect:{followRedirects:false}},
          response:{response:{fullResponse:true,neverError:true,responseFormat:'text'}}}},
      credentials:{httpHeaderAuth:{id:null,name:'UNCONFIGURED — Proxo TikTok DM worker'}},
      retryOnFail:true,maxTries:3,waitBetweenTries:5000,onError:'continueRegularOutput',
      notes:'Only transport failures retry here. The backend owns durable claims, bounded stage backoff and uncertain-outcome reconciliation.'});
    nodes.push({id:`${definition.file}-${operation}-result`,name:resultName,type:'n8n-nodes-base.code',typeVersion:2,
      position:[x+240,100],parameters:{mode:'runOnceForEachItem',jsCode:resultCode}});
    connections[previous]=edge(requestName);
    connections[requestName]=edge(resultName);
    previous=resultName;
  });
  const workflow={name:definition.name,nodes,connections,active:false,
    settings:{executionOrder:'v1',timezone:'Asia/Baghdad',executionTimeout:240*definition.operations.length,
      saveDataErrorExecution:'none',saveDataSuccessExecution:'none',saveManualExecutions:false,
      saveExecutionProgress:false},pinData:{},tags:[],meta:{templateCredsSetupCompleted:false},
    description:definition.description};
  writeFileSync(fileURLToPath(new URL(`./${definition.file}.json`,import.meta.url)),JSON.stringify(workflow,null,2)+'\n');
  console.log(`Wrote inactive ${definition.file}.json (${nodes.length} nodes).`);
}
