-- Mandatory whole-thousand IQD payouts, with the remainder returned atomically.
-- No historical order or customer balance is changed by this migration.
set local lock_timeout = '5s';
set local statement_timeout = '60s';

create table public.ex_order_payout_settlements (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.ex_orders(id) on delete restrict,
  request_key uuid not null unique,
  order_code text not null,
  user_id uuid not null references public.ex_profiles(id) on delete restrict,
  admin_id uuid not null references public.ex_profiles(id) on delete restrict,
  policy text not null default 'iqd_1000_v1' check (policy = 'iqd_1000_v1'),
  expected_updated_at timestamptz not null,
  expected_iqd bigint not null check (expected_iqd between 0 and 1000000000),
  payout_iqd bigint not null check (payout_iqd between 0 and 1000000000 and payout_iqd % 1000 = 0),
  rounding_iqd bigint not null check (rounding_iqd between 0 and 999),
  confirmed_received boolean not null check (confirmed_received),
  confirmed_paid boolean not null,
  requested_payout_receipt_url text,
  requested_admin_note text,
  payout_receipt_url text,
  admin_note text,
  funding_kind text not null check (funding_kind in ('account_balance','external_receipt')),
  funding_reference text not null,
  order_snapshot jsonb not null check (jsonb_typeof(order_snapshot) = 'object'),
  created_at timestamptz not null default now(),
  constraint ex_order_payout_split_matches check (
    expected_iqd = payout_iqd + rounding_iqd
    and confirmed_paid = (payout_iqd > 0)
    and (payout_iqd > 0 or payout_receipt_url is null)),
  constraint ex_order_payout_note_length check (
    requested_admin_note is null or char_length(requested_admin_note) <= 500)
);
create index ex_order_payout_settlements_user_created_idx
  on public.ex_order_payout_settlements(user_id,created_at desc);
create index ex_order_payout_settlements_admin_idx on public.ex_order_payout_settlements(admin_id);
alter table public.ex_order_payout_settlements enable row level security;
create policy ex_order_payout_settlements_read on public.ex_order_payout_settlements
  for select to authenticated using (user_id = (select auth.uid()) or (select public.ex_staff_has('view')));
revoke all on public.ex_order_payout_settlements from public,anon,authenticated,service_role;
grant select on public.ex_order_payout_settlements to authenticated,service_role;
create trigger ex_order_payout_settlements_immutable before update or delete on public.ex_order_payout_settlements
  for each row execute function public.ex_balance_deny_journal_mutation();

alter table public.ex_orders
  add column payout_iqd bigint,
  add column payout_rounding_iqd bigint,
  add column payout_settlement_id uuid unique references public.ex_order_payout_settlements(id) on delete restrict,
  add constraint ex_orders_payout_snapshot_complete check (
    (payout_settlement_id is null and payout_iqd is null and payout_rounding_iqd is null)
    or (payout_settlement_id is not null and payout_iqd is not null and payout_rounding_iqd is not null
      and payout_iqd between 0 and 1000000000 and payout_iqd % 1000 = 0
      and payout_rounding_iqd between 0 and 999));
comment on column public.ex_orders.total is
  'Original net recipient entitlement after fees/rewards; payout_iqd and the rounding wallet credit split this amount without changing it.';
comment on column public.ex_orders.payout_iqd is
  'Immutable external IQD payout confirmed at settlement; NULL denotes an order without this policy settlement.';

alter table public.ex_order_shortfall_refunds
  add column refund_source text not null default 'manual_shortfall'
    check (refund_source in ('manual_shortfall','payout_rounding')),
  add column payout_settlement_id uuid references public.ex_order_payout_settlements(id) on delete restrict,
  add constraint ex_shortfall_rounding_source_matches check (
    (refund_source = 'manual_shortfall' and payout_settlement_id is null)
    or (refund_source = 'payout_rounding' and payout_settlement_id is not null
      and amount_iqd between 1 and 999 and refunded_before_iqd = 0
      and refunded_after_iqd = amount_iqd and expected_iqd % 1000 = amount_iqd));
create unique index ex_shortfall_one_rounding_per_order on public.ex_order_shortfall_refunds(order_id)
  where refund_source = 'payout_rounding';
create unique index ex_shortfall_one_rounding_per_settlement on public.ex_order_shortfall_refunds(payout_settlement_id)
  where payout_settlement_id is not null;

