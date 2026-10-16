-- REVIEW REQUIRED: not applied to production. Run preflight and isolated tests first.
-- Keeps the existing USD wallet, fixed ad tiers, discount rules and FastPay flow.
begin;
create schema if not exists app_finance;
revoke all on schema app_finance from public, anon, authenticated;
grant usage on schema app_finance to authenticated;

-- Keep the pre-conversion decimal/text representation for reconciliation. This
-- is not a fabricated historical ledger. USD has six canonical decimal places.
create table if not exists app_finance.wallet_conversion_snapshot (
 user_id uuid primary key, original_text text not null, original_decimal numeric not null,
 converted_amount numeric(20,6) not null, captured_at timestamptz not null default now()
);
-- Refuse invalid legacy values instead of silently repairing financial data.
do $$ begin
  if exists(select 1 from public.pa_wallets where balance is null or balance<0
    or balance::text in ('NaN','Infinity','-Infinity') or balance>=100000000000000) then
    raise exception 'wallet_preflight_failed';
  end if;
end $$;
insert into app_finance.wallet_conversion_snapshot(user_id,original_text,original_decimal,converted_amount)
select user_id,balance::text,balance::numeric,round(balance::numeric,6) from public.pa_wallets
on conflict(user_id) do nothing;
alter table public.pa_wallets alter column balance type numeric(20,6) using round(balance::numeric,6);
alter table public.pa_wallets alter column balance set not null;
alter table public.pa_wallets drop constraint if exists pa_wallets_exact_balance;
alter table public.pa_wallets add constraint pa_wallets_exact_balance
  check(balance>=0 and balance::text not in ('NaN','Infinity','-Infinity'));
-- The canonical ad price is total_budget/charged_price_iqd; budget is legacy display.
-- All arithmetic in the canonical entry points below uses numeric or integer IQD.

create table if not exists app_finance.operations (
  actor_id uuid not null, operation text not null, request_key uuid not null,
  request jsonb not null, result jsonb not null,
  created_at timestamptz not null default clock_timestamp(),
  primary key(actor_id,operation,request_key)
);
create index if not exists finance_operations_rate on app_finance.operations(actor_id,created_at desc);
create table if not exists app_finance.request_limits (
  actor_id uuid not null, operation text not null, bucket timestamptz not null,
  requests integer not null check(requests>0), primary key(actor_id,operation)
);
create table if not exists app_finance.ledger (
  id uuid primary key default gen_random_uuid(), transaction_id uuid not null unique,
  original_transaction_id uuid, user_id uuid not null, actor_id uuid,
  wallet text not null default 'app_balance' check(wallet='app_balance'),
  currency text not null default 'USD' check(currency='USD'),
  amount numeric(20,6) not null check(amount::text not in ('NaN','Infinity','-Infinity')),
  balance_after numeric(20,6) not null check(balance_after>=0),
  operation text not null, reason text, created_at timestamptz not null default clock_timestamp()
);
create index if not exists finance_ledger_owner_time on app_finance.ledger(user_id,created_at desc);
create index if not exists finance_ledger_original on app_finance.ledger(original_transaction_id) where original_transaction_id is not null;
create table if not exists app_finance.topup_methods (
  method text primary key, enabled boolean not null, fee_basis_points integer not null check(fee_basis_points between 0 and 10000),
  min_iqd bigint not null check(min_iqd>0), max_iqd bigint not null check(max_iqd>=min_iqd),
  usd_iqd_rate numeric(20,6) not null check(usd_iqd_rate>0)
);
-- Same enabled rails and 18% telecom rules as the current screen. The previously
-- placeholder recipient rails remain disabled. Existing configuration is never overwritten.
insert into app_finance.topup_methods values
 ('fib',true,0,5000,10000000,1800),('fastpay',true,0,5000,10000000,1800),
 ('kcard',true,0,5000,10000000,1800),('zaincash',false,0,5000,10000000,1800),
 ('asiacell',false,1800,5000,10000000,1800),('korek',false,1800,5000,10000000,1800)
on conflict(method) do nothing;

alter table public.pa_transactions add column if not exists original_transaction_id uuid references public.pa_transactions(id);
alter table public.pa_transactions add column if not exists reviewed_by uuid;
alter table public.pa_transactions add column if not exists review_reason text;
alter table public.pa_transactions add column if not exists gross_amount_iqd bigint;
alter table public.pa_transactions add column if not exists fee_amount_iqd bigint;
alter table public.pa_transactions add column if not exists credited_amount_iqd bigint;
alter table public.pa_transactions add column if not exists request_key uuid;
create unique index if not exists pa_transactions_topup_key on public.pa_transactions(user_id,request_key) where request_key is not null;

create unique index if not exists pa_transactions_gateway_confirmation_once on public.pa_transactions(gateway,gw_transaction_id)
where wallet_credited and nullif(gw_transaction_id,'') is not null;

create or replace function app_finance.actor() returns uuid
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); s uuid;
begin
  begin s:=nullif(auth.jwt()->>'session_id','')::uuid;
  exception when invalid_text_representation then raise exception 'NOT_AUTHENTICATED' using errcode='42501'; end;
  if u is null or s is null or not exists(select 1 from auth.sessions x join auth.users a on a.id=x.user_id
    where x.id=s and x.user_id=u and (x.not_after is null or x.not_after>now())
    and (a.email_confirmed_at is not null or a.phone_confirmed_at is not null)) then
    raise exception 'NOT_AUTHENTICATED' using errcode='42501';
  end if;
  if exists(select 1 from public.profiles where id=u and is_banned) then
    raise exception 'ACCOUNT_UNAVAILABLE' using errcode='42501';
  end if;
  return u;
end $$;

create or replace function app_finance.rate_allowed(u uuid, op text, maximum integer) returns boolean
language plpgsql security definer set search_path='' as $$
declare n integer;
begin
  insert into app_finance.request_limits values(u,op,date_trunc('minute',clock_timestamp()),1)
  on conflict(actor_id,operation) do update set
    requests=case when request_limits.bucket=excluded.bucket then request_limits.requests+1 else 1 end,
    bucket=excluded.bucket returning requests into n;
  return n<=maximum;
end $$;

create or replace function app_finance.immutable_ledger() returns trigger
language plpgsql set search_path='' as $$ begin
 raise exception 'LEDGER_IMMUTABLE' using errcode='42501'; end $$;
