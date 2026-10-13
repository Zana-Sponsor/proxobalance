-- Lock down user-owned data and make ad purchase/refund atomic.
-- All SECURITY DEFINER functions below use an empty search_path and fully
-- qualified names. Client input never supplies a user id or authoritative price.

-- ---------------------------------------------------------------------------
-- Public, sanitised projection for the curated "best metrics" experience.
-- This deliberately contains no user_id, contact/asset data, notes or admin data.
-- ---------------------------------------------------------------------------
create table if not exists public.pa_featured_ads_public (
  id uuid primary key references public.pa_ads(id) on delete cascade,
  title text,
  goal text,
  video_link text,
  thumbnail_url text,
  clicks bigint not null default 0,
  impressions bigint not null default 0,
  spend numeric not null default 0,
  budget double precision,
  total_budget numeric,
  daily_budget numeric,
  days integer,
  status text,
  ad_number text,
  created_at timestamptz,
  is_featured boolean not null default true,
  featured_month smallint,
  featured_year smallint,
  featured_sort integer,
  updated_at timestamptz not null default now()
);

create index if not exists pa_featured_ads_public_period_idx
  on public.pa_featured_ads_public(featured_year, featured_month, featured_sort, created_at desc)
  where is_featured;

create or replace function public.pa_sync_featured_ad_public()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if tg_op = 'DELETE' then
    delete from public.pa_featured_ads_public where id = old.id;
    return old;
  end if;

  if coalesce(new.is_featured, false) then
    insert into public.pa_featured_ads_public (
      id, title, goal, video_link, thumbnail_url, clicks, impressions, spend,
      budget, total_budget, daily_budget, days, status, ad_number, created_at,
      is_featured, featured_month, featured_year, featured_sort, updated_at
    ) values (
      new.id, new.title, new.goal, new.video_link, new.thumbnail_url,
      coalesce(new.clicks, 0), coalesce(new.impressions, 0), coalesce(new.spend, 0),
      new.budget, new.total_budget, new.daily_budget, new.days, new.status,
      new.ad_number, new.created_at, true, new.featured_month, new.featured_year,
      new.featured_sort, now()
    )
    on conflict (id) do update set
      title = excluded.title,
      goal = excluded.goal,
      video_link = excluded.video_link,
      thumbnail_url = excluded.thumbnail_url,
      clicks = excluded.clicks,
      impressions = excluded.impressions,
      spend = excluded.spend,
      budget = excluded.budget,
      total_budget = excluded.total_budget,
      daily_budget = excluded.daily_budget,
      days = excluded.days,
      status = excluded.status,
      ad_number = excluded.ad_number,
      created_at = excluded.created_at,
      is_featured = true,
      featured_month = excluded.featured_month,
      featured_year = excluded.featured_year,
      featured_sort = excluded.featured_sort,
      updated_at = now();
  else
    delete from public.pa_featured_ads_public where id = new.id;
  end if;
  return new;
end;
$function$;

drop trigger if exists pa_ads_sync_featured_public on public.pa_ads;
create trigger pa_ads_sync_featured_public
after insert or update or delete on public.pa_ads
for each row execute function public.pa_sync_featured_ad_public();

insert into public.pa_featured_ads_public (
  id, title, goal, video_link, thumbnail_url, clicks, impressions, spend,
  budget, total_budget, daily_budget, days, status, ad_number, created_at,
  is_featured, featured_month, featured_year, featured_sort, updated_at
)
select id, title, goal, video_link, thumbnail_url, coalesce(clicks, 0),
       coalesce(impressions, 0), coalesce(spend, 0), budget, total_budget,
       daily_budget, days, status, ad_number, created_at, true,
       featured_month, featured_year, featured_sort, now()
from public.pa_ads
where coalesce(is_featured, false)
on conflict (id) do update set
  title = excluded.title, goal = excluded.goal,
  video_link = excluded.video_link, thumbnail_url = excluded.thumbnail_url,
  clicks = excluded.clicks, impressions = excluded.impressions,
  spend = excluded.spend, budget = excluded.budget,
  total_budget = excluded.total_budget, daily_budget = excluded.daily_budget,
  days = excluded.days, status = excluded.status, ad_number = excluded.ad_number,
  created_at = excluded.created_at, is_featured = true,
  featured_month = excluded.featured_month, featured_year = excluded.featured_year,
  featured_sort = excluded.featured_sort, updated_at = now();

