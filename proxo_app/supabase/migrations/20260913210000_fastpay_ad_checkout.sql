-- Proxo ad checkout: payment ownership, device targeting, customer notes,
-- server-side schedule validation, and immutable transaction-status history.

alter table public.pa_ads
  add column if not exists payment_method text not null default 'app_balance',
  add column if not exists payment_status text not null default 'paid',
  add column if not exists payment_transaction_id uuid null,
  add column if not exists device_type text not null default 'all',
  add column if not exists customer_note text null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'pa_ads_payment_transaction_id_fkey'
      and conrelid = 'public.pa_ads'::regclass
  ) then
    alter table public.pa_ads
      add constraint pa_ads_payment_transaction_id_fkey
      foreign key (payment_transaction_id)
      references public.pa_transactions(id)
      on delete set null;
  end if;
end $$;

alter table public.pa_ads
  drop constraint if exists pa_ads_payment_method_valid,
  add constraint pa_ads_payment_method_valid
    check (payment_method in ('app_balance', 'fastpay')),
  drop constraint if exists pa_ads_payment_status_valid,
  add constraint pa_ads_payment_status_valid
    check (payment_status in ('paid', 'failed', 'refunded', 'partially_refunded')),
  drop constraint if exists pa_ads_device_type_valid,
  add constraint pa_ads_device_type_valid
    check (device_type in ('all', 'iphone', 'android')),
  drop constraint if exists pa_ads_customer_note_length,
  add constraint pa_ads_customer_note_length
    check (customer_note is null or char_length(customer_note) <= 500),
  drop constraint if exists pa_ads_tiktok_video_link_valid,
  add constraint pa_ads_tiktok_video_link_valid
    check (
      video_link ~* '^https://([[:alnum:]-]+\.)*tiktok\.com([/:?#]|$)'
    ) not valid,
  drop constraint if exists pa_ads_pricing_payment_method_valid,
  add constraint pa_ads_pricing_payment_method_valid
    check (
      pricing_payment_method_snapshot is null
      or pricing_payment_method_snapshot in ('app_balance', 'fastpay')
    );

create unique index if not exists pa_ads_payment_transaction_unique
  on public.pa_ads(payment_transaction_id)
  where payment_transaction_id is not null;

