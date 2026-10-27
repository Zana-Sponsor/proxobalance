-- Depends on the secure financial baseline and immutable ad isolation. This
-- journals only legacy FastPay creation; all credits/refunds retain their
-- existing, verified financial authority. Deploy with the matching n8n patch.
begin;

do $$begin
 if to_regprocedure('app_finance.fastpay_create_order_legacy(uuid,text,numeric,text,text,text,integer,text)') is null
  or to_regprocedure('app_finance.fastpay_mark_paid_legacy(text,text,numeric,text,text,jsonb)') is null then
  raise exception 'LEGACY_FASTPAY_BASELINE_REQUIRED';
 end if;
end $$;

create table app_finance.legacy_fastpay_checkouts (
 transaction_id uuid primary key references public.pa_transactions(id),
 order_id text not null unique,
 user_id uuid not null references auth.users(id),
 request jsonb not null,
 request_hash text not null check(request_hash ~ '^[0-9a-f]{64}$'),
 creation_started_at timestamptz not null default now(),
 next_check_at timestamptz not null default now(),
 last_checked_at timestamptz,
 last_error_code text,
 last_observed_status text
);
create index legacy_fastpay_checkouts_due on app_finance.legacy_fastpay_checkouts(next_check_at,transaction_id);
alter table app_finance.legacy_fastpay_checkouts enable row level security;
revoke all on app_finance.legacy_fastpay_checkouts from public,anon,authenticated,service_role;

create function app_finance.protect_legacy_fastpay_intent() returns trigger
language plpgsql set search_path='' as $$begin
 if tg_op='DELETE' then raise exception 'LEGACY_FASTPAY_INTENT_IMMUTABLE';end if;
 if row(new.transaction_id,new.order_id,new.user_id,new.request,new.request_hash,new.creation_started_at)
  is distinct from row(old.transaction_id,old.order_id,old.user_id,old.request,old.request_hash,old.creation_started_at)
 then raise exception 'LEGACY_FASTPAY_INTENT_IMMUTABLE';end if;
 return new;
end $$;
create trigger legacy_fastpay_intent_immutable before update or delete on app_finance.legacy_fastpay_checkouts
 for each row execute function app_finance.protect_legacy_fastpay_intent();

create function app_finance.protect_legacy_fastpay_receipt() returns trigger
language plpgsql security definer set search_path='' as $$begin
 if not exists(select 1 from app_finance.legacy_fastpay_checkouts where transaction_id=old.id) then
  if tg_op='DELETE' then return old;end if;return new;
 end if;
 if tg_op='DELETE' then raise exception 'LEGACY_FASTPAY_RECEIPT_IMMUTABLE';end if;
 if row(new.id,new.user_id,new.amount,new.gateway_amount,new.fx_rate,new.currency,new.gateway,new.method,new.kind,new.type,new.fastpay_order_id,new.expires_at,new.expires_in,new.note)
  is distinct from row(old.id,old.user_id,old.amount,old.gateway_amount,old.fx_rate,old.currency,old.gateway,old.method,old.kind,old.type,old.fastpay_order_id,old.expires_at,old.expires_in,old.note)
  or (old.qr_url is not null and new.qr_url is distinct from old.qr_url)
  or (old.qr_text is not null and new.qr_text is distinct from old.qr_text)
 then raise exception 'LEGACY_FASTPAY_RECEIPT_IMMUTABLE';end if;
 return new;
end $$;
create trigger legacy_fastpay_receipt_immutable before update or delete on public.pa_transactions
 for each row execute function app_finance.protect_legacy_fastpay_receipt();

create function app_finance.legacy_fastpay_result(t public.pa_transactions,j app_finance.legacy_fastpay_checkouts)
returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('ok',true,'create_authorized',false,'must_reconcile',not coalesce(t.wallet_credited,false),
  'transaction_id',t.id,'user_id',t.user_id,'order_id',t.fastpay_order_id,'amount',t.amount,'amount_usd',t.amount,
  'amount_iqd',t.gateway_amount,'bill_amount',t.gateway_amount,'fx_rate',t.fx_rate,'currency',t.currency,
  'status',t.status,'gateway_status',t.gateway_status,'expires_at',t.expires_at,'wallet_credited',t.wallet_credited,
  'qr_url',case when t.status='pending' and t.gateway_status='CREATED' and t.expires_at>now() and j.last_observed_status is null then t.qr_url end,
  'qr_text',case when t.status='pending' and t.gateway_status='CREATED' and t.expires_at>now() and j.last_observed_status is null then t.qr_text end,
  'request_hash',j.request_hash,'creation_started_at',j.creation_started_at,
  'journaled',j.transaction_id is not null,'environment',j.request->>'environment','merchant_reference',j.request->>'merchant_reference');
