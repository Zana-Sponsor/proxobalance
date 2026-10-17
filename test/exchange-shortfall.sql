-- Run only as a trusted database operator after ORDER_SHORTFALL.sql.
-- All IDs, users, orders, rewards, funds, notifications and test trigger are
-- synthetic, created inside this transaction and removed by its ROLLBACK.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';
set local request.jwt.claim.role = 'service_role';
create temporary table shortfall_fixture as select
  gen_random_uuid() as customer, gen_random_uuid() as other_customer,
  gen_random_uuid() as admin, gen_random_uuid() as staff;
grant select on shortfall_fixture to authenticated;

-- An intentional failure after wallet posting proves the whole RPC rolls back.
create function pg_temp.shortfall_fail_audit() returns trigger
language plpgsql as $fn$
begin
  if new.action = 'balance_credit_shortfall' and new.target_user_id::text =
    current_setting('ex_shortfall_test.fail_audit_for', true) then
    raise exception 'SHORTFALL_TEST_AUDIT_FAILURE';
  end if;
  return new;
end $fn$;
create trigger shortfall_fixture_fail_audit before insert on public.ex_admin_audit_log
  for each row execute function pg_temp.shortfall_fail_audit();

do $test$
declare
  f record;
  v_route text := 'shortfall-fixture-' || gen_random_uuid()::text;
  v_dest text := 'shortfall-dest-' || gen_random_uuid()::text;
  v_key uuid := gen_random_uuid();
  v_fault_key uuid := gen_random_uuid();
  v_reward uuid;
  o public.ex_orders%rowtype;
  pending_o public.ex_orders%rowtype;
  unproven_o public.ex_orders%rowtype;
  balance_o public.ex_orders%rowtype;
  usdt_o public.ex_orders%rowtype;
  r public.ex_order_shortfall_refunds%rowtype;
  retried public.ex_order_shortfall_refunds%rowtype;
  invalid_amount numeric;
  v_count bigint;
  v_journals bigint;
  v_balance bigint;
  v_report jsonb;
  v_role text;
