-- ═════════════════════════════════════════════════════════════════
-- Account name, mobile number and WhatsApp (v42)
--
--  • Name: once every 30 days; fixed for good after identity verification
--    (the KYC lock already exists and is kept).
--  • Mobile number: only through /api/auth with a WhatsApp code sent to the
--    NEW number; once every 30 days. The browser can no longer write it.
--  • A verified number belongs to one account only (unique index).
--  • WhatsApp notifications go only to the account's verified number.
--
-- Nothing is deleted: existing names, numbers, balances, orders and WhatsApp
-- opt-ins stay. Accounts whose number was never verified keep it on the
-- profile, but WhatsApp waits until they verify it.
-- ═════════════════════════════════════════════════════════════════

-- 1. separate stamps for the name and the number ---------------------------
alter table public.ex_profiles
  add column if not exists name_changed_at   timestamptz,
  add column if not exists phone_changed_at  timestamptz,
  add column if not exists phone_verified_at timestamptz;

comment on column public.ex_profiles.name_changed_at   is 'Last name change by the customer; the next one is allowed 30 days later.';
comment on column public.ex_profiles.phone_changed_at  is 'Last verified number change; the next one is allowed 30 days later.';
comment on column public.ex_profiles.phone_verified_at is 'Set when the number was proven with a WhatsApp code (sign-up or number change). WhatsApp is sent only to a verified number.';

-- the last 7-day stamp counts as the last name change (the stricter reading)
update public.ex_profiles
   set name_changed_at = identity_updated_at
 where name_changed_at is null and identity_updated_at is not null;

-- accounts created with a number proved it with a code at sign-up
update public.ex_profiles p
   set phone_verified_at = coalesce(p.created_at, now())
  from auth.users u
 where u.id = p.id
   and u.email like '%@phone.proxobalance.app'
   and p.phone ~ '^07[0-9]{9}$'
   and p.phone_verified_at is null;

-- 2. one verified number = one account --------------------------------------
create unique index if not exists ex_profiles_verified_phone_uniq
  on public.ex_profiles (phone) where phone_verified_at is not null;

-- 3. codes for a number change ------------------------------------------------
alter table public.ex_auth_codes drop constraint if exists ex_auth_codes_purpose_check;
alter table public.ex_auth_codes add constraint ex_auth_codes_purpose_check
  check (purpose in ('signup', 'login', 'reset', 'change_phone'));

-- 4. new profiles start without stamps (only the server sets them) ---------
create or replace function public.ex_profiles_before_insert()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_backend boolean := public.ex_is_backend_request();
begin
  if not v_backend then
  new.role := 'user'; new.is_admin := false; new.is_banned := false;
  new.username := null; new.identity_updated_at := null; new.created_at := now();
  new.username_changed_at := null;
  new.name_changed_at := null; new.phone_changed_at := null; new.phone_verified_at := null;
  end if;
  new.role := coalesce(new.role, 'user');
  if v_backend and new.is_admin and new.role = 'user' then new.role := 'admin'; end if;
  new.is_admin := new.role in ('admin', 'super_admin');
  if new.username is null or btrim(new.username) = '' then
  new.username := public.ex_generate_username(new.email);
  else
  new.username := lower(btrim(new.username));
  end if;
  return new;
end;
$function$;

-- 5. profile guard: number frozen for the browser, name once per 30 days ---
create or replace function public.ex_profiles_guard()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_available_at timestamptz;
  v_backend      boolean := public.ex_is_backend_request();
  v_uid          uuid    := auth.uid();
  v_super        boolean := public.ex_is_super_admin();
  v_locked_name  text;
  v_username_rpc boolean := coalesce(current_setting('proxo.username_change', true), '') = '1';
