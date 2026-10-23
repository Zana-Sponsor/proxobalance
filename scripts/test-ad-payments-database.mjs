/** Isolated PostgreSQL transaction tests. No gateway request or real money. */
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {normalizeAd,fingerprint} from '../api/_lib/tiktok/contract.js';
import {normalizeConfiguration,unavailableForecast} from '../api/_lib/meta/contract.js';
const {PGlite}=await import(process.env.PGLITE_MODULE?pathToFileURL(process.env.PGLITE_MODULE).href:'@electric-sql/pglite');
const db=new PGlite();let checks=0;
const read=p=>fs.readFile(new URL('../'+p,import.meta.url),'utf8');
const check=(v,m)=>{assert.ok(v,m);checks++;};
const scalar=async(sql,args=[])=> (await db.query(sql,args)).rows[0]?.v;
const user='11111111-1111-4111-8111-111111111111',other='22222222-2222-4222-8222-222222222222',session='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',otherSession='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const account='44444444-4444-4444-8444-444444444444',conn='55555555-5555-4555-8555-555555555555';
const uuid=()=>crypto.randomUUID();
async function role(name,fn,who=user,sid=session){await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:who,session_id:sid,role:name})]);await db.exec(`set role ${name}`);try{return await fn();}finally{await db.exec('reset role');}}
const tiktok=(action,payload={},id=null)=>role('service_role',()=>scalar('select public.pa_tiktok_dm_service($1,$2,$3,null,$4::jsonb) v',[action,user,id,JSON.stringify(payload)]));
const meta=(action,payload={})=>role('service_role',()=>scalar('select public.pa_meta_service($1,$2,null,null,$3::jsonb) v',[action,user,JSON.stringify(payload)]));
const service=(action,id=null,payload={})=>role('service_role',()=>scalar('select public.pa_ad_payment_service($1,$2,$3::jsonb) v',[action,id,JSON.stringify(payload)]));
const base=normalizeAd({title:'Immutable payment fixture',goal:'messages',message_destination:'direct_message',tiktok_account_id:account,tiktok_item_id:'987654321',category:'other',age_groups:['all'],gender:'all',location:'kurdistan',device_type:'all',customer_note:'',daily_budget:10,days:1,payment_method:'fastpay',start_immediately:true,start_date:null,start_time:null});
const quote=(ad=base)=>tiktok('store_quote',{ad,config_hash:fingerprint(ad),evidence:{authorized:true,ready:true,account_id:account,declared_budget_usd:20}});
const attempt=(q,key=uuid(),platform='TIKTOK',who=user,sid=session)=>role('authenticated',()=>scalar('select public.pa_ad_payment_attempt($1,$2,$3,$4,$5) v',[key,platform,q.quote_id,q.cost_usd,q.amount_iqd]),who,sid);
const verified=(a,extra={})=>({order_id:a.order_id,environment:'sandbox',merchant_reference:'fixture-merchant',status:'PAID',gateway_transaction_id:uuid(),amount_iqd:a.amount_iqd,currency:'IQD',verified_at:new Date().toISOString(),response_sha256:fingerprint({a:a.attempt_id,n:uuid()}),verification_source:'FASTPAY_VALIDATE',...extra});
async function denied(sql){let ok=false;try{await role('authenticated',()=>db.exec(sql));}catch(e){ok=e.code==='42501';}check(ok,sql);}
async function fails(sql,args,code){let hit=false;try{await db.query(sql,args);}catch(e){hit=e.message.includes(code);}check(hit,code);}
try{
 await db.exec(await read('test/fixtures/secure-operations-database.sql'));
 await db.exec(await read('proxo_app/supabase/migrations/20261016174350_secure_financial_operations.sql'));
 // Sentinel legacy definitions prove wrappers delegate unchanged for unbound
 // orders, and refuse bound orders before these historical writers execute.
 await db.exec(`create function public.fastpay_create_order(uuid,text,numeric,text default 'IQD',text default null,text default null,integer default 10,text default null) returns jsonb language sql as $$select '{"legacy_create":true}'::jsonb$$;
 create function public.fastpay_apply_refund(text,numeric,text default null,boolean default true,jsonb default null) returns jsonb language sql as $$select '{"legacy_refund":true}'::jsonb$$;`);
 const checkout=await read('proxo_app/supabase/migrations/20260913210000_fastpay_ad_checkout.sql');
 await db.exec(checkout.slice(checkout.indexOf('create or replace function public.pa_quote_ad_checkout('),checkout.indexOf('revoke all on function public.pa_quote_ad_checkout(')));
 const migrations=(await fs.readdir(new URL('../proxo_app/supabase/migrations/',import.meta.url))).filter(n=>/^2026102[23].*\.sql$/.test(n)).sort();
 for(const name of migrations){const source=await read('proxo_app/supabase/migrations/'+name);if(source.trim())await db.exec(source);}
 await db.query('insert into auth.users(id,email_confirmed_at) values($1,now()),($2,now())',[user,other]);
 await db.query('insert into auth.sessions(id,user_id) values($1,$2),($3,$4)',[session,user,otherSession,other]);
 await db.query('insert into public.profiles(id) values($1),($2)',[user,other]);
 await db.query('update public.pa_wallets set balance=100 where user_id=$1',[user]);
 await denied('select * from app_finance.ad_payment_attempts');
 await denied("select public.pa_ad_payment_service('claim_reconcile')");
 await denied("select app_finance.commit_paid_ad(gen_random_uuid())");
 await db.exec('update app_tiktok_dm.settings set enabled=true,fastpay_enabled=true;update app_meta.settings set enabled=true,fastpay_enabled=true;');
 await db.query('insert into app_tiktok_dm.testers(user_id,enabled) values($1,true),($2,true)',[user,other]);
 await db.query('insert into app_meta.testers(user_id,enabled) values($1,true)',[user]);
 await db.query(`insert into app_tiktok_dm.accounts(id,user_id,requested_username,verified_username,identity_id,identity_type,identity_authorized_bc_id,business_center_id,advertiser_id,asset_id,available_status,can_pull_video,can_manage_message,message_ads_eligible,status,access_token_env,owner_binding_proof,last_verified_at)
 values($1,$2,'fixture','fixture','500','BC_AUTH_TT','100','100','200','300','AVAILABLE',true,true,true,'CONNECTED','TIKTOK_FIXTURE_TOKEN','{"verified":true,"reference":"test-only"}',now())`,[account,user]);
 const q=await quote(),key=uuid();check(q.ok,'quote fixture');
 check((await attempt(q,key)).code==='AD_FASTPAY_UNAVAILABLE','new gateway gate defaults OFF');
 await db.exec("update app_finance.ad_payment_settings set enabled=true,merchant_reference='fixture-merchant'");
 check((await attempt(q,uuid(),'TIKTOK',other,otherSession)).code==='QUOTE_NOT_FOUND','quote owner isolation');
 const a=await attempt(q,key);check(a.ok&&a.amount_iqd===18000&&Number(a.cost_usd)===10,'immutable attempt accepted');
 check((await role('authenticated',()=>scalar('select public.pa_ad_payment_status($1) v',[a.attempt_id]),other,otherSession)).code==='PAYMENT_ATTEMPT_NOT_FOUND','paymentstatus ownership isolation');
 check((await role('authenticated',()=>scalar('select public.pa_ad_payment_cancel($1) v',[a.attempt_id]),other,otherSession)).code==='PAYMENT_ATTEMPT_NOT_FOUND','paymentcancel ownership isolation');
 check(!('lease_token' in a)&&!('merchant_reference'in a),'user result omits internal lease and merchant');
 check((await role('authenticated',()=>scalar('select public.pa_ad_payment_status(p_submission_id=>$1) v',[key]))).attempt_id===a.attempt_id,'restart recovery by submission ID');
 check((await service('finish_reconcile',a.attempt_id,{})).code==='STALE_LEASE','missing lease never completes reconciliation');
 check(await scalar('select balance=100 v from public.pa_wallets where user_id=$1',[user]),'attempt creates no funding/debit');
 check(await scalar('select count(*)=0 v from public.pa_ads'),'attempt creates no ad or providerjob');
 assert.deepEqual(await attempt(q,key),a);checks++;
 check((await attempt({...q,cost_usd:11},key)).code==='IDEMPOTENCY_CONFLICT','submission cannot change price');
 check((await attempt(q)).code==='QUOTE_ALREADY_USED','quote cannot start a second charge');
 await fails('update app_finance.ad_payment_attempts set cost_usd=9 where id=$1',[a.attempt_id],'AD_PAYMENT_ATTEMPT_IMMUTABLE');
 await fails('update public.pa_transactions set amount=9 where id=$1',[a.transaction_id],'AD_PAYMENT_BINDING_IMMUTABLE');
 await fails('update public.pa_transactions set user_id=$2 where id=$1',[a.transaction_id,other],'AD_PAYMENT_BINDING_IMMUTABLE');
 check((await service('qr_created',a.attempt_id,{request_hash:'a'.repeat(64),qr_url:'https://example.invalid/qr',qr_text:'opaque'})).code==='CREATION_INTENT_REQUIRED','gatewayresult requires durable intent');
 check((await service('create_intent',a.attempt_id,{request_hash:'a'.repeat(64)})).create_authorized===true,'persist intent before gatewayPOST');
 check((await service('create_intent',a.attempt_id,{request_hash:'a'.repeat(64)})).must_reconcile===true,'lost create response cannot authorize a second POST');
 await service('unknown',a.attempt_id,{error_code:'GATEWAY_TIMEOUT'});
 check((await service('create_intent',a.attempt_id,{request_hash:'b'.repeat(64)})).must_reconcile===true,'unknown outcome remains reconcile');
 check((await service('qr_created',a.attempt_id,{request_hash:'a'.repeat(64),qr_url:'https://example.invalid/qr',qr_text:'opaque'})).status==='awaiting','recovered exact QR persists');
 check((await service('qr_created',a.attempt_id,{request_hash:'a'.repeat(64),qr_url:'https://example.invalid/qr',qr_text:'different'})).code==='GATEWAY_QR_CONFLICT','same attempt cannot silently replace QR');
 const proof=verified(a);
 for(const patch of [{amount_iqd:18001},{currency:'USD'},{environment:'production'},{order_id:'other'},{merchant_reference:'other'},{verification_source:'IPN_BODY'},{verified_at:new Date(Date.now()-600000).toISOString()},{gateway_transaction_id:null}])
  check((await service('observe_verified',a.attempt_id,{...proof,...patch})).code==='INVALID_GATEWAY_VERIFICATION','invalid verification '+JSON.stringify(patch));
 check((await role('service_role',()=>scalar('select public.fastpay_mark_paid($1,$2,$3,$4) v',[a.order_id,proof.gateway_transaction_id,18000,'IQD']))).code==='AD_PAYMENT_VERIFICATION_REQUIRED','old wallet-only callback blocked for bound ad');
 check((await role('service_role',()=>scalar('select public.fastpay_create_order($1,$2,18000) v',[user,a.order_id]))).code==='AD_PAYMENT_ATTEMPT_REQUIRED','legacy mutable gateway create cannot reuse immutable order');
 check((await role('service_role',()=>scalar('select public.fastpay_apply_refund($1,18000) v',[a.order_id]))).code==='AD_REFUND_REQUIRES_RECONCILIATION','legacy wallet or cash refund cannot bypass ad compensation');
 check((await role('service_role',()=>scalar("select public.fastpay_create_order($1,'unbound-order',18000) v",[user]))).legacy_create,'legacy create delegates unchanged');
 check((await role('service_role',()=>scalar("select public.fastpay_apply_refund('unbound-order',18000) v"))).legacy_refund,'legacy refund delegates unchanged');
 for(const order of ['AP'+'F'.repeat(28),'ap'+'f'.repeat(28),' AP'+'F'.repeat(28),null,'bad'])check((await role('service_role',()=>scalar('select public.pa_legacy_fastpay_guard($1) v',[order]))).legacy_allowed===false,'reserved or invalid gateway namespace blocked before attempt exists');
 check((await role('service_role',()=>scalar('select public.pa_legacy_fastpay_guard(null,$1) v',[a.transaction_id]))).immutable_ad_payment,'legacy guard resolves exact transaction binding');
 check(await role('service_role',()=>scalar('select count(*)=0 v from public.fastpay_orders_to_poll() where id=$1',[a.transaction_id])),'legacy polling excludes automatic attempt');
 await db.query("update public.pa_transactions set expires_at=now()-interval '1 hour' where id=$1",[a.transaction_id]);
 await role('service_role',()=>scalar('select public.fastpay_expire_stale_orders() v'));
 check(await scalar("select gateway_status='CREATED' v from public.pa_transactions where id=$1",[a.transaction_id]),'legacy global expiry cannot mutate automatic attempts');
 const paid=await service('observe_verified',a.attempt_id,proof);check(paid.status==='funded'&&paid.result?.ad_id,'callback creates funded order without mobile resubmit');
 check(await scalar('select balance=100 v from public.pa_wallets where user_id=$1',[user]),'gateway funding plus ad debit leaves existing wallet unchanged');
 check(await scalar('select count(*)=2 and sum(amount)=0 v from app_finance.ledger where user_id=$1',[user]),'one existing ledger credit and one captured debit');
 check(await scalar('select count(*)=1 v from app_finance.outbox where ad_id=$1',[paid.ad_id]),'one existing durable outbox');
 const debit=paid.result.receipt_uid;
 check(await scalar("select amount=10 and type='ad_payment' and method='fastpay' v from public.pa_transactions where id=$1",[debit]),'receipt points to captured ad debit');
 check(await scalar('select payment_transaction_id=$2 and receipt_uid=$3 v from public.pa_ads where id=$1',[paid.ad_id,a.transaction_id,debit]),'funding and receipt references distinct and exact');
 check((await service('observe_verified',a.attempt_id,proof)).duplicate,'duplicate verification replays result');
 check((await service('observe_verified',a.attempt_id,{...proof,gateway_transaction_id:uuid()})).code==='IDEMPOTENCY_CONFLICT','changed provider payment not accepted');
 assert.deepEqual(await role('authenticated',()=>scalar('select public.pa_ad_submission_status($1) v',[key])),paid.result);checks++;
 assert.deepEqual(await role('authenticated',()=>scalar('select public.pa_submit_ad($1,$2::jsonb,$3,$4) v',[key,JSON.stringify({...q.ad,tiktok_quote_id:q.quote_id,payment_transaction_id:a.transaction_id}),q.cost_usd,q.amount_iqd])),paid.result);checks++;
 // Force a failure after wallet credit and ad/debit construction. No partial
 // funding or job may escape the PostgreSQL transaction.
 const rollback=await attempt(await quote()),rollbackProof=verified(rollback);
 await db.exec("create function public.reject_payment_outbox() returns trigger language plpgsql as $$begin raise exception 'fixture outbox failure';end$$;create trigger reject_payment_outbox before insert on app_finance.outbox for each row execute function public.reject_payment_outbox()");
 await fails('select public.pa_ad_payment_service($1,$2,$3::jsonb)',['observe_verified',rollback.attempt_id,JSON.stringify(rollbackProof)],'fixture outbox failure');
 check(await scalar('select not wallet_credited v from public.pa_transactions where id=$1',[rollback.transaction_id]),'outbox failure rolls back gateway credit');
 check(await scalar('select balance=100 v from public.pa_wallets where user_id=$1',[user]),'outbox failure rolls back wallet');
 await db.exec('drop trigger reject_payment_outbox on app_finance.outbox');
 check((await service('observe_verified',rollback.attempt_id,rollbackProof)).status==='funded','same gateway receipt succeeds after atomic failure recovery');
 // Quote expiry must not invalidate a previously confirmed gateway attempt.
 const late=await attempt(await quote());
 await service('create_intent',late.attempt_id,{request_hash:'c'.repeat(64)});
 await db.exec('alter table app_tiktok_dm.quotes disable trigger tiktok_dm_quote_immutable');
 await db.query("update app_tiktok_dm.quotes set expires_at=now()-interval '1 hour' where id=(select tiktok_quote_id from app_finance.ad_payment_attempts where id=$1)",[late.attempt_id]);
 await db.exec('alter table app_tiktok_dm.quotes enable trigger tiktok_dm_quote_immutable');
 check((await service('observe_verified',late.attempt_id,verified(late,{status:'DECLINED'}))).code==='INVALID_GATEWAY_VERIFICATION','validate success proof cannot invent a declined result');
 check((await service('observe_status',late.attempt_id,verified(late,{verification_source:'FASTPAY_STATUS'}))).code==='INVALID_GATEWAY_VERIFICATION','status observation cannot authorize payment');
 check((await service('observe_status',late.attempt_id,verified(late,{status:'DECLINED',verification_source:'FASTPAY_STATUS',merchant_reference:'other'}))).code==='INVALID_GATEWAY_VERIFICATION','status observation retains immutable merchant binding');
 check((await service('observe_status',late.attempt_id,verified(late,{status:'UNPAID',verification_source:'FASTPAY_STATUS'}))).status==='creating','unpaid status retains unresolved creation state');
 check((await service('observe_status',late.attempt_id,verified(late,{status:'DECLINED',verification_source:'FASTPAY_STATUS'}))).status==='declined','actual decline is durable and remains recoverable');
 check(await scalar("select not wallet_credited and status='rejected' and gateway_status='DECLINED' v from public.pa_transactions where id=$1",[late.transaction_id]),'decline changes pending receipt without creating a credit');
 await service('callback_hint',null,{order_id:late.order_id,status:'PAID',amount_iqd:1});
 check(await scalar('select not wallet_credited v from public.pa_transactions where id=$1',[late.transaction_id]),'untrusted callback hint never proves payment');
 const lateClaim=await service('claim_reconcile');check(lateClaim?.attempt_id,'reconciler claims durable attempts without app');
 const latePaid=await service('observe_verified',late.attempt_id,verified(late));check(latePaid.status==='funded','verified late payment accepted despite local expiry and old quote');
 // Cancellation is an intent, not a pretend gateway refund. A late paid result
 // captures then compensates the original debit through the existing ledger.
 const cancel=await attempt(await quote());
 await service('create_intent',cancel.attempt_id,{request_hash:'d'.repeat(64)});
 await service('qr_created',cancel.attempt_id,{request_hash:'d'.repeat(64),qr_url:'https://example.invalid/cancel-qr',qr_text:'opaque-cancel'});
 const cancellation=await role('authenticated',()=>scalar('select public.pa_ad_payment_cancel($1) v',[cancel.attempt_id]));
 check(cancellation.cancel_requested&&cancellation.qr_url===null&&cancellation.qr_text===null,'durable cancel suppresses QR after creation');
 check((await role('authenticated',()=>scalar('select public.pa_ad_payment_status($1) v',[cancel.attempt_id]))).cancel_requested,'restart retains cancellation intent');
 const cancelPaid=await service('observe_verified',cancel.attempt_id,verified(cancel));check(cancelPaid.status==='compensated','late paid cancellation safely compensates');
 check(await scalar('select balance=110 v from public.pa_wallets where user_id=$1',[user]),'cancelled captured payment credited once back to existing wallet');
 check(await scalar('select count(*)=1 v from app_finance.ledger where original_transaction_id=$1 and amount=10',[cancelPaid.result.receipt_uid]),'compensation linked exactly to original debit');
 const gate=await attempt(await quote());await db.exec('update app_tiktok_dm.settings set enabled=false');
 const gatePaid=await service('observe_verified',gate.attempt_id,verified(gate));check(gatePaid.status==='compensated','gate OFF after authorization never strands captured money');
 check(await scalar("select status='cancelled' and provider_ids='{}'::jsonb v from app_finance.outbox where ad_id=$1",[gatePaid.ad_id]),'gate-off compensation creates no provider operation');
 check((await attempt(q,key)).result.ad_id===paid.ad_id,'committed attempt recovers before currentgate');
 await db.exec('update app_tiktok_dm.settings set enabled=true');
 const duplicateTarget=await attempt(await quote());check((await service('observe_verified',duplicateTarget.attempt_id,{...verified(duplicateTarget),gateway_transaction_id:proof.gateway_transaction_id})).code==='GATEWAY_TRANSACTION_ALREADY_USED','same provider transaction cannot fund another order');
 check(await scalar('select not wallet_credited v from public.pa_transactions where id=$1',[duplicateTarget.transaction_id]),'provider duplicate has no wallet effect');
 // Immutable FX: no reverse conversion from rounded IQD is used on callback.
 const preciseQ=await quote();await db.exec('alter table app_tiktok_dm.quotes disable trigger tiktok_dm_quote_immutable');
 await db.query("update app_tiktok_dm.quotes set pricing=jsonb_set(jsonb_set(pricing,'{cost_usd}','9.9999'),'{amount_iqd}','18000') where id=$1",[preciseQ.quote_id]);
 await db.exec('alter table app_tiktok_dm.quotes enable trigger tiktok_dm_quote_immutable');
 check((await attempt({...preciseQ,cost_usd:9.9999})).code==='PRICE_CHANGED','quote cannot bypass current established price check');
 await db.exec("insert into public.pa_levels(level_number,name_en,name_ku,min_points,discount_percent) values(1,'fixture','fixture',0,.001)");
 const fractionalQuote=await quote();check(Number(fractionalQuote.cost_usd)===9.9999&&fractionalQuote.amount_iqd===18000,'real discount creates USD price not reconstructible from rounded IQD');
 const fractional=await attempt(fractionalQuote);check(fractional.ok,'discounted attempt accepted');
 await db.exec("insert into public.pa_settings(key,value) values('iqd_per_usd','2000') on conflict(key) do update set value=excluded.value;update public.pa_levels set discount_percent=20");
 const fractionPaid=await service('observe_verified',fractional.attempt_id,verified(fractional));check(fractionPaid.status==='funded','FX and level changes after payment authorization do not requote');
 check(await scalar('select amount=9.9999 and fx_rate=1800 and gateway_amount=18000 v from public.pa_transactions where id=$1',[fractional.transaction_id]),'quote USD/IQD/FX persisted exactly without reverse conversion');
 check(await scalar('select amount=-9.9999 v from app_finance.ledger where transaction_id=$1',[fractionPaid.result.receipt_uid]),'captured debit uses exact discounted amount');
 await db.exec("update public.pa_settings set value='1800' where key='iqd_per_usd';delete from public.pa_levels");
 const promoId=uuid();await db.query("insert into public.promo_codes(id,code,discount_type,discount_value,max_uses,expires_at,created_by) values($1,'PAYMENT_TEST','percentage',20,1,now()+interval '1 day','fixture')",[promoId]);
 const pq=await tiktok('store_quote',{ad:base,config_hash:fingerprint(base),evidence:{authorized:true,ready:true,account_id:account,declared_budget_usd:20},promo_id:promoId,promo_code:'PAYMENT_TEST'});
 const pa=await attempt(pq);check(pa.ok&&Number(pa.cost_usd)===8,'promo price reserved before gateway');
 check(await scalar('select used_count=1 v from public.promo_codes where id=$1',[promoId]),'promo capacity reserved once');
 await service('observe_status',pa.attempt_id,verified(pa,{status:'DECLINED',verification_source:'FASTPAY_STATUS'}));
 check(await scalar('select used_count=0 v from public.promo_codes where id=$1',[promoId]),'verified decline releases promo hold while retaining late-payment recovery');
 const pp=await service('observe_verified',pa.attempt_id,verified(pa));check(pp.status==='funded'&&Number(pp.result.charged_usd)===8,'verified late capture honors original discounted price');
 check(await scalar('select used_count=1 v from public.promo_codes where id=$1',[promoId]),'late capture reinstates exact promo usage once');
 // Meta uses the same immutable gateway attempt and existing Meta durable job.
 await db.query("insert into app_meta.connections(id,user_id,status,ad_account_id,page_id,access_token_env,verified_at,expires_at) values($1,$2,'authorized','act_123','123','META_FIXTURE_TOKEN',now(),now()+interval '1 hour')",[conn,user]);
 const configuration=normalizeConfiguration({schema_version:3,platform:'META',ad_name:'Meta payment fixture',objective:'MESSAGES',page_url:'https://www.facebook.com/123',post_url:'https://www.facebook.com/123/posts/456',placements:['facebook'],destinations:['MESSENGER'],currency:'USD',budget_daily:2,duration_days:3,payment_method:'FASTPAY',schedule:{mode:'IMMEDIATE',timezone:'Asia/Baghdad'},targeting:{location:'all',gender:'ALL',age_min:18,age_max:65}});
 const mq=await meta('store_quote',{configuration,config_hash:fingerprint(configuration),evidence:{authorized:true,ready:true,connection_id:conn},forecast:unavailableForecast()});
 const metaKey=uuid();
 await db.query("update app_finance.request_limits set requests=10,bucket=date_trunc('minute',clock_timestamp()) where actor_id=$1 and operation='ad_payment_attempt'",[user]);
 check((await attempt(mq,metaKey,'META')).code==='RATE_LIMITED','new payment attempts rate limited before gateway');
 await db.query("update app_finance.request_limits set bucket=date_trunc('minute',clock_timestamp())-interval '1 minute' where actor_id=$1 and operation='ad_payment_attempt'",[user]);
 const ma=await attempt(mq,metaKey,'META');check(ma.ok,'Meta immutablepayment attempt');
 const mp=await service('observe_verified',ma.attempt_id,verified(ma));check(mp.status==='funded'&&mp.result.platform==='META','Meta paid callback accepted without mobile');
 check(await scalar('select count(*)=1 v from app_meta.jobs where ad_id=$1',[mp.ad_id]),'Meta retains dedicated durable providerjob');
 check(await scalar('select count(*)=0 v from app_finance.outbox where ad_id=$1',[mp.ad_id]),'Meta never enters TikTok queue');
 assert.deepEqual(await role('authenticated',()=>scalar('select public.pa_meta_accept($1,$2,$3::jsonb,$4,$5,$6) v',[metaKey,mq.quote_id,JSON.stringify(configuration),600,mq.amount_iqd,ma.transaction_id])),mp.result);checks++;
 // Legacy wallet-only callback remains available for unbound genuine top-ups.
 const legacyId=uuid();await db.query("insert into public.pa_transactions(id,user_id,type,kind,method,gateway,status,amount,currency,fx_rate,gateway_amount,fastpay_order_id) values($1,$2,'deposit','deposit','fastpay','fastpay','pending',10,'IQD',1800,18000,'legacy-topup')",[legacyId,user]);
 check((await role('service_role',()=>scalar("select public.fastpay_mark_paid('legacy-topup','legacy-provider',18000,'IQD') v"))).ok,'existing unbound FastPay top-up callback preserved');
 console.log(`PASS ${checks} immutable ad payment PostgreSQL assertions`);
}finally{await db.close();}