drop trigger if exists immutable_ledger on app_finance.ledger;
create trigger immutable_ledger before update or delete on app_finance.ledger
for each row execute function app_finance.immutable_ledger();

-- Capture approved local charges/refunds and gateway-confirmed credits in the
-- SAME transaction. No client may write this table. Existing records are not fabricated.
create or replace function app_finance.capture_ledger() returns trigger
language plpgsql security definer set search_path='' as $$
declare signed_amount numeric; op text; wallet_balance numeric;
begin
  if new.status is distinct from 'approved' then return new; end if;
  if new.type='ad_payment' then signed_amount:=-new.amount; op:='ad_payment';
  elsif new.type in ('refund','ad_unspent_refund') then signed_amount:=new.amount; op:='refund';
  elsif coalesce(new.type,new.kind)='deposit' and new.wallet_credited then signed_amount:=new.amount; op:='topup';
  else return new; end if;
  select balance into wallet_balance from public.pa_wallets where user_id=new.user_id;
  if wallet_balance is null or new.amount<0 or new.amount::text in ('NaN','Infinity','-Infinity') then
    raise exception 'INVALID_FINANCIAL_STATE';
  end if;
  insert into app_finance.ledger(transaction_id,original_transaction_id,user_id,actor_id,amount,balance_after,operation,reason)
    values(new.id,new.original_transaction_id,new.user_id,coalesce(new.reviewed_by,auth.uid()),signed_amount,wallet_balance,op,left(new.review_reason,500))
    on conflict(transaction_id) do nothing;
  return new;
end $$;
drop trigger if exists zz_capture_finance_ledger on public.pa_transactions;
create trigger zz_capture_finance_ledger after insert or update of status,wallet_credited on public.pa_transactions
for each row execute function app_finance.capture_ledger();

