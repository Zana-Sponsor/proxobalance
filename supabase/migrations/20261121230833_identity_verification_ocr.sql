-- Identity-document OCR uses the existing receipt-read Edge Function and reader key.
-- OCR results are kept in a separate, non-customer-readable table. The Edge Function
-- reads documents with the service role and stores only structured fields (no raw OCR text).

create table if not exists public.ex_identity_verification_ocr (
  verification_id uuid primary key
    references public.ex_identity_verifications(id) on delete cascade,
  status text not null default 'queued'
    check (status in ('queued', 'processing', 'complete', 'error')),
  is_identity_document boolean,
  extracted_full_legal_name text,
  extracted_date_of_birth date,
  extracted_document_number text,
  extracted_document_type text,
  error_code text,
  model text,
  processed_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.ex_identity_verification_ocr enable row level security;
revoke all on table public.ex_identity_verification_ocr from public, anon, authenticated;
grant all on table public.ex_identity_verification_ocr to service_role;

create or replace function public.ex_identity_ocr_enqueue()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_key text;
  v_request_id bigint;
begin
  insert into public.ex_identity_verification_ocr (verification_id, status, updated_at)
  values (new.id, 'queued', now())
  on conflict (verification_id) do update
    set status = 'queued', error_code = null, updated_at = now();

  select decrypted_secret into v_key
    from vault.decrypted_secrets
   where name = 'receipt_read_key'
   limit 1;

  if v_key is null then
    update public.ex_identity_verification_ocr
       set status = 'error', error_code = 'reader_key_missing', updated_at = now()
     where verification_id = new.id;
    return null;
  end if;

  select net.http_post(
    url := 'https://pycxuugoblkslvwebxuu.supabase.co/functions/v1/receipt-read',
    body := jsonb_build_object('verification_id', new.id),
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-receipt-key', v_key),
    timeout_milliseconds := 10000
  ) into v_request_id;

  if v_request_id is null then
    update public.ex_identity_verification_ocr
       set status = 'error', error_code = 'queue_failed', updated_at = now()
     where verification_id = new.id;
  end if;
  return null;
exception when others then
  begin
    update public.ex_identity_verification_ocr
       set status = 'error', error_code = 'queue_failed', updated_at = now()
     where verification_id = new.id;
  exception when others then
    null;
  end;
  return null;
end;
$$;
revoke all on function public.ex_identity_ocr_enqueue() from public, anon, authenticated;

drop trigger if exists trg_ex_identity_verifications_ocr on public.ex_identity_verifications;
create trigger trg_ex_identity_verifications_ocr
  after insert on public.ex_identity_verifications
  for each row execute function public.ex_identity_ocr_enqueue();

-- The feature also covers pending requests that were submitted before this migration.
do $$
declare
  v_key text;
  v_verification_id uuid;
  v_request_id bigint;
begin
  select decrypted_secret into v_key
    from vault.decrypted_secrets
   where name = 'receipt_read_key'
   limit 1;

  for v_verification_id in
    select id from public.ex_identity_verifications where status = 'pending'
  loop
    insert into public.ex_identity_verification_ocr (verification_id, status, updated_at)
    values (v_verification_id, 'queued', now())
    on conflict (verification_id) do nothing;

    if v_key is null then
      update public.ex_identity_verification_ocr
         set status = 'error', error_code = 'reader_key_missing', updated_at = now()
       where verification_id = v_verification_id;
      continue;
    end if;

    begin
      select net.http_post(
        url := 'https://pycxuugoblkslvwebxuu.supabase.co/functions/v1/receipt-read',
        body := jsonb_build_object('verification_id', v_verification_id),
        headers := jsonb_build_object('Content-Type', 'application/json', 'x-receipt-key', v_key),
        timeout_milliseconds := 10000
      ) into v_request_id;
    exception when others then
      v_request_id := null;
    end;

    if v_request_id is null then
      update public.ex_identity_verification_ocr
         set status = 'error', error_code = 'queue_failed', updated_at = now()
       where verification_id = v_verification_id;
    end if;
  end loop;
end;
$$;

create or replace function public.ex_admin_kyc_ocr_retry(p_verification_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_key text;
  v_request_id bigint;
  v_status text;
begin
  perform public.ex_kyc_assert_admin();
  if p_verification_id is null or not exists (
    select 1 from public.ex_identity_verifications where id = p_verification_id
  ) then
    raise exception using errcode = 'P0001', message = 'KYC_VERIFICATION_NOT_FOUND';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('ex_kyc_ocr:' || p_verification_id::text, 0));
  insert into public.ex_identity_verification_ocr (verification_id, status, updated_at)
  values (p_verification_id, 'queued', now())
  on conflict (verification_id) do nothing;
  select status into v_status from public.ex_identity_verification_ocr
   where verification_id = p_verification_id for update;
  if v_status in ('queued', 'processing') then
    return jsonb_build_object('queued', true, 'status', v_status);
  end if;

  select decrypted_secret into v_key from vault.decrypted_secrets
   where name = 'receipt_read_key' limit 1;
  if v_key is null then
    update public.ex_identity_verification_ocr
       set status = 'error', error_code = 'reader_key_missing', updated_at = now()
     where verification_id = p_verification_id;
    return jsonb_build_object('queued', false, 'status', 'error');
  end if;

  update public.ex_identity_verification_ocr
     set status = 'queued', error_code = null, processed_at = null, updated_at = now()
   where verification_id = p_verification_id;
  select net.http_post(
    url := 'https://pycxuugoblkslvwebxuu.supabase.co/functions/v1/receipt-read',
    body := jsonb_build_object('verification_id', p_verification_id),
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-receipt-key', v_key),
    timeout_milliseconds := 10000
  ) into v_request_id;
  if v_request_id is null then
    update public.ex_identity_verification_ocr
       set status = 'error', error_code = 'queue_failed', updated_at = now()
     where verification_id = p_verification_id;
    return jsonb_build_object('queued', false, 'status', 'error');
  end if;
  return jsonb_build_object('queued', true, 'status', 'queued');
exception when others then
  if sqlstate = '42501' then
    raise;
  end if;
  begin
    update public.ex_identity_verification_ocr
       set status = 'error', error_code = 'queue_failed', updated_at = now()
     where verification_id = p_verification_id;
  exception when others then
    null;
  end;
  return jsonb_build_object('queued', false, 'status', 'error');
end;
$$;
revoke all on function public.ex_admin_kyc_ocr_retry(uuid) from public, anon, authenticated;
grant execute on function public.ex_admin_kyc_ocr_retry(uuid) to authenticated;

create or replace function public.ex_admin_kyc_ocr_result(p_verification_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  perform public.ex_kyc_assert_admin();

  select jsonb_build_object(
    'verification_id', v.id,
    'status', coalesce(o.status, 'not_queued'),
    'is_identity_document', o.is_identity_document,
    'extracted_full_legal_name', o.extracted_full_legal_name,
    'extracted_date_of_birth', o.extracted_date_of_birth,
    'extracted_document_number', o.extracted_document_number,
    'extracted_document_type', o.extracted_document_type,
    'error_code', o.error_code,
    'model', o.model,
    'processed_at', o.processed_at,
    'submitted_full_legal_name', v.full_legal_name,
    'submitted_date_of_birth', v.date_of_birth,
    'submitted_document_number', v.document_number,
    'account_name', p.full_name
  )
    into v_result
    from public.ex_identity_verifications v
    join public.ex_profiles p on p.id = v.user_id
    left join public.ex_identity_verification_ocr o on o.verification_id = v.id
   where v.id = p_verification_id;

  return coalesce(v_result, jsonb_build_object('status', 'not_found'));
end;
$$;
revoke all on function public.ex_admin_kyc_ocr_result(uuid) from public, anon, authenticated;
grant execute on function public.ex_admin_kyc_ocr_result(uuid) to authenticated;
