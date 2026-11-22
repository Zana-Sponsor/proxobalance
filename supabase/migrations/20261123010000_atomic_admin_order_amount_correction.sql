-- Repository-only migration. Do not apply to production without separate approval.
-- This extends the live AccountBalance guard only for a transaction-local correction
-- performed by an active super_admin through the server-only RPC below.

create table if not exists public.ex_order_amount_corrections (
  id uuid primary key default gen_random_uuid(),
  request_key uuid not null unique,
  order_id uuid not null references public.ex_orders(id) on delete restrict,
  admin_id uuid not null references public.ex_profiles(id) on delete restrict,
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  old_snapshot jsonb not null,
  new_snapshot jsonb not null,
  balance_delta bigint not null default 0,
  journal_id uuid references public.ex_balance_journal(id) on delete restrict,
  available_iqd_after bigint,
  created_at timestamptz not null default now()
);
revoke all on public.ex_order_amount_corrections from public, anon, authenticated, service_role;
create trigger ex_order_amount_corrections_immutable before update or delete
  on public.ex_order_amount_corrections for each row execute function public.ex_balance_deny_journal_mutation();

-- Keep every existing AccountBalance insert/update rule. An amount change is allowed only
-- when this exact order and active super-admin were bound by ex_admin_order_update_atomic.
create or replace function public.ex_balance_order_guard()
returns trigger language plpgsql security definer set search_path = '' as $function$
declare
  v_correction_order text;
  v_correction_admin text;
begin
  if tg_op='INSERT' then
    if new.to_method='AccountBalance' then raise exception 'BALANCE_IS_SEND_ONLY' using errcode='22023'; end if;
    if new.from_method='AccountBalance' then
      if current_setting('ex_balance.order_authorized',true) is distinct from new.user_id::text
        or new.balance_request_key is null or new.amount<>trunc(new.amount) or new.to_method='USDT' then
        raise exception 'ATOMIC_BALANCE_ORDER_REQUIRED' using errcode='42501';
      end if;
      new.receipt_url:=null; new.receipt_hash:=null; new.transaction_reference:=null;
      new.balance_debit_journal_id:=null;
    elsif new.balance_request_key is not null or new.balance_debit_journal_id is not null then
      raise exception 'INVALID_BALANCE_ORDER_FIELDS' using errcode='22023';
    end if;
  elsif old.from_method='AccountBalance' or new.from_method='AccountBalance' then
    v_correction_order:=current_setting('ex_order_correction.order_id',true);
    v_correction_admin:=current_setting('ex_order_correction.admin_id',true);
    if v_correction_order is not distinct from old.id::text and v_correction_admin is not null
      and exists(select 1 from public.ex_profiles p where p.id::text=v_correction_admin
        and p.role='super_admin' and p.is_admin and not coalesce(p.is_banned,false)) then
      if new.user_id is distinct from old.user_id
        or new.from_method is distinct from old.from_method
        or new.to_method is distinct from old.to_method
        or new.total is distinct from old.total
        or new.fee is distinct from old.fee
        or new.reward_id is distinct from old.reward_id
        or new.reward_scope is distinct from old.reward_scope
        or new.reward_discount_iqd is distinct from old.reward_discount_iqd
        or new.reward_original_fee_iqd is distinct from old.reward_original_fee_iqd
        or new.reward_covered_amount_iqd is distinct from old.reward_covered_amount_iqd
        or new.reward_cap_iqd is distinct from old.reward_cap_iqd
        or new.balance_request_key is distinct from old.balance_request_key
        or new.balance_debit_journal_id is distinct from old.balance_debit_journal_id
        or new.amount<>trunc(new.amount) then
        raise exception 'BALANCE_ORDER_CORRECTION_SCOPE_VIOLATION' using errcode='23514';
      end if;
    elsif new.user_id is distinct from old.user_id or new.from_method is distinct from old.from_method
      or new.to_method is distinct from old.to_method or new.amount is distinct from old.amount
      or new.total is distinct from old.total or new.fee is distinct from old.fee
      or new.reward_id is distinct from old.reward_id or new.reward_scope is distinct from old.reward_scope
      or new.reward_discount_iqd is distinct from old.reward_discount_iqd
      or new.reward_original_fee_iqd is distinct from old.reward_original_fee_iqd
      or new.reward_covered_amount_iqd is distinct from old.reward_covered_amount_iqd
      or new.reward_cap_iqd is distinct from old.reward_cap_iqd
      or new.balance_request_key is distinct from old.balance_request_key
      or (old.balance_debit_journal_id is not null and new.balance_debit_journal_id is distinct from old.balance_debit_journal_id) then
      raise exception 'BALANCE_ORDER_FINANCIALS_IMMUTABLE' using errcode='23514';
    end if;
  end if;
  return new;
