-- Proxo Balance Exchange: controlled refunds, internal IQD liabilities and immutable journal.
-- No existing order is rewritten. No customer is credited by this migration.
create table if not exists public.ex_balance_config (
  id boolean primary key default true check (id),
  payouts_enabled boolean not null default false,
  max_single_payout_iqd bigint not null default 1000000 check (max_single_payout_iqd between 10000 and 1000000000),
  updated_at timestamptz not null default now()
);
insert into public.ex_balance_config(id,payouts_enabled) values(true,false) on conflict(id) do nothing;
alter table public.ex_balance_config enable row level security;
revoke all on public.ex_balance_config from public,anon,authenticated;
grant all on public.ex_balance_config to service_role;

create table if not exists public.ex_customer_balances (
  user_id uuid primary key references public.ex_profiles(id) on delete restrict,
  available_iqd bigint not null default 0 check(available_iqd>=0),
  held_iqd bigint not null default 0 check(held_iqd>=0),
  revision bigint not null default 0,
  updated_at timestamptz not null default now()
);
alter table public.ex_customer_balances enable row level security;
create policy ex_balance_own_read on public.ex_customer_balances for select to authenticated
  using ((select auth.uid())=user_id);
revoke all on public.ex_customer_balances from public,anon,authenticated;
grant select on public.ex_customer_balances to authenticated;
grant all on public.ex_customer_balances to service_role;

create table if not exists public.ex_balance_journal (
  id uuid primary key default gen_random_uuid(),
  operation_key text not null unique check(length(operation_key) between 4 and 160),
  kind text not null check(kind in ('verified_refund','payout_hold','payout_cancel','payout_paid')),
  user_id uuid not null references public.ex_profiles(id) on delete restrict,
  order_id uuid references public.ex_orders(id) on delete restrict,
  payout_id uuid,
  actor_id uuid references auth.users(id) on delete set null,
  note text not null,
  evidence_ref text,
  created_at timestamptz not null default now()
);
create index ex_balance_journal_user_idx on public.ex_balance_journal(user_id,created_at desc);
alter table public.ex_balance_journal enable row level security;
create policy ex_balance_journal_own_read on public.ex_balance_journal for select to authenticated
  using ((select auth.uid())=user_id);
revoke all on public.ex_balance_journal from public,anon,authenticated;
grant select on public.ex_balance_journal to authenticated;
grant all on public.ex_balance_journal to service_role;

create table if not exists public.ex_balance_entries (
  id uuid primary key default gen_random_uuid(),
  journal_id uuid not null references public.ex_balance_journal(id) on delete restrict,
  account text not null check(account in ('customer_available','customer_held','platform_clearing')),
  user_id uuid references public.ex_profiles(id) on delete restrict,
  delta_iqd bigint not null check(delta_iqd<>0),
  balance_after_iqd bigint check(balance_after_iqd>=0),
  created_at timestamptz not null default now(),
  constraint ex_balance_entry_owner check (
    (account='platform_clearing' and user_id is null and balance_after_iqd is null)
    or (account<>'platform_clearing' and user_id is not null and balance_after_iqd is not null))
);
create unique index ex_balance_entries_one_account_per_journal
  on public.ex_balance_entries(journal_id,account);
create index ex_balance_entries_user_idx on public.ex_balance_entries(user_id,created_at desc);
alter table public.ex_balance_entries enable row level security;
create policy ex_balance_entries_own_read on public.ex_balance_entries for select to authenticated
  using ((select auth.uid())=user_id);
revoke all on public.ex_balance_entries from public,anon,authenticated;
grant select on public.ex_balance_entries to authenticated;
grant all on public.ex_balance_entries to service_role;

