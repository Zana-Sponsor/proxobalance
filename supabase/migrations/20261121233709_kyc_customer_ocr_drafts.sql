-- Pre-submit identity OCR drafts. The OCR table remains inaccessible directly;
-- customers receive only their own structured data through guarded RPCs.

alter table public.ex_identity_verifications
  add column if not exists document_issue_date date,
  add column if not exists document_expiry_date date;

alter table public.ex_identity_verification_ocr
  add column if not exists extracted_document_issue_date date,
  add column if not exists extracted_document_expiry_date date;

create table if not exists public.ex_identity_verification_ocr_drafts (
  draft_id uuid primary key,
  user_id uuid not null references public.ex_profiles(id) on delete cascade,
  document_type text not null check (document_type in ('national_id','driving_license')),
  front_image_path text,
  back_image_path text,
  ocr_attempts smallint not null default 0 check (ocr_attempts between 0 and 3),
  status text not null default 'uploading' check (status in ('uploading','queued','processing','complete','error')),
  is_identity_document boolean,
  extracted_full_legal_name text,
  extracted_date_of_birth date,
  extracted_document_number text,
  extracted_document_type text,
  extracted_document_issue_date date,
  extracted_document_expiry_date date,
  error_code text,
  model text,
  processed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '30 minutes')
);
create index if not exists ex_kyc_ocr_drafts_user_created_idx
  on public.ex_identity_verification_ocr_drafts(user_id, created_at desc);
create index if not exists ex_kyc_ocr_drafts_expires_idx
  on public.ex_identity_verification_ocr_drafts(expires_at);

alter table public.ex_identity_verification_ocr_drafts enable row level security;
revoke all on table public.ex_identity_verification_ocr_drafts from public, anon, authenticated;
grant all on table public.ex_identity_verification_ocr_drafts to service_role;

-- Preserve existing owner/status/volume checks while allowing uploads only to
-- an unexpired draft created by the same authenticated user.
create or replace function public.ex_kyc_can_upload(p_folder text)
returns boolean language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_can boolean;
begin
  if v_uid is null or p_folder is null
     or p_folder !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then return false; end if;
  if exists(select 1 from public.ex_identity_verifications where id=p_folder::uuid) then return false; end if;
  if exists(select 1 from public.ex_profiles where id=v_uid and is_banned) then return false; end if;
  if (select count(*) from storage.objects o where o.bucket_id='identity-documents' and o.owner_id=v_uid::text
      and o.created_at>now()-interval '24 hours')>=30 then return false; end if;
  if exists(select 1 from public.ex_identity_verification_ocr_drafts d where d.draft_id=p_folder::uuid) then
    if exists(select 1 from public.ex_identity_verification_ocr_drafts d
        where d.draft_id=p_folder::uuid and d.user_id=v_uid and d.expires_at>now()
          and d.status in ('uploading','error') and d.ocr_attempts<3) then
      select s.can_submit into v_can from public.ex_kyc_state(v_uid) s;
      return coalesce(v_can,false);
    end if;
    return false;
  end if;
  select s.can_submit into v_can from public.ex_kyc_state(v_uid) s;
  return coalesce(v_can,false);
end; $$;

create or replace function public.ex_kyc_ocr_draft_start(p_draft_id uuid, p_document_type text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_state record; v_count integer;
begin
  if v_uid is null then raise exception using errcode='42501', message='AUTH_REQUIRED'; end if;
  if p_draft_id is null or p_document_type is null or p_document_type not in ('national_id','driving_license') then
    raise exception using errcode='P0001', message='KYC_DRAFT_INVALID';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('ex_kyc_ocr_draft:'||v_uid::text,0));
  select * into v_state from public.ex_kyc_state(v_uid);
  if not v_state.can_submit then raise exception using errcode='P0001', message='KYC_ALREADY_PENDING'; end if;
  delete from public.ex_identity_verification_ocr_drafts where expires_at<=now();
  select count(*) into v_count from public.ex_identity_verification_ocr_drafts
   where user_id=v_uid and created_at>now()-interval '1 hour';
  if v_count>=5 then raise exception using errcode='P0001', message='KYC_DRAFT_RATE_LIMIT'; end if;
  insert into public.ex_identity_verification_ocr_drafts(draft_id,user_id,document_type)
  values(p_draft_id,v_uid,p_document_type);
  return jsonb_build_object('draft_id',p_draft_id,'status','uploading','expires_in_seconds',1800);
