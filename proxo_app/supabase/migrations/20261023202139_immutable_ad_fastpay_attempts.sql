-- An ad checkout is authorized while its quote/session is valid. A later
-- verified gateway receipt completes that SAME authorization without the app.
-- No gateway request is made in SQL. Deployment and merchant gates default OFF.
begin;
create table app_finance.ad_payment_settings(
 singleton boolean primary key default true check(singleton), enabled boolean not null default false,
 environment text not null default 'sandbox' check(environment in ('sandbox','production')),
 merchant_reference text, updated_at timestamptz not null default now(),
 check(not enabled or nullif(btrim(merchant_reference),'') is not null));
insert into app_finance.ad_payment_settings(singleton) values(true);
create table app_finance.ad_payment_attempts(
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id),
 submission_id uuid not null, platform text not null check(platform in ('META','TIKTOK')),
 meta_quote_id uuid references app_meta.quotes(id),tiktok_quote_id uuid references app_tiktok_dm.quotes(id),
 order_id text not null unique, payment_transaction_id uuid not null unique references public.pa_transactions(id),
 environment text not null check(environment in ('sandbox','production')),merchant_reference text not null,
 configuration jsonb not null,pricing jsonb not null,evidence jsonb not null,
 cost_usd numeric(20,6) not null check(cost_usd>0 and cost_usd::text not in ('NaN','Infinity','-Infinity')),
 amount_iqd bigint not null check(amount_iqd>=1000),fx_rate numeric(20,6) not null check(fx_rate>0),
 promo_id uuid,promo_code text,promo_reservation_id uuid,
 status text not null default 'prepared' check(status in ('prepared','creating','awaiting','reconcile','expired','declined','cancelled','funded','compensated')),
 creation_hash text check(creation_hash ~ '^[a-f0-9]{64}$'),creation_started_at timestamptz,
 cancel_requested_at timestamptz,ad_id uuid unique references public.pa_ads(id),result jsonb,
 gateway_transaction_id text,verified_at timestamptz,last_error_code text,
 lease_token uuid,lease_until timestamptz,next_check_at timestamptz not null default now(),
 created_at timestamptz not null default now(),expires_at timestamptz not null default(now()+interval '10 minutes'),
 unique(user_id,submission_id),unique(meta_quote_id),unique(tiktok_quote_id),
 check((platform='META' and meta_quote_id is not null and tiktok_quote_id is null)
    or (platform='TIKTOK' and tiktok_quote_id is not null and meta_quote_id is null)));
create index ad_payment_reconcile_due on app_finance.ad_payment_attempts(next_check_at) where status not in ('funded','compensated');
create table app_finance.ad_payment_verifications(
 id uuid primary key default gen_random_uuid(),attempt_id uuid not null references app_finance.ad_payment_attempts(id),
 status text not null, gateway_transaction_id text, amount_iqd bigint not null,currency text not null check(currency='IQD'),
 verified_at timestamptz not null,response_sha256 text not null check(response_sha256 ~ '^[a-f0-9]{64}$'),
 verification_source text not null check(verification_source in ('FASTPAY_VALIDATE','FASTPAY_STATUS')),created_at timestamptz not null default now(),
 unique(attempt_id,response_sha256));
create trigger ad_payment_verification_immutable before update or delete on app_finance.ad_payment_verifications
 for each row execute function app_finance.immutable_ledger();
create function app_finance.protect_ad_payment_attempt() returns trigger language plpgsql set search_path='' as $$
begin
 if (to_jsonb(new)-array['status','creation_hash','creation_started_at','cancel_requested_at','ad_id','result','gateway_transaction_id','verified_at','last_error_code','lease_token','lease_until','next_check_at'])
  is distinct from (to_jsonb(old)-array['status','creation_hash','creation_started_at','cancel_requested_at','ad_id','result','gateway_transaction_id','verified_at','last_error_code','lease_token','lease_until','next_check_at'])
  or (old.creation_hash is not null and new.creation_hash is distinct from old.creation_hash)
  or (old.ad_id is not null and new.ad_id is distinct from old.ad_id)
  or (old.gateway_transaction_id is not null and new.gateway_transaction_id is distinct from old.gateway_transaction_id) then
  raise exception 'AD_PAYMENT_ATTEMPT_IMMUTABLE';end if;return new;
end $$;
create trigger ad_payment_attempt_immutable before update on app_finance.ad_payment_attempts for each row execute function app_finance.protect_ad_payment_attempt();
create function app_finance.protect_ad_payment_transaction() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from app_finance.ad_payment_attempts where payment_transaction_id=old.id) and
  (new.user_id is distinct from old.user_id or new.amount is distinct from old.amount or new.gateway_amount is distinct from old.gateway_amount
   or new.fx_rate is distinct from old.fx_rate or new.currency is distinct from old.currency or new.fastpay_order_id is distinct from old.fastpay_order_id
   or new.gateway is distinct from old.gateway or new.method is distinct from old.method or new.type is distinct from old.type
   or new.meta_quote_id is distinct from old.meta_quote_id or new.tiktok_quote_id is distinct from old.tiktok_quote_id
   or (old.ad_id is not null and new.ad_id is distinct from old.ad_id)) then raise exception 'AD_PAYMENT_BINDING_IMMUTABLE';end if;return new;
end $$;
create trigger ad_payment_transaction_binding before update on public.pa_transactions for each row execute function app_finance.protect_ad_payment_transaction();
create function app_finance.ad_payment_result(a app_finance.ad_payment_attempts) returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('ok',true,'attempt_id',a.id,'order_id',a.order_id,'transaction_id',a.payment_transaction_id,
 'environment',a.environment,'currency','IQD','amount_iqd',a.amount_iqd,'cost_usd',a.cost_usd,'fx_rate',a.fx_rate,
 'status',a.status,'expires_at',a.expires_at,'result',a.result,'ad_id',a.ad_id,'cancel_requested',a.cancel_requested_at is not null,
 'qr_url',case when a.cancel_requested_at is null and a.status not in ('declined','cancelled','expired','funded','compensated') and a.expires_at>now() then t.qr_url end,
 'qr_text',case when a.cancel_requested_at is null and a.status not in ('declined','cancelled','expired','funded','compensated') and a.expires_at>now() then t.qr_text end)
 from public.pa_transactions t where t.id=a.payment_transaction_id;
