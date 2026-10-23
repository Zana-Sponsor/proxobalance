import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { normalizeConfiguration, fingerprint, MetaError } from '../api/_lib/meta/contract.js';
import { graphClient, preflight, resolvePost, resolveRedirect, providerParameters, reconcileStage, observeChain, selectTuple } from '../api/_lib/meta/provider.js';
import { runWorker } from '../api/_lib/meta/worker.js';
import { createMetaHandler, backend } from '../api/meta-ads.js';

const now=Date.parse('2026-10-23T08:00:00Z');
const at=new Date(now).toISOString();
const uid='10000000-0000-4000-8000-000000000001';
const quoteId='20000000-0000-4000-8000-000000000002';
const jobId='30000000-0000-4000-8000-000000000003';
const configuration=(destinations=['MESSENGER'])=>normalizeConfiguration({schema_version:3,platform:'META',ad_name:'Existing post',objective:'MESSAGES',
  page_url:'https://facebook.com/our.page',post_url:'https://facebook.com/our.page/posts/pfbidOpaqueA',placements:['facebook','instagram'],
  destinations,currency:'USD',budget_daily:2,duration_days:1,payment_method:'WALLET',schedule:{mode:'IMMEDIATE',timezone:'Asia/Baghdad'},
  targeting:{location:'all',gender:'ALL',age_min:18,age_max:65}},{now});
const tuple=(config,post={id:'123_456',kind:'FACEBOOK',media_type:'VIDEO'})=>({api_version:'v26.0',verified:true,verified_at:at,post_id:post.id,post_kind:post.kind,post_media_type:post.media_type,
  objective:config.objective,destinations:config.destinations,placements:config.placements,campaign_objective:'OUTCOME_ENGAGEMENT',optimization_goal:'CONVERSATIONS',billing_event:'IMPRESSIONS',
  creative_mode:post.kind==='FACEBOOK'?'FACEBOOK_EXISTING':'INSTAGRAM_EXISTING',existing_post_multidestination:true});
const connection=config=>({id:quoteId,status:'authorized',page_id:'123',ad_account_id:'789',instagram_account_id:'222',whatsapp_phone_number_id:'333',access_token_env:'META_TEST_TOKEN',verified_at:at,
  expires_at:new Date(now+86400000).toISOString(),capabilities:{api_version:'v26.0',business_id:'888',system_user_id:'999',page_urls:[config.page_url],
    messenger:{enabled:true,verified_at:at},whatsapp:{page_id:'123',phone_number_id:'333',phone_number:'9647500000000',verified_at:at},
    locations:{all:{geo_locations:{countries:['IQ']},verified_at:at}},tuples:[tuple(config)]}});
function graphFixture({wrongOwner=false,emptyPage=false,calls=[]}={}) {
  return async(path,params,options={})=>{
    calls.push({path,params,options});
    const data={
      'me/permissions':{data:['ads_management','business_management','pages_read_engagement'].map(permission=>({permission,status:'granted'}))},
      me:{id:'999'},'999/assigned_pages':{data:[{id:'123',tasks:['ADVERTISE']}]},'999/assigned_ad_accounts':{data:[{id:'act_789',tasks:['ADVERTISE']}]},
      act_789:{id:'act_789',account_status:1,currency:'USD',timezone_name:'Asia/Baghdad'},
      '123':{id:'123',link:'https://www.facebook.com/our.page',instagram_business_account:{id:'222'}},
      '333':{id:'333',display_phone_number:'+964 750 000 0000',verified_name:'Our business'},
      '123/posts':{data:emptyPage?[]:[{id:'123_456',from:{id:wrongOwner?'555':'123'},permalink_url:'https://www.facebook.com/our.page/posts/pfbidOpaqueA',attachments:{data:[{media_type:'video'}]}}]},
    };
    if(path in data)return structuredClone(data[path]);
    throw Error(`unexpected graph read ${path}`);
  };
}
async function evidence(config=configuration()) { return preflight(config,connection(config),{graph:graphFixture(),now}); }

test('pfbid is resolved by authorized feed pagination and ownership; never fabricated',async()=>{
  const calls=[];const c=configuration();
  const e=await preflight(c,connection(c),{graph:graphFixture({calls}),now});
  assert.equal(e.post.id,'123_456');assert.equal(e.ready,true);
  assert(!calls.some(c=>c.path.includes('pfbid')));
  assert(calls.every(c=>(c.options.method||'GET')==='GET'));
  await assert.rejects(preflight(c,connection(c),{graph:graphFixture({wrongOwner:true}),now}),{code:'POST_PAGE_MISMATCH'});
  await assert.rejects(preflight(c,connection(c),{graph:graphFixture({emptyPage:true}),now}),{code:'POST_NOT_FOUND_IN_ACCESSIBLE_FEED'});
});