create table if not exists public.pa_transaction_events (
  id bigint generated always as identity primary key,
  transaction_id uuid not null
    references public.pa_transactions(id) on delete cascade,
  user_id uuid not null
    references auth.users(id) on delete cascade,
  event_type text not null,
  status text null,
  gateway_status text null,
  source text not null default 'database',
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.pa_transaction_events enable row level security;

revoke all on table public.pa_transaction_events from anon;
revoke insert, update, delete, truncate, references, trigger
  on table public.pa_transaction_events from authenticated;
grant select on table public.pa_transaction_events to authenticated;
grant all on table public.pa_transaction_events to service_role;
grant usage, select on sequence public.pa_transaction_events_id_seq to service_role;

drop policy if exists pa_transaction_events_select_own
  on public.pa_transaction_events;
create policy pa_transaction_events_select_own
  on public.pa_transaction_events
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create index if not exists pa_transaction_events_user_created_idx
  on public.pa_transaction_events(user_id, created_at desc);
create index if not exists pa_transaction_events_tx_created_idx
  on public.pa_transaction_events(transaction_id, created_at asc);

create schema if not exists private;

create or replace function private.pa_log_transaction_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event_type text;
  v_event_types text[] := array[]::text[];
begin
  if tg_op = 'INSERT' then
    v_event_types := array['created'];
  else
    if new.gateway_status is distinct from old.gateway_status then
      v_event_types := array_append(v_event_types, 'gateway_status_changed');
    end if;
    if new.status is distinct from old.status then
      v_event_types := array_append(v_event_types, 'status_changed');
    end if;
    if new.ad_id is distinct from old.ad_id and new.ad_id is not null then
      v_event_types := array_append(v_event_types, 'linked_to_ad');
    end if;
    if new.fail_reason is distinct from old.fail_reason then
      v_event_types := array_append(v_event_types, 'check_result');
    end if;
    if new.paid_at is distinct from old.paid_at and new.paid_at is not null then
      v_event_types := array_append(v_event_types, 'paid');
    end if;
    if new.refunded_at is distinct from old.refunded_at
       and new.refunded_at is not null then
      v_event_types := array_append(v_event_types, 'refunded');
    end if;
  end if;

  foreach v_event_type in array v_event_types loop
    insert into public.pa_transaction_events (
      transaction_id,
      user_id,
      event_type,
      status,
      gateway_status,
      source,
      details
    ) values (
      new.id,
      new.user_id,
      v_event_type,
      new.status,
      new.gateway_status,
      case
        when new.gateway = 'fastpay' then 'fastpay'
        when new.type = 'ad_payment' then 'ad_checkout'
        else 'database'
      end,
      jsonb_strip_nulls(jsonb_build_object(
        'method', new.method,
        'kind', new.kind,
        'type', new.type,
        'amount', new.amount,
        'currency', new.currency,
        'gateway_amount', new.gateway_amount,
        'received_amount', new.received_amount,
        'fastpay_order_id', new.fastpay_order_id,
        'gw_transaction_id', new.gw_transaction_id,
        'ad_id', new.ad_id,
        'fail_reason', new.fail_reason
      ))
    );
  end loop;

  return new;
end;
$$;

revoke all on function private.pa_log_transaction_event() from public;
revoke all on function private.pa_log_transaction_event() from anon;
revoke all on function private.pa_log_transaction_event() from authenticated;

drop trigger if exists trg_pa_transactions_event_history
  on public.pa_transactions;
create trigger trg_pa_transactions_event_history
after insert or update of status, gateway_status, ad_id, fail_reason, paid_at, refunded_at
on public.pa_transactions
for each row execute function private.pa_log_transaction_event();

create or replace function public.pa_ads_capture_snapshots()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  snapshot_asset_name text;
  snapshot_asset_number text;
  snapshot_rate numeric;
  snapshot_days integer;
  paid_usd numeric;
  gross_usd numeric;
  total_iqd bigint;
  service_iqd bigint;
  discount_iqd bigint;
  recorded_discount_iqd numeric;
begin
  if tg_op = 'INSERT'
     or new.asset_id is distinct from old.asset_id
     or new.user_id is distinct from old.user_id then
    new.asset_id_snapshot := new.asset_id;
    new.asset_name_snapshot := null;
    new.asset_card_number_snapshot := null;

    if new.asset_id is not null then
      select asset.name, asset.card_number::text
      into snapshot_asset_name, snapshot_asset_number
      from public.proxolink_cards as asset
      where asset.id = new.asset_id
        and asset.user_id = new.user_id;

      new.asset_name_snapshot := snapshot_asset_name;
      new.asset_card_number_snapshot := snapshot_asset_number;
    end if;
  else
    new.asset_id_snapshot := old.asset_id_snapshot;
    new.asset_name_snapshot := old.asset_name_snapshot;
    new.asset_card_number_snapshot := old.asset_card_number_snapshot;
  end if;

  if tg_op = 'UPDATE' then
    new.pricing_total_iqd_snapshot := old.pricing_total_iqd_snapshot;
    new.pricing_ad_budget_iqd_snapshot := old.pricing_ad_budget_iqd_snapshot;
    new.pricing_service_fee_iqd_snapshot := old.pricing_service_fee_iqd_snapshot;
    new.pricing_discount_iqd_snapshot := old.pricing_discount_iqd_snapshot;
    new.pricing_daily_iqd_snapshot := old.pricing_daily_iqd_snapshot;
    new.pricing_usd_iqd_rate_snapshot := old.pricing_usd_iqd_rate_snapshot;
    new.pricing_days_snapshot := old.pricing_days_snapshot;
    new.pricing_payment_method_snapshot := old.pricing_payment_method_snapshot;
    new.pricing_snapshot_at := old.pricing_snapshot_at;
    return new;
  end if;

  snapshot_rate := greatest(
    coalesce(
      nullif(new.charged_usd_iqd_rate, 0),
      nullif(new.effective_usd_iqd_rate, 0),
      nullif(new.usd_iqd_rate, 0),
      1800
    ),
    0.0001
  );
  snapshot_days := greatest(
    coalesce(
      nullif(new.days, 0),
      case
        when new.start_date is not null and new.end_date is not null
          then nullif(new.end_date - new.start_date, 0)
      end,
      1
    ),
    1
  );
  paid_usd := greatest(coalesce(new.total_budget, new.budget, 0), 0);
  gross_usd := case
    when new.daily_budget > 0 then new.daily_budget * snapshot_days
  end;
  recorded_discount_iqd := greatest(
    coalesce(new.global_discount_iqd, 0)
    + coalesce(new.direct_discount_iqd, 0)
    + coalesce(new.level_discount_iqd, 0),
    0
  );

  total_iqd := greatest(
    round(coalesce(
      new.charged_price_iqd,
      new.price_iqd,
      paid_usd * snapshot_rate
    )),
    0
  )::bigint;
  service_iqd := greatest(
    case
      when gross_usd is not null
        then round(gross_usd * 0.20 * snapshot_rate)
      when new.service_budget_usd > 0
        then round(new.service_budget_usd * snapshot_rate)
      else 0
    end,
    0
  )::bigint;
  discount_iqd := greatest(
    case
      when gross_usd is not null
        then round(greatest(gross_usd - paid_usd, 0) * snapshot_rate)
      else round(recorded_discount_iqd)
    end,
    0
  )::bigint;

  new.pricing_total_iqd_snapshot := total_iqd;
  new.pricing_service_fee_iqd_snapshot := service_iqd;
  new.pricing_discount_iqd_snapshot := discount_iqd;
  new.pricing_ad_budget_iqd_snapshot := greatest(
    total_iqd + discount_iqd - service_iqd,
    0
  );
  new.pricing_daily_iqd_snapshot := case
    when new.daily_budget > 0
      then round(new.daily_budget * snapshot_rate)::bigint
    else round(total_iqd::numeric / snapshot_days)::bigint
  end;
  new.pricing_usd_iqd_rate_snapshot := snapshot_rate;
  new.pricing_days_snapshot := snapshot_days;
  new.pricing_payment_method_snapshot := coalesce(new.payment_method, 'app_balance');
  new.pricing_snapshot_at := coalesce(new.created_at, now());

  return new;
end;
$$;

-- n8n calls this with the user id obtained from Supabase Auth. The phone never
-- decides the gateway amount: the same rate, level and promo rules used by
-- pa_create_ad are recomputed here immediately before the FastPay QR is made.
create or replace function public.pa_quote_ad_checkout(
  p_user_id uuid,
  p_ad jsonb,
  p_promo_id uuid default null,
  p_promo_code text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
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
    return jsonb_build_object('ok', false, 'code', 'INVALID_USER');
  end if;

  begin
    v_daily := (p_ad->>'daily_budget')::numeric;
    v_days := (p_ad->>'days')::integer;
  exception when others then
    return jsonb_build_object('ok', false, 'code', 'INVALID_INPUT');
  end;

  if v_daily not in (10,20,50,100,200,500,1000)
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

  if v_amount_iqd < 1000 then
    return jsonb_build_object('ok', false, 'code', 'AMOUNT_TOO_SMALL');
  end if;

  return jsonb_build_object(
    'ok', true,
    'amount_iqd', v_amount_iqd,
    'cost_usd', v_cost,
    'gross_usd', v_gross,
    'rate', v_rate,
    'promo_discount_usd', v_promo_discount,
    'level_discount_usd', v_level_discount
  );
end;
$$;

revoke all on function public.pa_quote_ad_checkout(uuid,jsonb,uuid,text) from public;
revoke all on function public.pa_quote_ad_checkout(uuid,jsonb,uuid,text) from anon;
revoke all on function public.pa_quote_ad_checkout(uuid,jsonb,uuid,text) from authenticated;
grant execute on function public.pa_quote_ad_checkout(uuid,jsonb,uuid,text)
  to service_role;

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
as $$
declare
  v_user uuid := auth.uid();
  v_goal text := lower(btrim(coalesce(p_ad->>'goal', '')));
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

  if v_payment_method = 'fastpay' then
    if v_payment_transaction_id is null then
      return jsonb_build_object('ok', false, 'code', 'FASTPAY_TRANSACTION_REQUIRED');
    end if;

    select *
    into v_payment_tx
    from public.pa_transactions t
    where t.id = v_payment_transaction_id
      and t.user_id = v_user
      and t.method = 'fastpay'
      and t.gateway = 'fastpay'
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
    user_id, ad_number, status, title, goal, age_groups, gender, location,
    daily_budget, budget, days, total_budget, video_link, video_code,
    asset_id, card_id, post_code, promo_code,
    level_discount_percent, level_discount_iqd, level_name_at_purchase,
    start_date, start_time, end_date, target_age, target_gender,
    target_location, service_type, charged_price_iqd,
    charged_usd_iqd_rate, effective_usd_iqd_rate, usd_iqd_rate,
    service_budget_usd, pricing_source,
    device_type, customer_note, payment_method, payment_status,
    payment_transaction_id
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
    v_rate, v_gross, 'server_atomic_v2',
    v_device_type, v_customer_note, v_payment_method, 'paid',
    v_payment_transaction_id
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
    user_id, type, kind, method, status, amount, note, balance_after,
    ad_id, ad_public_id, ad_title
  ) values (
    v_user, 'ad_payment', 'ad_payment', v_payment_method, 'approved', v_cost,
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
      'device_type', v_device_type
    )
  );

  return jsonb_build_object(
    'ok', true,
    'ad_id', v_ad.id,
    'ad_number', v_ad.public_ad_id,
    'public_ad_id', v_ad.public_ad_id,
    'status', v_status,
    'payment_method', v_payment_method,
    'payment_status', 'paid',
    'payment_transaction_id', v_payment_transaction_id,
    'charged_usd', v_cost,
    'gross_usd', v_gross,
    'promo_discount_usd', v_promo_discount,
    'level_discount_usd', v_level_discount,
    'balance_after', v_balance
  );
exception when unique_violation then
  raise;
end;
$$;

revoke all on function public.pa_create_ad(jsonb,numeric,uuid,text,numeric) from public;
revoke all on function public.pa_create_ad(jsonb,numeric,uuid,text,numeric) from anon;
grant execute on function public.pa_create_ad(jsonb,numeric,uuid,text,numeric)
  to authenticated, service_role;
