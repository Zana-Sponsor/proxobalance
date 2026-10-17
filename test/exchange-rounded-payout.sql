-- Trusted-operator regression fixture for the rounded IQD settlement migration.
-- Everything below is synthetic and transaction-local, including the temporary
-- helpers, audit-failure trigger and the historical-order setup. Never COMMIT it.
-- It may also run inside a migration exception subtransaction after stripping
-- the outer BEGIN/ROLLBACK; any failed assertion must abort that migration.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';
set local request.jwt.claim.role = 'service_role';

create temporary table rounding_fixture as select
  gen_random_uuid() customer, gen_random_uuid() other_customer,
  gen_random_uuid() approver, gen_random_uuid() refund_admin,
  gen_random_uuid() view_staff, gen_random_uuid() banned_admin;
grant select on rounding_fixture to authenticated;
create temporary table rounding_cases (
  label text primary key, order_id uuid not null, request_key uuid not null,
  before_order jsonb not null
);
grant select on rounding_cases to authenticated;

create function pg_temp.rounding_fail_audit() returns trigger language plpgsql as $fn$
begin
  if new.action = 'approve_order_settlement'
    and new.detail::jsonb -> 'settlement' ->> 'order_id' = current_setting('ex_rounding_test.fail_order',true) then
    raise exception 'ROUNDING_TEST_AUDIT_FAILURE';
  end if;
  if new.action = 'attach_settlement_receipt'
    and new.detail::jsonb ->> 'order_id' = current_setting('ex_rounding_test.fail_receipt',true) then
    raise exception 'ROUNDING_TEST_RECEIPT_AUDIT_FAILURE';
  end if;
  return new;
end $fn$;
create trigger rounding_fixture_fail_audit before insert on public.ex_admin_audit_log
  for each row execute function pg_temp.rounding_fail_audit();

-- Use the real pricing/insert triggers, with isolated rates and no live routes.
create function pg_temp.rounding_order(p_user uuid,p_expected numeric,p_amount numeric default 12000)
returns public.ex_orders language plpgsql as $fn$
declare o public.ex_orders%rowtype; v_from text := 'rounding-source-' || gen_random_uuid()::text;
  v_dest text := current_setting('ex_rounding_test.destination');
begin
  insert into public.ex_rates(from_method,to_method,rate_type,rate_value)
    values(v_from,v_dest,'fee_fixed',p_amount-p_expected);
  insert into public.ex_orders(user_id,from_method,to_method,amount,total,phone,receipt_url,receipt_hash)
    values(p_user,v_from,v_dest,p_amount,0,'07700000001',
      'https://example.invalid/rounding-funding.png',md5(v_from)||md5(v_dest)) returning * into o;
  return o;
end $fn$;

create function pg_temp.rounding_approve(
  p_order public.ex_orders,p_admin uuid,p_key uuid,p_receipt text default null
) returns jsonb language plpgsql as $fn$
begin
  return public.ex_admin_approve_order_settlement(p_order.id,p_admin,p_key,p_order.updated_at,
    p_order.total,trunc(p_order.total/1000)*1000,true,p_order.total>=1000,p_receipt,'Rounding fixture approval');
end $fn$;

create function pg_temp.rounding_expect_error(p_sql text,p_message text,p_state text default null)
returns void language plpgsql as $fn$
begin
  begin
    execute p_sql;
  exception when others then
    if (p_message is null or sqlerrm=p_message) and (p_state is null or sqlstate=p_state) then return;end if;
    raise exception 'UNEXPECTED_FIXTURE_ERROR [%] %, expected [%] %',sqlstate,sqlerrm,p_state,p_message;
  end;
  raise exception 'EXPECTED_ERROR_NOT_RAISED: %',coalesce(p_message,p_state);
end $fn$;

-- Hash complete non-fixture rows, so the regression also proves that existing
-- orders and money records were not modified while synthetic cases were tested.
create function pg_temp.rounding_existing_state() returns jsonb language sql as $fn$
  with fixture_users as (
    select unnest(array[customer,other_customer,approver,refund_admin,view_staff,banned_admin]) id from rounding_fixture
  ), rows as (
    select 'orders' name,o.id::text id,to_jsonb(o) value from public.ex_orders o
      where o.user_id not in(select id from fixture_users)
    union all select 'settlements',s.id::text,to_jsonb(s) from public.ex_order_payout_settlements s
      where s.user_id not in(select id from fixture_users)
    union all select 'shortfalls',s.id::text,to_jsonb(s) from public.ex_order_shortfall_refunds s
      where s.user_id not in(select id from fixture_users)
    union all select 'balances',b.user_id::text,to_jsonb(b) from public.ex_customer_balances b
      where b.user_id not in(select id from fixture_users)
    union all select 'journals',j.id::text,to_jsonb(j) from public.ex_balance_journal j
      where j.user_id not in(select id from fixture_users)
    union all select 'entries',e.id::text,to_jsonb(e) from public.ex_balance_entries e
      join public.ex_balance_journal j on j.id=e.journal_id where j.user_id not in(select id from fixture_users)
    union all select 'full_refunds',r.id::text,to_jsonb(r) from public.ex_refund_cases r
      where r.user_id not in(select id from fixture_users)
  ), checksums as (
    select name,jsonb_build_object('count',count(*),'hash',md5(string_agg(md5(value::text),'' order by id))) value
      from rows group by name
  ) select coalesce(jsonb_object_agg(name,value),'{}'::jsonb) from checksums;
