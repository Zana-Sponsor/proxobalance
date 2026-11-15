-- ═════════════════════════════════════════════════════════════════
-- E-mail next to the mobile number (v43)
--
--  • Every account can keep a verified mobile number AND a verified Gmail
--    address, and sign in with either (a lost SIM no longer locks anyone out).
--  • A verified address belongs to one account only (unique index).
--  • The browser can no longer write the e-mail; the server writes it after a
--    code sent to the new address, or an admin changes it from the panel.
--  • ex_auth_resolve: number or e-mail → the account, for sign-in and reset.
--  • E-mail password reset works for every account (one-time grant table).
--
-- Nothing is deleted. Existing e-mail accounts are marked verified: their
-- address is their Supabase sign-in, which was confirmed at sign-up.
-- ═════════════════════════════════════════════════════════════════

alter table public.ex_profiles add column if not exists email_verified_at timestamptz;
comment on column public.ex_profiles.email_verified_at is 'Set when the address was proven with a code (sign-up or the e-mail screen) or set by an admin. Sign-in by e-mail uses only a verified address.';

update public.ex_profiles p
   set email_verified_at = coalesce(u.email_confirmed_at, p.created_at, now())
  from auth.users u
 where u.id = p.id and p.email is not null and lower(p.email) = lower(u.email)
   and p.email_verified_at is null;

create unique index if not exists ex_profiles_verified_email_uniq
  on public.ex_profiles (lower(email)) where email_verified_at is not null;

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
  new.email_verified_at := null;
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

  -- the mobile number, the e-mail and their stamps change only on the server, after a
  -- code sent to the new number / address (/api/auth), or by an admin through /api/admin.
  if not v_backend then
    new.phone             := old.phone;
    new.phone_verified_at := old.phone_verified_at;
    new.phone_changed_at  := old.phone_changed_at;
    new.name_changed_at   := old.name_changed_at;
    -- the e-mail too: only the server, after a code sent to the new address
    new.email             := old.email;
    new.email_verified_at := old.email_verified_at;
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

-- deleted accounts release their number and address
create or replace function public.ex_account_release_phone()
 returns trigger
 language plpgsql
 set search_path to ''
as $function$
begin
  if new.phone is null then new.phone_verified_at := null; end if;
  if new.email is null then new.email_verified_at := null; end if;
  return new;
end $function$;
drop trigger if exists trg_ex_profiles_release_phone on public.ex_profiles;
create trigger trg_ex_profiles_release_phone
  before update of phone, email on public.ex_profiles
  for each row execute function public.ex_account_release_phone();

-- ── e-mail rules (server only) ──────────────────────────────────
create or replace function public.ex_account_email_taken(p_email text, p_except uuid default null)
 returns boolean
 language sql
 stable
 security definer
 set search_path to ''
as $function$
  select exists (select 1 from public.ex_profiles
                  where lower(email) = lower(p_email) and email_verified_at is not null
                    and id is distinct from p_except)
      or exists (select 1 from auth.users
                  where lower(email) = lower(p_email) and id is distinct from p_except);
$function$;

create or replace function public.ex_account_email_status(p_user uuid, p_email text)
 returns jsonb
 language plpgsql
 stable
 security definer
 set search_path to ''
as $function$
declare v public.ex_profiles; v_email text := lower(btrim(coalesce(p_email, '')));
begin
  if v_email !~ '^[a-z0-9._%+-]+@gmail\.com$' then
    return jsonb_build_object('ok', false, 'reason', 'invalid');
  end if;
  select * into v from public.ex_profiles where id = p_user;
  if not found or v.is_banned then
    return jsonb_build_object('ok', false, 'reason', 'no_account');
  end if;
  if lower(v.email) = v_email and v.email_verified_at is not null then
    return jsonb_build_object('ok', false, 'reason', 'same');
  end if;
  if public.ex_account_email_taken(v_email, p_user) then
    return jsonb_build_object('ok', false, 'reason', 'taken');
  end if;
  return jsonb_build_object('ok', true);
