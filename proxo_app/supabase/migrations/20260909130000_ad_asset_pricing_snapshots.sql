-- Keep historical communication-asset and pricing data on the ad itself.
-- These fields are deliberately denormalized: deleting/renaming an asset or
-- changing pricing rules must never rewrite what an existing ad displayed.

alter table public.pa_ads
  add column if not exists asset_id_snapshot uuid,
  add column if not exists asset_name_snapshot text,
  add column if not exists asset_card_number_snapshot text,
  add column if not exists pricing_total_iqd_snapshot bigint,
  add column if not exists pricing_ad_budget_iqd_snapshot bigint,
  add column if not exists pricing_service_fee_iqd_snapshot bigint,
  add column if not exists pricing_discount_iqd_snapshot bigint,
  add column if not exists pricing_daily_iqd_snapshot bigint,
  add column if not exists pricing_usd_iqd_rate_snapshot numeric(12, 4),
  add column if not exists pricing_days_snapshot integer,
  add column if not exists pricing_payment_method_snapshot text,
  add column if not exists pricing_snapshot_at timestamptz;

-- Backfill the stable asset id first. This also covers assets that were already
-- deleted before this migration and therefore can no longer be joined by name.
update public.pa_ads
set asset_id_snapshot = asset_id
where asset_id_snapshot is null
  and asset_id is not null;

-- Backfill the readable identity for assets that still exist. The owner check
-- prevents an incorrect cross-account snapshot if bad legacy data is present.
update public.pa_ads as ad
set
  asset_name_snapshot = coalesce(ad.asset_name_snapshot, asset.name),
  asset_card_number_snapshot = coalesce(
    ad.asset_card_number_snapshot,
    asset.card_number::text
  )
from public.proxolink_cards as asset
where asset.id = ad.asset_id
  and asset.user_id = ad.user_id
  and (
    ad.asset_name_snapshot is null
    or ad.asset_card_number_snapshot is null
  );

-- Calculate one immutable financial record for every legacy ad. Prefer the
-- exact IQD charge/rate saved by the payment path; USD is only a fallback.
with inputs as (
  select
    ad.id,
    greatest(
      coalesce(
        nullif(ad.charged_usd_iqd_rate, 0),
        nullif(ad.effective_usd_iqd_rate, 0),
        nullif(ad.usd_iqd_rate, 0),
        1800
      ),
      0.0001
    )::numeric as rate,
    greatest(
      coalesce(
        nullif(ad.days, 0),
        case
          when ad.start_date is not null and ad.end_date is not null
            then nullif(ad.end_date - ad.start_date, 0)
        end,
        1
      ),
      1
    )::integer as duration_days,
    greatest(coalesce(ad.total_budget, ad.budget, 0), 0)::numeric
      as paid_usd,
    case
      when ad.daily_budget > 0 then ad.daily_budget::numeric
    end as daily_usd,
    greatest(
      coalesce(ad.global_discount_iqd, 0)
      + coalesce(ad.direct_discount_iqd, 0)
      + coalesce(ad.level_discount_iqd, 0),
      0
    )::numeric as recorded_discount_iqd,
    case
      when ad.service_budget_usd > 0 then ad.service_budget_usd::numeric
    end as recorded_service_usd,
    ad.charged_price_iqd,
    ad.price_iqd,
    ad.created_at
  from public.pa_ads as ad
), calculated as (
  select
    i.*,
    case
      when i.daily_usd is not null
        then i.daily_usd * i.duration_days
    end as gross_usd,
    greatest(
      round(coalesce(i.charged_price_iqd, i.price_iqd, i.paid_usd * i.rate)),
      0
    )::bigint as total_iqd
  from inputs as i
), amounts as (
  select
    c.*,
    greatest(
      case
        when c.gross_usd is not null
          then round(c.gross_usd * 0.20 * c.rate)
        when c.recorded_service_usd is not null
          then round(c.recorded_service_usd * c.rate)
        else 0
      end,
      0
    )::bigint as service_iqd,
    greatest(
      case
        when c.gross_usd is not null
          then round(greatest(c.gross_usd - c.paid_usd, 0) * c.rate)
        else round(c.recorded_discount_iqd)
      end,
      0
    )::bigint as discount_iqd
  from calculated as c
)
update public.pa_ads as ad
set
  pricing_total_iqd_snapshot = coalesce(
    ad.pricing_total_iqd_snapshot,
    a.total_iqd
  ),
  pricing_service_fee_iqd_snapshot = coalesce(
    ad.pricing_service_fee_iqd_snapshot,
    a.service_iqd
  ),
  pricing_discount_iqd_snapshot = coalesce(
    ad.pricing_discount_iqd_snapshot,
    a.discount_iqd
  ),
  pricing_ad_budget_iqd_snapshot = coalesce(
    ad.pricing_ad_budget_iqd_snapshot,
    greatest(a.total_iqd + a.discount_iqd - a.service_iqd, 0)
  ),
  pricing_daily_iqd_snapshot = coalesce(
    ad.pricing_daily_iqd_snapshot,
    case
      when a.daily_usd is not null then round(a.daily_usd * a.rate)::bigint
      else round(a.total_iqd::numeric / a.duration_days)::bigint
    end
  ),
  pricing_usd_iqd_rate_snapshot = coalesce(
    ad.pricing_usd_iqd_rate_snapshot,
    a.rate
  ),
  pricing_days_snapshot = coalesce(
    ad.pricing_days_snapshot,
    a.duration_days
  ),
  pricing_payment_method_snapshot = coalesce(
    ad.pricing_payment_method_snapshot,
    'app_balance'
  ),
  pricing_snapshot_at = coalesce(
    ad.pricing_snapshot_at,
    a.created_at,
    now()
  )