-- A later receipt is an append-only fact, never an edit of the approval snapshot.
create table public.ex_order_settlement_receipts (
  id uuid primary key default gen_random_uuid(),
  settlement_id uuid not null unique references public.ex_order_payout_settlements(id) on delete restrict,
  order_id uuid not null unique references public.ex_orders(id) on delete restrict,
  user_id uuid not null references public.ex_profiles(id) on delete restrict,
  admin_id uuid not null references public.ex_profiles(id) on delete restrict,
  payout_receipt_url text not null check (
    char_length(payout_receipt_url) between 10 and 2000 and payout_receipt_url = btrim(payout_receipt_url)),
  created_at timestamptz not null default now()
);
create index ex_order_settlement_receipts_user_idx on public.ex_order_settlement_receipts(user_id);
create index ex_order_settlement_receipts_admin_idx on public.ex_order_settlement_receipts(admin_id);
alter table public.ex_order_settlement_receipts enable row level security;
create policy ex_order_settlement_receipts_read on public.ex_order_settlement_receipts
  for select to authenticated using (user_id = (select auth.uid()) or (select public.ex_staff_has('view')));
revoke all on public.ex_order_settlement_receipts from public,anon,authenticated,service_role;
grant select on public.ex_order_settlement_receipts to authenticated,service_role;
create trigger ex_order_settlement_receipts_immutable before update or delete on public.ex_order_settlement_receipts
  for each row execute function public.ex_balance_deny_journal_mutation();

create function public.ex_settlement_valid_receipt(p_user_id uuid,p_url text)
returns boolean language sql immutable set search_path = '' as $fn$
  select coalesce(p_user_id is not null and p_url = btrim(p_url)
    and char_length(p_url) between 10 and 2000
    and starts_with(p_url,'https://pycxuugoblkslvwebxuu.supabase.co/storage/v1/object/public/receipts/' || p_user_id::text || '/')
    and p_url !~ '[[:space:][:cntrl:]?#]'
    and lower(p_url) !~ '(%2e|%2f|%5c|/\.\.?/)' and position(chr(92) in p_url) = 0,false);
$fn$;
revoke all on function public.ex_settlement_valid_receipt(uuid,text) from public,anon,authenticated,service_role;

create function public.ex_settlement_receipt_append_allowed(p_order_id uuid,p_old_url text,p_new_url text)
returns boolean language sql stable security definer set search_path = '' as $fn$
  select nullif(btrim(p_old_url),'') is null and exists (
    select 1 from public.ex_order_settlement_receipts r
    join public.ex_order_payout_settlements s on s.id = r.settlement_id
    where r.order_id = p_order_id and s.order_id = p_order_id and s.payout_iqd > 0
      and s.user_id = r.user_id and s.payout_receipt_url is null
      and r.payout_receipt_url = p_new_url
      and current_setting('ex_settlement.receipt_id',true) = r.id::text
      and not exists (select 1 from public.ex_order_shortfall_refunds f
        where f.order_id = p_order_id and f.refund_source = 'manual_shortfall'));
$fn$;
revoke all on function public.ex_settlement_receipt_append_allowed(uuid,text,text) from public,anon,authenticated,service_role;