create table if not exists public.ex_refund_cases (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.ex_orders(id) on delete restrict,
  user_id uuid not null references public.ex_profiles(id) on delete restrict,
  amount_iqd bigint not null check(amount_iqd>=10000),
  status text not null default 'credited' check(status='credited'),
  receipt_url text,
  bank_verification_reference text not null unique check(length(bank_verification_reference) between 6 and 160),
  failure_reason text not null check(length(failure_reason) between 10 and 2000),
  verified_by uuid not null references auth.users(id) on delete restrict,
  confirmed_funds_received boolean not null check(confirmed_funds_received),
  confirmed_payout_failed boolean not null check(confirmed_payout_failed),
  journal_id uuid unique not null references public.ex_balance_journal(id) on delete restrict,
  created_at timestamptz not null default now()
);
create index ex_refund_cases_user_idx on public.ex_refund_cases(user_id,created_at desc);
alter table public.ex_refund_cases enable row level security;
create policy ex_refund_cases_own_read on public.ex_refund_cases for select to authenticated
  using ((select auth.uid())=user_id);
revoke all on public.ex_refund_cases from public,anon,authenticated;
grant select on public.ex_refund_cases to authenticated;
grant all on public.ex_refund_cases to service_role;

create table if not exists public.ex_payout_requests (
  id uuid primary key default gen_random_uuid(),
  request_key uuid not null unique,
  user_id uuid not null references public.ex_profiles(id) on delete restrict,
  amount_iqd bigint not null check(amount_iqd>=10000),
  destination_wallet text not null,
  destination_number text not null,
  destination_owner text not null,
  status text not null default 'pending' check(status in ('pending','paid','cancelled')),
  held_journal_id uuid unique references public.ex_balance_journal(id) on delete restrict,
  settled_journal_id uuid unique references public.ex_balance_journal(id) on delete restrict,
  transfer_reference text unique,
  payout_receipt_url text,
  verification_reference text,
  admin_note text,
  reviewed_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index ex_payout_requests_user_idx on public.ex_payout_requests(user_id,created_at desc);
create index ex_payout_requests_pending_idx on public.ex_payout_requests(status,created_at);
alter table public.ex_payout_requests enable row level security;
create policy ex_payout_requests_own_read on public.ex_payout_requests for select to authenticated
  using ((select auth.uid())=user_id);
revoke all on public.ex_payout_requests from public,anon,authenticated;
grant select on public.ex_payout_requests to authenticated;
grant all on public.ex_payout_requests to service_role;

alter table public.ex_balance_journal add constraint ex_balance_journal_payout_fkey
  foreign key(payout_id) references public.ex_payout_requests(id) on delete restrict;

create table if not exists public.ex_balance_risk_alerts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.ex_profiles(id) on delete set null,
  kind text not null,
  reference_id uuid,
  ip_address text,
  details jsonb not null default '{}'::jsonb,
  status text not null default 'open' check(status in ('open','reviewed','dismissed')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid references auth.users(id) on delete set null
);
create index ex_balance_risk_alerts_open_idx on public.ex_balance_risk_alerts(status,created_at desc);
alter table public.ex_balance_risk_alerts enable row level security;
revoke all on public.ex_balance_risk_alerts from public,anon,authenticated;
grant all on public.ex_balance_risk_alerts to service_role;

-- Append-only journal: corrections are new, explicitly labelled operations.
create or replace function public.ex_balance_deny_journal_mutation()
returns trigger language plpgsql set search_path='' as $fn$
begin
  raise exception 'IMMUTABLE_FINANCIAL_JOURNAL' using errcode='P0001';
end
$fn$;
revoke all on function public.ex_balance_deny_journal_mutation() from public,anon,authenticated;
create trigger ex_balance_journal_immutable before update or delete on public.ex_balance_journal
  for each row execute function public.ex_balance_deny_journal_mutation();
create trigger ex_balance_entries_immutable before update or delete on public.ex_balance_entries
  for each row execute function public.ex_balance_deny_journal_mutation();
create trigger ex_refund_cases_immutable before update or delete on public.ex_refund_cases
  for each row execute function public.ex_balance_deny_journal_mutation();

-- Only the trusted posting routine may update a customer balance.
create or replace function public.ex_balance_deny_direct_write()
returns trigger language plpgsql set search_path='' as $fn$
begin
  if current_setting('ex_balance.authorized_post',true) is distinct from 'yes' then
    raise exception 'BALANCE_DIRECT_WRITE_FORBIDDEN' using errcode='P0001';
  end if;
  return new;
end $fn$;
revoke all on function public.ex_balance_deny_direct_write() from public,anon,authenticated;
create trigger ex_balance_guard_balance before insert or update or delete on public.ex_customer_balances
  for each row execute function public.ex_balance_deny_direct_write();

create or replace function public.ex_balance_post(
 p_user_id uuid,p_available_delta bigint,p_held_delta bigint,p_kind text,
 p_key text,p_order_id uuid,p_payout_id uuid,p_actor uuid,p_note text,p_evidence text default null
) returns uuid language plpgsql security definer set search_path='' as $fn$
declare v_balance public.ex_customer_balances%rowtype;
        v_journal uuid; v_available bigint; v_held bigint; v_clearing bigint;
begin
 if p_kind not in ('verified_refund','payout_hold','payout_cancel','payout_paid')
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

create or replace function public.ex_balance_credit_refund(
 p_order_id uuid,p_admin_id uuid,p_verification_reference text,p_failure_reason text,
 p_confirmed_received boolean,p_confirmed_failed boolean
) returns public.ex_refund_cases language plpgsql security definer set search_path='' as $fn$
declare v_order public.ex_orders%rowtype;v_case public.ex_refund_cases%rowtype;
        v_journal uuid;v_amt bigint;
begin
 if not exists(select 1 from public.ex_profiles
    where id=p_admin_id and is_admin=true and is_banned=false) then
    raise exception 'ADMIN_REQUIRED' using errcode='42501'; end if;
 if p_confirmed_received is distinct from true or p_confirmed_failed is distinct from true
    or length(btrim(coalesce(p_failure_reason,'')))<10
    or length(btrim(coalesce(p_verification_reference,'')))<6 then
    raise exception 'VERIFIED_FUNDS_AND_FAILED_PAYOUT_PROOF_REQUIRED' using errcode='22023'; end if;
 select * into v_order from public.ex_orders where id=p_order_id for update;
 if not found then raise exception 'ORDER_NOT_FOUND' using errcode='22023'; end if;
 if v_order.status='پەسەندکرا' or v_order.from_method='USDT'
    or v_order.to_method='USDT' or v_order.amount<>trunc(v_order.amount)
    or v_order.amount<10000 or v_order.amount>1000000000 then
    raise exception 'ORDER_NOT_ELIGIBLE_FOR_IQD_REFUND' using errcode='22023'; end if;
 if exists(select 1 from public.ex_refund_cases where order_id=p_order_id) or
    exists(select 1 from public.ex_refund_cases r join public.ex_orders o on o.id=r.order_id
     where o.receipt_hash is not null and o.receipt_hash=v_order.receipt_hash) then
    raise exception 'ORDER_ALREADY_REFUNDED' using errcode='23505'; end if;
 v_amt:=v_order.amount::bigint;
 v_journal:=public.ex_balance_post(v_order.user_id,v_amt,0,'verified_refund',
     'refund:'||v_order.id::text,v_order.id,null,p_admin_id,
     left(p_failure_reason,2000),left(btrim(p_verification_reference),160));
 insert into public.ex_refund_cases(order_id,user_id,amount_iqd,receipt_url,
    bank_verification_reference,failure_reason,verified_by,
    confirmed_funds_received,confirmed_payout_failed,journal_id)
 values(v_order.id,v_order.user_id,v_amt,v_order.receipt_url,
    left(btrim(p_verification_reference),160),left(btrim(p_failure_reason),2000),
    p_admin_id,true,true,v_journal) returning * into v_case;
 insert into public.ex_admin_audit_log(admin_id,action,target_user_id,detail)
 values(p_admin_id,'balance_verified_refund',v_order.user_id,
       'refund:'||v_case.id||' order:'||v_order.order_code||' IQD:'||v_amt);
 insert into public.ex_notifications(user_id,order_id,type,title,message)
 values(v_order.user_id,v_order.id,'admin','پارەکەت گەڕێندرایەوە',
        'بڕی '||v_amt||' دینار بۆ باڵانسی هەژمارەکەت زیاد کرا.');
 return v_case;
end $fn$;
revoke all on function public.ex_balance_credit_refund(uuid,uuid,text,text,boolean,boolean) from public,anon,authenticated;
grant execute on function public.ex_balance_credit_refund(uuid,uuid,text,text,boolean,boolean) to service_role;

create or replace function public.ex_balance_request_payout(
 p_user_id uuid,p_request_key uuid,p_amount_iqd bigint,p_wallet text,p_number text
) returns public.ex_payout_requests language plpgsql security definer set search_path='' as $fn$
declare v_req public.ex_payout_requests%rowtype;v_name text;v_journal uuid;v_limit bigint;
begin
 if p_user_id is null or p_request_key is null then
   raise exception 'INVALID_PAYOUT_REQUEST' using errcode='22023'; end if;
 select * into v_req from public.ex_payout_requests
   where user_id=p_user_id and request_key=p_request_key;
 if found then return v_req; end if;
 select max_single_payout_iqd into v_limit from public.ex_balance_config
   where id=true and payouts_enabled=true;
 if v_limit is null then raise exception 'PAYOUTS_NOT_ENABLED' using errcode='42501'; end if;
 if p_amount_iqd is null or p_amount_iqd<10000 or p_amount_iqd>v_limit then
   raise exception 'PAYOUT_AMOUNT_OUT_OF_RANGE' using errcode='22023'; end if;
 select full_name into v_name from public.ex_profiles
   where id=p_user_id and is_banned=false;
 if length(btrim(coalesce(v_name,'')))<2 then
   raise exception 'PROFILE_IDENTITY_REQUIRED' using errcode='42501'; end if;
 if not exists(select 1 from public.ex_wallets where key=p_wallet
   and allow_receive=true and is_locked=false) then
   raise exception 'DESTINATION_CLOSED' using errcode='22023'; end if;
 if length(coalesce(p_number,''))<6 or length(p_number)>32
    or p_number !~ '^[0-9]+$' then
   raise exception 'INVALID_DESTINATION_NUMBER' using errcode='22023'; end if;
 insert into public.ex_payout_requests(request_key,user_id,amount_iqd,destination_wallet,
    destination_number,destination_owner)
 values(p_request_key,p_user_id,p_amount_iqd,p_wallet,p_number,v_name)
 returning * into v_req;
 v_journal:=public.ex_balance_post(p_user_id,-p_amount_iqd,p_amount_iqd,
    'payout_hold','payout-hold:'||v_req.id,null,v_req.id,p_user_id,
    'Hold for destination verification and manual payout');
 update public.ex_payout_requests set held_journal_id=v_journal where id=v_req.id
 returning * into v_req;
 return v_req;
end $fn$;
revoke all on function public.ex_balance_request_payout(uuid,uuid,bigint,text,text) from public,anon,authenticated;
grant execute on function public.ex_balance_request_payout(uuid,uuid,bigint,text,text) to service_role;

create or replace function public.ex_balance_cancel_payout(
 p_payout_id uuid,p_actor uuid,p_reason text
) returns public.ex_payout_requests language plpgsql security definer set search_path='' as $fn$
declare v_req public.ex_payout_requests%rowtype;v_journal uuid;v_is_admin boolean;
begin
 select * into v_req from public.ex_payout_requests where id=p_payout_id for update;
 if not found then raise exception 'PAYOUT_NOT_FOUND' using errcode='22023'; end if;
 select exists(select 1 from public.ex_profiles where id=p_actor and is_admin=true and is_banned=false)
    into v_is_admin;
 if p_actor<>v_req.user_id and not v_is_admin then
    raise exception 'PAYOUT_NOT_OWNED' using errcode='42501'; end if;
 if v_req.status<>'pending' then
    raise exception 'PAYOUT_ALREADY_FINAL' using errcode='22023'; end if;
 v_journal:=public.ex_balance_post(v_req.user_id,v_req.amount_iqd,-v_req.amount_iqd,
    'payout_cancel','payout-cancel:'||v_req.id,null,v_req.id,p_actor,
    left(coalesce(nullif(btrim(p_reason),''),'Cancelled before payout'),500));
 update public.ex_payout_requests set status='cancelled',settled_journal_id=v_journal,
    admin_note=left(coalesce(p_reason,'Cancelled'),500),
    reviewed_by=case when v_is_admin then p_actor else null end,updated_at=now()
 where id=v_req.id returning * into v_req;
 return v_req;
end $fn$;
revoke all on function public.ex_balance_cancel_payout(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.ex_balance_cancel_payout(uuid,uuid,text) to service_role;

create or replace function public.ex_balance_mark_payout_paid(
 p_payout_id uuid,p_admin_id uuid,p_reference text,p_verification_reference text,
 p_receipt_url text,p_note text
) returns public.ex_payout_requests language plpgsql security definer set search_path='' as $fn$
declare v_req public.ex_payout_requests%rowtype;v_journal uuid;
begin
 if not exists(select 1 from public.ex_profiles where id=p_admin_id and is_admin=true and is_banned=false) then
   raise exception 'ADMIN_REQUIRED' using errcode='42501'; end if;
 if length(btrim(coalesce(p_reference,'')))<6
    or length(btrim(coalesce(p_verification_reference,'')))<6
    or coalesce(p_receipt_url,'') not like 'https://%'
    or length(btrim(coalesce(p_note,'')))<10 then
   raise exception 'PAID_PROOF_AND_DESTINATION_VERIFICATION_REQUIRED' using errcode='22023'; end if;
 select * into v_req from public.ex_payout_requests where id=p_payout_id for update;
 if not found or v_req.status<>'pending' then
   raise exception 'PAYOUT_ALREADY_FINAL_OR_MISSING' using errcode='22023'; end if;
 v_journal:=public.ex_balance_post(v_req.user_id,0,-v_req.amount_iqd,
    'payout_paid','payout-paid:'||v_req.id,null,v_req.id,p_admin_id,
    left(btrim(p_note),500),left(p_receipt_url,2000));
 update public.ex_payout_requests set status='paid',settled_journal_id=v_journal,
    transfer_reference=left(btrim(p_reference),160),
    verification_reference=left(btrim(p_verification_reference),160),
    payout_receipt_url=left(p_receipt_url,2000),admin_note=left(btrim(p_note),500),
    reviewed_by=p_admin_id,updated_at=now()
  where id=v_req.id returning * into v_req;
 insert into public.ex_admin_audit_log(admin_id,action,target_user_id,detail)
 values(p_admin_id,'balance_payout_paid',v_req.user_id,
    'payout:'||v_req.id||' IQD:'||v_req.amount_iqd);
 insert into public.ex_notifications(user_id,type,title,message)
 values(v_req.user_id,'admin','ناردنی باڵانس تەواو بوو',
    'داواکاری ناردنی '||v_req.amount_iqd||' دینار جێبەجێ کرا.');
 return v_req;
end $fn$;
revoke all on function public.ex_balance_mark_payout_paid(uuid,uuid,text,text,text,text) from public,anon,authenticated;
grant execute on function public.ex_balance_mark_payout_paid(uuid,uuid,text,text,text,text) to service_role;

-- A credited receipt can never be recycled as a new order, even if the old order was rejected.
create or replace function public.ex_balance_guard_refunded_order()
returns trigger language plpgsql set search_path='' as $fn$
begin
 if tg_op='INSERT' and new.receipt_hash is not null and
   exists(select 1 from public.ex_refund_cases r
    join public.ex_orders o on o.id=r.order_id
    where o.receipt_hash=new.receipt_hash) then
   raise exception 'REFUNDED_RECEIPT_NOT_REUSABLE' using errcode='23505'; end if;
 if tg_op='UPDATE' and new.status='پەسەندکرا'
    and old.status is distinct from new.status and
   exists(select 1 from public.ex_refund_cases where order_id=old.id) then
   raise exception 'REFUNDED_ORDER_CANNOT_BE_APPROVED' using errcode='23514'; end if;
 return new;
end $fn$;
revoke all on function public.ex_balance_guard_refunded_order() from public,anon,authenticated;
create trigger trg_ex_orders_guard_refunded_insert before insert on public.ex_orders
  for each row execute function public.ex_balance_guard_refunded_order();
create trigger trg_ex_orders_guard_refunded_approval before update of status on public.ex_orders
  for each row execute function public.ex_balance_guard_refunded_order();
