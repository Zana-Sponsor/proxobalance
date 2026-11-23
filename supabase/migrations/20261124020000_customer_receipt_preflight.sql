-- Customer receipt preflight: read the uploaded incoming-transfer receipt before creating
-- a new order, compare its amount and recipient against server-owned inputs, then reuse the
-- successful OCR result in ex_receipt_reads instead of invoking Gemini a second time.

create table if not exists public.ex_customer_receipt_preflights (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  from_method text not null,
  to_method text not null,
  expected_amount numeric not null,
  expected_currency text not null check (expected_currency in ('IQD','USDT')),
  expected_receiver_account text not null,
  receipt_url text not null,
  receipt_hash text not null check (receipt_hash ~ '^[a-f0-9]{64}$'),
  status text not null default 'uploading' check (status in ('uploading','queued','processing','complete','error')),
  error_code text,
  is_receipt boolean,
  success boolean,
  actual_amount numeric,
  actual_currency text,
  amount_confidence numeric,
  receiver_account text,
  receiver_account_confidence numeric,
  wallet text,
  reference text,
  paid_at text,
  sender_name text,
  sender_account text,
  receiver_name text,
  status_text text,
  notes text,
  amount_matches boolean,
  receiver_matches boolean,
  model text,
  attempts smallint not null default 0 check (attempts between 0 and 3),
  claimed_at timestamptz,
  linked_order_id uuid unique references public.ex_orders(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '30 minutes'),
  constraint ex_customer_receipt_preflight_amount_valid check (expected_amount > 0 and expected_amount <= 1000000000)
);
create index if not exists ex_customer_receipt_preflights_owner_recent_idx
  on public.ex_customer_receipt_preflights(user_id, created_at desc);
alter table public.ex_customer_receipt_preflights enable row level security;
revoke all on public.ex_customer_receipt_preflights from public, anon, authenticated;
grant all on public.ex_customer_receipt_preflights to service_role;

alter table public.ex_orders
  add column if not exists receipt_preflight_id uuid references public.ex_customer_receipt_preflights(id) on delete set null;

