-- OTP registration hardening (2026-11-18)
-- Preserve the existing n8n delivery contract. Email OTPs are still requested
-- with { action: 'request_otp', email, purpose }; this migration only makes the
-- database-side issue/verify operations race-safe and server-only.

-- Serialize concurrent phone-code issuance by phone and IP before checking
-- active codes and rate counters. The row-locking verifier below remains the
-- single-use gate for every code.
CREATE OR REPLACE FUNCTION public.ex_auth_code_issue(p_phone text, p_purpose text, p_ip text DEFAULT NULL::text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
declare
  v_code text;
  v_id uuid := gen_random_uuid();
  v_until timestamptz;
  v_live timestamptz;
  v_expires timestamptz;
begin
  if p_phone is null or p_phone !~ '^\+9647[3-9][0-9]{8}$' then
    raise exception 'PHONE_INVALID' using errcode = 'P0001';
  end if;
  if p_purpose is null or p_purpose not in ('signup', 'login', 'reset', 'change_phone') then
    raise exception 'PURPOSE_INVALID' using errcode = 'P0001';
  end if;

  -- All phone-code issuance calls acquire locks in this order.
  perform pg_advisory_xact_lock(hashtextextended('ex_auth_code_issue:phone:' || p_phone, 0));
  if p_ip is not null then
    perform pg_advisory_xact_lock(hashtextextended('ex_auth_code_issue:ip:' || p_ip, 0));
  end if;

  v_until := public.ex_auth_lock_until('phone:' || p_phone);
  if v_until is not null then
    raise exception 'LOCKED' using errcode = 'P0001', detail = v_until::text;
  end if;

  select max(expires_at) into v_live
    from public.ex_auth_codes
   where phone = p_phone and purpose = p_purpose and consumed_at is null and expires_at > now();
  if v_live is not null then
    return jsonb_build_object('id', null, 'code', null, 'active', true, 'expires_at', v_live);
  end if;

  if (select count(*) from public.ex_auth_codes
       where phone = p_phone and created_at > now() - interval '10 minutes') >= 3 then
    raise exception 'TOO_MANY_CODES' using errcode = 'P0001';
  end if;
  if p_ip is not null and (select count(*) from public.ex_auth_codes
       where ip = p_ip and created_at > now() - interval '1 hour') >= 10 then
    raise exception 'TOO_MANY_CODES' using errcode = 'P0001';
  end if;

  v_code := lpad(((('x' || encode(extensions.gen_random_bytes(4), 'hex'))::bit(32)::bigint) % 1000000)::text, 6, '0');
  v_expires := now() + interval '5 minutes';
  insert into public.ex_auth_codes (id, phone, purpose, code_hash, ip, expires_at)
  values (v_id, p_phone, p_purpose,
          encode(extensions.digest(v_code || ':' || v_id::text, 'sha256'), 'hex'), p_ip, v_expires);
  return jsonb_build_object('id', v_id, 'code', v_code, 'active', false, 'expires_at', v_expires);
end
$function$;

REVOKE ALL ON FUNCTION public.ex_auth_code_issue(text, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ex_auth_code_issue(text, text, text) TO service_role;

-- Verification consumes the selected row inside this RPC transaction. FOR
-- UPDATE serializes simultaneous requests; only the first successful request
-- can observe an unconsumed row and mark it consumed.
CREATE OR REPLACE FUNCTION public.ex_auth_code_check(p_phone text, p_purpose text, p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
declare
  v public.ex_auth_codes%rowtype;
  v_until timestamptz;
  v_fail jsonb;
  v_grant text;
begin
  if p_phone is null or p_phone !~ '^\+9647[3-9][0-9]{8}$'
     or p_purpose is null or p_purpose not in ('signup', 'login', 'reset', 'change_phone') then
    return jsonb_build_object('ok', false, 'reason', 'expired');
  end if;
  v_until := public.ex_auth_lock_until('phone:' || p_phone);
  if v_until is not null then
    return jsonb_build_object('ok', false, 'reason', 'locked', 'locked_until', v_until);
  end if;

  select * into v
    from public.ex_auth_codes
   where phone = p_phone and purpose = p_purpose
     and consumed_at is null and expires_at > now()
   order by created_at desc
   limit 1
   for update;
  if not found then
    return jsonb_build_object('ok', false, 'reason', 'expired');
  end if;

  if v.code_hash is distinct from encode(
       extensions.digest(btrim(coalesce(p_code, '')) || ':' || v.id::text, 'sha256'), 'hex') then
    update public.ex_auth_codes set attempts = attempts + 1 where id = v.id;
    v_fail := public.ex_auth_fail('phone:' || p_phone);
    if (v_fail ->> 'locked_until') is not null then
      update public.ex_auth_codes set consumed_at = now() where id = v.id;
      return jsonb_build_object('ok', false, 'reason', 'locked', 'locked_until', v_fail ->> 'locked_until');
    end if;
    return jsonb_build_object('ok', false, 'reason', 'wrong',
      'attempts_left', (v_fail ->> 'attempts_left')::int);
  end if;

  if p_purpose = 'reset' then
    v_grant := encode(extensions.gen_random_bytes(24), 'hex');
    update public.ex_auth_codes
       set consumed_at = now(),
           grant_hash = encode(extensions.digest(v_grant, 'sha256'), 'hex'),
           grant_expires_at = now() + interval '10 minutes'
     where id = v.id;
  else
    update public.ex_auth_codes set consumed_at = now() where id = v.id;
  end if;
  perform public.ex_auth_clear('phone:' || p_phone);
  return jsonb_build_object('ok', true, 'grant', v_grant);
end
$function$;

REVOKE ALL ON FUNCTION public.ex_auth_code_check(text, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ex_auth_code_check(text, text, text) TO service_role;

-- Email OTP verification is purpose-mandatory and server-only. The code row is
-- locked then marked used in the same transaction; n8n remains the issuer/sender.
CREATE OR REPLACE FUNCTION public.ex_verify_otp(p_email text, p_code text, p_purpose text DEFAULT NULL::text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
declare
  v_row public.ex_otp_codes%rowtype;
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_fail jsonb;
begin
  if v_email = '' or p_purpose is null
     or p_purpose not in ('signup', 'login', 'reset_password')
     or p_code is null or p_code !~ '^\d{6}$' then
    return false;
  end if;
  if public.ex_auth_lock_until('email:' || v_email) is not null then
    return false;
  end if;

  select * into v_row
    from public.ex_otp_codes
   where email = v_email and purpose = p_purpose
     and is_used = false and expires_at > now()
   order by created_at desc
   limit 1
   for update;
  if not found then
    return false;
  end if;
  if v_row.attempts >= 5 then
    update public.ex_otp_codes set expires_at = now() where id = v_row.id;
    return false;
  end if;

  if v_row.code is distinct from btrim(p_code) then
    update public.ex_otp_codes
       set attempts = attempts + 1,
           expires_at = case when attempts + 1 >= 5 then now() else expires_at end
     where id = v_row.id;
    v_fail := public.ex_auth_fail('email:' || v_email);
    if (v_fail ->> 'locked_until') is not null then
      update public.ex_otp_codes set expires_at = now() where id = v_row.id;
    end if;
    return false;
  end if;

  update public.ex_otp_codes set is_used = true where id = v_row.id;
  perform public.ex_auth_clear('email:' || v_email);
  return true;
end
$function$;

REVOKE ALL ON FUNCTION public.ex_verify_otp(text, text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ex_verify_otp(text, text, text) TO service_role;

-- The n8n insert trigger serializes per email/purpose and retains the one-live
-- code rule. A 3-per-10-minute cap prevents repeated requests after expiry.
CREATE OR REPLACE FUNCTION public.ex_otp_codes_one_live()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
declare
  v_live timestamptz;
begin
  new.email := lower(btrim(coalesce(new.email, '')));
  if new.email = '' or new.purpose is null
     or new.purpose not in ('signup', 'login', 'reset_password') then
    raise exception using errcode = 'P0001', message = 'OTP_PURPOSE_INVALID';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('ex_otp_codes:' || new.email || ':' || new.purpose, 0));

  if (select count(*) from public.ex_otp_codes
       where email = new.email and purpose = new.purpose
         and created_at > now() - interval '10 minutes') >= 3 then
    raise exception using errcode = 'P0001', message = 'TOO_MANY_CODES';
  end if;

  select max(expires_at) into v_live
    from public.ex_otp_codes
   where email = new.email and purpose = new.purpose
     and is_used = false and expires_at > now();
  if v_live is not null then
    raise exception using errcode = 'P0001', message = 'CODE_STILL_VALID', detail = v_live::text;
  end if;
  return new;
end
$function$;

DROP TRIGGER IF EXISTS trg_ex_otp_codes_one_live ON public.ex_otp_codes;
CREATE TRIGGER trg_ex_otp_codes_one_live
  BEFORE INSERT ON public.ex_otp_codes
  FOR EACH ROW EXECUTE FUNCTION public.ex_otp_codes_one_live();
