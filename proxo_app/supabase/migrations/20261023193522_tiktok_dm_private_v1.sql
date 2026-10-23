-- Private TikTok Direct Message / Conversation integration. All rollout flags
-- default OFF. No production enablement, provider write or paid test occurs here.
-- Extends the established wallet/submission/outbox instead of a second checkout.
begin;
create schema app_tiktok_dm;
revoke all on schema app_tiktok_dm from public,anon,authenticated;
grant usage on schema app_tiktok_dm to authenticated,service_role;
create table app_tiktok_dm.settings(singleton boolean primary key default true check(singleton),enabled boolean not null default false,
 fastpay_enabled boolean not null default false,activation_enabled boolean not null default false,updated_at timestamptz not null default now());
insert into app_tiktok_dm.settings(singleton) values(true);
create table app_tiktok_dm.testers(user_id uuid primary key references auth.users(id),enabled boolean not null default false,expires_at timestamptz);
create table app_tiktok_dm.preferences(user_id uuid primary key references auth.users(id),seen_at timestamptz not null default now());
-- Reserve a session model for a supported provider-correlated authorization
-- flow. A local nonce or BC account-list polling is NOT authorization proof.
-- The shipped connect-start service fails closed and does not create fake URLs.
create table app_tiktok_dm.connection_requests(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id),
 requested_username text not null check(requested_username ~ '^[a-z0-9_.]{2,24}$'),state_hash text not null unique,
 expires_at timestamptz not null,status text not null default 'PENDING' check(status in ('PENDING','CONNECTED','MISMATCH','EXPIRED','FAILED')),
 provider_session_reference text,proof jsonb,resolved_identity_id text,resolved_username text,error_code text,created_at timestamptz not null default now());
create index tiktok_dm_requests_owner on app_tiktok_dm.connection_requests(user_id,created_at desc);
create table app_tiktok_dm.accounts(
 id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id),
 requested_username text not null,verified_username text not null,display_name text,profile_image_url text,
 identity_id text not null unique,identity_type text not null check(identity_type in ('BC_AUTH_TT','TT_USER')),
 identity_authorized_bc_id text,business_center_id text not null,advertiser_id text not null,asset_id text not null,
 available_status text not null,can_pull_video boolean not null default false,can_manage_message boolean not null default false,
 can_push_video boolean not null default false,message_ads_eligible boolean not null default false,
 status text not null check(status in ('CONNECTED','REVOKING','DISCONNECTED','EXPIRED')),
 access_token_env text not null check(access_token_env ~ '^TIKTOK_[A-Z0-9_]{1,100}$'),capabilities jsonb not null default '{}',
 owner_binding_proof jsonb not null check(jsonb_typeof(owner_binding_proof)='object' and owner_binding_proof->>'verified'='true'
  and nullif(owner_binding_proof->>'reference','') is not null),
 last_verified_at timestamptz not null,connected_at timestamptz not null default now(),disconnected_at timestamptz,
 lease_token uuid,lease_until timestamptz,lease_kind text,refresh_after timestamptz not null default now(),disconnect_requested_at timestamptz,
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 check(lower(regexp_replace(btrim(requested_username),'^@',''))=lower(regexp_replace(btrim(verified_username),'^@',''))),
 check(identity_type<>'BC_AUTH_TT' or identity_authorized_bc_id=business_center_id)
);
create index tiktok_dm_accounts_owner on app_tiktok_dm.accounts(user_id,created_at);
create table app_tiktok_dm.video_cache(account_id uuid not null references app_tiktok_dm.accounts(id),user_id uuid not null references auth.users(id),
 item_id text not null,metadata jsonb not null,expires_at timestamptz not null,verified_at timestamptz not null,
 primary key(account_id,item_id));
create index tiktok_dm_video_cache_owner on app_tiktok_dm.video_cache(user_id,account_id);
create table app_tiktok_dm.quotes(id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id),
 account_id uuid not null references app_tiktok_dm.accounts(id),ad jsonb not null,config_hash text not null check(config_hash ~ '^[a-f0-9]{64}$'),
 evidence jsonb not null,pricing jsonb not null,promo_id uuid,promo_code text,
 created_at timestamptz not null default now(),expires_at timestamptz not null default(now()+interval '5 minutes'));
create index tiktok_dm_quotes_owner on app_tiktok_dm.quotes(user_id,created_at desc);
create trigger tiktok_dm_quote_immutable before update or delete on app_tiktok_dm.quotes for each row execute function app_meta.immutable_quote();

alter table public.pa_ads add column if not exists fulfillment_kind text not null default 'manual' check(fulfillment_kind in ('manual','tiktok_conversation_auto'));
alter table public.pa_ads add column if not exists message_destination text;
alter table public.pa_ads add column if not exists tiktok_account_id uuid references app_tiktok_dm.accounts(id);
alter table public.pa_ads add column if not exists tiktok_item_id text;
alter table public.pa_ads add column if not exists tiktok_identity_id text;
alter table public.pa_ads add column if not exists tiktok_adgroup_id text;
alter table public.pa_ads add column if not exists tiktok_rule_id text;
alter table public.pa_ads add column if not exists tiktok_status_checked_at timestamptz;
alter table public.pa_ads add column if not exists provider_metrics_available jsonb not null default '[]'::jsonb;
alter table public.pa_ads add column if not exists tiktok_quote_id uuid references app_tiktok_dm.quotes(id);
alter table public.pa_ads add column if not exists proxo_total_budget_usd numeric(20,6);
alter table public.pa_ads add column if not exists tiktok_declared_budget_usd numeric(20,6);
alter table public.pa_ads add column if not exists spend_stop_threshold_usd numeric(20,6);
alter table public.pa_ads add column if not exists spend_stop_triggered_at timestamptz;
alter table public.pa_ads add column if not exists refund_eligible_at timestamptz;
alter table public.pa_ads add column if not exists final_spend_usd numeric(20,6);
alter table public.pa_ads add column if not exists spend_reconciled_at timestamptz;
alter table public.pa_ads add column if not exists unused_budget_refund_usd numeric(20,6);
alter table public.pa_ads add column if not exists unused_budget_refunded_at timestamptz;
alter table public.pa_ads add column if not exists unused_budget_refund_tx_id uuid references public.pa_transactions(id);
create unique index tiktok_dm_quote_once on public.pa_ads(tiktok_quote_id) where tiktok_quote_id is not null;
alter table public.pa_transactions add column if not exists tiktok_quote_id uuid references app_tiktok_dm.quotes(id);
create unique index tiktok_dm_fastpay_quote_once on public.pa_transactions(tiktok_quote_id) where tiktok_quote_id is not null and gateway='fastpay';
alter table app_finance.outbox add column fulfillment_kind text not null default 'manual' check(fulfillment_kind in ('manual','tiktok_conversation_auto'));
alter table app_finance.outbox add column tiktok_quote_id uuid references app_tiktok_dm.quotes(id);
alter table app_finance.outbox add column stages jsonb not null default '{}';
alter table app_finance.outbox add column provider_ids jsonb not null default '{}';
alter table app_finance.outbox add column observation jsonb;
alter table app_finance.outbox add column lease_kind text;
alter table app_finance.outbox add column terminal_failure boolean not null default false;
alter table app_finance.outbox add column stop_intent jsonb;
alter table app_finance.outbox add column final_observation jsonb;
create index tiktok_dm_outbox_due on app_finance.outbox(fulfillment_kind,status,available_at);

