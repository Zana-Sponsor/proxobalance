-- Correct the notification relation fields used by the atomic RPCs.
create or replace function public.pa_create_ad(
  p_ad jsonb,
  p_cost_usd numeric,
  p_promo_id uuid default null,
  p_promo_code text default null,
  p_promo_discount numeric default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user uuid := auth.uid();
  v_goal text := lower(btrim(coalesce(p_ad->>'goal', '')));
  v_title text := btrim(coalesce(p_ad->>'title', ''));
  v_link text := btrim(coalesce(p_ad->>'video_link', ''));
  v_code text := btrim(coalesce(p_ad->>'video_code', ''));
  v_gender text := lower(btrim(coalesce(p_ad->>'gender', 'all')));
  v_location text := lower(btrim(coalesce(p_ad->>'location', 'kurdistan')));
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
  v_status text;
  v_asset_id uuid;
  v_ad public.pa_ads%rowtype;
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'code', 'NOT_AUTHENTICATED');
  end if;

  begin
    v_daily := (p_ad->>'daily_budget')::numeric;
    v_days := (p_ad->>'days')::integer;
    v_start_date := coalesce(nullif(p_ad->>'start_date', '')::date, current_date);
    v_start_time := coalesce(nullif(p_ad->>'start_time', '')::time, localtime(0));
    v_asset_id := nullif(p_ad->>'asset_id', '')::uuid;
  exception when others then
    return jsonb_build_object('ok', false, 'code', 'INVALID_INPUT');
  end;

  if char_length(v_title) not between 1 and 120
     or char_length(v_link) not between 8 and 2048
     or v_link !~* '^https://'
     or char_length(v_code) not between 1 and 200
     or v_goal not in ('views', 'messages')
     or v_gender not in ('all', 'male', 'female')
     or v_location not in ('all', 'kurdistan', 'iraq')
     or v_daily not in (10,20,50,100,200,500,1000)
     or v_days not between 1 and 7
     or jsonb_typeof(coalesce(p_ad->'age_groups', '[]'::jsonb)) <> 'array'
  then
    return jsonb_build_object('ok', false, 'code', 'INVALID_INPUT');
  end if;

  if exists (
    select 1 from jsonb_array_elements_text(coalesce(p_ad->'age_groups','[]'::jsonb)) x(value)
    where x.value not in ('all','13-17','18-24','25-34','35-44','45-54','55+')
  ) then
    return jsonb_build_object('ok', false, 'code', 'INVALID_AGE_GROUP');
  end if;

  if v_goal = 'messages' then
    if v_asset_id is null or not exists (
      select 1 from public.proxolink_cards c
      where c.id = v_asset_id and c.user_id = v_user
    ) then
      return jsonb_build_object('ok', false, 'code', 'INVALID_ASSET');
    end if;
  else
    v_asset_id := null;
  end if;

  v_gross := round(v_daily * v_days, 6);
  select coalesce(points, 0) into v_points
    from public.pa_user_points where user_id = v_user;
  select * into v_level from public.pa_levels
   where min_points <= coalesce(v_points, 0)
   order by min_points desc limit 1;
  if found then
    v_level_discount := least(
      v_gross,
      round(v_gross * coalesce(v_level.discount_percent, 0) / 100, 6)
        + round(coalesce(v_level.discount_iqd, 0) / v_rate, 6)
    );
  end if;

  if p_promo_id is not null or coalesce(btrim(p_promo_code), '') <> '' then
    select * into v_promo
      from public.promo_codes pc
     where (p_promo_id is null or pc.id = p_promo_id)
       and (coalesce(btrim(p_promo_code), '') = '' or upper(pc.code) = upper(btrim(p_promo_code)))
     for update;
    if not found or not coalesce(v_promo.is_active, false)
       or (v_promo.expires_at is not null and v_promo.expires_at <= now())
       or (v_promo.max_uses is not null and coalesce(v_promo.used_count,0) >= v_promo.max_uses)
       or (v_promo.restricted_to_user_id is not null and v_promo.restricted_to_user_id <> v_user)
       or exists (
         select 1 from public.promo_code_usages u
          where u.promo_code_id = v_promo.id and u.user_id = v_user::text
            and u.status in ('active','consumed')
       )
    then
      return jsonb_build_object('ok', false, 'code', 'INVALID_PROMO');
    end if;
    if v_promo.discount_type::text = 'percentage' then
      v_promo_discount := round(v_gross * greatest(coalesce(v_promo.discount_value,0),0) / 100, 6);
    else
      v_promo_discount := round(greatest(coalesce(v_promo.discount_value, v_promo.discount_iqd, 0),0) / v_rate, 6);
    end if;
    v_promo_discount := least(v_gross, v_promo_discount);
  end if;

  v_cost := greatest(round(v_gross - v_level_discount - v_promo_discount, 6), 0);
  v_balance := public.pa_lock_wallet(v_user);
  if v_balance < v_cost then
    return jsonb_build_object('ok', false, 'code', 'INSUFFICIENT_FUNDS',
      'balance', v_balance, 'required', v_cost);
  end if;

  v_start_at := v_start_date + v_start_time;
  v_status := case when v_start_at > localtimestamp + interval '5 minutes'
                   then 'scheduled' else 'pending' end;

  insert into public.pa_ads (
    user_id, ad_number, status, title, goal, age_groups, gender, location,
    daily_budget, budget, days, total_budget, video_link, video_code,
    asset_id, card_id, post_code, promo_code,
    level_discount_percent, level_discount_iqd, level_name_at_purchase,
    start_date, start_time, end_date, target_age, target_gender,
    target_location, service_type, charged_price_iqd,
    charged_usd_iqd_rate, effective_usd_iqd_rate, usd_iqd_rate,
    service_budget_usd, pricing_source
  ) values (
    v_user, 'TEMP00000000', v_status, v_title, v_goal,
    coalesce(p_ad->'age_groups','["all"]'::jsonb), v_gender, v_location,
    v_daily, v_cost::double precision, v_days, v_cost, v_link, v_code,
    v_asset_id, v_asset_id, coalesce(nullif(p_ad->>'post_code',''), v_code),
    case when v_promo.id is null then null else v_promo.code end,
    coalesce(v_level.discount_percent,0), coalesce(v_level.discount_iqd,0),
    v_level.name_ku, v_start_date, v_start_time,
    v_start_date + v_days, coalesce(p_ad->'age_groups','["all"]'::jsonb),
    v_gender, v_location, 'tiktok', round(v_cost * v_rate), v_rate, v_rate,
    v_rate, v_gross, 'server_atomic_v1'
  ) returning * into v_ad;

  if v_promo.id is not null then
    insert into public.promo_code_usages
      (promo_code_id, user_id, ad_id, status, discount_applied, used_at)
    values (v_promo.id, v_user::text, v_ad.id::text, 'active',
            v_promo_discount, now());
    update public.promo_codes
       set used_count = coalesce(used_count,0) + 1, updated_at = now()
     where id = v_promo.id;
  end if;

  update public.pa_wallets
     set balance = balance - v_cost, updated_at = now()
   where user_id = v_user
  returning balance into v_balance;

  insert into public.pa_transactions (
    user_id, type, kind, status, amount, note, balance_after,
    ad_id, ad_public_id, ad_title
  ) values (
    v_user, 'ad_payment', 'ad_payment', 'approved', v_cost,
    format('ڕیکلام: %s | ئایدی ڕیکلام: %s', v_title, v_ad.public_ad_id),
    v_balance, v_ad.id, v_ad.public_ad_id, v_title
  );

  insert into public.pa_notifications
    (user_id, type, title, body, message, is_read, related_id, meta)
  values (
    v_user, v_status,
    case when v_status='scheduled' then 'ڕیکلامەکەت کات بۆ دانراوە' else 'ڕیکلامەکەت نێردرا' end,
    format('ڕیکلامی %s بە سەرکەوتوویی تۆمارکرا.', v_ad.public_ad_id),
    format('ڕیکلامی %s بە سەرکەوتوویی تۆمارکرا.', v_ad.public_ad_id),
    false, v_ad.id, jsonb_build_object('ad_number', v_ad.public_ad_id)
  );

  return jsonb_build_object(
    'ok', true, 'ad_id', v_ad.id, 'ad_number', v_ad.public_ad_id,
    'public_ad_id', v_ad.public_ad_id, 'status', v_status,
    'charged_usd', v_cost, 'gross_usd', v_gross,
    'promo_discount_usd', v_promo_discount,
    'level_discount_usd', v_level_discount,
    'balance_after', v_balance
  );