$fn$;
create temporary table rounding_existing_before as select pg_temp.rounding_existing_state() value;

do $setup$
declare f record; v_dest text := 'rounding-destination-' || gen_random_uuid()::text;
  o public.ex_orders%rowtype;
begin
  select * into f from rounding_fixture;
  insert into auth.users(id,email,raw_user_meta_data) values
    (f.customer,'rounding-customer-'||f.customer||'@example.invalid','{"full_name":"Rounding fixture customer"}'),
    (f.other_customer,'rounding-other-'||f.other_customer||'@example.invalid','{"full_name":"Rounding fixture other"}'),
    (f.approver,'rounding-approver-'||f.approver||'@example.invalid','{"full_name":"Rounding fixture approver"}'),
    (f.refund_admin,'rounding-refunds-'||f.refund_admin||'@example.invalid','{"full_name":"Rounding fixture refund admin"}'),
    (f.view_staff,'rounding-view-'||f.view_staff||'@example.invalid','{"full_name":"Rounding fixture view only"}'),
    (f.banned_admin,'rounding-banned-'||f.banned_admin||'@example.invalid','{"full_name":"Rounding fixture banned"}');
  update public.ex_profiles set role='admin' where id in(f.approver,f.refund_admin,f.view_staff,f.banned_admin);
  update public.ex_profiles set staff_permissions=array['view','approve_orders'] where id in(f.approver,f.banned_admin);
  update public.ex_profiles set staff_permissions=array['view','refunds'] where id=f.refund_admin;
  update public.ex_profiles set staff_permissions=array['view'] where id=f.view_staff;
  update public.ex_profiles set is_banned=true where id=f.banned_admin;
  update public.ex_user_rewards set active=false where campaign_key='welcome_signup_v1'
    and user_id in(f.customer,f.other_customer,f.approver,f.refund_admin,f.view_staff,f.banned_admin);
  insert into public.ex_wallets(key,name,allow_from,allow_receive)
    values(v_dest,'Rounding fixture destination',true,true);
  perform set_config('ex_rounding_test.destination',v_dest,true);
  o:=pg_temp.rounding_order(f.customer,10500);
  insert into rounding_cases values('historical',o.id,gen_random_uuid(),to_jsonb(o));
end $setup$;

-- Simulate ONE pre-migration approved row, without touching any existing order.
-- The trigger is restored before all assertions and before any settlement exists.
alter table public.ex_orders disable trigger trg_ex_orders_settlement_guard;
update public.ex_orders set status='پەسەندکرا'
  where id=(select order_id from rounding_cases where label='historical');
alter table public.ex_orders enable trigger trg_ex_orders_settlement_guard;

do $test$
declare
  f record; c record; v_dest text := current_setting('ex_rounding_test.destination');
  o public.ex_orders%rowtype; original_o public.ex_orders%rowtype; other_o public.ex_orders%rowtype;
  r public.ex_order_shortfall_refunds%rowtype;
  result jsonb; retried jsonb; receipt_result jsonb; v_before_report jsonb; v_report jsonb;
  v_expected numeric; v_invalid numeric; v_role uuid; v_key uuid; v_fail_key uuid:=gen_random_uuid();
  v_before_balance bigint; v_before_journals bigint; v_before_notifications bigint;
  v_receipt text; v_reward uuid; v_field text;
  v_reward_route text := 'rounding-reward-' || gen_random_uuid()::text;