exception when unique_violation then
  raise exception using errcode='P0001', message='KYC_DRAFT_EXISTS';
end; $$;
revoke all on function public.ex_kyc_ocr_draft_start(uuid,text) from public, anon;
grant execute on function public.ex_kyc_ocr_draft_start(uuid,text) to authenticated;

create or replace function public.ex_kyc_ocr_draft_queue(
  p_draft_id uuid, p_front_path text, p_back_path text default null
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_key text; v_request_id bigint; v_type text; v_prefix text; v_attempts smallint;
begin
  if v_uid is null then raise exception using errcode='42501', message='AUTH_REQUIRED'; end if;
  select document_type,ocr_attempts into v_type,v_attempts from public.ex_identity_verification_ocr_drafts
   where draft_id=p_draft_id and user_id=v_uid and expires_at>now() and status in ('uploading','error') for update;
  if not found then raise exception using errcode='P0001', message='KYC_DRAFT_NOT_FOUND'; end if;
  if v_attempts>=3 then raise exception using errcode='P0001', message='KYC_OCR_RATE_LIMIT'; end if;
  v_prefix:=v_uid::text||'/'||p_draft_id::text||'/';
  if p_front_path not in (v_prefix||'front.jpg',v_prefix||'front.png',v_prefix||'front.webp')
     or (p_back_path is not null and p_back_path not in (v_prefix||'back.jpg',v_prefix||'back.png',v_prefix||'back.webp')) then
    raise exception using errcode='P0001', message='KYC_DRAFT_PATH_INVALID';
  end if;
  if not exists(select 1 from storage.objects o where o.bucket_id='identity-documents' and o.name=p_front_path
      and (o.owner_id=v_uid::text or o.owner=v_uid) and coalesce((o.metadata->>'size')::bigint,0)>0)
    or (p_back_path is not null and not exists(select 1 from storage.objects o where o.bucket_id='identity-documents' and o.name=p_back_path
      and (o.owner_id=v_uid::text or o.owner=v_uid) and coalesce((o.metadata->>'size')::bigint,0)>0)) then
    raise exception using errcode='P0001', message='KYC_DRAFT_IMAGE_MISSING';
  end if;
  select decrypted_secret into v_key from vault.decrypted_secrets where name='receipt_read_key' limit 1;
  if v_key is null then raise exception using errcode='P0001', message='KYC_OCR_KEY_MISSING'; end if;
  update public.ex_identity_verification_ocr_drafts set front_image_path=p_front_path, back_image_path=p_back_path,
    status='queued', error_code=null, ocr_attempts=ocr_attempts+1, updated_at=now()
   where draft_id=p_draft_id and user_id=v_uid;
  select net.http_post(url:='https://pycxuugoblkslvwebxuu.supabase.co/functions/v1/receipt-read',
    body:=jsonb_build_object('identity_draft_id',p_draft_id),
    headers:=jsonb_build_object('Content-Type','application/json','x-receipt-key',v_key),timeout_milliseconds:=10000)
    into v_request_id;
  if v_request_id is null then
    update public.ex_identity_verification_ocr_drafts set status='error',error_code='queue_failed',updated_at=now() where draft_id=p_draft_id;
    raise exception using errcode='P0001', message='KYC_OCR_QUEUE_FAILED';
  end if;
  return jsonb_build_object('queued',true,'status','queued');
end; $$;
revoke all on function public.ex_kyc_ocr_draft_queue(uuid,text,text) from public, anon;
grant execute on function public.ex_kyc_ocr_draft_queue(uuid,text,text) to authenticated;

create or replace function public.ex_kyc_ocr_draft_result(p_draft_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_result jsonb;
begin
  if auth.uid() is null then raise exception using errcode='42501', message='AUTH_REQUIRED'; end if;
  select jsonb_build_object('draft_id',d.draft_id,'status',case when d.expires_at<=now() then 'expired' else d.status end,
    'is_identity_document',d.is_identity_document,'full_legal_name',d.extracted_full_legal_name,
    'date_of_birth',d.extracted_date_of_birth,'document_number',d.extracted_document_number,
    'document_type',d.extracted_document_type,'issue_date',d.extracted_document_issue_date,
    'expiry_date',d.extracted_document_expiry_date,'error_code',d.error_code)
    into v_result from public.ex_identity_verification_ocr_drafts d
   where d.draft_id=p_draft_id and d.user_id=auth.uid();
  return coalesce(v_result,jsonb_build_object('status','not_found'));
end; $$;
revoke all on function public.ex_kyc_ocr_draft_result(uuid) from public, anon;
grant execute on function public.ex_kyc_ocr_draft_result(uuid) to authenticated;

-- Extend the submit RPC without changing its validation/decision semantics.
drop function if exists public.ex_kyc_submit(uuid,text,text,date,text,text,text);
create function public.ex_kyc_submit(
  p_verification_id uuid,p_document_type text,p_full_legal_name text,p_date_of_birth date,
  p_document_number text,p_front_path text,p_back_path text default null,
  p_document_issue_date date default null,p_document_expiry_date date default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_uid uuid:=auth.uid(); v_banned boolean; s record; v_name text; v_number text; v_prefix text;
  v_req_id uuid; v_prior int; v_recent int; v_event text;
begin
  if v_uid is null then raise exception using errcode='42501',message='AUTH_REQUIRED'; end if;
  select is_banned into v_banned from public.ex_profiles where id=v_uid;
  if not found then raise exception using errcode='P0001',message='PROFILE_NOT_FOUND'; end if;
  if v_banned then raise exception using errcode='42501',message='ACCOUNT_BANNED'; end if;
  perform pg_advisory_xact_lock(hashtextextended('ex_kyc:'||v_uid::text,0));
  select * into s from public.ex_kyc_state(v_uid);
  if not s.can_submit then raise exception using errcode='P0001',message=case when s.status='pending' then 'KYC_ALREADY_PENDING' else 'KYC_ALREADY_APPROVED' end; end if;
  if p_verification_id is null then raise exception using errcode='P0001',message='KYC_INVALID_ID'; end if;
  if exists(select 1 from public.ex_identity_verifications where id=p_verification_id) then raise exception using errcode='P0001',message='KYC_DUPLICATE_SUBMISSION'; end if;
  select count(*) into v_recent from public.ex_identity_verifications where user_id=v_uid and submitted_at>now()-interval '24 hours';
  if v_recent>=5 then raise exception using errcode='P0001',message='KYC_RATE_LIMIT'; end if;
  if p_document_type is null or p_document_type not in ('national_id','driving_license') then raise exception using errcode='P0001',message='KYC_DOCUMENT_TYPE_INVALID'; end if;
  v_name:=nullif(regexp_replace(btrim(coalesce(p_full_legal_name,'')),'[[:space:]]+',' ','g'),'');
  if v_name is null or char_length(v_name)<5 or char_length(v_name)>120 or array_length(regexp_split_to_array(v_name,' '),1)<>3
    or v_name ~ '[0-9٠-٩۰-۹<>{}/@#$%^*=+_|~]' or position(chr(92) in v_name)>0 or position('[' in v_name)>0 or position(']' in v_name)>0
    then raise exception using errcode='P0001',message='KYC_NAME_INVALID'; end if;
  if p_date_of_birth is null or p_date_of_birth<date '1900-01-01' or p_date_of_birth>(now() at time zone 'Asia/Baghdad')::date then raise exception using errcode='P0001',message='KYC_DOB_INVALID'; end if;
  if p_document_issue_date is not null and (p_document_issue_date<date '1900-01-01' or p_document_issue_date>(now() at time zone 'Asia/Baghdad')::date) then raise exception using errcode='P0001',message='KYC_ISSUE_DATE_INVALID'; end if;
  if p_document_expiry_date is not null and p_document_expiry_date<date '1900-01-01' then raise exception using errcode='P0001',message='KYC_EXPIRY_DATE_INVALID'; end if;
  if p_document_issue_date is not null and p_document_expiry_date is not null and p_document_expiry_date<=p_document_issue_date then raise exception using errcode='P0001',message='KYC_DOCUMENT_DATES_INVALID'; end if;
  v_number:=upper(regexp_replace(coalesce(p_document_number,''),'[[:space:]]','','g'));
  v_number:=translate(v_number,'٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹','01234567890123456789');
  if v_number !~ '^[A-Z0-9-]{4,30}$' then raise exception using errcode='P0001',message='KYC_NUMBER_INVALID'; end if;
  v_prefix:=v_uid::text||'/'||p_verification_id::text||'/';
  if p_front_path not in(v_prefix||'front.jpg',v_prefix||'front.png',v_prefix||'front.webp') then raise exception using errcode='P0001',message='KYC_FRONT_PATH_INVALID'; end if;
  if p_back_path is null then raise exception using errcode='P0001',message='KYC_BACK_REQUIRED'; end if;
  if p_back_path not in(v_prefix||'back.jpg',v_prefix||'back.png',v_prefix||'back.webp') then raise exception using errcode='P0001',message='KYC_BACK_PATH_INVALID'; end if;
  if not exists(select 1 from storage.objects o where o.bucket_id='identity-documents' and o.name=p_front_path and (o.owner_id=v_uid::text or o.owner=v_uid) and coalesce((o.metadata->>'size')::bigint,0)>0) then raise exception using errcode='P0001',message='KYC_FRONT_IMAGE_MISSING'; end if;
  if not exists(select 1 from storage.objects o where o.bucket_id='identity-documents' and o.name=p_back_path and (o.owner_id=v_uid::text or o.owner=v_uid) and coalesce((o.metadata->>'size')::bigint,0)>0) then raise exception using errcode='P0001',message='KYC_BACK_IMAGE_MISSING'; end if;
  select id into v_req_id from public.ex_kyc_requests where user_id=v_uid and status in('open','submitted') for update;
  select count(*) into v_prior from public.ex_identity_verifications where user_id=v_uid;
  insert into public.ex_identity_verifications(id,user_id,request_id,document_type,full_legal_name,date_of_birth,document_number,front_image_path,back_image_path,document_issue_date,document_expiry_date,status,submitted_at)
  values(p_verification_id,v_uid,v_req_id,p_document_type,v_name,p_date_of_birth,v_number,p_front_path,p_back_path,p_document_issue_date,p_document_expiry_date,'pending',now());
  if v_req_id is not null then update public.ex_kyc_requests set status='submitted' where id=v_req_id; end if;
  v_event:=case when v_prior>0 then 'resubmitted' else 'submitted' end;
  insert into public.ex_kyc_events(user_id,verification_id,request_id,event,actor_id,actor_role) values(v_uid,p_verification_id,v_req_id,v_event,v_uid,'user');
  return jsonb_build_object('id',p_verification_id,'status','pending','event',v_event);
exception when unique_violation then raise exception using errcode='P0001',message='KYC_ALREADY_PENDING';
end; $$;
revoke all on function public.ex_kyc_submit(uuid,text,text,date,text,text,text,date,date) from public,anon;
grant execute on function public.ex_kyc_submit(uuid,text,text,date,text,text,text,date,date) to authenticated;

-- Keep completed pre-submit OCR and the final review record in sync; retry normal queue otherwise.
create or replace function public.ex_identity_ocr_enqueue()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_key text; v_request_id bigint; d record;
begin
  select * into d from public.ex_identity_verification_ocr_drafts where draft_id=new.id and user_id=new.user_id and expires_at>now();
  if found and d.status='complete' then
    insert into public.ex_identity_verification_ocr(verification_id,status,is_identity_document,extracted_full_legal_name,extracted_date_of_birth,extracted_document_number,extracted_document_type,extracted_document_issue_date,extracted_document_expiry_date,error_code,model,processed_at,updated_at)
    values(new.id,'complete',d.is_identity_document,d.extracted_full_legal_name,d.extracted_date_of_birth,d.extracted_document_number,d.extracted_document_type,d.extracted_document_issue_date,d.extracted_document_expiry_date,null,d.model,d.processed_at,now())
    on conflict(verification_id) do update set status=excluded.status,is_identity_document=excluded.is_identity_document,extracted_full_legal_name=excluded.extracted_full_legal_name,extracted_date_of_birth=excluded.extracted_date_of_birth,extracted_document_number=excluded.extracted_document_number,extracted_document_type=excluded.extracted_document_type,extracted_document_issue_date=excluded.extracted_document_issue_date,extracted_document_expiry_date=excluded.extracted_document_expiry_date,error_code=null,model=excluded.model,processed_at=excluded.processed_at,updated_at=now();
    return null;
  end if;
  insert into public.ex_identity_verification_ocr(verification_id,status,updated_at) values(new.id,'queued',now()) on conflict(verification_id) do update set status='queued',error_code=null,updated_at=now();
  select decrypted_secret into v_key from vault.decrypted_secrets where name='receipt_read_key' limit 1;
  if v_key is null then update public.ex_identity_verification_ocr set status='error',error_code='reader_key_missing',updated_at=now() where verification_id=new.id; return null; end if;
  select net.http_post(url:='https://pycxuugoblkslvwebxuu.supabase.co/functions/v1/receipt-read',body:=jsonb_build_object('verification_id',new.id),headers:=jsonb_build_object('Content-Type','application/json','x-receipt-key',v_key),timeout_milliseconds:=10000) into v_request_id;
  if v_request_id is null then update public.ex_identity_verification_ocr set status='error',error_code='queue_failed',updated_at=now() where verification_id=new.id; end if;
  return null;
exception when others then
  update public.ex_identity_verification_ocr set status='error',error_code='queue_failed',updated_at=now() where verification_id=new.id;
  return null;
end; $$;

create or replace function public.ex_kyc_my_status()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); s record; v_ver jsonb; v_verified text; v_prof record;
begin
  if v_uid is null then raise exception using errcode='42501',message='AUTH_REQUIRED'; end if;
  select * into s from public.ex_kyc_state(v_uid);
  select username,role,full_name into v_prof from public.ex_profiles where id=v_uid;
  v_verified:=public.ex_kyc_verified_name(v_uid);
  select jsonb_build_object('id',v.id,'status',v.status,'document_type',v.document_type,'full_legal_name',v.full_legal_name,
    'date_of_birth',v.date_of_birth,'document_number',v.document_number,'document_issue_date',v.document_issue_date,
    'document_expiry_date',v.document_expiry_date,'rejection_reason',v.rejection_reason,'submitted_at',v.submitted_at,
    'reviewed_at',v.reviewed_at,'has_back',v.back_image_path is not null) into v_ver
    from public.ex_identity_verifications v where v.id=s.verification_id;
  return jsonb_build_object('status',s.status,'can_submit',s.can_submit,
    'request',case when s.request_id is null then null else jsonb_build_object('id',s.request_id,'status',s.request_status,'reason',s.request_reason,'created_at',s.request_created_at) end,
    'verification',v_ver,'username',v_prof.username,'role',v_prof.role,'account_name',v_prof.full_name,
    'exchange_blocked',public.ex_kyc_exchange_blocked(v_uid),'name_locked',v_verified is not null,'verified_name',v_verified);
end; $$;
revoke all on function public.ex_kyc_my_status() from public,anon;
grant execute on function public.ex_kyc_my_status() to authenticated;

create or replace function public.ex_admin_kyc_ocr_result(p_verification_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_result jsonb;
begin
  perform public.ex_kyc_assert_admin();
  select jsonb_build_object('verification_id',v.id,'status',coalesce(o.status,'not_queued'),'is_identity_document',o.is_identity_document,
    'extracted_full_legal_name',o.extracted_full_legal_name,'extracted_date_of_birth',o.extracted_date_of_birth,
    'extracted_document_number',o.extracted_document_number,'extracted_document_type',o.extracted_document_type,
    'extracted_document_issue_date',o.extracted_document_issue_date,'extracted_document_expiry_date',o.extracted_document_expiry_date,
    'error_code',o.error_code,'model',o.model,'processed_at',o.processed_at,'submitted_full_legal_name',v.full_legal_name,
    'submitted_date_of_birth',v.date_of_birth,'submitted_document_number',v.document_number,
    'submitted_document_issue_date',v.document_issue_date,'submitted_document_expiry_date',v.document_expiry_date,'account_name',p.full_name)
    into v_result from public.ex_identity_verifications v join public.ex_profiles p on p.id=v.user_id
    left join public.ex_identity_verification_ocr o on o.verification_id=v.id where v.id=p_verification_id;
  return coalesce(v_result,jsonb_build_object('status','not_found'));
end; $$;
revoke all on function public.ex_admin_kyc_ocr_result(uuid) from public,anon;
grant execute on function public.ex_admin_kyc_ocr_result(uuid) to authenticated;
