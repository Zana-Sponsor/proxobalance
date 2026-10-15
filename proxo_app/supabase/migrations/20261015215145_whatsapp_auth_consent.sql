-- Prepared for review; do not apply to production as part of the draft PR.
-- OTP material is service-only. n8n reserves before sending, then records the
-- provider result. No client ever receives a code or calls the raw verifier.
begin;

alter table public.otp_whatsapp enable row level security;
revoke all on public.otp_whatsapp from public, anon, authenticated;
grant select, insert, update on public.otp_whatsapp to service_role;
create index if not exists otp_whatsapp_phone_created_idx
  on public.otp_whatsapp(phone, created_at desc);

create or replace function public.get_or_generate_otp_whatsapp(
  p_phone text, p_purpose text default 'login'
) returns json language plpgsql security invoker set search_path = '' as $$
declare
  v_phone text := regexp_replace(coalesce(p_phone,''), '[^0-9]', '', 'g');
  v_row public.otp_whatsapp%rowtype;
  v_code text;
  v_id uuid := gen_random_uuid();
  v_count integer;
begin
  if v_phone !~ '^9647[0-9]{9}$' or p_purpose is null or p_purpose not in ('login','signup','reset_password') then
    return json_build_object('success',false,'error','bad_request');
  end if;
  -- Serialize all purposes for this phone, including concurrent first sends.
  perform pg_advisory_xact_lock(hashtextextended('whatsapp-otp:' || v_phone,0));
  select coalesce(sum(send_count),0) into v_count from public.otp_whatsapp
    -- Keep a reused row in the window until its last send ages out. Using
    -- only created_at would forget recent resends at the hour boundary.
    where phone=v_phone and coalesce(last_sent_at,created_at)>now()-interval '1 hour';
  if v_count>=5 then
    return json_build_object('success',false,'error','rate_limited','retry_after_seconds',3600);
  end if;
  if exists(select 1 from public.otp_whatsapp where phone=v_phone
      and last_sent_at>now()-interval '60 seconds') then
    return json_build_object('success',false,'error','rate_limited','retry_after_seconds',60);
  end if;
  select * into v_row from public.otp_whatsapp
    where phone=v_phone and purpose=p_purpose and not is_used and expires_at>now()
    order by created_at desc limit 1 for update;
  if v_row.id is not null then
    if v_row.locked_at is not null or v_row.verify_attempts>=5 then
      return json_build_object('success',false,'error','otp_locked','retry_after_seconds',300);
    end if;
    update public.otp_whatsapp set send_count=send_count+1,last_sent_at=now()
      where id=v_row.id returning * into v_row;
  else
    -- UUID entropy comes from PostgreSQL's cryptographically secure generator.
    v_code := lpad(((('x'||substr(replace(gen_random_uuid()::text,'-',''),1,8))::bit(32)::bigint)%1000000)::text,6,'0');
    insert into public.otp_whatsapp(id,phone,code,wevlix_message_id,purpose,
      expires_at,send_count,last_sent_at,message_status)
      values(v_id,v_phone,v_code,'pending:'||v_id,p_purpose,now()+interval '5 minutes',1,now(),'pending')
      returning * into v_row;
  end if;
  return json_build_object('success',true,'otp_id',v_row.id,'code',v_row.code,
    'expires_at',v_row.expires_at,'reused',v_row.send_count>1,
    'send_count',v_row.send_count,'client_message_id','proxo-otp-'||v_row.id||'-'||v_row.send_count);
end $$;

create or replace function public.pa_finish_whatsapp_otp_send(
  p_otp_id uuid, p_send_count integer, p_message_id text, p_status text
) returns jsonb language plpgsql security invoker set search_path = '' as $$
declare v_rows integer;
begin
  if p_message_id is null or length(p_message_id) not between 1 and 200
    or p_status is null or p_status not in ('queued','sent','delivered','read','failed') then
    return jsonb_build_object('success',false,'error','bad_request');
  end if;
  update public.otp_whatsapp set wevlix_message_id=p_message_id,
    message_status=p_status,status_updated_at=now()
    where id=p_otp_id and send_count=p_send_count;
  get diagnostics v_rows=row_count;
  return jsonb_build_object('success',v_rows=1);
end $$;

create or replace function public.pa_verify_whatsapp_otp(
  p_phone text, p_code text, p_purpose text
) returns json language plpgsql security invoker set search_path = '' as $$
declare
  v_phone text := regexp_replace(coalesce(p_phone,''),'[^0-9]','','g');
  v_row public.otp_whatsapp%rowtype;