create function app_tiktok_dm.allowed(p_user uuid) returns boolean language sql stable security definer set search_path='' as $$
 select coalesce((select s.enabled and t.enabled and (t.expires_at is null or t.expires_at>now()) from app_tiktok_dm.settings s
 join app_tiktok_dm.testers t on t.user_id=p_user where s.singleton),false)
 and exists(select 1 from auth.users u join public.profiles p on p.id=u.id where u.id=p_user
 and (u.email_confirmed_at is not null or u.phone_confirmed_at is not null) and not coalesce(p.is_banned,false));
$$;
create function app_tiktok_dm.account_safe(a app_tiktok_dm.accounts) returns jsonb language sql immutable set search_path='' as $$
 select jsonb_build_object('id',a.id,'requested_username',a.requested_username,'verified_username',a.verified_username,'username',a.verified_username,
 'display_name',a.display_name,'profile_image_url',a.profile_image_url,'status',a.status,'connection_status',a.status,
 'message_ads_eligible',a.message_ads_eligible and a.can_pull_video and a.can_manage_message and a.available_status='AVAILABLE',
 'last_verified_at',a.last_verified_at,'connected_at',a.connected_at);
$$;
create function app_tiktok_dm.capabilities() returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=app_finance.actor(); begin return app_meta.capabilities()||jsonb_build_object('tiktok_dm_enabled',app_tiktok_dm.allowed(u),
 'tiktok_dm_fastpay_enabled',app_tiktok_dm.allowed(u) and (select fastpay_enabled from app_tiktok_dm.settings where singleton),
 'tiktok_dm_seen',exists(select 1 from app_tiktok_dm.preferences where user_id=u));end $$;
create or replace function public.pa_ad_capabilities() returns jsonb language sql security invoker set search_path='' as $$select app_tiktok_dm.capabilities();$$;

-- Deliberately narrow branch check; user-selected manual fields cannot leak into
-- the authorized identity/item flow, and unknown destinations fail closed.
create function app_tiktok_dm.valid_ad(a jsonb) returns boolean language plpgsql stable set search_path='' as $$
declare k text; dt timestamp; begin
 if a is null or jsonb_typeof(a)<>'object' or octet_length(a::text)>16384 or a->>'goal' is distinct from 'messages'
  or a->>'message_destination' is distinct from 'direct_message' or a ?| array['video_link','video_code','post_code','asset_id','card_id','destination_url']
  or coalesce(a->>'tiktok_account_id','') !~ '^[a-f0-9-]{36}$' or coalesce(a->>'tiktok_item_id','') !~ '^[0-9]{1,30}$'
  or char_length(btrim(coalesce(a->>'title',''))) not between 1 and 120
  or coalesce(a->>'category','') not in ('cosmetics_beauty','fashion_apparel','electronics','food_beverage','home_living','automotive','services','education','games_apps','health_wellness','retail_ecommerce','other')
  or char_length(coalesce(a->>'customer_note',''))>500
  or coalesce((a->>'daily_budget')::numeric,0) not in (10,20,50,100,200,500,1000)
  or coalesce((a->>'days')::numeric,0) not between 1 and 7 or (a->>'days')::numeric<>trunc((a->>'days')::numeric)
  or coalesce(a->>'gender','all') not in ('all','male','female') or coalesce(a->>'location','kurdistan') not in ('all','kurdistan','iraq')
  or coalesce(a->>'device_type','all') not in ('all','iphone','android') or coalesce(a->>'payment_method','app_balance') not in ('app_balance','fastpay')
  or jsonb_typeof(a->'age_groups') is distinct from 'array' or jsonb_array_length(a->'age_groups')=0
  or exists(select 1 from jsonb_array_elements_text(a->'age_groups') x where x not in ('all','18-24','25-34','35-44','45-54','55+')) then return false;end if;
 for k in select jsonb_object_keys(a) loop
  if k not in ('title','goal','category','age_groups','gender','location','device_type','customer_note','daily_budget','days','start_date','start_time',
   'start_immediately','payment_method','message_destination','tiktok_account_id','tiktok_item_id','promo_code') then return false; end if;
 end loop;
 if not coalesce((a->>'start_immediately')::boolean,false) then
  dt:=(a->>'start_date')::date+(a->>'start_time')::time;
  if dt is null or dt<=timezone('Asia/Baghdad',now()) or dt>timezone('Asia/Baghdad',now())+interval '90 days' then return false;end if;
 end if;return true;
exception when invalid_text_representation or numeric_value_out_of_range or datetime_field_overflow or invalid_datetime_format then return false;
end $$;

create function app_tiktok_dm.check_quote(p_ad jsonb,p_promo_id uuid,p_promo_code text) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=app_finance.actor(); q app_tiktok_dm.quotes%rowtype; a app_tiktok_dm.accounts%rowtype; body jsonb;
begin
 if not app_tiktok_dm.allowed(u) then return jsonb_build_object('ok',false,'code','TIKTOK_DM_DISABLED');end if;
 if not app_finance.rate_allowed(u,'tiktok_dm_accept',20) then return jsonb_build_object('ok',false,'code','RATE_LIMITED');end if;
 begin select * into q from app_tiktok_dm.quotes where id=(p_ad->>'tiktok_quote_id')::uuid and user_id=u for update;
 exception when invalid_text_representation then return jsonb_build_object('ok',false,'code','QUOTE_NOT_FOUND');end;
 if not found then return jsonb_build_object('ok',false,'code','QUOTE_NOT_FOUND');end if;
 if q.expires_at<=now() then return jsonb_build_object('ok',false,'code','QUOTE_EXPIRED');end if;
 body:=p_ad-array['tiktok_quote_id','payment_transaction_id','confirmation_cost_usd','confirmation_price_iqd'];
 if q.ad is distinct from body or q.promo_id is distinct from p_promo_id or nullif(btrim(q.promo_code),'') is distinct from nullif(btrim(p_promo_code),'') then return jsonb_build_object('ok',false,'code','QUOTE_CHANGED');end if;
 if not app_tiktok_dm.valid_ad(body) then return jsonb_build_object('ok',false,'code','INVALID_DIRECT_MESSAGE_AD');end if;
 if exists(select 1 from public.pa_ads where tiktok_quote_id=q.id) then return jsonb_build_object('ok',false,'code','QUOTE_ALREADY_USED');end if;
 select * into a from app_tiktok_dm.accounts where id=q.account_id and user_id=u and status='CONNECTED' and available_status='AVAILABLE'
 and can_pull_video and can_manage_message and message_ads_eligible for share;
 if not found then return jsonb_build_object('ok',false,'code','TIKTOK_ACCOUNT_UNAVAILABLE');end if;
 if body->>'payment_method'='fastpay' then
  if not (select fastpay_enabled from app_tiktok_dm.settings where singleton) then return jsonb_build_object('ok',false,'code','TIKTOK_DM_FASTPAY_UNAVAILABLE');end if;
  if not exists(select 1 from public.pa_transactions t where t.id=(p_ad->>'payment_transaction_id')::uuid and t.user_id=u and t.tiktok_quote_id=q.id
   and t.amount=(q.pricing->>'cost_usd')::numeric and t.gateway_amount=(q.pricing->>'amount_iqd')::numeric and t.status='approved' and t.wallet_credited and t.ad_id is null) then
   return jsonb_build_object('ok',false,'code','PAYMENT_NOT_VERIFIED');end if;
 end if;
 return jsonb_build_object('ok',true,'quote_id',q.id);
