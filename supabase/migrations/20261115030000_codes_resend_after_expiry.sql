-- ═════════════════════════════════════════════════════════════════
-- One live code at a time (v44)
--
-- A new verification code is only made once the previous one has
-- expired (or was used up). While it is still valid, asking again
-- returns the old code's expiry instead of a new code.
--
--  • WhatsApp codes (ex_auth_codes, 5 minutes): ex_auth_code_issue.
--  • E-mail codes (ex_otp_codes, 10 minutes, written by the n8n
--    "Email Exchange" workflow before it sends the e-mail): a trigger
--    refuses a second live code, so n8n does not send another e-mail.
-- ═════════════════════════════════════════════════════════════════

create or replace function public.ex_auth_code_issue(p_phone text, p_purpose text, p_ip text default null)
 returns jsonb
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare v_code text; v_id uuid := gen_random_uuid(); v_until timestamptz; v_live timestamptz;
begin
  if p_phone is null or p_phone !~ '^\+9647[3-9][0-9]{8}$' then raise exception 'PHONE_INVALID' using errcode = 'P0001'; end if;
  v_until := public.ex_auth_lock_until('phone:' || p_phone);
  if v_until is not null then raise exception 'LOCKED' using errcode = 'P0001', detail = v_until::text; end if;
  -- the previous code is still valid: no new code until it expires
  select max(expires_at) into v_live from public.ex_auth_codes
   where phone = p_phone and purpose = p_purpose and consumed_at is null and expires_at > now();
  if v_live is not null then
    return jsonb_build_object('id', null, 'code', null, 'active', true, 'expires_at', v_live);
  end if;
  if (select count(*) from public.ex_auth_codes where phone = p_phone and created_at > now() - interval '10 minutes') >= 3 then
    raise exception 'TOO_MANY_CODES' using errcode = 'P0001';
  end if;
  if p_ip is not null and (select count(*) from public.ex_auth_codes where ip = p_ip and created_at > now() - interval '1 hour') >= 10 then
    raise exception 'TOO_MANY_CODES' using errcode = 'P0001';
  end if;
  v_code := lpad(((('x' || encode(extensions.gen_random_bytes(4), 'hex'))::bit(32)::bigint) % 1000000)::text, 6, '0');
  insert into public.ex_auth_codes (id, phone, purpose, code_hash, ip, expires_at)
  values (v_id, p_phone, p_purpose, encode(extensions.digest(v_code || ':' || v_id::text, 'sha256'), 'hex'), p_ip, now() + interval '5 minutes');
  return jsonb_build_object('id', v_id, 'code', v_code, 'active', false, 'expires_at', now() + interval '5 minutes');
end $function$;

-- When the live e-mail code for this address and purpose expires (null = none).
create or replace function public.ex_auth_email_code_expiry(p_email text, p_purpose text)
 returns timestamptz
 language sql
 stable
 security definer
 set search_path to ''
as $function$
  select max(expires_at) from public.ex_otp_codes
   where email = lower(btrim(coalesce(p_email, ''))) and purpose = p_purpose
     and is_used = false and expires_at > now();
$function$;
revoke all on function public.ex_auth_email_code_expiry(text, text) from public, anon, authenticated;
grant execute on function public.ex_auth_email_code_expiry(text, text) to service_role;

-- E-mail codes: one live code per address and purpose; stored in lower case so
-- ex_verify_otp (which compares lower-case) always finds it.
create or replace function public.ex_otp_codes_one_live()
 returns trigger
 language plpgsql
 set search_path to ''
as $function$
declare v_live timestamptz;
begin
  new.email := lower(btrim(coalesce(new.email, '')));
  select max(expires_at) into v_live from public.ex_otp_codes
   where email = new.email and purpose = new.purpose and is_used = false and expires_at > now();
  if v_live is not null then
    raise exception using errcode = 'P0001', message = 'CODE_STILL_VALID', detail = v_live::text;
  end if;
  return new;
end $function$;
drop trigger if exists trg_ex_otp_codes_one_live on public.ex_otp_codes;
create trigger trg_ex_otp_codes_one_live
  before insert on public.ex_otp_codes
  for each row execute function public.ex_otp_codes_one_live();