test('feed permission, no result and bounded pagination remain distinct',async()=>{
  const c=configuration(),page={id:'123',instagram_id:'222'};
  const calls=[];
  const graph=async(path,params)=>{calls.push(params);return params.after?{data:[{id:'123_456',from:{id:'123'},permalink_url:c.post_url}]}:{data:[],paging:{next:'https://evil.invalid/?access_token=never-follow',cursors:{after:'cursor2'}}};};
  assert.equal((await resolvePost(graph,page,c.post_url)).id,'123_456');assert.equal(calls[1].after,'cursor2');
  await assert.rejects(resolvePost(async()=>{throw new MetaError('META_PERMISSION_MISSING');},page,c.post_url),{code:'META_PERMISSION_MISSING'});
  await assert.rejects(resolvePost(async()=>({data:[],paging:{next:'unused',cursors:{after:'more'}}}),page,c.post_url,{maxPages:2}),{code:'PROVIDER_LOOKUP_LIMIT_REACHED'});
});

test('Instagram content belongs to the Page linked IG account, not the Page numeric id',async()=>{
  const post={id:'765',owner:{id:'222'},permalink:'https://www.instagram.com/reel/CODE',media_type:'VIDEO'};
  let read=0;
  const graph=async path=>{read++;return path==='222/media'?{data:[post]}:post;};
  assert.equal((await resolvePost(graph,{id:'123',instagram_id:'222'},post.permalink)).owner_id,'222');assert.equal(read,2);
  await assert.rejects(resolvePost(async path=>path==='222/media'?{data:[post]}:{...post,owner:{id:'123'}},{id:'123',instagram_id:'222'},post.permalink),{code:'INSTAGRAM_OWNER_MISMATCH'});
});

test('short-link redirect safety blocks local/foreign/credential URLs without forwarding authorization',async()=>{
  for(const location of ['http://127.0.0.1/private','https://example.com/x','https://name:pass@facebook.com/x','https://facebook.com:444/x']) {
    let count=0;
    await assert.rejects(resolveRedirect('https://fb.watch/short',{fetchImpl:async(url,options)=>{count++;assert.equal(options.redirect,'manual');assert(!options.headers.Authorization);return new Response('',{status:302,headers:{location}});}}));
    assert.equal(count,1);
  }
  await assert.rejects(resolveRedirect('https://fb.watch/short',{fetchImpl:async()=>new Response('login')}),{code:'POST_DIRECT_LINK_REQUIRED'});
});

test('all seven destination subsets preserve native budget and existing content',async()=>{
  const channels=['MESSENGER','WHATSAPP','INSTAGRAM_DIRECT'];
  const types=new Set();
  for(let mask=1;mask<8;mask++) {
    const c=configuration(channels.filter((_,i)=>mask&(1<<i))),e=await evidence(c);
    const job={id:jobId,configuration:c,provider_ids:{campaign:'11',adset:'22',creative:'33'},start_at:at,end_at:new Date(now+86400000).toISOString()};
    const campaign=providerParameters('campaign',job,e),adset=providerParameters('adset',job,e),creative=providerParameters('creative',job,e),ad=providerParameters('ad',job,e);
    types.add(adset.destination_type);assert.equal(campaign.status,'PAUSED');assert.equal(adset.status,'PAUSED');assert.equal(ad.status,'PAUSED');
    assert.equal(adset.lifetime_budget,200);assert.equal(adset.daily_budget,undefined);assert.equal(creative.object_story_id,'123_456');assert.equal(creative.object_story_spec,undefined);
    const ctas=creative.asset_feed_spec?.call_to_actions||[creative.call_to_action];
    assert.deepEqual(ctas.map(c=>c.value.app_destination).sort(),c.destinations);
  }
  assert.equal(types.size,7);
});

test('preflight fails closed for stale approval, wrong currency, unknown tuple and all-Iraq misconfiguration',async()=>{
  const c=configuration(),conn=connection(c),graph=graphFixture();
  await assert.rejects(preflight(c,{...conn,expires_at:null},{graph,now}),{code:'META_CONNECTION_VERIFICATION_REQUIRED'});
  await assert.rejects(preflight(c,{...conn,capabilities:{...conn.capabilities,tuples:[]}},{graph,now}),{code:'EXISTING_POST_TUPLE_NOT_VERIFIED'});
  await assert.rejects(preflight(c,{...conn,capabilities:{...conn.capabilities,locations:{all:{geo_locations:{countries:['US']},verified_at:at}}}},{graph,now}),{code:'ALL_IRAQ_TARGETING_INVALID'});
  await assert.rejects(preflight(c,conn,{graph:async(p,q)=>p==='act_789'?{account_status:1,currency:'IQD'}:graph(p,q),now}),{code:'AD_ACCOUNT_CURRENCY_UNSUPPORTED'});
  assert.throws(()=>selectTuple(c,{id:'123_456',kind:'FACEBOOK',media_type:'VIDEO'},{tuples:[{...tuple(c),creative_mode:'REPLACE_WITH_NEW'}]},{now}),{code:'EXISTING_POST_CREATIVE_UNSUPPORTED'});
});