begin
  -- username (and its "already changed" stamp) can only move through ex_change_username()
  if not v_backend and not v_username_rpc then
    new.username := old.username;
    new.username_changed_at := old.username_changed_at;
  end if;
  if new.username is null then
    new.username := old.username;
  end if;

  -- the mobile number and its stamps change only on the server, after a WhatsApp
  -- code sent to the new number (/api/auth → ex_account_phone_set). Admins too.
  if not v_backend then
    new.phone             := old.phone;
    new.phone_verified_at := old.phone_verified_at;
    new.phone_changed_at  := old.phone_changed_at;
    new.name_changed_at   := old.name_changed_at;
  end if;

  new.role := coalesce(new.role, old.role);

  if new.is_admin is distinct from old.is_admin and new.role is not distinct from old.role then
    new.role := case
                  when new.is_admin then case when old.role = 'super_admin' then 'super_admin' else 'admin' end
                  else 'user'
                end;
  end if;

  if new.role is distinct from old.role then
    if not v_backend then
      if not v_super then
        raise exception using errcode = '42501', message = 'ROLE_CHANGE_FORBIDDEN';
      end if;
      if old.id = v_uid then
        raise exception using errcode = '42501', message = 'ROLE_SELF_CHANGE_FORBIDDEN';
      end if;
    end if;
    if old.role = 'super_admin'
       and not exists (select 1 from public.ex_profiles
                        where role = 'super_admin' and id <> old.id and not is_banned) then
      raise exception using errcode = 'P0001', message = 'LAST_SUPER_ADMIN';
    end if;
  end if;
  new.is_admin := new.role in ('admin', 'super_admin');

  if new.is_banned is distinct from old.is_banned and not v_backend then
    if old.id = v_uid then
      raise exception using errcode = '42501', message = 'SELF_BAN_FORBIDDEN';
    end if;
    if not v_super then
      raise exception using errcode = '42501', message = 'ADMIN_BAN_FORBIDDEN';
    end if;
  end if;

  -- Verified name lock (every browser caller, admins included).
  if not v_backend
     and public.ex_normalize_person_name(new.full_name)
         is distinct from public.ex_normalize_person_name(old.full_name) then
    v_locked_name := public.ex_kyc_verified_name(old.id);
    if v_locked_name is not null
       and public.ex_normalize_person_name(new.full_name)
           is distinct from public.ex_normalize_person_name(v_locked_name) then
      raise exception using
        errcode = 'P0001',
        message = 'PROFILE_NAME_LOCKED_BY_KYC',
        hint    = 'The account name must match the verified identity document.';
    end if;
  end if;

  if v_backend or public.is_ex_admin() then
    return new;
  end if;

  new.id                  := old.id;
  new.email               := old.email;
  new.role                := old.role;
  new.is_admin            := old.is_admin;
  new.is_banned           := old.is_banned;
  new.created_at          := old.created_at;
  new.identity_updated_at := old.identity_updated_at;

  new.full_name := nullif(regexp_replace(btrim(coalesce(new.full_name, '')), '[[:space:]]+', ' ', 'g'), '');

  if new.full_name is distinct from old.full_name then
    if new.full_name is null or char_length(new.full_name) < 3 or char_length(new.full_name) > 80 then
      raise exception using errcode = 'P0001', message = 'PROFILE_NAME_INVALID';
    end if;

    v_available_at := old.name_changed_at + interval '30 days';
    if old.name_changed_at is not null and v_available_at > now() then
      raise exception using
        errcode = 'P0001',
        message = 'PROFILE_NAME_COOLDOWN',
        detail  = v_available_at::text,
        hint    = 'The account name can be changed once every 30 days.';
    end if;

    new.name_changed_at     := now();
    new.identity_updated_at := now();
  end if;

  return new;
end;
$function$;

-- 6. number change (server only) ---------------------------------------------
-- Is this verified number already another account's? (also number sign-ins)
create or replace function public.ex_account_phone_taken(p_phone text, p_except uuid default null)
 returns boolean
 language sql
 stable
 security definer
 set search_path to ''
as $function$
  select exists (select 1 from public.ex_profiles
                  where phone = p_phone and phone_verified_at is not null
                    and id is distinct from p_except)
      or exists (select 1 from auth.users
                  where email = 'p964' || substr(p_phone, 2) || '@phone.proxobalance.app'
                    and id is distinct from p_except);
$function$;

-- Can this account switch to this number now?  {ok} or {ok:false, reason, available_at}
create or replace function public.ex_account_phone_status(p_user uuid, p_phone text)
 returns jsonb
 language plpgsql
 stable
 security definer
 set search_path to ''
