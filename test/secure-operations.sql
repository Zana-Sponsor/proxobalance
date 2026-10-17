\set ON_ERROR_STOP on
-- Synthetic users, no Auth API calls, no external messages.
insert into auth.users(id,email,email_confirmed_at) values
 ('11111111-1111-4111-8111-111111111111','one@example.invalid',now()),
 ('22222222-2222-4222-8222-222222222222','two@example.invalid',now()),
 ('33333333-3333-4333-8333-333333333333','admin@example.invalid',now());
insert into auth.sessions(id,user_id) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-1111-4111-8111-111111111111'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','22222222-2222-4222-8222-222222222222'),
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc','33333333-3333-4333-8333-333333333333');
create or replace function public.fixture_login(u text,s text) returns void language plpgsql as $$ begin
 perform set_config('request.jwt.claims',jsonb_build_object('sub',u,'session_id',s,'role','authenticated')::text,false); end $$;
select fixture_login('11111111-1111-4111-8111-111111111111','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
set role authenticated;
select test_assert((pa_ensure_account_ready()->>'ready')::boolean,'complete setup');
select test_assert((pa_ensure_account_ready()->>'ready')::boolean,'idempotent setup');
select test_assert((select count(*)=1 from pa_wallets),'owner wallet readable');
reset role;
select test_assert((select count(*)=1 from pa_wallets),'setup no duplicate wallet');
delete from pa_user_points where user_id='11111111-1111-4111-8111-111111111111';
set role authenticated;
select test_assert((pa_ensure_account_ready()->>'ready')::boolean,'setup repairs incomplete record');
reset role;
select fixture_login('22222222-2222-4222-8222-222222222222','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
select pa_ensure_account_ready();
select fixture_login('33333333-3333-4333-8333-333333333333','cccccccc-cccc-4ccc-8ccc-cccccccccccc');
select pa_ensure_account_ready();
select set_config('request.jwt.claims','{"role":"service_role"}',false);
update profiles set is_admin=true where id='33333333-3333-4333-8333-333333333333';
update pa_wallets set balance=100 where user_id='11111111-1111-4111-8111-111111111111';

create function public.fixture_ad() returns jsonb language sql as $$ select jsonb_build_object(
 'title','Test ad','goal','views','category','other','age_groups',jsonb_build_array('all'),'gender','all','location','kurdistan',
 'device_type','all','daily_budget',10,'days',1,'video_link','https://www.tiktok.com/@fixture/video/1234567890123456789',
 'video_code','test-code','start_immediately',true,'payment_method','app_balance'); $$;
create function public.fixture_buy(k uuid) returns jsonb language sql as $$ select pa_submit_ad(k,fixture_ad(),10,18000); $$;
select fixture_login('11111111-1111-4111-8111-111111111111','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
set role authenticated;
do $$ declare r jsonb; retry jsonb; begin
 r:=fixture_buy('10000000-0000-4000-8000-000000000001');
 perform test_assert(r->>'ok'='true','ad accepted');
 retry:=fixture_buy('10000000-0000-4000-8000-000000000001');
 perform test_assert(retry=r,'identical retry returns original result');
 perform test_assert(pa_submit_ad('10000000-0000-4000-8000-000000000001',fixture_ad()||'{"title":"changed"}',10,18000)->>'code'='IDEMPOTENCY_CONFLICT','key details conflict');
 perform test_assert(pa_submit_ad(gen_random_uuid(),fixture_ad(),0,0)->>'code'='PRICE_CHANGED','client cannot override price');
 perform test_assert((select count(*)=1 from pa_ads),'one ad');
 perform test_assert((select balance=90 from pa_wallets),'one debit');
 begin update pa_wallets set balance=100000;raise exception 'FAIL direct balance update';exception when insufficient_privilege then null;end;
 begin insert into pa_transactions(user_id,amount,status,type) values(auth.uid(),1000,'approved','deposit');raise exception 'FAIL direct transaction insert';exception when insufficient_privilege then null;end;
 begin update pa_ads set total_budget=9999;raise exception 'FAIL direct ad price';exception when insufficient_privilege then null;end;
 begin perform pa_create_ad(fixture_ad(),10);raise exception 'FAIL legacy bypass';exception when insufficient_privilege then null;end;
 begin perform pa_review_topup(gen_random_uuid(),gen_random_uuid(),true,'payment checked');raise exception 'FAIL unauthorized approval';exception when insufficient_privilege then null;end;
 begin perform pa_admin_app_report();raise exception 'FAIL report privacy';exception when insufficient_privilege then null;end;
 begin perform pa_admin_user_activity(auth.uid());raise exception 'FAIL per-user report privacy';exception when insufficient_privilege then null;end;
 begin perform 1 from app_finance.ledger;raise exception 'FAIL ledger read';exception when insufficient_privilege then null;end;
end $$;
reset role;
select test_assert((select count(*)=1 from app_finance.ledger),'immutable debit ledger');
select test_assert((select count(*)=1 from app_finance.outbox),'outbox committed with debit');
update pa_wallets set balance=0 where user_id='11111111-1111-4111-8111-111111111111';
set role authenticated;
select test_assert(fixture_buy(gen_random_uuid())->>'code'='INSUFFICIENT_FUNDS','insufficient funds');
reset role;
select test_assert((select count(*)=1 from pa_ads),'failure no partial ad');
-- Deliberately fail the final outbox write: wallet/ad/ledger MUST roll back.
update pa_wallets set balance=100 where user_id='11111111-1111-4111-8111-111111111111';
create function app_finance.fixture_fail() returns trigger language plpgsql as $$ begin raise exception 'injected_outbox_failure';end $$;
create trigger fixture_fail before insert on app_finance.outbox for each row execute function app_finance.fixture_fail();
set role authenticated;
do $$ begin begin perform fixture_buy(gen_random_uuid());raise exception 'FAIL injection missed';
exception when others then if sqlerrm<>'injected_outbox_failure' then raise;end if;end;end $$;
reset role;
drop trigger fixture_fail on app_finance.outbox;
select test_assert((select balance=100 from pa_wallets where user_id='11111111-1111-4111-8111-111111111111'),'partial failure balance rollback');
select test_assert((select count(*)=1 from app_finance.ledger),'partial failure ledger rollback');

-- Owner cancellation links the original debit, atomically credits once and replays.
set role authenticated;
do $$ declare a uuid; r jsonb; begin
 select id into a from pa_ads limit 1;
 r:=pa_cancel_pending_ad(a,'changed plans');perform test_assert(r->>'ok'='true','eligible refund');
 perform test_assert(pa_cancel_pending_ad(a,'changed plans')=r,'refund retry');
 perform test_assert(pa_cancel_pending_ad(a,'different reason')->>'code'='IDEMPOTENCY_CONFLICT','refund conflict');
end $$;
reset role;
select test_assert((select balance=110 from pa_wallets where user_id='11111111-1111-4111-8111-111111111111'),'refund exactly once');
select test_assert((select count(*)=1 from app_finance.ledger where original_transaction_id is not null and amount=10),'refund original reference');

-- Submission stores a pending request with server-calculated amounts, no credit.
set role authenticated;
do $$ declare r jsonb; begin
 r:=pa_submit_topup('20000000-0000-4000-8000-000000000001','fib',18000,'Fixture sender','note','YWJjZA==');
 perform test_assert(r->>'ok'='true' and (r->>'amount_usd')::numeric=10,'topup server quote');
 perform test_assert(pa_submit_topup('20000000-0000-4000-8000-000000000001','fib',18000,'Fixture sender','note','YWJjZA==')=r,'topup replay');
 perform test_assert(pa_submit_topup('20000000-0000-4000-8000-000000000001','fib',36000,'Fixture sender','note','YWJjZA==')->>'code'='IDEMPOTENCY_CONFLICT','topup changed amount');
 perform test_assert((select balance=110 from pa_wallets),'receipt does not credit');
end $$;
reset role;
select fixture_login('33333333-3333-4333-8333-333333333333','cccccccc-cccc-4ccc-8ccc-cccccccccccc');
-- Administrator can select pending requests through the established admin policy.
create policy fixture_admin_read on pa_transactions for select to authenticated using(pa_is_admin());
set role authenticated;
do $$ declare tx uuid;r jsonb;begin
 select id into tx from pa_transactions where request_key='20000000-0000-4000-8000-000000000001';
 r:=pa_review_topup('30000000-0000-4000-8000-000000000001',tx,true,'Bank transfer independently verified');
 perform test_assert(r->>'ok'='true','admin approval');
 perform test_assert(pa_review_topup('30000000-0000-4000-8000-000000000001',tx,true,'Bank transfer independently verified')=r,'approval retry');
 perform test_assert(pa_review_topup(gen_random_uuid(),tx,true,'Bank transfer independently verified')->>'code'='ALREADY_FINALIZED','new key repeat approval');
 perform test_assert(pa_review_topup(gen_random_uuid(),tx,false,'reject later')->>'code'='ALREADY_FINALIZED','finalized transition');
end $$;
reset role;
select test_assert((select balance=120 from pa_wallets where user_id='11111111-1111-4111-8111-111111111111'),'one topup credit');
select fixture_login('22222222-2222-4222-8222-222222222222','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
set role authenticated;
select test_assert((select count(*)=0 from pa_ads),'cross-account ad read');
select test_assert((select count(*)=0 from pa_transactions),'cross-account financial read');
select test_assert(pa_cancel_pending_ad('dddddddd-dddd-4ddd-8ddd-dddddddddddd','wrong owner')->>'code'='NOT_FOUND','unknown refund ID does not disclose ownership');
reset role;
-- The cancelled advertisement must never reach the provider.
select test_assert(pa_claim_ad_outbox() is null,'cancelled job not dispatched');
select fixture_login('11111111-1111-4111-8111-111111111111','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
set role authenticated;
select test_assert(fixture_buy('10000000-0000-4000-8000-000000000002')->>'ok'='true','second pending ad');
reset role;
-- Outbox timeout: keep the same provider idempotency key and reject stale lease.
do $$ declare first jsonb;again jsonb;begin
 first:=pa_claim_ad_outbox();
 update app_finance.outbox set lease_until=now()-interval '1 minute' where id=(first->>'id')::uuid;
 again:=pa_claim_ad_outbox();
 perform test_assert(first->>'id'=again->>'id' and first->>'lease_token'<>again->>'lease_token','external timeout lease recovery');
 perform test_assert(not pa_finish_ad_outbox((first->>'id')::uuid,(first->>'lease_token')::uuid,'late-provider-id'),'stale worker rejected');
 perform test_assert(pa_finish_ad_outbox((again->>'id')::uuid,(again->>'lease_token')::uuid,'provider-id'),'current worker acknowledged');
end $$;

-- Privacy, duplicates, stale heartbeat, foreground time and leaderboard sources.
select fixture_login('11111111-1111-4111-8111-111111111111','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
create function public.fixture_telemetry(seq integer,foreground boolean default true) returns jsonb language sql as $$
 select jsonb_build_object('installation_id','40000000-0000-4000-8000-000000000001','run_id','50000000-0000-4000-8000-000000000001',
 'sequence',seq,'foreground',foreground,'section','ads','device',jsonb_build_object('app_version','1.0.9','device_model','fixture'),
 'events',jsonb_build_array(jsonb_build_object('id','60000000-0000-4000-8000-000000000001','kind','error','section','ads','code','TimeoutException','ordinal',1)));$$;
set role authenticated;

do $$ begin
 begin
  perform pa_record_app_telemetry(fixture_telemetry(1)||jsonb_build_object('section','/profile/11111111-1111-4111-8111-111111111111'));
  raise exception 'FAIL raw route accepted';
 exception when others then if sqlerrm<>'INVALID_TELEMETRY' then raise;end if;end;
 begin
  perform pa_record_app_telemetry(jsonb_set(fixture_telemetry(1),'{events,0,section}','"/private/path"'));
  raise exception 'FAIL raw event route accepted';
 exception when others then if sqlerrm<>'INVALID_EVENT' then raise;end if;end;
end $$;
select test_assert(pa_record_app_telemetry(fixture_telemetry(1))->>'ok'='true','telemetry ingestion');
select pa_record_app_telemetry(fixture_telemetry(1));
do $$ begin begin perform 1 from app_telemetry.events;raise exception 'FAIL private event access';exception when insufficient_privilege then null;end;end $$;
reset role;
select test_assert((select count(*)=1 from app_telemetry.events),'event deduplication');
update app_telemetry.sessions set last_seen_at=clock_timestamp()-interval '30 seconds';
set role authenticated;
select pa_record_app_telemetry(fixture_telemetry(2,false));
select pa_record_app_telemetry(fixture_telemetry(1,true));
reset role;
select test_assert((select not active from app_telemetry.device_presence),'background and old sequence cannot reactivate');
select test_assert((select sum(active_seconds) between 29 and 31 from app_telemetry.daily_usage),'foreground time counted once');
select fixture_login('33333333-3333-4333-8333-333333333333','cccccccc-cccc-4ccc-8ccc-cccccccccccc');
set role authenticated;
select test_assert(jsonb_array_length(pa_admin_app_report()->'most_used_sections')=1,'ranked sections');
select test_assert(jsonb_array_length(pa_admin_user_activity('11111111-1111-4111-8111-111111111111')->'events')=1,'admin can inspect one account');
select test_assert(pa_admin_user_activity('11111111-1111-4111-8111-111111111111')->'events'->0->>'ordinal'='1','client order retained without trusting client timestamps');
select test_assert(pa_admin_user_activity('11111111-1111-4111-8111-111111111111')->'devices'->0->>'last_reported_section'='ads','last reported section available to admin');
select test_assert(jsonb_array_length(pa_admin_user_activity('22222222-2222-4222-8222-222222222222')->'events')=0,'per-user report filters identity');
reset role;
-- Revoked session may neither provision nor submit financial requests.
delete from auth.sessions where id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
select fixture_login('22222222-2222-4222-8222-222222222222','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
set role authenticated;
do $$ begin begin perform pa_ensure_account_ready();raise exception 'FAIL revoked session';exception when insufficient_privilege then null;end;end $$;
reset role;
select 'secure operations, setup and telemetry assertions passed' as result;