test('Graph transport keeps token server-side, pins version, distinguishes ambiguous writes',async()=>{
  const calls=[];
  const graph=graphClient({token:'secret-never-log',fetchImpl:async(url,options)=>{calls.push({url:String(url),options});return new Response(JSON.stringify({id:'123'}),{status:200});}});
  await graph('123',{fields:'id'});assert.match(calls[0].url,/graph.facebook.com\/v26.0\/123/);assert(!calls[0].url.includes('secret-never-log'));assert.equal(calls[0].options.redirect,'error');
  await assert.rejects(graph('../escape'),{code:'INVALID_PROVIDER_PATH'});
  const outage=graphClient({token:'x',fetchImpl:async()=>{throw Error('sensitive request');}});
  await assert.rejects(outage('act_1/campaigns',{status:'PAUSED'},{method:'POST'}),e=>e.code==='PROVIDER_OUTCOME_UNKNOWN'&&e.uncertain);
  await assert.rejects(outage('123'),e=>e.code==='PROVIDER_UNAVAILABLE'&&!e.uncertain);
  const denied=graphClient({token:'x',fetchImpl:async()=>new Response(JSON.stringify({error:{code:200,message:'private raw content'}}),{status:403})});
  await assert.rejects(denied('123'),e=>e.code==='META_PERMISSION_MISSING'&&!e.message.includes('private'));
});

test('reconciliation needs one exact paused object; a missing match never recreates',async()=>{
  const c=configuration(),e=await evidence(c),job={id:jobId,configuration:c,provider_ids:{}};
  const expected=providerParameters('campaign',job,e);
  assert.equal(await reconcileStage(async path=>path==='444'?{id:'444',...expected}:{data:[{id:'444',...expected}]} ,'campaign',job,e),'444');
  await assert.rejects(reconcileStage(async()=>({data:[]}),'campaign',job,e),{code:'PROVIDER_RECONCILIATION_PENDING',uncertain:true});
  await assert.rejects(reconcileStage(async path=>path==='444'?{id:'444',...expected,status:'ACTIVE'}:{data:[{id:'444',...expected,status:'ACTIVE'}]},'campaign',job,e),{code:'PROVIDER_RECONCILIATION_MISMATCH'});
  await assert.rejects(reconcileStage(async()=>({data:[{id:'444',...expected},{id:'555',...expected}]}),'campaign',job,e),{code:'PROVIDER_DUPLICATE_OBJECTS'});
});

test('worker saves intent before POST and never recreates a lost create response',async()=>{
  const c=configuration(),e=await evidence(c);
  const job={id:jobId,lease_token:uid,configuration:c,evidence:e,connection:connection(c),provider_ids:{},stages:{},start_at:at,end_at:new Date(now+86400000).toISOString()};
  const events=[];let posts=0;
  const service=async(action,{payload}={})=>{
    events.push(action);if(action==='claim')return structuredClone(job);
    if(action==='intent')job.stages[payload.stage]={state:'inflight',request_hash:payload.request_hash};
    return {ok:true};
  };
  const reads=graphFixture();
  const graph=async(path,params,opts={})=>{if(opts.method==='POST'){assert.equal(events.at(-1),'intent');posts++;throw new MetaError('PROVIDER_OUTCOME_UNKNOWN',{uncertain:true});}return reads(path,params);};
  assert.equal((await runWorker('create',{service,graphFactory:()=>graph,now:()=>now})).status,'reconcile');
  assert.equal(posts,1);assert.equal(job.stages.campaign.state,'inflight');
  await runWorker('create',{service,graphFactory:()=>graph,now:()=>now});assert.equal(posts,1);
  assert(!events.includes('refund'));assert(!events.includes('reject'));
});

test('reconciliation adoption requires persisted request hash and passes proof to DB',async()=>{
  const c=configuration(),e=await evidence(c),job={id:jobId,lease_token:uid,configuration:c,evidence:e,connection:connection(c),provider_ids:{},stages:{},start_at:at,end_at:new Date(now+86400000).toISOString()};
  const params=providerParameters('campaign',job,e);job.stages.campaign={state:'inflight',request_hash:fingerprint(params)};
  const events=[];
  const service=async(action,{payload}={})=>{events.push({action,payload});return action==='claim'?job:{ok:true};};
  const graph=async path=>path==='act_789/campaigns'?{data:[{id:'444',...params}]}:path==='444'?{id:'444',...params,effective_status:'PAUSED'}:{data:[]};
  await runWorker('reconcile',{service,graphFactory:()=>graph,now:()=>now});
  assert.equal(events.find(e=>e.action==='complete').payload.reconciled,true);assert(!events.some(e=>e.action==='intent'||e.action==='refund'));
});