-- Enforce the policy at the table boundary, including authenticated status UPDATE.
create function public.ex_order_settlement_guard() returns trigger
language plpgsql security definer set search_path = '' as $fn$
declare s public.ex_order_payout_settlements%rowtype; protected_field text;
begin
  if tg_op = 'DELETE' then
    if old.payout_settlement_id is not null then
      raise exception 'SETTLEMENT_ORDER_IMMUTABLE' using errcode = '23514';
    end if;
    return old;
  end if;
  if tg_op = 'INSERT' then
    if new.payout_settlement_id is not null or new.payout_iqd is not null or new.payout_rounding_iqd is not null
      or (new.status = 'پەسەندکرا' and coalesce(new.to_method,'') not in ('USDT','AccountBalance')) then
      raise exception 'ATOMIC_IQD_SETTLEMENT_REQUIRED' using errcode = '42501';
    end if;
    return new;
  end if;
  if old.payout_settlement_id is not null then
    foreach protected_field in array array[
      'status','user_id','order_code','amount','total','fee','from_method','to_method','phone','sender_phone','sender_name',
      'receipt_url','receipt_hash','transaction_reference','balance_request_key','balance_debit_journal_id',
      'balance_refund_case_id','balance_refunded_at','reward_id','reward_scope','reward_discount_iqd',
      'reward_original_fee_iqd','reward_covered_amount_iqd','reward_cap_iqd','handled_by','decided_at',
      'payout_iqd','payout_rounding_iqd','payout_settlement_id'] loop
      if (to_jsonb(new) -> protected_field) is distinct from (to_jsonb(old) -> protected_field) then
        raise exception 'SETTLEMENT_ORDER_IMMUTABLE' using errcode = '23514';
      end if;
    end loop;
    if new.payout_receipt_url is distinct from old.payout_receipt_url
      and not public.ex_settlement_receipt_append_allowed(old.id,old.payout_receipt_url,new.payout_receipt_url) then
      raise exception 'SETTLEMENT_RECEIPT_LOCKED' using errcode = '23514';
    end if;
  elsif new.payout_settlement_id is not null then
    select * into s from public.ex_order_payout_settlements where id = new.payout_settlement_id;
    if not found or current_setting('ex_settlement.approval_id',true) is distinct from s.id::text
      or s.order_id is distinct from new.id or s.user_id is distinct from new.user_id
      or new.status is distinct from 'پەسەندکرا' or new.handled_by is distinct from s.admin_id
      or new.payout_iqd is distinct from s.payout_iqd or new.payout_rounding_iqd is distinct from s.rounding_iqd
      or new.total is distinct from s.expected_iqd
      or new.payout_receipt_url is distinct from s.payout_receipt_url then
      raise exception 'ATOMIC_IQD_SETTLEMENT_REQUIRED' using errcode = '42501';
    end if;
    foreach protected_field in array array[
      'user_id','order_code','amount','total','fee','from_method','to_method','phone','sender_phone','sender_name',
      'receipt_url','receipt_hash','transaction_reference','balance_request_key','balance_debit_journal_id',
      'balance_refund_case_id','balance_refunded_at','reward_id','reward_scope','reward_discount_iqd',
      'reward_original_fee_iqd','reward_covered_amount_iqd','reward_cap_iqd'] loop
      if (to_jsonb(new) -> protected_field) is distinct from (s.order_snapshot -> protected_field) then
        raise exception 'SETTLEMENT_ORDER_IMMUTABLE' using errcode = '23514';
      end if;
    end loop;
  elsif new.payout_iqd is not null or new.payout_rounding_iqd is not null then
    raise exception 'ATOMIC_IQD_SETTLEMENT_REQUIRED' using errcode = '42501';
  end if;
  if new.status = 'پەسەندکرا' and coalesce(new.to_method,'') not in ('USDT','AccountBalance')
    and (old.status is distinct from new.status or old.to_method in ('USDT','AccountBalance') or old.to_method is null)
    and new.payout_settlement_id is null then
    raise exception 'ATOMIC_IQD_SETTLEMENT_REQUIRED' using errcode = '42501';
  end if;
  -- Historical approvals cannot be reopened to acquire a new automatic credit.
  if old.status = 'پەسەندکرا' and coalesce(old.to_method,'') not in ('USDT','AccountBalance')
    and (new.status is distinct from old.status or new.to_method is distinct from old.to_method) then
    raise exception 'SETTLEMENT_ORDER_IMMUTABLE' using errcode = '23514';
  end if;
  return new;
end $fn$;
revoke all on function public.ex_order_settlement_guard() from public,anon,authenticated,service_role;
create trigger trg_ex_orders_settlement_guard before insert or update or delete on public.ex_orders
  for each row execute function public.ex_order_settlement_guard();

create function public.ex_admin_approve_order_settlement(
  p_order_id uuid,p_admin_id uuid,p_request_key uuid,p_expected_updated_at timestamptz,
  p_expected_total numeric,p_confirmed_payout_iqd numeric,p_confirmed_received boolean,
  p_confirmed_paid boolean,p_payout_receipt_url text,p_admin_note text
) returns jsonb language plpgsql security definer set search_path = '' as $fn$
declare
  o public.ex_orders%rowtype; a public.ex_profiles%rowtype;
  s public.ex_order_payout_settlements%rowtype; r public.ex_order_shortfall_refunds%rowtype;
  v_requested_receipt text := nullif(btrim(p_payout_receipt_url),'');
  v_requested_note text := nullif(btrim(p_admin_note),'');
  v_receipt text; v_note text; v_payout bigint; v_rounding bigint;
  v_funding_kind text; v_funding_reference text; v_journal uuid; v_after bigint;
