-- Exact IQD shortfall credits for completed exchange orders.
-- Additive: no existing order is changed or customer balance credited on install.
-- Apply after BALANCE_SOURCE, CUSTOMER_STAFF_FEATURES and PROCESSING_RECONCILIATION.
set local lock_timeout = '5s';
set local statement_timeout = '60s';
alter table public.ex_orders
  add column shortfall_refunded_iqd bigint not null default 0
  check (shortfall_refunded_iqd between 0 and 1000000000);

create table public.ex_order_shortfall_refunds (
  id uuid primary key default gen_random_uuid(),
  request_key uuid not null unique,
  order_id uuid not null references public.ex_orders(id) on delete restrict,
  order_code text not null,
  user_id uuid not null references public.ex_profiles(id) on delete restrict,
  customer_phone text,
  admin_id uuid not null references public.ex_profiles(id) on delete restrict,
  amount_iqd bigint not null check (amount_iqd between 1 and 1000000000),
  expected_iqd bigint not null check (expected_iqd between 1 and 1000000000),
  expected_refunded_iqd bigint not null check (expected_refunded_iqd >= 0),
  refunded_before_iqd bigint not null check (refunded_before_iqd >= 0),
  refunded_after_iqd bigint not null,
  balance_before_iqd bigint not null check (balance_before_iqd >= 0),
  balance_after_iqd bigint not null,
  journal_id uuid not null unique references public.ex_balance_journal(id) on delete restrict,
  reason text not null check (char_length(reason) between 10 and 2000 and reason = btrim(reason)),
  verification_reference text not null check (char_length(verification_reference) between 6 and 160 and verification_reference = btrim(verification_reference)),
  confirmed_shortfall boolean not null check (confirmed_shortfall),
  order_snapshot jsonb not null,
  created_at timestamptz not null default now(),
  constraint ex_order_shortfall_evidence_once unique (order_id, verification_reference),
  constraint ex_order_shortfall_amounts_match check (
    expected_refunded_iqd = refunded_before_iqd
    and refunded_after_iqd = refunded_before_iqd + amount_iqd
    and refunded_after_iqd <= expected_iqd
    and balance_after_iqd = balance_before_iqd + amount_iqd)
);
create index ex_order_shortfall_user_created_idx on public.ex_order_shortfall_refunds(user_id, created_at desc);
create index ex_order_shortfall_order_created_idx on public.ex_order_shortfall_refunds(order_id, created_at desc);
create index ex_order_shortfall_admin_idx on public.ex_order_shortfall_refunds(admin_id);
alter table public.ex_order_shortfall_refunds enable row level security;
create policy ex_order_shortfall_own_read on public.ex_order_shortfall_refunds
  for select to authenticated using (
    user_id = (select auth.uid()) or (select public.ex_staff_has('refunds')));
revoke all on public.ex_order_shortfall_refunds from public, anon, authenticated, service_role;
grant select on public.ex_order_shortfall_refunds to authenticated, service_role;
create trigger ex_order_shortfall_immutable before update or delete on public.ex_order_shortfall_refunds
  for each row execute function public.ex_balance_deny_journal_mutation();
comment on table public.ex_order_shortfall_refunds is
  'Append-only, exact IQD credits of verified undelivered payout amounts. Original fees, rewards and approved status are preserved.';
comment on column public.ex_orders.shortfall_refunded_iqd is
  'Cumulative shortfall ledger credits; bounded by expected payout total, never original principal amount.';

