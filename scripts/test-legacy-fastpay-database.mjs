/** Isolated PostgreSQL tests: no remote database, provider call, or real money. */
import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';
import {fastpayDatabaseFixtureSql,legacyCheckoutMigrationSql} from './fastpay-database-fixture.mjs';
const {PGlite}=await import(process.env.PGLITE_MODULE?pathToFileURL(process.env.PGLITE_MODULE).href:'@electric-sql/pglite');
const db=new PGlite();let checks=0;
const check=(value,label)=>{assert.ok(value,label);checks++;};
const scalar=async(sql,args=[])=> (await db.query(sql,args)).rows[0]?.v;
const user='11111111-1111-4111-8111-111111111111',other='22222222-2222-4222-8222-222222222222';
const payload={amount_iqd:18000,currency:'IQD',environment:'sandbox',merchant_reference:'fixture-merchant',expires_in:10,
 success_url:'https://example.invalid/success',cancel_url:'https://example.invalid/cancel',callback_url:'https://example.invalid/ipn',purpose:'wallet_deposit',note:'fixture'};
async function role(name,fn){await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:user,role:name})]);await db.exec(`set role ${name}`);try{return await fn();}finally{await db.exec('reset role');}}
const checkout=(action,order,p=payload,who=user)=>role('service_role',()=>scalar('select public.pa_legacy_fastpay_checkout($1,$2,$3,$4::jsonb) v',[action,who,order,JSON.stringify(p)]));
const paid=(order,id,amount=18000,currency='IQD')=>role('service_role',()=>scalar('select public.fastpay_mark_paid($1,$2,$3,$4) v',[order,id,amount,currency]));
const oldCreate=(order,who=user,amount=18000)=>role('service_role',()=>scalar('select public.fastpay_create_order($1,$2,$3) v',[who,order,amount]));
async function denied(sql,as='authenticated'){let hit=false;try{await role(as,()=>db.exec(sql));}catch(e){hit=e.code==='42501';}check(hit,as+' denied '+sql);}
async function fails(sql,args,code){let hit=false;try{await db.query(sql,args);}catch(e){hit=e.message.includes(code);}check(hit,code);}
try{
 await db.exec(await fastpayDatabaseFixtureSql());
 const migration=await legacyCheckoutMigrationSql();
 await db.exec('begin;'+migration.replace(/^begin;$/m,'').replace(/^commit;$/m,'')+'rollback;');
 check(await scalar("select to_regclass('app_finance.legacy_fastpay_checkouts') is null v"),'migration rollback removes journal');
 check(await scalar("select to_regprocedure('public.fastpay_mark_declined(text,text,jsonb)') is not null v"),'rollback restores historical decline');
 await db.exec(migration);
 await db.query('insert into auth.users(id,email_confirmed_at) values($1,now()),($2,now())',[user,other]);
 await db.query('insert into public.profiles(id) values($1),($2)',[user,other]);
 await denied("select public.pa_legacy_fastpay_checkout('prepare',null,'fixture-order')");
 await denied('select * from app_finance.legacy_fastpay_checkouts','service_role');
 await denied("select app_finance.fastpay_create_order_legacy(null,null,null,null,null,null,null,null)",'service_role');
 await denied("select app_finance.fastpay_mark_declined_before_journal('fixture-order',null,null)",'service_role');
 await denied("select public.fastpay_mark_declined('fixture-order')");
 await denied("select public.fastpay_mark_check_failed('fixture-order','malicious')");
 await denied("select app_finance.fastpay_mark_check_failed_before_journal('fixture-order',null,true,null)",'service_role');
 for(const patch of [{amount_iqd:0},{amount_iqd:-1},{amount_iqd:1.5},{amount_iqd:'18000'},{currency:'USD'},{environment:'test'},{expires_in:0},{expires_in:61},{merchant_reference:''},{callback_url:'http://example.invalid/ipn'},{storePassword:'must-not-persist'}]){
  check((await checkout('prepare','invalid-order',{...payload,...patch})).code==='INVALID_REQUEST','reject invalid request '+JSON.stringify(patch));
 }
 check(await scalar('select count(*)=0 v from public.pa_transactions'),'invalid input makes no receipt');
 check((await checkout('prepare','AP'+'a'.repeat(28))).code==='INVALID_ORDER','reserved immutable namespace blocked before ledger creation');
 const first=await checkout('prepare','journal-first');
 check(first.ok&&first.create_authorized===true&&first.must_reconcile===false,'original pending receipt plus one dispatch authorization');
 check(first.request_hash?.length===64&&first.user_id===user&&first.environment==='sandbox','SQL creates fingerprint and trusted binding');
 check(await scalar("select status='pending' and gateway_status='CREATED' and not wallet_credited and qr_url is null and qr_text is null and amount=10 and gateway_amount=18000 v from public.pa_transactions where id=$1",[first.transaction_id]),'original ledger exists before gateway call');
 check(await scalar('select balance=0 v from public.pa_wallets where user_id=$1',[user]),'creation cannot credit wallet');
 check(await scalar('select count(*)=0 v from app_finance.ledger'),'creation cannot insert financial funding');
 const replay=await checkout('prepare','journal-first');
 check(replay.create_authorized===false&&replay.must_reconcile===true&&replay.transaction_id===first.transaction_id&&replay.request_hash===first.request_hash,'lost reservation response cannot authorize replay');
 check((await checkout('prepare','journal-first',payload,other)).code==='ORDER_NOT_FOUND','owner isolation before amount details');
 for(const patch of [{amount_iqd:18001},{merchant_reference:'different'},{environment:'production'},{expires_in:9},{callback_url:'https://example.invalid/changed'},{purpose:'ad_checkout'},{note:'different'}])
  check((await checkout('prepare','journal-first',{...payload,...patch})).code==='IDEMPOTENCY_CONFLICT','frozen request '+JSON.stringify(patch));
 check((await checkout('qr_created','journal-first',{request_hash:'a'.repeat(64),qr_text:'opaque'})).code==='CREATION_INTENT_REQUIRED','QR save binds exact dispatch');
 await checkout('unknown','journal-first',{request_hash:first.request_hash,error_code:'GATEWAY_TIMEOUT'});
 check((await checkout('prepare','journal-first')).create_authorized===false,'unknown provider outcome never replays');
 check((await oldCreate('journal-first')).code==='DURABLE_CHECKOUT_REQUIRED','old writer cannot refresh journal receipt');
 await fails('update public.pa_transactions set amount=9 where id=$1',[first.transaction_id],'LEGACY_FASTPAY_RECEIPT_IMMUTABLE');
 await fails('update public.pa_transactions set user_id=$2 where id=$1',[first.transaction_id,other],'LEGACY_FASTPAY_RECEIPT_IMMUTABLE');
 await fails("update public.pa_transactions set expires_at=expires_at+interval '1 hour' where id=$1",[first.transaction_id],'LEGACY_FASTPAY_RECEIPT_IMMUTABLE');
 await fails('delete from public.pa_transactions where id=$1',[first.transaction_id],'LEGACY_FASTPAY_RECEIPT_IMMUTABLE');
 await fails("update app_finance.legacy_fastpay_checkouts set request_hash=repeat('a',64) where transaction_id=$1",[first.transaction_id],'LEGACY_FASTPAY_INTENT_IMMUTABLE');
 await fails('delete from app_finance.legacy_fastpay_checkouts where transaction_id=$1',[first.transaction_id],'LEGACY_FASTPAY_INTENT_IMMUTABLE');
 await db.exec("insert into public.pa_settings(key,value) values('iqd_per_usd','2000') on conflict(key) do update set value=excluded.value");
 const qrPayload={request_hash:first.request_hash,qr_url:'https://example.invalid/qr',qr_text:'opaque-first'};
 const qr=await checkout('qr_created','journal-first',qrPayload);
 check(qr.qr_text==='opaque-first'&&qr.qr_url==='https://example.invalid/qr','exact QR persisted after durable intent');
 check(qr.amount_usd===10&&qr.fx_rate===1800&&qr.expires_at===first.expires_at,'QR save never refreshes frozen rate, money, or expiry');
 assert.deepEqual(await checkout('qr_created','journal-first',qrPayload),qr);checks++;
 check((await checkout('qr_created','journal-first',{...qrPayload,qr_text:'replacement'})).code==='GATEWAY_QR_CONFLICT','conflicting QR refused');
 check((await checkout('read','journal-first',{})).qr_text==='opaque-first','readback recovers exact QR without gateway POST');
 check((await checkout('read','journal-first',{},other)).code==='ORDER_NOT_FOUND','readback owner isolation');
 // Historical row may already represent a dispatched charge: recovery only.
 const historical=await oldCreate('history-order');check(historical.ok,'historical create delegates unchanged');
 const recovered=await checkout('prepare','history-order');
 check(recovered.ok&&!recovered.create_authorized&&!recovered.journaled&&recovered.must_reconcile,'historical row is not newly authorized');
 check((await checkout('prepare','history-order',{...payload,amount_iqd:19000})).code==='IDEMPOTENCY_CONFLICT','historical money mismatch cannot mutate receipt');
 check((await checkout('prepare','history-order',payload,other)).code==='ORDER_NOT_FOUND','historical owner mismatch cannot mutate receipt');
 check((await checkout('qr_created','history-order',qrPayload)).code==='CREATION_INTENT_REQUIRED','cannot attach new QR to an unjournaled historical row');
 // Local expiry/decline cannot strand late verified payments under the strict
 // secure baseline, which only settles pending receipts.
 await db.exec('alter table public.pa_transactions disable trigger legacy_fastpay_receipt_immutable');
 await db.query("update public.pa_transactions set expires_at=now()-interval '1 hour' where id in ($1,$2)",[first.transaction_id,historical.transaction_id]);
 await db.exec('alter table public.pa_transactions enable trigger legacy_fastpay_receipt_immutable');
 await role('service_role',()=>scalar('select public.fastpay_expire_stale_orders() v'));
 check(await scalar("select status='pending' and gateway_status='CREATED' v from public.pa_transactions where id=$1",[first.transaction_id]),'journaled dispatch survives hard expiry');
 check(await scalar("select status='rejected' and gateway_status='EXPIRED' v from public.pa_transactions where id=$1",[historical.transaction_id]),'historical expiry semantics preserved');
 check((await checkout('read','journal-first',{})).qr_text===null,'expired QR suppressed without finality claim');
 const decline=await role('service_role',()=>scalar("select public.fastpay_mark_declined('journal-first','DECLINED','{}') v"));
 check(decline.must_reconcile&&decline.status==='pending'&&decline.gateway_status==='DECLINED','decline observation cannot foreclose verified late settlement');
 check(await scalar("select gateway_status='DECLINED' and status='pending' v from public.pa_transactions where id=$1",[first.transaction_id]),'direct mobile receipt reads suppress declined QR without finality');
 check(await scalar("select last_observed_status='DECLINED' v from app_finance.legacy_fastpay_checkouts where transaction_id=$1",[first.transaction_id]),'decline evidence retained privately');
 check((await role('service_role',()=>scalar("select public.fastpay_mark_declined($1,'DECLINED','{}') v",['AP'+'f'.repeat(28)]))).code==='AD_PAYMENT_VERIFICATION_REQUIRED','decline cannot mutate immutable namespace');
 const pollFirst=await role('service_role',()=>db.query('select * from public.fastpay_orders_to_poll(1,2)'));
 check(pollFirst.rows[0]?.id===first.transaction_id,'expired journal remains pollable');
 check((await role('service_role',()=>db.query('select * from public.fastpay_orders_to_poll(1,2)'))).rows.length===0,'claimed unresolved row does not occupy every poll');
 await db.exec("update public.pa_settings set value='1800' where key='iqd_per_usd'");
 const second=await checkout('prepare','journal-second');
 check((await role('service_role',()=>db.query('select * from public.fastpay_orders_to_poll(1,2)'))).rows[0]?.id===second.transaction_id,'newer order not starved by old unresolved order');
 await checkout('qr_created','journal-second',{request_hash:second.request_hash,qr_text:'second-token'});
 await role('service_role',()=>scalar("select public.fastpay_mark_declined('journal-second','DECLINED','{}') v"));
 check((await checkout('read','journal-second',{})).qr_text===null,'unexpired decline suppresses QR on trusted readback too');
 check((await checkout('qr_created','journal-second',{request_hash:second.request_hash,qr_text:'second-token'})).gateway_status==='DECLINED','delayed QR save cannot reopen a declined observation');
 const settled=await paid('journal-first','gateway-first');
 check(settled.ok&&settled.amount_usd===10,'verified late payment uses strict existing financial authority');
 check(await scalar('select balance=10 v from public.pa_wallets where user_id=$1',[user]),'late funding exactly frozen original USD');
 check(await scalar('select count(*)=1 and sum(amount)=10 v from app_finance.ledger where user_id=$1',[user]),'late funding one original financial ledger entry');
 check((await paid('journal-first','gateway-first')).duplicate,'duplicate verification idempotent');
 check((await paid('journal-first','different-gateway')).code==='IDEMPOTENCY_CONFLICT','conflicting payment cannot credit twice');
 check((await checkout('prepare','journal-first')).create_authorized===false,'settled retry never reauthorizes');
 check((await checkout('qr_created','journal-first',qrPayload)).gateway_status==='PAID','late QR callback cannot reopen settled order');
 await db.exec("update app_finance.legacy_fastpay_checkouts set next_check_at=now()-interval '1 hour'");
 check(!(await role('service_role',()=>db.query('select * from public.fastpay_orders_to_poll()'))).rows.some(r=>r.id===first.transaction_id),'settled row excluded from polling');
 // Failure after original row creation rolls the entire transaction back.
 await db.exec("create function public.reject_legacy_intent_fixture() returns trigger language plpgsql as $$begin raise exception 'fixture intent failure';end$$;create trigger reject_legacy_intent_fixture before insert on app_finance.legacy_fastpay_checkouts for each row execute function public.reject_legacy_intent_fixture()");
 await fails('select public.pa_legacy_fastpay_checkout($1,$2,$3,$4::jsonb)',['prepare',user,'rollback-order',JSON.stringify(payload)],'fixture intent failure');
 check(await scalar("select count(*)=0 v from public.pa_transactions where fastpay_order_id='rollback-order'"),'intent failure rolls back original pending receipt');
 await db.exec('drop trigger reject_legacy_intent_fixture on app_finance.legacy_fastpay_checkouts');
 check((await checkout('prepare','rollback-order')).create_authorized===true,'rolled back intent can safely retry before provider dispatch');
 check((await paid('rollback-order',null)).code==='PAYMENT_CONFIRMATION_REQUIRED','missing verification identity cannot fund journaled order');
 check((await paid('rollback-order','fraud-proof',18001)).code==='AMOUNT_MISMATCH','verified amount mismatch retains fraud hold');
 check(await scalar("select status='rejected' and gateway_status='FRAUD_SUSPECT' and not wallet_credited v from public.pa_transactions where fastpay_order_id='rollback-order'"),'fraud observation creates no funding');
 await role('service_role',()=>scalar("select public.fastpay_mark_declined('rollback-order','DECLINED','{}') v"));
 check(await scalar("select status='rejected' and gateway_status='FRAUD_SUSPECT' v from public.pa_transactions where fastpay_order_id='rollback-order'"),'decline does not reopen a fraud hold');
 check((await paid('rollback-order','fraud-proof')).code==='INVALID_PAYMENT_STATE','mismatch requires manual reconciliation, never automatic reopening');
 check((await role('service_role',()=>scalar('select public.fastpay_mark_check_failed($1,$2) v',['AP'+'f'.repeat(28),'untrusted']))).code==='AD_PAYMENT_VERIFICATION_REQUIRED','legacy verification failure cannot mutate immutable ad order');
 check(await scalar('select count(*)=0 v from public.pa_ads'),'legacy creation never creates ads');
 console.log(`Legacy FastPay database tests: ${checks} assertions passed`);
}finally{await db.close();}