begin
  select * into a from public.ex_profiles where id = p_admin_id for share;
  if not found or a.is_admin is distinct from true or a.is_banned is distinct from false
    or not coalesce(a.role = 'super_admin' or a.staff_permissions is null or 'approve_orders' = any(a.staff_permissions),false) then
    raise exception 'STAFF_PERMISSION_REQUIRED' using errcode = '42501';
  end if;
  if p_order_id is null or p_request_key is null or p_expected_updated_at is null or not isfinite(p_expected_updated_at)
    or p_expected_total is null or p_expected_total < 0 or p_expected_total > 1000000000
    or p_expected_total <> trunc(p_expected_total)
    or p_confirmed_payout_iqd is null or p_confirmed_payout_iqd < 0 or p_confirmed_payout_iqd > 1000000000
    or p_confirmed_payout_iqd <> trunc(p_confirmed_payout_iqd) or mod(p_confirmed_payout_iqd,1000) <> 0
    or p_confirmed_received is distinct from true or p_confirmed_paid is null
    or char_length(coalesce(v_requested_note,'')) > 500
    or char_length(coalesce(v_requested_receipt,'')) > 2000 then
    raise exception 'INVALID_SETTLEMENT_REQUEST' using errcode = '22023';
  end if;
  -- Use the same namespace as manual shortfall requests because their case keys are shared.
  perform pg_advisory_xact_lock(hashtextextended('ex-shortfall:' || p_request_key::text,0));
  select * into s from public.ex_order_payout_settlements where request_key = p_request_key;
  if found then
    if s.order_id is distinct from p_order_id or s.admin_id is distinct from p_admin_id
      or s.expected_updated_at is distinct from p_expected_updated_at or s.expected_iqd is distinct from p_expected_total
      or s.payout_iqd is distinct from p_confirmed_payout_iqd or s.confirmed_received is distinct from p_confirmed_received
      or s.confirmed_paid is distinct from p_confirmed_paid
      or s.requested_payout_receipt_url is distinct from v_requested_receipt or s.requested_admin_note is distinct from v_requested_note then
      raise exception 'SETTLEMENT_REQUEST_KEY_CONFLICT' using errcode = '22023';
    end if;
    select * into o from public.ex_orders where id = s.order_id;
    select * into r from public.ex_order_shortfall_refunds where payout_settlement_id = s.id;
    return jsonb_build_object('order',to_jsonb(o),'settlement',to_jsonb(s),'refund',case when r.id is null then null else to_jsonb(r) end);
  end if;
  if exists (select 1 from public.ex_order_shortfall_refunds where request_key = p_request_key) then
    raise exception 'SETTLEMENT_REQUEST_KEY_CONFLICT' using errcode = '22023';
  end if;
  select * into o from public.ex_orders where id = p_order_id for update;
  if not found then raise exception 'ORDER_NOT_FOUND' using errcode = '22023'; end if;
  if o.status not in ('چاوەڕوانە','ڕاستکراوەتەوە') or o.status is null
    or o.payout_settlement_id is not null or o.balance_refund_case_id is not null or o.balance_refunded_at is not null
    or o.shortfall_refunded_iqd <> 0
    or exists (select 1 from public.ex_order_payout_settlements where order_id = o.id)
    or exists (select 1 from public.ex_refund_cases where order_id = o.id)
    or exists (select 1 from public.ex_order_shortfall_refunds where order_id = o.id) then
    raise exception 'ORDER_ALREADY_DECIDED' using errcode = '22023';
  end if;
  if o.to_method is null or o.to_method in ('USDT','AccountBalance') or o.from_method is null
    or o.amount is null or o.amount <= 0 or o.amount > 1000000000
    or (o.from_method <> 'USDT' and o.amount <> trunc(o.amount))
    or o.total is null or o.total < 0 or o.total > 1000000000 or o.total <> trunc(o.total) then
    raise exception 'ORDER_NOT_ELIGIBLE_FOR_SETTLEMENT' using errcode = '22023';
  end if;
  if o.updated_at is distinct from p_expected_updated_at or o.total is distinct from p_expected_total then
    raise exception 'ORDER_SETTLEMENT_STALE' using errcode = '22023';
  end if;
  v_payout := (trunc(o.total / 1000) * 1000)::bigint;
  v_rounding := o.total::bigint - v_payout;
  if p_confirmed_payout_iqd <> v_payout or p_confirmed_paid is distinct from (v_payout > 0) then
    raise exception 'PAYOUT_AMOUNT_MISMATCH' using errcode = '22023';
  end if;
  if o.from_method = 'AccountBalance' then
    if not exists (select 1 from public.ex_balance_journal j join public.ex_balance_entries e on e.journal_id = j.id
      where j.id = o.balance_debit_journal_id and j.order_id = o.id and j.user_id = o.user_id and j.kind = 'order_debit'
        and e.account = 'customer_available' and e.user_id = o.user_id and e.delta_iqd = -o.amount) then
      raise exception 'BALANCE_DEBIT_PROOF_REQUIRED' using errcode = '22023';
    end if;
    v_funding_kind := 'account_balance'; v_funding_reference := o.balance_debit_journal_id::text;
  else
    if nullif(btrim(o.receipt_url),'') is null then
      raise exception 'RECEIVED_FUNDS_PROOF_REQUIRED' using errcode = '22023';
    end if;
    v_funding_kind := 'external_receipt'; v_funding_reference := o.receipt_url;
  end if;
  if o.receipt_hash is not null and exists (select 1 from public.ex_orders where receipt_hash = o.receipt_hash and id <> o.id) then
    raise exception 'RECEIPT_HAS_MULTIPLE_ORDERS' using errcode = '23505';
  end if;
  v_receipt := coalesce(v_requested_receipt,nullif(btrim(o.payout_receipt_url),''));
  v_note := coalesce(v_requested_note,o.admin_note);
  if v_receipt is not null and (v_payout = 0 or not public.ex_settlement_valid_receipt(o.user_id,v_receipt)) then
    raise exception 'INVALID_PAYOUT_RECEIPT' using errcode = '22023';
  end if;
  insert into public.ex_order_payout_settlements(order_id,request_key,order_code,user_id,admin_id,
    expected_updated_at,expected_iqd,payout_iqd,rounding_iqd,confirmed_received,confirmed_paid,
    requested_payout_receipt_url,requested_admin_note,payout_receipt_url,admin_note,funding_kind,funding_reference,order_snapshot)
  values(o.id,p_request_key,o.order_code,o.user_id,p_admin_id,p_expected_updated_at,o.total::bigint,v_payout,v_rounding,
    true,p_confirmed_paid,v_requested_receipt,v_requested_note,v_receipt,v_note,v_funding_kind,v_funding_reference,to_jsonb(o))
  returning * into s;
  perform set_config('ex_settlement.approval_id',s.id::text,true);
  update public.ex_orders set status = 'پەسەندکرا',decided_at = now(),handled_by = p_admin_id,
    payout_iqd = v_payout,payout_rounding_iqd = v_rounding,payout_settlement_id = s.id,
    payout_receipt_url = v_receipt,admin_note = v_note where id = o.id returning * into o;
  perform set_config('ex_settlement.approval_id','',true);
  if v_rounding > 0 then
    v_journal := public.ex_balance_post(o.user_id,v_rounding,0,'shortfall_refund','shortfall:' || p_request_key::text,
      o.id,null,p_admin_id,'گەڕاندنەوەی پاشماوەی ناردن بە هەزار دینار','rounding:' || s.id::text);
    select balance_after_iqd into strict v_after from public.ex_balance_entries
      where journal_id = v_journal and account = 'customer_available' and user_id = o.user_id;
    insert into public.ex_order_shortfall_refunds(request_key,order_id,order_code,user_id,customer_phone,admin_id,
      amount_iqd,expected_iqd,expected_refunded_iqd,refunded_before_iqd,refunded_after_iqd,balance_before_iqd,balance_after_iqd,
      journal_id,reason,verification_reference,confirmed_shortfall,order_snapshot,refund_source,payout_settlement_id)
    values(p_request_key,o.id,o.order_code,o.user_id,o.phone,p_admin_id,v_rounding,s.expected_iqd,0,0,v_rounding,
      v_after-v_rounding,v_after,v_journal,'گەڕاندنەوەی پاشماوەی ناردن بە هەزار دینار','rounding:' || s.id::text,
      true,to_jsonb(o),'payout_rounding',s.id) returning * into r;
    update public.ex_orders set shortfall_refunded_iqd = v_rounding where id = o.id returning * into o;
  end if;
  insert into public.ex_admin_audit_log(admin_id,action,target_user_id,detail)
    values(p_admin_id,'approve_order_settlement',o.user_id,jsonb_build_object(
      'settlement',to_jsonb(s),'refund',case when r.id is null then null else to_jsonb(r) end)::text);
  return jsonb_build_object('order',to_jsonb(o),'settlement',to_jsonb(s),'refund',case when r.id is null then null else to_jsonb(r) end);