begin
  if v_phone !~ '^9647[0-9]{9}$' or coalesce(p_code,'') !~ '^[0-9]{6}$'
      or p_purpose is null or p_purpose not in ('login','signup','reset_password') then
    return json_build_object('success',true,'data',json_build_object('verified',false));
  end if;
  select * into v_row from public.otp_whatsapp where phone=v_phone
    and purpose=p_purpose and not is_used and expires_at>now()
    order by created_at desc limit 1 for update;
  if v_row.id is null or v_row.locked_at is not null or v_row.verify_attempts>=5 then
    return json_build_object('success',true,'data',json_build_object('verified',false));
  end if;
  if v_row.code<>p_code then
    update public.otp_whatsapp set verify_attempts=verify_attempts+1,
      locked_at=case when verify_attempts+1>=5 then now() else locked_at end
      where id=v_row.id;
    return json_build_object('success',true,'data',json_build_object('verified',false));
  end if;
  update public.otp_whatsapp set is_used=true,verified_at=now() where id=v_row.id;
  return json_build_object('success',true,'data',json_build_object('verified',true,'otp_id',v_row.id));
end $$;

-- Revoke the older verifier too: it must never be an anonymous API.
revoke all on function public.get_or_generate_otp_whatsapp(text,text) from public,anon,authenticated;
revoke all on function public.verify_otp_whatsapp(text,text) from public,anon,authenticated;
revoke all on function public.pa_verify_whatsapp_otp(text,text,text) from public,anon,authenticated;
revoke all on function public.pa_finish_whatsapp_otp_send(uuid,integer,text,text) from public,anon,authenticated;
grant execute on function public.get_or_generate_otp_whatsapp(text,text),
  public.pa_verify_whatsapp_otp(text,text,text),
  public.pa_finish_whatsapp_otp_send(uuid,integer,text,text) to service_role;

create table if not exists public.whatsapp_marketing_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  phone text not null check(phone ~ '^\+9647[0-9]{9}$'),
  opted_in boolean not null default false,
  consent_version text not null,
  consent_locale text not null check(consent_locale in ('ckb','ar','kmr')),
  consent_text text not null,
  source text not null check(source in ('signup','profile','support')),
  updated_at timestamptz not null default now(),
  accepted_at timestamptz,
  withdrawn_at timestamptz
);
create table if not exists public.whatsapp_marketing_consent_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  phone text not null, opted_in boolean not null, consent_version text not null,
  consent_locale text not null, consent_text text not null, source text not null,
  recorded_at timestamptz not null default now()
);
create index if not exists whatsapp_marketing_events_user_idx
  on public.whatsapp_marketing_consent_events(user_id,recorded_at desc);
alter table public.whatsapp_marketing_preferences enable row level security;
alter table public.whatsapp_marketing_consent_events enable row level security;
revoke all on public.whatsapp_marketing_preferences,public.whatsapp_marketing_consent_events from public,anon,authenticated;
grant select on public.whatsapp_marketing_preferences to authenticated;
grant select,insert,update on public.whatsapp_marketing_preferences to service_role;
grant select,insert on public.whatsapp_marketing_consent_events to service_role;
drop policy if exists own_whatsapp_marketing_preference on public.whatsapp_marketing_preferences;
create policy own_whatsapp_marketing_preference on public.whatsapp_marketing_preferences
  for select to authenticated using(user_id=(select auth.uid()));