end;
$function$;

create or replace function public.ex_account_email_set(p_user uuid, p_email text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare v_status jsonb; v_email text := lower(btrim(coalesce(p_email, ''))); v_now timestamptz := now();
begin
  v_status := public.ex_account_email_status(p_user, v_email);
  if not coalesce((v_status ->> 'ok')::boolean, false) then
    raise exception using errcode = 'P0001', message = 'EMAIL_' || upper(coalesce(v_status ->> 'reason', 'invalid'));
  end if;
  update public.ex_profiles set email = v_email, email_verified_at = v_now where id = p_user;
  return jsonb_build_object('ok', true, 'email', v_email, 'changed_at', v_now);
exception when unique_violation then
  raise exception using errcode = 'P0001', message = 'EMAIL_TAKEN';
end;
$function$;

-- ── sign-in / reset: number or e-mail → account ─────────────────
-- p_identifier is '+9647XXXXXXXXX' or a lower-case address.
-- own_password: number accounts keep their password hash in ex_auth_passwords;
-- e-mail accounts keep it in Supabase Auth.
create or replace function public.ex_auth_resolve(p_identifier text)
 returns jsonb
 language plpgsql
 stable
 security definer
 set search_path to ''
as $function$
declare v_user uuid; v_id text := lower(btrim(coalesce(p_identifier, ''))); v_auth text;
begin
  if v_id ~ '^\+9647[3-9][0-9]{8}$' then
    select p.id into v_user from public.ex_profiles p
     where p.phone = '0' || substr(v_id, 5) and p.phone_verified_at is not null;
    if v_user is null then
      select u.id into v_user from auth.users u where u.email = 'p' || substr(v_id, 2) || '@phone.proxobalance.app';
    end if;
  elsif v_id ~ '^[^@[:space:]]+@[^@[:space:]]+$' then
    select u.id into v_user from auth.users u
     where lower(u.email) = v_id and u.email not like '%@phone.proxobalance.app';
    if v_user is null then
      select p.id into v_user from public.ex_profiles p
       where lower(p.email) = v_id and p.email_verified_at is not null;
    end if;
  end if;
  if v_user is null then return null; end if;
  select email into v_auth from auth.users where id = v_user;
  if v_auth is null or v_auth like 'deleted-%@deleted.invalid' then return null; end if;
  return jsonb_build_object('user_id', v_user, 'auth_email', v_auth,
    'own_password', exists (select 1 from public.ex_auth_passwords where user_id = v_user));
end;
$function$;

-- one-time grant between "code is right" and "new password" for e-mail resets
create table if not exists public.ex_auth_email_grants (
  id          uuid primary key default gen_random_uuid(),
  email       text not null,
  grant_hash  text not null,
  expires_at  timestamptz not null,
  used_at     timestamptz,
  created_at  timestamptz not null default now()
);
create index if not exists ex_auth_email_grants_email_idx on public.ex_auth_email_grants (email, created_at desc);
alter table public.ex_auth_email_grants enable row level security;
revoke all on public.ex_auth_email_grants from public, anon, authenticated;

create or replace function public.ex_auth_email_grant_issue(p_email text)
 returns text
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare v_grant text := encode(extensions.gen_random_bytes(24), 'hex'); v_email text := lower(btrim(coalesce(p_email, '')));
begin
  delete from public.ex_auth_email_grants where created_at < now() - interval '1 day';
  update public.ex_auth_email_grants set used_at = now() where email = v_email and used_at is null;
  insert into public.ex_auth_email_grants (email, grant_hash, expires_at)
  values (v_email, encode(extensions.digest(v_grant, 'sha256'), 'hex'), now() + interval '10 minutes');
  return v_grant;
end;
$function$;

create or replace function public.ex_auth_email_grant_use(p_email text, p_grant text)
 returns boolean
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare v_id uuid;
begin
  update public.ex_auth_email_grants
     set used_at = now()
   where id = (select id from public.ex_auth_email_grants
                where email = lower(btrim(coalesce(p_email, ''))) and used_at is null and expires_at > now()
                  and grant_hash = encode(extensions.digest(coalesce(p_grant, ''), 'sha256'), 'hex')
                order by created_at desc limit 1)
  returning id into v_id;
  return v_id is not null;
end;
$function$;

-- ── admin: change a customer's e-mail and/or number ─────────────
-- Called by /api/admin (service role) after its own admin check. Empty = unchanged.
-- An admin change counts as verified and does not start the customer's 30 days.
create or replace function public.ex_account_contact_check(p_user uuid, p_email text, p_phone text)
 returns jsonb
 language plpgsql
 stable
 security definer
 set search_path to ''
as $function$
declare v public.ex_profiles; v_email text := nullif(lower(btrim(coalesce(p_email, ''))), ''); v_phone text := nullif(btrim(coalesce(p_phone, '')), '');
begin
  select * into v from public.ex_profiles where id = p_user;
  if not found then return jsonb_build_object('ok', false, 'reason', 'no_account'); end if;
  if v_email is null and v_phone is null then return jsonb_build_object('ok', false, 'reason', 'nothing'); end if;
  if v_email is not null then
    if v_email !~ '^[a-z0-9._%+-]+@gmail\.com$' then return jsonb_build_object('ok', false, 'reason', 'email_invalid'); end if;
    if public.ex_account_email_taken(v_email, p_user) then return jsonb_build_object('ok', false, 'reason', 'email_taken'); end if;
  end if;
  if v_phone is not null then
    if v_phone !~ '^07[3-9][0-9]{8}$' then return jsonb_build_object('ok', false, 'reason', 'phone_invalid'); end if;
    if public.ex_account_phone_taken(v_phone, p_user) then return jsonb_build_object('ok', false, 'reason', 'phone_taken'); end if;
  end if;
  return jsonb_build_object('ok', true, 'old_email', v.email, 'old_phone', v.phone);
end;
$function$;

create or replace function public.ex_account_contact_admin_set(p_user uuid, p_email text, p_phone text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare v_check jsonb; v_email text := nullif(lower(btrim(coalesce(p_email, ''))), ''); v_phone text := nullif(btrim(coalesce(p_phone, '')), ''); v_now timestamptz := now();
begin
  v_check := public.ex_account_contact_check(p_user, v_email, v_phone);
  if not coalesce((v_check ->> 'ok')::boolean, false) then
    raise exception using errcode = 'P0001', message = 'CONTACT_' || upper(coalesce(v_check ->> 'reason', 'invalid'));
  end if;
  if v_email is not null then
    update public.ex_profiles set email = v_email, email_verified_at = v_now where id = p_user;
  end if;
  if v_phone is not null then
    update public.ex_profiles set phone = v_phone, phone_verified_at = v_now where id = p_user;
    update public.ex_whatsapp_settings set phone = '+964' || substr(v_phone, 2), updated_at = v_now where user_id = p_user;
    insert into public.ex_whatsapp_consent_log (user_id, enabled, phone)
    select user_id, enabled, phone from public.ex_whatsapp_settings where user_id = p_user;
  end if;
  return v_check || jsonb_build_object('email', coalesce(v_email, v_check ->> 'old_email'), 'phone', coalesce(v_phone, v_check ->> 'old_phone'));
exception when unique_violation then
  raise exception using errcode = 'P0001', message = 'CONTACT_TAKEN';
end;
$function$;

do $$
declare f text;
begin
  foreach f in array array[
    'public.ex_account_email_taken(text, uuid)', 'public.ex_account_email_status(uuid, text)',
    'public.ex_account_email_set(uuid, text)', 'public.ex_auth_resolve(text)',
    'public.ex_auth_email_grant_issue(text)', 'public.ex_auth_email_grant_use(text, text)',
    'public.ex_account_contact_check(uuid, text, text)', 'public.ex_account_contact_admin_set(uuid, text, text)'
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;