as $function$
declare v public.ex_profiles;
begin
  if p_phone is null or p_phone !~ '^07[3-9][0-9]{8}$' then
    return jsonb_build_object('ok', false, 'reason', 'invalid');
  end if;
  select * into v from public.ex_profiles where id = p_user;
  if not found or v.is_banned then
    return jsonb_build_object('ok', false, 'reason', 'no_account');
  end if;
  if v.phone = p_phone and v.phone_verified_at is not null then
    return jsonb_build_object('ok', false, 'reason', 'same');
  end if;
  if v.phone_changed_at is not null and v.phone_changed_at + interval '30 days' > now() then
    return jsonb_build_object('ok', false, 'reason', 'cooldown',
                              'available_at', v.phone_changed_at + interval '30 days');
  end if;
  if public.ex_account_phone_taken(p_phone, p_user) then
    return jsonb_build_object('ok', false, 'reason', 'taken');
  end if;
  return jsonb_build_object('ok', true);
end;
$function$;

-- Save the verified number (called by /api/auth after the code was right).
create or replace function public.ex_account_phone_set(p_user uuid, p_phone text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare v_status jsonb; v_now timestamptz := now();
begin
  v_status := public.ex_account_phone_status(p_user, p_phone);
  if not coalesce((v_status ->> 'ok')::boolean, false) then
    raise exception using errcode = 'P0001',
      message = 'PHONE_' || upper(coalesce(v_status ->> 'reason', 'invalid')),
      detail  = coalesce(v_status ->> 'available_at', '');
  end if;

  update public.ex_profiles
     set phone = p_phone, phone_verified_at = v_now, phone_changed_at = v_now
   where id = p_user;

  -- WhatsApp follows the account number
  update public.ex_whatsapp_settings
     set phone = '+964' || substr(p_phone, 2), updated_at = v_now
   where user_id = p_user;
  insert into public.ex_whatsapp_consent_log (user_id, enabled, phone)
  select user_id, enabled, phone from public.ex_whatsapp_settings where user_id = p_user;

  return jsonb_build_object('ok', true, 'phone', p_phone, 'changed_at', v_now,
                            'available_at', v_now + interval '30 days');
exception when unique_violation then
  raise exception using errcode = 'P0001', message = 'PHONE_TAKEN';
end;
$function$;

revoke all on function public.ex_account_phone_taken(text, uuid)  from public, anon, authenticated;
revoke all on function public.ex_account_phone_status(uuid, text) from public, anon, authenticated;
revoke all on function public.ex_account_phone_set(uuid, text)    from public, anon, authenticated;
grant execute on function public.ex_account_phone_taken(text, uuid)  to service_role;
grant execute on function public.ex_account_phone_status(uuid, text) to service_role;
grant execute on function public.ex_account_phone_set(uuid, text)    to service_role;

-- 7. WhatsApp: only the account's verified number -----------------------------
create or replace function public.ex_my_whatsapp_settings()
 returns jsonb
 language sql
 stable
 security definer
 set search_path to ''
as $function$
  select jsonb_build_object(
    'enabled',   coalesce(s.enabled, false) and p.phone_verified_at is not null,
    'phone',     case when p.phone_verified_at is not null then public.ex_wa_normalize_phone(p.phone) end,
    'verified',  p.phone_verified_at is not null,
    'suggested_phone', null,
    'updated_at', s.updated_at)
  from (select (select auth.uid()) as uid) u
  left join public.ex_whatsapp_settings s on s.user_id = u.uid
  left join public.ex_profiles p on p.id = u.uid
  where u.uid is not null;
$function$;

-- p_phone is ignored (kept so older pages do not break): the number is the account's.
create or replace function public.ex_set_whatsapp_settings(p_enabled boolean, p_phone text default null)
 returns jsonb
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare
  v_uid uuid := auth.uid();
  v_phone text;
  v_cur public.ex_whatsapp_settings;
begin
  if v_uid is null then raise exception 'not_authenticated' using errcode = '28000'; end if;
  select public.ex_wa_normalize_phone(p.phone) into v_phone
    from public.ex_profiles p where p.id = v_uid and p.phone_verified_at is not null;
  if coalesce(p_enabled, false) and v_phone is null then
    raise exception 'phone_not_verified' using errcode = '22023';
  end if;
  select * into v_cur from public.ex_whatsapp_settings where user_id = v_uid;
  insert into public.ex_whatsapp_settings as s (user_id, phone, enabled, updated_at)
  values (v_uid, v_phone, coalesce(p_enabled, false), now())
  on conflict (user_id) do update set phone = excluded.phone, enabled = excluded.enabled, updated_at = now();
  if v_cur.user_id is null or v_cur.enabled is distinct from coalesce(p_enabled, false) or v_cur.phone is distinct from v_phone then
    insert into public.ex_whatsapp_consent_log (user_id, enabled, phone) values (v_uid, coalesce(p_enabled, false), v_phone);
  end if;
  return public.ex_my_whatsapp_settings();
end $function$;

create or replace function public.ex_wa_queue_order_approved()
 returns trigger
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare
  v_tpl public.ex_whatsapp_templates;
  v_kind text;
  v_name text;
  v_code text;
  v_body jsonb;
  v_phone text;
begin
  if old.status is distinct from new.status and new.user_id is not null and new.secure_token is not null then
    v_kind := case new.status when 'پەسەندکرا' then 'order_approved' when 'ڕەتکرا' then 'order_rejected' else null end;
    if v_kind is not null then
      begin
        select * into v_tpl from public.ex_whatsapp_templates where kind = v_kind and active;
        if found and exists (select 1 from public.ex_whatsapp_settings where user_id = new.user_id and enabled) then
          -- only the account's own verified number (unique per account)
          select public.ex_wa_normalize_phone(p.phone),
                 nullif(btrim(coalesce(p.full_name, p.username, '')), '')
            into v_phone, v_name
            from public.ex_profiles p
           where p.id = new.user_id and p.phone_verified_at is not null and not p.is_banned;
          if v_phone is not null then
            v_name := coalesce(v_name, 'عميلنا العزيز');
            v_code := coalesce(new.order_code, new.order_number::text);
            if v_kind = 'order_rejected' then
              -- one line, no line breaks (WhatsApp variables may not contain new lines)
              v_body := jsonb_build_array(v_name, v_code,
                left(coalesce(nullif(btrim(regexp_replace(coalesce(new.admin_note, ''), '\s+', ' ', 'g')), ''), 'يرجى مراجعة تفاصيل الطلب في التطبيق'), 500));
            else
              v_body := jsonb_build_array(v_name, v_code);
            end if;
            insert into public.ex_whatsapp_messages (kind, order_id, user_id, phone, template_id, params)
            values (v_kind, new.id, new.user_id, v_phone, v_tpl.template_id,
              jsonb_build_object('body', v_body, 'button', jsonb_build_array(new.secure_token::text),
                                 'customer_name', v_name, 'order_code', v_code, 'summary_token', new.secure_token::text))
            on conflict (order_id, kind) where order_id is not null do nothing;
          end if;
        end if;
      exception when others then
        raise warning 'ex_wa_queue_order_approved skipped for order %: %', new.id, sqlerrm;
      end;
    end if;
  end if;
  return null;
end $function$;

-- where the account number is verified, the saved WhatsApp number follows it.
-- Unverified accounts keep their row and opt-in untouched; sending (above) uses
-- the profile's verified number only, so nothing goes out until they verify.
update public.ex_whatsapp_settings s
   set phone = public.ex_wa_normalize_phone(p.phone), updated_at = now()
  from public.ex_profiles p
 where p.id = s.user_id and p.phone_verified_at is not null
   and s.phone is distinct from public.ex_wa_normalize_phone(p.phone);

-- 8. deleted accounts release their number ------------------------------------
create or replace function public.ex_account_release_phone()
 returns trigger
 language plpgsql
 set search_path to ''
as $function$
begin
  if new.phone is null then
    new.phone_verified_at := null;
  end if;
  return new;
end $function$;
drop trigger if exists trg_ex_profiles_release_phone on public.ex_profiles;
create trigger trg_ex_profiles_release_phone
  before update of phone on public.ex_profiles
  for each row execute function public.ex_account_release_phone();