$$;
create function app_finance.ad_payment_attempt(p_submission_id uuid,p_platform text,p_quote_id uuid,p_expected_cost_usd numeric,p_expected_amount_iqd bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=app_finance.actor();a app_finance.ad_payment_attempts%rowtype;s app_finance.ad_payment_settings%rowtype;
 mq app_meta.quotes%rowtype;tq app_tiktok_dm.quotes%rowtype;c jsonb;price jsonb;e jsonb;cost numeric;rate numeric;iqd bigint;
 tx uuid:=gen_random_uuid();aid uuid:=gen_random_uuid();oid text;promo public.promo_codes%rowtype;reservation uuid;preview jsonb;
begin
 if p_submission_id is null or p_quote_id is null or p_platform not in ('META','TIKTOK') or p_expected_cost_usd is null or p_expected_amount_iqd is null then
  return jsonb_build_object('ok',false,'code','INVALID_INPUT');end if;
 perform pg_advisory_xact_lock(hashtextextended(u::text||':'||p_submission_id::text,0));
 select * into a from app_finance.ad_payment_attempts where user_id=u and submission_id=p_submission_id for update;
 if found then
  if a.platform is distinct from p_platform or coalesce(a.meta_quote_id,a.tiktok_quote_id) is distinct from p_quote_id
   or a.cost_usd is distinct from p_expected_cost_usd or a.amount_iqd is distinct from p_expected_amount_iqd then return jsonb_build_object('ok',false,'code','IDEMPOTENCY_CONFLICT');end if;
  return app_finance.ad_payment_result(a);end if;
 if exists(select 1 from proxo_private.ad_submissions where user_id=u and submission_id=p_submission_id) then return jsonb_build_object('ok',false,'code','SUBMISSION_ALREADY_COMMITTED');end if;
 select * into s from app_finance.ad_payment_settings where singleton;
 if not s.enabled then return jsonb_build_object('ok',false,'code','AD_FASTPAY_UNAVAILABLE');end if;
 if not app_finance.rate_allowed(u,'ad_payment_attempt',10) then return jsonb_build_object('ok',false,'code','RATE_LIMITED');end if;
 perform public.pa_assert_ad_allowed(u);
 if p_platform='META' then
  if not app_meta.allowed(u) or not(select fastpay_enabled from app_meta.settings where singleton) then return jsonb_build_object('ok',false,'code','META_FASTPAY_UNAVAILABLE');end if;
  select * into mq from app_meta.quotes where id=p_quote_id and user_id=u for update;
  if not found then return jsonb_build_object('ok',false,'code','QUOTE_NOT_FOUND');end if;
  if mq.expires_at<=now() then return jsonb_build_object('ok',false,'code','QUOTE_EXPIRED');end if;
  if mq.configuration->>'payment_method'<>'FASTPAY' or not app_meta.valid_configuration(mq.configuration) then return jsonb_build_object('ok',false,'code','QUOTE_CHANGED');end if;
  if not exists(select 1 from app_meta.connections where id=mq.connection_id and user_id=u and status='authorized' and expires_at>now()) then return jsonb_build_object('ok',false,'code','CONNECTION_EXPIRED');end if;
  c:=mq.configuration;price:=mq.pricing;e:=mq.evidence;cost:=mq.payable_minor::numeric/100;rate:=mq.rate;iqd:=mq.amount_iqd;
 else
  if not app_tiktok_dm.allowed(u) or not(select fastpay_enabled from app_tiktok_dm.settings where singleton) then return jsonb_build_object('ok',false,'code','TIKTOK_DM_FASTPAY_UNAVAILABLE');end if;
  select * into tq from app_tiktok_dm.quotes where id=p_quote_id and user_id=u for update;
  if not found then return jsonb_build_object('ok',false,'code','QUOTE_NOT_FOUND');end if;
  if tq.expires_at<=now() then return jsonb_build_object('ok',false,'code','QUOTE_EXPIRED');end if;
  if tq.ad->>'payment_method'<>'fastpay' or not app_tiktok_dm.valid_ad(tq.ad) then return jsonb_build_object('ok',false,'code','QUOTE_CHANGED');end if;
  if not exists(select 1 from app_tiktok_dm.accounts where id=tq.account_id and user_id=u and status='CONNECTED' and available_status='AVAILABLE' and can_pull_video and can_manage_message and message_ads_eligible) then return jsonb_build_object('ok',false,'code','TIKTOK_ACCOUNT_UNAVAILABLE');end if;
  -- Recheck current pricing before the customer starts a gateway payment; after
  -- this point the confirmed price is frozen, including later FX/level changes.
  preview:=public.pa_preview_ad(tq.ad,tq.promo_id,tq.promo_code);
  if preview->>'ok' is distinct from 'true' then return preview;end if;
  if preview->'cost_usd' is distinct from tq.pricing->'cost_usd' or preview->'amount_iqd' is distinct from tq.pricing->'amount_iqd'
   or preview->'rate' is distinct from tq.pricing->'rate' then return jsonb_build_object('ok',false,'code','PRICE_CHANGED');end if;
  c:=tq.ad;price:=tq.pricing;e:=tq.evidence;cost:=(price->>'cost_usd')::numeric;rate:=(price->>'rate')::numeric;iqd:=(price->>'amount_iqd')::bigint;
  if tq.promo_id is not null or nullif(btrim(tq.promo_code),'') is not null then
   select * into promo from public.promo_codes where (tq.promo_id is null or id=tq.promo_id)
    and (nullif(btrim(tq.promo_code),'') is null or upper(code)=upper(btrim(tq.promo_code))) for update;
   if not found or not promo.is_active or (promo.expires_at is not null and promo.expires_at<=now())
    or (promo.max_uses is not null and promo.used_count>=promo.max_uses)
    or exists(select 1 from public.promo_code_usages where promo_code_id=promo.id and user_id=u::text and status in ('active','consumed')) then return jsonb_build_object('ok',false,'code','INVALID_PROMO');end if;
  end if;
 end if;
 if cost is distinct from p_expected_cost_usd or iqd is distinct from p_expected_amount_iqd or iqd<1000 then return jsonb_build_object('ok',false,'code','PRICE_CHANGED');end if;
 if exists(select 1 from public.pa_ads where meta_quote_id=p_quote_id or tiktok_quote_id=p_quote_id)
  or exists(select 1 from app_finance.ad_payment_attempts where meta_quote_id=p_quote_id or tiktok_quote_id=p_quote_id) then return jsonb_build_object('ok',false,'code','QUOTE_ALREADY_USED');end if;
 -- Separate from the existing manual-ad AD namespace and deposit PX namespace.
 -- The legacy route guard reserves AP before the attempt row exists.
 oid:='AP'||upper(left(replace(p_submission_id::text,'-',''),28));
 if exists(select 1 from public.pa_transactions where fastpay_order_id=oid) then return jsonb_build_object('ok',false,'code','ORDER_ID_CONFLICT');end if;
 insert into public.pa_transactions(id,user_id,amount,gateway_amount,fx_rate,currency,method,kind,type,status,note,gateway,gateway_status,fastpay_order_id,expires_in,expires_at,meta_quote_id,tiktok_quote_id)
 values(tx,u,cost,iqd,rate,'IQD','fastpay','deposit','deposit','pending','Proxo immutable ad checkout','fastpay','CREATED',oid,10,now()+interval '10 minutes',mq.id,tq.id);
 if promo.id is not null then
  reservation:=gen_random_uuid();
  insert into public.promo_code_usages(id,promo_code_id,user_id,status,discount_applied) values(reservation,promo.id,u::text,'active',(price->>'promo_discount_usd')::numeric);
  update public.promo_codes set used_count=coalesce(used_count,0)+1,updated_at=now() where id=promo.id;
 end if;
 insert into app_finance.ad_payment_attempts(id,user_id,submission_id,platform,meta_quote_id,tiktok_quote_id,order_id,payment_transaction_id,environment,merchant_reference,configuration,pricing,evidence,cost_usd,amount_iqd,fx_rate,promo_id,promo_code,promo_reservation_id)
 values(aid,u,p_submission_id,p_platform,mq.id,tq.id,oid,tx,s.environment,s.merchant_reference,c,price,e,cost,iqd,rate,promo.id,promo.code,reservation) returning * into a;
 return app_finance.ad_payment_result(a);
end $$;
create function public.pa_ad_payment_attempt(p_submission_id uuid,p_platform text,p_quote_id uuid,p_expected_cost_usd numeric,p_expected_amount_iqd bigint)
returns jsonb language sql security invoker set search_path='' as $$select app_finance.ad_payment_attempt(p_submission_id,p_platform,p_quote_id,p_expected_cost_usd,p_expected_amount_iqd);$$;

-- This internal constructor consumes only a persisted authorization and verified
-- funding. It writes the established order, receipt debit and fulfillment queues.
-- It cannot accept an arbitrary user/configuration or impersonate a JWT session.
create function app_finance.commit_paid_ad(p_attempt_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
<<commit_paid>>
declare a app_finance.ad_payment_attempts%rowtype;c jsonb;ad public.pa_ads%rowtype;tq app_tiktok_dm.quotes%rowtype;
 mq app_meta.quotes%rowtype;account app_tiktok_dm.accounts%rowtype;starts timestamptz;ends timestamptz;days integer;daily numeric;
 receipt uuid:=gen_random_uuid();job uuid:=gen_random_uuid();balance numeric;result jsonb;req jsonb;compensate boolean;refund jsonb;
begin
 -- Match the authenticated retry's advisory-lock then row-lock order. Otherwise
 -- a paid callback and same-submission retry can deadlock each other.
 select * into a from app_finance.ad_payment_attempts where id=p_attempt_id;
 if found then perform pg_advisory_xact_lock(hashtextextended(a.user_id::text||':'||a.submission_id::text,0));end if;
 select * into a from app_finance.ad_payment_attempts where id=p_attempt_id for update;
 if not found then raise exception 'PAYMENT_ATTEMPT_NOT_FOUND';end if;
 if a.result is not null then return a.result;end if;
 if a.verified_at is null or a.gateway_transaction_id is null or not exists(select 1 from public.pa_transactions where id=a.payment_transaction_id and wallet_credited and status='approved' and gateway_status='PAID' and amount=a.cost_usd and gateway_amount=a.amount_iqd and fx_rate=a.fx_rate and user_id=a.user_id) then raise exception 'PAYMENT_NOT_VERIFIED';end if;
 if exists(select 1 from proxo_private.ad_submissions where user_id=a.user_id and submission_id=a.submission_id) then raise exception 'SUBMISSION_CONFLICT';end if;
 c:=a.configuration;balance:=public.pa_lock_wallet(a.user_id);
 if balance<a.cost_usd then raise exception 'INVALID_FUNDED_BALANCE';end if;
 compensate:=a.cancel_requested_at is not null or a.status='cancelled' or exists(select 1 from public.profiles where id=a.user_id and (is_banned or ads_locked));
 compensate:=compensate or exists(select 1 from public.pa_settings where key='ads_global_lock' and value::jsonb->>'locked'='true');
 if a.platform='TIKTOK' then
  select * into tq from app_tiktok_dm.quotes where id=a.tiktok_quote_id;
  select * into account from app_tiktok_dm.accounts where id=tq.account_id;
  days:=(c->>'days')::integer;daily:=(c->>'daily_budget')::numeric;
  starts:=case when (c->>'start_immediately')::boolean then date_trunc('minute',now())+interval '1 minute'
   else ((c->>'start_date')::date+(c->>'start_time')::time) at time zone 'Asia/Baghdad' end;
  ends:=starts+make_interval(hours=>24*days);
  compensate:=compensate or not app_tiktok_dm.allowed(a.user_id) or account.status<>'CONNECTED' or starts<now();
  insert into public.pa_ads(user_id,ad_number,status,title,goal,category,age_groups,gender,location,daily_budget,budget,days,total_budget,
   start_date,start_time,end_date,target_age,target_gender,target_location,service_type,platform,charged_price_iqd,charged_usd_iqd_rate,
   effective_usd_iqd_rate,usd_iqd_rate,service_budget_usd,pricing_source,device_type,customer_note,payment_method,payment_status,payment_transaction_id,receipt_uid,
   fulfillment_kind,message_destination,tiktok_quote_id,tiktok_account_id,tiktok_identity_id,tiktok_item_id,proxo_total_budget_usd,tiktok_declared_budget_usd,spend_stop_threshold_usd,
   promo_code,level_discount_percent,level_discount_iqd,pricing_total_iqd_snapshot,pricing_ad_budget_iqd_snapshot,pricing_service_fee_iqd_snapshot,pricing_discount_iqd_snapshot,
   pricing_daily_iqd_snapshot,pricing_usd_iqd_rate_snapshot,pricing_days_snapshot,pricing_payment_method_snapshot,pricing_snapshot_at)
  values(a.user_id,'TEMP00000000',case when compensate then 'rejected' when starts>now()+interval '5 minutes' then 'scheduled' else 'pending' end,c->>'title','messages',c->>'category',c->'age_groups',c->>'gender',c->>'location',daily,a.cost_usd,days,a.cost_usd,
   (starts at time zone 'Asia/Baghdad')::date,(starts at time zone 'Asia/Baghdad')::time,(ends at time zone 'Asia/Baghdad')::date,c->'age_groups',c->>'gender',c->>'location','tiktok','TIKTOK',a.amount_iqd,a.fx_rate,a.fx_rate,a.fx_rate,(a.pricing->>'gross_usd')::numeric,'immutable_fastpay_quote',c->>'device_type',nullif(c->>'customer_note',''),'fastpay','paid',a.payment_transaction_id,receipt,
   'tiktok_conversation_auto','direct_message',tq.id,account.id,account.identity_id,c->>'tiktok_item_id',(a.pricing->>'gross_usd')::numeric,(a.evidence->>'declared_budget_usd')::numeric,round((a.pricing->>'gross_usd')::numeric*.95,6),
   a.promo_code,coalesce((a.pricing->>'level_percent')::numeric,0),coalesce((a.pricing->>'level_fixed_iqd')::numeric,0),a.amount_iqd,round((a.pricing->>'gross_usd')::numeric*a.fx_rate),0,
   round(((a.pricing->>'gross_usd')::numeric-a.cost_usd)*a.fx_rate),round(daily*a.fx_rate),a.fx_rate,days,'fastpay',a.created_at) returning * into ad;
  insert into app_finance.outbox(id,ad_id,status,terminal_failure,last_error_code) values(job,ad.id,case when compensate then 'reconcile' else 'pending' end,compensate,case when compensate then 'PAID_AUTHORIZATION_NO_LONGER_DELIVERABLE' end);
  req:=jsonb_build_object('ad',c||jsonb_build_object('tiktok_quote_id',tq.id,'payment_transaction_id',a.payment_transaction_id),'promo_id',tq.promo_id,'promo_code',tq.promo_code,'cost_usd',a.cost_usd,'price_iqd',a.amount_iqd);
 else
  select * into mq from app_meta.quotes where id=a.meta_quote_id;
  days:=(c->>'duration_days')::integer;daily:=(c->>'budget_daily')::numeric;
  starts:=case when c#>>'{schedule,mode}'='IMMEDIATE' then now() else (c#>>'{schedule,start_at}')::timestamptz end;ends:=starts+make_interval(hours=>24*days);
  compensate:=compensate or not app_meta.allowed(a.user_id) or starts<now() or not exists(select 1 from app_meta.connections where id=mq.connection_id and status='authorized' and expires_at>now());
  insert into public.pa_ads(user_id,ad_number,status,title,goal,category,age_groups,gender,location,daily_budget,budget,days,total_budget,video_link,
   start_date,start_time,end_date,target_age,target_gender,target_location,service_type,platform,charged_price_iqd,charged_usd_iqd_rate,effective_usd_iqd_rate,usd_iqd_rate,service_budget_usd,
   pricing_source,payment_method,payment_status,payment_transaction_id,receipt_uid,meta_configuration,meta_quote_id,meta_start_at,meta_end_at,
   pricing_total_iqd_snapshot,pricing_ad_budget_iqd_snapshot,pricing_service_fee_iqd_snapshot,pricing_discount_iqd_snapshot,pricing_daily_iqd_snapshot,pricing_usd_iqd_rate_snapshot,pricing_days_snapshot,pricing_payment_method_snapshot,pricing_snapshot_at)
  values(a.user_id,'TEMP00000000',case when compensate then 'rejected' when starts>now()+interval '5 minutes' then 'scheduled' else 'pending' end,c->>'ad_name',c->>'objective','other',
   jsonb_build_array((c#>>'{targeting,age_min}')||'-'||(c#>>'{targeting,age_max}')),lower(c#>>'{targeting,gender}'),c#>>'{targeting,location}',daily,a.cost_usd,days,a.cost_usd,c->>'post_url',
   (starts at time zone 'Asia/Baghdad')::date,(starts at time zone 'Asia/Baghdad')::time,(ends at time zone 'Asia/Baghdad')::date,c->'targeting',lower(c#>>'{targeting,gender}'),c#>>'{targeting,location}',
   'meta','META',a.amount_iqd,a.fx_rate,a.fx_rate,a.fx_rate,a.cost_usd,'immutable_fastpay_quote','fastpay','paid',a.payment_transaction_id,receipt,c,mq.id,starts,ends,
   a.amount_iqd,a.amount_iqd,0,0,round(daily*a.fx_rate),a.fx_rate,days,'fastpay',a.created_at) returning * into ad;
  insert into app_meta.jobs(id,ad_id,user_id,quote_id,status,terminal_failure,last_error_code) values(job,ad.id,a.user_id,mq.id,case when compensate then 'reconcile' else 'queued' end,compensate,case when compensate then 'PAID_AUTHORIZATION_NO_LONGER_DELIVERABLE' end);
  req:=jsonb_build_object('platform','META','quote_id',mq.id,'configuration',c,'expected_total_minor',mq.payable_minor,'expected_total_iqd',mq.amount_iqd,'payment_transaction_id',a.payment_transaction_id);
 end if;
 if a.promo_reservation_id is not null then
  -- A verified unpaid terminal result can release a coupon reservation. A later
  -- genuine capture still honors the already authorized price, never reprices it.
  if not exists(select 1 from public.promo_code_usages where id=a.promo_reservation_id) then
   insert into public.promo_code_usages(id,promo_code_id,user_id,ad_id,status,discount_applied)
    values(a.promo_reservation_id,a.promo_id,a.user_id::text,ad.id::text,'active',(a.pricing->>'promo_discount_usd')::numeric);
   update public.promo_codes set used_count=coalesce(used_count,0)+1,updated_at=now() where id=a.promo_id;
  else update public.promo_code_usages set ad_id=ad.id::text where id=a.promo_reservation_id;end if;
 end if;
 update public.pa_wallets set balance=pa_wallets.balance-a.cost_usd,updated_at=now() where user_id=a.user_id returning pa_wallets.balance into balance;
 update public.pa_transactions set ad_id=ad.id,ad_public_id=ad.public_ad_id,ad_title=ad.title,updated_at=now() where id=a.payment_transaction_id;
 insert into public.pa_transactions(id,user_id,type,kind,method,status,amount,currency,note,balance_after,ad_id,ad_public_id,ad_title)
 values(receipt,a.user_id,'ad_payment','ad_payment','fastpay','approved',a.cost_usd,'USD','Proxo advertisement',balance,ad.id,ad.public_ad_id,ad.title);
 if compensate then
  refund:=case when a.platform='META' then app_meta.service('refund',a.user_id,job,null,jsonb_build_object('reason','PAID_AUTHORIZATION_NO_LONGER_DELIVERABLE'))
   else app_tiktok_dm.service('refund',a.user_id,job,null,jsonb_build_object('reason','PAID_AUTHORIZATION_NO_LONGER_DELIVERABLE')) end;
  if refund->>'ok' is distinct from 'true' then raise exception 'PAYMENT_COMPENSATION_FAILED';end if;
  select * into ad from public.pa_ads where id=ad.id;select w.balance into balance from public.pa_wallets w where w.user_id=a.user_id;
 end if;
 result:=jsonb_build_object('ok',true,'platform',a.platform,'ad_id',ad.id,'ad_number',ad.public_ad_id,'public_ad_id',ad.public_ad_id,'status',ad.status,
  'payment_method','fastpay','payment_status',ad.payment_status,'payment_transaction_id',a.payment_transaction_id,'receipt_uid',receipt,'charged_usd',a.cost_usd,
  'charged_iqd',a.amount_iqd,'rate',a.fx_rate,'gross_usd',coalesce((a.pricing->>'gross_usd')::numeric,a.cost_usd),'balance_after',balance,'job_id',job,'quote_id',coalesce(a.meta_quote_id,a.tiktok_quote_id),
  'compensated',compensate,'refund',refund);
 if not compensate then
  insert into public.pa_notifications(user_id,type,title,body,message,is_read,related_id,meta)
  values(a.user_id,ad.status,case when ad.status='scheduled' then 'ڕیکلامەکەت کات بۆ دانراوە' else 'ڕیکلامەکەت نێردرا' end,
   format('ڕیکلامی %s بە سەرکەوتوویی تۆمارکرا.',ad.public_ad_id),format('ڕیکلامی %s بە سەرکەوتوویی تۆمارکرا.',ad.public_ad_id),
   false,ad.id,jsonb_build_object('ad_number',ad.public_ad_id,'payment_method','fastpay','platform',a.platform,'submission_id',a.submission_id));
 end if;
 insert into proxo_private.ad_submissions(user_id,submission_id,request,result) values(a.user_id,a.submission_id,req,result);
 update app_finance.ad_payment_attempts set ad_id=ad.id,result=commit_paid.result,status=case when compensate then 'compensated' else 'funded' end,lease_token=null,lease_until=null where id=a.id;
 return result;
end $$;

create function app_finance.ad_payment_service(p_action text,p_attempt_id uuid,p_payload jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare a app_finance.ad_payment_attempts%rowtype;t public.pa_transactions%rowtype;stamp timestamptz;amount numeric;balance numeric;st text;res jsonb;
begin
 if p_action='callback_hint' then
  -- Public IPNs are hints only. The caller cannot supply payment authority.
  update app_finance.ad_payment_attempts set next_check_at=now()
   where order_id=p_payload->>'order_id' and status not in ('funded','compensated');
  return jsonb_build_object('ok',true);end if;
 if p_action='claim_reconcile' then
  -- A crash before the creation intent cannot have issued a gateway POST.
  -- Expire those local-only authorizations and release their coupon hold.
  for a in select * from app_finance.ad_payment_attempts where status='prepared' and creation_hash is null and expires_at<=now() for update skip locked loop
   if a.promo_reservation_id is not null then
    delete from public.promo_code_usages where id=a.promo_reservation_id and ad_id is null;
    if found then update public.promo_codes set used_count=greatest(coalesce(used_count,0)-1,0),updated_at=now() where id=a.promo_id;end if;
   end if;
   update app_finance.ad_payment_attempts set status='expired' where id=a.id;
  end loop;
  select * into a from app_finance.ad_payment_attempts where status not in ('funded','compensated') and next_check_at<=now()
   and (lease_until is null or lease_until<now()) and creation_hash is not null
   order by next_check_at,created_at for update skip locked limit 1;
  if not found then return null;end if;
  update app_finance.ad_payment_attempts set lease_token=gen_random_uuid(),lease_until=now()+interval '2 minutes',next_check_at=now()+interval '1 minute' where id=a.id returning * into a;
  return app_finance.ad_payment_result(a)||jsonb_build_object('merchant_reference',a.merchant_reference,'lease_token',a.lease_token,'creation_hash',a.creation_hash);end if;
 if p_action='observe_verified' then
  select * into a from app_finance.ad_payment_attempts where id=p_attempt_id;
  if found then perform pg_advisory_xact_lock(hashtextextended(a.user_id::text||':'||a.submission_id::text,0));end if;
 end if;
 select * into a from app_finance.ad_payment_attempts where id=p_attempt_id for update;
 if not found then return jsonb_build_object('ok',false,'code','PAYMENT_ATTEMPT_NOT_FOUND');end if;
 if p_action='read' then return app_finance.ad_payment_result(a)||jsonb_build_object('merchant_reference',a.merchant_reference,'lease_token',a.lease_token,'creation_hash',a.creation_hash);end if;
 if p_action='finish_reconcile' then
  if a.lease_token is null or a.lease_until is null or nullif(p_payload->>'lease_token','') is null or a.lease_token::text is distinct from p_payload->>'lease_token' or a.lease_until<now() then return jsonb_build_object('ok',false,'code','STALE_LEASE');end if;
  update app_finance.ad_payment_attempts set lease_token=null,lease_until=null,next_check_at=now()+interval '1 minute',last_error_code=left(p_payload->>'error_code',80) where id=a.id;
  return jsonb_build_object('ok',true);end if;
 if p_action='create_intent' then
  if a.status<>'prepared' then return app_finance.ad_payment_result(a)||jsonb_build_object('must_reconcile',a.status in ('creating','reconcile'));end if;
  if a.expires_at<=now() or a.cancel_requested_at is not null or not(select enabled from app_finance.ad_payment_settings where singleton) then return jsonb_build_object('ok',false,'code','PAYMENT_ATTEMPT_EXPIRED');end if;
  if coalesce(p_payload->>'request_hash','') !~ '^[a-f0-9]{64}$' then return jsonb_build_object('ok',false,'code','INVALID_REQUEST_HASH');end if;
  update app_finance.ad_payment_attempts set status='creating',creation_hash=p_payload->>'request_hash',creation_started_at=now() where id=a.id returning * into a;
  return app_finance.ad_payment_result(a)||jsonb_build_object('create_authorized',true);end if;
 if p_action='qr_created' then
  if a.creation_hash is null or a.creation_hash is distinct from p_payload->>'request_hash' then return jsonb_build_object('ok',false,'code','CREATION_INTENT_REQUIRED');end if;
  if a.status in ('funded','compensated') then return app_finance.ad_payment_result(a);end if;
  if coalesce(p_payload->>'qr_url','') !~ '^https://' or nullif(p_payload->>'qr_text','') is null or length(p_payload->>'qr_text')>4096 then return jsonb_build_object('ok',false,'code','INVALID_GATEWAY_QR');end if;
  select * into t from public.pa_transactions where id=a.payment_transaction_id for update;
  if t.qr_text is not null and (t.qr_text is distinct from p_payload->>'qr_text' or t.qr_url is distinct from p_payload->>'qr_url') then return jsonb_build_object('ok',false,'code','GATEWAY_QR_CONFLICT');end if;
  update public.pa_transactions set qr_url=p_payload->>'qr_url',qr_text=p_payload->>'qr_text',updated_at=now() where id=t.id;
  update app_finance.ad_payment_attempts set status='awaiting' where id=a.id returning * into a;return app_finance.ad_payment_result(a);end if;
 if p_action='unknown' then
  if a.status not in ('funded','compensated') then update app_finance.ad_payment_attempts set status='reconcile',last_error_code=left(p_payload->>'error_code',80) where id=a.id;end if;
  return jsonb_build_object('ok',true,'must_reconcile',true);end if;
 if p_action not in ('observe_verified','observe_status') then return jsonb_build_object('ok',false,'code','INVALID_PAYMENT_ACTION');end if;
 begin stamp:=(p_payload->>'verified_at')::timestamptz;amount:=(p_payload->>'amount_iqd')::numeric;
 exception when others then return jsonb_build_object('ok',false,'code','INVALID_GATEWAY_VERIFICATION');end;
 st:=p_payload->>'status';
 if p_payload->>'verification_source' is distinct from (case when p_action='observe_status' then 'FASTPAY_STATUS' else 'FASTPAY_VALIDATE' end) or coalesce(p_payload->>'response_sha256','') !~ '^[a-f0-9]{64}$'
  or stamp is null or stamp>now()+interval '1 minute' or stamp<now()-interval '5 minutes'
  or p_payload->>'order_id' is distinct from a.order_id or p_payload->>'environment' is distinct from a.environment
  or p_payload->>'merchant_reference' is distinct from a.merchant_reference or p_payload->>'currency' is distinct from 'IQD'
  or amount is distinct from a.amount_iqd or (p_action='observe_verified' and st is distinct from 'PAID')
  or (p_action='observe_status' and coalesce(st,'') not in ('UNPAID','DECLINED'))
  or (st='PAID' and nullif(btrim(p_payload->>'gateway_transaction_id'),'') is null) then return jsonb_build_object('ok',false,'code','INVALID_GATEWAY_VERIFICATION');end if;
 if a.status in ('funded','compensated') then
  if p_action='observe_status' then return app_finance.ad_payment_result(a)||jsonb_build_object('duplicate',true);end if;
  if st<>'PAID' or a.gateway_transaction_id is distinct from p_payload->>'gateway_transaction_id' then return jsonb_build_object('ok',false,'code','IDEMPOTENCY_CONFLICT');end if;
  return app_finance.ad_payment_result(a)||jsonb_build_object('duplicate',true);end if;
 insert into app_finance.ad_payment_verifications(attempt_id,status,gateway_transaction_id,amount_iqd,currency,verified_at,response_sha256,verification_source)
 values(a.id,st,p_payload->>'gateway_transaction_id',a.amount_iqd,'IQD',stamp,p_payload->>'response_sha256',p_payload->>'verification_source') on conflict(attempt_id,response_sha256) do nothing;
 if st='UNPAID' then return app_finance.ad_payment_result(a);end if;
 if st<>'PAID' then
  if a.promo_reservation_id is not null then
   delete from public.promo_code_usages where id=a.promo_reservation_id and ad_id is null;
   if found then update public.promo_codes set used_count=greatest(coalesce(used_count,0)-1,0),updated_at=now() where id=a.promo_id;end if;
  end if;
  update app_finance.ad_payment_attempts set status=lower(st),verified_at=stamp,next_check_at=now()+interval '5 minutes' where id=a.id returning * into a;
  update public.pa_transactions set status='rejected',gateway_status=st,updated_at=now() where id=a.payment_transaction_id and not wallet_credited;
  return app_finance.ad_payment_result(a);end if;
 -- The callback or reconciler has independently validated the gateway receipt.
 -- Late/expired/cancelled local state never discards a real captured payment.
 select * into t from public.pa_transactions where id=a.payment_transaction_id for update;
 if t.wallet_credited then raise exception 'PAYMENT_RECONCILIATION_REQUIRED';end if;
 if exists(select 1 from public.pa_transactions where gateway='fastpay' and gw_transaction_id=p_payload->>'gateway_transaction_id' and id<>t.id) then return jsonb_build_object('ok',false,'code','GATEWAY_TRANSACTION_ALREADY_USED');end if;
 balance:=public.pa_lock_wallet(a.user_id);
 update public.pa_wallets set balance=pa_wallets.balance+a.cost_usd,updated_at=now() where user_id=a.user_id returning pa_wallets.balance into balance;
 update public.pa_transactions set status='approved',gateway_status='PAID',gw_transaction_id=p_payload->>'gateway_transaction_id',received_amount=a.amount_iqd,
  wallet_credited=true,balance_after=balance,paid_at=now(),review_reason='verified_fastpay_ad_payment',fail_reason=null,updated_at=now() where id=t.id;
 update app_finance.ad_payment_attempts set gateway_transaction_id=p_payload->>'gateway_transaction_id',verified_at=stamp where id=a.id;
 res:=app_finance.commit_paid_ad(a.id);
 select * into a from app_finance.ad_payment_attempts where id=a.id;
 return app_finance.ad_payment_result(a);
end $$;
create function public.pa_ad_payment_service(p_action text,p_attempt_id uuid default null,p_payload jsonb default '{}') returns jsonb
 language sql security invoker set search_path='' as $$select app_finance.ad_payment_service(p_action,p_attempt_id,p_payload);$$;
create function app_finance.ad_payment_cancel(p_attempt_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=app_finance.actor();a app_finance.ad_payment_attempts%rowtype;begin
 select * into a from app_finance.ad_payment_attempts where id=p_attempt_id and user_id=u for update;
 if not found then return jsonb_build_object('ok',false,'code','PAYMENT_ATTEMPT_NOT_FOUND');end if;
 if a.status not in ('funded','compensated') then
  update app_finance.ad_payment_attempts set cancel_requested_at=coalesce(cancel_requested_at,now()),next_check_at=now(),
   status=case when creation_hash is null then 'cancelled' else status end where id=a.id returning * into a;
  if a.creation_hash is null and a.promo_reservation_id is not null then
   delete from public.promo_code_usages where id=a.promo_reservation_id and ad_id is null;
   if found then update public.promo_codes set used_count=greatest(coalesce(used_count,0)-1,0),updated_at=now() where id=a.promo_id;end if;
  end if;
 end if;
 -- A client cancellation is not a provider cancellation or proof of nonpayment.
 return app_finance.ad_payment_result(a);end $$;
create function public.pa_ad_payment_cancel(p_attempt_id uuid) returns jsonb language sql security invoker set search_path='' as $$select app_finance.ad_payment_cancel(p_attempt_id);$$;
create function app_finance.ad_payment_status(p_attempt_id uuid,p_submission_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=app_finance.actor();a app_finance.ad_payment_attempts%rowtype;begin
 select * into a from app_finance.ad_payment_attempts where user_id=u and ((p_attempt_id is not null and id=p_attempt_id) or (p_attempt_id is null and p_submission_id is not null and submission_id=p_submission_id));
 if not found then return jsonb_build_object('ok',false,'code','PAYMENT_ATTEMPT_NOT_FOUND');end if;
 return app_finance.ad_payment_result(a);end $$;
create function public.pa_ad_payment_status(p_attempt_id uuid default null,p_submission_id uuid default null) returns jsonb language sql security invoker set search_path='' as $$select app_finance.ad_payment_status(p_attempt_id,p_submission_id);$$;

-- Existing top-ups/manual checkout keep their established callback. Bound ad
-- payments must use the verified atomic path, never a wallet-only callback.
create function app_finance.legacy_fastpay_guard(p_order_id text,p_transaction_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare resolved text:=p_order_id;bound_order text;protected boolean;begin
 if p_transaction_id is not null then select fastpay_order_id into bound_order from public.pa_transactions where id=p_transaction_id and gateway='fastpay';
  if not found or (p_order_id is not null and p_order_id is distinct from bound_order) then return jsonb_build_object('ok',false,'legacy_allowed',false,'immutable_ad_payment',false,'code','INVALID_ORDER');end if;
  resolved:=coalesce(p_order_id,bound_order);end if;
 if resolved is null or resolved !~ '^[A-Za-z0-9_-]{8,32}$' then return jsonb_build_object('ok',false,'legacy_allowed',false,'immutable_ad_payment',false,'code','INVALID_ORDER');end if;
 protected:=resolved ~* '^AP[0-9A-F]{28}$' or exists(select 1 from app_finance.ad_payment_attempts where order_id=resolved or payment_transaction_id=p_transaction_id);
 return jsonb_build_object('ok',true,'legacy_allowed',not protected,'immutable_ad_payment',protected,'code',case when protected then 'AD_PAYMENT_IMMUTABLE' else 'LEGACY_ALLOWED' end);
end;
$$;
create function public.pa_legacy_fastpay_guard(p_order_id text,p_transaction_id uuid default null) returns jsonb language sql security invoker set search_path='' as $$select app_finance.legacy_fastpay_guard(p_order_id,p_transaction_id);$$;
create function app_finance.fastpay_expire_stale_orders(p_grace_minutes integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare changed integer;begin
 update public.pa_transactions set gateway_status='EXPIRED',status='rejected',fail_reason=coalesce(fail_reason,'Expired before payment')
 where gateway='fastpay' and gateway_status='CREATED' and wallet_credited=false
  and coalesce(expires_at,created_at+(coalesce(expires_in,10)*interval '1 minute'))+(coalesce(p_grace_minutes,2)*interval '1 minute')<now()
  and app_finance.legacy_fastpay_guard(fastpay_order_id,id)->>'legacy_allowed'='true';
 get diagnostics changed=row_count;return jsonb_build_object('ok',true,'expired',changed);end $$;
create or replace function public.fastpay_expire_stale_orders(p_grace_minutes integer default 2) returns jsonb language sql security invoker set search_path='' as $$select app_finance.fastpay_expire_stale_orders(p_grace_minutes);$$;
create function app_finance.fastpay_orders_to_poll(p_limit integer,p_grace_minutes integer)
 returns table(id uuid,user_id uuid,fastpay_order_id text,amount numeric,gateway_amount numeric,currency text,created_at timestamptz,expires_at timestamptz)
 language sql stable security definer set search_path='' as $$
 select t.id,t.user_id,t.fastpay_order_id,t.amount,t.gateway_amount,t.currency,t.created_at,
  coalesce(t.expires_at,t.created_at+(coalesce(t.expires_in,10)*interval '1 minute'))
 from public.pa_transactions t where t.gateway='fastpay' and t.gateway_status='CREATED' and t.wallet_credited=false
  and now()<coalesce(t.expires_at,t.created_at+(coalesce(t.expires_in,10)*interval '1 minute'))+(coalesce(p_grace_minutes,2)*interval '1 minute')
  and app_finance.legacy_fastpay_guard(t.fastpay_order_id,t.id)->>'legacy_allowed'='true'
 order by t.created_at asc limit greatest(coalesce(p_limit,50),1);$$;
create or replace function public.fastpay_orders_to_poll(p_limit integer default 50,p_grace_minutes integer default 2)
 returns table(id uuid,user_id uuid,fastpay_order_id text,amount numeric,gateway_amount numeric,currency text,created_at timestamptz,expires_at timestamptz)
 language sql stable security invoker set search_path='' as $$select * from app_finance.fastpay_orders_to_poll(p_limit,p_grace_minutes);$$;
alter function public.fastpay_mark_paid(text,text,numeric,text,text,jsonb) set schema app_finance;
alter function app_finance.fastpay_mark_paid(text,text,numeric,text,text,jsonb) rename to fastpay_mark_paid_legacy;
revoke all on function app_finance.fastpay_mark_paid_legacy(text,text,numeric,text,text,jsonb) from public,anon,authenticated,service_role;
create function app_finance.fastpay_mark_paid(p_order_id text,p_gw_transaction_id text,p_received_amount numeric,p_currency text,p_source text,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$begin
 if app_finance.legacy_fastpay_guard(p_order_id,null)->>'legacy_allowed'<>'true' then return jsonb_build_object('ok',false,'code','AD_PAYMENT_VERIFICATION_REQUIRED');end if;
 return app_finance.fastpay_mark_paid_legacy(p_order_id,p_gw_transaction_id,p_received_amount,p_currency,p_source,p_payload);end $$;
create function public.fastpay_mark_paid(p_order_id text,p_gw_transaction_id text default null,p_received_amount numeric default null,p_currency text default null,p_source text default 'ipn',p_payload jsonb default null)
returns jsonb language sql security invoker set search_path='' as $$select app_finance.fastpay_mark_paid(p_order_id,p_gw_transaction_id,p_received_amount,p_currency,p_source,p_payload);$$;

-- These functions belong to the existing deployed gateway baseline (the
-- historical repository does not bootstrap them). Preserve their implementation
-- byte for byte and add an order-binding guard where they are installed.
do $guards$ begin
 if to_regprocedure('public.fastpay_create_order(uuid,text,numeric,text,text,text,integer,text)') is not null then
  alter function public.fastpay_create_order(uuid,text,numeric,text,text,text,integer,text) set schema app_finance;
  alter function app_finance.fastpay_create_order(uuid,text,numeric,text,text,text,integer,text) rename to fastpay_create_order_legacy;
  revoke all on function app_finance.fastpay_create_order_legacy(uuid,text,numeric,text,text,text,integer,text) from public,anon,authenticated,service_role;
  execute $fn$create function app_finance.fastpay_create_order(p_user_id uuid,p_order_id text,p_amount numeric,p_currency text,p_qr_url text,p_qr_text text,p_expires_in integer,p_note text)
  returns jsonb language plpgsql security definer set search_path='' as $body$begin
   if app_finance.legacy_fastpay_guard(p_order_id,null)->>'legacy_allowed'<>'true' then return jsonb_build_object('ok',false,'code','AD_PAYMENT_ATTEMPT_REQUIRED');end if;
   return app_finance.fastpay_create_order_legacy(p_user_id,p_order_id,p_amount,p_currency,p_qr_url,p_qr_text,p_expires_in,p_note);end $body$$fn$;
  execute $fn$create function public.fastpay_create_order(p_user_id uuid,p_order_id text,p_amount numeric,p_currency text default 'IQD',p_qr_url text default null,p_qr_text text default null,p_expires_in integer default 10,p_note text default null)
  returns jsonb language sql security invoker set search_path='' as $body$select app_finance.fastpay_create_order(p_user_id,p_order_id,p_amount,p_currency,p_qr_url,p_qr_text,p_expires_in,p_note);$body$$fn$;
  revoke all on function app_finance.fastpay_create_order(uuid,text,numeric,text,text,text,integer,text),public.fastpay_create_order(uuid,text,numeric,text,text,text,integer,text) from public,anon,authenticated;
  grant execute on function app_finance.fastpay_create_order(uuid,text,numeric,text,text,text,integer,text),public.fastpay_create_order(uuid,text,numeric,text,text,text,integer,text) to service_role;
 end if;
 if to_regprocedure('public.fastpay_apply_refund(text,numeric,text,boolean,jsonb)') is not null then
  alter function public.fastpay_apply_refund(text,numeric,text,boolean,jsonb) set schema app_finance;
  alter function app_finance.fastpay_apply_refund(text,numeric,text,boolean,jsonb) rename to fastpay_apply_refund_legacy;
  revoke all on function app_finance.fastpay_apply_refund_legacy(text,numeric,text,boolean,jsonb) from public,anon,authenticated,service_role;
  execute $fn$create function app_finance.fastpay_apply_refund(p_order_id text,p_amount numeric,p_msisdn text,p_deduct_wallet boolean,p_payload jsonb)
  returns jsonb language plpgsql security definer set search_path='' as $body$begin
   if app_finance.legacy_fastpay_guard(p_order_id,null)->>'legacy_allowed'<>'true' then return jsonb_build_object('ok',false,'code','AD_REFUND_REQUIRES_RECONCILIATION');end if;
   return app_finance.fastpay_apply_refund_legacy(p_order_id,p_amount,p_msisdn,p_deduct_wallet,p_payload);end $body$$fn$;
  execute $fn$create function public.fastpay_apply_refund(p_order_id text,p_amount numeric,p_msisdn text default null,p_deduct_wallet boolean default true,p_payload jsonb default null)
  returns jsonb language sql security invoker set search_path='' as $body$select app_finance.fastpay_apply_refund(p_order_id,p_amount,p_msisdn,p_deduct_wallet,p_payload);$body$$fn$;
  revoke all on function app_finance.fastpay_apply_refund(text,numeric,text,boolean,jsonb),public.fastpay_apply_refund(text,numeric,text,boolean,jsonb) from public,anon,authenticated;
  grant execute on function app_finance.fastpay_apply_refund(text,numeric,text,boolean,jsonb),public.fastpay_apply_refund(text,numeric,text,boolean,jsonb) to service_role;
 end if;
end $guards$;

do $$declare name text;begin
 foreach name in array array['ad_payment_settings','ad_payment_attempts','ad_payment_verifications'] loop
  execute format('alter table app_finance.%I enable row level security',name);
  execute format('revoke all on app_finance.%I from public,anon,authenticated,service_role',name);
 end loop;end $$;
revoke all on function app_finance.protect_ad_payment_attempt(),app_finance.protect_ad_payment_transaction(),app_finance.ad_payment_result(app_finance.ad_payment_attempts),
 app_finance.commit_paid_ad(uuid),app_finance.ad_payment_attempt(uuid,text,uuid,numeric,bigint),app_finance.ad_payment_cancel(uuid),app_finance.ad_payment_status(uuid,uuid),
 app_finance.ad_payment_service(text,uuid,jsonb),app_finance.fastpay_mark_paid(text,text,numeric,text,text,jsonb),app_finance.legacy_fastpay_guard(text,uuid) from public,anon,authenticated,service_role;
revoke all on function app_finance.fastpay_expire_stale_orders(integer),app_finance.fastpay_orders_to_poll(integer,integer),public.fastpay_expire_stale_orders(integer),public.fastpay_orders_to_poll(integer,integer) from public,anon,authenticated;
grant execute on function app_finance.fastpay_expire_stale_orders(integer),app_finance.fastpay_orders_to_poll(integer,integer),public.fastpay_expire_stale_orders(integer),public.fastpay_orders_to_poll(integer,integer) to service_role;
grant execute on function app_finance.ad_payment_attempt(uuid,text,uuid,numeric,bigint),app_finance.ad_payment_cancel(uuid),app_finance.ad_payment_status(uuid,uuid) to authenticated;
grant usage on schema app_finance to service_role;
grant execute on function app_finance.ad_payment_service(text,uuid,jsonb),app_finance.fastpay_mark_paid(text,text,numeric,text,text,jsonb),app_finance.legacy_fastpay_guard(text,uuid) to service_role;
revoke all on function public.pa_ad_payment_attempt(uuid,text,uuid,numeric,bigint),public.pa_ad_payment_cancel(uuid),public.pa_ad_payment_status(uuid,uuid),public.pa_ad_payment_service(text,uuid,jsonb),
 public.fastpay_mark_paid(text,text,numeric,text,text,jsonb),public.pa_legacy_fastpay_guard(text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.pa_ad_payment_attempt(uuid,text,uuid,numeric,bigint),public.pa_ad_payment_cancel(uuid),public.pa_ad_payment_status(uuid,uuid) to authenticated;
grant execute on function public.pa_ad_payment_service(text,uuid,jsonb),public.fastpay_mark_paid(text,text,numeric,text,text,jsonb),public.pa_legacy_fastpay_guard(text,uuid) to service_role;
commit;
