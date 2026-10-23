/** PostgreSQL report/settlement authority boundaries; no live provider call. */
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {fingerprint,normalizeAd} from '../api/_lib/tiktok/contract.js';
const {PGlite}=await import(process.env.PGLITE_MODULE?pathToFileURL(process.env.PGLITE_MODULE).href:'@electric-sql/pglite');
const db=new PGlite();let checks=0;
const read=p=>fs.readFile(new URL('../'+p,import.meta.url),'utf8');
const check=(v,m)=>{assert.ok(v,m);checks++;};
const scalar=async(sql,args=[])=> (await db.query(sql,args)).rows[0]?.v;
const user='11111111-1111-4111-8111-111111111111',other='22222222-2222-4222-8222-222222222222',session='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',account='44444444-4444-4444-8444-444444444444';
const uuid=()=>crypto.randomUUID();
async function role(name,fn){await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:user,session_id:session,role:name})]);await db.exec(`set role ${name}`);try{return await fn();}finally{await db.exec('reset role');}}
const service=(action,id=null,token=null,payload={},owner=null)=>role('service_role',()=>scalar('select public.pa_tiktok_dm_service($1,$2,$3,$4,$5::jsonb) v',[action,owner,id,token,JSON.stringify(payload)]));
async function denied(sql){let result=false;try{await role('authenticated',()=>db.exec(sql));}catch(e){result=e.code==='42501';}check(result,sql);}
try{
 await db.exec(await read('test/fixtures/secure-operations-database.sql'));
 await db.exec(await read('proxo_app/supabase/migrations/20261016174350_secure_financial_operations.sql'));
 const checkout=await read('proxo_app/supabase/migrations/20260913210000_fastpay_ad_checkout.sql');
 await db.exec(checkout.slice(checkout.indexOf('create or replace function public.pa_quote_ad_checkout('),checkout.indexOf('revoke all on function public.pa_quote_ad_checkout(')));
 const names=(await fs.readdir(new URL('../proxo_app/supabase/migrations/',import.meta.url))).filter(n=>/^2026102[23].*\.sql$/.test(n)).sort();
 for(const name of names){const source=await read('proxo_app/supabase/migrations/'+name);if(source.trim())await db.exec(source);}
 await db.query('insert into auth.users(id,email_confirmed_at) values($1,now()),($2,now())',[user,other]);
 await db.query('insert into auth.sessions(id,user_id) values($1,$2)',[session,user]);
 await db.query('insert into public.profiles(id) values($1),($2)',[user,other]);
 await db.query('update public.pa_wallets set balance=100 where user_id=$1',[user]);
 await db.exec('update app_tiktok_dm.settings set enabled=true');
 await db.query('insert into app_tiktok_dm.testers(user_id,enabled) values($1,true)',[user]);
 await db.query(`insert into app_tiktok_dm.accounts(id,user_id,requested_username,verified_username,identity_id,identity_type,identity_authorized_bc_id,business_center_id,advertiser_id,asset_id,available_status,can_pull_video,can_manage_message,message_ads_eligible,status,access_token_env,owner_binding_proof,last_verified_at)
 values($1,$2,'fixture','fixture','500','BC_AUTH_TT','100','100','200','300','AVAILABLE',true,true,true,'CONNECTED','TIKTOK_FIXTURE_TOKEN','{"verified":true,"reference":"test-only"}',now())`,[account,user]);
 const ad=normalizeAd({title:'Report authority fixture',goal:'messages',message_destination:'direct_message',tiktok_account_id:account,tiktok_item_id:'987654321',category:'other',age_groups:['all'],gender:'all',location:'kurdistan',device_type:'all',customer_note:'',daily_budget:10,days:1,payment_method:'app_balance',start_immediately:true,start_date:null,start_time:null});
 const quote=await service('store_quote',null,null,{ad,config_hash:fingerprint(ad),evidence:{authorized:true,ready:true,account_id:account,declared_budget_usd:20,advertiser_timezone:'Asia/Baghdad',identity:{advertiser_id:'200'}}},user);
 const accepted=await role('authenticated',()=>scalar('select public.pa_submit_ad($1,$2::jsonb,$3,$4) v',[uuid(),JSON.stringify({...ad,tiktok_quote_id:quote.quote_id}),quote.cost_usd,quote.amount_iqd]));
 check(accepted.ok,'existing funded order fixture accepted');
 const job=await scalar('select id v from app_finance.outbox where ad_id=$1',[accepted.ad_id]),token=uuid();
 // Advance a synthetic completed fixture; never alter time in a live database.
 await db.exec('alter table public.pa_ads disable trigger tiktok_dm_order_binding');
 await db.query("update public.pa_ads set start_date=(now() at time zone 'Asia/Baghdad')::date-4,start_time='10:00',status='completed',completed_at=now()-interval '3 days',refund_eligible_at=now()-interval '3 days'+interval '2 hours' where id=$1",[accepted.ad_id]);
 await db.exec('alter table public.pa_ads enable trigger tiktok_dm_order_binding');
 await db.query("update app_finance.outbox set status='completed',provider_ids='{"+'"campaign":"1000","adgroup":"1001","ad":"1002"'+"}',lease_token=$2,lease_until=now()+interval '1 hour' where id=$1",[job,token]);
 const scope=(await db.query("select start_date::text as start_date,(completed_at at time zone 'Asia/Baghdad')::date::text as end_date from public.pa_ads where id=$1",[accepted.ad_id])).rows[0];
 const candidate={schema_version:1,source:'TIKTOK_OFFLINE_REPORT_CANDIDATE',api_version:'v1.3',advertiser_id:'200',adgroup_id:'1001',currency:'USD',scope:{...scope,timezone:'Asia/Baghdad'},query:{advertiser_id:'200',data_level:'AUCTION_ADGROUP',dimensions:['adgroup_id','ad_type','stat_time_day'],metrics:['spend']},captured_at:new Date().toISOString(),provider_published_at:null,earliest_candidate_at:new Date(Date.now()-86400000).toISOString(),latency_elapsed:true,pagination_complete:true,completeness_verified:false,settlement_verified:false,refund_authorized:false,finality_blocker:'PROVIDER_COMPLETENESS_CONTRACT_UNAVAILABLE',spend_usd:'9.9',unreported_dates:[],records:[{dimensions:{adgroup_id:'1001',ad_type:'AUCTION',stat_time_day:scope.end_date+' 00:00:00'},metrics:{spend:'9.9'}}],pages:[{page:1,page_size:100,total_page:1,total_number:1}]};
 candidate.evidence_hash=fingerprint(candidate);
 await denied('select * from app_tiktok_dm.report_candidates');
 await denied("select app_tiktok_dm.service_before_report_boundary('final_observe')");
 check((await service('ingest_report_candidate',job,uuid(),candidate)).code==='STALE_LEASE','candidate requires current worker lease');
 check((await service('ingest_report_candidate',job,token,candidate,other)).code==='JOB_NOT_FOUND','candidate cannot cross ownership');
 const stored=await service('ingest_report_candidate',job,token,candidate);check(stored.ok&&stored.candidate_id&&stored.settlement_verified===false,'actual report snapshot stored without financial finality');
 check((await service('ingest_report_candidate',job,token,candidate)).duplicate,'same evidence replay idempotent');
 check((await service('ingest_report_candidate',job,token,{...candidate,unreported_dates:[scope.start_date]})).code==='REPORT_EVIDENCE_CONFLICT','same hash different payload rejected');
 for(const patch of [{advertiser_id:'201'},{adgroup_id:'1009'},{currency:'IQD'},{scope:{...candidate.scope,timezone:'UTC'}},{completeness_verified:true},{settlement_verified:true},{refund_authorized:true},{provider_published_at:new Date().toISOString()},{spend_usd:'0'},{spend_usd:'NaN'},{records:[]},{pagination_complete:false},{captured_at:new Date(Date.now()-3600000).toISOString()}]){
  const response=await service('ingest_report_candidate',job,token,{...candidate,...patch,evidence_hash:fingerprint(patch)});check(response.ok===false,'invalid candidate rejected '+JSON.stringify(patch));
 }
 let immutable=false;try{await db.query('update app_tiktok_dm.report_candidates set reported_spend_usd=0 where id=$1',[stored.candidate_id]);}catch(e){immutable=e.message.includes('LEDGER_IMMUTABLE');}check(immutable,'report evidence is immutable');
 const lookup=await service('settlement_lookup',job,token);check(lookup.ok&&lookup.candidate_id===stored.candidate_id&&!lookup.settlement_verified,'stored report is not a settlement authority');
 check((await service('final_observe',job,token,{spend_usd:0,settlement_verified:true,paused:true,provider_ad_id:'1002',provider_adgroup_id:'1001',provider_observed_at:new Date().toISOString()})).code==='PROVIDER_COMPLETENESS_CONTRACT_UNAVAILABLE','manual service boolean cannot declare final spend');
 // Even historical equal samples/manual finality cannot authorize a known-ad
 // refund through the delegated old implementation.
 await db.query("update public.pa_ads set final_spend_usd=0,spend_reconciled_at=now() where id=$1",[accepted.ad_id]);
 await db.query("update app_finance.outbox set final_observation='{"+'"spend_usd":0,"settled":true,"paused":true'+"}' where id=$1",[job]);
 check((await service('refund',job)).code==='FINAL_SPEND_NOT_RECONCILED','legacy manual settled flag cannot release known-ad money');
 check(await scalar('select balance=90 v from public.pa_wallets where user_id=$1',[user]),'unverified finality never changes wallet');
 check(await scalar('select count(*)=0 v from app_finance.ledger where original_transaction_id=$1',[accepted.receipt_uid]),'no fabricated refund ledger event');
 const historicalRefund=uuid();
 await db.query('update public.pa_wallets set balance=balance+.1 where user_id=$1',[user]);
 await db.query("insert into public.pa_transactions(id,user_id,type,kind,method,status,amount,currency,ad_id,original_transaction_id) values($1,$2,'ad_unspent_refund','ad_unspent_refund','app_balance','approved',.1,'USD',$3,$4)",[historicalRefund,user,accepted.ad_id,accepted.receipt_uid]);
 await db.query("update public.pa_ads set unused_budget_refunded_at=now(),unused_budget_refund_usd=.1,unused_budget_refund_tx_id=$2 where id=$1",[accepted.ad_id,historicalRefund]);
 check((await service('refund',job)).already_refunded,'already committed historical refund recovers before new finality validation');
 check(await scalar('select balance=90.1 v from public.pa_wallets where user_id=$1',[user]),'historical refund recovery does not credit again');
 console.log(`PASS ${checks} TikTok report authority PostgreSQL assertions`);
}finally{await db.close();}
