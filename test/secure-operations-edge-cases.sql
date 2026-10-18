\set ON_ERROR_STOP on
-- No network calls; execute as real client roles and trusted fixture admin.
select set_config('request.jwt.claims','{"role":"service_role"}',false);
create policy fixture_admin_ads on pa_ads for select to authenticated using(pa_is_admin());
create policy fixture_admin_wallets on pa_wallets for select to authenticated using(pa_is_admin());
set role anon;
do $$ begin
 begin perform pa_submit_topup(gen_random_uuid(),'fib',18000,'name','','YWJjZA==');raise exception 'FAIL anonymous submit';exception when insufficient_privilege then null;end;
 begin perform pa_claim_ad_outbox();raise exception 'FAIL anonymous worker';exception when insufficient_privilege then null;end;
end $$;
reset role;
select fixture_login('11111111-1111-4111-8111-111111111111','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
set role authenticated;
do $$ begin
 update profiles set is_admin=true,is_banned=false where id=auth.uid();
 perform test_assert(not pa_is_admin(),'profile cannot grant admin role');
 perform test_assert(app_finance.refund_ad(gen_random_uuid(),gen_random_uuid(),'reason',null)->>'code'='INVALID_INPUT','NULL cannot bypass refund eligibility');
 begin update pa_wallets set balance=999;raise exception 'FAIL column-level update bypass';exception when insufficient_privilege then null;end;
 begin update pa_user_points set points=999999;raise exception 'FAIL client discount tampering';exception when insufficient_privilege then null;end;
end $$;
reset role;
-- Reference a real owned ad as a different verified account.
insert into auth.sessions(id,user_id) values('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','22222222-2222-4222-8222-222222222222');
select id as real_ad from pa_ads where status='pending' limit 1 \gset
select fixture_login('22222222-2222-4222-8222-222222222222','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
set role authenticated;
select test_assert(pa_cancel_pending_ad(:'real_ad','wrong owner')->>'code'='NOT_FOUND','real cross-account refund denied');
reset role;
-- Completed unspent refund must be capped by the original debit, despite a
-- larger display budget. The same original wallet is credited once.
select set_config('request.jwt.claims','{"role":"service_role"}',false);
update pa_ads set status='completed',spend=3.12,current_spend=2,prev_spend=0,budget=999 where id=:'real_ad';
select fixture_login('33333333-3333-4333-8333-333333333333','cccccccc-cccc-4ccc-8ccc-cccccccccccc');
set role authenticated;
select test_assert((pa_admin_refund_ad_unspent_budget(:'real_ad')->>'refund_usd')::numeric=6.88,'admin refund uses original cost minus exact spend');
select test_assert((pa_admin_refund_ad_unspent_budget(:'real_ad')->>'refund_usd')::numeric=6.88,'admin refund replay');
reset role;
select test_assert((select count(*)=1 from app_finance.ledger where original_transaction_id=(select id from pa_transactions where ad_id=:'real_ad' and type='ad_payment')),'one refund ledger row');
do $$ begin
 begin update app_finance.ledger set amount=0;raise exception 'FAIL mutable ledger';exception when insufficient_privilege then null;end;
 begin delete from app_finance.ledger;raise exception 'FAIL deleted ledger';exception when insufficient_privilege then null;end;
end $$;
-- Rejection never credits. An approval failure rolls back all financial writes.
select fixture_login('11111111-1111-4111-8111-111111111111','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
set role authenticated;
select pa_submit_topup('20000000-0000-4000-8000-000000000002','kcard',18000,'sender','reject case','YWJjZA==');
select pa_submit_topup('20000000-0000-4000-8000-000000000003','fib',36000,'sender','atomic case','YWJjZA==');
select test_assert(pa_submit_topup(gen_random_uuid(),'fib',-1,'sender','','YWJjZA==')->>'code'='INVALID_INPUT','negative amount');
select test_assert(pa_submit_topup(gen_random_uuid(),'fib',10000001,'sender','','YWJjZA==')->>'code'='INVALID_METHOD_OR_AMOUNT','topup maximum');
select test_assert(pa_submit_topup(gen_random_uuid(),'korek',18000,'sender','','YWJjZA==')->>'code'='INVALID_METHOD_OR_AMOUNT','disabled rail unchanged');
reset role;
select id as rejected_tx from pa_transactions where request_key='20000000-0000-4000-8000-000000000002' \gset
select id as atomic_tx from pa_transactions where request_key='20000000-0000-4000-8000-000000000003' \gset
select balance as before_review from pa_wallets where user_id='11111111-1111-4111-8111-111111111111' \gset
select fixture_login('33333333-3333-4333-8333-333333333333','cccccccc-cccc-4ccc-8ccc-cccccccccccc');
set role authenticated;
select test_assert(pa_review_topup(gen_random_uuid(),:'rejected_tx',false,'Payment not received')->>'status'='rejected','authorized rejection');
select test_assert(pa_review_topup(gen_random_uuid(),:'rejected_tx',true,'later approval')->>'code'='ALREADY_FINALIZED','reject is terminal');
reset role;
select test_assert((select balance=:'before_review'::numeric from pa_wallets where user_id='11111111-1111-4111-8111-111111111111'),'rejection no credit');
create trigger fixture_fail before insert on app_finance.ledger for each row execute function app_finance.fixture_fail();
do $$ declare tx uuid;begin
 select id into tx from pa_transactions where request_key='20000000-0000-4000-8000-000000000003';
 begin perform pa_review_topup('30000000-0000-4000-8000-000000000003',tx,true,'Bank verified');raise exception 'FAIL ledger injection';
 exception when others then if sqlerrm<>'injected_outbox_failure' then raise;end if;end;
end $$;
drop trigger fixture_fail on app_finance.ledger;
select test_assert((select balance=:'before_review'::numeric from pa_wallets where user_id='11111111-1111-4111-8111-111111111111'),'approval failure wallet rollback');
select test_assert((select status='pending' and not wallet_credited from pa_transactions where id=:'atomic_tx'),'approval failure status rollback');
set role authenticated;
select test_assert(pa_review_topup('30000000-0000-4000-8000-000000000003',:'atomic_tx',true,'Bank verified')->>'ok'='true','retry same failed operation succeeds once');
reset role;
-- Missing identity and a partially failed setup must not create a usable account.
insert into auth.users(id,email) values('44444444-4444-4444-8444-444444444444','new@example.invalid');
insert into auth.sessions(id,user_id) values('dddddddd-dddd-4ddd-8ddd-dddddddddddd','44444444-4444-4444-8444-444444444444');
select fixture_login('44444444-4444-4444-8444-444444444444','dddddddd-dddd-4ddd-8ddd-dddddddddddd');
set role authenticated;
do $$ begin begin perform pa_ensure_account_ready();raise exception 'FAIL unverified identity';exception when insufficient_privilege then null;end;end $$;
reset role;
update auth.users set email_confirmed_at=now() where id='44444444-4444-4444-8444-444444444444';
create trigger fixture_fail before insert on pa_coins for each row execute function app_finance.fixture_fail();
do $$ begin begin perform pa_ensure_account_ready();raise exception 'FAIL provisioning injection';exception when others then if sqlerrm<>'injected_outbox_failure' then raise;end if;end;end $$;
select test_assert(not exists(select 1 from profiles where id='44444444-4444-4444-8444-444444444444'),'provisioning rollback profile');
select test_assert(not exists(select 1 from pa_wallets where user_id='44444444-4444-4444-8444-444444444444'),'provisioning rollback wallet');
drop trigger fixture_fail on pa_coins;
set role authenticated;
select test_assert(pa_ensure_account_ready()->>'ready'='true','resume partial setup');
select test_assert(pa_ensure_account_ready()->>'ready'='true','resume idempotent');
reset role;
-- FastPay credits require explicit verified gateway facts, keep exact money,
-- and reject reuse of the provider transaction across different orders.
select set_config('request.jwt.claims','{"role":"service_role"}',false);
insert into pa_transactions(user_id,type,kind,method,gateway,status,amount,currency,fx_rate,gateway_amount,fastpay_order_id)
values ('11111111-1111-4111-8111-111111111111','deposit','deposit','fastpay','fastpay','pending',10,'IQD',1800,18000,'fixture-pay-1'),
 ('11111111-1111-4111-8111-111111111111','deposit','deposit','fastpay','fastpay','pending',10,'IQD',1800,18000,'fixture-pay-2');
set role service_role;
select test_assert(fastpay_mark_paid('fixture-pay-1')->>'code'='PAYMENT_CONFIRMATION_REQUIRED','receipt/defaults cannot prove payment');
select test_assert(fastpay_mark_paid('fixture-pay-1','provider-001',18000,'IQD')->>'ok'='true','verified gateway credit');
select test_assert(fastpay_mark_paid('fixture-pay-1','provider-001',18000,'IQD')->>'duplicate'='true','gateway retry');
select test_assert(fastpay_mark_paid('fixture-pay-1','provider-002',18000,'IQD')->>'code'='IDEMPOTENCY_CONFLICT','gateway details conflict');
do $$ begin begin perform fastpay_mark_paid('fixture-pay-2','provider-001',18000,'IQD');raise exception 'FAIL repeated provider transaction';exception when unique_violation then null;end;end $$;
reset role;
select test_assert((select not wallet_credited from pa_transactions where fastpay_order_id='fixture-pay-2'),'provider duplicate rolls back second credit');
select test_assert((select count(*)=1 from app_finance.ledger where transaction_id in (select id from pa_transactions where fastpay_order_id in ('fixture-pay-1','fixture-pay-2'))),'one gateway ledger credit');
-- Session expiry and ban are server-side gates, not metadata from Flutter.
update auth.sessions set not_after=now()-interval '1 second' where id='dddddddd-dddd-4ddd-8ddd-dddddddddddd';
select fixture_login('44444444-4444-4444-8444-444444444444','dddddddd-dddd-4ddd-8ddd-dddddddddddd');
set role authenticated;
do $$ begin begin perform fixture_buy(gen_random_uuid());raise exception 'FAIL expired session';exception when insufficient_privilege then null;end;end $$;
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',false);
update profiles set is_banned=true where id='22222222-2222-4222-8222-222222222222';
select fixture_login('22222222-2222-4222-8222-222222222222','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
set role authenticated;
do $$ begin begin perform pa_ensure_account_ready();raise exception 'FAIL banned account';exception when insufficient_privilege then null;end;end $$;
reset role;
select 'extended security and recovery assertions passed' as result;