end $$;

-- Added before the existing outbox insert. The original submission transaction
-- therefore commits the funded order, immutable request and auto discriminator
-- together; an outbox insertion error rolls every wallet/ledger write back.
create function app_tiktok_dm.prepare_outbox() returns trigger language plpgsql security definer set search_path='' as $$
declare a public.pa_ads%rowtype;begin select * into a from public.pa_ads where id=new.ad_id;
 new.fulfillment_kind:=a.fulfillment_kind;new.tiktok_quote_id:=a.tiktok_quote_id;return new;end $$;
create trigger tiktok_dm_outbox_kind before insert on app_finance.outbox for each row execute function app_tiktok_dm.prepare_outbox();

-- Exact existing checkout with a guarded identity/item branch; pricing, promo,
-- wallet, notifications and manual TikTok validation remain the established code.
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
  v_direct boolean := p_ad->>'message_destination'='direct_message';
  v_dm_quote app_tiktok_dm.quotes%rowtype;
  v_dm_account app_tiktok_dm.accounts%rowtype;
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'code', 'NOT_AUTHENTICATED');
  end if;

  if coalesce(v_direct,false) then
    select * into v_dm_quote from app_tiktok_dm.quotes where id=(p_ad->>'tiktok_quote_id')::uuid and user_id=v_user;
    if not found or not app_tiktok_dm.allowed(v_user) or v_dm_quote.expires_at<=now()
      or v_dm_quote.ad is distinct from (p_ad-array['tiktok_quote_id','payment_transaction_id','confirmation_cost_usd','confirmation_price_iqd']) then
      return jsonb_build_object('ok',false,'code','QUOTE_CHANGED');end if;
    select * into v_dm_account from app_tiktok_dm.accounts where id=v_dm_quote.account_id and user_id=v_user and status='CONNECTED';
    if not found then return jsonb_build_object('ok',false,'code','TIKTOK_ACCOUNT_UNAVAILABLE');end if;
    -- A verified existing post does not need a fabricated manual post code/URL.
    v_link:=null;v_code:=null;
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
     or (not coalesce(v_direct,false) and (char_length(v_link) not between 8 and 2048
       or v_link !~* '^https://' or char_length(v_code) not between 1 and 200))
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

  if v_goal = 'messages' and not coalesce(v_direct,false) then
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
  if coalesce(v_direct,false) then
    update public.pa_ads set platform='TIKTOK',fulfillment_kind='tiktok_conversation_auto',message_destination='direct_message',
      tiktok_quote_id=v_dm_quote.id,tiktok_account_id=v_dm_account.id,tiktok_identity_id=v_dm_account.identity_id,tiktok_item_id=p_ad->>'tiktok_item_id',
      proxo_total_budget_usd=v_gross,tiktok_declared_budget_usd=(v_dm_quote.evidence->>'declared_budget_usd')::numeric,
      spend_stop_threshold_usd=round(v_gross*0.95,6)
      where id=v_ad.id returning * into v_ad;
  end if;

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