$$;

-- All old create calls take the same order lock. They cannot refresh a
-- journaled receipt, even through an older checkout execution still retrying.
create or replace function app_finance.fastpay_create_order(p_user_id uuid,p_order_id text,p_amount numeric,p_currency text,p_qr_url text,p_qr_text text,p_expires_in integer,p_note text)
returns jsonb language plpgsql security definer set search_path='' as $$begin
 if app_finance.legacy_fastpay_guard(p_order_id,null)->>'legacy_allowed'<>'true' then
  return jsonb_build_object('ok',false,'code','AD_PAYMENT_ATTEMPT_REQUIRED');end if;
 perform pg_advisory_xact_lock(hashtextextended('legacy-fastpay:'||p_order_id,0));
 if exists(select 1 from app_finance.legacy_fastpay_checkouts where order_id=p_order_id) then
  return jsonb_build_object('ok',false,'code','DURABLE_CHECKOUT_REQUIRED');end if;
 return app_finance.fastpay_create_order_legacy(p_user_id,p_order_id,p_amount,p_currency,p_qr_url,p_qr_text,p_expires_in,p_note);
end $$;

create function app_finance.legacy_fastpay_checkout(p_action text,p_user_id uuid,p_order_id text,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare t public.pa_transactions%rowtype;j app_finance.legacy_fastpay_checkouts%rowtype;
 req jsonb;res jsonb;amount_iqd numeric;minutes integer;request_hash text;url text;qr text;
begin
 if p_user_id is null or app_finance.legacy_fastpay_guard(p_order_id,null)->>'legacy_allowed'<>'true' then
  return jsonb_build_object('ok',false,'code','INVALID_ORDER');end if;
 if p_action not in ('prepare','read','qr_created','unknown') or p_action is null then
  return jsonb_build_object('ok',false,'code','INVALID_ACTION');end if;
 if jsonb_typeof(p_payload) is distinct from 'object' then return jsonb_build_object('ok',false,'code','INVALID_REQUEST');end if;
 perform pg_advisory_xact_lock(hashtextextended('legacy-fastpay:'||p_order_id,0));
 select * into t from public.pa_transactions where fastpay_order_id=p_order_id for update;
 if found and (t.user_id is distinct from p_user_id or t.gateway is distinct from 'fastpay') then
  return jsonb_build_object('ok',false,'code','ORDER_NOT_FOUND');end if;
 select * into j from app_finance.legacy_fastpay_checkouts where order_id=p_order_id;
 if p_action='prepare' then
  -- Persist an allowlist, never credentials or arbitrary gateway payloads.
  if exists(select 1 from jsonb_object_keys(p_payload) k where k not in
   ('amount_iqd','currency','environment','merchant_reference','expires_in','success_url','cancel_url','callback_url','purpose','note'))
   or jsonb_typeof(p_payload->'amount_iqd') is distinct from 'number'
   or coalesce(p_payload->>'amount_iqd','') !~ '^[0-9]+$'
   or p_payload->>'currency' is distinct from 'IQD'
   or coalesce(p_payload->>'environment','') not in ('sandbox','production')
   or length(coalesce(p_payload->>'merchant_reference','')) not between 1 and 200
   or coalesce(p_payload->>'expires_in','') !~ '^[0-9]+$'
   or length(coalesce(p_payload->>'note',''))>1000
   or length(coalesce(p_payload->>'purpose','')) not between 1 and 50
   or exists(select 1 from (values(p_payload->>'success_url'),(p_payload->>'cancel_url'),(p_payload->>'callback_url')) v(url)
     where coalesce(v.url,'') !~ '^https://[^[:space:]]+$' or length(v.url)>2000)
  then return jsonb_build_object('ok',false,'code','INVALID_REQUEST');end if;
  amount_iqd:=(p_payload->>'amount_iqd')::numeric;
  if amount_iqd<=0 or amount_iqd>9007199254740991 or length(p_payload->>'expires_in')>3 then
   return jsonb_build_object('ok',false,'code','INVALID_REQUEST');end if;
  minutes:=(p_payload->>'expires_in')::integer;
  if minutes not between 1 and 60 then return jsonb_build_object('ok',false,'code','INVALID_REQUEST');end if;
  req:=p_payload||jsonb_build_object('amount_iqd',amount_iqd,'expires_in',minutes,'note',coalesce(p_payload->>'note',''));
  request_hash:=encode(sha256(convert_to(jsonb_build_object('user_id',p_user_id,'order_id',p_order_id,'request',req)::text,'UTF8')),'hex');
  if j.transaction_id is not null and (j.user_id is distinct from p_user_id or j.request_hash is distinct from request_hash or j.request is distinct from req) then
   return jsonb_build_object('ok',false,'code','IDEMPOTENCY_CONFLICT');end if;
  if t.id is not null then
   if t.gateway_amount is distinct from amount_iqd or t.currency is distinct from 'IQD' then
    return jsonb_build_object('ok',false,'code','IDEMPOTENCY_CONFLICT');end if;
   -- A historical row without a journal might already have a dispatched QR.
   -- Never adopt it as a new creation authorization or refresh its money/FX.
   return app_finance.legacy_fastpay_result(t,j);
  end if;
  res:=app_finance.fastpay_create_order_legacy(p_user_id,p_order_id,amount_iqd,'IQD',null,null,minutes,req->>'note');
  if res->>'ok' is distinct from 'true' then return res;end if;
  select * into t from public.pa_transactions where fastpay_order_id=p_order_id for update;
  if t.id is null or t.user_id is distinct from p_user_id or t.gateway_amount is distinct from amount_iqd
   or t.currency is distinct from 'IQD' or t.gateway is distinct from 'fastpay' or t.status is distinct from 'pending'
   or t.gateway_status is distinct from 'CREATED' or coalesce(t.wallet_credited,false)
   or t.gw_transaction_id is not null or t.qr_url is not null or t.qr_text is not null
   or t.amount is null or t.amount<=0 or t.amount::text in ('NaN','Infinity','-Infinity')
   or t.fx_rate is null or t.fx_rate<=0 or t.fx_rate::text in ('NaN','Infinity','-Infinity')
   or t.expires_at is null or t.expires_at<=now()
  then raise exception 'INVALID_LEGACY_FASTPAY_RECEIPT';end if;
  insert into app_finance.legacy_fastpay_checkouts(transaction_id,order_id,user_id,request,request_hash)
   values(t.id,p_order_id,p_user_id,req,request_hash) returning * into j;
  return app_finance.legacy_fastpay_result(t,j)||jsonb_build_object('create_authorized',true,'must_reconcile',false);
 end if;
 if t.id is null then return jsonb_build_object('ok',false,'code','ORDER_NOT_FOUND');end if;
 if p_action='read' then return app_finance.legacy_fastpay_result(t,j);end if;
 if j.transaction_id is null or j.request_hash is distinct from p_payload->>'request_hash' then
  return jsonb_build_object('ok',false,'code','CREATION_INTENT_REQUIRED');end if;
 if p_action='unknown' then
  update app_finance.legacy_fastpay_checkouts set last_error_code=left(regexp_replace(coalesce(p_payload->>'error_code','GATEWAY_OUTCOME_UNKNOWN'),'[^A-Z0-9_]','','g'),100)
   where transaction_id=t.id;
  return app_finance.legacy_fastpay_result(t,j);
 end if;
 url:=nullif(p_payload->>'qr_url','');qr:=nullif(p_payload->>'qr_text','');
 if (url is null and qr is null) or (url is not null and (url !~ '^https://[^[:space:]]+$' or length(url)>8192)) or length(qr)>16384 then
  return jsonb_build_object('ok',false,'code','INVALID_GATEWAY_QR');end if;
 if (t.qr_url is not null and t.qr_url is distinct from url) or (t.qr_text is not null and t.qr_text is distinct from qr) then
  return jsonb_build_object('ok',false,'code','GATEWAY_QR_CONFLICT');end if;
 if not coalesce(t.wallet_credited,false) and t.gateway_status='CREATED' and t.status='pending' then
  update public.pa_transactions set qr_url=url,qr_text=qr,updated_at=now() where id=t.id returning * into t;
 end if;
 return app_finance.legacy_fastpay_result(t,j);
end $$;
create function public.pa_legacy_fastpay_checkout(p_action text,p_user_id uuid,p_order_id text,p_payload jsonb default '{}')
returns jsonb language sql security invoker set search_path='' as $$select app_finance.legacy_fastpay_checkout(p_action,p_user_id,p_order_id,p_payload);$$;

-- QR display expiry is not proof that a dispatched payment can never settle.
create or replace function app_finance.fastpay_expire_stale_orders(p_grace_minutes integer) returns jsonb
language plpgsql security definer set search_path='' as $$declare changed integer;begin
 update public.pa_transactions t set gateway_status='EXPIRED',status='rejected',fail_reason=coalesce(fail_reason,'Expired before payment')
 where gateway='fastpay' and gateway_status='CREATED' and wallet_credited=false
  and coalesce(expires_at,created_at+(coalesce(expires_in,10)*interval '1 minute'))+(coalesce(p_grace_minutes,2)*interval '1 minute')<now()
  and app_finance.legacy_fastpay_guard(fastpay_order_id,id)->>'legacy_allowed'='true'
  and not exists(select 1 from app_finance.legacy_fastpay_checkouts j where j.transaction_id=t.id);
 get diagnostics changed=row_count;return jsonb_build_object('ok',true,'expired',changed);
end $$;

-- Existing n8n polling already uses POST. Claiming advances the journal's due
-- time so unresolved old orders cannot permanently starve newer checkouts.
create or replace function app_finance.fastpay_orders_to_poll(p_limit integer,p_grace_minutes integer)
returns table(id uuid,user_id uuid,fastpay_order_id text,amount numeric,gateway_amount numeric,currency text,created_at timestamptz,expires_at timestamptz)
language plpgsql volatile security definer set search_path='' as $$declare t record;begin
 for t in select tx.* from public.pa_transactions tx left join app_finance.legacy_fastpay_checkouts j on j.transaction_id=tx.id
  where tx.gateway='fastpay' and tx.wallet_credited=false
   and app_finance.legacy_fastpay_guard(tx.fastpay_order_id,tx.id)->>'legacy_allowed'='true'
   and ((j.transaction_id is null and tx.gateway_status='CREATED' and now()<coalesce(tx.expires_at,tx.created_at+(coalesce(tx.expires_in,10)*interval '1 minute'))+(coalesce(p_grace_minutes,2)*interval '1 minute'))
     or (j.transaction_id is not null and tx.status='pending' and tx.gateway_status in ('CREATED','DECLINED') and j.next_check_at<=now()))
  order by coalesce(j.next_check_at,tx.created_at),tx.id limit least(greatest(coalesce(p_limit,50),1),100)
  for update of tx skip locked
 loop
  update app_finance.legacy_fastpay_checkouts set next_check_at=now()+interval '2 minutes',last_checked_at=now() where transaction_id=t.id;
  id:=t.id;user_id:=t.user_id;fastpay_order_id:=t.fastpay_order_id;amount:=t.amount;gateway_amount:=t.gateway_amount;
  currency:=t.currency;created_at:=t.created_at;expires_at:=coalesce(t.expires_at,t.created_at+(coalesce(t.expires_in,10)*interval '1 minute'));return next;
 end loop;
end $$;
create or replace function public.fastpay_orders_to_poll(p_limit integer default 50,p_grace_minutes integer default 2)
returns table(id uuid,user_id uuid,fastpay_order_id text,amount numeric,gateway_amount numeric,currency text,created_at timestamptz,expires_at timestamptz)
language sql volatile security invoker set search_path='' as $$select * from app_finance.fastpay_orders_to_poll(p_limit,p_grace_minutes);$$;

-- Preserve the installed legacy decline implementation for historical rows.
-- A status observation on a journaled dispatch is not irreversible finality.
do $decline$ begin
 if to_regprocedure('public.fastpay_mark_declined(text,text,jsonb)') is not null then
  alter function public.fastpay_mark_declined(text,text,jsonb) set schema app_finance;
  alter function app_finance.fastpay_mark_declined(text,text,jsonb) rename to fastpay_mark_declined_before_journal;
  revoke all on function app_finance.fastpay_mark_declined_before_journal(text,text,jsonb) from public,anon,authenticated,service_role;
  execute $fn$create function app_finance.fastpay_mark_declined(p_order_id text,p_gateway_status text,p_payload jsonb)
  returns jsonb language plpgsql security definer set search_path='' as $body$
  declare t public.pa_transactions%rowtype;begin
   if app_finance.legacy_fastpay_guard(p_order_id,null)->>'legacy_allowed'<>'true' then return jsonb_build_object('ok',false,'code','AD_PAYMENT_VERIFICATION_REQUIRED');end if;
   select * into t from public.pa_transactions where fastpay_order_id=p_order_id for update;
   if exists(select 1 from app_finance.legacy_fastpay_checkouts where transaction_id=t.id) then
    update app_finance.legacy_fastpay_checkouts set last_observed_status=left(coalesce(p_gateway_status,'DECLINED'),100) where transaction_id=t.id;
    -- Mobile also reads the original receipt directly. Publish the observation
    -- there to hide QR, while pending retains strict late-settlement authority.
    if not coalesce(t.wallet_credited,false) and t.status='pending' and t.gateway_status in ('CREATED','DECLINED') then
     update public.pa_transactions set gateway_status='DECLINED',updated_at=now() where id=t.id returning * into t;
    end if;
    return jsonb_build_object('ok',true,'code','RECONCILIATION_REQUIRED','transaction_id',t.id,'gateway_status',t.gateway_status,'status',t.status,'must_reconcile',not coalesce(t.wallet_credited,false));
   end if;
   return app_finance.fastpay_mark_declined_before_journal(p_order_id,p_gateway_status,p_payload);
  end $body$$fn$;
  execute $fn$create function public.fastpay_mark_declined(p_order_id text,p_gateway_status text default null,p_payload jsonb default null)
   returns jsonb language sql security invoker set search_path='' as $body$select app_finance.fastpay_mark_declined(p_order_id,p_gateway_status,p_payload);$body$$fn$;
  revoke all on function app_finance.fastpay_mark_declined(text,text,jsonb),public.fastpay_mark_declined(text,text,jsonb) from public,anon,authenticated;
  grant execute on function app_finance.fastpay_mark_declined(text,text,jsonb),public.fastpay_mark_declined(text,text,jsonb) to service_role;
 end if;
end $decline$;

-- Verification failures remain observations/manual fraud holds, with the
-- installed behavior intact. They must not be a public receipt mutation RPC.
do $failure$ begin
 if to_regprocedure('public.fastpay_mark_check_failed(text,text,boolean,jsonb)') is not null then
  alter function public.fastpay_mark_check_failed(text,text,boolean,jsonb) set schema app_finance;
  alter function app_finance.fastpay_mark_check_failed(text,text,boolean,jsonb) rename to fastpay_mark_check_failed_before_journal;
  revoke all on function app_finance.fastpay_mark_check_failed_before_journal(text,text,boolean,jsonb) from public,anon,authenticated,service_role;
  execute $fn$create function app_finance.fastpay_mark_check_failed(p_order_id text,p_reason text,p_retryable boolean,p_payload jsonb)
  returns jsonb language plpgsql security definer set search_path='' as $body$begin
   if app_finance.legacy_fastpay_guard(p_order_id,null)->>'legacy_allowed'<>'true' then return jsonb_build_object('ok',false,'code','AD_PAYMENT_VERIFICATION_REQUIRED');end if;
   return app_finance.fastpay_mark_check_failed_before_journal(p_order_id,p_reason,p_retryable,p_payload);
  end $body$$fn$;
  execute $fn$create function public.fastpay_mark_check_failed(p_order_id text,p_reason text,p_retryable boolean default true,p_payload jsonb default null)
   returns jsonb language sql security invoker set search_path='' as $body$select app_finance.fastpay_mark_check_failed(p_order_id,p_reason,p_retryable,p_payload);$body$$fn$;
  revoke all on function app_finance.fastpay_mark_check_failed(text,text,boolean,jsonb),public.fastpay_mark_check_failed(text,text,boolean,jsonb) from public,anon,authenticated;
  grant execute on function app_finance.fastpay_mark_check_failed(text,text,boolean,jsonb),public.fastpay_mark_check_failed(text,text,boolean,jsonb) to service_role;
 end if;
end $failure$;

revoke all on function app_finance.protect_legacy_fastpay_intent(),app_finance.protect_legacy_fastpay_receipt(),
 app_finance.legacy_fastpay_result(public.pa_transactions,app_finance.legacy_fastpay_checkouts),
 app_finance.legacy_fastpay_checkout(text,uuid,text,jsonb),public.pa_legacy_fastpay_checkout(text,uuid,text,jsonb) from public,anon,authenticated,service_role;
grant execute on function app_finance.legacy_fastpay_checkout(text,uuid,text,jsonb),public.pa_legacy_fastpay_checkout(text,uuid,text,jsonb) to service_role;
commit;