end $fn$;
revoke all on function public.ex_admin_approve_order_settlement(uuid,uuid,uuid,timestamptz,numeric,numeric,boolean,boolean,text,text)
  from public,anon,authenticated;
grant execute on function public.ex_admin_approve_order_settlement(uuid,uuid,uuid,timestamptz,numeric,numeric,boolean,boolean,text,text) to service_role;

create function public.ex_admin_attach_settlement_receipt(p_order_id uuid,p_admin_id uuid,p_payout_receipt_url text)
returns jsonb language plpgsql security definer set search_path = '' as $fn$
declare o public.ex_orders%rowtype; a public.ex_profiles%rowtype;
  s public.ex_order_payout_settlements%rowtype; r public.ex_order_settlement_receipts%rowtype;
  v_url text := nullif(btrim(p_payout_receipt_url),'');
begin
  select * into a from public.ex_profiles where id = p_admin_id for share;
  if not found or a.is_admin is distinct from true or a.is_banned is distinct from false
    or not coalesce(a.role = 'super_admin' or a.staff_permissions is null or 'approve_orders' = any(a.staff_permissions),false) then
    raise exception 'STAFF_PERMISSION_REQUIRED' using errcode = '42501';
  end if;
  select * into o from public.ex_orders where id = p_order_id for update;
  if not found then raise exception 'ORDER_NOT_FOUND' using errcode = '22023'; end if;
  if not public.ex_settlement_valid_receipt(o.user_id,v_url) then
    raise exception 'INVALID_PAYOUT_RECEIPT' using errcode = '22023';
  end if;
  select * into r from public.ex_order_settlement_receipts where order_id = o.id;
  if found then
    if r.payout_receipt_url is distinct from v_url or r.admin_id is distinct from p_admin_id then
      raise exception 'SETTLEMENT_RECEIPT_CONFLICT' using errcode = '22023';
    end if;
    return jsonb_build_object('order',to_jsonb(o),'receipt',to_jsonb(r));
  end if;
  select * into s from public.ex_order_payout_settlements where id = o.payout_settlement_id;
  if not found or o.status is distinct from 'پەسەندکرا' or s.payout_iqd <= 0
    or s.payout_receipt_url is not null or nullif(btrim(o.payout_receipt_url),'') is not null
    or exists (select 1 from public.ex_order_shortfall_refunds where order_id = o.id and refund_source = 'manual_shortfall') then
    raise exception 'SETTLEMENT_RECEIPT_LOCKED' using errcode = '22023';
  end if;
  insert into public.ex_order_settlement_receipts(settlement_id,order_id,user_id,admin_id,payout_receipt_url)
    values(s.id,o.id,o.user_id,p_admin_id,v_url) returning * into r;
  perform set_config('ex_settlement.receipt_id',r.id::text,true);
  update public.ex_orders set payout_receipt_url = v_url where id = o.id returning * into o;
  perform set_config('ex_settlement.receipt_id','',true);
  insert into public.ex_admin_audit_log(admin_id,action,target_user_id,detail)
    values(p_admin_id,'attach_settlement_receipt',o.user_id,to_jsonb(r)::text);
  return jsonb_build_object('order',to_jsonb(o),'receipt',to_jsonb(r));