create or replace function public.ex_customer_receipt_preflight_start(
  p_check_id uuid,p_from_method text,p_to_method text,p_amount numeric,p_receipt_url text,p_receipt_hash text
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_uid uuid:=auth.uid(); v_currency text; v_receiver text; v_path text; v_count integer;
  v_source public.ex_wallets%rowtype; v_target public.ex_wallets%rowtype; v_rate boolean;
begin
  if v_uid is null then raise exception using errcode='42501',message='AUTH_REQUIRED'; end if;
  if p_check_id is null or p_from_method is null or p_to_method is null or p_from_method=p_to_method
     or p_amount is null or p_amount<=0 or p_amount>1000000000
     or (p_from_method<>'USDT' and p_amount<>trunc(p_amount))
     or p_receipt_url is null or p_receipt_hash is null
     or p_receipt_hash !~ '^[A-Fa-f0-9]{64}$' then
    raise exception using errcode='P0001',message='RECEIPT_PREFLIGHT_INVALID';
  end if;
  if exists(select 1 from public.ex_profiles p where p.id=v_uid and p.is_banned) then
    raise exception using errcode='42501',message='ACCOUNT_BANNED';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_uid::text,73194921));
  select * into v_source from public.ex_wallets where key=p_from_method and is_locked=false and allow_from=true;
  select * into v_target from public.ex_wallets where key=p_to_method and is_locked=false and allow_receive=true;
  select exists(select 1 from public.ex_rates r where r.from_method=p_from_method and r.to_method=p_to_method and r.is_active=true) into v_rate;
  if v_source.id is null or v_target.id is null or not v_rate then
    raise exception using errcode='P0001',message='RECEIPT_PREFLIGHT_ROUTE_UNAVAILABLE';
  end if;
  v_receiver:=nullif(btrim(v_target.wallet_number),'');
  if v_receiver is null then raise exception using errcode='P0001',message='RECEIPT_PREFLIGHT_DESTINATION_UNAVAILABLE'; end if;
  v_currency:=case when p_from_method='USDT' then 'USDT' else 'IQD' end;
  if p_receipt_url !~ ('^https://pycxuugoblkslvwebxuu\.supabase\.co/storage/v1/object/public/receipts/'||v_uid::text||'/[^/?#]+$') then
    raise exception using errcode='P0001',message='RECEIPT_PREFLIGHT_PATH_INVALID';
  end if;
  v_path:=regexp_replace(p_receipt_url,'^https://pycxuugoblkslvwebxuu\.supabase\.co/storage/v1/object/public/receipts/','');
  if not exists(select 1 from storage.objects o where o.bucket_id='receipts' and o.name=v_path
      and (o.owner_id=v_uid::text or o.owner=v_uid) and coalesce((o.metadata->>'size')::bigint,0) between 1 and 10485760) then
    raise exception using errcode='P0001',message='RECEIPT_PREFLIGHT_UPLOAD_NOT_FOUND';
  end if;
  delete from public.ex_customer_receipt_preflights where expires_at<=now() and linked_order_id is null;
  select count(*) into v_count from public.ex_customer_receipt_preflights
   where user_id=v_uid and created_at>now()-interval '1 hour';
  if v_count>=8 then raise exception using errcode='P0001',message='RECEIPT_PREFLIGHT_RATE_LIMIT'; end if;
  insert into public.ex_customer_receipt_preflights(
    id,user_id,from_method,to_method,expected_amount,expected_currency,expected_receiver_account,receipt_url,receipt_hash
  ) values (
    p_check_id,v_uid,p_from_method,p_to_method,p_amount,v_currency,v_receiver,p_receipt_url,lower(p_receipt_hash)
  );
  return jsonb_build_object('check_id',p_check_id,'status','uploading');
exception when unique_violation then
  raise exception using errcode='P0001',message='RECEIPT_PREFLIGHT_EXISTS';
end; $$;
revoke all on function public.ex_customer_receipt_preflight_start(uuid,text,text,numeric,text,text) from public,anon;
grant execute on function public.ex_customer_receipt_preflight_start(uuid,text,text,numeric,text,text) to authenticated;