exception when unique_violation then
  raise;
end
$function$;

-- Atomic owner-only cancellation/refund; row locks prevent double refunds.
create or replace function public.pa_cancel_pending_ad(p_ad_id uuid, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user uuid := auth.uid();
  v_ad public.pa_ads%rowtype;
  v_refund numeric;
  v_balance numeric;
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'code', 'NOT_AUTHENTICATED');
  end if;
  select * into v_ad from public.pa_ads
   where id = p_ad_id and user_id = v_user for update;
  if not found then return jsonb_build_object('ok',false,'code','NOT_FOUND'); end if;
  if v_ad.status <> 'pending' or coalesce(v_ad.tiktok_ad_id,'') <> '' then
    return jsonb_build_object('ok',false,'code','NOT_CANCELLABLE');
  end if;
  if v_ad.refunded_at is not null then
    return jsonb_build_object('ok',false,'code','ALREADY_REFUNDED');
  end if;
  v_refund := greatest(coalesce(v_ad.total_budget, v_ad.budget, 0), 0);
  perform public.pa_lock_wallet(v_user);
  update public.pa_wallets set balance=balance+v_refund, updated_at=now()
   where user_id=v_user returning balance into v_balance;
  update public.pa_ads set
    status='rejected',
    reject_reason='بەکارهێنەر خۆی ڕەتیکردەوە — هۆکار: ' || left(btrim(coalesce(p_reason,'')),500),
    refunded_amount=v_refund,
    refunded_at=now(),
    refunded_by=v_user,
    updated_at=now()
   where id=v_ad.id;
  update public.promo_code_usages set
    status='refunded', refunded_at=now(), refund_reason='user_cancelled'
   where ad_id=v_ad.id::text and user_id=v_user::text and status='active';
  update public.promo_codes pc set
    used_count=greatest(coalesce(pc.used_count,0)-1,0), updated_at=now()
   where exists (
     select 1 from public.promo_code_usages u
      where u.promo_code_id=pc.id and u.ad_id=v_ad.id::text
        and u.user_id=v_user::text and u.status='refunded'
   );
  insert into public.pa_transactions
    (user_id,amount,type,kind,status,note,balance_after,ad_id,ad_public_id,ad_title)
  values (v_user,v_refund,'refund','refund','approved',
    format('گەڕانەوەی پارەی ڕیکلام %s',v_ad.public_ad_id),v_balance,
    v_ad.id,v_ad.public_ad_id,v_ad.title);
  insert into public.pa_notifications(user_id,type,title,body,message,is_read,related_id,meta)
  values(v_user,'refund','پارەکەت گەڕایەوە',
    format('پارەی ڕیکلامی %s گەڕایەوە بۆ باڵانسەکەت.',v_ad.public_ad_id),
    format('پارەی ڕیکلامی %s گەڕایەوە بۆ باڵانسەکەت.',v_ad.public_ad_id),
    false,v_ad.id,jsonb_build_object('ad_number',v_ad.public_ad_id));
  return jsonb_build_object('ok',true,'refund_usd',v_refund,'balance_after',v_balance);
end
$function$;

