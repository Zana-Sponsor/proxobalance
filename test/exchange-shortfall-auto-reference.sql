-- Automatic API references need no schema change. Run this complete script as
-- a trusted operator after ORDER_SHORTFALL.sql. It uses only synthetic DML and
-- DO assertions; every user, order, rate, credit and notification rolls back.
-- The reference expression mirrors the API's canonical-UUID derivation.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '60s';
set local request.jwt.claim.role = 'service_role';

do $test$
declare
  v_user uuid := gen_random_uuid();
  v_admin uuid := gen_random_uuid();
  v_auto_key uuid := gen_random_uuid();
  v_stale_key uuid := gen_random_uuid();
  v_legacy_key uuid := gen_random_uuid();
  v_route text := 'shortfall-auto-fixture-' || gen_random_uuid()::text;
  v_auto_ref text := 'shortfall:' || v_auto_key::text;
  v_legacy_ref text := 'legacy-manual-proof-' || v_legacy_key::text;
  v_reason text := 'Verified undelivered amount of 150 IQD';
  v_legacy_reason text := 'Legacy tab separately verified another 50 IQD';
  v_order public.ex_orders%rowtype;
  v_auto public.ex_order_shortfall_refunds%rowtype;
  v_legacy public.ex_order_shortfall_refunds%rowtype;
  v_retry public.ex_order_shortfall_refunds%rowtype;
  v_auto_snapshot jsonb;
  v_legacy_snapshot jsonb;
  v_notifications_before bigint;
