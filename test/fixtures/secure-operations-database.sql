-- Disposable PostgreSQL fixture. Columns and purchase/quote functions captured
-- from the current implementation on 2026-10-16. No production rows/secrets.
-- External notification triggers are intentionally excluded (no real messages).
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
create schema auth;
create function auth.jwt() returns jsonb language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb; $$;
create function auth.uid() returns uuid language sql stable as $$ select nullif(auth.jwt()->>'sub','')::uuid; $$;
create function auth.role() returns text language sql stable as $$ select auth.jwt()->>'role'; $$;
grant usage on schema auth to authenticated,anon,service_role;
create table auth.users(id uuid primary key,email text,phone text,email_confirmed_at timestamptz,phone_confirmed_at timestamptz,raw_user_meta_data jsonb default '{}',last_sign_in_at timestamptz);
create table auth.sessions(id uuid primary key,user_id uuid references auth.users(id) on delete cascade,not_after timestamptz,created_at timestamptz default now());
create table public.profiles(
"id" uuid not null,
"full_name" text,
"email" text,
"avatar_b64" text,
"created_at" timestamptz default now(),
"phone" text,
"avatar_updated_at" timestamptz,
"name_updated_at" timestamptz,
"is_admin" bool default false,
"is_banned" bool default false,
"ref_code" text,
"referral_rewarded" bool default false,
"ban_reason" text,
"banned_at" timestamptz,
"device_fingerprint" text,
"avatar_url" text,
"lang_pref" text default 'ku'::text,
"balance_locked" bool default false not null,
"balance_lock_reason" text,
"balance_locked_at" timestamptz,
"balance_locked_by" uuid,
"force_logout_at" timestamptz,
"banned_ip" text,
"identity_verification_status" text,
"identity_requested_at" timestamptz,
"identity_requested_by" uuid,
"identity_selfie_path" text,
"identity_id_front_path" text,
"identity_id_back_path" text,
"identity_submitted_at" timestamptz,
"identity_reviewed_at" timestamptz,
"identity_reviewed_by" uuid,
"identity_reject_reason" text,
"is_identity_verified" bool default false not null,
"ads_locked" bool default false not null,
"ads_lock_reason" text,
"ads_locked_at" timestamptz,
"ads_locked_by" uuid,
"banned_by" uuid,
"ban_appeal_url" text,
"ban_case_id" text,
"ban_notice_id" uuid,
"ban_notice_read_at" timestamptz,
"failed_login_attempts" int4 default 0 not null,
"locked_until" timestamptz,
"login_locked_at" timestamptz,
"login_unlocked_by" uuid,
"last_login_at" timestamptz,
"last_logout_at" timestamptz
);
alter table public.profiles enable row level security;
alter table public.profiles add primary key(id);
create table public.pa_wallets(
"id" uuid default gen_random_uuid() not null,
"user_id" uuid,
"balance" float8 default 0.0,
"created_at" timestamptz default now(),
"updated_at" timestamptz default now(),
"coins_balance" int4 default 0 not null
);
alter table public.pa_wallets enable row level security;
alter table public.pa_wallets add primary key(id);
create table public.pa_transactions(
"id" uuid default gen_random_uuid() not null,
"user_id" uuid not null,
"amount" numeric not null,
"method" text,
"receipt_url" text,
"receipt_b64" text,
"status" text default 'pending'::text,
"created_at" timestamptz default now(),
"kind" text default 'deposit'::text,
"ad_number" int4,
"note" text,
"deposit_number" text,
"type" text,
"receiver_email" text,
"receiver_id" uuid,
"sender_email" text,
"sender_id" uuid,
"fee" numeric default 0,
"balance_after" numeric,
"fastpay_order_id" text,
"gateway" text,
"gateway_status" text,
"gw_transaction_id" text,
"currency" text default 'IQD'::text,
"qr_url" text,
"qr_text" text,
"expires_in" int4 default 10,
"received_amount" numeric,
"fail_reason" text,
"refund_amount" numeric,
"refund_msisdn" text,
"wallet_credited" bool default false not null,
"wallet_debited" bool default false not null,
"paid_at" timestamptz,
"refunded_at" timestamptz,
"updated_at" timestamptz default now(),
"gateway_payload" jsonb,
"gateway_amount" numeric,
"gateway_refund_amount" numeric,
"fx_rate" numeric,
"balance_before" numeric,
"public_transaction_id" text not null,
"legacy_transaction_ids" jsonb default '{}'::jsonb not null,
"tx_id" varchar not null,
"legacy_id" text,
"old_tx_id" text,
"ad_id" uuid,
"ad_public_id" text,
"ad_title" text,
"expires_at" timestamptz
);
alter table public.pa_transactions enable row level security;
alter table public.pa_transactions add primary key(id);
create table public.pa_ads(
"id" uuid default gen_random_uuid() not null,
"user_id" uuid,
"budget" float8,
"days" int4 default 1,
"target_ages" text,
"asset_id" uuid,
"status" text default 'pending'::text,
"created_at" timestamptz default now(),
"title" text,
"goal" text,
"video_code" text,
"video_link" text,
"card_id" uuid,
"start_date" date,
"start_time" time,
"age_groups" jsonb,
"gender" text default 'all'::text,
"location" text default 'kurdistan'::text,
"ad_number" text not null,
"reject_reason" text,
"impressions" int8 default 0,
"clicks" int8 default 0,
"spend" numeric default 0,
"last_sync" timestamptz default now(),
"tiktok_ad_id" text,
"current_spend" numeric default 0,
"end_date" date,
"target_budget" numeric default 0,
"tiktok_campaign_id" text,
"notified_admin" bool default false,
"daily_budget" numeric,
"total_budget" numeric,
"tiktok_url" text,
"post_code" text,
"promo_code" text,
"target_age" jsonb,
"target_gender" text,
"target_location" text,
"updated_at" timestamptz default now(),
"conversions" int4 default 0,
"conversion_rate" numeric default 0.00,
"cost_per_conversion" numeric default 0.00,
"cpm" numeric default 0.00,
"is_featured" bool default false,
"thumbnail_url" text,
"level_discount_percent" numeric,
"level_discount_iqd" numeric,
"level_name_at_purchase" text,
"prev_spend" numeric default 0,
"prev_impressions" int8 default 0,
"stop_reason" text,
"global_discount_iqd" numeric,
"direct_discount_id" uuid,
"direct_discount_iqd" numeric,
"feedback_rating" int2,
"feedback_comment" text,
"feedback_at" timestamptz,
"featured_month" int2,
"featured_year" int2,
"featured_sort" int4,
"prev_clicks" int8 default 0 not null,
"prev_conversions" int8 default 0 not null,
"previous_tiktok_ad_id" text,
"public_ad_id" text not null,
"needs_update" bool default false not null,
"update_field" text,
"update_reason" text,
"update_requested_at" timestamptz,
"update_submitted_at" timestamptz,
"likes" int8 default 0,
"comments" int8 default 0,
"follows" int8 default 0,
"prev_likes" int8 default 0 not null,
"prev_comments" int8 default 0 not null,
"prev_follows" int8 default 0 not null,
"final_metrics_synced_at" timestamptz,
"legacy_ad_number" text,
"profile_visits" int8 default 0,
"prev_profile_visits" int8 default 0,
"video_views" int8 default 0,
"prev_video_views" int8 default 0,
"shares" int8 default 0,
"prev_shares" int8 default 0,
"ctr" numeric default 0,
"cpc" numeric default 0,
"reach" int8 default 0,
"prev_reach" int8 default 0,
"data_updated_at" timestamptz,
"synced_metrics" text[],
"tiktok_operation_status" text,
"tiktok_secondary_status" text,
"tiktok_status_synced_at" timestamptz,
"refunded_amount" numeric,
"refunded_at" timestamptz,
"refunded_by" uuid,
"refund_tx_id" text,
"completed_at" timestamptz,
"usd_iqd_rate" numeric,
"price_iqd" numeric,
"service_type" text default 'tiktok'::text not null,
"service_budget_usd" numeric,
"effective_usd_iqd_rate" numeric,
"pricing_source" text,
"price_updated_at" timestamptz,
"charged_price_iqd" numeric,
"charged_usd_iqd_rate" numeric,
"asset_id_snapshot" uuid,
"asset_name_snapshot" text,
"asset_card_number_snapshot" text,
"pricing_total_iqd_snapshot" int8,
"pricing_ad_budget_iqd_snapshot" int8,
"pricing_service_fee_iqd_snapshot" int8,
"pricing_discount_iqd_snapshot" int8,
"pricing_daily_iqd_snapshot" int8,
"pricing_usd_iqd_rate_snapshot" numeric,
"pricing_days_snapshot" int4,
"pricing_payment_method_snapshot" text,
"pricing_snapshot_at" timestamptz,
"payment_method" text default 'app_balance'::text not null,
"payment_status" text default 'paid'::text not null,
"payment_transaction_id" uuid,
"device_type" text default 'all'::text not null,
"customer_note" text,
"category" text default 'other'::text not null,
"featured_week_start" date,
"receipt_uid" uuid default gen_random_uuid() not null,
"form_id" uuid
);
alter table public.pa_ads enable row level security;
alter table public.pa_ads add primary key(id);
create table public.pa_settings(
"key" text not null,
"value" text,
"updated_at" timestamptz default now()
);
alter table public.pa_settings enable row level security;
alter table public.pa_settings add primary key(key);
create table public.pa_levels(
"id" uuid default gen_random_uuid() not null,
"level_number" int4 not null,
"name_en" text not null,
"name_ku" text not null,
"min_points" numeric default 0 not null,
"discount_percent" numeric default 0 not null,
"discount_iqd" numeric default 0 not null,
"icon" text,
"color" text,
"created_at" timestamptz default now() not null
);
alter table public.pa_levels enable row level security;
alter table public.pa_levels add primary key(id);
create table public.pa_user_points(
"user_id" uuid not null,
"points" numeric default 0 not null,
"updated_at" timestamptz default now() not null
);
alter table public.pa_user_points enable row level security;
alter table public.pa_user_points add primary key(user_id);
create table public.pa_coins(
"user_id" uuid not null,
"coins_balance" int4 default 0,
"updated_at" timestamptz default now()
);
alter table public.pa_coins enable row level security;
alter table public.pa_coins add primary key(user_id);
create table public.pa_notifications(
"id" uuid default gen_random_uuid() not null,
"user_id" uuid,
"title" text not null,
"message" text,
"is_read" bool default false,
"created_at" timestamptz default now(),
"type" text default 'general'::text,
"body" text,
"related_id" uuid,
"meta" jsonb,
"updated_at" timestamptz,
"edited_by" uuid
);
alter table public.pa_notifications enable row level security;
alter table public.pa_notifications add primary key(id);
create table public.promo_codes(
"id" uuid default gen_random_uuid() not null,
"code" text not null,
"discount_type" text not null,
"discount_value" numeric not null,
"max_uses" int4 default 1 not null,
"used_count" int4 default 0 not null,
"is_active" bool default true not null,
"expires_at" timestamptz not null,
"created_by" text not null,
"description" text,
"created_at" timestamptz default now() not null,
"updated_at" timestamptz default now() not null,
"discount_iqd" int4 default 5000,
"expire_days" int4 default 3,
"restricted_to_user_id" uuid
);
alter table public.promo_codes enable row level security;
alter table public.promo_codes add primary key(id);
create table public.promo_code_usages(
"id" uuid default gen_random_uuid() not null,
"promo_code_id" uuid not null,
"user_id" text not null,
"ad_id" text,
"status" text default 'active'::text not null,
"discount_applied" numeric not null,
"used_at" timestamptz default now() not null,
"refunded_at" timestamptz,
"refund_reason" text
);
alter table public.promo_code_usages enable row level security;
alter table public.promo_code_usages add primary key(id);
create table public.proxolink_cards(
"id" uuid default gen_random_uuid() not null,
"user_id" uuid not null,
"name" text not null,
"description" text,
"avatar_b64" text,
"style" text default 'classic'::text,
"color_theme" text default '#1c2333'::text,
"platforms" jsonb default '{}'::jsonb,
"status" text default 'active'::text,
"card_number" int4 not null,
"created_at" timestamptz default now(),
"bio" text,
"html_content" text,
"checked_btns" jsonb,
"tiktok" text,
"logo_b64" text,
"video_url" text,
"tt" text,
"template_key" text,
"template_version" int4 default 1 not null,
"avatar_path" text,
"card_language" text default 'ku'::text not null,
"publish_status" text default 'creating'::text not null,
"last_publish_error_code" text,
"last_publish_error_at" timestamptz,
"published_at" timestamptz,
"updated_at" timestamptz default now() not null,
"client_request_id" uuid,
"creation_request_hash" text,
"page_type" text default 'contact'::text not null
);
alter table public.proxolink_cards enable row level security;
alter table public.proxolink_cards add primary key(id);
alter table public.pa_wallets add unique(user_id);
alter table public.profiles add foreign key(id) references auth.users(id) on delete cascade;
create schema proxo_private;
create table proxo_private.ad_submissions(user_id uuid,submission_id uuid,request jsonb,result jsonb,created_at timestamptz default now(),primary key(user_id,submission_id));
create function public.fixture_ids() returns trigger language plpgsql as $$ begin
 if tg_table_name='pa_ads' then new.public_ad_id:='AD'||substr(replace(new.id::text,'-',''),1,10);new.ad_number:=new.public_ad_id;
 else new.tx_id:='TX'||upper(substr(replace(new.id::text,'-',''),1,10));new.public_transaction_id:=new.tx_id;end if;return new;end $$;