end $fn$;
revoke all on function public.ex_admin_attach_settlement_receipt(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.ex_admin_attach_settlement_receipt(uuid,uuid,text) to service_role;

-- Full-refund case INSERT is also an existing service-role surface. Protect a
-- zero-remainder settlement even though it deliberately has no shortfall row.
create or replace function public.ex_shortfall_guard_full_refund() returns trigger
language plpgsql security definer set search_path = '' as $fn$
declare v_shortfall bigint; v_settlement uuid;
begin
  select shortfall_refunded_iqd,payout_settlement_id into v_shortfall,v_settlement
    from public.ex_orders where id=new.order_id for update;
  if v_settlement is not null then
    raise exception 'ORDER_HAS_PAYOUT_SETTLEMENT' using errcode='23514';
  end if;
  if v_shortfall > 0 or exists(select 1 from public.ex_order_shortfall_refunds where order_id=new.order_id) then
    raise exception 'ORDER_HAS_SHORTFALL_REFUND' using errcode='23514';
  end if;
  return new;
end $fn$;
revoke all on function public.ex_shortfall_guard_full_refund() from public,anon,authenticated,service_role;

-- Deferred checks allow status, case and aggregate updates within one transaction,
-- but require the complete, balanced settlement before that transaction commits.
create function public.ex_payout_settlement_consistent(p_settlement_id uuid)
returns boolean language sql stable security definer set search_path = '' as $fn$
  select coalesce((select
    o.payout_settlement_id = s.id and o.user_id = s.user_id and o.order_code = s.order_code
    and o.handled_by = s.admin_id and o.status = 'پەسەندکرا'
    and o.payout_iqd = s.payout_iqd and o.payout_rounding_iqd = s.rounding_iqd and o.total = s.expected_iqd
    and o.to_method not in ('USDT','AccountBalance') and o.balance_refund_case_id is null and o.balance_refunded_at is null
    and not exists (select 1 from public.ex_refund_cases f where f.order_id = o.id)
    and o.shortfall_refunded_iqd = (select coalesce(sum(f.amount_iqd),0) from public.ex_order_shortfall_refunds f where f.order_id = o.id)
    and o.shortfall_refunded_iqd between s.rounding_iqd and s.expected_iqd
    and not exists (select 1 from unnest(array[
      'user_id','order_code','amount','total','fee','from_method','to_method','phone','sender_phone','sender_name',
      'receipt_url','receipt_hash','transaction_reference','balance_request_key','balance_debit_journal_id',
      'balance_refund_case_id','balance_refunded_at','reward_id','reward_scope','reward_discount_iqd',
      'reward_original_fee_iqd','reward_covered_amount_iqd','reward_cap_iqd']) as f(name)
      where (to_jsonb(o) -> f.name) is distinct from (s.order_snapshot -> f.name))
    and o.payout_receipt_url is not distinct from coalesce(att.payout_receipt_url,s.payout_receipt_url)
    and (att.id is null or (att.order_id = s.order_id and att.user_id = s.user_id
      and s.payout_iqd > 0 and s.payout_receipt_url is null
      and public.ex_settlement_valid_receipt(s.user_id,att.payout_receipt_url)))
    and ((s.rounding_iqd = 0 and r.id is null) or (s.rounding_iqd > 0
      and r.id is not null and r.refund_source = 'payout_rounding' and r.order_id = s.order_id
      and r.user_id = s.user_id and r.admin_id = s.admin_id and r.request_key = s.request_key
      and r.amount_iqd = s.rounding_iqd and r.expected_iqd = s.expected_iqd
      and r.refunded_before_iqd = 0 and r.refunded_after_iqd = s.rounding_iqd
      and j.kind = 'shortfall_refund' and j.operation_key = 'shortfall:' || s.request_key::text
      and j.user_id = s.user_id and j.order_id = s.order_id and j.actor_id = s.admin_id
      and exists (select 1 from public.ex_balance_entries e where e.journal_id = r.journal_id
        and e.account = 'customer_available' and e.user_id = s.user_id and e.delta_iqd = s.rounding_iqd
        and e.balance_after_iqd = r.balance_after_iqd)
      and exists (select 1 from public.ex_balance_entries e where e.journal_id = r.journal_id
        and e.account = 'platform_clearing' and e.delta_iqd = -s.rounding_iqd)
      and (select count(*) = 2 and sum(e.delta_iqd) = 0 from public.ex_balance_entries e where e.journal_id = r.journal_id)))
  from public.ex_order_payout_settlements s
  join public.ex_orders o on o.id = s.order_id
  left join public.ex_order_shortfall_refunds r on r.payout_settlement_id = s.id
  left join public.ex_balance_journal j on j.id = r.journal_id
  left join public.ex_order_settlement_receipts att on att.settlement_id = s.id
  where s.id = p_settlement_id),false);
$fn$;
revoke all on function public.ex_payout_settlement_consistent(uuid) from public,anon,authenticated,service_role;

create function public.ex_check_payout_settlement() returns trigger
language plpgsql security definer set search_path = '' as $fn$
declare v_settlement uuid;
begin
  if tg_table_name = 'ex_order_payout_settlements' then v_settlement := new.id;
  elsif tg_table_name = 'ex_order_settlement_receipts' then v_settlement := new.settlement_id;
  else v_settlement := new.payout_settlement_id; end if;
  if v_settlement is not null and not public.ex_payout_settlement_consistent(v_settlement) then
    raise exception 'SETTLEMENT_INCOMPLETE' using errcode = '23514';
  end if;
  return null;
end $fn$;
revoke all on function public.ex_check_payout_settlement() from public,anon,authenticated,service_role;
create constraint trigger ex_payout_settlement_complete after insert on public.ex_order_payout_settlements
  deferrable initially deferred for each row execute function public.ex_check_payout_settlement();
create constraint trigger ex_payout_rounding_complete after insert on public.ex_order_shortfall_refunds
  deferrable initially deferred for each row execute function public.ex_check_payout_settlement();
create constraint trigger ex_payout_receipt_complete after insert on public.ex_order_settlement_receipts
  deferrable initially deferred for each row execute function public.ex_check_payout_settlement();

create or replace function public.ex_notify_order_status() returns trigger
language plpgsql security definer set search_path = '' as $fn$
declare order_tag text := chr(8296) || coalesce(new.order_code,'P-' || lpad(new.order_number::text,6,'0')) || chr(8297);
  v_message text;
begin
  if new.status is distinct from old.status then
    if new.status = 'پەسەندکرا' and new.payout_settlement_id is not null then
      v_message := 'داواکاری ' || order_tag || ' پەسەندکرا. ' ||
        case when new.payout_iqd > 0 then 'بڕی ' || new.payout_iqd || ' دینار بۆ وەرگر نێردرا. '
          else 'ناردنی دەرەکی نییە. ' end ||
        case when new.payout_rounding_iqd > 0 then 'پاشماوەی ' || new.payout_rounding_iqd || ' دینار بۆ باڵانسی هەژمارەکەت گەڕێندرایەوە.'
          else 'پاشماوەی گەڕاندنەوە نییە.' end;
    elsif new.status = 'پەسەندکرا' then
      v_message := 'داواکاری ' || order_tag || ' بە سەرکەوتوویی پەسەندکرا و بڕەکە دەگاتە دەستت.';
    elsif new.status = 'ڕەتکرا' then
      v_message := 'داواکاری ' || order_tag || ' ڕەتکرایەوە.';
    else v_message := 'داواکاری ' || order_tag || ' - ' || new.status;
    end if;
    if nullif(new.admin_note,'') is not null then
      v_message := v_message || case when new.status = 'ڕەتکرا' then ' هۆکار: ' else ' — ' end || new.admin_note;
    end if;
    insert into public.ex_notifications(user_id,order_id,type,title,message) values(new.user_id,new.id,
      case when new.status = 'پەسەندکرا' then 'order_approved' when new.status = 'ڕەتکرا' then 'order_rejected' else 'order_status' end,
      case when new.status = 'پەسەندکرا' then 'داواکارییەکەت پەسەندکرا 🎉'
        when new.status = 'ڕەتکرا' then 'داواکارییەکەت ڕەتکرایەوە ❌' else 'دۆخی داواکارییەکەت گۆڕا' end,v_message);
  end if;
  return new;
end $fn$;
revoke all on function public.ex_notify_order_status() from public,anon,authenticated,service_role;

-- Preserve the existing shortfall controls, allowing only the durable first-receipt append.
CREATE OR REPLACE FUNCTION public.ex_order_shortfall_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
        or (new.payout_receipt_url is distinct from old.payout_receipt_url
          and not public.ex_settlement_receipt_append_allowed(old.id,old.payout_receipt_url,new.payout_receipt_url))
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
end $function$
;

-- Automatic approval request keys cannot be replayed through the manual-refund entry point.
CREATE OR REPLACE FUNCTION public.ex_admin_credit_shortfall(p_order_id uuid, p_admin_id uuid, p_amount_iqd numeric, p_request_key uuid, p_expected_refunded_iqd numeric, p_reason text, p_verification_reference text, p_confirmed_shortfall boolean)
 RETURNS public.ex_order_shortfall_refunds
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
    if v_case.refund_source is distinct from 'manual_shortfall'
      or v_case.order_id is distinct from p_order_id or v_case.admin_id is distinct from p_admin_id
      or v_case.amount_iqd is distinct from p_amount_iqd
      or v_case.expected_refunded_iqd is distinct from p_expected_refunded_iqd
      or v_case.reason is distinct from btrim(p_reason)
      or v_case.verification_reference is distinct from btrim(p_verification_reference) then
      raise exception 'SHORTFALL_REQUEST_KEY_CONFLICT' using errcode = '22023';
    end if;
    return v_case;
  end if;
  if exists (select 1 from public.ex_order_payout_settlements where request_key = p_request_key) then
    raise exception 'SHORTFALL_REQUEST_KEY_CONFLICT' using errcode = '22023';
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
end $function$
;

-- Keep all existing reconciliation counts; add complete rounding/receipt linkage checks.
CREATE OR REPLACE FUNCTION public.ex_admin_balance_reconcile(p_admin_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_unbalanced bigint;v_balance_drift bigint;v_hold_drift bigint;
 v_unlinked_refunds bigint;v_liability numeric;v_clearing numeric;
 v_unlinked_shortfalls bigint;v_shortfall_amount_mismatches bigint;v_rounding_mismatches bigint;
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
 select count(*) into v_rounding_mismatches from public.ex_order_payout_settlements s
 where not public.ex_payout_settlement_consistent(s.id);
 select coalesce(sum(available_iqd+held_iqd),0) into v_liability
   from public.ex_customer_balances;
 select coalesce(sum(delta_iqd),0) into v_clearing
   from public.ex_balance_entries where account='platform_clearing';
 return jsonb_build_object(
   'unbalanced_journals',v_unbalanced,'balance_mismatches',v_balance_drift,
   'held_payout_mismatches',v_hold_drift,'unlinked_refunds',v_unlinked_refunds,
   'unlinked_shortfalls',v_unlinked_shortfalls,'shortfall_amount_mismatches',v_shortfall_amount_mismatches,
   'rounding_settlement_mismatches',v_rounding_mismatches,
   'customer_liability_iqd',v_liability,'platform_clearing_iqd',v_clearing,
   'clearing_mismatch',v_liability+v_clearing<>0,
   'checked_at',now()
 );
end $function$
;

notify pgrst, 'reload schema';