end;
$function$;

create or replace function public.ex_admin_order_update_atomic(
  p_order_id uuid, p_fields jsonb, p_reason text, p_admin_id uuid,
  p_request_key uuid, p_expected_updated_at timestamptz
) returns jsonb language plpgsql security definer set search_path = '' as $fn$
declare
  o public.ex_orders%rowtype;
  v_profile public.ex_profiles%rowtype;
  v_old jsonb;
  v_new jsonb;
  v_prior public.ex_order_amount_corrections%rowtype;
  v_delta bigint := 0;
  v_journal uuid;
  v_balance bigint;
  v_payload jsonb;
  v_fields jsonb;
begin
  if p_request_key is null or p_order_id is null or p_admin_id is null or p_expected_updated_at is null
    or p_fields is null or jsonb_typeof(p_fields) <> 'object'
    or char_length(btrim(coalesce(p_reason,''))) < 5 or char_length(p_reason)>500 then
    raise exception 'INVALID_ORDER_CORRECTION' using errcode='22023';
  end if;
  select * into v_profile from public.ex_profiles where id=p_admin_id for share;
  if not found or v_profile.role <> 'super_admin' or not v_profile.is_admin or coalesce(v_profile.is_banned,false) then
    raise exception 'SUPER_ADMIN_REQUIRED' using errcode='42501';
  end if;
  v_payload:=jsonb_build_object('order_id',p_order_id,'fields',p_fields,'reason',btrim(p_reason),
    'admin_id',p_admin_id,'expected_updated_at',p_expected_updated_at);
  select * into v_prior from public.ex_order_amount_corrections where request_key=p_request_key;
  if found then
    if v_prior.payload is distinct from v_payload then raise exception 'ORDER_CORRECTION_REQUEST_KEY_CONFLICT' using errcode='23505'; end if;
    select * into o from public.ex_orders where id=p_order_id;
    return jsonb_build_object('order',to_jsonb(o),'correction_id',v_prior.id,'journal_id',v_prior.journal_id,
      'balance_delta',v_prior.balance_delta,'balance_after_iqd',v_prior.available_iqd_after,'idempotent',true);
  end if;
  select * into o from public.ex_orders where id=p_order_id for update;
  if not found then raise exception 'ORDER_NOT_FOUND' using errcode='P0002'; end if;
  select * into v_prior from public.ex_order_amount_corrections where request_key=p_request_key;
  if found then
    if v_prior.payload is distinct from v_payload then raise exception 'ORDER_CORRECTION_REQUEST_KEY_CONFLICT' using errcode='23505'; end if;
    return jsonb_build_object('order',to_jsonb(o),'correction_id',v_prior.id,'journal_id',v_prior.journal_id,
      'balance_delta',v_prior.balance_delta,'balance_after_iqd',v_prior.available_iqd_after,'idempotent',true);
  end if;
  if o.updated_at is distinct from p_expected_updated_at then raise exception 'ORDER_CORRECTION_STALE' using errcode='40001'; end if;
  if p_fields='{}'::jsonb then raise exception 'NO_CHANGES' using errcode='22023'; end if;
  if exists(select 1 from jsonb_object_keys(p_fields) k where k not in
    ('amount','phone','sender_name','sender_phone','receipt_url','receipt_hash','payout_receipt_url',
     'transaction_reference','extra_info','admin_note','order_code','created_at','decided_at')) then
    raise exception 'ORDER_CORRECTION_FIELD_NOT_ALLOWED' using errcode='22023';
  end if;
  if p_fields ? 'amount' and (o.balance_refunded_at is not null or o.balance_refund_case_id is not null
    or exists(select 1 from public.ex_order_shortfall_refunds f where f.order_id=o.id)
    or o.shortfall_refunded_iqd>0 or o.payout_settlement_id is not null or o.status='پەسەندکرا') then
    raise exception 'ORDER_CORRECTION_PROTECTED_STATE' using errcode='23514';
  end if;
  if p_fields ? 'amount' then
    if o.from_method<>'AccountBalance' then raise exception 'EXTERNAL_ORDER_FINANCIAL_EDIT_DENIED' using errcode='23514'; end if;
    if p_fields->>'amount' is null or (p_fields->>'amount') !~ '^[0-9]+$'
      or (p_fields->>'amount')::numeric<10000 or (p_fields->>'amount')::numeric>9223372036854775807::numeric
      or o.amount<>trunc(o.amount) or o.amount>9223372036854775807::numeric then
      raise exception 'INVALID_AMOUNT' using errcode='22023';
    end if;
    v_delta := o.amount::bigint - (p_fields->>'amount')::bigint;
  end if;
  v_old:=to_jsonb(o);
  v_fields:=p_fields;
  perform set_config('ex_order_correction.order_id',o.id::text,true);
  perform set_config('ex_order_correction.admin_id',p_admin_id::text,true);
  perform set_config('ex_admin.silent',o.id::text,true);
  perform set_config('ex_admin.order_manual',o.id::text,true);
  if v_fields ? 'order_code' then perform set_config('ex_admin.order_edit',o.id::text,true); end if;
  update public.ex_orders set
    amount=case when v_fields ? 'amount' then (v_fields->>'amount')::numeric else amount end,
    phone=case when v_fields ? 'phone' then nullif(btrim(v_fields->>'phone'),'') else phone end,
    sender_name=case when v_fields ? 'sender_name' then nullif(btrim(v_fields->>'sender_name'),'') else sender_name end,
    sender_phone=case when v_fields ? 'sender_phone' then nullif(btrim(v_fields->>'sender_phone'),'') else sender_phone end,
    receipt_url=case when v_fields ? 'receipt_url' then nullif(btrim(v_fields->>'receipt_url'),'') else receipt_url end,
    receipt_hash=case when v_fields ? 'receipt_hash' then nullif(btrim(v_fields->>'receipt_hash'),'') else receipt_hash end,
    payout_receipt_url=case when v_fields ? 'payout_receipt_url' then nullif(btrim(v_fields->>'payout_receipt_url'),'') else payout_receipt_url end,
    transaction_reference=case when v_fields ? 'transaction_reference' then nullif(btrim(v_fields->>'transaction_reference'),'') else transaction_reference end,
    extra_info=case when v_fields ? 'extra_info' then nullif(btrim(v_fields->>'extra_info'),'') else extra_info end,
    admin_note=case when v_fields ? 'admin_note' then nullif(btrim(v_fields->>'admin_note'),'') else admin_note end,
    order_code=case when v_fields ? 'order_code' then upper(btrim(v_fields->>'order_code')) else order_code end,
    created_at=case when v_fields ? 'created_at' then (v_fields->>'created_at')::timestamptz else created_at end,
    decided_at=case when v_fields ? 'decided_at' then (v_fields->>'decided_at')::timestamptz else decided_at end,
    updated_at=now()
  where id=o.id returning * into o;
  if v_delta<>0 then
    v_journal:=public.ex_balance_post(o.user_id,v_delta,0,
      case when v_delta>0 then 'admin_refund' else 'admin_debit' end,
      'order-correction:'||p_request_key::text,o.id,null,p_admin_id,
      'Order amount correction: '||btrim(p_reason),null);
  end if;
  select available_iqd into v_balance from public.ex_customer_balances where user_id=o.user_id;
  v_new:=to_jsonb(o);
  insert into public.ex_order_amount_corrections(request_key,order_id,admin_id,payload,old_snapshot,new_snapshot,
    balance_delta,journal_id,available_iqd_after)
  values(p_request_key,o.id,p_admin_id,v_payload,v_old,v_new,v_delta,v_journal,v_balance) returning * into v_prior;
  insert into public.ex_order_admin_actions(order_id,order_code,user_id,admin_id,action,reason,notified,old_data,new_data)
  values(o.id,o.order_code,o.user_id,p_admin_id,'edit',btrim(p_reason),false,v_old,v_new);
  insert into public.ex_admin_audit_log(admin_id,action,target_user_id,detail)
  values(p_admin_id,'order_amount_correction',o.user_id,jsonb_build_object('order_id',o.id,'correction_id',v_prior.id,
    'request_key',p_request_key,'balance_delta',v_delta,'journal_id',v_journal,'reason',btrim(p_reason))::text);
  return jsonb_build_object('order',v_new,'correction_id',v_prior.id,'journal_id',v_journal,
    'balance_delta',v_delta,'balance_after_iqd',v_balance,'idempotent',false);
end;
$fn$;
revoke all on function public.ex_admin_order_update_atomic(uuid,jsonb,text,uuid,uuid,timestamptz) from public,anon,authenticated;
grant execute on function public.ex_admin_order_update_atomic(uuid,jsonb,text,uuid,uuid,timestamptz) to service_role;