create trigger fixture_ids before insert on public.pa_ads for each row execute function public.fixture_ids();
create trigger fixture_ids before insert on public.pa_transactions for each row execute function public.fixture_ids();
CREATE OR REPLACE FUNCTION public.pa_is_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
  SELECT COALESCE(
    (SELECT COALESCE(p.is_admin, false) AND NOT COALESCE(p.is_banned, false)
     FROM public.profiles p WHERE p.id = auth.uid()),
    false
  );
$function$;
CREATE OR REPLACE FUNCTION public.pa_lock_wallet(p_user_id uuid)
 RETURNS numeric
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_balance numeric;
begin
  insert into public.pa_wallets (user_id, balance)
  values (p_user_id, 0) on conflict (user_id) do nothing;

  select balance into v_balance
    from public.pa_wallets where user_id = p_user_id for update;

  return coalesce(v_balance, 0);
end $function$;
CREATE OR REPLACE FUNCTION public.pa_preview_ad(p_ad jsonb, p_promo_id uuid DEFAULT NULL::uuid, p_promo_code text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  p_user_id uuid := auth.uid();
  v_view_rate numeric;
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
  v_amount_iqd bigint;
begin
  if p_user_id is null or not exists (
    select 1 from auth.users u where u.id = p_user_id
  ) then
    return jsonb_build_object('ok', false, 'code', 'NOT_AUTHENTICATED');
  end if;

  begin
    v_daily := (p_ad->>'daily_budget')::numeric;
    v_days := (p_ad->>'days')::integer;
  exception when others then
    return jsonb_build_object('ok', false, 'code', 'INVALID_INPUT');
  end;

  if v_daily is null or v_days is null or v_daily not in (10,20,50,100,200,500,1000)
     or v_days not between 1 and 7 then
    return jsonb_build_object('ok', false, 'code', 'INVALID_INPUT');
  end if;

  v_gross := round(v_daily * v_days, 6);

  select coalesce(points, 0)
  into v_points
  from public.pa_user_points
  where user_id = p_user_id;

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
      );

    if not found
       or not coalesce(v_promo.is_active, false)
       or (v_promo.expires_at is not null and v_promo.expires_at <= now())
       or (v_promo.max_uses is not null and coalesce(v_promo.used_count,0) >= v_promo.max_uses)
       or (v_promo.restricted_to_user_id is not null and v_promo.restricted_to_user_id <> p_user_id)
       or exists (
         select 1
         from public.promo_code_usages u
         where u.promo_code_id = v_promo.id
           and u.user_id = p_user_id::text
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
  v_amount_iqd := greatest(round(v_cost * v_rate), 0)::bigint;


  -- Aggregate only validated recent campaigns, with a minimum sample size.
  select case when count(*) >= 5 and sum(a.impressions) >= 10000
    then round(sum(a.video_views)::numeric / sum(a.impressions), 6) end
  into v_view_rate from public.pa_ads a
  where a.goal = coalesce(p_ad->>'goal', 'views') and a.service_type = 'tiktok'
    and a.status in ('active','completed','stopped','paused')
    and a.created_at >= now() - interval '180 days'
    and a.impressions >= 1000 and a.video_views > 0 and a.video_views <= a.impressions;

  return jsonb_build_object(
    'ok', true,
    'balance_usd', coalesce((select w.balance from public.pa_wallets w where w.user_id=p_user_id),0),
    'historical_view_rate', v_view_rate,
    'level_percent', coalesce(v_level.discount_percent,0),
    'level_fixed_iqd', coalesce(v_level.discount_iqd,0),
    'promo_percent', case when v_promo.discount_type::text='percentage' then greatest(coalesce(v_promo.discount_value,0),0) else 0 end,
    'promo_fixed_iqd', case when v_promo.discount_type::text='fixed' then greatest(coalesce(v_promo.discount_value,v_promo.discount_iqd,0),0) else 0 end,
    'amount_iqd', v_amount_iqd,
    'cost_usd', v_cost,
    'gross_usd', v_gross,
    'rate', v_rate,
    'promo_discount_usd', v_promo_discount,
    'level_discount_usd', v_level_discount
  );
end;
$function$;
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
    id, user_id, type, kind, method, status, amount, note, balance_after,
    ad_id, ad_public_id, ad_title
  ) values (
    v_receipt_uid, v_user, 'ad_payment', 'ad_payment', v_payment_method, 'approved', v_cost,
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
CREATE OR REPLACE FUNCTION public.fastpay_rate()
 RETURNS numeric
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v numeric;
begin
  select nullif(value, '')::numeric into v
  from public.pa_settings
  where key = 'iqd_per_usd';

  -- never return 0 or null: a bad settings row must not divide by zero
  if v is null or v <= 0 then
    return 1800;
  end if;
  return v;
end $function$
;
CREATE OR REPLACE FUNCTION public.pa_assert_ad_allowed(p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_global jsonb;
begin
  select (value::jsonb) into v_global
  from public.pa_settings where key = 'ads_global_lock';

  if coalesce((v_global ->> 'locked')::boolean, false) then
    raise exception 'ad_submission_blocked' using errcode = 'P0001';
  end if;

  if exists (
    select 1 from public.profiles
    where id = p_user_id and coalesce(ads_locked, false)
  ) then
    raise exception 'ad_submission_blocked' using errcode = 'P0001';
  end if;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.pa_assert_balance_unlocked(p_user_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_locked boolean;
  v_reason text;
begin
  select balance_locked, balance_lock_reason into v_locked, v_reason
  from public.profiles where id = p_user_id;
  if coalesce(v_locked, false) then
    raise exception 'balance_locked: باڵانسەکەت لەلایەن بەڕێوەبەرەوە قفڵکراوە%',
      case when v_reason is not null and v_reason <> '' then ' — ' || v_reason else '' end
      using errcode = 'P0001';
  end if;
end;
$function$
;
create function public.test_assert(ok boolean,message text) returns void language plpgsql as $$ begin if ok is distinct from true then raise exception 'FAIL: %',message;end if;end $$;
-- Existing owner policies/grants; migrations must seal write permissions.
create policy fixture_owner on public.pa_wallets to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
grant select,insert,update,delete on public.pa_wallets to authenticated;
create policy fixture_owner on public.pa_transactions to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
grant select,insert,update,delete on public.pa_transactions to authenticated;
create policy fixture_owner on public.pa_ads to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
grant select,insert,update,delete on public.pa_ads to authenticated;
create policy fixture_owner on public.pa_user_points to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
grant select,insert,update,delete on public.pa_user_points to authenticated;
create policy fixture_owner on public.pa_coins to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
grant select,insert,update,delete on public.pa_coins to authenticated;
create policy fixture_owner on public.profiles to authenticated using(id=auth.uid()) with check(id=auth.uid());
grant select,insert,update,delete on public.profiles to authenticated;
grant all on all tables in schema public to service_role;

CREATE OR REPLACE FUNCTION public.pa_protect_profile_columns()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if coalesce(nullif(pg_catalog.current_setting('app.pa_profile_override', true), ''), 'off') = 'on' then
    return new;
  end if;
  if coalesce(auth.role(), '') = 'service_role' then
    return new;
  end if;
  if auth.uid() is null then
    return new;
  end if;
  if public.pa_is_admin() then
    return new;
  end if;

  new.is_admin := old.is_admin;
  new.is_banned := old.is_banned;
  new.ban_reason := old.ban_reason;
  new.banned_at := old.banned_at;
  new.banned_ip := old.banned_ip;
  new.banned_by := old.banned_by;
  new.ban_appeal_url := old.ban_appeal_url;
  new.ban_case_id := old.ban_case_id;
  new.ban_notice_id := old.ban_notice_id;
  new.ban_notice_read_at := old.ban_notice_read_at;
  new.balance_locked := old.balance_locked;
  new.balance_lock_reason := old.balance_lock_reason;
  new.balance_locked_at := old.balance_locked_at;
  new.balance_locked_by := old.balance_locked_by;
  new.force_logout_at := old.force_logout_at;
  new.ads_locked := old.ads_locked;
  new.ads_lock_reason := old.ads_lock_reason;
  new.ads_locked_at := old.ads_locked_at;
  new.ads_locked_by := old.ads_locked_by;

  -- Login lockout: only pa_login_attempt (via app.pa_profile_override) and
  -- admins may write these.
  new.failed_login_attempts := old.failed_login_attempts;
  new.locked_until := old.locked_until;
  new.login_locked_at := old.login_locked_at;

  new.identity_verification_status := old.identity_verification_status;
  new.identity_requested_at := old.identity_requested_at;
  new.identity_requested_by := old.identity_requested_by;
  new.identity_selfie_path := old.identity_selfie_path;
  new.identity_id_front_path := old.identity_id_front_path;
  new.identity_id_back_path := old.identity_id_back_path;
  new.identity_submitted_at := old.identity_submitted_at;
  new.identity_reviewed_at := old.identity_reviewed_at;
  new.identity_reviewed_by := old.identity_reviewed_by;
  new.identity_reject_reason := old.identity_reject_reason;
  new.is_identity_verified := old.is_identity_verified;

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.pa_ads_guard_refund_fields()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
  if new.refunded_amount is not distinct from old.refunded_amount
     and new.refunded_at is not distinct from old.refunded_at
     and new.refunded_by is not distinct from old.refunded_by
     and new.refund_tx_id is not distinct from old.refund_tx_id then
    return new;
  end if;

  if current_user in ('postgres', 'service_role', 'supabase_admin')
     or coalesce(auth.role(), '') = 'service_role'
     or public.pa_is_admin() then
    return new;
  end if;

  raise exception 'refund_fields_are_admin_only'
    using errcode = '42501';
end
$function$;

CREATE OR REPLACE FUNCTION public.pa_initialize_wallet_after_profile_insert()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  INSERT INTO public.pa_wallets (user_id,balance)
  VALUES (NEW.id,0)
  ON CONFLICT (user_id) DO NOTHING;
  RETURN NEW;
END
$function$;

CREATE OR REPLACE FUNCTION public.handle_ad_rejection()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if new.status = 'rejected' and old.status is distinct from 'rejected' then
    perform public.pa_lock_wallet(new.user_id);
    update public.pa_wallets
       set coins_balance = greatest(0, coalesce(coins_balance, 0) - 50),
           updated_at = now()
     where user_id = new.user_id;
  end if;
  return new;
end
$function$;

CREATE OR REPLACE FUNCTION public.pa_guard_balance_lock()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_locked boolean;
  v_reason text;
begin
  -- تەنها کەمکردنەوە دەپشکنرێت — زیادکردن هەمیشە ڕێگەپێدراوە
  if new.balance is null or old.balance is null or new.balance >= old.balance then
    return new;
  end if;

  -- بایپاسی سیستەم (n8n / فەنکشنە ئۆتۆماتیکەکان)
  if coalesce(nullif(current_setting('app.pa_balance_override', true), ''), 'off') = 'on' then
    return new;
  end if;
  if coalesce(auth.role(), '') = 'service_role' then
    return new;
  end if;
  -- ئادمین هەمیشە دەتوانێت کەم بکاتەوە
  if public.pa_is_admin() then
    return new;
  end if;

  select balance_locked, balance_lock_reason
    into v_locked, v_reason
  from public.profiles
  where id = new.user_id;

  if coalesce(v_locked, false) then
    raise exception 'balance_locked: باڵانسەکەت لەلایەن بەڕێوەبەرەوە قفڵکراوە%',
      case when v_reason is not null and v_reason <> '' then ' — ' || v_reason else '' end
      using errcode = 'P0001';
  end if;

  return new;
end;
$function$;
create trigger profile_guard before update on public.profiles for each row execute function public.pa_protect_profile_columns();
create trigger initialize_wallet after insert on public.profiles for each row execute function public.pa_initialize_wallet_after_profile_insert();
create trigger wallet_lock before update on public.pa_wallets for each row execute function public.pa_guard_balance_lock();
create trigger refund_fields before update of refunded_amount,refunded_at,refunded_by,refund_tx_id on public.pa_ads for each row execute function public.pa_ads_guard_refund_fields();
create trigger ad_rejection after update on public.pa_ads for each row execute function public.handle_ad_rejection();
revoke insert,update,delete on public.pa_user_points,public.pa_coins from authenticated;

grant update(balance) on public.pa_wallets to authenticated;
