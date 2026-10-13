-- Authenticated pricing preview, frozen confirmation and atomic idempotency.
-- Existing tables, relationships, pricing, Edge Functions and RLS are preserved.

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


-- Completed operations only; editing/cancellation/countdown writes nothing.
create schema if not exists proxo_private;
revoke all on schema proxo_private from public, anon, authenticated;
create table proxo_private.ad_submissions (
  user_id uuid not null references auth.users(id) on delete cascade,
  submission_id uuid not null,
  request jsonb not null,
  result jsonb not null,
  created_at timestamptz not null default now(),
  primary key (user_id,submission_id)
);
alter table proxo_private.ad_submissions enable row level security;
revoke all on proxo_private.ad_submissions from public,anon,authenticated;

create or replace function public.pa_ad_submission_status(p_submission_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_user uuid := auth.uid(); v_result jsonb;
begin
  if v_user is null then return jsonb_build_object('ok',false,'code','NOT_AUTHENTICATED'); end if;
  select s.result into v_result from proxo_private.ad_submissions s
    where s.user_id=v_user and s.submission_id=p_submission_id;
  return coalesce(v_result,jsonb_build_object('ok',false,'code','NOT_FOUND'));
end $$;

create or replace function public.pa_submit_ad(
  p_submission_id uuid, p_ad jsonb, p_expected_cost_usd numeric,
  p_expected_price_iqd bigint, p_promo_id uuid default null, p_promo_code text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_user uuid := auth.uid();
  v_request jsonb;
  v_previous proxo_private.ad_submissions%rowtype;
  v_result jsonb;
begin
  if v_user is null then return jsonb_build_object('ok',false,'code','NOT_AUTHENTICATED'); end if;
  if p_submission_id is null or p_ad is null or jsonb_typeof(p_ad)<>'object'
     or p_expected_cost_usd is null or p_expected_price_iqd is null
     or p_expected_cost_usd::text in ('NaN','Infinity','-Infinity')
     or p_expected_cost_usd<0 or p_expected_price_iqd<0 then
    return jsonb_build_object('ok',false,'code','INVALID_INPUT');
  end if;
  v_request := jsonb_build_object('ad',p_ad,'promo_id',p_promo_id,
    'promo_code',p_promo_code,'cost_usd',p_expected_cost_usd,'price_iqd',p_expected_price_iqd);
  -- Same key waits for the first transaction; different keys serialize on
  -- the existing wallet row lock inside pa_create_ad.
  perform pg_advisory_xact_lock(hashtextextended(v_user::text||':'||p_submission_id::text,0));
  select * into v_previous from proxo_private.ad_submissions s
    where s.user_id=v_user and s.submission_id=p_submission_id;
  if found then
    if v_previous.request is distinct from v_request then
      return jsonb_build_object('ok',false,'code','IDEMPOTENCY_CONFLICT');
    end if;
    return v_previous.result;
  end if;
  v_result := public.pa_create_ad(
    p_ad || jsonb_build_object('confirmation_cost_usd',p_expected_cost_usd,
      'confirmation_price_iqd',p_expected_price_iqd),
    p_expected_cost_usd,p_promo_id,p_promo_code,null);
  if v_result->>'ok'='true' then
    insert into proxo_private.ad_submissions(user_id,submission_id,request,result)
      values(v_user,p_submission_id,v_request,v_result);
  end if;
  -- Ad, wallet, ledger, coupon and retry receipt commit together; any
  -- exception rolls back the entire operation.
  return v_result;
end $$;

revoke all on function public.pa_preview_ad(jsonb,uuid,text) from public,anon;
revoke all on function public.pa_ad_submission_status(uuid) from public,anon;
revoke all on function public.pa_submit_ad(uuid,jsonb,numeric,bigint,uuid,text) from public,anon;
grant execute on function public.pa_preview_ad(jsonb,uuid,text) to authenticated;
grant execute on function public.pa_ad_submission_status(uuid) to authenticated;
grant execute on function public.pa_submit_ad(uuid,jsonb,numeric,bigint,uuid,text) to authenticated;
