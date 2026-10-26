-- Historical installed routines, retrieved read-only 2026-10-26.
-- Test fixture only: the migration delegates the installed baseline; it does not deploy these weaker definitions.
-- Payment settlement always comes from the reviewed secure_financial_operations migration.

CREATE OR REPLACE FUNCTION public.fastpay_create_order(p_user_id uuid, p_order_id text, p_amount numeric, p_currency text DEFAULT 'IQD'::text, p_qr_url text DEFAULT NULL::text, p_qr_text text DEFAULT NULL::text, p_expires_in integer DEFAULT 10, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_existing public.pa_transactions%rowtype;
  v_rate numeric; v_usd numeric; v_id uuid; v_expires timestamptz;
begin
  if p_user_id is null or p_order_id is null or p_amount is null then
    return jsonb_build_object('ok', false, 'code', 'MISSING_ARGUMENTS');
  end if;
  if p_amount <= 0 then
    return jsonb_build_object('ok', false, 'code', 'INVALID_AMOUNT', 'amount', p_amount);
  end if;

  v_rate := public.fastpay_rate();
  v_usd  := round(p_amount / v_rate, 6);
  if v_usd <= 0 then
    return jsonb_build_object('ok', false, 'code', 'AMOUNT_TOO_SMALL',
                              'bill_amount', p_amount, 'fx_rate', v_rate);
  end if;

  v_expires := now() + (coalesce(p_expires_in, 10) * interval '1 minute');

  select * into v_existing from public.pa_transactions
   where fastpay_order_id = p_order_id for update;

  if found and coalesce(v_existing.gateway_status,'CREATED') not in ('CREATED','EXPIRED') then
    return jsonb_build_object('ok', false, 'code', 'ORDER_ALREADY_FINALIZED',
      'transaction_id', v_existing.id, 'gateway_status', v_existing.gateway_status);
  end if;

  insert into public.pa_transactions (
    user_id, amount, gateway_amount, fx_rate, currency,
    method, kind, type, status, note,
    gateway, gateway_status, fastpay_order_id, qr_url, qr_text,
    expires_in, expires_at)
  values (
    p_user_id, v_usd, p_amount, v_rate, coalesce(p_currency,'IQD'),
    'fastpay', 'deposit', 'deposit', 'pending', p_note,
    'fastpay', 'CREATED', p_order_id, p_qr_url, p_qr_text,
    coalesce(p_expires_in,10), v_expires)
  on conflict (fastpay_order_id) do update
    set amount = excluded.amount, gateway_amount = excluded.gateway_amount,
        fx_rate = excluded.fx_rate, currency = excluded.currency,
        method = 'fastpay', qr_url = excluded.qr_url, qr_text = excluded.qr_text,
        expires_in = excluded.expires_in,
        expires_at = excluded.expires_at,   -- the fix: fresh window on retry
        status = 'pending', gateway_status = 'CREATED',
        fail_reason = null, updated_at = now()
  returning id into v_id;

  return jsonb_build_object('ok', true, 'transaction_id', v_id, 'order_id', p_order_id,
    'bill_amount', p_amount, 'amount', v_usd, 'fx_rate', v_rate,
    'currency', coalesce(p_currency,'IQD'), 'status', 'pending',
    'gateway_status', 'CREATED', 'expires_at', v_expires);
end $function$;

CREATE OR REPLACE FUNCTION public.fastpay_mark_declined(p_order_id text, p_gateway_status text DEFAULT NULL::text, p_payload jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_tx public.pa_transactions%rowtype; v_expired boolean; v_new text;
begin
  select * into v_tx from public.pa_transactions
   where fastpay_order_id = p_order_id for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'ORDER_NOT_FOUND', 'order_id', p_order_id);
  end if;

  if v_tx.wallet_credited or v_tx.gateway_status in ('PAID','REFUNDED','REFUND_FAILED') then
    return jsonb_build_object('ok', false, 'code', 'ALREADY_SETTLED',
      'transaction_id', v_tx.id, 'gateway_status', v_tx.gateway_status);
  end if;

  if v_tx.gateway_status in ('EXPIRED','DECLINED') then
    return jsonb_build_object('ok', true, 'duplicate', true,
      'transaction_id', v_tx.id, 'gateway_status', v_tx.gateway_status);
  end if;

  v_expired := coalesce(v_tx.expires_at,
                        v_tx.created_at + (coalesce(v_tx.expires_in,10) * interval '1 minute')) <= now();
  v_new := case when v_expired then 'EXPIRED' else 'DECLINED' end;

  update public.pa_transactions
     set gateway_status  = v_new,
         status          = 'rejected',
         fail_reason     = case when v_expired then 'Expired before payment'
                                else 'Declined at gateway' ||
                                     coalesce(': ' || nullif(p_gateway_status,''), '') end,
         gateway_payload = coalesce(p_payload, gateway_payload)
   where id = v_tx.id;

  return jsonb_build_object('ok', true, 'duplicate', false,
    'transaction_id', v_tx.id, 'gateway_status', v_new, 'expired', v_expired);
end $function$;

CREATE OR REPLACE FUNCTION public.fastpay_mark_check_failed(p_order_id text, p_reason text, p_retryable boolean DEFAULT true, p_payload jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare v_tx public.pa_transactions%rowtype;
begin
  select * into v_tx from public.pa_transactions
   where fastpay_order_id = p_order_id for update;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'ORDER_NOT_FOUND', 'order_id', p_order_id);
  end if;

  if v_tx.wallet_credited or v_tx.gateway_status in ('PAID','REFUNDED','REFUND_FAILED') then
    return jsonb_build_object('ok', false, 'code', 'ALREADY_SETTLED',
      'transaction_id', v_tx.id, 'gateway_status', v_tx.gateway_status);
  end if;

  if coalesce(p_retryable, true) then
    update public.pa_transactions
       set fail_reason = left(coalesce(p_reason,'check failed'), 500),
           gateway_payload = coalesce(p_payload, gateway_payload)
     where id = v_tx.id;
    return jsonb_build_object('ok', true, 'retryable', true, 'code', 'LOGGED_ONLY',
      'transaction_id', v_tx.id, 'gateway_status', v_tx.gateway_status);
  end if;

  update public.pa_transactions
     set gateway_status  = 'FRAUD_SUSPECT',
         status          = 'rejected',
         fail_reason     = left(coalesce(p_reason,'mismatch'), 500),
         gateway_payload = coalesce(p_payload, gateway_payload)
   where id = v_tx.id;

  return jsonb_build_object('ok', true, 'retryable', false, 'code', 'FRAUD_SUSPECT',
    'transaction_id', v_tx.id);
end $function$;
