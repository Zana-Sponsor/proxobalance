-- Receipt reading: a failed reading never wipes a good one.
-- 1. When an order already has a reading of its receipt (ok or not_receipt) and a later
--    reading fails (Gemini busy, a timeout), the good reading stays; only the failure is
--    noted in error and attempts goes up. The next good reading clears error again.
-- 2. A reading always belongs to the receipt the order has now: when the receipt changes
--    (a correction with a new receipt), the old reading is deleted before the new one is asked.

create or replace function public.ex_receipt_read_save(p_key text, p_order_id uuid, p_result jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
set statement_timeout = '10s'
as $$
declare
  v_order public.ex_orders%rowtype;
  r jsonb := coalesce(p_result, '{}'::jsonb);
  v_status text;
  v_amount numeric;
  v_ref text;
  v_ref_norm text;
  v_match boolean;
  v_dup uuid;
  num_or_null text;
begin
  if not public.ex_receipt_read_key_ok(p_key) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select * into v_order from public.ex_orders where id = p_order_id for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'order_not_found');
  end if;
  -- The reader must save against the exact receipt it downloaded; row locking serializes this
  -- check with receipt_url updates and their trigger-driven deletion of the old reading.
  if nullif(r->>'receipt_url', '') is null or v_order.receipt_url is distinct from r->>'receipt_url' then
    return jsonb_build_object('ok', false, 'error', 'stale_receipt');
  end if;

  v_status := case
    when nullif(r->>'error', '') is not null then 'error'
    when (r->>'is_receipt') = 'false' then 'not_receipt'
    else 'ok' end;

  -- a failure over a good reading: keep the reading, note the failure
  if v_status = 'error' then
    update public.ex_receipt_reads
       set error = nullif(left(r->>'error', 300), ''), attempts = attempts + 1
     where order_id = p_order_id and status <> 'error';
    if found then
      return jsonb_build_object('ok', true, 'status', 'kept', 'amount_matches', null, 'duplicate', false);
    end if;
  end if;

  num_or_null := nullif(regexp_replace(coalesce(r->>'amount', ''), '[^0-9.]', '', 'g'), '');
  v_amount := case when num_or_null ~ '^[0-9]+(\.[0-9]+)?$' then num_or_null::numeric end;

  v_ref := nullif(left(btrim(coalesce(r->>'reference', '')), 120), '');
  v_ref_norm := nullif(upper(regexp_replace(coalesce(v_ref, ''), '[^0-9A-Za-z]', '', 'g')), '');
  if length(coalesce(v_ref_norm, '')) < 6 then v_ref_norm := null; end if;

  v_match := case
    when v_status <> 'ok' or v_amount is null then null
    when v_order.from_method = 'USDT' then abs(v_amount - v_order.amount) < 0.01
    else v_amount = v_order.amount end;

  if v_ref_norm is not null then
    select rr.order_id into v_dup
      from public.ex_receipt_reads rr
      join public.ex_orders o on o.id = rr.order_id
     where rr.reference_norm = v_ref_norm
       and rr.order_id <> p_order_id
       and (o.status <> 'ڕەتکرا' or o.user_id <> v_order.user_id)
     order by o.created_at
     limit 1;
  end if;

  insert into public.ex_receipt_reads as t (
    order_id, status, is_receipt, wallet, success, status_text, amount, currency, fee,
    reference, reference_norm, paid_at, sender_name, sender_account, receiver_name,
    receiver_account, notes, amount_matches, duplicate_order_id, model, error, attempts, read_at)
  values (
    p_order_id, v_status,
    case when r ? 'is_receipt' and jsonb_typeof(r->'is_receipt') = 'boolean' then (r->>'is_receipt')::boolean end,
    nullif(left(r->>'wallet', 60), ''),
    case when r ? 'success' and jsonb_typeof(r->'success') = 'boolean' then (r->>'success')::boolean end,
    nullif(left(r->>'status_text', 120), ''),
    v_amount,
    nullif(left(upper(r->>'currency'), 8), ''),
    case when (r->>'fee') ~ '^[0-9]+(\.[0-9]+)?$' then (r->>'fee')::numeric end,
    v_ref, v_ref_norm,
    nullif(left(r->>'paid_at', 60), ''),
    nullif(left(r->>'sender_name', 120), ''),
    nullif(left(r->>'sender_account', 60), ''),
    nullif(left(r->>'receiver_name', 120), ''),
    nullif(left(r->>'receiver_account', 60), ''),
    nullif(left(r->>'notes', 400), ''),
    v_match, v_dup,
    nullif(left(r->>'model', 60), ''),
    nullif(left(r->>'error', 300), ''),
    1, now())
  on conflict (order_id) do update set
    status = excluded.status, is_receipt = excluded.is_receipt, wallet = excluded.wallet,
    success = excluded.success, status_text = excluded.status_text, amount = excluded.amount,
    currency = excluded.currency, fee = excluded.fee, reference = excluded.reference,
    reference_norm = excluded.reference_norm, paid_at = excluded.paid_at,
    sender_name = excluded.sender_name, sender_account = excluded.sender_account,
    receiver_name = excluded.receiver_name, receiver_account = excluded.receiver_account,
    notes = excluded.notes, amount_matches = excluded.amount_matches,
    duplicate_order_id = excluded.duplicate_order_id, model = excluded.model,
    error = excluded.error, attempts = t.attempts + 1, read_at = now();

  return jsonb_build_object('ok', true, 'status', v_status, 'amount_matches', v_match,
                            'duplicate', v_dup is not null);
end;
$$;
revoke all on function public.ex_receipt_read_save(text, uuid, jsonb) from public, anon, authenticated;
grant execute on function public.ex_receipt_read_save(text, uuid, jsonb) to service_role;

create or replace function public.ex_orders_queue_receipt_read()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- the reading of an earlier receipt does not describe the new one
  if tg_op = 'UPDATE' and new.receipt_url is distinct from old.receipt_url then
    delete from public.ex_receipt_reads where order_id = new.id;
  end if;
  if new.receipt_url is not null
     and (tg_op = 'INSERT' or new.receipt_url is distinct from old.receipt_url) then
    perform public.ex_receipt_read_queue(new.id);
  end if;
  return null;
exception when others then
  return null;
end;
$$;
revoke all on function public.ex_orders_queue_receipt_read() from public, anon, authenticated;
