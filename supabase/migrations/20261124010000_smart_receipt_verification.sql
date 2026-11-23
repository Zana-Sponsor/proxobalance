-- Smart Receipt Verification for outbound payout receipts.
-- This history is intentionally separate from ex_receipt_reads (incoming customer proof).
-- OCR never approves an order; this migration only blocks a recorded ID mismatch and
-- requires a same-admin manual review for any other non-verified receipt result.

create table if not exists public.ex_payout_receipt_verifications (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.ex_orders(id) on delete cascade,
  user_id uuid not null references public.ex_profiles(id) on delete cascade,
  admin_id uuid not null references public.ex_profiles(id),
  payout_receipt_url text not null,
  source_admin_note text,
  expected_amount_iqd bigint not null check (expected_amount_iqd between 0 and 1000000000),
  expected_reference text,
  expected_reference_norm text,
  ocr_status text not null default 'queued'
    check (ocr_status in ('queued','processing','complete','error')),
  is_receipt boolean,
  wallet text,
  bank_name text,
  success boolean,
  status_text text,
  actual_amount_iqd bigint,
  currency text,
  extracted_reference text,
  extracted_reference_norm text,
  description text,
  paid_at text,
  sender_name text,
  sender_account text,
  receiver_name text,
  receiver_account text,
  notes text,
  reference_confidence numeric check (reference_confidence between 0 and 1),
  amount_confidence numeric check (amount_confidence between 0 and 1),
  amount_status text check (amount_status in ('EXACT_MATCH','OVERPAID','UNDERPAID','AMOUNT_NOT_FOUND')),
  difference_iqd bigint,
  id_status text check (id_status in ('MATCH','MISMATCH','NOT_FOUND','UNCERTAIN')),
  verification_status text check (verification_status in ('VERIFIED','ID_MISMATCH','DUPLICATE','NEEDS_REVIEW','OCR_FAILED')),
  receipt_fingerprint text check (receipt_fingerprint is null or receipt_fingerprint ~ '^[0-9a-f]{64}$'),
  duplicate_order_id uuid references public.ex_orders(id) on delete set null,
  model text,
  error_code text,
  manual_review_by uuid references public.ex_profiles(id),
  manual_review_at timestamptz,
  manual_review_reason text,
  created_at timestamptz not null default now(),
  processed_at timestamptz,
  updated_at timestamptz not null default now(),
  check ((manual_review_by is null and manual_review_at is null and manual_review_reason is null)
      or (manual_review_by is not null and manual_review_at is not null and char_length(btrim(manual_review_reason)) between 10 and 300))
);

create index if not exists ex_payout_receipt_verifications_order_idx
  on public.ex_payout_receipt_verifications (order_id, created_at desc);
create index if not exists ex_payout_receipt_verifications_fingerprint_idx
  on public.ex_payout_receipt_verifications (receipt_fingerprint)
  where receipt_fingerprint is not null;
create index if not exists ex_payout_receipt_verifications_reference_idx
  on public.ex_payout_receipt_verifications (extracted_reference_norm)
  where extracted_reference_norm is not null;

alter table public.ex_payout_receipt_verifications enable row level security;
revoke all on table public.ex_payout_receipt_verifications from public, anon, authenticated;
grant all on table public.ex_payout_receipt_verifications to service_role;

create or replace function public.ex_payout_receipt_normalize_reference(p_value text)
returns text
language sql
immutable
set search_path = ''
as $$
  select nullif(regexp_replace(
    lower(translate(coalesce(p_value,''),
      '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹', '01234567890123456789')),
    '[-[:space:]_:/.,‐‑‒–—]+', '', 'g'), '');
$$;
revoke all on function public.ex_payout_receipt_normalize_reference(text) from public, anon, authenticated;
grant execute on function public.ex_payout_receipt_normalize_reference(text) to service_role;

