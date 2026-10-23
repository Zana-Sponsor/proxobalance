/** Disposable PostgreSQL activation journal tests. No network/provider calls.
 * PGLITE_MODULE=/absolute/@electric-sql/pglite/dist/index.js node scripts/test-tiktok-activation-database.mjs
 */
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {normalizeAd,fingerprint} from '../api/_lib/tiktok/contract.js';
const {PGlite}=await import(process.env.PGLITE_MODULE?pathToFileURL(process.env.PGLITE_MODULE).href:'@electric-sql/pglite');
const db=new PGlite();let checks=0,provider=7000;
const read=p=>fs.readFile(new URL('../'+p,import.meta.url),'utf8');
const check=(v,m)=>{assert.ok(v,m);checks++;};
const scalar=async(sql,args=[])=>(await db.query(sql,args)).rows[0]?.v;
const user='11111111-1111-4111-8111-111111111111',admin='22222222-2222-4222-8222-222222222222';
const session='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',adminSession='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const account='44444444-4444-4444-8444-444444444444',hash='a'.repeat(64);
const uuid=()=>crypto.randomUUID();
async function role(name,fn,who=user,sid=session,extra={}) {
 await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:who,session_id:sid,role:name,...extra})]);
 await db.exec(`set role ${name}`);try{return await fn();}finally{await db.exec('reset role');}
}
const service=(action,{id=null,token=null,userId=null,payload={}}={})=>role('service_role',()=>scalar('select public.pa_tiktok_dm_service($1,$2,$3,$4,$5::jsonb) v',[action,userId,id,token,JSON.stringify(payload)]));
const approve=(id,approval=uuid(),reason='Explicit approved fixture',who=admin,sid=adminSession)=>role('authenticated',()=>scalar('select public.pa_tiktok_dm_approve_activation($1,$2,$3) v',[id,approval,reason]),who,sid);
async function denied(fn,label){await assert.rejects(fn,e=>e.code==='42501',label);checks++;}
const observation=(ids)=>({operation_status:'DISABLE',secondary_status:'AD_STATUS_DISABLE',spend_usd:0,
 provider_observed_at:new Date().toISOString(),provider_ad_id:ids.ad,provider_adgroup_id:ids.adgroup,paused:true,chain_paused:true,
 raw_statuses:Object.fromEntries(['campaign','adgroup','ad'].map(stage=>[stage,{operation_status:'DISABLE',secondary_status:'AD_STATUS_DISABLE'}])),metrics:{spend_usd:0}});
const readback=(job,stage,op='ENABLE',extra={})=>({stage,provider_id:job.provider_ids[stage],operation_status:op,request_hash:hash,provider_observed_at:new Date().toISOString(),...extra});
const base=normalizeAd({title:'Activation fixture',goal:'messages',message_destination:'direct_message',tiktok_account_id:account,tiktok_item_id:'987654321',
 category:'other',age_groups:['all'],gender:'all',location:'kurdistan',device_type:'all',customer_note:'',daily_budget:10,days:1,payment_method:'app_balance',start_immediately:true,start_date:null,start_time:null});