create or replace function app_finance.submit_topup(p_key uuid,p_method text,p_gross_iqd bigint,p_sender text,p_note text,p_receipt text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=app_finance.actor(); m app_finance.topup_methods%rowtype;
 req jsonb; prev app_finance.operations%rowtype; tx public.pa_transactions%rowtype;
 fee_iqd bigint; net_iqd bigint; result jsonb;
begin
 if p_key is null or p_gross_iqd is null or p_gross_iqd<=0 or char_length(coalesce(p_sender,'')) not between 1 and 120
   or char_length(coalesce(p_note,''))>500 or char_length(coalesce(p_receipt,'')) not between 4 and 3000000
   or p_receipt !~ '^[A-Za-z0-9+/=]+$' then return jsonb_build_object('ok',false,'code','INVALID_INPUT'); end if;
 -- Hash receipt contents; the retry record must not duplicate the uploaded image.
 req:=jsonb_build_object('method',p_method,'gross',p_gross_iqd,'sender',p_sender,'note',p_note,'receipt',encode(sha256(convert_to(p_receipt,'UTF8')),'hex'));
 perform pg_advisory_xact_lock(hashtextextended(u::text||':topup:'||p_key::text,0));
 select * into prev from app_finance.operations where actor_id=u and operation='topup' and request_key=p_key;
 if found then
  if prev.request<>req then return jsonb_build_object('ok',false,'code','IDEMPOTENCY_CONFLICT'); end if;
  return prev.result;
 end if;
 if not app_finance.rate_allowed(u,'topup',5) then return jsonb_build_object('ok',false,'code','RATE_LIMITED'); end if;
 select * into m from app_finance.topup_methods where method=p_method and enabled;
 if not found or p_gross_iqd not between m.min_iqd and m.max_iqd then return jsonb_build_object('ok',false,'code','INVALID_METHOD_OR_AMOUNT'); end if;
 net_iqd:=round(p_gross_iqd::numeric*(10000-m.fee_basis_points)/10000); fee_iqd:=p_gross_iqd-net_iqd;
 insert into public.pa_transactions(user_id,amount,method,note,status,type,kind,currency,receipt_b64,fx_rate,
   gross_amount_iqd,fee_amount_iqd,credited_amount_iqd,request_key,wallet_credited)
 values(u,round(net_iqd/m.usd_iqd_rate,6),m.method,concat('ناو: ',p_sender,' | ',p_note),'pending','deposit','deposit','USD',p_receipt,m.usd_iqd_rate,
   p_gross_iqd,fee_iqd,net_iqd,p_key,false) returning * into tx;
 result:=jsonb_build_object('ok',true,'transaction_id',tx.id,'public_transaction_id',tx.public_transaction_id,
   'status','pending','amount_usd',tx.amount,'gross_iqd',p_gross_iqd,'credited_iqd',net_iqd,'fee_iqd',fee_iqd);
 insert into app_finance.operations values(u,'topup',p_key,req,result,clock_timestamp());
 return result;
end $$;
create or replace function public.pa_submit_topup(p_key uuid,p_method text,p_gross_iqd bigint,p_sender text,p_note text,p_receipt text)
returns jsonb language sql security invoker set search_path='' as $$
 select app_finance.submit_topup(p_key,p_method,p_gross_iqd,p_sender,p_note,p_receipt); $$;

create or replace function app_finance.review_topup(p_key uuid,p_transaction_id uuid,p_approve boolean,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=app_finance.actor(); tx public.pa_transactions%rowtype; req jsonb; prev app_finance.operations%rowtype;
 bal numeric; result jsonb;
begin
 if not public.pa_is_admin() then raise exception 'ADMIN_REQUIRED' using errcode='42501'; end if;
 if p_key is null or p_transaction_id is null or p_approve is null or char_length(btrim(coalesce(p_reason,''))) not between 3 and 500
 then return jsonb_build_object('ok',false,'code','INVALID_INPUT'); end if;
 req:=jsonb_build_object('transaction',p_transaction_id,'approve',p_approve,'reason',p_reason);
 perform pg_advisory_xact_lock(hashtextextended(u::text||':topup_review:'||p_key::text,0));
 select * into prev from app_finance.operations where actor_id=u and operation='topup_review' and request_key=p_key;
 if found then
  if prev.request<>req then return jsonb_build_object('ok',false,'code','IDEMPOTENCY_CONFLICT'); end if;
  return prev.result;
 end if;
 if not app_finance.rate_allowed(u,'topup_review',60) then return jsonb_build_object('ok',false,'code','RATE_LIMITED'); end if;
 select * into tx from public.pa_transactions where id=p_transaction_id for update;
 if not found or coalesce(tx.type,tx.kind)<>'deposit' or tx.gateway is not null then return jsonb_build_object('ok',false,'code','NOT_MANUAL_TOPUP'); end if;
 if tx.status is distinct from 'pending' or tx.wallet_credited or tx.paid_at is not null then return jsonb_build_object('ok',false,'code','ALREADY_FINALIZED'); end if;
 -- Only the new server-priced requests are approvable here. Legacy rows need
 -- explicit reconciliation; their client-supplied amount is never trusted.
 if tx.gross_amount_iqd is null or tx.credited_amount_iqd is null or tx.fx_rate is null or tx.amount<>round(tx.credited_amount_iqd/tx.fx_rate,6)
   or tx.amount<=0 then return jsonb_build_object('ok',false,'code','RECONCILIATION_REQUIRED'); end if;
 if p_approve then
   perform public.pa_lock_wallet(tx.user_id);
   update public.pa_wallets set balance=balance+tx.amount,updated_at=now() where user_id=tx.user_id returning balance into bal;
 end if;
 update public.pa_transactions set status=case when p_approve then 'approved' else 'rejected' end,
   wallet_credited=p_approve,paid_at=case when p_approve then now() else null end,balance_after=bal,
   reviewed_by=u,review_reason=p_reason,updated_at=now() where id=tx.id;
 result:=jsonb_build_object('ok',true,'transaction_id',tx.id,'status',case when p_approve then 'approved' else 'rejected' end);
 insert into app_finance.operations values(u,'topup_review',p_key,req,result,clock_timestamp());
 return result;
end $$;
create or replace function public.pa_review_topup(p_key uuid,p_transaction_id uuid,p_approve boolean,p_reason text)
returns jsonb language sql security invoker set search_path='' as $$ select app_finance.review_topup(p_key,p_transaction_id,p_approve,p_reason); $$;

create or replace function app_finance.refund_ad(p_key uuid,p_ad_id uuid,p_reason text,p_admin boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=app_finance.actor(); a public.pa_ads%rowtype; original public.pa_transactions%rowtype;
 req jsonb; prev app_finance.operations%rowtype; result jsonb; amount numeric; spent numeric; bal numeric; tx public.pa_transactions%rowtype;
begin
 if p_admin and not public.pa_is_admin() then raise exception 'ADMIN_REQUIRED' using errcode='42501'; end if;
 if p_admin is null or p_key is null or p_ad_id is null or char_length(btrim(coalesce(p_reason,''))) not between 1 and 500 then return jsonb_build_object('ok',false,'code','INVALID_INPUT'); end if;
 req:=jsonb_build_object('ad',p_ad_id,'reason',p_reason,'admin',p_admin);
 perform pg_advisory_xact_lock(hashtextextended(u::text||':refund:'||p_key::text,0));
 select * into prev from app_finance.operations where actor_id=u and operation='refund' and request_key=p_key;
 if found then
  if prev.request<>req then return jsonb_build_object('ok',false,'code','IDEMPOTENCY_CONFLICT'); end if;
  return prev.result;
 end if;
 if not app_finance.rate_allowed(u,'refund',20) then return jsonb_build_object('ok',false,'code','RATE_LIMITED'); end if;
 select * into a from public.pa_ads where id=p_ad_id and (p_admin or user_id=u) for update;
 if not found then return jsonb_build_object('ok',false,'code','NOT_FOUND'); end if;
 if not p_admin and exists(select 1 from app_finance.outbox where ad_id=a.id and status in ('leased','completed','reconcile')) then
   return jsonb_build_object('ok',false,'code','FULFILLMENT_IN_PROGRESS');
 end if;
 if a.refunded_at is not null then return jsonb_build_object('ok',false,'code','ALREADY_REFUNDED'); end if;
 if (p_admin and a.status is distinct from 'completed') or (not p_admin and (a.status is distinct from 'pending' or coalesce(a.tiktok_ad_id,'')<>''))
 then return jsonb_build_object('ok',false,'code','NOT_REFUNDABLE'); end if;
 -- Original debit is authoritative, including its discounts. Never refund a
 -- client-edited budget or an unrelated wallet/payment rail.
 select * into original from public.pa_transactions where ad_id=a.id and user_id=a.user_id and type='ad_payment' and status='approved' order by created_at limit 1 for update;
 if not found or original.method not in ('app_balance','fastpay') or original.amount<0 or original.amount::text in ('NaN','Infinity','-Infinity') then return jsonb_build_object('ok',false,'code','ORIGINAL_PAYMENT_REQUIRED'); end if;
 spent:=case when p_admin then round(coalesce(a.prev_spend,0)+greatest(coalesce(a.spend,0),coalesce(a.current_spend,0)),2) else 0 end;
 amount:=least(original.amount,case when p_admin then round(greatest(original.amount-spent,0),2) else original.amount end);
 amount:=amount-coalesce((select sum(l.amount) from app_finance.ledger l where original_transaction_id=original.id and operation='refund'),0);
 if amount<=0 then return jsonb_build_object('ok',false,'code','NO_REFUNDABLE_BALANCE'); end if;
 perform public.pa_lock_wallet(a.user_id);
 update public.pa_wallets set balance=balance+amount,updated_at=now() where user_id=a.user_id returning balance into bal;
 insert into public.pa_transactions(user_id,amount,method,status,type,kind,currency,note,balance_after,ad_id,ad_public_id,ad_title,
   original_transaction_id,reviewed_by,review_reason)
 values(a.user_id,amount,'app_balance','approved',case when p_admin then 'ad_unspent_refund' else 'refund' end,'refund','USD',p_reason,bal,a.id,a.public_ad_id,a.title,
   original.id,u,p_reason) returning * into tx;
 update public.pa_ads set refunded_amount=amount,refunded_at=now(),refunded_by=u,refund_tx_id=tx.tx_id,
   status=case when p_admin then status else 'rejected' end,
   reject_reason=case when p_admin then reject_reason else 'بەکارهێنەر خۆی ڕەتیکردەوە — هۆکار: '||p_reason end,updated_at=now() where id=a.id;
 if not p_admin then
   update app_finance.outbox set status='cancelled',lease_until=null where ad_id=a.id and status='pending';
   with released as (update public.promo_code_usages set status='refunded',refunded_at=now(),refund_reason='user_cancelled'
     where ad_id=a.id::text and user_id=a.user_id::text and status='active' returning promo_code_id)
   update public.promo_codes pc set used_count=greatest(coalesce(used_count,0)-1,0),updated_at=now() where pc.id in (select promo_code_id from released);
 end if;
 insert into public.pa_notifications(user_id,type,title,body,message,is_read,related_id,meta)
 values(a.user_id,'refund','پارەکەت گەڕایەوە',format('پارەی ڕیکلامی %s گەڕایەوە بۆ باڵانسەکەت.',a.public_ad_id),
 format('پارەی ڕیکلامی %s گەڕایەوە بۆ باڵانسەکەت.',a.public_ad_id),false,a.id,jsonb_build_object('ad_number',a.public_ad_id));
 result:=jsonb_build_object('ok',true,'ad_id',a.id,'refund_usd',amount,'refund_amount_usd',amount,'refund_tx_id',tx.tx_id,'balance_after',bal);
 insert into app_finance.operations values(u,'refund',p_key,req,result,clock_timestamp());
 return result;
end $$;
create or replace function public.pa_cancel_pending_ad(p_ad_id uuid,p_reason text) returns jsonb
language sql security invoker set search_path='' as $$ select app_finance.refund_ad(p_ad_id,p_ad_id,p_reason,false); $$;
create or replace function public.pa_admin_refund_ad_unspent_budget(p_ad_id uuid) returns jsonb
language sql security invoker set search_path='' as $$ select app_finance.refund_ad(p_ad_id,p_ad_id,'completed_ad_unspent_budget',true); $$;

-- Keep the live purchase implementation and its rules; make the newly stored
-- transaction denomination explicit (amount has always been wallet USD).
CREATE OR REPLACE FUNCTION public.pa_create_ad(p_ad jsonb, p_cost_usd numeric, p_promo_id uuid DEFAULT NULL::uuid, p_promo_code text DEFAULT NULL::text, p_promo_discount numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_user uuid := auth.uid();
  v_goal text := lower(btrim(coalesce(p_ad->>'goal', '')));
  v_category text := lower(coalesce(nullif(btrim(p_ad->>'category'), ''), 'other'));
  v_title text := btrim(coalesce(p_ad->>'title', ''));
  v_link text := btrim(coalesce(p_ad->>'video_link', ''));
  v_code text := btrim(coalesce(p_ad->>'video_code', ''));
  v_gender text := lower(btrim(coalesce(p_ad->>'gender', 'all')));
  v_location text := lower(btrim(coalesce(p_ad->>'location', 'kurdistan')));
  v_device_type text := lower(btrim(coalesce(p_ad->>'device_type', 'all')));
  v_customer_note text := nullif(btrim(coalesce(p_ad->>'customer_note', '')), '');
  v_payment_method text := lower(btrim(coalesce(p_ad->>'payment_method', 'app_balance')));
  v_payment_transaction_id uuid;
  v_payment_tx public.pa_transactions%rowtype;
  v_daily numeric;
  v_days integer;
  v_gross numeric;
  v_rate numeric := public.fastpay_rate();
  v_points numeric := 0;
  v_level public.pa_levels%rowtype;
  v_level_discount numeric := 0;
  v_promo public.promo_codes%rowtype;
  v_promo_discount numeric := 0;
  v_cost numeric;
  v_balance numeric;
  v_start_date date;
  v_start_time time;
  v_start_at timestamp;
  v_now_local timestamp := timezone('Asia/Baghdad', now());
  v_status text;
  v_asset_id uuid;
  v_ad public.pa_ads%rowtype;
  v_receipt_uid uuid := gen_random_uuid();
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'code', 'NOT_AUTHENTICATED');
  end if;

  begin
    v_daily := (p_ad->>'daily_budget')::numeric;
    v_days := (p_ad->>'days')::integer;
    v_start_date := nullif(p_ad->>'start_date', '')::date;
    v_start_time := nullif(p_ad->>'start_time', '')::time;
    v_asset_id := nullif(p_ad->>'asset_id', '')::uuid;
    v_payment_transaction_id := nullif(p_ad->>'payment_transaction_id', '')::uuid;
    if coalesce((p_ad->>'start_immediately')::boolean,false) then
      v_start_at := date_trunc('minute', v_now_local) + interval '1 minute';
      v_start_date := v_start_at::date; v_start_time := v_start_at::time;
    end if;
  exception when others then
    return jsonb_build_object('ok', false, 'code', 'INVALID_INPUT');
  end;

  if v_category not in (
    'cosmetics_beauty',
    'fashion_apparel',
    'electronics',
    'food_beverage',
    'home_living',
    'automotive',
    'services',
    'education',
    'games_apps',
    'health_wellness',
    'retail_ecommerce',
    'other'
  ) then
    return jsonb_build_object('ok', false, 'code', 'INVALID_CATEGORY');
  end if;

  if v_daily is null or v_days is null or char_length(v_title) not between 1 and 120
     or char_length(v_link) not between 8 and 2048
     or v_link !~* '^https://'
     or char_length(v_code) not between 1 and 200
     or v_goal not in ('views', 'messages')
     or v_gender not in ('all', 'male', 'female')
     or v_location not in ('all', 'kurdistan', 'iraq')
     or v_device_type not in ('all', 'iphone', 'android')
     or v_payment_method not in ('app_balance', 'fastpay')
     or v_daily not in (10,20,50,100,200,500,1000)
     or v_days not between 1 and 7
     or v_start_date is null
     or v_start_time is null
     or char_length(coalesce(v_customer_note, '')) > 500
     or jsonb_typeof(coalesce(p_ad->'age_groups', '[]'::jsonb)) <> 'array'
  then
    return jsonb_build_object('ok', false, 'code', 'INVALID_INPUT');
  end if;

  v_start_at := v_start_date + v_start_time;
  if v_start_at < v_now_local then
    return jsonb_build_object(
      'ok', false,
      'code', 'INVALID_SCHEDULE',
      'server_time', to_char(v_now_local, 'YYYY-MM-DD HH24:MI')
    );
  end if;

  if jsonb_array_length(coalesce(p_ad->'age_groups','[]'::jsonb))=0 then
    return jsonb_build_object('ok', false, 'code', 'INVALID_AGE_GROUP');
  end if;
  if exists (
    select 1
    from jsonb_array_elements_text(coalesce(p_ad->'age_groups','[]'::jsonb)) x(value)
    where x.value not in ('all','13-17','18-24','25-34','35-44','45-54','55+')
  ) then
    return jsonb_build_object('ok', false, 'code', 'INVALID_AGE_GROUP');
  end if;

  if v_goal = 'messages' then
    if v_asset_id is null or not exists (
      select 1
      from public.proxolink_cards c
      where c.id = v_asset_id and c.user_id = v_user
    ) then
      return jsonb_build_object('ok', false, 'code', 'INVALID_ASSET');
    end if;
  else
    v_asset_id := null;
  end if;

  v_gross := round(v_daily * v_days, 6);

  select coalesce(points, 0)
  into v_points
  from public.pa_user_points
  where user_id = v_user;

  select *
  into v_level
  from public.pa_levels
  where min_points <= coalesce(v_points, 0)
  order by min_points desc
  limit 1;

  if found then
    v_level_discount := least(
      v_gross,
      round(v_gross * coalesce(v_level.discount_percent, 0) / 100, 6)
        + round(coalesce(v_level.discount_iqd, 0) / v_rate, 6)
    );
  end if;

  if p_promo_id is not null or coalesce(btrim(p_promo_code), '') <> '' then
    select *
    into v_promo
    from public.promo_codes pc
    where (p_promo_id is null or pc.id = p_promo_id)
      and (
        coalesce(btrim(p_promo_code), '') = ''
        or upper(pc.code) = upper(btrim(p_promo_code))
      )
    for update;

    if not found
       or not coalesce(v_promo.is_active, false)
       or (v_promo.expires_at is not null and v_promo.expires_at <= now())
       or (v_promo.max_uses is not null and coalesce(v_promo.used_count,0) >= v_promo.max_uses)
       or (v_promo.restricted_to_user_id is not null and v_promo.restricted_to_user_id <> v_user)
       or exists (
         select 1
         from public.promo_code_usages u
         where u.promo_code_id = v_promo.id
           and u.user_id = v_user::text
           and u.status in ('active','consumed')
       )
    then
      return jsonb_build_object('ok', false, 'code', 'INVALID_PROMO');
    end if;

    if v_promo.discount_type::text = 'percentage' then
      v_promo_discount := round(
        v_gross * greatest(coalesce(v_promo.discount_value,0),0) / 100,
        6
      );
    else
      v_promo_discount := round(
        greatest(coalesce(v_promo.discount_value, v_promo.discount_iqd, 0),0) / v_rate,
        6
      );
    end if;
    v_promo_discount := least(v_gross, v_promo_discount);
  end if;

  v_cost := greatest(round(v_gross - v_level_discount - v_promo_discount, 6), 0);

  -- New confirmation callers require exactly the amount shown.
  if p_ad ? 'confirmation_cost_usd' and (
    round((p_ad->>'confirmation_cost_usd')::numeric,6) is distinct from v_cost
    or (p_ad->>'confirmation_price_iqd')::bigint is distinct from round(v_cost*v_rate)::bigint
  ) then
    return jsonb_build_object('ok',false,'code','PRICE_CHANGED');
  end if;

  if v_payment_method = 'fastpay' then
    if v_payment_transaction_id is null then
      return jsonb_build_object('ok', false, 'code', 'FASTPAY_TRANSACTION_REQUIRED');
    end if;

    select *
    into v_payment_tx
    from public.pa_transactions t
    where t.id = v_payment_transaction_id
      and t.user_id = v_user
      and t.method = v_payment_method
      and t.gateway = v_payment_method
    for update;

    if not found then
      return jsonb_build_object('ok', false, 'code', 'FASTPAY_TRANSACTION_NOT_FOUND');
    end if;
    if v_payment_tx.status <> 'approved'
       or v_payment_tx.gateway_status <> 'PAID'
       or not v_payment_tx.wallet_credited then
      return jsonb_build_object('ok', false, 'code', 'FASTPAY_NOT_PAID');
    end if;
    if v_payment_tx.ad_id is not null then
      return jsonb_build_object('ok', false, 'code', 'FASTPAY_ALREADY_USED');
    end if;
    if abs(v_payment_tx.amount - v_cost) > 0.01 then
      return jsonb_build_object(
        'ok', false,
        'code', 'FASTPAY_AMOUNT_MISMATCH',
        'paid_usd', v_payment_tx.amount,
        'required_usd', v_cost
      );
    end if;
  elsif v_payment_transaction_id is not null then
    return jsonb_build_object('ok', false, 'code', 'UNEXPECTED_PAYMENT_TRANSACTION');
  end if;

  v_balance := public.pa_lock_wallet(v_user);
  if v_balance < v_cost then
    return jsonb_build_object(
      'ok', false,
      'code', 'INSUFFICIENT_FUNDS',
      'balance', v_balance,
      'required', v_cost
    );
  end if;

  v_status := case
    when v_start_at > v_now_local + interval '5 minutes' then 'scheduled'
    else 'pending'
  end;

  insert into public.pa_ads (
    user_id, ad_number, status, title, goal, category, age_groups, gender, location,
    daily_budget, budget, days, total_budget, video_link, video_code,
    asset_id, card_id, post_code, promo_code,
    level_discount_percent, level_discount_iqd, level_name_at_purchase,
    start_date, start_time, end_date, target_age, target_gender,
    target_location, service_type, charged_price_iqd,
    charged_usd_iqd_rate, effective_usd_iqd_rate, usd_iqd_rate,
    service_budget_usd, pricing_source,
    device_type, customer_note, payment_method, payment_status,
    payment_transaction_id, receipt_uid
  ) values (
    v_user, 'TEMP00000000', v_status, v_title, v_goal, v_category,
    coalesce(p_ad->'age_groups','["all"]'::jsonb), v_gender, v_location,
    v_daily, v_cost::double precision, v_days, v_cost, v_link, v_code,
    v_asset_id, v_asset_id, coalesce(nullif(p_ad->>'post_code',''), v_code),
    case when v_promo.id is null then null else v_promo.code end,
    coalesce(v_level.discount_percent,0), coalesce(v_level.discount_iqd,0),
    v_level.name_ku, v_start_date, v_start_time,
    v_start_date + v_days, coalesce(p_ad->'age_groups','["all"]'::jsonb),
    v_gender, v_location, 'tiktok', round(v_cost * v_rate), v_rate, v_rate,
    v_rate, v_gross, 'server_atomic_v2',
    v_device_type, v_customer_note, v_payment_method, 'paid',
    v_payment_transaction_id, v_receipt_uid
  ) returning * into v_ad;

  if v_promo.id is not null then
    insert into public.promo_code_usages (
      promo_code_id, user_id, ad_id, status, discount_applied, used_at
    ) values (
      v_promo.id, v_user::text, v_ad.id::text, 'active',
      v_promo_discount, now()
    );
    update public.promo_codes
    set used_count = coalesce(used_count,0) + 1,
        updated_at = now()
    where id = v_promo.id;
  end if;

  update public.pa_wallets
  set balance = balance - v_cost,
      updated_at = now()
  where user_id = v_user
  returning balance into v_balance;

  if v_payment_method = 'fastpay' then
    update public.pa_transactions
    set ad_id = v_ad.id,
        ad_public_id = v_ad.public_ad_id,
        ad_title = v_title,
        note = format('FastPay بۆ ڕیکلام: %s | %s', v_title, v_ad.public_ad_id),
        updated_at = now()
    where id = v_payment_transaction_id;
  end if;

  insert into public.pa_transactions (
    id, user_id, type, kind, method, status, amount, currency, note, balance_after,
    ad_id, ad_public_id, ad_title
  ) values (
    v_receipt_uid, v_user, 'ad_payment', 'ad_payment', v_payment_method, 'approved', v_cost, 'USD',
    format('ڕیکلام: %s | ئایدی ڕیکلام: %s', v_title, v_ad.public_ad_id),
    v_balance, v_ad.id, v_ad.public_ad_id, v_title
  );

  insert into public.pa_notifications (
    user_id, type, title, body, message, is_read, related_id, meta
  ) values (
    v_user, v_status,
    case
      when v_status='scheduled' then 'ڕیکلامەکەت کات بۆ دانراوە'
      else 'ڕیکلامەکەت نێردرا'
    end,
    format('ڕیکلامی %s بە سەرکەوتوویی تۆمارکرا.', v_ad.public_ad_id),
    format('ڕیکلامی %s بە سەرکەوتوویی تۆمارکرا.', v_ad.public_ad_id),
    false,
    v_ad.id,
    jsonb_build_object(
      'ad_number', v_ad.public_ad_id,
      'payment_method', v_payment_method,
      'device_type', v_device_type,
      'category', v_category
    )
  );

  return jsonb_build_object(
    'ok', true,
    'ad_id', v_ad.id,
    'ad_number', v_ad.public_ad_id,
    'public_ad_id', v_ad.public_ad_id,
    'status', v_status,
    'category', v_category,
    'payment_method', v_payment_method,
    'payment_status', 'paid',
    'payment_transaction_id', v_payment_transaction_id,
    'receipt_uid', v_receipt_uid,
    'charged_usd', v_cost,
    'charged_iqd', round(v_cost*v_rate),
    'rate', v_rate,
    'gross_usd', v_gross,
    'promo_discount_usd', v_promo_discount,
    'level_discount_usd', v_level_discount,
    'balance_after', v_balance
  );
exception when unique_violation then
  raise;
end;
$function$;

-- Clients cannot bypass pricing/idempotency through the old purchase RPC or
-- insert arbitrary paid/gateway fields in pending transactions.
revoke insert,update,delete,truncate,references,trigger on public.pa_ads from public,anon,authenticated;
revoke insert,update,delete,truncate,references,trigger on public.pa_transactions from public,anon,authenticated;
revoke all on public.pa_wallets from public,anon,authenticated;
-- REVOKE on a table does not remove independent column-level grants.
do $$ declare t text; cols text; begin
 foreach t in array array['pa_ads','pa_transactions','pa_wallets'] loop
  select string_agg(quote_ident(attname),',') into cols from pg_attribute
  where attrelid=('public.'||t)::regclass and attnum>0 and not attisdropped;
  execute format('revoke insert(%s),update(%s),references(%s) on public.%I from public,anon,authenticated',cols,cols,cols,t);
 end loop;
end $$;
grant select on public.pa_wallets to authenticated;
revoke all on function public.pa_create_ad(jsonb,numeric,uuid,text,numeric) from public,anon,authenticated;

-- Per-ad pending records already form a manual fulfillment queue. The outbox
-- records integration work durably; external effects never happen in the SQL transaction.
create table if not exists app_finance.outbox (
 id uuid primary key default gen_random_uuid(),ad_id uuid not null unique references public.pa_ads(id),
 status text not null default 'pending' check(status in ('pending','leased','completed','reconcile','cancelled')),
 attempts integer not null default 0,available_at timestamptz not null default now(),lease_until timestamptz,
 lease_token uuid,external_reference text,last_error_code text,created_at timestamptz not null default now()
);
alter table app_finance.outbox drop constraint if exists outbox_status_check;
alter table app_finance.outbox add constraint outbox_status_check check(status in ('pending','leased','completed','reconcile','cancelled'));
create index if not exists finance_outbox_due on app_finance.outbox(available_at) where status in ('pending','leased');

create or replace function app_finance.submit_ad(p_submission_id uuid,p_ad jsonb,p_expected_cost_usd numeric,p_expected_price_iqd bigint,p_promo_id uuid,p_promo_code text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=app_finance.actor(); req jsonb; prev proxo_private.ad_submissions%rowtype; result jsonb;
begin
 if p_submission_id is null or p_ad is null or jsonb_typeof(p_ad)<>'object' or octet_length(p_ad::text)>16384
 or p_expected_cost_usd is null or p_expected_price_iqd is null or p_expected_cost_usd::text in ('NaN','Infinity','-Infinity')
 or p_expected_cost_usd<0 or p_expected_price_iqd<0 then return jsonb_build_object('ok',false,'code','INVALID_INPUT'); end if;
 req:=jsonb_build_object('ad',p_ad,'promo_id',p_promo_id,'promo_code',p_promo_code,'cost_usd',p_expected_cost_usd,'price_iqd',p_expected_price_iqd);
 perform pg_advisory_xact_lock(hashtextextended(u::text||':'||p_submission_id::text,0));
 select * into prev from proxo_private.ad_submissions where user_id=u and submission_id=p_submission_id;
 if found then
  if prev.request<>req then return jsonb_build_object('ok',false,'code','IDEMPOTENCY_CONFLICT'); end if;
  return prev.result;
 end if;
 if not app_finance.rate_allowed(u,'ad',20) then return jsonb_build_object('ok',false,'code','RATE_LIMITED'); end if;
 perform public.pa_assert_ad_allowed(u);
 result:=public.pa_create_ad(p_ad||jsonb_build_object('confirmation_cost_usd',p_expected_cost_usd,'confirmation_price_iqd',p_expected_price_iqd),p_expected_cost_usd,p_promo_id,p_promo_code,null);
 if result->>'ok'='true' then
  insert into proxo_private.ad_submissions(user_id,submission_id,request,result) values(u,p_submission_id,req,result);
  insert into app_finance.outbox(ad_id) values((result->>'ad_id')::uuid);
 end if;
 return result;
end $$;
create or replace function public.pa_submit_ad(p_submission_id uuid,p_ad jsonb,p_expected_cost_usd numeric,p_expected_price_iqd bigint,p_promo_id uuid default null,p_promo_code text default null)
returns jsonb language sql security invoker set search_path='' as $$ select app_finance.submit_ad(p_submission_id,p_ad,p_expected_cost_usd,p_expected_price_iqd,p_promo_id,p_promo_code); $$;

-- Only a trusted worker can lease work. A lease token prevents stale workers
-- from completing work reassigned after a timeout. Provider key MUST be outbox.id.
create or replace function public.pa_claim_ad_outbox() returns jsonb language plpgsql security definer set search_path='' as $$
declare job app_finance.outbox%rowtype;
begin
 update app_finance.outbox set status='reconcile',lease_until=null where status='leased' and lease_until<now() and attempts>=8;
 -- Lock the advertisement first, matching cancellation's lock order. Never
 -- dispatch an already-cancelled or externally fulfilled advertisement.
 select o.* into job from app_finance.outbox o join public.pa_ads a on a.id=o.ad_id
 where (o.status='pending' or (o.status='leased' and o.lease_until<now()))
 and o.available_at<=now() and o.attempts<8 and a.status in ('pending','scheduled')
 and a.refunded_at is null and coalesce(a.tiktok_ad_id,'')=''
 order by o.available_at for update of a skip locked limit 1;
 if not found then return null; end if;
 update app_finance.outbox set status='leased',attempts=attempts+1,lease_until=now()+interval '2 minutes',lease_token=gen_random_uuid()
 where id=job.id returning * into job; return to_jsonb(job);
end $$;
create or replace function public.pa_finish_ad_outbox(p_id uuid,p_lease uuid,p_reference text,p_error text default null) returns boolean
language plpgsql security definer set search_path='' as $$
begin
 update app_finance.outbox set status=case when p_reference is not null then 'completed' when attempts>=8 then 'reconcile' else 'pending' end,
 external_reference=left(p_reference,200),last_error_code=left(p_error,80),lease_until=null,
 available_at=now()+make_interval(secs=>least(3600,30*(2^least(attempts,7))::integer))
 where id=p_id and status='leased' and lease_token=p_lease and lease_until>now(); return found;
end $$;
revoke all on function public.pa_claim_ad_outbox(),public.pa_finish_ad_outbox(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.pa_claim_ad_outbox(),public.pa_finish_ad_outbox(uuid,uuid,text,text) to service_role;

do $$ declare t text; r record; begin
 foreach t in array array['operations','request_limits','ledger','topup_methods','outbox','wallet_conversion_snapshot'] loop
  execute format('alter table app_finance.%I enable row level security',t);
  execute format('revoke all on app_finance.%I from public,anon,authenticated',t);
 end loop;
 for r in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='app_finance' loop
  execute format('revoke all on function %s from public,anon,authenticated',r.sig);
 end loop;
end $$;
grant execute on function app_finance.submit_ad(uuid,jsonb,numeric,bigint,uuid,text),app_finance.submit_topup(uuid,text,bigint,text,text,text),
 app_finance.review_topup(uuid,uuid,boolean,text),app_finance.refund_ad(uuid,uuid,text,boolean) to authenticated;
revoke all on function public.pa_submit_topup(uuid,text,bigint,text,text,text),public.pa_review_topup(uuid,uuid,boolean,text),
 public.pa_submit_ad(uuid,jsonb,numeric,bigint,uuid,text),public.pa_cancel_pending_ad(uuid,text),public.pa_admin_refund_ad_unspent_budget(uuid) from public,anon;
grant execute on function public.pa_submit_topup(uuid,text,bigint,text,text,text),public.pa_review_topup(uuid,uuid,boolean,text),
 public.pa_submit_ad(uuid,jsonb,numeric,bigint,uuid,text),public.pa_cancel_pending_ad(uuid,text),public.pa_admin_refund_ad_unspent_budget(uuid) to authenticated;
CREATE OR REPLACE FUNCTION public.fastpay_mark_paid(p_order_id text, p_gw_transaction_id text DEFAULT NULL::text, p_received_amount numeric DEFAULT NULL::numeric, p_currency text DEFAULT NULL::text, p_source text DEFAULT 'ipn'::text, p_payload jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_tx          public.pa_transactions%rowtype;
  v_rate        numeric;
  v_bill_iqd    numeric;   -- what we asked FastPay to collect
  v_usd         numeric;   -- what goes into the wallet
  v_balance     numeric;   -- USD
  v_balance_iqd numeric;   -- display only
begin
  if p_received_amount is null or p_received_amount<=0 or p_received_amount::text in ('NaN','Infinity','-Infinity')
    or p_currency is null or nullif(btrim(p_gw_transaction_id),'') is null then
    return jsonb_build_object('ok',false,'code','PAYMENT_CONFIRMATION_REQUIRED');
  end if;
  select * into v_tx
  from public.pa_transactions
  where fastpay_order_id = p_order_id
  for update;

  if not found then
    return jsonb_build_object('ok', false, 'code', 'ORDER_NOT_FOUND', 'order_id', p_order_id);
  end if;

  -- ---- duplicate processing guard -----------------------------------
  if v_tx.wallet_credited and (v_tx.gw_transaction_id is distinct from p_gw_transaction_id
    or v_tx.received_amount is distinct from p_received_amount or upper(v_tx.currency) is distinct from upper(p_currency)) then
    return jsonb_build_object('ok',false,'code','IDEMPOTENCY_CONFLICT');
  end if;
  if v_tx.wallet_credited then
    return jsonb_build_object(
      'ok', true, 'duplicate', true, 'code', 'ALREADY_PROCESSED',
      'transaction_id', v_tx.id, 'user_id', v_tx.user_id,
      'status', v_tx.status, 'gateway_status', v_tx.gateway_status,
      'balance_after', v_tx.balance_after
    );
  end if;

  if v_tx.gateway_status in ('REFUNDED', 'REFUND_FAILED') then
    return jsonb_build_object('ok', false, 'code', 'ALREADY_REFUNDED', 'transaction_id', v_tx.id);
  end if;

  if v_tx.status is distinct from 'pending' or v_tx.gateway is distinct from 'fastpay' then
    return jsonb_build_object('ok',false,'code','INVALID_PAYMENT_STATE');
  end if;

  if v_tx.amount is null or v_tx.amount<=0 or v_tx.amount::text in ('NaN','Infinity','-Infinity')
    or v_tx.gateway_amount is null or v_tx.gateway_amount<=0 or v_tx.gateway_amount::text in ('NaN','Infinity','-Infinity')
    or v_tx.fx_rate is null or v_tx.fx_rate<=0 or v_tx.fx_rate::text in ('NaN','Infinity','-Infinity')
    or v_tx.currency is distinct from 'IQD' then
    return jsonb_build_object('ok',false,'code','INVALID_PAYMENT_STATE');
  end if;
  v_rate     := v_tx.fx_rate;
  v_usd      := v_tx.amount;
  v_bill_iqd := coalesce(v_tx.gateway_amount, round(v_tx.amount * v_rate, 2));

  -- ---- amount check, in IQD (the gateway's unit) ---------------------
  if p_received_amount is not null and p_received_amount <> v_bill_iqd then
    update public.pa_transactions
       set gateway_status    = 'FRAUD_SUSPECT',
           status            = 'rejected',
           fail_reason       = format('amount mismatch: billed %s IQD, received %s IQD',
                                      v_bill_iqd, p_received_amount),
           received_amount   = p_received_amount,
           gw_transaction_id = coalesce(p_gw_transaction_id, gw_transaction_id),
           gateway_payload   = coalesce(p_payload, gateway_payload)
     where id = v_tx.id;

    return jsonb_build_object(
      'ok', false, 'code', 'AMOUNT_MISMATCH',
      'expected_iqd', v_bill_iqd, 'received_iqd', p_received_amount,
      'transaction_id', v_tx.id
    );
  end if;

  -- ---- currency check -------------------------------------------------
  if p_currency is not null and upper(p_currency) <> upper(coalesce(v_tx.currency, 'IQD')) then
    update public.pa_transactions
       set gateway_status  = 'FRAUD_SUSPECT',
           status          = 'rejected',
           fail_reason     = format('currency mismatch: expected %s, received %s', v_tx.currency, p_currency),
           gateway_payload = coalesce(p_payload, gateway_payload)
     where id = v_tx.id;

    return jsonb_build_object(
      'ok', false, 'code', 'CURRENCY_MISMATCH',
      'expected', v_tx.currency, 'received', p_currency, 'transaction_id', v_tx.id
    );
  end if;

  -- ---- 1. credit the wallet in USD ------------------------------------
  insert into public.pa_wallets (user_id, balance)
  values (v_tx.user_id, v_usd)
  on conflict (user_id) do update
    set balance    = pa_wallets.balance + excluded.balance,
        updated_at = now()
  returning balance into v_balance;

  v_balance_iqd := round(v_balance * v_rate);

  -- ---- 2. settle the transaction row -----------------------------------
  --   status -> 'approved' also fires notify_transaction_email, which now
  --   matches method='fastpay' and sends the Kurdish FastPay receipt.
  update public.pa_transactions
     set status            = 'approved',
         gateway_status    = 'PAID',
         gw_transaction_id = coalesce(p_gw_transaction_id, gw_transaction_id),
         received_amount   = coalesce(p_received_amount, v_bill_iqd),
         wallet_credited   = true,
         balance_after     = v_balance_iqd,
         paid_at           = now(),
         review_reason     = 'verified_fastpay_payment',
         fail_reason       = null,
         gateway_payload   = coalesce(p_payload, gateway_payload)
   where id = v_tx.id;

  -- ---- 3. notify the user (amounts shown in IQD) -----------------------
  insert into public.pa_notifications (user_id, title, message, body, type, related_id, meta)
  values (
    v_tx.user_id,
    'Payment received',
    format('%s IQD has been added to your wallet.', v_bill_iqd),
    format('Order %s was paid successfully. New balance: %s IQD.', p_order_id, v_balance_iqd),
    'payment',
    v_tx.id,
    jsonb_build_object(
      'source', 'fastpay',
      'trigger', p_source,
      'order_id', p_order_id,
      'gw_transaction_id', p_gw_transaction_id,
      'amount_iqd', v_bill_iqd,
      'amount_usd', v_usd,
      'fx_rate', v_rate,
      'balance_after_usd', v_balance,
      'balance_after_iqd', v_balance_iqd
    )
  );

  return jsonb_build_object(
    'ok', true, 'duplicate', false,
    'transaction_id', v_tx.id, 'user_id', v_tx.user_id,
    'amount_iqd', v_bill_iqd,
    'amount_usd', v_usd,
    'fx_rate', v_rate,
    'balance_after', v_balance,             -- USD, matches pa_wallets.balance
    'balance_after_iqd', v_balance_iqd,     -- for display
    'status', 'approved', 'gateway_status', 'PAID'
  );
end $function$;

revoke all on function public.fastpay_mark_paid(text,text,numeric,text,text,jsonb) from public,anon,authenticated;
grant execute on function public.fastpay_mark_paid(text,text,numeric,text,text,jsonb) to service_role;
commit;