create or replace function public.ex_customer_receipt_preflight_queue(p_check_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_row public.ex_customer_receipt_preflights%rowtype; v_key text; v_request_id bigint;
begin
  if v_uid is null then raise exception using errcode='42501',message='AUTH_REQUIRED'; end if;
  select * into v_row from public.ex_customer_receipt_preflights
   where id=p_check_id and user_id=v_uid and expires_at>now() and status in ('uploading','error') for update;
  if not found then raise exception using errcode='P0001',message='RECEIPT_PREFLIGHT_NOT_FOUND'; end if;
  if v_row.attempts>=3 then raise exception using errcode='P0001',message='RECEIPT_PREFLIGHT_RATE_LIMIT'; end if;
  select decrypted_secret into v_key from vault.decrypted_secrets where name='receipt_read_key' limit 1;
  if v_key is null then raise exception using errcode='P0001',message='RECEIPT_PREFLIGHT_KEY_MISSING'; end if;
  update public.ex_customer_receipt_preflights set status='queued',error_code=null,attempts=attempts+1,updated_at=now() where id=p_check_id;
  select net.http_post(url:='https://pycxuugoblkslvwebxuu.supabase.co/functions/v1/receipt-read',
    body:=jsonb_build_object('customer_preflight_id',p_check_id),
    headers:=jsonb_build_object('Content-Type','application/json','x-receipt-key',v_key),timeout_milliseconds:=10000)
    into v_request_id;
  if v_request_id is null then
    update public.ex_customer_receipt_preflights set status='error',error_code='queue_failed',updated_at=now() where id=p_check_id;
    raise exception using errcode='P0001',message='RECEIPT_PREFLIGHT_QUEUE_FAILED';
  end if;
  return jsonb_build_object('queued',true,'status','queued');
end; $$;
revoke all on function public.ex_customer_receipt_preflight_queue(uuid) from public,anon;
grant execute on function public.ex_customer_receipt_preflight_queue(uuid) to authenticated;

-- Gemini cannot decide the expected receiver or amount: this RPC compares its
-- extraction with values recorded from the authenticated request and ex_wallets.
create or replace function public.ex_customer_receipt_preflight_save(p_preflight_id uuid,p_result jsonb)
returns boolean language plpgsql security definer set search_path='' as $$
declare
  d public.ex_customer_receipt_preflights%rowtype; v_amount numeric; v_currency text;
  v_receiver text; v_expected text; v_amount_conf numeric; v_receiver_conf numeric;
  v_amount_matches boolean; v_receiver_matches boolean;
begin
  select * into d from public.ex_customer_receipt_preflights where id=p_preflight_id for update;
  if not found or d.status<>'processing' then return false; end if;
  v_amount:=nullif(p_result->>'actual_amount','')::numeric;
  v_currency:=upper(nullif(btrim(p_result->>'actual_currency'),''));
  v_receiver:=regexp_replace(coalesce(p_result->>'receiver_account',''),'[^0-9]','','g');
  v_expected:=regexp_replace(coalesce(d.expected_receiver_account,''),'[^0-9]','','g');
  -- Treat Iraqi domestic and +964 mobile notation as equivalent; do not otherwise
  -- truncate account/card numbers or accept a partial/masked match.
  if left(v_receiver,3)='964' and length(v_receiver)=13 then v_receiver:='0'||substr(v_receiver,4);
  elsif left(v_receiver,1)='7' and length(v_receiver)=10 then v_receiver:='0'||v_receiver; end if;
  if left(v_expected,3)='964' and length(v_expected)=13 then v_expected:='0'||substr(v_expected,4);
  elsif left(v_expected,1)='7' and length(v_expected)=10 then v_expected:='0'||v_expected; end if;
  v_amount_conf:=nullif(p_result->>'amount_confidence','')::numeric;
  v_receiver_conf:=nullif(p_result->>'receiver_account_confidence','')::numeric;
  if v_amount is null or v_amount<=0 or v_amount_conf is null or v_amount_conf<0.8
     or v_amount_conf>1 or v_receiver_conf is null or v_receiver_conf<0.8
     or v_receiver_conf>1 or length(v_receiver)<6 then
    return false;
  end if;
  v_amount_matches:=case when d.expected_currency='USDT'
    then abs(v_amount-d.expected_amount)<0.000001 else v_amount=d.expected_amount end;
  if v_currency is not null and v_currency not in (d.expected_currency,case when d.expected_currency='IQD' then 'د.ع' else 'USDT' end) then
    v_amount_matches:=false;
  end if;
  v_receiver_matches:=v_expected=v_receiver;
  update public.ex_customer_receipt_preflights set
    status='complete',error_code=null,is_receipt=(p_result->>'is_receipt')::boolean,
    success=nullif(p_result->>'success','')::boolean,actual_amount=v_amount,actual_currency=left(v_currency,8),
    amount_confidence=v_amount_conf,receiver_account=left(p_result->>'receiver_account',60),
    receiver_account_confidence=v_receiver_conf,wallet=left(p_result->>'wallet',60),
    reference=left(p_result->>'reference',120),paid_at=left(p_result->>'paid_at',60),
    sender_name=left(p_result->>'sender_name',120),sender_account=left(p_result->>'sender_account',60),
    receiver_name=left(p_result->>'receiver_name',120),status_text=left(p_result->>'status_text',120),
    notes=left(p_result->>'notes',400),amount_matches=v_amount_matches,receiver_matches=v_receiver_matches,
    model=left(p_result->>'model',60),updated_at=now()
   where id=p_preflight_id;
  return true;
end; $$;
revoke all on function public.ex_customer_receipt_preflight_save(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.ex_customer_receipt_preflight_save(uuid,jsonb) to service_role;

create or replace function public.ex_customer_receipt_preflight_result(p_check_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_row public.ex_customer_receipt_preflights%rowtype;
begin
  if auth.uid() is null then raise exception using errcode='42501',message='AUTH_REQUIRED'; end if;
  select * into v_row from public.ex_customer_receipt_preflights where id=p_check_id and user_id=auth.uid();
  if not found then return jsonb_build_object('status','not_found'); end if;
  return jsonb_build_object(
    'status',case when v_row.expires_at<=now() and v_row.linked_order_id is null then 'expired' else v_row.status end,
    'error_code',v_row.error_code,'is_receipt',v_row.is_receipt,
    'amount_matches',v_row.amount_matches,'receiver_matches',v_row.receiver_matches,
    'amount_confidence',v_row.amount_confidence,'receiver_confidence',v_row.receiver_account_confidence
  );
end; $$;
revoke all on function public.ex_customer_receipt_preflight_result(uuid) from public,anon;
grant execute on function public.ex_customer_receipt_preflight_result(uuid) to authenticated;

-- Called only from /api/orders with the service-role credential after its normal validation.
-- The pass is one-use and is tied to the authenticated owner and the exact submitted fields.
create or replace function public.ex_customer_receipt_preflight_claim(
  p_check_id uuid,p_user_id uuid,p_from_method text,p_to_method text,p_amount numeric,
  p_receipt_url text,p_receipt_hash text
) returns boolean language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
  update public.ex_customer_receipt_preflights d set claimed_at=now(),updated_at=now()
   where d.id=p_check_id and d.user_id=p_user_id and d.from_method=p_from_method and d.to_method=p_to_method
     and d.expected_amount=p_amount and d.receipt_url=p_receipt_url and d.receipt_hash=lower(p_receipt_hash)
     and d.status='complete' and d.is_receipt=true and d.amount_matches=true and d.receiver_matches=true
     and d.claimed_at is null and d.linked_order_id is null and d.expires_at>now()
   returning d.id into v_id;
  if v_id is null then raise exception using errcode='P0001',message='RECEIPT_PREFLIGHT_REQUIRED'; end if;
  return true;
end; $$;
revoke all on function public.ex_customer_receipt_preflight_claim(uuid,uuid,text,text,numeric,text,text) from public,anon,authenticated;
grant execute on function public.ex_customer_receipt_preflight_claim(uuid,uuid,text,text,numeric,text,text) to service_role;

-- A preflight is promoted to the same admin-facing receipt table only when the matching order
-- is inserted. This preserves the current admin read UI and avoids a second Gemini request.
create or replace function public.ex_customer_receipt_preflight_promote(p_order_id uuid,p_check_id uuid)
returns boolean language plpgsql security definer set search_path='' as $$
declare
  o public.ex_orders%rowtype; d public.ex_customer_receipt_preflights%rowtype; v_ref_norm text; v_duplicate uuid; v_amount_matches boolean;
begin
  select * into o from public.ex_orders where id=p_order_id;
  if not found then return false; end if;
  select * into d from public.ex_customer_receipt_preflights where id=p_check_id for update;
  if not found or d.status<>'complete' or d.is_receipt is distinct from true
     or d.amount_matches is distinct from true or d.receiver_matches is distinct from true
     or d.claimed_at is null or d.linked_order_id is not null or d.user_id<>o.user_id
     or d.from_method<>o.from_method or d.to_method<>o.to_method or d.expected_amount<>o.amount
     or d.receipt_url is distinct from o.receipt_url or d.receipt_hash is distinct from o.receipt_hash then return false; end if;
  v_amount_matches:=case when o.from_method='USDT' then abs(d.actual_amount-o.amount)<0.000001 else d.actual_amount=o.amount end;
  v_ref_norm:=nullif(upper(regexp_replace(coalesce(d.reference,''),'[^0-9A-Za-z]','','g')),'');
  if length(coalesce(v_ref_norm,''))<6 then v_ref_norm:=null; end if;
  if v_ref_norm is not null then
    select rr.order_id into v_duplicate from public.ex_receipt_reads rr join public.ex_orders prior on prior.id=rr.order_id
     where rr.reference_norm=v_ref_norm and rr.order_id<>o.id
       and (prior.status<>'ڕەتکرا' or prior.user_id<>o.user_id) order by prior.created_at limit 1;
  end if;
  insert into public.ex_receipt_reads(
    order_id,status,is_receipt,wallet,success,status_text,amount,currency,reference,reference_norm,paid_at,
    sender_name,sender_account,receiver_name,receiver_account,notes,amount_matches,duplicate_order_id,model,error,attempts,read_at
  ) values (
    o.id,'ok',true,nullif(left(d.wallet,60),''),d.success,nullif(left(d.status_text,120),''),d.actual_amount,
    nullif(left(upper(d.actual_currency),8),''),nullif(left(btrim(d.reference),120),''),v_ref_norm,nullif(left(d.paid_at,60),''),
    nullif(left(d.sender_name,120),''),nullif(left(d.sender_account,60),''),nullif(left(d.receiver_name,120),''),
    nullif(left(d.receiver_account,60),''),nullif(left(d.notes,400),''),v_amount_matches,v_duplicate,nullif(left(d.model,60),''),null,1,now()
  ) on conflict(order_id) do update set status=excluded.status,is_receipt=excluded.is_receipt,wallet=excluded.wallet,
    success=excluded.success,status_text=excluded.status_text,amount=excluded.amount,currency=excluded.currency,
    reference=excluded.reference,reference_norm=excluded.reference_norm,paid_at=excluded.paid_at,sender_name=excluded.sender_name,
    sender_account=excluded.sender_account,receiver_name=excluded.receiver_name,receiver_account=excluded.receiver_account,
    notes=excluded.notes,amount_matches=excluded.amount_matches,duplicate_order_id=excluded.duplicate_order_id,
    model=excluded.model,error=null,attempts=ex_receipt_reads.attempts+1,read_at=now();
  update public.ex_customer_receipt_preflights set linked_order_id=o.id,updated_at=now() where id=d.id;
  return true;
end; $$;
revoke all on function public.ex_customer_receipt_preflight_promote(uuid,uuid) from public,anon,authenticated;
grant execute on function public.ex_customer_receipt_preflight_promote(uuid,uuid) to service_role;

-- Existing receipts (including legacy clients and rejected-order retries) keep their current
-- best-effort reader. New receipt submissions attach a claimed preflight and reuse its result.
create or replace function public.ex_orders_queue_receipt_read()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if tg_op='INSERT' and new.receipt_url is not null and new.receipt_preflight_id is not null then
    if not public.ex_customer_receipt_preflight_promote(new.id,new.receipt_preflight_id) then
      raise exception using errcode='P0001',message='RECEIPT_PREFLIGHT_REQUIRED';
    end if;
    return null;
  end if;
  if new.receipt_url is not null and (tg_op='INSERT' or new.receipt_url is distinct from old.receipt_url) then
    perform public.ex_receipt_read_queue(new.id);
  end if;
  return null;
exception when others then
  if sqlstate='P0001' and sqlerrm='RECEIPT_PREFLIGHT_REQUIRED' then raise; end if;
  return null;
end; $$;
revoke all on function public.ex_orders_queue_receipt_read() from public,anon,authenticated;
drop trigger if exists trg_ex_orders_zz_receipt_read on public.ex_orders;
create trigger trg_ex_orders_zz_receipt_read after insert or update of receipt_url on public.ex_orders
  for each row execute function public.ex_orders_queue_receipt_read();
