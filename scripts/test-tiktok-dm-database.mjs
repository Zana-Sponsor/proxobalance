/** Isolated PostgreSQL tests; no provider requests or production connection.
 * PGLITE_MODULE=/absolute/node_modules/@electric-sql/pglite/dist/index.js node scripts/test-tiktok-dm-database.mjs
 */
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {normalizeAd,fingerprint} from '../api/_lib/tiktok/contract.js';
const {PGlite}=await import(process.env.PGLITE_MODULE?pathToFileURL(process.env.PGLITE_MODULE).href:'@electric-sql/pglite');
const db=new PGlite();let checks=0;
const read=p=>fs.readFile(new URL('../'+p,import.meta.url),'utf8');
const check=(v,m)=>{assert.ok(v,m);checks++;};
const scalar=async(sql,args=[])=> (await db.query(sql,args)).rows[0]?.v;
const user='11111111-1111-4111-8111-111111111111',other='22222222-2222-4222-8222-222222222222',session='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',otherSession='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const account='44444444-4444-4444-8444-444444444444',account2='55555555-5555-4555-8555-555555555555';
const uuid=()=>crypto.randomUUID();
async function role(name,fn,who=user,sid=session){await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:who,session_id:sid,role:name})]);await db.exec(`set role ${name}`);try{return await fn();}finally{await db.exec('reset role');}}
const service=(action,{userId=null,id=null,token=null,payload={}}={})=>role('service_role',()=>scalar('select public.pa_tiktok_dm_service($1,$2,$3,$4,$5::jsonb) v',[action,userId,id,token,JSON.stringify(payload)]));
const base=normalizeAd({title:'DM fixture',goal:'messages',message_destination:'direct_message',tiktok_account_id:account,tiktok_item_id:'987654321',category:'other',age_groups:['all'],gender:'all',location:'kurdistan',device_type:'all',customer_note:'',daily_budget:10,days:1,payment_method:'app_balance',start_immediately:true,start_date:null,start_time:null});
const quote=(ad=base)=>service('store_quote',{userId:user,payload:{ad,config_hash:fingerprint(ad),evidence:{authorized:true,ready:true,account_id:account,declared_budget_usd:20},promo_id:null,promo_code:null}});
const buy=(q,key=uuid(),ad=q.ad,who=user,sid=session)=>role('authenticated',()=>scalar('select public.pa_submit_ad($1,$2::jsonb,$3,$4) v',[key,JSON.stringify({...ad,tiktok_quote_id:q.quote_id}),q.cost_usd,q.amount_iqd]),who,sid);
async function denied(sql){let ok=false;try{await role('authenticated',()=>db.exec(sql));}catch(e){ok=e.code==='42501';}check(ok,sql);}
async function seedAccount(id,owner,identity,name='fixture'){await db.query(`insert into app_tiktok_dm.accounts(id,user_id,requested_username,verified_username,display_name,identity_id,identity_type,identity_authorized_bc_id,business_center_id,advertiser_id,asset_id,available_status,can_pull_video,can_manage_message,message_ads_eligible,status,access_token_env,owner_binding_proof,last_verified_at)
values($1,$2,$4,$4,$4,$3,'BC_AUTH_TT','100','100','200','300','AVAILABLE',true,true,true,'CONNECTED','TIKTOK_FIXTURE_TOKEN',$5::jsonb,now())`,[id,owner,identity,name,JSON.stringify({verified:true,reference:'fixture-owner-check',method:'INDEPENDENT_OWNER_VERIFICATION',proxo_user_id:owner,identity_id:identity,verified_username:name,verified_at:new Date().toISOString()})]);}
try{
 await db.exec(await read('test/fixtures/secure-operations-database.sql'));
 await db.exec(await read('proxo_app/supabase/migrations/20261016174350_secure_financial_operations.sql'));
 const checkout=await read('proxo_app/supabase/migrations/20260913210000_fastpay_ad_checkout.sql');
 await db.exec(checkout.slice(checkout.indexOf('create or replace function public.pa_quote_ad_checkout('),checkout.indexOf('revoke all on function public.pa_quote_ad_checkout(')));
 for(const name of ['20261022235825_meta_ads_private_v3.sql','20261023193522_tiktok_dm_private_v1.sql'])await db.exec(await read('proxo_app/supabase/migrations/'+name));
 await db.query('insert into auth.users(id,email_confirmed_at) values($1,now()),($2,now())',[user,other]);
 await db.query('insert into auth.sessions(id,user_id) values($1,$2),($3,$4)',[session,user,otherSession,other]);
 await db.query('insert into public.profiles(id) values($1),($2)',[user,other]);
 await db.query('update public.pa_wallets set balance=100 where user_id=$1',[user]);
 let flags=await role('authenticated',()=>scalar('select public.pa_ad_capabilities() v'));
 check(!flags.tiktok_dm_enabled&&!flags.tiktok_dm_fastpay_enabled&&!flags.tiktok_dm_seen,'default OFF and badge unseen');
 check((await quote()).code==='TIKTOK_DM_DISABLED','quote defaultOFF');
 check((await service('connect_start',{userId:user,payload:{username:'fixture'}})).code==='TIKTOK_AUTH_CORRELATION_UNAVAILABLE','no fake provider auth session');
 check(await scalar('select count(*)=0 v from app_tiktok_dm.connection_requests'),'unsupported auth does not persist invented session');
 await service('seen',{userId:user});
 check((await role('authenticated',()=>scalar('select public.pa_ad_capabilities() v'))).tiktok_dm_seen,'badge seen persists');
 check(!(await role('authenticated',()=>scalar('select public.pa_ad_capabilities() v'),other,otherSession)).tiktok_dm_seen,'badge owner isolation');
 await denied('select * from app_tiktok_dm.accounts');await denied("select public.pa_tiktok_dm_service('claim')");await denied('update app_tiktok_dm.settings set enabled=true');
 await db.exec('update app_tiktok_dm.settings set enabled=true');
 check((await quote()).code==='TIKTOK_DM_DISABLED','private tester allowlist required');
 await db.query('insert into app_tiktok_dm.testers(user_id,enabled) values($1,true),($2,true)',[user,other]);
 await seedAccount(account,user,'500');await seedAccount(account2,user,'501','fixture_two');
 check((await service('list_accounts',{userId:user})).accounts.length===2,'multiple accounts same user');
 check((await service('list_accounts',{userId:other})).accounts.length===0,'no crossowner list');
 check((await service('account',{userId:other,id:account})).code==='TIKTOK_ACCOUNT_NOT_FOUND','IDOR account denied');
 let unique=false;try{await seedAccount(uuid(),other,'500');}catch(e){unique=e.code==='23505';}check(unique,'global identity cannot be taken over');
 let mismatch=false;try{await db.query('update app_tiktok_dm.accounts set verified_username=$2 where id=$1',[account,'wrong']);}catch(e){mismatch=e.code==='23514';}check(mismatch,'wrong username never connected');
 await service('cache_videos',{userId:user,id:account,payload:{videos:[{item_id:'987654321',status:'ITEM_STATUS_HESITATE_RECOMMEND',ad_eligible:true,title:'Public'},{item_id:'9',status:'ITEM_STATUS_ONLY_AUTHOR_SEE',ad_eligible:true}]}});
 check((await service('videos',{userId:user,id:account})).videos.length===1,'only public eligible metadata cached');
 check((await service('videos',{userId:other,id:account})).code==='TIKTOK_ACCOUNT_NOT_FOUND','cache owner isolation');
 const q=await quote();check(q.ok&&Number(q.cost_usd)===10&&q.amount_iqd===18000,'reuses established server preview prices');
 check(await scalar('select balance=100 v from public.pa_wallets where user_id=$1',[user]),'quote read-only wallet');
 for(const extra of [{video_code:'manual'},{video_link:'https://www.tiktok.com/@x/video/1'},{asset_id:uuid()},{goal:'views'},{age_groups:['13-17']},{daily_budget:2}])check((await quote({...base,...extra})).code==='INVALID_DIRECT_MESSAGE_AD','reject mixed/manual invalid direct '+JSON.stringify(extra));
 check((await quote({...base,payment_method:'fastpay'})).code==='TIKTOK_DM_FASTPAY_UNAVAILABLE','FastPay stays gated until webhook binding verified');
 const key=uuid(),accepted=await buy(q,key);check(accepted.ok,'Direct accepted through existing pa_submit_ad');
 check(await scalar('select balance=90 v from public.pa_wallets where user_id=$1',[user]),'existing wallet debited exact once');
 check(await scalar("select video_link is null and video_code is null and asset_id is null and fulfillment_kind='tiktok_conversation_auto' and tiktok_account_id=$2 and tiktok_item_id='987654321' v from public.pa_ads where id=$1",[accepted.ad_id,account]),'no fake manual link/code/card; verified identity/item persisted');
 check(await scalar("select fulfillment_kind='tiktok_conversation_auto' and tiktok_quote_id=$2 v from app_finance.outbox where ad_id=$1",[accepted.ad_id,q.quote_id]),'same atomic outbox tagged automatic');
 check(await scalar('select proxo_total_budget_usd=10 and tiktok_declared_budget_usd=20 and spend_stop_threshold_usd=9.5 v from public.pa_ads where id=$1',[accepted.ad_id]),'declared provider budget separate from user and95percent stop');
 const captured=await scalar('select receipt_uid v from public.pa_ads where id=$1',[accepted.ad_id]);
 check(await scalar('select amount=-10 v from app_finance.ledger where transaction_id=$1',[captured]),'existing immutable debit ledger');
 await db.exec('update app_tiktok_dm.settings set enabled=false');assert.deepEqual(await buy(q,key),accepted);checks++;
 check((await buy(q,key,{...base,title:'Changed'})).code==='IDEMPOTENCY_CONFLICT','retry mismatch before gate');
 assert.deepEqual(await role('authenticated',()=>scalar('select public.pa_ad_submission_status($1) v',[key])),accepted);checks++;
 check(!(await role('authenticated',()=>scalar('select public.pa_ad_capabilities() v'))).tiktok_dm_enabled,'gate OFF prevents new acceptance capability');
 await db.exec('update app_tiktok_dm.settings set enabled=true');
 check((await buy(q)).code==='QUOTE_ALREADY_USED','quote only once');
 check((await buy(q,uuid(),base,other,otherSession)).code==='QUOTE_NOT_FOUND','crossowner quote blocked');
 check((await role('authenticated',()=>scalar('select public.pa_cancel_pending_ad($1,$2) v',[accepted.ad_id,'cancel']))).code==='TIKTOK_REFUND_REQUIRES_SERVER','legacy refund cannot bypass auto provider safeguards');
 const manual={title:'manual unchanged',goal:'views',category:'other',age_groups:['all'],gender:'all',location:'kurdistan',device_type:'all',daily_budget:10,days:1,start_immediately:true,payment_method:'app_balance',video_code:'actual-post-code',video_link:'https://www.tiktok.com/@fixture/video/123456789'};
 const manualResult=await role('authenticated',()=>scalar('select public.pa_submit_ad($1,$2::jsonb,10,18000) v',[uuid(),JSON.stringify(manual)]));check(manualResult.ok,'manual TikTok checkout unchanged');
 const manualJob=await role('service_role',()=>scalar('select public.pa_claim_ad_outbox() v'));check(manualJob.ad_id===manualResult.ad_id,'legacy claim only manual');
 const job=await service('claim',{payload:{kind:'create'}});check(job.ad_id===accepted.ad_id,'auto claim only direct Conversation');
 const hash='a'.repeat(64),token=job.lease_token;
 check((await service('intent',{id:job.id,token,payload:{stage:'activation',request_hash:hash}})).code==='INVALID_STAGE','no activation codepath');
 check((await service('intent',{id:job.id,token,payload:{stage:'adgroup',request_hash:hash}})).code==='INVALID_STAGE_ORDER','campaign first');
 for(const [stage,id] of [['campaign','1000'],['adgroup','1001'],['ad','1002']]){
  check((await service('intent',{id:job.id,token,payload:{stage,request_hash:hash}})).ok,stage+' intent');
  check((await service('intent',{id:job.id,token,payload:{stage,request_hash:hash}})).code==='PROVIDER_OUTCOME_UNKNOWN',stage+' ambiguous never re-created');
  check((await service('complete',{id:job.id,token,payload:{stage,provider_id:id,request_hash:hash}})).ok,stage+' ID durable');
 }
 check(await scalar("select tiktok_campaign_id='1000' and tiktok_adgroup_id='1001' and tiktok_ad_id='1002' v from public.pa_ads where id=$1",[accepted.ad_id]),'provider IDs automatically persisted');
 const observation=(spend=0,status='ADGROUP_STATUS_DISABLE',op='DISABLE')=>({operation_status:op,secondary_status:status,spend_usd:spend,provider_observed_at:new Date().toISOString(),provider_ad_id:'1002',provider_adgroup_id:'1001',paused:op==='DISABLE',metrics:{impressions:100}});
 check((await service('observe',{id:job.id,token,payload:{...observation(),provider_ad_id:'999'}})).code==='INVALID_OBSERVATION','wrong provider object cannot update order');
 check((await service('observe',{id:job.id,token,payload:{...observation(),spend_usd:null,metrics:{}}})).ok,'verified status persists despite unavailable spend report');
 check(await scalar("select provider_metrics_available='[]'::jsonb v from public.pa_ads where id=$1",[accepted.ad_id]),'status-only report never fabricates spend or metrics availability');
 check((await service('stop_intent',{id:job.id,token,payload:{reason:'budget_limit'}})).code==='STOP_NOT_ELIGIBLE','new budget stop requires explicit numeric current spend');
 check((await service('observe',{id:job.id,token,payload:observation(0,'ADGROUP_STATUS_AUDIT')})).status==='review','actual review maps existing review');
 check(await scalar("select provider_metrics_available ?& array['spend','impressions'] and not provider_metrics_available ? 'clicks' v from public.pa_ads where id=$1",[accepted.ad_id]),'metric availability reflects only actual fields, never fabricated zero clicks');
 // Advance only synthetic order fixture schedule, never production time/wallet.
 await db.exec('alter table public.pa_ads disable trigger tiktok_dm_order_binding');
 await db.query("update public.pa_ads set start_date=(now()-interval '1 hour')::date,start_time=(now()-interval '1 hour')::time where id=$1",[accepted.ad_id]);
 await db.exec('alter table public.pa_ads enable trigger tiktok_dm_order_binding');
 check((await service('observe',{id:job.id,token,payload:observation()})).status==='paused','manual provider disable is paused, not completed');
 check((await service('stop_intent',{id:job.id,token,payload:{reason:'budget_limit'}})).code==='STOP_NOT_ELIGIBLE','cannot stop as budget completion below threshold');
 check((await service('observe',{id:job.id,token,payload:observation(9.5,'ADGROUP_STATUS_DELIVERY_OK','ENABLE')})).status==='active','actual delivering maps active');
 check((await service('stop_intent',{id:job.id,token,payload:{reason:'budget_limit'}})).ok,'95percent threshold records durable stop intent');
 check((await service('pause_complete',{id:job.id,token,payload:{...observation(9.9),spend_usd:null,metrics:{}}})).status==='completed','durable budget stop completes from verified disable despite missing report');
 check(await scalar('select spend=9.5 and current_spend=9.5 v from public.pa_ads where id=$1',[accepted.ad_id]),'missing stop readback spend preserves last authoritative numeric value');
 check((await service('stop_intent',{id:job.id,token,payload:{reason:'budget_limit'}})).code==='STOP_NOT_ELIGIBLE','preserved older public spend is not fresh budget-stop evidence');
 check(await scalar('select refund_eligible_at=completed_at+interval \'2 hours\' v from public.pa_ads where id=$1',[accepted.ad_id]),'mandatory2h stored from confirmed completion');
 check((await service('refund',{id:job.id})).code==='REFUND_WAITING_PERIOD','cannot refund early');
 check((await service('observe',{id:job.id,token,payload:observation(9.9,'ADGROUP_STATUS_DELIVERY_OK','ENABLE')})).status==='completed','terminal completion cannot regress to active');
 await db.query("update public.pa_ads set completed_at=now()-interval '3 hours',refund_eligible_at=now()-interval '1 hour' where id=$1",[accepted.ad_id]);
 check((await service('refund',{id:job.id})).code==='FINAL_SPEND_NOT_RECONCILED','elapsed2h alone is not final-spend proof');
 const final={...observation(9.9),settlement_verified:true};
 check((await service('final_observe',{id:job.id,token,payload:final})).settled===false,'first final report samples, no premature refund');
 check((await service('final_observe',{id:job.id,token,payload:final})).settled===false,'immediate repeated report not stable30min');
 await db.query("update app_finance.outbox set final_observation=jsonb_set(final_observation,'{sample_started_at}',to_jsonb(now()-interval '31 minutes')) where id=$1",[job.id]);
 check((await service('final_observe',{id:job.id,token,payload:{...final,provider_observed_at:new Date().toISOString()}})).settled===true,'stable verified final spend after wait');
 const refunded=await service('refund',{id:accepted.ad_id,userId:user});check(refunded.ok&&Number(refunded.amount)===0.1,'10budget9.90spend returns0.10');
 check(await scalar('select balance=80.1 v from public.pa_wallets where user_id=$1',[user]),'one partial wallet credit (other manual debit preserved)');
 check(await scalar("select amount=10 and status='partially_refunded' v from public.pa_transactions where id=$1",[captured]),'original debit amount preserved partial status');
 check(await scalar('select count(*)=1 and sum(amount)=0.1 v from app_finance.ledger where original_transaction_id=$1',[captured]),'partial refund linked original ledger');
 check((await service('refund',{id:accepted.ad_id,userId:user})).already_refunded,'repeat returns original refund');
 check(await scalar('select balance=80.1 v from public.pa_wallets where user_id=$1',[user]),'no double refund');
 // Outbox failure must still roll back the existing checkout transaction.
 const rollbackQuote=await quote(),beforeBalance=await scalar('select balance v from public.pa_wallets where user_id=$1',[user]);
 const beforeAds=await scalar('select count(*) v from public.pa_ads'),beforeLedger=await scalar('select count(*) v from app_finance.ledger');
 await db.exec("create function app_tiktok_dm.fixture_fail_outbox() returns trigger language plpgsql as $$begin raise exception 'injected_auto_outbox_failure';end$$;create trigger fixture_fail_outbox before insert on app_finance.outbox for each row execute function app_tiktok_dm.fixture_fail_outbox()");
 let rolledBack=false;try{await buy(rollbackQuote);}catch(e){rolledBack=e.message.includes('injected_auto_outbox_failure');}check(rolledBack,'DM outbox failure injected');
 await db.exec('drop trigger fixture_fail_outbox on app_finance.outbox');
 check(await scalar('select balance v from public.pa_wallets where user_id=$1',[user])===beforeBalance,'DM failed outbox rolls wallet back');
 check(await scalar('select count(*) v from public.pa_ads')===beforeAds,'DM failed outbox rolls ad back');
 check(await scalar('select count(*) v from app_finance.ledger')===beforeLedger,'DM failed outbox rolls immutable debit back');
 // Private rollout OFF and exhausted preflight leases must remain recoverable.
 for(const exhausted of [false,true]) {
  const qSafe=await quote(),rSafe=await buy(qSafe),jSafe=await service('claim',{id:await scalar('select id v from app_finance.outbox where ad_id=$1',[rSafe.ad_id]),payload:{kind:'create'}});
  await db.query("update app_finance.outbox set lease_until=now()-interval '1 minute',attempts=$2 where id=$1",[jSafe.id,exhausted?8:1]);
  if(!exhausted)await db.exec('update app_tiktok_dm.settings set enabled=false');
  const jRecover=await service('claim',{id:jSafe.id,payload:{kind:'reconcile'}});
  check(jRecover?.terminal_failure===true,exhausted?'exhausted no-intent lease is recoverable':'gate-off expired no-intent lease is recoverable');
  check((await service('refund',{id:jSafe.id})).ok,'provably never-created funded order safely compensated');
  await db.exec('update app_tiktok_dm.settings set enabled=true');
 }
 // An unknown POST reconciled after rollout OFF becomes safe compensation
 // only after exact provider identity adoption removes every inflight stage.
 const unknownOrder=await buy(await quote()),unknownId=await scalar('select id v from app_finance.outbox where ad_id=$1',[unknownOrder.ad_id]);
 const unknownClaim=await service('claim',{id:unknownId,payload:{kind:'create'}});
 await service('intent',{id:unknownId,token:unknownClaim.lease_token,payload:{stage:'campaign',request_hash:hash}});
 await db.query("update app_finance.outbox set lease_until=now()-interval '1 minute' where id=$1",[unknownId]);
 await db.exec('update app_tiktok_dm.settings set enabled=false');
 const unknownRecovery=await service('claim',{id:unknownId,payload:{kind:'reconcile'}});
 check((await service('refund',{id:unknownId})).code==='PROVIDER_OUTCOME_UNKNOWN','unknown provider POST still blocks compensation gateOFF');
 await service('complete',{id:unknownId,token:unknownRecovery.lease_token,payload:{stage:'campaign',provider_id:'8100',request_hash:hash,reconciled:true}});
 await service('finish',{id:unknownId,token:unknownRecovery.lease_token,payload:{status:'pending'}});
 check((await service('job',{id:unknownId})).terminal_failure,'gate-off refuses recreate and records terminal disposition after reconciliation');
 await db.query('update app_finance.outbox set available_at=now() where id=$1',[unknownId]);
 const noAdRecovery=await service('claim',{id:unknownId,payload:{kind:'reconcile'}});
 await service('observe',{id:unknownId,token:noAdRecovery.lease_token,payload:{operation_status:'DISABLE',secondary_status:'',spend_usd:0,provider_observed_at:new Date().toISOString(),provider_ad_id:null,provider_adgroup_id:null,paused:true,metrics:{}}});
 check((await service('refund',{id:unknownId})).ok,'proved paused ancestors with no possible ad safely compensated');
 await db.exec('update app_tiktok_dm.settings set enabled=true');
 // Financial completion fixtures intentionally represent trusted final provider
 // observations. Arithmetic uses the captured customer payment, excluding the
 // larger provider declaration and any Proxo-funded discount/subsidy.
 let identityCounter=4000;
 async function finalFinancialCase(qFinal,expected,reported) {
  const result=await buy(qFinal),jobId=await scalar('select id v from app_finance.outbox where ad_id=$1',[result.ad_id]);
  const ids={campaign:String(++identityCounter),adgroup:String(++identityCounter),ad:String(++identityCounter)};
  await db.query("update public.pa_ads set status='completed',completed_at=now()-interval '3 hours',refund_eligible_at=now()-interval '1 hour' where id=$1",[result.ad_id]);
  await db.query("update app_finance.outbox set status='completed',provider_ids=$2::jsonb,available_at=now(),lease_until=null,lease_token=null,final_observation=jsonb_build_object('spend_usd',$3::numeric,'sample_started_at',now()-interval '31 minutes','settled',false) where id=$1",[jobId,JSON.stringify(ids),reported]);
  check(await service('claim',{id:jobId,payload:{kind:'status'}})===null,'status cannot starve refund-eligible job');
  check(await service('claim',{id:jobId,payload:{kind:'budget'}})===null,'budget cannot starve refund-eligible job');
  const claimed=await service('claim',{id:jobId,payload:{kind:'refund'}});check(claimed?.id===jobId,'refund claim succeeds after status/budget polling');
  const settled=await service('final_observe',{id:jobId,token:claimed.lease_token,payload:{spend_usd:reported,paused:true,provider_observed_at:new Date().toISOString(),provider_ad_id:ids.ad,provider_adgroup_id:ids.adgroup,settlement_verified:true}});
  check(settled.settled,'verified final report settles');
  const before=Number(await scalar('select balance v from public.pa_wallets where user_id=$1',[user]));
  const paid=await service('refund',{id:jobId});check(Number(paid.amount)===expected,'paid-media refund formula '+qFinal.cost_usd+' - '+reported);
  check(Number(await scalar('select balance v from public.pa_wallets where user_id=$1',[user]))===Math.round((before+expected)*1e6)/1e6,'no extra charge for provider overspend');
  return result;
 }
 await db.exec("insert into public.pa_levels(level_number,name_en,name_ku,min_points,discount_percent,discount_iqd) values(1,'Fixture','Fixture',0,20,0)");
 const discountQuote=await quote();check(Number(discountQuote.gross_usd)===10&&Number(discountQuote.cost_usd)===8,'existing discount retained in direct quote');
 await finalFinancialCase(discountQuote,0,9.9); // Gross10 does not create a subsidy refund.
 await finalFinancialCase(await quote(),0.1,7.9);
 await db.exec('delete from public.pa_levels');
 await finalFinancialCase(await quote(),0,10.15);
 const failedKnown=await buy(await quote()),failedKnownId=await scalar('select id v from app_finance.outbox where ad_id=$1',[failedKnown.ad_id]),failedToken=uuid();
 await db.query("update app_finance.outbox set status='reconcile',terminal_failure=true,provider_ids='{\"campaign\":\"6200\",\"adgroup\":\"6201\",\"ad\":\"6202\"}',lease_kind='reconcile',lease_token=$2,lease_until=now()+interval '2 minutes' where id=$1",[failedKnownId,failedToken]);
 check((await service('stop_intent',{id:failedKnownId,token:failedToken,payload:{reason:'provider_failure'}})).ok,'known-ad terminal failure permits safe stop');
 check((await service('pause_complete',{id:failedKnownId,token:failedToken,payload:{...observation(0),spend_usd:null,metrics:{},provider_ad_id:'6202',provider_adgroup_id:'6201'}})).status==='rejected','provider-failure stop preserves rejected customer status');
 check((await service('refund',{id:failedKnownId})).code==='REFUND_WAITING_PERIOD','known ad with unknown spend still requires final-report wait');
 check(await scalar("select not provider_metrics_available ? 'spend' v from public.pa_ads where id=$1",[failedKnown.ad_id]),'provider-failure stop does not publish unknown spend as zero');
 await db.query("update public.pa_ads set completed_at=now()-interval '3 hours',refund_eligible_at=now()-interval '1 hour' where id=$1",[failedKnown.ad_id]);
 check((await service('final_observe',{id:failedKnownId,token:failedToken,payload:{...observation(0),spend_usd:null,metrics:{},provider_ad_id:'6202',provider_adgroup_id:'6201',settlement_verified:true}})).code==='INVALID_OBSERVATION','nullable status report can never become a settled final spend');
 check((await service('refund',{id:failedKnownId})).code==='FINAL_SPEND_NOT_RECONCILED','unknown spend cannot fund a refund even after waiting');
 // End-of-schedule stop must remain possible when reporting is unavailable.
 const ended=await buy(await quote()),endedId=await scalar('select id v from app_finance.outbox where ad_id=$1',[ended.ad_id]),endedToken=uuid();
 await db.exec('alter table public.pa_ads disable trigger tiktok_dm_order_binding');
 await db.query("update public.pa_ads set start_date=(now()-interval '2 days')::date,start_time=(now()-interval '2 days')::time where id=$1",[ended.ad_id]);
 await db.exec('alter table public.pa_ads enable trigger tiktok_dm_order_binding');
 await db.query("update app_finance.outbox set status='completed',provider_ids='{\"campaign\":\"6300\",\"adgroup\":\"6301\",\"ad\":\"6302\"}',lease_kind='budget',lease_token=$2,lease_until=now()+interval '2 minutes' where id=$1",[endedId,endedToken]);
 const noReport={...observation(0),spend_usd:null,metrics:{},provider_ad_id:'6302',provider_adgroup_id:'6301'};
 check((await service('observe',{id:endedId,token:endedToken,payload:noReport})).ok,'scheduled-end observation accepts unknown spend');
 check((await service('stop_intent',{id:endedId,token:endedToken,payload:{reason:'scheduled_end'}})).ok,'trusted due schedule can request stop without spend report');
 check((await service('pause_complete',{id:endedId,token:endedToken,payload:noReport})).status==='completed','verified scheduled-end disable persists completion with unknown spend');
 check(await scalar("select provider_metrics_available='[]'::jsonb and final_spend_usd is null and spend_reconciled_at is null v from public.pa_ads where id=$1",[ended.ad_id]),'scheduled-end unknown report leaves all financial evidence unavailable');
 check((await service('refund',{id:endedId})).code==='REFUND_WAITING_PERIOD','scheduled-end pause proof alone cannot refund');
 // Incomplete/reconcile chains cannot be consumed by status polling.
 const partial=await buy(await quote()),partialId=await scalar('select id v from app_finance.outbox where ad_id=$1',[partial.ad_id]);
 await db.query("update app_finance.outbox set status='reconcile',provider_ids='{\"campaign\":\"9000\"}',stages='{\"adgroup\":{\"state\":\"rejected\"}}',terminal_failure=true,available_at=now() where id=$1",[partialId]);
 check(await service('claim',{id:partialId,payload:{kind:'status'}})===null,'incomplete reconcile chain not consumed by status');
 check((await service('claim',{id:partialId,payload:{kind:'reconcile'}}))?.id===partialId,'incomplete chain stays recoverable');
 check((await service('disconnect',{userId:user,id:account})).status==='REVOKING','disconnect persists intent before provider unlink');
 check(await scalar('select count(*)=0 v from app_tiktok_dm.video_cache where account_id=$1',[account]),'disconnect invalidates account cache');
 check((await quote()).code==='TIKTOK_ACCOUNT_UNAVAILABLE','REVOKING blocks new purchase');
 const disconnect=await service('claim',{payload:{kind:'account-disconnect'}});check(disconnect.id===account,'disconnect leased');
 check((await service('disconnect_complete',{id:account,token:disconnect.lease_token,payload:{advertiser_unlinked:false}})).code==='UNLINK_NOT_VERIFIED','timeout not confirmed unlink');
 check((await service('disconnect_complete',{id:account,token:disconnect.lease_token,payload:{advertiser_unlinked:true}})).ok,'verified unlink finalizes');
 check(await scalar('select count(*)=1 v from public.pa_ads where id=$1',[accepted.ad_id]),'disconnect preserves historical ad');
 console.log(`PASS ${checks} TikTok DM PostgreSQL integration assertions (disposable PGlite; no external calls).`);
}catch(error){console.error('FAIL',error.message,error.where||'',error.detail||'');process.exitCode=1;}finally{await db.close();}