begin
  select * into f from rounding_fixture;
  v_before_report:=public.ex_admin_balance_reconcile(f.approver);
  if (v_before_report->>'rounding_settlement_mismatches')::bigint<>0 then
    raise exception 'PREEXISTING_ROUNDING_INCONSISTENCY';
  end if;
  v_receipt:='https://pycxuugoblkslvwebxuu.supabase.co/storage/v1/object/public/receipts/'||f.customer||'/rounding-proof.png';

  -- A historical approval remains untouched; neither reopening nor a new key credits it.
  select * into o from public.ex_orders where id=(select order_id from rounding_cases where label='historical');
  perform pg_temp.rounding_expect_error(format('select pg_temp.rounding_approve((select o from public.ex_orders o where id=%L),%L,%L)',
    o.id,f.approver,gen_random_uuid()),'ORDER_ALREADY_DECIDED','22023');
  perform pg_temp.rounding_expect_error(format('update public.ex_orders set status=%L where id=%L','چاوەڕوانە',o.id),
    'SETTLEMENT_ORDER_IMMUTABLE','23514');
  perform pg_temp.rounding_expect_error(format('update public.ex_orders set to_method=%L where id=%L','USDT',o.id),
    'SETTLEMENT_ORDER_IMMUTABLE','23514');
  if exists(select 1 from public.ex_order_payout_settlements where order_id=o.id)
    or exists(select 1 from public.ex_order_shortfall_refunds where order_id=o.id)
    or (select payout_settlement_id from public.ex_orders where id=o.id) is not null then
    raise exception 'HISTORICAL_ORDER_WAS_BACKFILLED';
  end if;

  -- Whole-thousand policy includes zero net and a full net credit below 1,000.
  foreach v_expected in array array[10500,1600,10000,500,0]::numeric[] loop
    o:=pg_temp.rounding_order(f.customer,v_expected);
    original_o:=o;v_key:=gen_random_uuid();
    if o.total<>v_expected then raise exception 'FIXTURE_PRICING_CHANGED_EXPECTED: %',v_expected;end if;
    insert into rounding_cases values('net-'||v_expected,o.id,v_key,to_jsonb(o));
    select coalesce((select available_iqd from public.ex_customer_balances where user_id=f.customer),0) into v_before_balance;
    result:=pg_temp.rounding_approve(o,f.approver,v_key);
    if result->'order'->>'status'<>'پەسەندکرا'
      or (result->'order'->>'total')::numeric<>v_expected
      or (result->'order'->>'fee')::numeric<>original_o.fee
      or (result->'order'->>'amount')::numeric<>original_o.amount
      or (result->'order'->>'payout_iqd')::numeric<>trunc(v_expected/1000)*1000
      or (result->'order'->>'payout_rounding_iqd')::numeric<>mod(v_expected,1000)
      or (result->'order'->>'shortfall_refunded_iqd')::numeric<>mod(v_expected,1000)
      or (result->'settlement'->>'confirmed_paid')::boolean is distinct from (v_expected>=1000)
      or (select coalesce((select available_iqd from public.ex_customer_balances where user_id=f.customer),0))
         <>v_before_balance+mod(v_expected,1000) then
      raise exception 'ROUNDING_SPLIT_OR_WALLET_WRONG: %',v_expected;
    end if;
    if mod(v_expected,1000)>0 then
      if result->'refund'->>'refund_source'<>'payout_rounding'
        or (result->'refund'->>'amount_iqd')::numeric<>mod(v_expected,1000)
        or result->'refund'->>'payout_settlement_id'<>result->'settlement'->>'id'
        or (select count(*) from public.ex_balance_entries where journal_id=(result->'refund'->>'journal_id')::uuid)<>2
        or (select sum(delta_iqd) from public.ex_balance_entries where journal_id=(result->'refund'->>'journal_id')::uuid)<>0 then
        raise exception 'AUTOMATIC_CASE_OR_BALANCED_LEDGER_WRONG: %',v_expected;
      end if;
    elsif result->'refund'<>'null'::jsonb
      or exists(select 1 from public.ex_balance_journal where operation_key='shortfall:'||v_key) then
      raise exception 'ZERO_REMAINDER_CREATED_JOURNAL';
    end if;
    retried:=pg_temp.rounding_approve(original_o,f.approver,v_key);
    if retried->'settlement'->>'id'<>result->'settlement'->>'id'
      or (select count(*) from public.ex_order_payout_settlements where order_id=o.id)<>1
      or (select count(*) from public.ex_order_shortfall_refunds where order_id=o.id)<>(case when mod(v_expected,1000)>0 then 1 else 0 end)
      or (select count(*) from public.ex_admin_audit_log where action='approve_order_settlement'
        and detail::jsonb->'settlement'->>'order_id'=o.id::text)<>1
      or (select count(*) from public.ex_notifications where order_id=o.id and type='order_approved')<>1 then
      raise exception 'EXACT_RETRY_DUPLICATED_SETTLEMENT: %',v_expected;
    end if;
    if not exists(select 1 from public.ex_notifications where order_id=o.id and type='order_approved'
      and ((v_expected>=1000 and position((trunc(v_expected/1000)*1000)::text in message)>0)
        or (v_expected<1000 and position('ناردنی دەرەکی نییە' in message)>0))) then
      raise exception 'APPROVAL_NOTIFICATION_MISSTATES_PAYOUT';
    end if;
    perform pg_temp.rounding_expect_error(format('select public.ex_admin_approve_order_settlement(%L,%L,%L,%L,%s,%s,true,%L,null,%L)',
      o.id,f.approver,v_key,original_o.updated_at,v_expected,trunc(v_expected/1000)*1000,v_expected>=1000,'Changed request note'),
      'SETTLEMENT_REQUEST_KEY_CONFLICT','22023');
    perform pg_temp.rounding_expect_error(format('select pg_temp.rounding_approve((select o from public.ex_orders o where id=%L),%L,%L)',
      o.id,f.approver,gen_random_uuid()),'ORDER_ALREADY_DECIDED','22023');
    perform pg_temp.rounding_expect_error(format('update public.ex_orders set payout_iqd=payout_iqd+1000 where id=%L',o.id),
      'SETTLEMENT_ORDER_IMMUTABLE','23514');
  end loop;

  -- Permissions are checked afresh, including idempotent retries after revocation.
  o:=pg_temp.rounding_order(f.customer,10500);
  insert into rounding_cases values('pending',o.id,gen_random_uuid(),to_jsonb(o));
  foreach v_role in array array[f.customer,f.refund_admin,f.view_staff,f.banned_admin] loop
    perform pg_temp.rounding_expect_error(format('select pg_temp.rounding_approve((select o from public.ex_orders o where id=%L),%L,%L)',
      o.id,v_role,gen_random_uuid()),'STAFF_PERMISSION_REQUIRED','42501');
  end loop;
  update public.ex_profiles set staff_permissions=array['view'] where id=f.approver;
  select * into c from rounding_cases where label='net-10500';
  perform pg_temp.rounding_expect_error(format('select public.ex_admin_approve_order_settlement(%L,%L,%L,%L,10500,10000,true,true,null,%L)',
    c.order_id,f.approver,c.request_key,c.before_order->>'updated_at','Rounding fixture approval'),'STAFF_PERMISSION_REQUIRED','42501');
  update public.ex_profiles set staff_permissions=array['view','approve_orders'] where id=f.approver;

  -- The version records every reviewed destination edit; SQL compares its full precision.
  update public.ex_orders set phone='07700000002' where id=o.id returning * into o;
  perform pg_temp.rounding_expect_error(format('select public.ex_admin_approve_order_settlement(%L,%L,%L,%L,10500,10000,true,true,null,null)',
    o.id,f.approver,gen_random_uuid(),o.updated_at-interval '1 second'),'ORDER_SETTLEMENT_STALE','22023');
  perform pg_temp.rounding_expect_error(format('select public.ex_admin_approve_order_settlement(%L,%L,%L,%L,10501,10000,true,true,null,null)',
    o.id,f.approver,gen_random_uuid(),o.updated_at),'ORDER_SETTLEMENT_STALE','22023');
  perform pg_temp.rounding_expect_error(format('select public.ex_admin_approve_order_settlement(%L,%L,%L,%L,10500,9000,true,true,null,null)',
    o.id,f.approver,gen_random_uuid(),o.updated_at),'PAYOUT_AMOUNT_MISMATCH','22023');
  perform pg_temp.rounding_expect_error(format('select public.ex_admin_approve_order_settlement(%L,%L,%L,%L,10500,10000,false,true,null,null)',
    o.id,f.approver,gen_random_uuid(),o.updated_at),'INVALID_SETTLEMENT_REQUEST','22023');
  perform pg_temp.rounding_expect_error(format('select public.ex_admin_approve_order_settlement(%L,%L,%L,%L,10500,10000,true,false,null,null)',
    o.id,f.approver,gen_random_uuid(),o.updated_at),'PAYOUT_AMOUNT_MISMATCH','22023');
  foreach v_invalid in array array[-1,0.5,10500.5,1000000001,'NaN'::numeric,'Infinity'::numeric,'-Infinity'::numeric] loop
    perform pg_temp.rounding_expect_error(format('select public.ex_admin_approve_order_settlement(%L,%L,%L,%L,%L::numeric,10000,true,true,null,null)',
      o.id,f.approver,gen_random_uuid(),o.updated_at,v_invalid),'INVALID_SETTLEMENT_REQUEST','22023');
  end loop;
  update public.ex_orders set receipt_url=null where id=o.id returning * into o;
  perform pg_temp.rounding_expect_error(format('select pg_temp.rounding_approve((select o from public.ex_orders o where id=%L),%L,%L)',
    o.id,f.approver,gen_random_uuid()),'RECEIVED_FUNDS_PROOF_REQUIRED','22023');
  update public.ex_orders set receipt_url='https://example.invalid/restored-funding.png' where id=o.id returning * into o;
  other_o:=pg_temp.rounding_order(f.customer,10500,12000.5);
  perform pg_temp.rounding_expect_error(format('select pg_temp.rounding_approve((select o from public.ex_orders o where id=%L),%L,%L)',
    other_o.id,f.approver,gen_random_uuid()),'ORDER_NOT_ELIGIBLE_FOR_SETTLEMENT','22023');

  -- Approval audit failure occurs after posting; its exception rolls everything back.
  select coalesce((select available_iqd from public.ex_customer_balances where user_id=f.customer),0) into v_before_balance;
  select count(*) into v_before_journals from public.ex_balance_journal where user_id=f.customer;
  select count(*) into v_before_notifications from public.ex_notifications where order_id=o.id;
  perform set_config('ex_rounding_test.fail_order',o.id::text,true);
  perform pg_temp.rounding_expect_error(format('select pg_temp.rounding_approve((select o from public.ex_orders o where id=%L),%L,%L)',
    o.id,f.approver,v_fail_key),'ROUNDING_TEST_AUDIT_FAILURE','P0001');
  perform set_config('ex_rounding_test.fail_order','',true);
  if exists(select 1 from public.ex_order_payout_settlements where order_id=o.id)
    or exists(select 1 from public.ex_order_shortfall_refunds where order_id=o.id)
    or (select status from public.ex_orders where id=o.id)<>'چاوەڕوانە'
    or (select available_iqd from public.ex_customer_balances where user_id=f.customer)<>v_before_balance
    or (select count(*) from public.ex_balance_journal where user_id=f.customer)<>v_before_journals
    or (select count(*) from public.ex_notifications where order_id=o.id)<>v_before_notifications then
    raise exception 'APPROVAL_AUDIT_FAILURE_LEFT_PARTIAL_MONEY_OR_STATUS';
  end if;
  result:=pg_temp.rounding_approve(o,f.approver,v_fail_key);
  if result->'settlement'->>'request_key'<>v_fail_key::text then raise exception 'FAILED_KEY_NOT_RETRYABLE';end if;

  -- A valid IQD recipient can have a fractional USDT source amount.
  insert into public.ex_orders(user_id,from_method,to_method,amount,total,phone,receipt_url)
    values(f.customer,'USDT',v_dest,7.5,10500,'07700000001','https://example.invalid/usdt-funding.png') returning * into o;
  v_key:=gen_random_uuid();result:=pg_temp.rounding_approve(o,f.approver,v_key);
  if (result->'order'->>'payout_iqd')::bigint<>10000 or (result->'refund'->>'amount_iqd')::bigint<>500 then
    raise exception 'USDT_TO_IQD_NOT_ROUNDED';end if;
  insert into rounding_cases values('usdt-to-iqd',o.id,v_key,to_jsonb(o));
  perform pg_temp.rounding_expect_error(format('select public.ex_admin_credit_shortfall(%L,%L,1,%L,500,%L,%L,true)',
    o.id,f.refund_admin,gen_random_uuid(),'Manual FX exclusion is preserved','fixture-manual-fx'),
    'ORDER_NOT_ELIGIBLE_FOR_SHORTFALL','22023');
  insert into public.ex_orders(user_id,from_method,to_method,amount,total,phone,receipt_url)
    values(f.customer,'USDT',v_dest,7.5,10500.5,'07700000001','https://example.invalid/usdt-fraction.png') returning * into o;
  perform pg_temp.rounding_expect_error(format('select public.ex_admin_approve_order_settlement(%L,%L,%L,%L,10500,10000,true,true,null,null)',
    o.id,f.approver,gen_random_uuid(),o.updated_at),'ORDER_NOT_ELIGIBLE_FOR_SETTLEMENT','22023');
  insert into public.ex_orders(user_id,from_method,to_method,amount,total,phone,receipt_url)
    values(f.customer,'rounding-excluded','USDT',12000,8,'07700000001','https://example.invalid/usdt-out.png') returning * into o;
  perform pg_temp.rounding_expect_error(format('select pg_temp.rounding_approve((select o from public.ex_orders o where id=%L),%L,%L)',
    o.id,f.approver,gen_random_uuid()),'ORDER_NOT_ELIGIBLE_FOR_SETTLEMENT','22023');
  other_o:=pg_temp.rounding_order(f.customer,10500);
  update public.ex_orders set to_method='AccountBalance' where id=other_o.id returning * into other_o;
  perform pg_temp.rounding_expect_error(format('select pg_temp.rounding_approve((select o from public.ex_orders o where id=%L),%L,%L)',
    other_o.id,f.approver,gen_random_uuid()),'ORDER_NOT_ELIGIBLE_FOR_SETTLEMENT','22023');

  -- AccountBalance funding is already debited, then only its net remainder returns.
  insert into public.ex_rates(from_method,to_method,rate_type,rate_value) values('AccountBalance',v_dest,'fee_percent',2);
  perform public.ex_balance_post(f.other_customer,20000,0,'verified_refund','rounding-fixture-funds:'||gen_random_uuid(),
    null,null,f.refund_admin,'Synthetic rollback fixture funding',null);
  o:=public.ex_balance_create_order(f.other_customer,gen_random_uuid(),v_dest,12000,'07700000001');
  if o.total<>11760 or o.balance_debit_journal_id is null then raise exception 'BALANCE_SOURCE_FIXTURE_INVALID';end if;
  v_key:=gen_random_uuid();result:=pg_temp.rounding_approve(o,f.approver,v_key);
  if result->'settlement'->>'funding_kind'<>'account_balance'
    or (result->'order'->>'payout_iqd')::bigint<>11000
    or (result->'refund'->>'amount_iqd')::bigint<>760
    or (select available_iqd from public.ex_customer_balances where user_id=f.other_customer)<>8760 then
    raise exception 'BALANCE_SOURCE_DEBIT_AND_REMAINDER_WRONG';end if;
  insert into rounding_cases values('balance-source',o.id,v_key,to_jsonb(o));

  -- Rewards stay consumed and their original pricing remains unchanged.
  insert into public.ex_user_rewards(user_id,kind,discount_percent,max_uses,max_amount_iqd,reward_scope,created_by)
    values(f.customer,'free_transactions',100,1,50000,'wallets',f.refund_admin) returning id into v_reward;
  insert into public.ex_rates(from_method,to_method,rate_type,rate_value) values(v_reward_route,v_dest,'fee_percent',2);
  insert into public.ex_orders(user_id,from_method,to_method,amount,total,phone,receipt_url)
    values(f.customer,v_reward_route,v_dest,60000,0,'07700000001','https://example.invalid/rounding-reward.png') returning * into o;
  if o.reward_id is distinct from v_reward or o.total<>59800 or o.fee<>200 then
    raise exception 'REWARD_FIXTURE_NOT_APPLIED';end if;
  original_o:=o;result:=pg_temp.rounding_approve(o,f.approver,gen_random_uuid());
  if (result->'order'->>'total')::numeric<>original_o.total
    or (result->'order'->>'fee')::numeric<>original_o.fee
    or (result->'order'->>'reward_discount_iqd')::numeric<>original_o.reward_discount_iqd
    or (select used_count from public.ex_user_rewards where id=v_reward)<>1
    or exists(select 1 from public.ex_reward_usages where order_id=o.id and reversed_at is not null) then
    raise exception 'SETTLEMENT_CHANGED_REWARD_ENTITLEMENT';end if;
  perform pg_temp.rounding_expect_error(format('update public.ex_orders set reward_scope=%L where id=%L','korek',o.id),null,'23514');

  -- First receipt attachment has its own durable, atomic audit and retry result.
  select * into o from public.ex_orders where id=(select order_id from rounding_cases where label='net-10500');
  perform set_config('ex_rounding_test.fail_receipt',o.id::text,true);
  perform pg_temp.rounding_expect_error(format('select public.ex_admin_attach_settlement_receipt(%L,%L,%L)',
    o.id,f.approver,v_receipt),'ROUNDING_TEST_RECEIPT_AUDIT_FAILURE','P0001');
  perform set_config('ex_rounding_test.fail_receipt','',true);
  if exists(select 1 from public.ex_order_settlement_receipts where order_id=o.id)
    or (select payout_receipt_url from public.ex_orders where id=o.id) is not null then
    raise exception 'RECEIPT_AUDIT_FAILURE_LEFT_UNAUDITED_PROOF';end if;
  receipt_result:=public.ex_admin_attach_settlement_receipt(o.id,f.approver,v_receipt);
  retried:=public.ex_admin_attach_settlement_receipt(o.id,f.approver,v_receipt);
  if receipt_result->'receipt'->>'id'<>retried->'receipt'->>'id'
    or retried->'order'->>'payout_receipt_url'<>v_receipt
    or (select count(*) from public.ex_admin_audit_log where action='attach_settlement_receipt' and detail::jsonb->>'order_id'=o.id::text)<>1 then
    raise exception 'RECEIPT_RETRY_NOT_IDEMPOTENT';end if;
  perform pg_temp.rounding_expect_error(format('select public.ex_admin_attach_settlement_receipt(%L,%L,%L)',
    o.id,f.approver,replace(v_receipt,'proof.png','replacement.png')),'SETTLEMENT_RECEIPT_CONFLICT','22023');
  perform pg_temp.rounding_expect_error(format('update public.ex_orders set payout_receipt_url=null where id=%L',o.id),null,'23514');
  perform pg_temp.rounding_expect_error(format('update public.ex_order_settlement_receipts set payout_receipt_url=%L where order_id=%L',
    replace(v_receipt,'proof.png','replacement.png'),o.id),'IMMUTABLE_FINANCIAL_JOURNAL','P0001');

  -- A later manual 150 IQD adds once to the aggregate, without another rounding pass.
  select request_key into v_key from rounding_cases where label='net-10500';
  perform pg_temp.rounding_expect_error(format('select public.ex_admin_credit_shortfall(%L,%L,500,%L,0,%L,%L,true)',
    o.id,f.refund_admin,v_key,'Cannot reuse automatic approval key','fixture-manual-reserved'),
    'SHORTFALL_REQUEST_KEY_CONFLICT','22023');
  r:=public.ex_admin_credit_shortfall(o.id,f.refund_admin,150,gen_random_uuid(),500,
    'Additional independently verified missing payout','fixture-after-rounding-150',true);
  if r.refund_source<>'manual_shortfall' or r.payout_settlement_id is not null or r.refunded_after_iqd<>650
    or (select payout_iqd from public.ex_orders where id=o.id)<>10000
    or (select payout_rounding_iqd from public.ex_orders where id=o.id)<>500 then
    raise exception 'LATER_MANUAL_CREDIT_CHANGED_FIXED_PAYOUT';end if;
  retried:=public.ex_admin_attach_settlement_receipt(o.id,f.approver,v_receipt);
  if retried->'receipt'->>'id'<>receipt_result->'receipt'->>'id' then raise exception 'ATTACHMENT_RETRY_AFTER_MANUAL_FAILED';end if;
  perform pg_temp.rounding_expect_error(format('select public.ex_admin_reject_and_refund(%L,%L,%L,%L,true)',
    o.id,f.refund_admin,'fixture-rounded-full-reject','Must not reverse an approved settlement'),null,'22023');

  select * into o from public.ex_orders where id=(select order_id from rounding_cases where label='net-1600');
  r:=public.ex_admin_credit_shortfall(o.id,f.refund_admin,150,gen_random_uuid(),600,
    'Manual credit freezes late attachment','fixture-blocks-late-proof',true);
  perform pg_temp.rounding_expect_error(format('select public.ex_admin_attach_settlement_receipt(%L,%L,%L)',
    o.id,f.approver,v_receipt),'SETTLEMENT_RECEIPT_LOCKED','22023');
  select * into o from public.ex_orders where id=(select order_id from rounding_cases where label='net-0');
  perform pg_temp.rounding_expect_error(format('select public.ex_admin_attach_settlement_receipt(%L,%L,%L)',
    o.id,f.approver,v_receipt),'SETTLEMENT_RECEIPT_LOCKED','22023');

  o:=pg_temp.rounding_order(f.customer,10000);
  result:=pg_temp.rounding_approve(o,f.approver,gen_random_uuid(),v_receipt);
  perform pg_temp.rounding_expect_error(format('select public.ex_admin_attach_settlement_receipt(%L,%L,%L)',
    o.id,f.approver,v_receipt),'SETTLEMENT_RECEIPT_LOCKED','22023');
  perform pg_temp.rounding_expect_error(format('update public.ex_orders set phone=%L where id=%L','07700000003',o.id),
    'SETTLEMENT_ORDER_IMMUTABLE','23514');
  perform pg_temp.rounding_expect_error(format('update public.ex_orders set total=total+1 where id=%L',o.id),null,'23514');
  perform pg_temp.rounding_expect_error(format('update public.ex_orders set status=%L where id=%L','ڕەتکرا',o.id),null,'23514');
  perform pg_temp.rounding_expect_error(format('update public.ex_order_payout_settlements set payout_iqd=0 where order_id=%L',o.id),
    'IMMUTABLE_FINANCIAL_JOURNAL','P0001');
  -- No shortfall row exists for an exact-thousand payout, but a full refund
  -- cannot be injected through the older table's service-role INSERT grant.
  perform pg_temp.rounding_expect_error(format(
    'insert into public.ex_refund_cases(order_id,user_id,amount_iqd,receipt_url,bank_verification_reference,failure_reason,verified_by,confirmed_funds_received,confirmed_payout_failed,journal_id,refund_kind) values(%L,%L,12000,%L,%L,%L,%L,true,false,%L,%L)',
    o.id,f.customer,o.receipt_url,'fixture-zero-rounding-full','Direct full refund must not overlap settlement',f.refund_admin,r.journal_id,'admin_rejection'),
    'ORDER_HAS_PAYOUT_SETTLEMENT','23514');

  -- SQL grants and RLS stay narrow even though staff can UPDATE order.status.
  if has_function_privilege('authenticated','public.ex_admin_approve_order_settlement(uuid,uuid,uuid,timestamptz,numeric,numeric,boolean,boolean,text,text)','EXECUTE')
    or has_function_privilege('anon','public.ex_admin_approve_order_settlement(uuid,uuid,uuid,timestamptz,numeric,numeric,boolean,boolean,text,text)','EXECUTE')
    or has_function_privilege('authenticated','public.ex_admin_attach_settlement_receipt(uuid,uuid,text)','EXECUTE')
    or not has_function_privilege('service_role','public.ex_admin_approve_order_settlement(uuid,uuid,uuid,timestamptz,numeric,numeric,boolean,boolean,text,text)','EXECUTE')
    or has_table_privilege('authenticated','public.ex_order_payout_settlements','INSERT')
    or has_table_privilege('service_role','public.ex_order_payout_settlements','INSERT')
    or has_table_privilege('authenticated','public.ex_order_settlement_receipts','UPDATE') then
    raise exception 'SETTLEMENT_API_GRANTS_UNSAFE';end if;
  o:=pg_temp.rounding_order(f.customer,10000);
  perform set_config('request.jwt.claim.sub',f.approver::text,true);
  perform set_config('request.jwt.claim.role','authenticated',true);
  execute 'set local role authenticated';
  begin
    update public.ex_orders set status='پەسەندکرا' where id=o.id;
    raise exception 'DIRECT_AUTHENTICATED_APPROVAL_BYPASSED_SETTLEMENT';
  exception when insufficient_privilege then
    if sqlerrm<>'ATOMIC_IQD_SETTLEMENT_REQUIRED' then raise;end if;
  end;
  execute 'reset role';
  perform set_config('request.jwt.claim.sub',f.other_customer::text,true);
  execute 'set local role authenticated';
  if exists(select 1 from public.ex_order_payout_settlements where user_id=f.customer)
    or exists(select 1 from public.ex_order_settlement_receipts where user_id=f.customer) then
    raise exception 'SETTLEMENT_RLS_EXPOSES_OTHER_CUSTOMER';end if;
  if not exists(select 1 from public.ex_order_payout_settlements where user_id=f.other_customer) then
    raise exception 'SETTLEMENT_RLS_HIDES_OWN_HISTORY';end if;
  execute 'reset role';
  perform set_config('request.jwt.claim.role','service_role',true);
  perform set_config('request.jwt.claim.sub','',true);

  -- Every new consistency count is zero and none of the original counts worsens.
  v_report:=public.ex_admin_balance_reconcile(f.approver);
  foreach v_field in array array['unbalanced_journals','balance_mismatches','held_payout_mismatches',
    'unlinked_refunds','unlinked_shortfalls','shortfall_amount_mismatches','rounding_settlement_mismatches'] loop
    if (v_report->>v_field)::bigint<>(v_before_report->>v_field)::bigint then
      raise exception 'RECONCILIATION_REGRESSED: %',v_field;end if;
  end loop;
  if (v_report->>'clearing_mismatch')::boolean is distinct from (v_before_report->>'clearing_mismatch')::boolean
    or exists(select 1 from public.ex_order_payout_settlements s
      where s.user_id in(f.customer,f.other_customer) and not public.ex_payout_settlement_consistent(s.id)) then
    raise exception 'ROUNDING_FINAL_LEDGER_INCONSISTENCY';end if;
end $test$;

-- Do not let a deferred FK/financial assertion escape the migration self-test.
set constraints all immediate;
do $unchanged$
begin
  if pg_temp.rounding_existing_state() is distinct from (select value from rounding_existing_before) then
    raise exception 'ROUNDING_FIXTURE_CHANGED_EXISTING_CUSTOMER_RECORDS';
  end if;
  if (select tgenabled from pg_trigger where tgrelid='public.ex_orders'::regclass
    and tgname='trg_ex_orders_settlement_guard') is distinct from 'O'::"char" then
    raise exception 'ROUNDING_FIXTURE_DID_NOT_RESTORE_GUARD';
  end if;
end $unchanged$;
select 'PASS: IQD 1,000 settlement splits, zero/sub-1,000, FX recipient, source proof, stale snapshot, fresh permissions, retry conflicts, audit rollback, immutable receipts, later manual refund, balanced ledger and owner RLS' as result;
rollback;