-- Protect the order's accounting/evidence and aggregate, including all old status
-- and full-refund entry points. The aggregate must equal its immutable case rows.
create function public.ex_order_shortfall_guard() returns trigger
language plpgsql security definer set search_path = '' as $fn$
declare v_sum numeric;
begin
  if tg_op = 'DELETE' then
    if old.shortfall_refunded_iqd > 0 or exists (
      select 1 from public.ex_order_shortfall_refunds where order_id = old.id) then
      raise exception 'SHORTFALL_ORDER_IMMUTABLE' using errcode = '23514';
    end if;
    return old;
  end if;
  if tg_op = 'INSERT' then
    if new.shortfall_refunded_iqd is distinct from 0::bigint then
      raise exception 'SHORTFALL_AGGREGATE_MISMATCH' using errcode = '23514';
    end if;
  else
    select coalesce(sum(amount_iqd), 0) into v_sum
      from public.ex_order_shortfall_refunds where order_id = old.id;
    if new.shortfall_refunded_iqd is distinct from v_sum then
      raise exception 'SHORTFALL_AGGREGATE_MISMATCH' using errcode = '23514';
    end if;
    if old.shortfall_refunded_iqd > 0 or v_sum > 0 then
      if new.status is distinct from old.status
        or new.user_id is distinct from old.user_id
        or new.order_code is distinct from old.order_code
        or new.amount is distinct from old.amount
        or new.total is distinct from old.total
        or new.fee is distinct from old.fee
        or new.from_method is distinct from old.from_method
        or new.to_method is distinct from old.to_method
        or new.phone is distinct from old.phone
        or new.receipt_url is distinct from old.receipt_url
        or new.receipt_hash is distinct from old.receipt_hash
        or new.transaction_reference is distinct from old.transaction_reference
        or new.payout_receipt_url is distinct from old.payout_receipt_url
        or new.balance_request_key is distinct from old.balance_request_key
        or new.balance_debit_journal_id is distinct from old.balance_debit_journal_id
        or new.balance_refund_case_id is distinct from old.balance_refund_case_id
        or new.balance_refunded_at is distinct from old.balance_refunded_at
        or new.reward_id is distinct from old.reward_id
        or new.reward_scope is distinct from old.reward_scope
        or new.reward_discount_iqd is distinct from old.reward_discount_iqd
        or new.reward_original_fee_iqd is distinct from old.reward_original_fee_iqd
        or new.reward_covered_amount_iqd is distinct from old.reward_covered_amount_iqd
        or new.reward_cap_iqd is distinct from old.reward_cap_iqd then
        raise exception 'SHORTFALL_ORDER_IMMUTABLE' using errcode = '23514';
      end if;
    end if;
  end if;
  if new.receipt_hash is not null and exists (
    select 1 from public.ex_orders o join public.ex_order_shortfall_refunds r on r.order_id = o.id
    where o.id <> new.id and o.receipt_hash = new.receipt_hash) then
    raise exception 'SHORTFALL_RECEIPT_NOT_REUSABLE' using errcode = '23505';
  end if;
  return new;
end $fn$;
revoke all on function public.ex_order_shortfall_guard() from public, anon, authenticated;
create trigger trg_ex_orders_shortfall_guard before insert or update or delete on public.ex_orders
  for each row execute function public.ex_order_shortfall_guard();

create function public.ex_shortfall_guard_full_refund() returns trigger
language plpgsql security definer set search_path = '' as $fn$
declare v_shortfall bigint;
begin
  select shortfall_refunded_iqd into v_shortfall from public.ex_orders where id = new.order_id for update;
  if v_shortfall > 0 or exists (
    select 1 from public.ex_order_shortfall_refunds where order_id = new.order_id) then
    raise exception 'ORDER_HAS_SHORTFALL_REFUND' using errcode = '23514';
  end if;
  return new;
end $fn$;
revoke all on function public.ex_shortfall_guard_full_refund() from public, anon, authenticated;
create trigger ex_refund_cases_guard_shortfall before insert on public.ex_refund_cases
  for each row execute function public.ex_shortfall_guard_full_refund();

-- Extend the existing balanced posting primitive by one explicitly labelled kind.
alter table public.ex_balance_journal drop constraint ex_balance_journal_kind_check;
alter table public.ex_balance_journal add constraint ex_balance_journal_kind_check
  check (kind in ('verified_refund','payout_hold','payout_cancel','payout_paid','order_debit','shortfall_refund'));