async function fundedPausedJob() {
 const q=await service('store_quote',{userId:user,payload:{ad:base,config_hash:fingerprint(base),evidence:{authorized:true,ready:true,account_id:account,declared_budget_usd:20}}});
 assert.equal(q.ok,true);
 const accepted=await role('authenticated',()=>scalar('select public.pa_submit_ad($1,$2::jsonb,$3,$4) v',[uuid(),JSON.stringify({...base,tiktok_quote_id:q.quote_id}),q.cost_usd,q.amount_iqd]));
 assert.equal(accepted.ok,true);
 const id=await scalar('select id v from app_finance.outbox where ad_id=$1',[accepted.ad_id]);
 let job=await service('claim',{id,payload:{kind:'create'}});
 for(const stage of ['campaign','adgroup','ad']) {
  assert.equal((await service('intent',{id,token:job.lease_token,payload:{stage,request_hash:hash}})).ok,true);
  assert.equal((await service('complete',{id,token:job.lease_token,payload:{stage,provider_id:String(++provider),request_hash:hash}})).ok,true);
 }
 job=await service('job',{id});
 assert.equal((await service('observe',{id,token:job.lease_token,payload:observation(job.provider_ids)})).ok,true);
 assert.equal((await service('finish',{id,token:job.lease_token,payload:{status:'paused',creation_paused_verified:true}})).ok,true);
 return await service('job',{id});
}
async function claim(id){await db.query('update app_finance.outbox set activation_available_at=now() where id=$1',[id]);return service('claim',{id,payload:{kind:'activate'}});}
try {
 await db.exec(await read('test/fixtures/secure-operations-database.sql'));
 await db.exec(await read('proxo_app/supabase/migrations/20261016174350_secure_financial_operations.sql'));
 const checkout=await read('proxo_app/supabase/migrations/20260913210000_fastpay_ad_checkout.sql');
 await db.exec(checkout.slice(checkout.indexOf('create or replace function public.pa_quote_ad_checkout('),checkout.indexOf('revoke all on function public.pa_quote_ad_checkout(')));
 // Read-only live introspection verified this exact existing admin model. The
 // disposable baseline fixture has the profile columns but omitted its helper.
 await db.exec("create function public.is_admin() returns boolean language sql security definer set search_path='public' as $$ select coalesce((select coalesce(p.is_admin,false) and not coalesce(p.is_banned,false) from public.profiles p where p.id=auth.uid()),false) $$");
 // Apply the complete additive stack in deployment order: the activation
 // wrapper must coexist with OAuth, immutable payment attempts and reporting.
 const migrationDirectory=new URL('../proxo_app/supabase/migrations/',import.meta.url);
 for(const name of (await fs.readdir(migrationDirectory)).filter(name=>name>='20261022235825_'&&name.endsWith('.sql')).sort())
  await db.exec(await read('proxo_app/supabase/migrations/'+name));
 await db.query('insert into auth.users(id,email_confirmed_at) values($1,now()),($2,now())',[user,admin]);
 await db.query('insert into auth.sessions(id,user_id) values($1,$2),($3,$4)',[session,user,adminSession,admin]);
 await db.query('insert into public.profiles(id,is_admin) values($1,false),($2,true)',[user,admin]);
 await db.query('update public.pa_wallets set balance=100 where user_id=$1',[user]);
 check(await scalar('select not activation_enabled v from app_tiktok_dm.settings'),'activation defaults OFF');
 await db.exec('update app_tiktok_dm.settings set enabled=true');
 await db.query('insert into app_tiktok_dm.testers(user_id,enabled) values($1,true)',[user]);
 await db.query(`insert into app_tiktok_dm.accounts(id,user_id,requested_username,verified_username,identity_id,identity_type,identity_authorized_bc_id,business_center_id,advertiser_id,asset_id,
 available_status,can_pull_video,can_manage_message,message_ads_eligible,status,access_token_env,owner_binding_proof,last_verified_at)
 values($1,$2,'fixture','fixture','500','BC_AUTH_TT','100','100','200','300','AVAILABLE',true,true,true,'CONNECTED','TIKTOK_FIXTURE_TOKEN',$3::jsonb,now())`,
 [account,user,JSON.stringify({verified:true,reference:'synthetic-owner-proof',method:'INDEPENDENT_OWNER_VERIFICATION',proxo_user_id:user,identity_id:'500',verified_username:'fixture',verified_at:new Date().toISOString()})]);
 let job=await fundedPausedJob();const id=job.id,approval=uuid(),startingStatus=job.canonical_status;
 check((await approve(id,approval)).code==='TIKTOK_ACTIVATION_DISABLED','admin approval cannot bypass disabled rollout');
 check(await scalar('select count(*)=0 v from app_tiktok_dm.activation_approvals'),'OFF approval leaves no inert authorization');
 check((await approve(id,approval,'Explicit approved fixture',user,session)).code==='ADMIN_REQUIRED','ordinary owner cannot approve activation');
 check((await role('authenticated',()=>scalar('select public.pa_tiktok_dm_approve_activation($1,$2,$3) v',[id,approval,'Spoof']),user,session,{user_metadata:{is_admin:true},app_metadata:{is_admin:true}})).code==='ADMIN_REQUIRED','JWT metadata cannot mint admin authority');
 await denied(()=>role('anon',()=>scalar('select public.pa_tiktok_dm_approve_activation($1,$2,$3) v',[id,approval,'Denied'])),'anonymous approval denied');
 await denied(()=>role('service_role',()=>scalar('select public.pa_tiktok_dm_approve_activation($1,$2,$3) v',[id,approval,'Denied'])),'service role cannot impersonate admin approval');
 await denied(()=>approve(id,approval,'Missing session',admin,uuid()),'revoked/missing administrator session denied');
 await denied(()=>role('authenticated',()=>db.exec('select * from app_tiktok_dm.activation_approvals')),'private approvals not client-readable');
 await denied(()=>role('authenticated',()=>scalar("select public.pa_tiktok_dm_service('claim',null,null,null,'{\"kind\":\"activate\"}') v")),'authenticated users cannot call activation worker service');
 await db.exec('update app_tiktok_dm.settings set activation_enabled=true');
 const saved=await scalar('select observation v from app_finance.outbox where id=$1',[id]);
 await db.query("update app_finance.outbox set observation=jsonb_set(observation,'{raw_statuses,ad,operation_status}','\"ENABLE\"') where id=$1",[id]);
 check((await approve(id,approval)).code==='ACTIVATION_PAUSE_PROOF_REQUIRED','approval requires every exact ancestor disabled');
 await db.query('update app_finance.outbox set observation=$2::jsonb where id=$1',[id,JSON.stringify(saved)]);
 check((await approve(id,approval)).ok,'admin approval binds funded paused exact job');
 check((await approve(id,approval)).already_approved,'approval response retry is idempotent');
 check((await approve(id,approval,'Changed purpose')).code==='IDEMPOTENCY_CONFLICT','approval key cannot change purpose');
 check(await scalar("select snapshot->>'debit_id'=(select receipt_uid::text from public.pa_ads where id=$2) and snapshot->>'quote_id'=$3 and snapshot->'provider_ids'=$4::jsonb v from app_tiktok_dm.activation_approvals where id=$1",[approval,job.ad_id,job.quote_id,JSON.stringify(job.provider_ids)]),'approval binds original debit quote and provider chain');
 await denied(()=>db.exec('update app_tiktok_dm.activation_approvals set reason=\'tamper\''),'immutable approval cannot be edited even by database owner');
 job=await claim(id);check(job.activation_can_mutate&&job.activation_approval.id===approval,'activation claim returns exact immutable approval');
 const token=job.lease_token;
 check((await service('activation_intent',{id,token,payload:{stage:'campaign',request_hash:hash}})).code==='INVALID_ACTIVATION_STAGE_ORDER','campaign enables last');
 await db.query('update public.profiles set is_admin=false where id=$1',[admin]);
 check((await service('activation_intent',{id,token,payload:{stage:'ad',request_hash:hash}})).code==='TIKTOK_ACTIVATION_DISABLED','revoked administrator cannot start new effects');
 await db.query('update public.profiles set is_admin=true where id=$1',[admin]);
 await db.query("update app_finance.outbox set provider_ids=jsonb_set(provider_ids,'{ad}','\"9999\"') where id=$1",[id]);
 check((await service('activation_intent',{id,token,payload:{stage:'ad',request_hash:hash}})).code==='TIKTOK_ACTIVATION_DISABLED','provider ID drift invalidates immutable approval');
 await db.query('update app_finance.outbox set provider_ids=$2::jsonb where id=$1',[id,JSON.stringify(job.provider_ids)]);
 await db.query("update public.pa_transactions set status='refund_pending' where id=(select receipt_uid from public.pa_ads where id=$1)",[job.ad_id]);
 check((await service('activation_intent',{id,token,payload:{stage:'ad',request_hash:hash}})).code==='TIKTOK_ACTIVATION_DISABLED','pending refund invalidates paid activation');
 await db.query("update public.pa_transactions set status='approved' where id=(select receipt_uid from public.pa_ads where id=$1)",[job.ad_id]);
 check((await service('activation_intent',{id,token,payload:{stage:'ad',request_hash:hash}})).ok,'ad enable intent persists before provider write');
 check((await service('activation_intent',{id,token,payload:{stage:'ad',request_hash:hash}})).code==='ACTIVATION_OUTCOME_UNKNOWN','unknown enable cannot blindly repeat');
 check(['ACTIVATION_OUTCOME_UNKNOWN','FINAL_SPEND_NOT_RECONCILED'].includes((await service('refund',{id})).code),'unknown enable blocks refund through the full wrapper stack');
 check(['ACTIVATION_OUTCOME_UNKNOWN','PROVIDER_COMPLETENESS_CONTRACT_UNAVAILABLE'].includes((await service('final_observe',{id,token,payload:observation(job.provider_ids)})).code),'unknown enable blocks final financial evidence through the full wrapper stack');
 check((await service('activation_complete',{id,token,payload:readback(job,'ad','ENABLE',{provider_id:'9999'})})).code==='INVALID_ACTIVATION_OBSERVATION','wrong provider readback rejected');
 check((await service('activation_complete',{id,token,payload:readback(job,'ad','ENABLE',{provider_observed_at:new Date(Date.now()-3600000).toISOString()})})).code==='INVALID_ACTIVATION_OBSERVATION','stale readback rejected');
 await db.exec('update app_tiktok_dm.settings set activation_enabled=false');
 check((await service('activation_complete',{id,token,payload:readback(job,'ad','ENABLE',{reconciled:true})})).ok,'actual ENABLE evidence persists after gate OFF');
 check((await service('activation_complete',{id,token,payload:readback(job,'ad','ENABLE',{reconciled:true})})).already_recorded,'duplicate readback adds no repeated effect');
 check((await service('activation_intent',{id,token,payload:{stage:'adgroup',request_hash:hash}})).code==='TIKTOK_ACTIVATION_DISABLED','gate OFF blocks next stage');
 await service('finish',{id,token,payload:{status:'completed'}});
 check(await claim(id)===null,'gate OFF does not claim a new activation stage');
 await db.exec('update app_tiktok_dm.settings set activation_enabled=true');job=await claim(id);
 check((await service('activation_intent',{id,token:job.lease_token,payload:{stage:'adgroup',request_hash:hash}})).ok,'ad group follows durable ad confirmation');
 const oldToken=job.lease_token;
 await db.query("update app_finance.outbox set lease_until=now()-interval '1 second' where id=$1",[id]);
 await db.exec('update app_tiktok_dm.settings set activation_enabled=false');job=await claim(id);
 check(!job.activation_can_mutate&&job.activation_stages.adgroup.state==='inflight','gate OFF still claims uncertain effect for read-only recovery');
 check((await service('activation_complete',{id,token:oldToken,payload:readback(job,'adgroup')})).code==='STALE_LEASE','superseded lease cannot acknowledge effect');
 check((await service('activation_reconcile',{id,token:job.lease_token,payload:readback(job,'adgroup','DISABLE',{reconciled:true})})).ok,'exact disabled readback reconciles unknown effect');
 check((await service('activation_intent',{id,token:job.lease_token,payload:{stage:'adgroup',request_hash:hash}})).code==='TIKTOK_ACTIVATION_DISABLED','disabled readback never bypasses OFF gate');
 await service('finish',{id,token:job.lease_token,payload:{status:'reconcile'}});
 await db.exec('update app_tiktok_dm.settings set activation_enabled=true');job=await claim(id);
 check((await service('activation_intent',{id,token:job.lease_token,payload:{stage:'adgroup',request_hash:'b'.repeat(64)}})).code==='ACTIVATION_INTENT_CONFLICT','retry keeps original semantic hash');
 check((await service('activation_intent',{id,token:job.lease_token,payload:{stage:'adgroup',request_hash:hash}})).ok,'confirmed inactive exact effect may retry');
 check((await service('activation_complete',{id,token:job.lease_token,payload:readback(job,'adgroup')})).ok,'group readback persisted');
 check((await service('activation_intent',{id,token:job.lease_token,payload:{stage:'campaign',request_hash:hash}})).ok,'campaign intent only after both children durable');
 check((await service('activation_complete',{id,token:job.lease_token,payload:readback(job,'campaign')})).ok,'last exact provider readback persisted');
 await service('finish',{id,token:job.lease_token,payload:{status:'completed'}});
 check(await scalar("select activation_status='completed' and status='completed' and lease_token is null v from app_finance.outbox where id=$1",[id]),'activation completes on same financial outbox');
 check(await claim(id)===null,'completed activation never automatically re-enables');
 check(await scalar('select count(*)=8 v from app_tiktok_dm.activation_events where job_id=$1',[id]),'append-only audit retains intent and reconciliation attempts exactly once');
 await denied(()=>db.exec('delete from app_tiktok_dm.activation_events'),'activation audit cannot be deleted');
 check(await scalar('select balance=90 v from public.pa_wallets where user_id=$1',[user]),'activation never changes wallet');
 check(await scalar('select count(*)=1 and sum(amount)=-10 v from app_finance.ledger where user_id=$1',[user]),'activation never duplicates debit or creates refund');
 check(await scalar('select status=$2 v from public.pa_ads where id=$1',[job.ad_id,startingStatus]),'activation journal alone does not invent live status');
 // A rejected order cannot leave a partial approval from a failed statement.
 const rejected=await fundedPausedJob(),rejectedApproval=uuid();
 await db.query("update public.pa_ads set status='rejected' where id=$1",[rejected.ad_id]);
 check((await approve(rejected.id,rejectedApproval)).code==='ACTIVATION_NOT_READY','terminal rejected order cannot be approved');
 check(await scalar('select count(*)=0 v from app_tiktok_dm.activation_approvals where id=$1',[rejectedApproval]),'failed approval rolls immutable record back');
 check(await scalar('select activation_approval_id is null v from app_finance.outbox where id=$1',[rejected.id]),'failed approval rolls outbox reference back');
 // Approval replay cannot target another paid order, and creation leases are
 // shared with activation to prevent overlapping effect workers.
 let later=await fundedPausedJob();
 check((await approve(later.id,approval)).code==='IDEMPOTENCY_CONFLICT','approval ID cannot authorize a different job');
 const laterApproval=uuid();
 await db.query("update app_finance.outbox set lease_token=$2,lease_kind='status',lease_until=now()+interval '1 minute' where id=$1",[later.id,uuid()]);
 check((await approve(later.id,laterApproval)).code==='ACTIVATION_NOT_READY','approval waits for active observation lease');
 await db.query('update app_finance.outbox set lease_token=null,lease_until=null where id=$1',[later.id]);
 check((await approve(later.id,laterApproval)).ok,'fresh second order can be approved explicitly');
 later=await claim(later.id);
 check(await claim(later.id)===null,'activation claims are exclusive while lease is live');
 check((await service('activation_complete',{id:later.id,token:later.lease_token,payload:readback(later,'ad')})).code==='INVALID_ACTIVATION_OBSERVATION','readback without prior durable intent rejected');
 await db.query("update app_finance.outbox set lease_until=now()-interval '1 second' where id=$1",[later.id]);
 check((await service('activation_intent',{id:later.id,token:later.lease_token,payload:{stage:'ad',request_hash:hash}})).code==='STALE_LEASE','expired lease cannot authorize enable');
 later=await claim(later.id);
 await db.query('update public.pa_ads set current_spend=spend_stop_threshold_usd where id=$1',[later.ad_id]);
 check((await service('activation_intent',{id:later.id,token:later.lease_token,payload:{stage:'ad',request_hash:hash}})).code==='TIKTOK_ACTIVATION_DISABLED','known threshold spend cannot be reactivated before stop worker runs');
 await db.query('update public.pa_ads set current_spend=0 where id=$1',[later.ad_id]);
 check((await service('activation_intent',{id:later.id,token:later.lease_token,payload:{stage:'ad',request_hash:hash}})).ok,'valid reclaimed lease records new intent');
 check((await service('activation_reconcile',{id:later.id,token:later.lease_token,payload:readback(later,'ad','DISABLE')})).code==='INVALID_ACTIVATION_OBSERVATION','inactive recovery requires explicit reconciliation evidence');
 check((await service('activation_complete',{id:later.id,token:later.lease_token,payload:readback(later,'ad','ENABLE',{request_hash:'b'.repeat(64)})})).code==='INVALID_ACTIVATION_OBSERVATION','readback hash must match exact prior intent');
 check((await service('activation_complete',{id:later.id,token:later.lease_token,payload:readback(later,'ad','ENABLE',{provider_observed_at:new Date(Date.now()+3600000).toISOString()})})).code==='INVALID_ACTIVATION_OBSERVATION','future-dated readback rejected');
 await db.query('update public.profiles set is_banned=true where id=$1',[admin]);
 await service('activation_complete',{id:later.id,token:later.lease_token,payload:readback(later,'ad','ENABLE',{reconciled:true})});
 check((await service('activation_intent',{id:later.id,token:later.lease_token,payload:{stage:'adgroup',request_hash:hash}})).code==='TIKTOK_ACTIVATION_DISABLED','administrator ban prevents any subsequent stage');
 check(await scalar('select count(*)=3 and sum(amount)=-30 v from app_finance.ledger where user_id=$1',[user]),'all activation failure scenarios preserve exactly the three original debits');
 console.log(`PASS ${checks} TikTok activation PostgreSQL assertions (disposable PGlite; no external calls).`);
} finally {await db.close();}