begin
  select * into f from shortfall_fixture;
  insert into auth.users(id,email,raw_user_meta_data) values
    (f.customer,'shortfall-customer-'||f.customer||'@example.invalid','{"full_name":"Shortfall Test Customer"}'),
    (f.other_customer,'shortfall-other-'||f.other_customer||'@example.invalid','{"full_name":"Shortfall Other Customer"}'),
    (f.admin,'shortfall-admin-'||f.admin||'@example.invalid','{"full_name":"Shortfall Test Admin"}'),
    (f.staff,'shortfall-staff-'||f.staff||'@example.invalid','{"full_name":"Shortfall View Only"}');
  update public.ex_profiles set role='admin' where id in(f.admin,f.staff);
  update public.ex_profiles set staff_permissions=array['view','refunds'] where id=f.admin;
  update public.ex_profiles set staff_permissions=array['view'] where id=f.staff;
  update public.ex_user_rewards set active=false
    where user_id in(f.customer,f.other_customer,f.admin,f.staff) and campaign_key='welcome_signup_v1';
  insert into public.ex_wallets(key,name,allow_from,allow_receive)
    values(v_dest,'Shortfall fixture wallet',true,true);
  insert into public.ex_rates(from_method,to_method,rate_type,rate_value)
    values(v_route,v_dest,'fee_percent',2),('AccountBalance',v_dest,'fee_percent',2);
  insert into public.ex_user_rewards(user_id,kind,discount_percent,max_uses,max_amount_iqd,reward_scope,created_by)
    values(f.customer,'free_transactions',100,1,50000,'wallets',f.admin) returning id into v_reward;
  insert into public.ex_orders(user_id,from_method,to_method,amount,total,phone,receipt_url,receipt_hash)
    values(f.customer,v_route,v_dest,60000,0,'07700000001','https://example.invalid/shortfall-fixture.png',
      md5(v_route)||md5(v_dest)) returning * into o;
  update public.ex_orders set status='پەسەندکرا',payout_receipt_url='https://example.invalid/shortfall-payout.png'
    where id=o.id returning * into o;
  if o.amount<>60000 or o.total<>59800 or o.fee<>200 or o.reward_id<>v_reward then
    raise exception 'FIXTURE_PRICING_NOT_60000_PRINCIPAL_59800_PAYOUT';
  end if;

  r:=public.ex_admin_credit_shortfall(o.id,f.admin,150,v_key,0,
    'Verified 150 IQD not delivered','fixture-shortfall-first',true);
  if r.amount_iqd<>150 or r.expected_iqd<>59800 or r.refunded_before_iqd<>0 or r.refunded_after_iqd<>150
    or r.balance_before_iqd<>0 or r.balance_after_iqd<>150 or r.user_id<>f.customer or r.admin_id<>f.admin
    or r.order_code<>o.order_code or r.journal_id is null
    or (select available_iqd from public.ex_customer_balances where user_id=f.customer)<>150
    or (select shortfall_refunded_iqd from public.ex_orders where id=o.id)<>150 then
    raise exception 'EXACT_150_CREDIT_OR_AUDIT_SNAPSHOTS_WRONG';
  end if;
  if (select count(*) from public.ex_balance_entries where journal_id=r.journal_id)<>2
    or (select sum(delta_iqd) from public.ex_balance_entries where journal_id=r.journal_id)<>0
    or not exists(select 1 from public.ex_balance_journal where id=r.journal_id and kind='shortfall_refund')
    or not exists(select 1 from public.ex_admin_audit_log where admin_id=f.admin
      and action='balance_credit_shortfall' and detail::jsonb->>'id'=r.id::text) then
    raise exception 'BALANCED_LEDGER_OR_DETAILED_ADMIN_AUDIT_MISSING';
  end if;
  retried:=public.ex_admin_credit_shortfall(o.id,f.admin,150,v_key,0,
    'Verified 150 IQD not delivered','fixture-shortfall-first',true);
  if retried.id<>r.id or (select available_iqd from public.ex_customer_balances where user_id=f.customer)<>150 then
    raise exception 'EXACT_RETRY_CREDITED_TWICE';
  end if;
  begin
    perform public.ex_admin_credit_shortfall(o.id,f.admin,151,v_key,0,
      'Verified 150 IQD not delivered','fixture-shortfall-first',true);
    raise exception 'CHANGED_REQUEST_KEY_PAYLOAD_ACCEPTED';
  exception when invalid_parameter_value then
    if sqlerrm<>'SHORTFALL_REQUEST_KEY_CONFLICT' then raise;end if;
  end;
  begin
    perform public.ex_admin_credit_shortfall(o.id,f.admin,150,gen_random_uuid(),0,
      'Second tab has stale refund total','fixture-shortfall-stale',true);
    raise exception 'STALE_FORM_ACCEPTED';
  exception when invalid_parameter_value then
    if sqlerrm<>'SHORTFALL_STATE_CHANGED' then raise;end if;
  end;
  begin
    perform public.ex_admin_credit_shortfall(o.id,f.admin,150,gen_random_uuid(),150,
      'New key must not reuse the same evidence',' fixture-shortfall-first ',true);
    raise exception 'DUPLICATE_EVIDENCE_ACCEPTED';
  exception when unique_violation then
    if sqlerrm<>'SHORTFALL_EVIDENCE_ALREADY_USED' then raise;end if;
  end;
  r:=public.ex_admin_credit_shortfall(o.id,f.admin,200,gen_random_uuid(),150,
    'Second independently verified shortfall','fixture-shortfall-second',true);
  if r.refunded_before_iqd<>150 or r.refunded_after_iqd<>350 or r.balance_before_iqd<>150
    or r.balance_after_iqd<>350 then raise exception 'SECOND_CREDIT_NOT_CUMULATIVE';end if;
  -- Principal is 60000, but maximum refundable payout is 59800.
  begin
    perform public.ex_admin_credit_shortfall(o.id,f.admin,59800-350+1,gen_random_uuid(),350,
      'Must cap against payout not principal','fixture-shortfall-overcap',true);
    raise exception 'REFUND_EXCEEDED_EXPECTED_PAYOUT';
  exception when invalid_parameter_value then
    if sqlerrm<>'SHORTFALL_EXCEEDS_REMAINING' then raise;end if;
  end;
  foreach invalid_amount in array array[null::numeric,0,-1,0.5,150.5,1000000001,'NaN'::numeric,'Infinity'::numeric,'-Infinity'::numeric] loop
    begin
      perform public.ex_admin_credit_shortfall(o.id,f.admin,invalid_amount,gen_random_uuid(),350,
        'Invalid amount must never be rounded','fixture-shortfall-invalid',true);
      raise exception 'INVALID_AMOUNT_ACCEPTED: %',invalid_amount;
    exception when invalid_parameter_value then
      if sqlerrm<>'INVALID_SHORTFALL_REQUEST' then raise;end if;
    end;
  end loop;
  begin
    perform public.ex_admin_credit_shortfall(o.id,f.admin,1,gen_random_uuid(),350.1,
      'Fractional baseline must be rejected','fixture-shortfall-baseline',true);
    raise exception 'FRACTIONAL_BASELINE_ACCEPTED';
  exception when invalid_parameter_value then null;end;
  begin
    perform public.ex_admin_credit_shortfall(o.id,f.admin,1,gen_random_uuid(),350,
      'An explicit confirmation is required','fixture-shortfall-confirm',false);
    raise exception 'MISSING_CONFIRMATION_ACCEPTED';
  exception when invalid_parameter_value then null;end;
  begin
    perform public.ex_admin_credit_shortfall(o.id,f.staff,1,gen_random_uuid(),350,
      'View only staff must not credit money','fixture-shortfall-staff',true);
    raise exception 'VIEW_ONLY_STAFF_CREDITED';
  exception when insufficient_privilege then null;end;
  begin
    perform public.ex_admin_credit_shortfall(o.id,f.customer,1,gen_random_uuid(),350,
      'Customer must not credit their account','fixture-shortfall-customer',true);
    raise exception 'CUSTOMER_CREDITED_OWN_ACCOUNT';
  exception when insufficient_privilege then null;end;
  update public.ex_profiles set staff_permissions=array['view'] where id=f.admin;
  begin
    perform public.ex_admin_credit_shortfall(o.id,f.admin,150,v_key,0,
      'Verified 150 IQD not delivered','fixture-shortfall-first',true);
    raise exception 'REVOKED_ADMIN_REPLAY_ALLOWED';
  exception when insufficient_privilege then null;end;
  update public.ex_profiles set staff_permissions=array['view','refunds'] where id=f.admin;

  -- Existing reversal/full-refund paths and direct mutation must not reopen money.
  begin
    perform public.ex_admin_reject_and_refund(o.id,f.admin,'fixture-full-refund',
      'A credited completed order cannot be fully refunded',true);
    raise exception 'OLD_FULL_REFUND_ACCEPTED_SHORTFALL_ORDER';
  exception when invalid_parameter_value or check_violation then null;end;
  begin
    insert into public.ex_refund_cases(order_id,user_id,amount_iqd,receipt_url,
      bank_verification_reference,failure_reason,verified_by,confirmed_funds_received,
      confirmed_payout_failed,journal_id,refund_kind)
    values(o.id,f.customer,60000,o.receipt_url,'fixture-shortfall-direct-full',
      'Direct full refund must reject a shortfall order',f.admin,true,false,r.journal_id,'admin_rejection');
    raise exception 'DIRECT_FULL_REFUND_INSERT_ACCEPTED';
  exception when check_violation then
    if sqlerrm<>'ORDER_HAS_SHORTFALL_REFUND' then raise;end if;
  end;
  begin
    update public.ex_orders set status='ڕەتکرا' where id=o.id;
    raise exception 'SHORTFALL_ORDER_STATUS_CHANGED';
  exception when check_violation then null;end;
  begin
    update public.ex_orders set total=total+1 where id=o.id;
    raise exception 'SHORTFALL_ORDER_PAYOUT_CHANGED';
  exception when check_violation then null;end;
  begin
    update public.ex_orders set payout_receipt_url=null where id=o.id;
    raise exception 'SHORTFALL_PAYOUT_EVIDENCE_REMOVED';
  exception when check_violation then null;end;
  begin
    update public.ex_orders set reward_scope='korek' where id=o.id;
    raise exception 'SHORTFALL_REWARD_SCOPE_CHANGED';
  exception when check_violation then null;end;
  begin
    update public.ex_orders set shortfall_refunded_iqd=0 where id=o.id;
    raise exception 'SHORTFALL_AGGREGATE_RESET';
  exception when check_violation then null;end;
  begin
    update public.ex_order_shortfall_refunds set reason='A changed audit reason' where id=r.id;
    raise exception 'SHORTFALL_AUDIT_MUTABLE';
  exception when raise_exception then
    if sqlerrm<>'IMMUTABLE_FINANCIAL_JOURNAL' then raise;end if;
  end;
  if (select status from public.ex_orders where id=o.id)<>'پەسەندکرا'
    or (select fee from public.ex_orders where id=o.id)<>200
    or (select used_count from public.ex_user_rewards where id=v_reward)<>1
    or exists(select 1 from public.ex_reward_usages where order_id=o.id and reversed_at is not null)
    or exists(select 1 from public.ex_refund_cases where order_id=o.id) then
    raise exception 'SHORTFALL_CHANGED_STATUS_FEES_OR_REWARD_QUOTA';
  end if;

  select count(*) into v_count from public.ex_order_shortfall_refunds where user_id=f.customer;
  select count(*) into v_journals from public.ex_balance_journal where user_id=f.customer;
  select available_iqd into v_balance from public.ex_customer_balances where user_id=f.customer;
  perform set_config('ex_shortfall_test.fail_audit_for',f.customer::text,true);
  begin
    perform public.ex_admin_credit_shortfall(o.id,f.admin,25,v_fault_key,350,
      'Audit failure must roll back wallet and order','fixture-shortfall-fault',true);
    raise exception 'AUDIT_FAILURE_DID_NOT_FAIL_RPC';
  exception when raise_exception then
    if sqlerrm<>'SHORTFALL_TEST_AUDIT_FAILURE' then raise;end if;
  end;
  perform set_config('ex_shortfall_test.fail_audit_for','',true);
  if (select count(*) from public.ex_order_shortfall_refunds where user_id=f.customer)<>v_count
    or (select count(*) from public.ex_balance_journal where user_id=f.customer)<>v_journals
    or (select available_iqd from public.ex_customer_balances where user_id=f.customer)<>v_balance
    or (select shortfall_refunded_iqd from public.ex_orders where id=o.id)<>350 then
    raise exception 'FAILED_AUDIT_LEFT_PARTIAL_CREDIT';
  end if;
  -- The failed key can be retried after rollback; no poisoned idempotency record.
  r:=public.ex_admin_credit_shortfall(o.id,f.admin,25,v_fault_key,350,
    'Audit failure must roll back wallet and order','fixture-shortfall-fault',true);
  if r.refunded_after_iqd<>375 then raise exception 'FAILED_KEY_NOT_RETRYABLE';end if;

  insert into public.ex_orders(user_id,from_method,to_method,amount,total,phone,receipt_url)
    values(f.customer,v_route,v_dest,10000,0,'07700000001','https://example.invalid/pending.png') returning * into pending_o;
  begin
    perform public.ex_admin_credit_shortfall(pending_o.id,f.admin,1,gen_random_uuid(),0,
      'Pending orders are not shortfall eligible','fixture-shortfall-pending',true);
    raise exception 'PENDING_ORDER_CREDITED';
  exception when invalid_parameter_value then null;end;
  insert into public.ex_orders(user_id,from_method,to_method,amount,total,phone)
    values(f.customer,v_route,v_dest,10000,0,'07700000001') returning * into unproven_o;
  update public.ex_orders set status='پەسەندکرا' where id=unproven_o.id;
  begin
    perform public.ex_admin_credit_shortfall(unproven_o.id,f.admin,1,gen_random_uuid(),0,
      'Source funds evidence is required','fixture-shortfall-noproof',true);
    raise exception 'ORDER_WITHOUT_FUNDS_PROOF_CREDITED';
  exception when invalid_parameter_value then null;end;
  insert into public.ex_orders(user_id,from_method,to_method,amount,total,phone,receipt_url)
    values(f.customer,'USDT',v_dest,10000,10000,'07700000001','https://example.invalid/usdt.png') returning * into usdt_o;
  update public.ex_orders set status='پەسەندکرا' where id=usdt_o.id;
  begin
    perform public.ex_admin_credit_shortfall(usdt_o.id,f.admin,1,gen_random_uuid(),0,
      'USDT routes cannot receive IQD shortfall credit','fixture-shortfall-usdt',true);
    raise exception 'USDT_ORDER_CREDITED';
  exception when invalid_parameter_value then null;end;

  -- A real internal debit is also valid source proof, with no external receipt.
  perform public.ex_balance_post(f.other_customer,100000,0,'verified_refund',
    'shortfall-fixture-opening:'||f.other_customer,null,null,f.admin,'Synthetic opening funds only');
  balance_o:=public.ex_balance_create_order(f.other_customer,gen_random_uuid(),v_dest,60000,'07700000002');
  update public.ex_orders set status='پەسەندکرا' where id=balance_o.id;
  r:=public.ex_admin_credit_shortfall(balance_o.id,f.admin,150,gen_random_uuid(),0,
    'Shortfall on an internally funded transfer','fixture-shortfall-balance',true);
  if r.balance_before_iqd<>40000 or r.balance_after_iqd<>40150 then
    raise exception 'INTERNAL_DEBIT_SHORTFALL_PROOF_OR_BALANCE_WRONG';
  end if;
  v_report:=public.ex_admin_balance_reconcile(f.admin);
  if (v_report->>'unlinked_shortfalls')::bigint<>0 or (v_report->>'shortfall_amount_mismatches')::bigint<>0 then
    raise exception 'SHORTFALL_RECONCILIATION_FAILED: %',v_report;
  end if;
  foreach v_role in array array['anon','authenticated'] loop
    if has_function_privilege(v_role,'public.ex_admin_credit_shortfall(uuid,uuid,numeric,uuid,numeric,text,text,boolean)','EXECUTE')
      or has_table_privilege(v_role,'public.ex_order_shortfall_refunds','INSERT')
      or has_table_privilege(v_role,'public.ex_order_shortfall_refunds','UPDATE')
      or has_table_privilege(v_role,'public.ex_order_shortfall_refunds','DELETE') then
      raise exception 'UNTRUSTED_SHORTFALL_WRITE_PRIVILEGE: %',v_role;
    end if;
  end loop;
  if has_table_privilege('service_role','public.ex_order_shortfall_refunds','INSERT')
    or not has_function_privilege('service_role','public.ex_admin_credit_shortfall(uuid,uuid,numeric,uuid,numeric,text,text,boolean)','EXECUTE') then
    raise exception 'SERVICE_SHORTFALL_ACCESS_NOT_RPC_ONLY';
  end if;
end $test$;

-- Exercise actual RLS as a synthetic customer rather than only reading policies.
set local role authenticated;
set local request.jwt.claim.role='authenticated';
select set_config('request.jwt.claim.sub',(select customer::text from shortfall_fixture),true);
do $test$
declare f record;
begin
  select * into f from shortfall_fixture;
  if (select count(*) from public.ex_order_shortfall_refunds where user_id=f.customer)<>3
    or exists(select 1 from public.ex_order_shortfall_refunds where user_id<>f.customer) then
    raise exception 'SHORTFALL_OWNER_HISTORY_RLS_FAILED';
  end if;
  begin
    perform public.ex_admin_credit_shortfall(gen_random_uuid(),f.admin,150,gen_random_uuid(),0,
      'Browser cannot invoke a privileged refund','fixture-shortfall-browser',true);
    raise exception 'BROWSER_CALLED_PRIVILEGED_RPC';
  exception when insufficient_privilege then null;end;
end $test$;
reset role;
rollback;
select 'PASS: exact 150 IQD, cumulative payout cap, replay, stale form, duplicate evidence, authorization, source proof, immutable audit, reward preservation, rollback and owner RLS' as result;