begin
  insert into auth.users(id,email,raw_user_meta_data) values
    (v_user,'shortfall-auto-user-'||v_user||'@example.invalid','{"full_name":"Auto Reference Fixture Customer"}'),
    (v_admin,'shortfall-auto-admin-'||v_admin||'@example.invalid','{"full_name":"Auto Reference Fixture Admin"}');
  update public.ex_profiles set role='admin' where id=v_admin;
  update public.ex_profiles set staff_permissions=array['view','refunds'] where id=v_admin;
  update public.ex_user_rewards set active=false
    where user_id in(v_user,v_admin) and campaign_key='welcome_signup_v1';
  insert into public.ex_rates(from_method,to_method,rate_type,rate_value)
    values(v_route,v_route||'-destination','fee_percent',2);
  insert into public.ex_orders(user_id,from_method,to_method,amount,total,phone,receipt_url,receipt_hash)
    values(v_user,v_route,v_route||'-destination',10000,0,'07700000001',
      'https://example.invalid/shortfall-auto-receipt.png',md5(v_route)||md5(v_route||'-receipt'))
    returning * into v_order;
  update public.ex_orders set status='پەسەندکرا',payout_receipt_url='https://example.invalid/shortfall-auto-payout.png'
    where id=v_order.id returning * into v_order;
  select count(*) into v_notifications_before from public.ex_notifications where user_id=v_user and order_id=v_order.id;

  v_auto:=public.ex_admin_credit_shortfall(v_order.id,v_admin,150,v_auto_key,0,v_reason,v_auto_ref,true);
  v_auto_snapshot:=to_jsonb(v_auto);
  if v_auto.amount_iqd<>150 or v_auto.verification_reference<>v_auto_ref
    or char_length(v_auto.verification_reference)<>46
    or v_auto.balance_before_iqd<>0 or v_auto.balance_after_iqd<>150
    or v_auto.refunded_before_iqd<>0 or v_auto.refunded_after_iqd<>150
    or (select available_iqd from public.ex_customer_balances where user_id=v_user)<>150 then
    raise exception 'AUTO_REFERENCE_OR_EXACT_150_CREDIT_WRONG';
  end if;
  -- A reloaded client must keep its original UUID, reason and baseline of zero.
  -- Canonicalizing an uppercase UUID must regenerate the same reference string.
  v_retry:=public.ex_admin_credit_shortfall(v_order.id,v_admin,150,v_auto_key,0,
    v_reason,'shortfall:'||lower(upper(v_auto_key::text)),true);
  if to_jsonb(v_retry) is distinct from v_auto_snapshot then
    raise exception 'AUTO_REFERENCE_RETRY_DID_NOT_RETURN_ORIGINAL_CASE';
  end if;
  if (select count(*) from public.ex_order_shortfall_refunds where order_id=v_order.id)<>1
    or (select count(*) from public.ex_balance_journal where order_id=v_order.id and kind='shortfall_refund')<>1
    or (select count(*) from public.ex_admin_audit_log where target_user_id=v_user and action='balance_credit_shortfall')<>1
    or (select count(*) from public.ex_notifications where user_id=v_user and order_id=v_order.id)<>v_notifications_before+1
    or (select count(*) from public.ex_balance_entries where journal_id=v_auto.journal_id)<>2
    or (select sum(delta_iqd) from public.ex_balance_entries where journal_id=v_auto.journal_id)<>0
    or (select available_iqd from public.ex_customer_balances where user_id=v_user)<>150 then
    raise exception 'AUTO_RETRY_DUPLICATED_LEDGER_AUDIT_NOTIFICATION_OR_BALANCE';
  end if;

  begin
    perform public.ex_admin_credit_shortfall(v_order.id,v_admin,150,v_stale_key,0,
      v_reason,'shortfall:'||v_stale_key::text,true);
    raise exception 'FRESH_KEY_WITH_STALE_BASELINE_ACCEPTED';
  exception when invalid_parameter_value then
    if sqlerrm<>'SHORTFALL_STATE_CHANGED' then raise;end if;
  end;
  begin
    perform public.ex_admin_credit_shortfall(v_order.id,v_admin,151,v_auto_key,0,v_reason,v_auto_ref,true);
    raise exception 'PERSISTED_KEY_WITH_CHANGED_AMOUNT_ACCEPTED';
  exception when invalid_parameter_value then
    if sqlerrm<>'SHORTFALL_REQUEST_KEY_CONFLICT' then raise;end if;
  end;
  begin
    perform public.ex_admin_credit_shortfall(v_order.id,v_admin,150,v_auto_key,150,v_reason,v_auto_ref,true);
    raise exception 'RETRY_SILENTLY_REPLACED_ORIGINAL_BASELINE';
  exception when invalid_parameter_value then
    if sqlerrm<>'SHORTFALL_REQUEST_KEY_CONFLICT' then raise;end if;
  end;
  -- The required DB column stays intact: the API, not a migration, derives it.
  begin
    perform public.ex_admin_credit_shortfall(v_order.id,v_admin,1,gen_random_uuid(),150,
      'Missing API reference must still be rejected',null,true);
    raise exception 'NULL_DATABASE_REFERENCE_ACCEPTED';
  exception when invalid_parameter_value then
    if sqlerrm<>'INVALID_SHORTFALL_REQUEST' then raise;end if;
  end;
  if (select shortfall_refunded_iqd from public.ex_orders where id=v_order.id)<>150
    or (select count(*) from public.ex_order_shortfall_refunds where order_id=v_order.id)<>1 then
    raise exception 'INVALID_AUTO_REQUEST_LEFT_PARTIAL_STATE';
  end if;

  -- An old browser tab keeps sending its manual reference. Preserve it exactly
  -- apart from the existing trim, or its safe same-key replay will conflict.
  v_legacy:=public.ex_admin_credit_shortfall(v_order.id,v_admin,50,v_legacy_key,150,
    v_legacy_reason,v_legacy_ref,true);
  v_legacy_snapshot:=to_jsonb(v_legacy);
  v_retry:=public.ex_admin_credit_shortfall(v_order.id,v_admin,50,v_legacy_key,150,
    v_legacy_reason,' '||v_legacy_ref||' ',true);
  if to_jsonb(v_retry) is distinct from v_legacy_snapshot or v_legacy.verification_reference<>v_legacy_ref then
    raise exception 'LEGACY_REFERENCE_OR_LEGACY_RETRY_CHANGED';
  end if;
  begin
    perform public.ex_admin_credit_shortfall(v_order.id,v_admin,50,v_legacy_key,150,
      v_legacy_reason,'shortfall:'||v_legacy_key::text,true);
    raise exception 'LEGACY_REFERENCE_WAS_SILENTLY_REPLACED';
  exception when invalid_parameter_value then
    if sqlerrm<>'SHORTFALL_REQUEST_KEY_CONFLICT' then raise;end if;
  end;
  -- Original auto retry still succeeds after a later legitimate credit, before
  -- the aggregate-staleness check; neither old case may be rewritten.
  v_retry:=public.ex_admin_credit_shortfall(v_order.id,v_admin,150,v_auto_key,0,v_reason,v_auto_ref,true);
  if to_jsonb(v_retry) is distinct from v_auto_snapshot
    or (select to_jsonb(r) from public.ex_order_shortfall_refunds r where r.id=v_legacy.id) is distinct from v_legacy_snapshot
    or (select count(*) from public.ex_order_shortfall_refunds where order_id=v_order.id)<>2
    or (select count(*) from public.ex_balance_journal where order_id=v_order.id and kind='shortfall_refund')<>2
    or (select count(*) from public.ex_admin_audit_log where target_user_id=v_user and action='balance_credit_shortfall')<>2
    or (select count(*) from public.ex_notifications where user_id=v_user and order_id=v_order.id)<>v_notifications_before+2
    or (select available_iqd from public.ex_customer_balances where user_id=v_user)<>200
    or (select shortfall_refunded_iqd from public.ex_orders where id=v_order.id)<>200
    or (select status from public.ex_orders where id=v_order.id)<>'پەسەندکرا'
    or (select fee from public.ex_orders where id=v_order.id) is distinct from v_order.fee
    or exists(select 1 from public.ex_refund_cases where order_id=v_order.id) then
    raise exception 'AUTO_OR_LEGACY_REPLAY_CHANGED_EXISTING_CREDIT_OR_ORDER';
  end if;
end $test$;

rollback;
select 'PASS: automatic reference, exact 150 IQD replay, one ledger/audit/notification, stale and changed-payload rejection, legacy compatibility; synthetic fixtures rolled back' as result;
