-- The exchange screen's «پوختەی نرخ» is checked by the database before it is trusted.
--
-- ex_order_quote_preview(from, to, amount) prices an amount exactly as a new order is priced
-- (trg_ex_orders_zz_pricing → ex_orders_apply_pricing): the active ex_rates row for the route,
-- its effective value for this amount (ex_effective_rate_value_b, brackets and tiers), then
-- ex_order_quote. It also splits the total the way an approval does
-- (ex_admin_approve_order_settlement: trunc(total / 1000) * 1000 to the recipient, the rest
-- back to the balance), except for AccountBalance, which is not split.
--
-- Read only: it changes no rate, order or balance. Signed-in customers only.
create or replace function public.ex_order_quote_preview(p_from_method text, p_to_method text, p_amount numeric)
returns jsonb
language plpgsql
stable
security definer
set search_path to ''
as $f$
declare
  v_rate public.ex_rates%rowtype;
  v_effective numeric;
  v_quote jsonb;
  v_total numeric;
  v_fee numeric;
  v_split boolean;
  v_payout numeric;
begin
  if auth.uid() is null then
    raise exception 'AUTH_REQUIRED' using errcode = '42501';
  end if;
  if p_from_method is null or p_to_method is null or p_from_method = '' or p_to_method = ''
     or p_from_method = p_to_method then
    return jsonb_build_object('ok', false, 'code', 'INVALID_ROUTE');
  end if;
  if p_from_method = 'USDT' or p_to_method = 'USDT' then
    return jsonb_build_object('ok', false, 'code', 'NOT_PRICED');
  end if;
  if p_amount is null or p_amount = 'NaN'::numeric or p_amount <= 0 or p_amount > 1000000000
     or p_amount <> trunc(p_amount) then
    return jsonb_build_object('ok', false, 'code', 'INVALID_AMOUNT');
  end if;

  -- the same row the order trigger reads
  select * into v_rate from public.ex_rates
   where from_method = p_from_method and to_method = p_to_method and is_active
   limit 1;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'EXCHANGE_RATE_NOT_AVAILABLE');
  end if;

  v_effective := public.ex_effective_rate_value_b(v_rate.rate_type, v_rate.rate_value, v_rate.fee_tier_enabled,
    v_rate.fee_tier_limit_iqd, v_rate.fee_tier_low_percent, v_rate.fee_tier_high_percent, v_rate.fee_brackets, p_amount);
  v_quote := public.ex_order_quote(p_amount, v_rate.rate_type, v_effective);
  v_total := (v_quote->>'total')::numeric;
  v_fee := (v_quote->>'fee')::numeric;

  v_split := p_to_method <> 'AccountBalance';
  v_payout := case when v_split then trunc(v_total / 1000) * 1000 else v_total end;

  return jsonb_build_object(
    'ok', true,
    'from_method', p_from_method,
    'to_method', p_to_method,
    'amount', p_amount,
    'fee', v_fee,
    'total', v_total,
    'split', v_split,
    'payout_iqd', v_payout,
    'remainder_iqd', v_total - v_payout,
    'rate_type', v_rate.rate_type,
    'rate_value', v_effective,
    'rate_updated_at', v_rate.updated_at
  );
end
$f$;

revoke all on function public.ex_order_quote_preview(text, text, numeric) from public, anon;
grant execute on function public.ex_order_quote_preview(text, text, numeric) to authenticated;

comment on function public.ex_order_quote_preview(text, text, numeric) is
  'Exchange price summary: prices an amount exactly as ex_orders_apply_pricing does and splits it as an approval does. Read only.';