-- Internal owner-checked writer. No client-supplied timestamp or consent copy.
create schema if not exists proxo_private;
revoke all on schema proxo_private from public,anon,authenticated;
create or replace function proxo_private.record_whatsapp_marketing_choice(
  p_user_id uuid, p_opted_in boolean, p_version text, p_locale text, p_source text
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_phone text; v_text text; v_hint text; v_old public.whatsapp_marketing_preferences%rowtype;
begin
  if p_opted_in is null or p_version<>'whatsapp-marketing-v1' or p_version is null
    or p_locale not in ('ckb','ar','kmr') or p_locale is null
    or p_source is null or p_source not in ('signup','profile','support') then
    raise exception 'invalid_consent' using errcode='22023';
  end if;
  -- The signup Edge Function has already verified the phone. Profile changes
  -- use Auth's confirmed phone, never a freely editable profile phone.
  select '+'||regexp_replace(phone,'[^0-9]','','g') into v_phone from auth.users
    where id=p_user_id and phone_confirmed_at is not null;
  if v_phone is null or v_phone !~ '^\+9647[0-9]{9}$' then
    if p_opted_in then raise exception 'verified_phone_required' using errcode='22023'; end if;
    select phone into v_phone from public.whatsapp_marketing_preferences where user_id=p_user_id;
    if v_phone is null then return jsonb_build_object('ok',true,'opted_in',false); end if;
  end if;
  v_text := case p_locale
    when 'ar' then 'أوافق على استلام الإشعارات والمستجدات عبر واتساب'
    when 'kmr' then 'ئەز ڕازیم ئاگەهداری و نووکرنێن نوی ل ڕێکا واتسئاپ وەربگرم'
    else 'ڕەزامەندم، بە هاتنی ئاگاداری و نوێکارییەکان لە ڕێگەی واتسئاپ' end;
  v_hint := case p_locale
    when 'ar' then 'رسائل Proxo التسويقية؛ اختياري ويمكنك إيقافها من الملف الشخصي.'
    when 'kmr' then 'نامەیێن مارکێتینگا Proxo؛ ب دڵێ تەیە و دشێی ژ پرۆفایلێ ناچالاک بکەی.'
    else 'نامەکانی مارکێتینگی Proxo؛ ئارەزوومەندانەیە و لە پڕۆفایل دەتوانیت ناچالاکی بکەیت.' end;
  perform pg_advisory_xact_lock(hashtextextended('whatsapp-marketing:'||p_user_id,0));
  select * into v_old from public.whatsapp_marketing_preferences where user_id=p_user_id for update;
  if v_old.user_id is not null and v_old.opted_in=p_opted_in and v_old.phone=v_phone
      and v_old.consent_version=p_version then
    return jsonb_build_object('ok',true,'opted_in',p_opted_in);
  end if;
  insert into public.whatsapp_marketing_preferences(user_id,phone,opted_in,consent_version,
    consent_locale,consent_text,source,updated_at,accepted_at,withdrawn_at)
    values(p_user_id,v_phone,p_opted_in,p_version,p_locale,v_text||E'\n'||v_hint,p_source,now(),
      case when p_opted_in then now() else v_old.accepted_at end,
      case when p_opted_in then null when v_old.opted_in then now() else v_old.withdrawn_at end)
    on conflict(user_id) do update set phone=excluded.phone,opted_in=excluded.opted_in,
      consent_version=excluded.consent_version,consent_locale=excluded.consent_locale,
      consent_text=excluded.consent_text,source=excluded.source,updated_at=excluded.updated_at,
      accepted_at=excluded.accepted_at,withdrawn_at=excluded.withdrawn_at;
  insert into public.whatsapp_marketing_consent_events(user_id,phone,opted_in,
    consent_version,consent_locale,consent_text,source)
    values(p_user_id,v_phone,p_opted_in,p_version,p_locale,v_text||E'\n'||v_hint,p_source);
  return jsonb_build_object('ok',true,'opted_in',p_opted_in);
end $$;
revoke all on function proxo_private.record_whatsapp_marketing_choice(uuid,boolean,text,text,text) from public,anon,authenticated;

create or replace function public.pa_record_signup_whatsapp_marketing(
  p_user_id uuid,p_opted_in boolean,p_version text,p_locale text
) returns jsonb language sql security definer set search_path = '' as $$
  select proxo_private.record_whatsapp_marketing_choice(p_user_id,p_opted_in,p_version,p_locale,'signup');
$$;
revoke all on function public.pa_record_signup_whatsapp_marketing(uuid,boolean,text,text) from public,anon,authenticated;
grant execute on function public.pa_record_signup_whatsapp_marketing(uuid,boolean,text,text) to service_role;

create or replace function public.pa_set_whatsapp_marketing(p_opted_in boolean,p_version text,p_locale text)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'authentication_required' using errcode='42501'; end if;
  return proxo_private.record_whatsapp_marketing_choice(auth.uid(),p_opted_in,p_version,p_locale,'profile');
end $$;
revoke all on function public.pa_set_whatsapp_marketing(boolean,text,text) from public,anon;
grant execute on function public.pa_set_whatsapp_marketing(boolean,text,text) to authenticated;

-- Service-side audience gate: consent must still refer to the confirmed number.
-- Use this immediately before any approved MARKETING template is sent.
create or replace function public.pa_whatsapp_marketing_allowed(p_user_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.whatsapp_marketing_preferences p join auth.users u on u.id=p.user_id
    where p.user_id=p_user_id and p.opted_in and u.phone_confirmed_at is not null
      and p.phone='+'||regexp_replace(u.phone,'[^0-9]','','g'));
$$;
revoke all on function public.pa_whatsapp_marketing_allowed(uuid) from public,anon,authenticated;
grant execute on function public.pa_whatsapp_marketing_allowed(uuid) to service_role;

-- Only the trusted support/inbound-message processor may invoke this after
-- authenticating the sender. It handles requests made outside the app too.
create or replace function public.pa_withdraw_whatsapp_marketing(p_phone text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_row public.whatsapp_marketing_preferences%rowtype;
begin
  for v_row in select * from public.whatsapp_marketing_preferences
      where phone='+'||regexp_replace(coalesce(p_phone,''),'[^0-9]','','g') and opted_in
  loop
    perform proxo_private.record_whatsapp_marketing_choice(v_row.user_id,false,
      'whatsapp-marketing-v1',v_row.consent_locale,'support');
  end loop;
  return jsonb_build_object('ok',true);
end $$;
revoke all on function public.pa_withdraw_whatsapp_marketing(text) from public,anon,authenticated;
grant execute on function public.pa_withdraw_whatsapp_marketing(text) to service_role;
commit;