-- Queue the existing receipt-read Edge Function with the same Vault-held reader key.
create or replace function public.ex_payout_receipt_enqueue(p_verification_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_key text;
  v_request_id bigint;
begin
  select decrypted_secret into v_key from vault.decrypted_secrets
   where name = 'receipt_read_key' limit 1;
  if v_key is null then
    update public.ex_payout_receipt_verifications
       set ocr_status='error', verification_status='OCR_FAILED', error_code='reader_key_missing',
           processed_at=now(), updated_at=now()
     where id=p_verification_id;
    return jsonb_build_object('queued',false,'status','error');
  end if;

  select net.http_post(
    url := 'https://pycxuugoblkslvwebxuu.supabase.co/functions/v1/receipt-read',
    body := jsonb_build_object('payout_verification_id',p_verification_id),
    headers := jsonb_build_object('Content-Type','application/json','x-receipt-key',v_key),
    timeout_milliseconds := 10000
  ) into v_request_id;

  if v_request_id is null then
    update public.ex_payout_receipt_verifications
       set ocr_status='error', verification_status='OCR_FAILED', error_code='queue_failed',
           processed_at=now(), updated_at=now()
     where id=p_verification_id;
    return jsonb_build_object('queued',false,'status','error');
  end if;
  return jsonb_build_object('queued',true,'status','queued');
exception when others then
  update public.ex_payout_receipt_verifications
     set ocr_status='error', verification_status='OCR_FAILED', error_code='queue_failed',
         processed_at=now(), updated_at=now()
   where id=p_verification_id;
  return jsonb_build_object('queued',false,'status','error');
end;
$$;
revoke all on function public.ex_payout_receipt_enqueue(uuid) from public, anon, authenticated;
grant execute on function public.ex_payout_receipt_enqueue(uuid) to service_role;

create or replace function public.ex_admin_payout_receipt_start(
  p_order_id uuid,
  p_admin_id uuid,
  p_receipt_url text,
  p_refund_iqd bigint,
  p_expected_total numeric,
  p_expected_amount_iqd bigint,
  p_source_admin_note text,
  p_expected_reference text
) returns jsonb
language plpgsql
security definer
set search_path = ''
set statement_timeout = '10s'
as $$
declare
  v_admin public.ex_profiles%rowtype;
  v_order public.ex_orders%rowtype;
  v_id uuid;
  v_existing_status text;
  v_reviewed_by uuid;
  v_existing_updated_at timestamptz;
  v_expected_payout bigint;
  v_prefix text;
  v_queue jsonb;
begin
  select * into v_admin from public.ex_profiles where id=p_admin_id;
  if not found or not coalesce(v_admin.is_admin,false) or coalesce(v_admin.is_banned,false)
     or not coalesce(v_admin.role='super_admin' or v_admin.staff_permissions is null
       or 'approve_orders'=any(v_admin.staff_permissions),false) then
    raise exception using errcode='42501', message='STAFF_PERMISSION_REQUIRED';
  end if;
  if p_order_id is null or p_receipt_url is null or p_refund_iqd is null
     or p_expected_total is null or p_expected_amount_iqd is null
     or p_refund_iqd < 0 or p_refund_iqd > 1000000000 or mod(p_refund_iqd,1000)<>0
     or (p_expected_reference is not null and char_length(p_expected_reference)>120) then
    raise exception using errcode='22023', message='INVALID_SMART_RECEIPT_REQUEST';
  end if;

  select * into v_order from public.ex_orders where id=p_order_id for update;
  if not found then raise exception using errcode='P0001', message='ORDER_NOT_FOUND'; end if;
  if v_order.status not in ('چاوەڕوانە','ڕاستکراوەتەوە','لەژێر پێداچوونەوەدایە')
     or v_order.balance_refunded_at is not null or v_order.payout_settlement_id is not null
     or v_order.to_method in ('USDT','AccountBalance') then
    raise exception using errcode='P0001', message='ORDER_NOT_ELIGIBLE_FOR_SMART_RECEIPT';
  end if;

  if p_expected_total is distinct from v_order.total
     or v_order.total is null or v_order.total<>trunc(v_order.total)
     or v_order.total<0 or v_order.total>1000000000 then
    raise exception using errcode='22023', message='SMART_RECEIPT_STALE_AMOUNT';
  end if;
  v_expected_payout := (trunc(v_order.total/1000)*1000)::bigint;
  if p_refund_iqd>v_expected_payout
     or p_expected_amount_iqd<>v_expected_payout-p_refund_iqd
     or p_expected_amount_iqd<=0 then
    raise exception using errcode='22023', message='SMART_RECEIPT_AMOUNT_MISMATCH';
  end if;
  if p_source_admin_note is distinct from v_order.admin_note then
    raise exception using errcode='22023', message='SMART_RECEIPT_NOTE_STALE';
  end if;
  if p_receipt_url ~ '[[:space:]?#]' or position(chr(92) in p_receipt_url)>0
     or position('..' in p_receipt_url)>0 or p_receipt_url ~* '%2e|%2f|%5c' then
    raise exception using errcode='22023', message='INVALID_PAYOUT_RECEIPT';
  end if;
  v_prefix := 'https://pycxuugoblkslvwebxuu.supabase.co/storage/v1/object/public/receipts/'||v_order.user_id::text||'/payout_';
  if left(p_receipt_url,char_length(v_prefix))<>v_prefix or char_length(p_receipt_url)>2000 then
    raise exception using errcode='22023', message='INVALID_PAYOUT_RECEIPT';
  end if;

  select id,ocr_status,manual_review_by,updated_at into v_id,v_existing_status,v_reviewed_by,v_existing_updated_at
    from public.ex_payout_receipt_verifications
   where order_id=v_order.id and admin_id=p_admin_id and payout_receipt_url=p_receipt_url
     and expected_amount_iqd=p_expected_amount_iqd
     and source_admin_note is not distinct from p_source_admin_note
     and expected_reference_norm is not distinct from public.ex_payout_receipt_normalize_reference(p_expected_reference)
   order by created_at desc limit 1;
  if found then
    if v_reviewed_by is not null or (v_existing_status<>'error'
       and not (v_existing_status='queued' and v_existing_updated_at<now()-interval '1 minute')
       and not (v_existing_status='processing' and v_existing_updated_at<now()-interval '5 minutes')) then
      return jsonb_build_object('verification_id',v_id,'queued',v_existing_status in ('queued','processing'),
        'ocr_status',v_existing_status);
    end if;
    update public.ex_payout_receipt_verifications set ocr_status='queued',is_receipt=null,wallet=null,bank_name=null,
      success=null,status_text=null,actual_amount_iqd=null,currency=null,extracted_reference=null,
      extracted_reference_norm=null,description=null,paid_at=null,sender_name=null,sender_account=null,
      receiver_name=null,receiver_account=null,notes=null,reference_confidence=null,amount_confidence=null,
      amount_status=null,difference_iqd=null,id_status=null,verification_status=null,receipt_fingerprint=null,
      duplicate_order_id=null,model=null,error_code=null,processed_at=null,updated_at=now()
     where id=v_id;
  else
    insert into public.ex_payout_receipt_verifications(
      order_id,user_id,admin_id,payout_receipt_url,source_admin_note,
      expected_amount_iqd,expected_reference,expected_reference_norm,ocr_status,created_at,updated_at
    ) values(
      v_order.id,v_order.user_id,p_admin_id,p_receipt_url,p_source_admin_note,
      p_expected_amount_iqd,nullif(btrim(p_expected_reference),''),
      public.ex_payout_receipt_normalize_reference(p_expected_reference),'queued',now(),now()
    ) returning id into v_id;
  end if;

  v_queue := public.ex_payout_receipt_enqueue(v_id);
  return jsonb_build_object('verification_id',v_id,'queued',coalesce((v_queue->>'queued')::boolean,false),
    'ocr_status',coalesce(v_queue->>'status','error'));
end;
$$;
revoke all on function public.ex_admin_payout_receipt_start(uuid,uuid,text,bigint,numeric,bigint,text,text) from public, anon, authenticated;
grant execute on function public.ex_admin_payout_receipt_start(uuid,uuid,text,bigint,numeric,bigint,text,text) to service_role;

-- Called only by the existing receipt-read Edge Function, authenticated with the reader key.
-- The OCR result is reduced to structured fields; raw OCR text and image bytes are not stored.
create or replace function public.ex_payout_receipt_ocr_save(p_key text,p_verification_id uuid,p_result jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
set statement_timeout = '10s'
as $$
declare
  v_row public.ex_payout_receipt_verifications%rowtype;
  r jsonb := coalesce(p_result,'{}'::jsonb);
  v_error text;
  v_is_receipt boolean;
  v_success boolean;
  v_amount_text text;
  v_amount_num numeric;
  v_amount bigint;
  v_currency text;
  v_currency_norm text;
  v_ref text;
  v_ref_norm text;
  v_fingerprint text;
  v_ref_conf numeric;
  v_amount_conf numeric;
  v_id_status text;
  v_amount_status text := 'AMOUNT_NOT_FOUND';
  v_verification_status text;
  v_difference bigint;
  v_duplicate uuid;
  v_now timestamptz := now();
begin
  if not public.ex_receipt_read_key_ok(p_key) then
    raise exception using errcode='42501', message='NOT_ALLOWED';
  end if;
  select * into v_row from public.ex_payout_receipt_verifications where id=p_verification_id for update;
  if not found then return jsonb_build_object('ok',false,'error','verification_not_found'); end if;
  if v_row.ocr_status='complete' or v_row.ocr_status='error' then
    return jsonb_build_object('ok',true,'status',v_row.ocr_status,'verification_status',v_row.verification_status);
  end if;

  v_error := nullif(left(coalesce(r->>'error',''),80),'');
  v_is_receipt := case when jsonb_typeof(r->'is_receipt')='boolean' then (r->>'is_receipt')::boolean end;
  v_success := case when jsonb_typeof(r->'success')='boolean' then (r->>'success')::boolean end;
  v_amount_text := nullif(btrim(r->>'amount'),'');
  if (r->>'reference_confidence') ~ '^[0-9]+(\.[0-9]+)?$' then
    v_ref_conf := (r->>'reference_confidence')::numeric;
    if v_ref_conf<0 or v_ref_conf>1 then v_ref_conf := null; end if;
  end if;
  if (r->>'amount_confidence') ~ '^[0-9]+(\.[0-9]+)?$' then
    v_amount_conf := (r->>'amount_confidence')::numeric;
    if v_amount_conf<0 or v_amount_conf>1 then v_amount_conf := null; end if;
  end if;
  if v_amount_text ~ '^[0-9]+(\.[0-9]+)?$' then
    v_amount_num := v_amount_text::numeric;
  elsif v_amount_text ~ '^[0-9]{1,3}(,[0-9]{3})+$' or v_amount_text ~ '^[0-9]{1,3}(\.[0-9]{3})+$' then
    v_amount_num := replace(replace(v_amount_text,',',''),'.','')::numeric;
  end if;
  v_currency := nullif(left(btrim(r->>'currency'),20),'');
  v_currency_norm := regexp_replace(lower(coalesce(v_currency,'')),'[[:space:].]','','g');
  if v_amount_num is not null and v_amount_num=trunc(v_amount_num)
     and v_amount_num between 0 and 1000000000
     and v_currency_norm in ('iqd','دع','دينار','دینار','دينارعراقي','دینارعراقی','عراقيدينار','عراقدينار','عراقیدینار')
     and v_amount_conf>=0.8 then
    v_amount := v_amount_num::bigint;
  end if;

  v_ref := nullif(left(btrim(r->>'reference'),120),'');
  v_ref_norm := public.ex_payout_receipt_normalize_reference(v_ref);
  v_fingerprint := lower(nullif(r->>'receipt_fingerprint',''));
  if v_fingerprint !~ '^[0-9a-f]{64}$' then v_fingerprint := null; end if;

  if v_fingerprint is not null then
    perform pg_advisory_xact_lock(hashtextextended('payout-receipt:file:'||v_fingerprint,0));
  end if;
  if v_ref_norm is not null and char_length(v_ref_norm)>=4 then
    perform pg_advisory_xact_lock(hashtextextended('payout-receipt:ref:'||v_ref_norm,0));
  end if;

  if v_fingerprint is not null then
    select prior.order_id into v_duplicate
      from public.ex_payout_receipt_verifications prior
     where prior.id<>v_row.id and prior.order_id<>v_row.order_id
       and prior.receipt_fingerprint=v_fingerprint
     order by prior.created_at limit 1;
    if v_duplicate is null then
      select prior.id into v_duplicate from public.ex_orders prior
       where prior.id<>v_row.order_id and prior.receipt_hash=v_fingerprint
       order by prior.created_at limit 1;
    end if;
  end if;
  if v_duplicate is null and v_ref_norm is not null and char_length(v_ref_norm)>=4
     and v_ref_conf>=0.8 then
    select prior.order_id into v_duplicate
      from public.ex_payout_receipt_verifications prior
     where prior.id<>v_row.id and prior.order_id<>v_row.order_id
       and prior.ocr_status='complete' and prior.is_receipt is true
       and prior.extracted_reference_norm=v_ref_norm
     order by prior.created_at limit 1;
  end if;

  if v_error is not null or v_is_receipt is not true then
    v_id_status := case when v_row.expected_reference_norm is null or v_ref_norm is null then 'NOT_FOUND' else 'UNCERTAIN' end;
  elsif v_row.expected_reference_norm is null or v_ref_norm is null then
    v_id_status := 'NOT_FOUND';
  elsif v_ref_conf is null or v_ref_conf<0.8 or char_length(v_row.expected_reference_norm)<4 or char_length(v_ref_norm)<4 then
    v_id_status := 'UNCERTAIN';
  elsif v_row.expected_reference_norm=v_ref_norm then
    v_id_status := 'MATCH';
  else
    v_id_status := 'MISMATCH';
  end if;

  if v_amount is not null and v_amount_conf>=0.8 and v_error is null and v_is_receipt is true then
    v_difference := v_amount-v_row.expected_amount_iqd;
    v_amount_status := case when v_difference=0 then 'EXACT_MATCH'
      when v_difference>0 then 'OVERPAID' else 'UNDERPAID' end;
  end if;

  v_verification_status := case
    when v_duplicate is not null then 'DUPLICATE'
    when v_error is not null or v_is_receipt is not true then 'OCR_FAILED'
    when v_id_status='MISMATCH' then 'ID_MISMATCH'
    when v_id_status='MATCH' and v_amount_status='EXACT_MATCH' and v_success is true
      and nullif(btrim(r->>'notes'),'') is null then 'VERIFIED'
    else 'NEEDS_REVIEW' end;

  update public.ex_payout_receipt_verifications set
    ocr_status=case when v_error is null then 'complete' else 'error' end,
    is_receipt=v_is_receipt,wallet=nullif(left(r->>'wallet',80),''),bank_name=nullif(left(r->>'bank_name',100),''),
    success=v_success,status_text=nullif(left(r->>'status_text',120),''),actual_amount_iqd=v_amount,currency=v_currency,
    extracted_reference=v_ref,extracted_reference_norm=v_ref_norm,description=nullif(left(r->>'description',600),''),
    paid_at=nullif(left(r->>'paid_at',80),''),sender_name=nullif(left(r->>'sender_name',120),''),
    sender_account=nullif(left(r->>'sender_account',60),''),receiver_name=nullif(left(r->>'receiver_name',120),''),
    receiver_account=nullif(left(r->>'receiver_account',60),''),notes=nullif(left(r->>'notes',500),''),
    reference_confidence=v_ref_conf,amount_confidence=v_amount_conf,amount_status=v_amount_status,
    difference_iqd=v_difference,id_status=v_id_status,verification_status=v_verification_status,
    receipt_fingerprint=v_fingerprint,duplicate_order_id=v_duplicate,model=nullif(left(r->>'model',60),''),
    error_code=v_error,processed_at=v_now,updated_at=v_now
   where id=v_row.id;

  return jsonb_build_object('ok',true,'ocr_status',case when v_error is null then 'complete' else 'error' end,
    'verification_status',v_verification_status,'id_status',v_id_status,'amount_status',v_amount_status,
    'duplicate',v_duplicate is not null);
end;
$$;
revoke all on function public.ex_payout_receipt_ocr_save(text,uuid,jsonb) from public, anon, authenticated;
grant execute on function public.ex_payout_receipt_ocr_save(text,uuid,jsonb) to service_role;

create or replace function public.ex_admin_payout_receipt_review(
  p_verification_id uuid,p_admin_id uuid,p_reason text
) returns jsonb
language plpgsql
security definer
set search_path = ''
set statement_timeout = '10s'
as $$
declare
  v_admin public.ex_profiles%rowtype;
  v_verification public.ex_payout_receipt_verifications%rowtype;
  v_order public.ex_orders%rowtype;
  v_reason text := btrim(coalesce(p_reason,''));
begin
  select * into v_admin from public.ex_profiles where id=p_admin_id;
  if not found or not coalesce(v_admin.is_admin,false) or coalesce(v_admin.is_banned,false)
     or not coalesce(v_admin.role='super_admin' or v_admin.staff_permissions is null
       or 'approve_orders'=any(v_admin.staff_permissions),false) then
    raise exception using errcode='42501', message='STAFF_PERMISSION_REQUIRED';
  end if;
  if p_verification_id is null or char_length(v_reason)<10 or char_length(v_reason)>300 then
    raise exception using errcode='22023', message='SMART_RECEIPT_REVIEW_REASON_REQUIRED';
  end if;
  select * into v_verification from public.ex_payout_receipt_verifications
   where id=p_verification_id for update;
  if not found then raise exception using errcode='P0001', message='SMART_RECEIPT_NOT_FOUND'; end if;
  if v_verification.ocr_status not in ('complete','error') or v_verification.id_status='MISMATCH'
     or v_verification.verification_status='VERIFIED' then
    raise exception using errcode='22023', message='SMART_RECEIPT_NOT_REVIEWABLE';
  end if;
  select * into v_order from public.ex_orders where id=v_verification.order_id for update;
  if not found or v_order.status not in ('چاوەڕوانە','ڕاستکراوەتەوە','لەژێر پێداچوونەوەدایە')
     or v_order.balance_refunded_at is not null then
    raise exception using errcode='P0001', message='ORDER_NOT_ELIGIBLE_FOR_SMART_RECEIPT';
  end if;
  if v_verification.source_admin_note is distinct from v_order.admin_note then
    raise exception using errcode='22023', message='SMART_RECEIPT_NOTE_STALE';
  end if;
  if v_verification.manual_review_by is not null then
    if v_verification.manual_review_by=p_admin_id and v_verification.manual_review_reason=v_reason then
      return jsonb_build_object('reviewed',true,'verification_id',p_verification_id);
    end if;
    raise exception using errcode='22023', message='SMART_RECEIPT_ALREADY_REVIEWED';
  end if;
  update public.ex_payout_receipt_verifications set manual_review_by=p_admin_id,
    manual_review_at=now(),manual_review_reason=v_reason,updated_at=now()
   where id=p_verification_id;
  return jsonb_build_object('reviewed',true,'verification_id',p_verification_id);
end;
$$;
revoke all on function public.ex_admin_payout_receipt_review(uuid,uuid,text) from public, anon, authenticated;
grant execute on function public.ex_admin_payout_receipt_review(uuid,uuid,text) to service_role;

-- This trigger covers both the Node admin API settlement and the existing refund approval RPC.
create or replace function public.ex_payout_receipt_approval_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.ex_payout_receipt_verifications%rowtype;
begin
  if new.status='پەسەندکرا' and old.status is distinct from 'پەسەندکرا'
     and coalesce(new.to_method,'') not in ('USDT','AccountBalance')
     and nullif(btrim(new.payout_receipt_url),'') is not null then
    select * into v from public.ex_payout_receipt_verifications
     where order_id=new.id and payout_receipt_url=new.payout_receipt_url
     order by created_at desc limit 1;
    if not found then
      raise exception using errcode='P0001', message='SMART_RECEIPT_VERIFICATION_REQUIRED';
    end if;
    if v.ocr_status not in ('complete','error') then
      raise exception using errcode='P0001', message='SMART_RECEIPT_OCR_PENDING';
    end if;
    if v.source_admin_note is distinct from new.admin_note or v.expected_amount_iqd is distinct from new.payout_iqd then
      raise exception using errcode='P0001', message='SMART_RECEIPT_STALE';
    end if;
    if v.id_status='MISMATCH' then
      raise exception using errcode='P0001', message='SMART_RECEIPT_ID_MISMATCH';
    end if;
    if v.verification_status is distinct from 'VERIFIED'
       and (v.manual_review_by is distinct from new.handled_by or v.manual_review_at is null
         or char_length(coalesce(v.manual_review_reason,''))<10) then
      raise exception using errcode='P0001', message='SMART_RECEIPT_MANUAL_REVIEW_REQUIRED';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.ex_payout_receipt_approval_guard() from public, anon, authenticated, service_role;
drop trigger if exists trg_ex_payout_receipt_approval_guard on public.ex_orders;
create trigger trg_ex_payout_receipt_approval_guard
  before update of status,payout_receipt_url,payout_iqd,admin_note on public.ex_orders
  for each row execute function public.ex_payout_receipt_approval_guard();