test('status read failures never manufacture zero spend, failure or refunds',async()=>{
  const c=configuration(),e=await evidence(c),job={id:jobId,lease_token:uid,configuration:c,evidence:e,connection:connection(c),provider_ids:{campaign:'444'},stages:{}};
  const events=[];
  const service=async(action)=>{events.push(action);return action==='claim'?job:{ok:true};};
  await runWorker('status',{service,graphFactory:()=>async()=>{throw new MetaError('PROVIDER_UNAVAILABLE',{retryable:true});},now:()=>now});
  assert(!events.includes('refund'));assert(!events.includes('observe'));assert.equal(events.at(-1),'finish');
  await assert.rejects(observeChain(async()=>{throw new Error('offline');},job));
});

test('backend service envelopes cannot bypass gate/intent and unknown mutation response stays uncertain',async()=>{
  const env={PROXO_SUPABASE_URL:'https://unit.invalid',PROXO_SUPABASE_SERVICE_ROLE_KEY:'service'};
  const denied=backend({env,fetchImpl:async()=>new Response(JSON.stringify({ok:false,code:'META_DISABLED'}))});
  await assert.rejects(denied.service('intent',{id:jobId}),{code:'META_DISABLED'});
  const disabled=backend({env,fetchImpl:async()=>new Response(JSON.stringify({ok:true,enabled:false}))});
  await assert.rejects(disabled.service('gate',{userId:uid}),{code:'META_DISABLED'});
  const bad=backend({env,fetchImpl:async()=>new Response(JSON.stringify({code:'08006',message:'connection interrupted'}),{status:500})});
  await assert.rejects(bad.user({headers:{authorization:'Bearer jwt'}},'pa_meta_accept',{}),e=>e.uncertain&&e.retryable);
  const conn=connection(configuration());
  assert.deepEqual(await backend({env,fetchImpl:async()=>new Response(JSON.stringify({ok:true,connection:conn}))}).service('connection'),conn);
});

test('isolated HTTP endpoint authenticates, quotes read-only, normalizes submit and authenticates refund',async t=>{
  const events=[],c=configuration(),conn=connection(c),env={META_TEST_TOKEN:'test-token',META_WORKER_SECRET:'worker-secret-32-chars-xxxxxxxxxxxx'};
  const db={authenticate:async req=>req.headers.authorization==='Bearer user-jwt'?{id:uid}:null,
    service:async(action,args)=>{events.push({action,args});return action==='connection'?conn:action==='store_quote'?{ok:true,quote_id:quoteId,gross_usd:2,cost_usd:2,amount_iqd:3000,rate:1500,balance_usd:8}:action==='refund'?{ok:true,status:'refunded'}:{ok:true};},
    user:async(req,name,payload)=>{events.push({action:name,payload});return {ok:true,ad_id:jobId};}};
  const server=createServer(createMetaHandler({env,db,now:()=>now,preflightImpl:async()=>evidence(c)}));
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));t.after(()=>new Promise(resolve=>server.close(resolve)));
  const url=`http://127.0.0.1:${server.address().port}/api/meta-ads`;
  const post=async(op,body,token='user-jwt')=>{const r=await fetch(`${url}?op=${op}`,{method:'POST',headers:{Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:JSON.stringify(body)});return {status:r.status,body:await r.json()};};
  assert.equal((await post('quote',{configuration:c},'bad')).status,401);assert.equal(events.length,0);
  const q=await post('quote',{configuration:{...c,page_url:'https://m.facebook.com/our.page/'}});assert.equal(q.status,200);assert.equal(q.body.configuration.page_url,c.page_url);
  assert.deepEqual(events.map(e=>e.action),['gate','connection','store_quote']);assert(!events.some(e=>e.action==='pa_meta_accept'));
  events.length=0;
  const input={configuration:c,quote_id:quoteId,submission_id:uid,expected_total_minor:200,expected_total_iqd:3000};
  assert.equal((await post('submit',input)).status,200);assert.deepEqual(events.map(e=>e.action),['pa_meta_accept']);
  assert.equal((await post('submit',{...input,user_id:jobId})).status,422);
  const refund={user_id:uid,order_id:jobId,amount:2,reason:'Provider rejected before delivery'};
  assert.equal((await post('refund',refund)).status,401);
  assert.equal((await post('refund',refund,env.META_WORKER_SECRET)).status,200);
  assert.equal(events.at(-1).args.payload.expected_amount,2);
});
