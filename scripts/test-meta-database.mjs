/** Disposable PostgreSQL integration tests; never connects to Supabase.
 * Install @electric-sql/pglite externally, then:
 * PGLITE_MODULE=/absolute/node_modules/@electric-sql/pglite/dist/index.js node scripts/test-meta-database.mjs
 */
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import { pathToFileURL } from 'node:url';
import { normalizeConfiguration, fingerprint, unavailableForecast } from '../api/_lib/meta/contract.js';
const modulePath=process.env.PGLITE_MODULE;
const { PGlite }=await import(modulePath?pathToFileURL(modulePath).href:'@electric-sql/pglite');
const db=new PGlite();
const read=p=>fs.readFile(new URL('../'+p,import.meta.url),'utf8');
let checks=0;
function check(value,message) { assert.ok(value,message); checks++; }
async function scalar(sql,args=[]) {return (await db.query(sql,args)).rows[0]?.v;}
const user='11111111-1111-4111-8111-111111111111', other='22222222-2222-4222-8222-222222222222', admin='33333333-3333-4333-8333-333333333333';
const session='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', otherSession='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', adminSession='cccccccc-cccc-4ccc-8ccc-cccccccccccc';
const conn='44444444-4444-4444-8444-444444444444';
async function role(name,fn,who=user,sid=session) {
 await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({role:name,sub:who,session_id:sid})]);
 await db.exec(`set role ${name}`);
 try {return await fn();} finally {await db.exec('reset role');}
}
const service=(action,{userId=null,id=null,token=null,payload={}}={})=>role('service_role',()=>scalar('select public.pa_meta_service($1,$2,$3,$4,$5::jsonb) v',[action,userId,id,token,JSON.stringify(payload)]));
const base=normalizeConfiguration({schema_version:3,platform:'META',ad_name:'Private Meta fixture',objective:'MESSAGES',page_url:'https://www.facebook.com/123',post_url:'https://www.facebook.com/123/posts/456',placements:['facebook','instagram'],destinations:['WHATSAPP','MESSENGER','INSTAGRAM_DIRECT'],currency:'USD',budget_daily:2,duration_days:3,payment_method:'WALLET',schedule:{mode:'IMMEDIATE',timezone:'Asia/Baghdad'},targeting:{location:'all',gender:'ALL',age_min:18,age_max:65}});
const quote=(configuration=base)=>service('store_quote',{userId:user,payload:{configuration,config_hash:fingerprint(configuration),evidence:{authorized:true,ready:true,connection_id:conn},forecast:unavailableForecast()}});
const accept=(q,key,configuration=q.configuration,who=user,sid=session,payment=null)=>role('authenticated',()=>scalar('select public.pa_meta_accept($1,$2,$3::jsonb,$4,$5,$6) v',[key,q.quote_id,JSON.stringify(configuration),q.pricing?.payable_minor,q.amount_iqd,payment]),who,sid);
const uuid=()=>crypto.randomUUID();
async function deny(sql) {let denied=false;try{await role('authenticated',()=>db.exec(sql));}catch(e){denied=e.code==='42501';}check(denied,`authorization: ${sql}`);}
try {
 await db.exec(await read('test/fixtures/secure-operations-database.sql'));
 await db.exec(await read('proxo_app/supabase/migrations/20261016174350_secure_financial_operations.sql'));
 const checkout=await read('proxo_app/supabase/migrations/20260913210000_fastpay_ad_checkout.sql');
 await db.exec(checkout.slice(checkout.indexOf('create or replace function public.pa_quote_ad_checkout('),checkout.indexOf('revoke all on function public.pa_quote_ad_checkout(')));
 await db.exec(await read('proxo_app/supabase/migrations/20261022235825_meta_ads_private_v3.sql'));
 await db.exec(await read('proxo_app/supabase/migrations/20261023193522_tiktok_dm_private_v1.sql'));
 await db.query('insert into auth.users(id,email,email_confirmed_at) values($1,$2,now()),($3,$4,now()),($5,$6,now())',[user,'one@example.invalid',other,'two@example.invalid',admin,'admin@example.invalid']);
 await db.query('insert into auth.sessions(id,user_id) values($1,$2),($3,$4),($5,$6)',[session,user,otherSession,other,adminSession,admin]);
 await db.query('insert into public.profiles(id,is_admin) values($1,false),($2,false),($3,true)',[user,other,admin]);
 await db.query('update public.pa_wallets set balance=100 where user_id=$1',[user]);
 const flags=await role('authenticated',()=>scalar('select public.pa_ad_capabilities() v'));
 check(flags.meta_enabled===false && flags.meta_public_enabled===false && flags.meta_paid_activation_enabled===false && flags.meta_fastpay_enabled===false,'all rollout gates default OFF');
 check((await quote()).code==='META_DISABLED','default OFF denies service quote');
 await deny('select * from app_meta.connections');
 await deny("select public.pa_meta_service('claim')");
 await deny('update app_meta.settings set enabled=true');
 await deny("select public.pa_quote_ad_checkout('"+user+"','{}')");
 await db.exec('update app_meta.settings set enabled=true');
 check((await quote()).code==='META_DISABLED','global flag alone does not authorize ordinary user');
 await db.query('insert into app_meta.testers(user_id,enabled) values($1,true),($2,true)',[user,other]);
 check((await quote()).code==='CONNECTION_REQUIRED','requires verified authorized connection');
 await db.query("insert into app_meta.connections(id,user_id,status,ad_account_id,page_id,access_token_env,verified_at,expires_at) values($1,$2,'authorized','act_123','123','META_FIXTURE_TOKEN',now(),now()+interval '1 hour')",[conn,user]);
 const q=await quote();
 check(q.ok && q.pricing.payable_minor===600 && q.amount_iqd===10800,'one total across two placements and three destinations');
 check(q.forecast.status==='UNAVAILABLE' && q.forecast.lower_bound===null,'unavailable forecast remains unavailable');
 check(await scalar('select balance=100 v from public.pa_wallets where user_id=$1',[user]),'quote does not fund/debit');
 check(await scalar('select count(*)=0 v from public.pa_ads'),'quote creates no order');
 check(await scalar('select count(*)=0 v from app_meta.jobs'),'quote creates no provider job');
 let immutable=false;try{await db.query("update app_meta.quotes set payable_minor=1 where id=$1",[q.quote_id]);}catch(e){immutable=e.message.includes('META_QUOTE_IMMUTABLE');}check(immutable,'quote pricing immutable');
 const invalids=[{destinations:['MESSENGER','MESSENGER']},{destinations:['both']},{destination:'MESSENGER'},{destinations:['messenger']},{placements:['instagram'],destinations:['MESSENGER']},{objective:'VIDEO_VIEWS'},{budget_daily:1.99},{budget_daily:2.001},{duration_days:1.5},{schedule:{mode:'SCHEDULED',timezone:'Asia/Baghdad',start_at:'2020-01-01T00:00:00Z'}},{schedule:{mode:'IMMEDIATE',timezone:'Asia/Baghdad',start_at:'2040-01-01T00:00:00Z'}}];
 for(const patch of invalids) check(await scalar('select not app_meta.valid_configuration($1::jsonb) v',[JSON.stringify({...base,...patch})]),'DB rejects invalid v3 configuration '+JSON.stringify(patch));
 check((await quote({...base,payment_method:'FASTPAY'})).code==='META_FASTPAY_UNAVAILABLE','FastPay requires verified rollout flag');
 const key=uuid(),accepted=await accept(q,key);
 check(accepted.ok && accepted.platform==='META','accepted Meta order');
 check(await scalar('select balance=94 v from public.pa_wallets where user_id=$1',[user]),'exact debit once');
 check(await scalar('select count(*)=1 v from app_finance.ledger'),'one immutable debit ledger');
 check(await scalar('select count(*)=1 v from app_meta.jobs'),'durable job committed with debit');
 check(await scalar('select count(*)=0 v from app_finance.outbox'),'never dispatched to TikTok outbox');
 check(Date.parse(accepted.end_at)-Date.parse(accepted.start_at)===3*86400000,'exclusive schedule duration exactly days*24h');
 check(await scalar("select age_groups='[\"18-65\"]'::jsonb v from public.pa_ads where id=$1",[accepted.ad_id]),'receipt keeps actual age range');
 await db.exec('update app_meta.settings set enabled=false');
 assert.deepEqual(await accept(q,key),accepted);checks++;
 assert.deepEqual(await role('authenticated',()=>scalar('select public.pa_ad_submission_status($1) v',[key])),accepted);checks++;
 check((await accept(q,key,{...base,ad_name:'Different'})).code==='IDEMPOTENCY_CONFLICT','conflicting retry fails before gate');
 check((await role('authenticated',()=>scalar('select public.pa_ad_submission_status($1) v',[key]),other,otherSession)).code==='NOT_FOUND','recovery scoped to owner');
 check(await service('claim',{payload:{kind:'create'}})===null,'OFF blocks new job claim');
 await db.exec('update app_meta.settings set enabled=true');
 check((await accept(q,uuid())).code==='QUOTE_ALREADY_USED','different request key cannot reuse funded quote');
 check((await accept(q,uuid(),base,other,otherSession)).code==='QUOTE_NOT_FOUND','cannot accept another owner quote');
 check((await role('authenticated',()=>scalar('select public.pa_cancel_pending_ad($1,$2) v',[accepted.ad_id,'cancel']))).code==='META_REFUND_REQUIRES_SERVER','legacy cancellation cannot refund Meta');
 const q2=await quote();
 await db.query('update public.pa_wallets set balance=1 where user_id=$1',[user]);
 check((await accept(q2,uuid())).code==='INSUFFICIENT_FUNDS','insufficient funds refuses atomically');
 await db.query('update public.pa_wallets set balance=94 where user_id=$1',[user]);
 await db.exec("create function app_meta.fixture_fail_job() returns trigger language plpgsql as $$begin raise exception 'injected_job_failure';end$$;create trigger fixture_fail_job before insert on app_meta.jobs for each row execute function app_meta.fixture_fail_job()");
 let failed=false;try{await accept(q2,uuid());}catch(e){failed=e.message.includes('injected_job_failure');}check(failed,'outbox failure injected');
 await db.exec('drop trigger fixture_fail_job on app_meta.jobs');
 check(await scalar('select balance=94 v from public.pa_wallets where user_id=$1',[user]),'outbox failure rolls wallet back');
 check(await scalar('select count(*)=1 v from public.pa_ads'),'outbox failure rolls order back');
 check(await scalar('select count(*)=1 v from app_finance.ledger'),'outbox failure rolls ledger back');
 const job=await service('claim',{payload:{kind:'create'}});
 check(job.id===accepted.job_id && job.configuration.platform==='META' && job.connection.access_token_env==='META_FIXTURE_TOKEN','worker gets immutable bound config and metadata');
 const hash='a'.repeat(64);
 check((await service('intent',{id:job.id,token:job.lease_token,payload:{stage:'adset',request_hash:hash}})).code==='INVALID_STAGE_ORDER','cannot skip campaign');
 check((await service('intent',{id:job.id,token:job.lease_token,payload:{stage:'campaign',request_hash:hash}})).ok,'intent durable before provider POST');
 check((await service('intent',{id:job.id,token:job.lease_token,payload:{stage:'campaign',request_hash:hash}})).code==='PROVIDER_OUTCOME_UNKNOWN','never repeat ambiguous POST');
 check((await service('refund',{userId:user,id:accepted.ad_id,payload:{expected_amount:5}})).code==='AMOUNT_MISMATCH','refund cannot trust caller amount');
 check((await service('refund',{userId:user,id:accepted.ad_id,payload:{expected_amount:6}})).status==='refund_pending','ambiguous provider outcome cannot credit wallet');
 check(await scalar('select status=$2 and amount=6 v from public.pa_transactions where id=$1',[accepted.receipt_uid,'refund_pending']),'original debit pending preserves amount');
 check(await scalar('select balance=94 v from public.pa_wallets where user_id=$1',[user]),'uncertain refund has no credit');
 await service('finish',{id:job.id,token:job.lease_token,payload:{status:'reconcile'}});
 await db.query('update app_meta.jobs set available_at=now() where id=$1',[job.id]);
 await db.exec('update app_meta.settings set enabled=false');
 const recovery=await service('claim',{id:job.id,payload:{kind:'reconcile'}});
 check(recovery.id===job.id,'reconcile still available gate OFF');
 check((await service('complete',{id:job.id,token:recovery.lease_token,payload:{stage:'campaign',provider_id:'987'}})).code==='RECONCILIATION_EVIDENCE_REQUIRED','reconcile cannot invent provider id');
 check((await service('complete',{id:job.id,token:recovery.lease_token,payload:{stage:'campaign',provider_id:'987',request_hash:hash,reconciled:true}})).ok,'exact reconciled provider ID adopted');
 check((await service('refund',{id:job.id})).status==='refund_pending','known ID alone cannot prove no spend');
 check((await service('observe',{id:job.id,token:recovery.lease_token,payload:{chain_paused:true,spend_minor:null,provider_status:'PAUSED',verified_at:new Date().toISOString()}})).ok,'unknown spend permits status-only observation');
 check((await service('refund',{id:job.id})).status==='refund_pending','unknown spend cannot manufacture refund eligibility');
 check(await scalar("select not provider_metrics_available ? 'spend' v from public.pa_ads where id=$1",[accepted.ad_id]),'unknown Meta spend is not published as a zero metric');
 check((await service('observe',{id:job.id,token:recovery.lease_token,payload:{chain_paused:true,spend_minor:0,provider_status:'PAUSED',review_status:null,terminal_failure:true,verified_at:new Date().toISOString()}})).ok,'read-only provider observation persisted');
 const refund=await service('refund',{id:accepted.ad_id,userId:user,payload:{expected_amount:6,reason:'fixture paused'}});
 check(refund.ok && refund.status==='refunded' && Number(refund.amount)===6,'full refund derives original debit');
 check(await scalar('select balance=100 v from public.pa_wallets where user_id=$1',[user]),'compensating credit exact');
 check(await scalar('select status=$2 and amount=6 v from public.pa_transactions where id=$1',[accepted.receipt_uid,'refunded']),'original debit updated refunded, amount preserved');
 check(await scalar('select count(*)=1 and sum(amount)=6 v from app_finance.ledger where original_transaction_id=$1',[accepted.receipt_uid]),'linked compensating credit ledger');
 check((await service('refund',{id:accepted.ad_id,userId:user})).already_refunded===true,'repeated refund harmless');
 check(await scalar('select balance=100 v from public.pa_wallets where user_id=$1',[user]),'repeat refund cannot double credit');
 await db.exec('update app_meta.settings set enabled=true');
 const accepted2=await accept(q2,uuid());
 check(accepted2.ok,'second quote available after atomic rollback');
 const noProvider=await service('refund',{id:accepted2.ad_id,userId:user});
 check(noProvider.ok && noProvider.status==='refunded','never-created job safely refundable');
 // Admin changes apply remotely; ordinary users cannot write the scoped notice.
 let adminDenied=false;try{await role('authenticated',()=>scalar("select public.pa_set_ad_help('all','{\"active\":true,\"message\":\"Help\"}') v"));}catch(e){adminDenied=e.code==='42501';}check(adminDenied,'ordinary user cannot edit help');
 const help=(scope,message,url='https://example.com/video')=>role('authenticated',()=>scalar('select public.pa_set_ad_help($1,$2::jsonb) v',[scope,JSON.stringify({active:true,message,video_url:url})]),admin,adminSession);
 check((await help('all','General')).ok,'admin shared help saved');check((await help('meta','Meta')).ok,'admin platform help saved');
 check((await role('authenticated',()=>scalar("select public.pa_ad_help('META') v"))).message==='Meta','platform help takes deterministic precedence');
 check((await role('authenticated',()=>scalar("select public.pa_ad_help('TIKTOK') v"))).message==='General','shared help fallback');
 check((await help('meta','bad','http://example.com')).code==='INVALID_HELP','help refuses non-HTTPS destination');
 // Existing TikTok checkout price is still delegated to the unmodified function.
 const legacy=await role('service_role',()=>scalar('select public.pa_quote_ad_checkout($1,$2::jsonb) v',[user,JSON.stringify({daily_budget:10,days:1})]));
 check(legacy.ok && Number(legacy.cost_usd)===10,'legacy TikTok FastPay quote behavior preserved');
 console.log(`PASS ${checks} Meta PostgreSQL integration assertions (disposable PGlite; no external calls).`);
} catch(error) {console.error('FAIL',error.message,error.where||'',error.detail||'');process.exitCode=1;} finally {await db.close();}