create or replace function public.ex_balance_post(
 p_user_id uuid,p_available_delta bigint,p_held_delta bigint,p_kind text,
 p_key text,p_order_id uuid,p_payout_id uuid,p_actor uuid,p_note text,p_evidence text default null
) returns uuid language plpgsql security definer set search_path='' as $fn$
declare v_balance public.ex_customer_balances%rowtype;
        v_journal uuid; v_available bigint; v_held bigint; v_clearing bigint;
begin
 if p_kind not in ('verified_refund','payout_hold','payout_cancel','payout_paid','order_debit','shortfall_refund')
    or p_user_id is null or p_available_delta is null or p_held_delta is null
    or (p_available_delta=0 and p_held_delta=0)
    or length(coalesce(p_key,''))<4 or p_actor is null then
   raise exception 'INVALID_LEDGER_POST' using errcode='22023';
 end if;
 perform set_config('ex_balance.authorized_post','yes',true);
 insert into public.ex_customer_balances(user_id) values(p_user_id) on conflict(user_id) do nothing;
 select * into strict v_balance from public.ex_customer_balances
   where user_id=p_user_id for update;
 v_available:=v_balance.available_iqd+p_available_delta;
 v_held:=v_balance.held_iqd+p_held_delta;
 if v_available<0 or v_held<0 then
   raise exception 'INSUFFICIENT_BALANCE' using errcode='23514';
 end if;
 v_clearing:=-(p_available_delta+p_held_delta);
 insert into public.ex_balance_journal(operation_key,kind,user_id,order_id,payout_id,actor_id,note,evidence_ref)
 values(p_key,p_kind,p_user_id,p_order_id,p_payout_id,p_actor,p_note,p_evidence)
 returning id into v_journal;
 update public.ex_customer_balances set available_iqd=v_available,held_iqd=v_held,
   revision=revision+1,updated_at=now() where user_id=p_user_id;
 if p_available_delta<>0 then
   insert into public.ex_balance_entries(journal_id,account,user_id,delta_iqd,balance_after_iqd)
     values(v_journal,'customer_available',p_user_id,p_available_delta,v_available);
 end if;
 if p_held_delta<>0 then
   insert into public.ex_balance_entries(journal_id,account,user_id,delta_iqd,balance_after_iqd)
     values(v_journal,'customer_held',p_user_id,p_held_delta,v_held);
 end if;
 if v_clearing<>0 then
   insert into public.ex_balance_entries(journal_id,account,user_id,delta_iqd)
     values(v_journal,'platform_clearing',null,v_clearing);
 end if;
 perform set_config('ex_balance.authorized_post','no',true);
 return v_journal;