create or replace function app_finance.submit_ad(p_submission_id uuid,p_ad jsonb,p_expected_cost_usd numeric,p_expected_price_iqd bigint,p_promo_id uuid,p_promo_code text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=app_finance.actor(); req jsonb; prev proxo_private.ad_submissions%rowtype; result jsonb; dm_check jsonb;
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
 if p_ad->>'message_destination'='direct_message' then
  dm_check:=app_tiktok_dm.check_quote(p_ad,p_promo_id,p_promo_code);
  if dm_check->>'ok' is distinct from 'true' then return dm_check;end if;
 elsif coalesce(p_ad->>'message_destination','external_contact')<>'external_contact'
   or p_ad ?| array['tiktok_account_id','tiktok_item_id','tiktok_quote_id'] then
  return jsonb_build_object('ok',false,'code','INVALID_MESSAGE_DESTINATION');
 end if;
 perform public.pa_assert_ad_allowed(u);
 result:=public.pa_create_ad(p_ad||jsonb_build_object('confirmation_cost_usd',p_expected_cost_usd,'confirmation_price_iqd',p_expected_price_iqd),p_expected_cost_usd,p_promo_id,p_promo_code,null);
 if result->>'ok'='true' then
  insert into proxo_private.ad_submissions(user_id,submission_id,request,result) values(u,p_submission_id,req,result);
  insert into app_finance.outbox(ad_id) values((result->>'ad_id')::uuid);
 end if;
 return result;
end $$;

-- Preserve generic manual queue claims; the automatic worker has its own
-- service-only claim action over these SAME outbox rows.
create or replace function public.pa_claim_ad_outbox() returns jsonb language plpgsql security definer set search_path='' as $$
declare job app_finance.outbox%rowtype;
begin
 update app_finance.outbox set status='reconcile',lease_until=null where fulfillment_kind='manual' and status='leased' and lease_until<now() and attempts>=8;
 select o.* into job from app_finance.outbox o join public.pa_ads a on a.id=o.ad_id
 where o.fulfillment_kind='manual' and (o.status='pending' or (o.status='leased' and o.lease_until<now()))
 and o.available_at<=now() and o.attempts<8 and a.status in ('pending','scheduled')
 and a.refunded_at is null and coalesce(a.tiktok_ad_id,'')=''
 order by o.available_at for update of a skip locked limit 1;
 if not found then return null;end if;
 update app_finance.outbox set status='leased',attempts=attempts+1,lease_until=now()+interval '2 minutes',lease_token=gen_random_uuid()
 where id=job.id returning * into job;return to_jsonb(job);
end $$;
create or replace function public.pa_finish_ad_outbox(p_id uuid,p_lease uuid,p_reference text,p_error text default null) returns boolean
language plpgsql security definer set search_path='' as $$
begin update app_finance.outbox set status=case when p_reference is not null then 'completed' when attempts>=8 then 'reconcile' else 'pending' end,
 external_reference=left(p_reference,200),last_error_code=left(p_error,80),lease_until=null,
 available_at=now()+make_interval(secs=>least(3600,30*(2^least(attempts,7))::integer))
 where id=p_id and fulfillment_kind='manual' and status='leased' and lease_token=p_lease and lease_until>now();return found;end $$;
create or replace function app_finance.refund_ad(p_key uuid,p_ad_id uuid,p_reason text,p_admin boolean) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=app_finance.actor();begin
 if exists(select 1 from public.pa_ads where id=p_ad_id and platform='META') then return jsonb_build_object('ok',false,'code','META_REFUND_REQUIRES_SERVER');end if;
 if exists(select 1 from public.pa_ads where id=p_ad_id and fulfillment_kind='tiktok_conversation_auto') then return jsonb_build_object('ok',false,'code','TIKTOK_REFUND_REQUIRES_SERVER');end if;
 return app_finance.refund_ad_tiktok_v2(p_key,p_ad_id,p_reason,p_admin);end $$;

create function app_tiktok_dm.protect_payment() returns trigger language plpgsql set search_path='' as $$
begin if old.tiktok_quote_id is not null and old.tiktok_quote_id is distinct from new.tiktok_quote_id then raise exception 'TIKTOK_PAYMENT_BINDING_IMMUTABLE';end if;return new;end $$;
create trigger tiktok_dm_payment_binding before update of tiktok_quote_id on public.pa_transactions for each row execute function app_tiktok_dm.protect_payment();

create function app_tiktok_dm.protect_account() returns trigger language plpgsql set search_path='' as $$
begin
 if old.user_id is distinct from new.user_id or old.identity_id is distinct from new.identity_id or old.identity_type is distinct from new.identity_type
  or old.business_center_id is distinct from new.business_center_id or old.advertiser_id is distinct from new.advertiser_id
  or old.requested_username is distinct from new.requested_username or old.owner_binding_proof is distinct from new.owner_binding_proof then
  raise exception 'TIKTOK_ACCOUNT_BINDING_IMMUTABLE';end if;return new;end $$;
create trigger tiktok_dm_account_binding before update on app_tiktok_dm.accounts for each row execute function app_tiktok_dm.protect_account();
create function app_tiktok_dm.protect_ad() returns trigger language plpgsql set search_path='' as $$
begin
 if old.fulfillment_kind='tiktok_conversation_auto' and (new.fulfillment_kind is distinct from old.fulfillment_kind
  or new.message_destination is distinct from old.message_destination or new.tiktok_quote_id is distinct from old.tiktok_quote_id
  or new.tiktok_account_id is distinct from old.tiktok_account_id or new.tiktok_item_id is distinct from old.tiktok_item_id
  or new.tiktok_identity_id is distinct from old.tiktok_identity_id or new.video_link is distinct from old.video_link
  or new.video_code is distinct from old.video_code or new.post_code is distinct from old.post_code or new.asset_id is distinct from old.asset_id
  or new.total_budget is distinct from old.total_budget or new.receipt_uid is distinct from old.receipt_uid
  or new.start_date is distinct from old.start_date or new.start_time is distinct from old.start_time or new.days is distinct from old.days
  or new.goal is distinct from old.goal or new.title is distinct from old.title or new.target_gender is distinct from old.target_gender
  or new.target_location is distinct from old.target_location or new.age_groups is distinct from old.age_groups) then
  raise exception 'TIKTOK_AUTOMATED_ORDER_IMMUTABLE';end if;return new;end $$;
create trigger tiktok_dm_order_binding before update on public.pa_ads for each row execute function app_tiktok_dm.protect_ad();

create function app_tiktok_dm.job_result(j app_finance.outbox) returns jsonb language sql stable security definer set search_path='' as $$
 select to_jsonb(j)||jsonb_build_object('user_id',a.user_id,'ad',q.ad,'configuration',q.ad,'evidence',q.evidence,'pricing',q.pricing,
 'config_hash',q.config_hash,'account',to_jsonb(c),'quote_id',q.id,'canonical_status',a.status,'start_at',(a.start_date+a.start_time) at time zone 'Asia/Baghdad',
 'end_at',((a.start_date+a.start_time) at time zone 'Asia/Baghdad')+make_interval(hours=>a.days*24),
 'proxo_total_budget_usd',a.proxo_total_budget_usd,'customer_paid_usd',a.total_budget,'declared_budget_usd',a.tiktok_declared_budget_usd,
 'spend_stop_threshold_usd',a.spend_stop_threshold_usd,'completed_at',a.completed_at,'refund_eligible_at',a.refund_eligible_at,
 'spend_stop_triggered_at',a.spend_stop_triggered_at,'stop_reason',a.stop_reason,'final_spend_usd',a.final_spend_usd)
 from public.pa_ads a join app_tiktok_dm.quotes q on q.id=j.tiktok_quote_id join app_tiktok_dm.accounts c on c.id=q.account_id where a.id=j.ad_id;
$$;

create function app_tiktok_dm.service(p_action text,p_user_id uuid default null,p_id uuid default null,p_token uuid default null,p_payload jsonb default '{}')
returns jsonb language plpgsql security definer set search_path='' as $$
declare a app_tiktok_dm.accounts%rowtype;q app_tiktok_dm.quotes%rowtype;j app_finance.outbox%rowtype;ad public.pa_ads%rowtype;debit public.pa_transactions%rowtype;
 b jsonb;e jsonb;price jsonb;result jsonb;claims text;kind text;st text;stage jsonb;observed timestamptz;observed_spend numeric;canonical text;
 v_refund_amount numeric(20,6);balance numeric(20,6);credit uuid;threshold numeric;cache_row jsonb;
begin
 if p_payload is null or jsonb_typeof(p_payload)<>'object' or octet_length(p_payload::text)>262144 then return jsonb_build_object('ok',false,'code','INVALID_INPUT');end if;
 if p_action='gate' then
  if not app_tiktok_dm.allowed(p_user_id) then return jsonb_build_object('ok',false,'code','TIKTOK_DM_DISABLED');end if;
  if not app_finance.rate_allowed(p_user_id,'tiktok_dm_preflight',30) then return jsonb_build_object('ok',false,'code','RATE_LIMITED');end if;
  return jsonb_build_object('ok',true,'enabled',true,'activation_enabled',(select activation_enabled from app_tiktok_dm.settings where singleton));end if;
 if p_action='seen' then
  if p_user_id is null or not exists(select 1 from auth.users where id=p_user_id) then return jsonb_build_object('ok',false,'code','INVALID_USER');end if;
  insert into app_tiktok_dm.preferences(user_id) values(p_user_id) on conflict(user_id) do nothing;return jsonb_build_object('ok',true);end if;
 if p_action='connect_start' or (p_action='claim' and p_payload->>'kind'='account-connect') then
  return jsonb_build_object('ok',false,'code','TIKTOK_AUTH_CORRELATION_UNAVAILABLE');end if;
 if p_action='list_accounts' then
  return jsonb_build_object('ok',true,'accounts',coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at)
  from app_tiktok_dm.accounts x where x.user_id=p_user_id and x.status<>'DISCONNECTED'),'[]'::jsonb));end if;
 if p_action in ('account','videos','cache_videos','disconnect','disconnect_complete','finish_account') then
  select * into a from app_tiktok_dm.accounts where id=p_id and (p_user_id is null or user_id=p_user_id) for update;
  if not found then return jsonb_build_object('ok',false,'code','TIKTOK_ACCOUNT_NOT_FOUND');end if;
  if p_action='account' then
   if not app_tiktok_dm.allowed(a.user_id) then return jsonb_build_object('ok',false,'code','TIKTOK_DM_DISABLED');end if;
   if a.status<>'CONNECTED' then return jsonb_build_object('ok',false,'code','TIKTOK_ACCOUNT_UNAVAILABLE');end if;
   return jsonb_build_object('ok',true,'account',to_jsonb(a));end if;
  if p_action='disconnect' then
   if a.status='DISCONNECTED' then return jsonb_build_object('ok',true,'status','DISCONNECTED');end if;
   update app_tiktok_dm.accounts set status='REVOKING',disconnect_requested_at=coalesce(disconnect_requested_at,now()),refresh_after=now(),updated_at=now() where id=a.id;
   delete from app_tiktok_dm.video_cache where account_id=a.id;
   return jsonb_build_object('ok',true,'status','REVOKING','account_id',a.id);end if;
  if p_action in ('disconnect_complete','finish_account') then
   if p_token is null or a.lease_token is distinct from p_token then return jsonb_build_object('ok',false,'code','STALE_LEASE');end if;
   if p_action='disconnect_complete' then
    if a.status<>'REVOKING' or p_payload->>'advertiser_unlinked' is distinct from 'true' then return jsonb_build_object('ok',false,'code','UNLINK_NOT_VERIFIED');end if;
    update app_tiktok_dm.accounts set status='DISCONNECTED',disconnected_at=now(),lease_token=null,lease_until=null,updated_at=now() where id=a.id;
    delete from app_tiktok_dm.video_cache where account_id=a.id;
   else update app_tiktok_dm.accounts set lease_token=null,lease_until=null,refresh_after=now()+interval '10 minutes',updated_at=now() where id=a.id;end if;
   return jsonb_build_object('ok',true);end if;
  if a.status<>'CONNECTED' or not a.can_pull_video then return jsonb_build_object('ok',false,'code','TIKTOK_ACCOUNT_UNAVAILABLE');end if;
  if p_action='videos' then
   return jsonb_build_object('ok',true,'videos',coalesce((select jsonb_agg(metadata order by item_id) from app_tiktok_dm.video_cache
    where account_id=a.id and user_id=a.user_id and expires_at>now()),'[]'::jsonb));end if;
  if p_action='cache_videos' then
   if jsonb_typeof(p_payload->'videos') is distinct from 'array' then return jsonb_build_object('ok',false,'code','INVALID_VIDEOS');end if;
   for cache_row in select value from jsonb_array_elements(p_payload->'videos') loop
    if coalesce(cache_row->>'item_id','') !~ '^[0-9]{1,30}$' or cache_row->>'status' is distinct from 'ITEM_STATUS_HESITATE_RECOMMEND'
      or cache_row->>'ad_eligible' is distinct from 'true' then continue;end if;
    insert into app_tiktok_dm.video_cache(account_id,user_id,item_id,metadata,expires_at,verified_at)
     values(a.id,a.user_id,cache_row->>'item_id',cache_row,least(now()+interval '5 minutes',coalesce((cache_row->>'expires_at')::timestamptz,now()+interval '5 minutes')),now())
     on conflict(account_id,item_id) do update set metadata=excluded.metadata,expires_at=excluded.expires_at,verified_at=excluded.verified_at;
   end loop;return jsonb_build_object('ok',true);end if;
 end if;
 if p_action='store_quote' then
  if not app_tiktok_dm.allowed(p_user_id) then return jsonb_build_object('ok',false,'code','TIKTOK_DM_DISABLED');end if;
  b:=p_payload->'ad';e:=p_payload->'evidence';
  if not app_tiktok_dm.valid_ad(b) then return jsonb_build_object('ok',false,'code','INVALID_DIRECT_MESSAGE_AD');end if;
  select * into a from app_tiktok_dm.accounts where id=(b->>'tiktok_account_id')::uuid and user_id=p_user_id and status='CONNECTED'
   and available_status='AVAILABLE' and can_pull_video and can_manage_message and message_ads_eligible for share;
  if not found then return jsonb_build_object('ok',false,'code','TIKTOK_ACCOUNT_UNAVAILABLE');end if;
  if e->>'authorized' is distinct from 'true' or e->>'ready' is distinct from 'true' or e->>'account_id' is distinct from a.id::text
   or coalesce(p_payload->>'config_hash','') !~ '^[a-f0-9]{64}$'
   or coalesce((e->>'declared_budget_usd')::numeric,0)<=0 or e->>'declared_budget_usd' in ('NaN','Infinity','-Infinity') then return jsonb_build_object('ok',false,'code','PREFLIGHT_REQUIRED');end if;
  if b->>'payment_method'='fastpay' and not (select fastpay_enabled from app_tiktok_dm.settings where singleton) then return jsonb_build_object('ok',false,'code','TIKTOK_DM_FASTPAY_UNAVAILABLE');end if;
  -- Reuse the exact current preview/pricing function for the authenticated user
  -- already verified by the API. JWT context is transaction-local and restored.
  claims:=current_setting('request.jwt.claims',true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',p_user_id,'role','service_role')::text,true);
  price:=public.pa_preview_ad(b,(p_payload->>'promo_id')::uuid,p_payload->>'promo_code');
  perform set_config('request.jwt.claims',coalesce(claims,''),true);
  if price->>'ok' is distinct from 'true' then return price;end if;
  insert into app_tiktok_dm.quotes(user_id,account_id,ad,config_hash,evidence,pricing,promo_id,promo_code)
   values(p_user_id,a.id,b,p_payload->>'config_hash',e,price,(p_payload->>'promo_id')::uuid,p_payload->>'promo_code') returning * into q;
  return price||jsonb_build_object('quote_id',q.id,'ad',b,'configuration',b,'expires_at',q.expires_at,'evidence',e,'server_time',clock_timestamp());end if;
 if p_action='claim' then
  kind:=coalesce(p_payload->>'kind','create');
  if kind in ('account-videos','account-disconnect') then
   select * into a from app_tiktok_dm.accounts x where (x.lease_until is null or x.lease_until<now()) and x.refresh_after<=now()
    and ((kind='account-disconnect' and x.status='REVOKING') or (kind='account-videos' and x.status='CONNECTED' and x.can_pull_video and app_tiktok_dm.allowed(x.user_id)))
    order by x.refresh_after for update skip locked limit 1;
   if not found then return null;end if;
   update app_tiktok_dm.accounts set lease_kind=kind,lease_token=gen_random_uuid(),lease_until=now()+interval '2 minutes' where id=a.id returning * into a;
   return to_jsonb(a)||jsonb_build_object('account',to_jsonb(a));end if;
  if kind not in ('create','status','budget','reconcile','refund') then return jsonb_build_object('ok',false,'code','INVALID_WORKER_KIND');end if;
  update app_finance.outbox x set status='reconcile',lease_until=null,last_error_code='PROVIDER_OUTCOME_UNKNOWN',
   terminal_failure=terminal_failure or (x.attempts>=8 and not exists(select 1 from jsonb_each(x.stages) t where t.value->>'state'='inflight'))
   where x.fulfillment_kind='tiktok_conversation_auto' and x.status='leased' and x.lease_until<now()
    and (x.attempts>=8 or exists(select 1 from jsonb_each(x.stages) t where t.value->>'state'='inflight'));
  update app_finance.outbox x set status='reconcile',lease_until=null,
   terminal_failure=not exists(select 1 from jsonb_each(x.stages) t where t.value->>'state'='inflight'),
   last_error_code=case when x.attempts>=8 then 'CREATE_ATTEMPTS_EXHAUSTED' else 'TIKTOK_DM_DISABLED' end
   from public.pa_ads o where o.id=x.ad_id and x.fulfillment_kind='tiktok_conversation_auto'
    and ((x.status='pending' and (not app_tiktok_dm.allowed(o.user_id) or x.attempts>=8))
     or (x.status='leased' and x.lease_until<now() and (x.attempts>=8 or not app_tiktok_dm.allowed(o.user_id))));
  select x.* into j from app_finance.outbox x join public.pa_ads o on o.id=x.ad_id
   where x.fulfillment_kind='tiktok_conversation_auto' and (p_id is null or x.id=p_id) and (p_user_id is null or o.user_id=p_user_id)
    and (x.lease_until is null or x.lease_until<now()) and x.available_at<=now() and o.unused_budget_refunded_at is null
    and ((kind='create' and x.status in ('pending','leased') and x.attempts<8 and app_tiktok_dm.allowed(o.user_id))
     or (kind in ('status','budget') and x.status='completed' and x.provider_ids ?& array['campaign','adgroup','ad']
       and not exists(select 1 from jsonb_each(x.stages) t where t.value->>'state'='inflight')
       and not (o.status in ('completed','rejected') and o.refund_eligible_at<=now()))
     or (kind='reconcile' and x.status='reconcile')
     or (kind='refund' and o.status in ('completed','rejected') and o.refund_eligible_at<=now()))
   order by x.available_at for update of x skip locked limit 1;
  if not found then return null;end if;
  update app_finance.outbox set lease_kind=kind,lease_token=gen_random_uuid(),lease_until=now()+interval '2 minutes',attempts=attempts+1,
   status=case when kind='create' then 'leased' else status end where id=j.id returning * into j;
  return app_tiktok_dm.job_result(j);end if;
 select x.* into j from app_finance.outbox x join public.pa_ads o on o.id=x.ad_id
  where x.fulfillment_kind='tiktok_conversation_auto' and (x.id=p_id or (p_action='refund' and x.ad_id=p_id)) and (p_user_id is null or o.user_id=p_user_id) for update of x;
 if not found then return jsonb_build_object('ok',false,'code','JOB_NOT_FOUND');end if;
 select * into ad from public.pa_ads where id=j.ad_id for update;
 if p_action='job' then return app_tiktok_dm.job_result(j);end if;
 if p_action='refund' then
  select * into debit from public.pa_transactions where id=ad.receipt_uid and ad_id=ad.id and user_id=ad.user_id and type='ad_payment' for update;
  if not found then return jsonb_build_object('ok',false,'code','ORIGINAL_DEBIT_NOT_FOUND');end if;
  if ad.unused_budget_refunded_at is not null then return jsonb_build_object('ok',true,'already_refunded',true,'amount',ad.unused_budget_refund_usd,'refund_transaction_id',ad.unused_budget_refund_tx_id);end if;
  if debit.status not in ('approved','refund_pending') or exists(select 1 from app_finance.ledger where original_transaction_id=debit.id and amount>0) then
   return jsonb_build_object('ok',false,'code','REFUND_RECONCILIATION_REQUIRED');end if;
  if exists(select 1 from jsonb_each(j.stages) t where t.value->>'state'='inflight') then return jsonb_build_object('ok',false,'code','PROVIDER_OUTCOME_UNKNOWN');end if;
  if j.terminal_failure and not j.provider_ids ? 'ad' and (j.provider_ids='{}'::jsonb or (j.observation->>'paused'='true'
   and (j.observation->>'spend_usd')::numeric=0 and (j.observation->>'provider_observed_at')::timestamptz>now()-interval '10 minutes')) then v_refund_amount:=debit.amount;
  else
   if ad.status not in ('completed','rejected') or ad.refund_eligible_at is null or ad.refund_eligible_at>now() then return jsonb_build_object('ok',false,'code','REFUND_WAITING_PERIOD');end if;
   if ad.spend_reconciled_at is null or ad.spend_reconciled_at<ad.refund_eligible_at or ad.spend_reconciled_at<now()-interval '10 minutes'
    or ad.final_spend_usd is null or jsonb_typeof(j.final_observation->'spend_usd') is distinct from 'number' or j.final_observation->>'settled' is distinct from 'true'
    or j.final_observation->>'paused' is distinct from 'true' then return jsonb_build_object('ok',false,'code','FINAL_SPEND_NOT_RECONCILED');end if;
   v_refund_amount:=greatest(debit.amount-ad.final_spend_usd,0);
  end if;
  if v_refund_amount>0 then
   balance:=public.pa_lock_wallet(ad.user_id);credit:=gen_random_uuid();
   update public.pa_wallets set balance=pa_wallets.balance+v_refund_amount,updated_at=now() where user_id=ad.user_id returning pa_wallets.balance into balance;
   insert into public.pa_transactions(id,user_id,type,kind,method,status,amount,currency,note,balance_after,ad_id,ad_public_id,ad_title,original_transaction_id)
    values(credit,ad.user_id,'ad_unspent_refund','ad_unspent_refund',debit.method,'approved',v_refund_amount,'USD','TikTok confirmed unused budget',balance,ad.id,ad.public_ad_id,ad.title,debit.id);
   update public.pa_transactions set status=case when v_refund_amount=debit.amount then 'refunded' else 'partially_refunded' end,
    refunded_at=now(),updated_at=now() where id=debit.id;
   update public.pa_ads set refunded_amount=v_refund_amount,refunded_at=now(),refund_tx_id=credit::text,
    payment_status=case when v_refund_amount=debit.amount then 'refunded' else 'partially_refunded' end where id=ad.id;
  end if;
  update public.pa_ads set unused_budget_refund_usd=v_refund_amount,unused_budget_refunded_at=now(),unused_budget_refund_tx_id=credit,
   status=case when j.terminal_failure and j.provider_ids='{}'::jsonb then 'rejected' else status end,updated_at=now() where id=ad.id;
  update app_finance.outbox set status='cancelled',lease_until=null,lease_token=null where id=j.id;
  return jsonb_build_object('ok',true,'amount',v_refund_amount,'refund_transaction_id',credit,'original_transaction_id',debit.id,'balance_after',balance);end if;
 if p_token is null or j.lease_token is distinct from p_token or j.lease_until is null then return jsonb_build_object('ok',false,'code','STALE_LEASE');end if;
 if p_action='intent' then
  if not app_tiktok_dm.allowed(ad.user_id) then return jsonb_build_object('ok',false,'code','TIKTOK_DM_DISABLED');end if;
  if j.lease_kind<>'create' or j.status<>'leased' or j.lease_until<=now() then return jsonb_build_object('ok',false,'code','STALE_LEASE');end if;
  st:=p_payload->>'stage';
  if coalesce(st,'') not in ('campaign','adgroup','ad') or coalesce(p_payload->>'request_hash','') !~ '^[a-f0-9]{64}$' then return jsonb_build_object('ok',false,'code','INVALID_STAGE');end if;
  if j.stages ? st then return jsonb_build_object('ok',false,'code',case when j.provider_ids ? st then 'STAGE_ALREADY_COMPLETE' else 'PROVIDER_OUTCOME_UNKNOWN' end);end if;
  if exists(select 1 from jsonb_each(j.stages) t where t.value->>'state'='inflight') or (st in ('adgroup','ad') and not j.provider_ids ? 'campaign')
   or (st='ad' and not j.provider_ids ? 'adgroup') then return jsonb_build_object('ok',false,'code','INVALID_STAGE_ORDER');end if;
  stage:=jsonb_build_object('state','inflight','request_hash',p_payload->>'request_hash','started_at',clock_timestamp());
  update app_finance.outbox set stages=jsonb_set(stages,array[st],stage),observation=null where id=j.id returning * into j;
  return jsonb_build_object('ok',true,'job',app_tiktok_dm.job_result(j));end if;
 if p_action='reject' then
  st:=p_payload->>'stage';stage:=j.stages->st;
  if stage->>'state' is distinct from 'inflight' or p_payload->>'request_hash' is distinct from stage->>'request_hash' then return jsonb_build_object('ok',false,'code','INVALID_REJECTION');end if;
  update app_finance.outbox set stages=jsonb_set(stages,array[st],stage||jsonb_build_object('state','rejected','error_code',left(p_payload->>'error_code',80))),
   terminal_failure=true,last_error_code=left(p_payload->>'error_code',80) where id=j.id returning * into j;
  return jsonb_build_object('ok',true,'job',app_tiktok_dm.job_result(j));end if;
 if p_action='complete' then
  st:=p_payload->>'stage';stage:=j.stages->st;
  if coalesce(st,'') not in ('campaign','adgroup','ad') or coalesce(p_payload->>'provider_id','') !~ '^[0-9]{1,40}$'
    or stage is null or stage->>'state' not in ('inflight','complete') then return jsonb_build_object('ok',false,'code','INVALID_STAGE');end if;
  if j.lease_kind='reconcile' and (p_payload->>'request_hash' is distinct from stage->>'request_hash' or p_payload->>'reconciled' is distinct from 'true') then return jsonb_build_object('ok',false,'code','RECONCILIATION_EVIDENCE_REQUIRED');end if;
  if j.provider_ids ? st and j.provider_ids->>st is distinct from p_payload->>'provider_id' then return jsonb_build_object('ok',false,'code','PROVIDER_ID_CONFLICT');end if;
  update app_finance.outbox set provider_ids=jsonb_set(provider_ids,array[st],to_jsonb(p_payload->>'provider_id')),
   stages=jsonb_set(stages,array[st],stage||jsonb_build_object('state','complete','provider_id',p_payload->>'provider_id','completed_at',clock_timestamp())),observation=null
   where id=j.id returning * into j;
  update public.pa_ads set tiktok_campaign_id=case when st='campaign' then p_payload->>'provider_id' else tiktok_campaign_id end,
   tiktok_adgroup_id=case when st='adgroup' then p_payload->>'provider_id' else tiktok_adgroup_id end,
   tiktok_ad_id=case when st='ad' then p_payload->>'provider_id' else tiktok_ad_id end where id=ad.id;
  return jsonb_build_object('ok',true,'job',app_tiktok_dm.job_result(j));end if;
 if p_action in ('observe','final_observe','pause_complete') then
  begin observed:=(p_payload->>'provider_observed_at')::timestamptz;observed_spend:=(p_payload->>'spend_usd')::numeric;
  exception when others then return jsonb_build_object('ok',false,'code','INVALID_OBSERVATION');end;
  if observed is null or observed>now()+interval '1 minute' or observed<now()-interval '10 minutes'
   or coalesce(jsonb_typeof(p_payload->'spend_usd'),'missing') not in ('number','null')
   or observed_spend<0 or observed_spend::text in ('NaN','Infinity','-Infinity')
   or (p_action='final_observe' and jsonb_typeof(p_payload->'spend_usd') is distinct from 'number')
   or (j.provider_ids ? 'ad' and p_payload->>'provider_ad_id' is distinct from j.provider_ids->>'ad')
   or (j.provider_ids ? 'adgroup' and p_payload->>'provider_adgroup_id' is distinct from j.provider_ids->>'adgroup')
   or (j.observation is not null and observed<(j.observation->>'provider_observed_at')::timestamptz) then return jsonb_build_object('ok',false,'code','INVALID_OBSERVATION');end if;
  if p_action='final_observe' then
   if ad.status not in ('completed','rejected') or ad.refund_eligible_at is null or observed<ad.refund_eligible_at or now()<ad.refund_eligible_at
    or p_payload->>'paused' is distinct from 'true' then return jsonb_build_object('ok',false,'code','REFUND_WAITING_PERIOD');end if;
   if ad.unused_budget_refunded_at is not null then return jsonb_build_object('ok',true,'already_reconciled',true);end if;
   if j.final_observation is not null and (j.final_observation->>'spend_usd')::numeric=observed_spend
    and observed>=(j.final_observation->>'sample_started_at')::timestamptz+interval '30 minutes'
    and p_payload->>'settlement_verified'='true' then
    update app_finance.outbox set final_observation=p_payload||jsonb_build_object('settled',true,'sample_started_at',j.final_observation->>'sample_started_at') where id=j.id;
    update public.pa_ads set final_spend_usd=observed_spend,spend_reconciled_at=observed,final_metrics_synced_at=observed where id=ad.id;
    return jsonb_build_object('ok',true,'settled',true,'final_spend_usd',observed_spend);
   end if;
   update app_finance.outbox set final_observation=p_payload||jsonb_build_object('settled',false,'sample_started_at',case
    when j.final_observation is not null and (j.final_observation->>'spend_usd')::numeric=observed_spend then (j.final_observation->>'sample_started_at')::timestamptz else observed end) where id=j.id;
   return jsonb_build_object('ok',true,'settled',false,'code','FINAL_REPORT_SETTLEMENT_PENDING');end if;
  if p_action='pause_complete' then
   if j.stop_intent is null or p_payload->>'operation_status' is distinct from 'DISABLE' or p_payload->>'paused' is distinct from 'true' then return jsonb_build_object('ok',false,'code','PAUSE_NOT_CONFIRMED');end if;
   update public.pa_ads set stop_reason=j.stop_intent->>'reason',spend_stop_triggered_at=coalesce(spend_stop_triggered_at,now()) where id=ad.id returning * into ad;
  end if;
  st:=coalesce(p_payload->>'secondary_status','');
  canonical:=case
   when ad.stop_reason='provider_failure' and j.terminal_failure then 'rejected'
   when st in ('ADGROUP_STATUS_AUDIT_DENY','AD_STATUS_AUDIT_DENY','AD_STATUS_PRIVACY_POLICY_REJECTED') then 'rejected'
   when st in ('ADGROUP_STATUS_AUDIT','ADGROUP_STATUS_REAUDIT','AD_STATUS_AUDIT','AD_STATUS_REAUDIT','AD_STATUS_PRIVACY_POLICY_AUDIT') then 'review'
   when p_payload->>'operation_status'='DISABLE' and ad.stop_reason in ('budget_limit','scheduled_end') and ad.spend_stop_triggered_at is not null then 'completed'
   when st in ('ADGROUP_STATUS_TIME_DONE','AD_STATUS_DONE') and p_payload->>'paused'='true'
    and ((ad.start_date+ad.start_time) at time zone 'Asia/Baghdad')+make_interval(hours=>ad.days*24)<=now() then 'completed'
   when ((ad.start_date+ad.start_time) at time zone 'Asia/Baghdad')>now() and st in ('ADGROUP_STATUS_NOT_START','AD_STATUS_NOT_START','ADGROUP_STATUS_DELIVERY_OK','AD_STATUS_DELIVERY_OK','ADGROUP_STATUS_DISABLE','AD_STATUS_DISABLE') then 'scheduled'
   when p_payload->>'operation_status'='ENABLE' and st in ('ADGROUP_STATUS_DELIVERY_OK','AD_STATUS_DELIVERY_OK','AD_STATUS_DELIVERY_AND_REAUDIT','AD_STATUS_REVIEW_PARTIALLY_APPROVED') then 'active'
   when p_payload->>'operation_status'='DISABLE' then 'paused'
   else ad.status end;
  if ad.status in ('completed','rejected') then canonical:=ad.status;end if;
  update app_finance.outbox set observation=p_payload,terminal_failure=terminal_failure or canonical='rejected' where id=j.id;
  update public.pa_ads set status=canonical,tiktok_operation_status=p_payload->>'operation_status',tiktok_secondary_status=st,tiktok_status_synced_at=observed,tiktok_status_checked_at=observed,
   current_spend=coalesce(observed_spend,current_spend),spend=coalesce(observed_spend,spend),last_sync=observed,data_updated_at=observed,
   provider_metrics_available=(select coalesce(jsonb_agg(distinct known.metric),'[]'::jsonb) from (
     select value metric from jsonb_array_elements(provider_metrics_available)
     union select to_jsonb('spend'::text) where observed_spend is not null
     union select to_jsonb(x.key) from jsonb_each(coalesce(p_payload->'metrics','{}'::jsonb)) x
      where x.key in ('impressions','clicks','video_views','reach','conversions') and jsonb_typeof(x.value)='number'
    ) known),
   impressions=coalesce((p_payload#>>'{metrics,impressions}')::bigint,impressions),clicks=coalesce((p_payload#>>'{metrics,clicks}')::bigint,clicks),
   video_views=coalesce((p_payload#>>'{metrics,video_views}')::bigint,video_views),reach=coalesce((p_payload#>>'{metrics,reach}')::bigint,reach),
   conversions=coalesce((p_payload#>>'{metrics,conversions}')::integer,conversions),
   completed_at=case when canonical='completed' or (canonical='rejected' and p_payload->>'paused'='true') then coalesce(completed_at,now()) else completed_at end,
   refund_eligible_at=case when canonical='completed' or (canonical='rejected' and p_payload->>'paused'='true') then coalesce(refund_eligible_at,coalesce(completed_at,now())+interval '2 hours') else refund_eligible_at end,
   stop_reason=case when canonical='completed' and stop_reason is null then 'scheduled_end' else stop_reason end,
   reject_reason=case when canonical='rejected' then left(coalesce(p_payload->>'rejection_reason',st),500) else reject_reason end,updated_at=now()
   where id=ad.id;
  return jsonb_build_object('ok',true,'status',canonical);end if;
 if p_action='stop_intent' then
  st:=p_payload->>'reason';
  if coalesce(st,'') not in ('budget_limit','scheduled_end','provider_failure') or not j.provider_ids ? 'adgroup'
   or (st='budget_limit' and (j.observation is null or jsonb_typeof(j.observation->'spend_usd') is distinct from 'number'
     or (j.observation->>'spend_usd')::numeric is null or (j.observation->>'spend_usd')::numeric<ad.spend_stop_threshold_usd
     or (j.observation->>'provider_observed_at')::timestamptz<now()-interval '10 minutes'))
   or (st='provider_failure' and not j.terminal_failure and coalesce(j.observation->>'secondary_status','') not in ('ADGROUP_STATUS_AUDIT_DENY','AD_STATUS_AUDIT_DENY','AD_STATUS_PRIVACY_POLICY_REJECTED'))
   or (st='scheduled_end' and ((ad.start_date+ad.start_time) at time zone 'Asia/Baghdad')+make_interval(hours=>ad.days*24)>now()) then return jsonb_build_object('ok',false,'code','STOP_NOT_ELIGIBLE');end if;
  update app_finance.outbox set stop_intent=coalesce(stop_intent,jsonb_build_object('reason',st,'requested_at',clock_timestamp(),'adgroup_id',j.provider_ids->>'adgroup')) where id=j.id returning * into j;
  return jsonb_build_object('ok',true,'stop_intent',j.stop_intent);end if;
 if p_action='finish' then
  st:=coalesce(p_payload->>'status','reconcile');
  if st not in ('paused','completed','reconcile','pending') then return jsonb_build_object('ok',false,'code','INVALID_JOB_STATUS');end if;
  if exists(select 1 from jsonb_each(j.stages) t where t.value->>'state'='inflight') then st:='reconcile';end if;
  if st='pending' and (not app_tiktok_dm.allowed(ad.user_id) or j.attempts>=8 or j.terminal_failure or exists(select 1 from jsonb_each(j.stages) t where t.value->>'state'='rejected')) then st:='reconcile';end if;
  update app_finance.outbox set status=case when st='paused' then 'completed' else st end,lease_token=null,lease_until=null,
   terminal_failure=terminal_failure or ((coalesce(p_payload->>'terminal_failure','false')='true' or (p_payload->>'status'='pending' and (not app_tiktok_dm.allowed(ad.user_id) or j.attempts>=8))) and not exists(select 1 from jsonb_each(j.stages) t where t.value->>'state'='inflight')),
   last_error_code=left(p_payload->>'error_code',80),available_at=now()+case when j.lease_kind in ('status','budget') then interval '1 minute' else interval '5 minutes' end where id=j.id returning * into j;
  return jsonb_build_object('ok',true,'job',app_tiktok_dm.job_result(j));end if;
 return jsonb_build_object('ok',false,'code','UNKNOWN_ACTION');
end $$;
create function public.pa_tiktok_dm_service(p_action text,p_user_id uuid default null,p_id uuid default null,p_token uuid default null,p_payload jsonb default '{}')
returns jsonb language sql security invoker set search_path='' as $$select app_tiktok_dm.service(p_action,p_user_id,p_id,p_token,p_payload);$$;

-- Keep the established FastPay service endpoint, now with a bound DM quote.
alter function app_meta.fastpay_quote(uuid,jsonb,uuid,text) rename to fastpay_quote_meta_v3;
revoke all on function app_meta.fastpay_quote_meta_v3(uuid,jsonb,uuid,text) from public,anon,authenticated,service_role;
create function app_meta.fastpay_quote(p_user_id uuid,p_ad jsonb,p_promo_id uuid,p_promo_code text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare q app_tiktok_dm.quotes%rowtype;
begin
 if p_ad->>'message_destination' is distinct from 'direct_message' then return app_meta.fastpay_quote_meta_v3(p_user_id,p_ad,p_promo_id,p_promo_code);end if;
 if not app_tiktok_dm.allowed(p_user_id) then return jsonb_build_object('ok',false,'code','TIKTOK_DM_DISABLED');end if;
 if not (select fastpay_enabled from app_tiktok_dm.settings where singleton) then return jsonb_build_object('ok',false,'code','TIKTOK_DM_FASTPAY_UNAVAILABLE');end if;
 select * into q from app_tiktok_dm.quotes where id=(p_ad->>'tiktok_quote_id')::uuid and user_id=p_user_id;
 if not found then return jsonb_build_object('ok',false,'code','QUOTE_NOT_FOUND');end if;
 if q.expires_at<=now() then return jsonb_build_object('ok',false,'code','QUOTE_EXPIRED');end if;
 if exists(select 1 from public.pa_ads where tiktok_quote_id=q.id) then return jsonb_build_object('ok',false,'code','QUOTE_ALREADY_USED');end if;
 if q.ad->>'payment_method'<>'fastpay' or q.promo_id is distinct from p_promo_id or nullif(btrim(q.promo_code),'') is distinct from nullif(btrim(p_promo_code),'') then return jsonb_build_object('ok',false,'code','QUOTE_CHANGED');end if;
 return q.pricing||jsonb_build_object('tiktok_quote_id',q.id);
end $$;
revoke all on function app_meta.fastpay_quote(uuid,jsonb,uuid,text) from public,anon,authenticated;
grant execute on function app_meta.fastpay_quote(uuid,jsonb,uuid,text) to service_role;

do $$declare t text;r record;begin
 foreach t in array array['settings','testers','preferences','connection_requests','accounts','video_cache','quotes'] loop
  execute format('alter table app_tiktok_dm.%I enable row level security',t);
  execute format('revoke all on app_tiktok_dm.%I from public,anon,authenticated,service_role',t);
 end loop;
 for r in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='app_tiktok_dm' loop
  execute format('revoke all on function %s from public,anon,authenticated,service_role',r.sig);
 end loop;
end $$;
grant execute on function app_tiktok_dm.capabilities() to authenticated;
grant execute on function app_tiktok_dm.service(text,uuid,uuid,uuid,jsonb) to service_role;
revoke all on function public.pa_tiktok_dm_service(text,uuid,uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.pa_tiktok_dm_service(text,uuid,uuid,uuid,jsonb) to service_role;
commit;
