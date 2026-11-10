-- Optional per-direction, amount-based fee tiers for percentage-fee and fee-like multiplier routes.
-- Existing commission values remain authoritative until an admin explicitly enables tiers.
BEGIN;

ALTER TABLE public.ex_rates
  ADD COLUMN IF NOT EXISTS fee_tier_enabled boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS fee_tier_limit_iqd bigint NOT NULL DEFAULT 500000,
  ADD COLUMN IF NOT EXISTS fee_tier_low_percent numeric,
  ADD COLUMN IF NOT EXISTS fee_tier_high_percent numeric;

ALTER TABLE public.ex_rates
  ADD CONSTRAINT ex_rates_fee_tier_limit_iqd_check
    CHECK (fee_tier_limit_iqd BETWEEN 1000 AND 1000000000),
  ADD CONSTRAINT ex_rates_fee_tier_low_percent_check
    CHECK (fee_tier_low_percent IS NULL OR fee_tier_low_percent BETWEEN 0 AND 100),
  ADD CONSTRAINT ex_rates_fee_tier_high_percent_check
    CHECK (fee_tier_high_percent IS NULL OR fee_tier_high_percent BETWEEN 0 AND 100),
  ADD CONSTRAINT ex_rates_fee_tier_config_check
    CHECK (
      NOT fee_tier_enabled OR (
        (rate_type = 'fee_percent' OR (rate_type = 'multiplier' AND rate_value BETWEEN 0 AND 1))
        AND from_method NOT IN ('USDT', 'AccountBalance')
        AND fee_tier_low_percent IS NOT NULL
        AND fee_tier_high_percent IS NOT NULL
      )
    );

-- Preserve the existing audit behavior and record the complete per-route tier
-- configuration in the same ex_change_log table used for ordinary rate edits.
CREATE OR REPLACE FUNCTION public.ex_log_rate_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  lbl text := coalesce(new.from_method,'?') || ' → ' || coalesce(new.to_method,'?');
  dir text;
  old_tiers jsonb;
  new_tiers jsonb;
begin
  new_tiers := jsonb_build_object(
    'enabled',new.fee_tier_enabled,
    'limit_iqd',new.fee_tier_limit_iqd,
    'low_percent',new.fee_tier_low_percent,
    'high_percent',new.fee_tier_high_percent
  );

  if tg_op = 'INSERT' then
    insert into public.ex_change_log(kind, from_method, to_method, label, field, old_value, new_value, direction, changed_by)
    values ('rate', new.from_method, new.to_method, lbl, 'new_route', null, new.rate_value::text, 'same', new.updated_by);
    if new.fee_tier_enabled then
      insert into public.ex_change_log(kind, from_method, to_method, label, field, old_value, new_value, direction, changed_by)
      values ('rate', new.from_method, new.to_method, lbl, 'fee_tier_config', null, new_tiers::text, 'same', new.updated_by);
    end if;
    return new;
  end if;

  if new.rate_value is distinct from old.rate_value then
    dir := case
      when new.rate_value > old.rate_value then 'up'
      when new.rate_value < old.rate_value then 'down'
      else 'same' end;
    insert into public.ex_change_log(kind, from_method, to_method, label, field, old_value, new_value, direction, changed_by)
    values ('rate', new.from_method, new.to_method, lbl, new.rate_type, old.rate_value::text, new.rate_value::text, dir, new.updated_by);
  end if;

  if new.is_active is distinct from old.is_active then
    insert into public.ex_change_log(kind, from_method, to_method, label, field, old_value, new_value, direction, changed_by)
    values ('rate', new.from_method, new.to_method, lbl, 'is_active', old.is_active::text, new.is_active::text,
            case when new.is_active then 'up' else 'down' end, new.updated_by);
  end if;

  old_tiers := jsonb_build_object(
    'enabled',old.fee_tier_enabled,
    'limit_iqd',old.fee_tier_limit_iqd,
    'low_percent',old.fee_tier_low_percent,
    'high_percent',old.fee_tier_high_percent
  );
  if new_tiers is distinct from old_tiers then
    insert into public.ex_change_log(kind, from_method, to_method, label, field, old_value, new_value, direction, changed_by)
    values ('rate', new.from_method, new.to_method, lbl, 'fee_tier_config', old_tiers::text, new_tiers::text, 'same', new.updated_by);
  end if;

  return new;
end;
$function$;

COMMIT;