end $fn$;
revoke all on function public.ex_balance_post(uuid,bigint,bigint,text,text,uuid,uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.ex_balance_post(uuid,bigint,bigint,text,text,uuid,uuid,uuid,text,text) to service_role;

-- Service-only: the server verifies the session and supplies its admin identity.
-- Numeric inputs are deliberate: bigint arguments silently round fractions before
-- the function can validate them. Every comparison precedes the bigint casts.
create function public.ex_admin_credit_shortfall(
  p_order_id uuid, p_admin_id uuid, p_amount_iqd numeric, p_request_key uuid,
  p_expected_refunded_iqd numeric, p_reason text, p_verification_reference text,
  p_confirmed_shortfall boolean
) returns public.ex_order_shortfall_refunds
language plpgsql security definer set search_path = '' as $fn$
declare
  v_order public.ex_orders%rowtype;
  v_admin public.ex_profiles%rowtype;
  v_case public.ex_order_shortfall_refunds%rowtype;
  v_sum numeric;
  v_journal uuid;
  v_after bigint;
begin
  select * into v_admin from public.ex_profiles where id = p_admin_id for share;
  if not found or v_admin.is_admin is distinct from true or v_admin.is_banned is distinct from false
    or not coalesce(v_admin.role = 'super_admin' or v_admin.staff_permissions is null
      or 'refunds' = any(v_admin.staff_permissions), false) then
    raise exception 'STAFF_PERMISSION_REQUIRED' using errcode = '42501';
  end if;
  if p_order_id is null or p_request_key is null
    or p_amount_iqd is null or p_amount_iqd < 1 or p_amount_iqd > 1000000000
    or p_amount_iqd <> trunc(p_amount_iqd)
    or p_expected_refunded_iqd is null or p_expected_refunded_iqd < 0
    or p_expected_refunded_iqd > 1000000000 or p_expected_refunded_iqd <> trunc(p_expected_refunded_iqd)
    or p_confirmed_shortfall is distinct from true
    or char_length(btrim(coalesce(p_reason,''))) not between 10 and 2000
    or char_length(btrim(coalesce(p_verification_reference,''))) not between 6 and 160 then
    raise exception 'INVALID_SHORTFALL_REQUEST' using errcode = '22023';
  end if;
  -- Serialize a global idempotency key even when a changed request names another order.
  perform pg_advisory_xact_lock(hashtextextended('ex-shortfall:' || p_request_key::text, 0));
  select * into v_case from public.ex_order_shortfall_refunds where request_key = p_request_key;
  if found then
    if v_case.order_id is distinct from p_order_id or v_case.admin_id is distinct from p_admin_id
      or v_case.amount_iqd is distinct from p_amount_iqd
      or v_case.expected_refunded_iqd is distinct from p_expected_refunded_iqd
      or v_case.reason is distinct from btrim(p_reason)
      or v_case.verification_reference is distinct from btrim(p_verification_reference) then
      raise exception 'SHORTFALL_REQUEST_KEY_CONFLICT' using errcode = '22023';
    end if;
    return v_case;
  end if;
  select * into v_order from public.ex_orders where id = p_order_id for update;
  if not found then raise exception 'ORDER_NOT_FOUND' using errcode = '22023'; end if;
  select coalesce(sum(amount_iqd),0) into v_sum from public.ex_order_shortfall_refunds where order_id = v_order.id;
  if v_sum <> v_order.shortfall_refunded_iqd then
    raise exception 'SHORTFALL_AGGREGATE_MISMATCH' using errcode = '23514';
  end if;
  if v_sum <> p_expected_refunded_iqd then
    raise exception 'SHORTFALL_STATE_CHANGED' using errcode = '22023';
  end if;
  if v_order.status is distinct from 'پەسەندکرا'
    or v_order.from_method = 'USDT' or v_order.to_method in ('USDT','AccountBalance')
    or v_order.total is null or v_order.total < 1 or v_order.total > 1000000000
    or v_order.total <> trunc(v_order.total)
    or v_order.balance_refund_case_id is not null or v_order.balance_refunded_at is not null
    or exists (select 1 from public.ex_refund_cases where order_id = v_order.id) then
    raise exception 'ORDER_NOT_ELIGIBLE_FOR_SHORTFALL' using errcode = '22023';
  end if;
  if v_sum + p_amount_iqd > v_order.total then
    raise exception 'SHORTFALL_EXCEEDS_REMAINING' using errcode = '22023';
  end if;
  if v_order.from_method = 'AccountBalance' then
    if not exists (
      select 1 from public.ex_balance_journal j join public.ex_balance_entries e on e.journal_id = j.id
      where j.id = v_order.balance_debit_journal_id and j.order_id = v_order.id
        and j.user_id = v_order.user_id and j.kind = 'order_debit'
        and e.account = 'customer_available' and e.user_id = v_order.user_id and e.delta_iqd = -v_order.amount) then
      raise exception 'BALANCE_DEBIT_PROOF_REQUIRED' using errcode = '22023';
    end if;
  elsif nullif(btrim(v_order.receipt_url),'') is null then
    raise exception 'RECEIVED_FUNDS_PROOF_REQUIRED' using errcode = '22023';
  end if;
  if v_order.receipt_hash is not null and exists (
    select 1 from public.ex_orders where receipt_hash = v_order.receipt_hash and id <> v_order.id) then
    raise exception 'RECEIPT_HAS_MULTIPLE_ORDERS' using errcode = '23505';
  end if;
  if exists (select 1 from public.ex_order_shortfall_refunds
    where order_id = v_order.id and verification_reference = btrim(p_verification_reference)) then
    raise exception 'SHORTFALL_EVIDENCE_ALREADY_USED' using errcode = '23505';
  end if;
  -- The existing posting routine locks the customer's wallet after the order lock.
  v_journal := public.ex_balance_post(v_order.user_id,p_amount_iqd::bigint,0,'shortfall_refund',
    'shortfall:' || p_request_key::text,v_order.id,null,p_admin_id,btrim(p_reason),btrim(p_verification_reference));
  select balance_after_iqd into strict v_after from public.ex_balance_entries
    where journal_id = v_journal and account = 'customer_available' and user_id = v_order.user_id;
  insert into public.ex_order_shortfall_refunds (
    request_key,order_id,order_code,user_id,customer_phone,admin_id,amount_iqd,expected_iqd,
    expected_refunded_iqd,refunded_before_iqd,refunded_after_iqd,balance_before_iqd,balance_after_iqd,
    journal_id,reason,verification_reference,confirmed_shortfall,order_snapshot)
  values (p_request_key,v_order.id,v_order.order_code,v_order.user_id,v_order.phone,p_admin_id,
    p_amount_iqd::bigint,v_order.total::bigint,p_expected_refunded_iqd::bigint,v_sum::bigint,
    (v_sum+p_amount_iqd)::bigint,v_after-p_amount_iqd::bigint,v_after,v_journal,
    btrim(p_reason),btrim(p_verification_reference),true,
    jsonb_build_object('status',v_order.status,'amount',v_order.amount,'total',v_order.total,'fee',v_order.fee,
      'from_method',v_order.from_method,'to_method',v_order.to_method,'receipt_url',v_order.receipt_url,
      'receipt_hash',v_order.receipt_hash,'payout_receipt_url',v_order.payout_receipt_url,
      'balance_debit_journal_id',v_order.balance_debit_journal_id,'reward_id',v_order.reward_id,
      'reward_scope',v_order.reward_scope,'reward_discount_iqd',v_order.reward_discount_iqd)) returning * into v_case;
  update public.ex_orders set shortfall_refunded_iqd = v_case.refunded_after_iqd where id = v_order.id;
  insert into public.ex_admin_audit_log(admin_id,action,target_user_id,detail)
    values(p_admin_id,'balance_credit_shortfall',v_order.user_id,to_jsonb(v_case)::text);
  insert into public.ex_notifications(user_id,order_id,type,title,message)
    values(v_order.user_id,v_order.id,'admin','گەڕاندنەوەی بڕی کەمەکە',
      'بڕی ' || v_case.amount_iqd || ' دینار لە مامەڵەی ' || v_order.order_code || ' بۆ باڵانسی هەژمارەکەت گەڕێندرایەوە.');
  return v_case;
end $fn$;
revoke all on function public.ex_admin_credit_shortfall(uuid,uuid,numeric,uuid,numeric,text,text,boolean)
  from public,anon,authenticated;
grant execute on function public.ex_admin_credit_shortfall(uuid,uuid,numeric,uuid,numeric,text,text,boolean) to service_role;

-- Preserve every existing reconciliation key and processing-hold calculation.
-- Add bidirectional shortfall/journal links plus the order aggregate check.
create or replace function public.ex_admin_balance_reconcile(p_admin_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $fn$
declare v_unbalanced bigint;v_balance_drift bigint;v_hold_drift bigint;
 v_unlinked_refunds bigint;v_liability numeric;v_clearing numeric;
 v_unlinked_shortfalls bigint;v_shortfall_amount_mismatches bigint;
begin
 if not exists(select 1 from public.ex_profiles where id=p_admin_id
   and is_admin=true and is_banned=false) then
    raise exception 'ADMIN_REQUIRED' using errcode='42501';
 end if;
 select count(*) into v_unbalanced from (
   select j.id from public.ex_balance_journal j
   left join public.ex_balance_entries e on e.journal_id=j.id
   group by j.id
   having count(e.id)<2 or coalesce(sum(e.delta_iqd),0)<>0
 ) drift;
 with actual as (
   select user_id,
    coalesce(sum(delta_iqd) filter(where account='customer_available'),0) as available,
    coalesce(sum(delta_iqd) filter(where account='customer_held'),0) as held
   from public.ex_balance_entries where user_id is not null group by user_id
 )
 select count(*) into v_balance_drift
 from public.ex_customer_balances b left join actual a using(user_id)
 where b.available_iqd<>coalesce(a.available,0)
    or b.held_iqd<>coalesce(a.held,0);
 with waiting as (
   select user_id,coalesce(sum(amount_iqd),0) as amt from public.ex_payout_requests
   where status in ('pending','processing') group by user_id
 )
 select count(*) into v_hold_drift
 from public.ex_customer_balances b left join waiting w using(user_id)
 where b.held_iqd<>coalesce(w.amt,0);
 select count(*) into v_unlinked_refunds
 from public.ex_refund_cases r
 join public.ex_orders o on o.id=r.order_id
 where o.balance_refund_case_id is distinct from r.id
    or o.balance_refunded_at is null
    or not exists(
      select 1 from public.ex_balance_entries e
       where e.journal_id=r.journal_id and e.account='customer_available'
         and e.user_id=r.user_id and e.delta_iqd=r.amount_iqd
    );
 select count(*) into v_unlinked_shortfalls from (
   select r.id from public.ex_order_shortfall_refunds r
   join public.ex_balance_journal j on j.id=r.journal_id
   where j.kind<>'shortfall_refund' or j.order_id is distinct from r.order_id
     or j.user_id is distinct from r.user_id or j.actor_id is distinct from r.admin_id
     or j.operation_key is distinct from 'shortfall:'||r.request_key::text
     or not exists(select 1 from public.ex_balance_entries e
       where e.journal_id=r.journal_id and e.account='customer_available'
         and e.user_id=r.user_id and e.delta_iqd=r.amount_iqd
         and e.balance_after_iqd=r.balance_after_iqd)
     or not exists(select 1 from public.ex_balance_entries e
       where e.journal_id=r.journal_id and e.account='platform_clearing'
         and e.delta_iqd=-r.amount_iqd)
   union all
   select j.id from public.ex_balance_journal j
   where j.kind='shortfall_refund' and not exists(
     select 1 from public.ex_order_shortfall_refunds r where r.journal_id=j.id)
 ) drift;
 with actual as (
   select order_id,sum(amount_iqd) amount_iqd from public.ex_order_shortfall_refunds group by order_id
 )
 select count(*) into v_shortfall_amount_mismatches
 from public.ex_orders o left join actual a on a.order_id=o.id
 where o.shortfall_refunded_iqd<>coalesce(a.amount_iqd,0)
   or (coalesce(a.amount_iqd,0)>0 and (
     a.amount_iqd>o.total or o.status is distinct from 'پەسەندکرا'
     or o.balance_refund_case_id is not null or o.balance_refunded_at is not null
     or exists(select 1 from public.ex_refund_cases r where r.order_id=o.id)));
 select coalesce(sum(available_iqd+held_iqd),0) into v_liability
   from public.ex_customer_balances;
 select coalesce(sum(delta_iqd),0) into v_clearing
   from public.ex_balance_entries where account='platform_clearing';
 return jsonb_build_object(
   'unbalanced_journals',v_unbalanced,'balance_mismatches',v_balance_drift,
   'held_payout_mismatches',v_hold_drift,'unlinked_refunds',v_unlinked_refunds,
   'unlinked_shortfalls',v_unlinked_shortfalls,'shortfall_amount_mismatches',v_shortfall_amount_mismatches,
   'customer_liability_iqd',v_liability,'platform_clearing_iqd',v_clearing,
   'clearing_mismatch',v_liability+v_clearing<>0,
   'checked_at',now()
 );
end $fn$;
revoke all on function public.ex_admin_balance_reconcile(uuid) from public,anon,authenticated;
grant execute on function public.ex_admin_balance_reconcile(uuid) to service_role;
notify pgrst, 'reload schema';