from amounts as a
where a.id = ad.id;

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
  -- Asset snapshots may be refreshed only if the selected asset (or owner)
  -- changes. Renaming/deleting the source asset cannot modify old snapshots.
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

  -- Pricing is captured exactly once. Later status, metric or admin updates
  -- cannot silently change an ad's historical financial breakdown.
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
  new.pricing_payment_method_snapshot := 'app_balance';
  new.pricing_snapshot_at := coalesce(new.created_at, now());

  return new;
end;
$$;

revoke all on function public.pa_ads_capture_snapshots()
from public, anon, authenticated;

drop trigger if exists pa_ads_capture_snapshots_before_write
on public.pa_ads;

create trigger pa_ads_capture_snapshots_before_write
before insert or update on public.pa_ads
for each row
execute function public.pa_ads_capture_snapshots();

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'pa_ads_pricing_snapshots_nonnegative'
      and conrelid = 'public.pa_ads'::regclass
  ) then
    alter table public.pa_ads
      add constraint pa_ads_pricing_snapshots_nonnegative check (
        coalesce(pricing_total_iqd_snapshot, 0) >= 0
        and coalesce(pricing_ad_budget_iqd_snapshot, 0) >= 0
        and coalesce(pricing_service_fee_iqd_snapshot, 0) >= 0
        and coalesce(pricing_discount_iqd_snapshot, 0) >= 0
        and coalesce(pricing_daily_iqd_snapshot, 0) >= 0
        and coalesce(pricing_usd_iqd_rate_snapshot, 0) >= 0
        and coalesce(pricing_days_snapshot, 0) >= 0
      );
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname = 'pa_ads_pricing_payment_method_valid'
      and conrelid = 'public.pa_ads'::regclass
  ) then
    alter table public.pa_ads
      add constraint pa_ads_pricing_payment_method_valid check (
        pricing_payment_method_snapshot is null
        or pricing_payment_method_snapshot = 'app_balance'
      );
  end if;
end
$$;

comment on column public.pa_ads.asset_id_snapshot is
  'Immutable communication asset id recorded on the ad.';
comment on column public.pa_ads.asset_name_snapshot is
  'Communication asset name at selection time; survives rename/deletion.';
comment on column public.pa_ads.asset_card_number_snapshot is
  'Readable communication asset number at selection time.';
comment on column public.pa_ads.pricing_total_iqd_snapshot is
  'Exact total charged in IQD when the ad was created.';
comment on column public.pa_ads.pricing_ad_budget_iqd_snapshot is
  'Ad-delivery budget in IQD captured at creation.';
comment on column public.pa_ads.pricing_service_fee_iqd_snapshot is
  'Service fee in IQD captured at creation.';
comment on column public.pa_ads.pricing_discount_iqd_snapshot is
  'Combined coupon and level discount in IQD captured at creation.';
comment on column public.pa_ads.pricing_daily_iqd_snapshot is
  'Daily amount in IQD captured at creation.';
comment on column public.pa_ads.pricing_usd_iqd_rate_snapshot is
  'USD/IQD exchange rate used for the creation-time pricing snapshot.';
comment on column public.pa_ads.pricing_days_snapshot is
  'Campaign duration used for the creation-time pricing snapshot.';
comment on column public.pa_ads.pricing_payment_method_snapshot is
  'Creation-time payment method enum; currently app_balance.';
comment on column public.pa_ads.pricing_snapshot_at is
  'Timestamp at which the immutable pricing snapshot was captured.';