alter table public.pa_featured_ads_public enable row level security;
drop policy if exists "featured public read" on public.pa_featured_ads_public;
create policy "featured public read" on public.pa_featured_ads_public
  for select to anon, authenticated using (is_featured = true);
revoke all on public.pa_featured_ads_public from public, anon, authenticated;
grant select on public.pa_featured_ads_public to anon, authenticated;
grant all on public.pa_featured_ads_public to service_role;

-- ---------------------------------------------------------------------------
-- Canonical RLS: one small policy per operation, indexed ownership predicates.
-- ---------------------------------------------------------------------------
do $block$
declare r record;
begin
  for r in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename = any(array[
        'pa_wallets','pa_ads','promo_code_usages','pa_transactions',
        'pa_challenge_progress','pa_user_points','pa_vouchers','promo_codes'
      ])
  loop
    execute format('drop policy if exists %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end
$block$;

alter table public.pa_wallets enable row level security;
create policy "wallet select own" on public.pa_wallets
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "wallet admin all" on public.pa_wallets
  for all to authenticated
  using ((select public.pa_is_admin()))
  with check ((select public.pa_is_admin()));

alter table public.pa_ads enable row level security;
create policy "ads select own" on public.pa_ads
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "ads update own" on public.pa_ads
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "ads admin all" on public.pa_ads
  for all to authenticated
  using ((select public.pa_is_admin()))
  with check ((select public.pa_is_admin()));

alter table public.promo_code_usages enable row level security;
create policy "promo usage select own" on public.promo_code_usages
  for select to authenticated
  using ((select auth.uid())::text = user_id);

alter table public.pa_transactions enable row level security;
create policy "transactions select own" on public.pa_transactions
  for select to authenticated using ((select auth.uid()) = user_id);
-- Manual deposit requests remain supported, but a caller can only create a row
-- for itself. Wallet credits are never performed by this policy.
create policy "transactions insert own" on public.pa_transactions
  for insert to authenticated with check (
    (select auth.uid()) = user_id
    and coalesce(status, 'pending') = 'pending'
    and coalesce(type, 'deposit') = 'deposit'
    and amount > 0
  );
create policy "transactions admin all" on public.pa_transactions
  for all to authenticated
  using ((select public.pa_is_admin()))
  with check ((select public.pa_is_admin()));

alter table public.pa_challenge_progress enable row level security;
create policy "challenge progress select own" on public.pa_challenge_progress
  for select to authenticated using ((select auth.uid()) = user_id);

alter table public.pa_user_points enable row level security;
create policy "points select own" on public.pa_user_points
  for select to authenticated using ((select auth.uid()) = user_id);

alter table public.pa_vouchers enable row level security;
create policy "vouchers select own" on public.pa_vouchers
  for select to authenticated using (
    (select auth.uid()) = assigned_user_id or (select auth.uid()) = used_by
  );

alter table public.promo_codes enable row level security;
create policy "promo select eligible" on public.promo_codes
  for select to authenticated using (
    is_active = true
    and (expires_at is null or expires_at > now())
    and (restricted_to_user_id is null or restricted_to_user_id = (select auth.uid()))
  );
create policy "promo admin all" on public.promo_codes
  for all to authenticated
  using ((select public.pa_is_admin()))
  with check ((select public.pa_is_admin()));

revoke all on public.pa_wallets from public, anon, authenticated;
grant select on public.pa_wallets to authenticated;
grant all on public.pa_wallets to service_role;

revoke all on public.pa_ads from public, anon, authenticated;
grant select, update on public.pa_ads to authenticated;
grant all on public.pa_ads to service_role;

revoke all on public.promo_code_usages from public, anon, authenticated;
grant select on public.promo_code_usages to authenticated;
grant all on public.promo_code_usages to service_role;

revoke all on public.pa_transactions from public, anon, authenticated;
grant select, insert on public.pa_transactions to authenticated;
grant all on public.pa_transactions to service_role;

revoke all on public.pa_challenge_progress from public, anon, authenticated;
grant select on public.pa_challenge_progress to authenticated;
grant all on public.pa_challenge_progress to service_role;

revoke all on public.pa_user_points from public, anon, authenticated;
grant select on public.pa_user_points to authenticated;
grant all on public.pa_user_points to service_role;

revoke all on public.pa_vouchers from public, anon, authenticated;
grant select on public.pa_vouchers to authenticated;
grant all on public.pa_vouchers to service_role;

revoke all on public.promo_codes from public, anon, authenticated;
grant select on public.promo_codes to authenticated;
grant all on public.promo_codes to service_role;

-- The old view joined auth.users and used owner privileges. It is now invisible
-- to browser roles and obeys underlying RLS when queried by a permitted role.
alter view public.pa_transactions_with_email set (security_invoker = true);
revoke all on public.pa_transactions_with_email from public, anon, authenticated;
grant select on public.pa_transactions_with_email to service_role;

create index if not exists pa_challenge_progress_user_idx
  on public.pa_challenge_progress(user_id);
create index if not exists pa_vouchers_assigned_user_idx
  on public.pa_vouchers(assigned_user_id) where assigned_user_id is not null;
create index if not exists pa_vouchers_used_by_idx
  on public.pa_vouchers(used_by) where used_by is not null;
create index if not exists promo_codes_restricted_user_idx
  on public.promo_codes(restricted_to_user_id) where restricted_to_user_id is not null;

-- ---------------------------------------------------------------------------
-- Atomic, server-priced ad purchase.
-- ---------------------------------------------------------------------------
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

-- Existing reward RPCs are atomic; expose them only to authenticated callers.
revoke all on function public.pa_create_ad(jsonb,numeric,uuid,text,numeric) from public, anon;
grant execute on function public.pa_create_ad(jsonb,numeric,uuid,text,numeric) to authenticated, service_role;
revoke all on function public.pa_cancel_pending_ad(uuid,text) from public, anon;
grant execute on function public.pa_cancel_pending_ad(uuid,text) to authenticated, service_role;
revoke all on function public.pa_claim_challenge(uuid) from public, anon;
grant execute on function public.pa_claim_challenge(uuid) to authenticated, service_role;
revoke all on function public.pa_redeem_voucher(text) from public, anon;
grant execute on function public.pa_redeem_voucher(text) to authenticated, service_role;

-- Remove obsolete caller-supplied-user/caller-supplied-price attack surfaces.
revoke all on function public.create_ad_and_deduct(uuid,text,text,text,numeric,uuid,uuid,date,time,text,text,text) from public, anon, authenticated;
grant execute on function public.create_ad_and_deduct(uuid,text,text,text,numeric,uuid,uuid,date,time,text,text,text) to service_role;
revoke all on function public.deduct_balance(uuid,double precision,jsonb) from public, anon, authenticated;
grant execute on function public.deduct_balance(uuid,double precision,jsonb) to service_role;
revoke all on function public.admin_add_balance(uuid,numeric,text) from public, anon, authenticated;
grant execute on function public.admin_add_balance(uuid,numeric,text) to service_role;
revoke all on function public.admin_deduct_balance(uuid,numeric,text) from public, anon, authenticated;
grant execute on function public.admin_deduct_balance(uuid,numeric,text) to service_role;
revoke all on function public.exchange_coins_for_balance(uuid) from public, anon, authenticated;
grant execute on function public.exchange_coins_for_balance(uuid) to service_role;

-- Every pa_admin_* function must reject anonymous execution. One legacy helper
-- lacks an internal admin assertion and therefore remains service-role-only.
do $block$
declare r record;
begin
  for r in
    select p.oid::regprocedure as signature, p.proname
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname like 'pa_admin_%'
  loop
    execute format('revoke all on function %s from public, anon', r.signature);
    if r.proname = 'pa_admin_unlock_login' then
      execute format('revoke all on function %s from authenticated', r.signature);
      execute format('grant execute on function %s to service_role', r.signature);
    else
      execute format('grant execute on function %s to authenticated, service_role', r.signature);
    end if;
  end loop;
end
$block$;

-- Server polling/settlement helpers must never be browser-callable.
do $block$
declare r record;
begin
  for r in
    select p.oid::regprocedure as signature
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname in (
      'fastpay_expire_stale_orders','fastpay_mark_check_failed',
      'fastpay_mark_declined','fastpay_orders_to_poll'
    )
  loop
    execute format('revoke all on function %s from public, anon, authenticated', r.signature);
    execute format('grant execute on function %s to service_role', r.signature);
  end loop;
end
$block$;

revoke all on function public.pa_sync_featured_ad_public() from public, anon, authenticated;
grant execute on function public.pa_sync_featured_ad_public() to service_role;
