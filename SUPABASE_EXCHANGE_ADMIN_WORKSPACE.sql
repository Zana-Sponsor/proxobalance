-- Super-admin security boundaries and personal monthly Exchange activity.
begin;
CREATE OR REPLACE FUNCTION public.ex_admin_allow_ip(p_ip text, p_note text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$;
declare
  v_id uuid;
  v_ip cidr;
begin
  if not public.ex_is_super_admin() then raise exception 'not authorized'; end if;
  v_ip := p_ip::cidr;

  insert into public.ex_ip_allowlist (ip_address, note, added_by)
  values (v_ip, p_note, auth.uid())
  on conflict (ip_address) do update
    set note = coalesce(excluded.note, public.ex_ip_allowlist.note)
  returning id into v_id;

  -- clear any active ban covering this address
  update public.banned_ips
     set is_active = false, unbanned_at = now(), unbanned_by = auth.uid()
   where is_active and ip_address <<= v_ip;

  return v_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.ex_admin_remove_allow_ip(p_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$;
begin
  if not public.ex_is_super_admin() then raise exception 'not authorized'; end if;
  delete from public.ex_ip_allowlist where id = p_id;
  return found;
end;
$function$;

CREATE OR REPLACE FUNCTION public.ex_admin_ip_stats()
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$;
begin
  if not public.ex_is_super_admin() then raise exception 'not authorized'; end if;
  return json_build_object(
    'active_bans',   (select count(*) from public.banned_ips where is_active and (expires_at is null or expires_at > now())),
    'total_bans',    (select count(*) from public.banned_ips),
    'events_24h',    (select count(*) from public.suspicious_events where created_at > now() - interval '24 hours'),
    'blocked_hits',  (select coalesce(sum(hit_count),0) from public.banned_ips),
    'top_type',      (select event_type from public.suspicious_events
                      where created_at > now() - interval '7 days'
                      group by event_type order by count(*) desc limit 1)
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.ex_admin_list_bans(p_active_only boolean DEFAULT false, p_limit integer DEFAULT 200)
 RETURNS TABLE(id uuid, ip_address text, user_id uuid, account_name text, account_email text, browser_agent text, browser text, os text, device text, reason text, risk_score integer, banned_at timestamp with time zone, expires_at timestamp with time zone, is_active boolean, effective_active boolean, auto_banned boolean, hit_count integer, last_hit_at timestamp with time zone, event_count bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$;
begin
  if not public.ex_is_super_admin() then raise exception 'not authorized'; end if;
  return query
    select b.id, host(b.ip_address), b.user_id, p.full_name, p.email,
           b.browser_agent, b.browser, b.os, b.device,
           b.reason, b.risk_score, b.banned_at, b.expires_at,
           b.is_active,
           (b.is_active and (b.expires_at is null or b.expires_at > now())) as effective_active,
           b.auto_banned, b.hit_count, b.last_hit_at,
           (select count(*) from public.suspicious_events e where e.ip_address = b.ip_address)
    from public.banned_ips b
    left join public.ex_profiles p on p.id = b.user_id
    where (not p_active_only) or (b.is_active and (b.expires_at is null or b.expires_at > now()))
    order by b.banned_at desc
    limit least(greatest(p_limit,1), 500);
end;
$function$;

CREATE OR REPLACE FUNCTION public.ex_admin_list_events(p_limit integer DEFAULT 200, p_ip text DEFAULT NULL::text, p_user_id uuid DEFAULT NULL::uuid, p_type text DEFAULT NULL::text)
 RETURNS TABLE(id uuid, ip_address text, user_id uuid, account_name text, account_email text, browser_agent text, browser text, os text, device text, event_type text, detail text, risk_score integer, path text, created_at timestamp with time zone, ip_is_banned boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$;
begin
  if not public.ex_is_super_admin() then raise exception 'not authorized'; end if;
  return query
    select e.id, host(e.ip_address), e.user_id, e.account_name, e.account_email,
           e.browser_agent, e.browser, e.os, e.device,
           e.event_type, e.detail, e.risk_score, e.path, e.created_at,
           exists(select 1 from public.banned_ips b
                  where b.is_active and (b.expires_at is null or b.expires_at > now())
                    and e.ip_address <<= b.ip_address)
    from public.suspicious_events e
    where (p_ip is null      or host(e.ip_address) = p_ip)
      and (p_user_id is null or e.user_id = p_user_id)
      and (p_type is null    or e.event_type = p_type)
    order by e.created_at desc
    limit least(greatest(p_limit,1), 500);
end;
$function$;

CREATE OR REPLACE FUNCTION public.ex_admin_ip_accounts(p_ip text)
 RETURNS TABLE(user_id uuid, account_name text, account_email text, events bigint, last_seen timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$;
begin
  if not public.ex_is_super_admin() then raise exception 'not authorized'; end if;
  return query
    select e.user_id, max(e.account_name), max(e.account_email), count(*), max(e.created_at)
    from public.suspicious_events e
    where host(e.ip_address) = p_ip and e.user_id is not null
    group by e.user_id
    order by max(e.created_at) desc;
end;
$function$;

CREATE OR REPLACE FUNCTION public.ex_admin_unban_ip(p_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$;
begin
  if not public.ex_is_super_admin() then raise exception 'not authorized'; end if;
  update public.banned_ips
     set is_active = false, unbanned_at = now(), unbanned_by = auth.uid()
   where id = p_id;
  return found;
end;
$function$;

CREATE OR REPLACE FUNCTION public.ex_admin_pending_alerts(p_limit integer DEFAULT 20)
 RETURNS TABLE(id uuid, created_at timestamp with time zone, event_type text, detail text, risk_score integer, ip_address text, user_id uuid, account_name text, account_email text, browser text, os text, device text, browser_agent text, meta jsonb, ip_is_banned boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$;
begin
  if not public.ex_is_super_admin() then raise exception 'not authorized'; end if;
  return query
    select e.id, e.created_at, e.event_type, e.detail, e.risk_score,
           host(e.ip_address), e.user_id, e.account_name, e.account_email,
           e.browser, e.os, e.device, e.browser_agent, e.meta,
           coalesce((select true from public.banned_ips b
                     where b.is_active and (b.expires_at is null or b.expires_at > now())
                       and e.ip_address <<= b.ip_address limit 1), false)
    from public.suspicious_events e
    where e.alert_status = 'pending'
    order by e.risk_score desc, e.created_at desc
    limit least(greatest(p_limit,1), 100);
end;
$function$;

CREATE OR REPLACE FUNCTION public.ex_admin_user_ips(p_user_id uuid, p_limit integer DEFAULT 10)
 RETURNS TABLE(ip_address text, first_seen timestamp with time zone, last_seen timestamp with time zone, events bigint, browser text, os text, device text, is_banned boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$;
begin
  if not public.ex_is_super_admin() then raise exception 'not authorized'; end if;
  return query
    select host(e.ip_address), min(e.created_at), max(e.created_at), count(*),
           (array_agg(e.browser order by e.created_at desc))[1],
           (array_agg(e.os      order by e.created_at desc))[1],
           (array_agg(e.device  order by e.created_at desc))[1],
           coalesce((select true from public.banned_ips b
                     where b.is_active and (b.expires_at is null or b.expires_at > now())
                       and e.ip_address <<= b.ip_address limit 1), false)
    from public.suspicious_events e
    where e.user_id = p_user_id and e.ip_address is not null
    group by e.ip_address
    order by max(e.created_at) desc
    limit least(greatest(p_limit,1), 50);
end;
$function$;

CREATE OR REPLACE FUNCTION public.ex_admin_accounts_ip_summary()
 RETURNS TABLE(user_id uuid, last_ip text, ip_count bigint, last_seen timestamp with time zone, browser text, os text, device text, last_ip_banned boolean, flagged_events bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$;
begin
  if not public.ex_is_super_admin() then raise exception 'not authorized'; end if;
  return query
    with ranked as (
      select e.*, row_number() over (partition by e.user_id order by e.created_at desc) as rn
      from public.suspicious_events e
      where e.user_id is not null and e.ip_address is not null
    )
    select r.user_id,
           host(r.ip_address),
           (select count(distinct x.ip_address) from public.suspicious_events x where x.user_id = r.user_id),
           r.created_at,
           r.browser, r.os, r.device,
           coalesce((select true from public.banned_ips b
                     where b.is_active and (b.expires_at is null or b.expires_at > now())
                       and r.ip_address <<= b.ip_address limit 1), false),
           (select count(*) from public.suspicious_events y where y.user_id = r.user_id and y.risk_score > 0)
    from ranked r
    where r.rn = 1;
end;
$function$;

CREATE OR REPLACE FUNCTION public.ex_admin_ban_ip(p_ip text, p_reason text, p_hours integer DEFAULT NULL::integer, p_user_id uuid DEFAULT NULL::uuid, p_notes text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$;
declare
  v_id uuid;
  v_ip inet;
  v_ua text; v_br text; v_os text; v_dev text;
begin
  if not public.ex_is_super_admin() then raise exception 'not authorized'; end if;
  v_ip := p_ip::inet;

  if public.ex_is_ip_allowlisted(v_ip) then
    raise exception 'ip is allowlisted';
  end if;

  select browser_agent, browser, os, device into v_ua, v_br, v_os, v_dev
  from public.suspicious_events where ip_address <<= v_ip
  order by created_at desc limit 1;

  insert into public.banned_ips (ip_address, user_id, browser_agent, browser, os, device,
                                 reason, expires_at, banned_by, auto_banned, notes)
  values (v_ip, p_user_id, v_ua, v_br, v_os, v_dev,
          coalesce(p_reason,'دەستی'),
          case when p_hours is null then null else now() + make_interval(hours => p_hours) end,
          auth.uid(), false, p_notes)
  returning id into v_id;

  return v_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.ex_admin_ban_from_alert(p_id uuid, p_hours integer DEFAULT 24)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$;
declare
  v_e public.suspicious_events%rowtype;
  v_ban uuid;
begin
  if not public.ex_is_super_admin() then raise exception 'not authorized'; end if;

  select * into v_e from public.suspicious_events where id = p_id;
  if v_e.id is null or v_e.ip_address is null then
    raise exception 'alert has no IP';
  end if;

  insert into public.banned_ips (ip_address, user_id, browser_agent, browser, os, device,
                                 reason, risk_score, expires_at, banned_by, auto_banned)
  values (v_e.ip_address, v_e.user_id, v_e.browser_agent, v_e.browser, v_e.os, v_e.device,
          format('ئاگاداری: %s — %s', v_e.event_type, coalesce(v_e.detail,'')),
          v_e.risk_score,
          case when p_hours is null then null else now() + make_interval(hours => p_hours) end,
          auth.uid(), false)
  returning id into v_ban;

  update public.suspicious_events
     set alert_status = 'actioned', reviewed_by = auth.uid(), reviewed_at = now()
   where alert_status = 'pending' and ip_address = v_e.ip_address;

  return v_ban;
end;
$function$;

CREATE OR REPLACE FUNCTION public.ex_admin_extend_ban(p_id uuid, p_hours integer)
 RETURNS timestamp with time zone
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$;
declare v_new timestamptz;
begin
  if not public.ex_is_super_admin() then raise exception 'not authorized'; end if;
  update public.banned_ips
     set expires_at = case when p_hours is null then null
                           else greatest(coalesce(expires_at, now()), now()) + make_interval(hours => p_hours) end,
         is_active = true, unbanned_at = null, unbanned_by = null
   where id = p_id
   returning expires_at into v_new;
  return v_new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.ex_admin_resolve_alert(p_id uuid, p_status text DEFAULT 'dismissed'::text, p_all_for_ip boolean DEFAULT false)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$;
declare
  v_ip inet;
  v_n  integer;
begin
  if not public.ex_is_super_admin() then raise exception 'not authorized'; end if;
  if p_status not in ('dismissed','actioned') then
    raise exception 'invalid status';
  end if;

  select ip_address into v_ip from public.suspicious_events where id = p_id;

  if p_all_for_ip and v_ip is not null then
    update public.suspicious_events
       set alert_status = p_status, reviewed_by = auth.uid(), reviewed_at = now()
     where alert_status = 'pending' and ip_address = v_ip;
  else
    update public.suspicious_events
       set alert_status = p_status, reviewed_by = auth.uid(), reviewed_at = now()
     where id = p_id;
  end if;

  get diagnostics v_n = row_count;
  return v_n;
end;
$function$;

CREATE OR REPLACE FUNCTION public.ex_admin_delete_otp(p_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$;
begin
  if not public.ex_is_super_admin() then
    raise exception 'not authorized';
  end if;
  insert into public.ex_admin_audit_log(admin_id, action, target_user_id, detail)
    values (auth.uid(), 'otp_delete', (select user_id from public.ex_otp_codes where id = p_id), 'otp_id='||p_id::text);
  delete from public.ex_otp_codes where id = p_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.ex_admin_expire_otp(p_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$;
begin
  if not public.ex_is_super_admin() then
    raise exception 'not authorized';
  end if;
  update public.ex_otp_codes set expires_at = now(), is_used = true where id = p_id;
  insert into public.ex_admin_audit_log(admin_id, action, target_user_id, detail)
    values (auth.uid(), 'otp_force_expire', (select user_id from public.ex_otp_codes where id = p_id), 'otp_id='||p_id::text);
end;
$function$;

CREATE OR REPLACE FUNCTION public.ex_admin_create_otp(p_email text, p_code text, p_purpose text DEFAULT 'login'::text, p_minutes integer DEFAULT 10)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$;
declare
  v_user uuid;
  v_id uuid;
begin
  if not public.ex_is_super_admin() then
    raise exception 'not authorized';
  end if;
  if p_email is null or btrim(p_email) = '' then
    raise exception 'email required';
  end if;
  if p_code is null or btrim(p_code) = '' then
    raise exception 'code required';
  end if;

  select id into v_user from public.ex_profiles
   where lower(email) = lower(btrim(p_email)) limit 1;

  insert into public.ex_otp_codes(user_id, email, code, purpose, expires_at, is_used)
  values (v_user, lower(btrim(p_email)), btrim(p_code),
          coalesce(nullif(btrim(p_purpose), ''), 'login'),
          now() + make_interval(mins => greatest(coalesce(p_minutes, 10), 1)),
          false)
  returning id into v_id;

  insert into public.ex_admin_audit_log(admin_id, action, target_user_id, detail)
    values (auth.uid(), 'otp_create', v_user, 'otp_id=' || v_id::text);

  return v_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.ex_admin_list_otp(p_limit integer DEFAULT 200)
 RETURNS TABLE(id uuid, user_id uuid, email text, code text, purpose text, created_at timestamp with time zone, expires_at timestamp with time zone, is_used boolean, status text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$;
begin
  if not public.ex_is_super_admin() then
    raise exception 'not authorized';
  end if;
  return query
    select o.id, o.user_id, o.email, o.code, o.purpose, o.created_at, o.expires_at, o.is_used,
      case
        when o.is_used then 'used'
        when o.expires_at < now() then 'expired'
        else 'active'
      end as status
    from public.ex_otp_codes o
    order by o.created_at desc
    limit p_limit;
end;
$function$;

CREATE OR REPLACE FUNCTION public.ex_admin_update_otp(p_id uuid, p_code text DEFAULT NULL::text, p_purpose text DEFAULT NULL::text, p_expires_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_is_used boolean DEFAULT NULL::boolean, p_email text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$;
declare
  v_user uuid;
begin
  if not public.ex_is_super_admin() then
    raise exception 'not authorized';
  end if;
  if p_code is not null and btrim(p_code) = '' then
    raise exception 'code cannot be empty';
  end if;

  select user_id into v_user from public.ex_otp_codes where id = p_id;
  if not found then
    raise exception 'otp not found';
  end if;

  update public.ex_otp_codes
     set code       = coalesce(btrim(p_code), code),
         purpose    = coalesce(nullif(btrim(p_purpose), ''), purpose),
         expires_at = coalesce(p_expires_at, expires_at),
         is_used    = coalesce(p_is_used, is_used),
         email      = coalesce(nullif(btrim(p_email), ''), email)
   where id = p_id;

  insert into public.ex_admin_audit_log(admin_id, action, target_user_id, detail)
    values (auth.uid(), 'otp_update', v_user, 'otp_id=' || p_id::text);
end;
$function$;

CREATE OR REPLACE FUNCTION public.ex_profiles_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$;
declare
  v_available_at timestamptz;
  v_backend      boolean := public.ex_is_backend_request();
  v_uid          uuid    := auth.uid();
  v_super        boolean := public.ex_is_super_admin();
  v_locked_name  text;
begin
  if not v_backend then
    new.username := old.username;
  end if;
  if new.username is null then
    new.username := old.username;
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
  new.phone     := nullif(regexp_replace(coalesce(new.phone, ''), '[^0-9]', '', 'g'), '');

  if new.full_name is distinct from old.full_name
     or new.phone is distinct from old.phone then

    if new.full_name is null or char_length(new.full_name) < 3 then
      raise exception using errcode = 'P0001', message = 'PROFILE_NAME_INVALID';
    end if;

    if new.phone is not null and new.phone !~ '^07[0-9]{9}$' then
      raise exception using errcode = 'P0001', message = 'PROFILE_PHONE_INVALID';
    end if;

    v_available_at := old.identity_updated_at + interval '7 days';
    if old.identity_updated_at is not null and v_available_at > now() then
      raise exception using
        errcode = 'P0001',
        message = 'PROFILE_UPDATE_COOLDOWN',
        detail  = v_available_at::text,
        hint    = 'Name and phone can be changed once every 7 days.';
    end if;

    new.identity_updated_at := now();
  end if;

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.ex_staff_profile_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$;
begin
 if tg_op='INSERT' and not public.ex_is_backend_request() then new.staff_permissions:=null;end if;
 if tg_op='UPDATE' and old.role='user' and new.role='admin' then
  new.staff_permissions:=array['view','approve_orders']::text[];
 end if;
 if tg_op='UPDATE' and new.staff_permissions is distinct from old.staff_permissions then
  if not public.ex_is_backend_request() and not public.ex_is_super_admin() then
   raise exception 'SUPER_ADMIN_REQUIRED' using errcode='42501';end if;
  if old.role='super_admin' or new.role='super_admin' or old.id=auth.uid() then
   raise exception 'STAFF_PERMISSION_TARGET_FORBIDDEN' using errcode='42501';end if;
 end if;
 return new;
end $function$;

drop policy if exists ex_staff_read_audit on public.ex_admin_audit_log;
drop policy if exists ex_admin_audit_log_select on public.ex_admin_audit_log;
create policy ex_admin_audit_log_select on public.ex_admin_audit_log for select to authenticated using ((select public.ex_is_super_admin()));
drop policy if exists suspicious_events_admin_select on public.suspicious_events;
create policy suspicious_events_admin_select on public.suspicious_events for select to authenticated using ((select public.ex_is_super_admin()));
alter table public.ex_orders add column if not exists handled_by uuid references public.ex_profiles(id);
-- Historical attribution only where an exact public code and matching final action exists.
update public.ex_orders o set handled_by=(
 select a.admin_id from public.ex_admin_audit_log a
 where a.detail=o.order_code and a.action=case when o.status='پەسەندکرا' then 'approve_order' else 'reject_order' end
 order by a.created_at desc,a.id desc limit 1)
where o.handled_by is null and o.order_code is not null and o.status in ('پەسەندکرا','ڕەتکرا');
create index if not exists ex_orders_handler_month_idx on public.ex_orders(handled_by,decided_at);
create or replace function public.ex_order_handler_guard() returns trigger
language plpgsql security definer set search_path='' as $fn$
begin
 if not public.ex_is_backend_request() then
  if tg_op='INSERT' then new.handled_by:=null;
  elsif new.status is distinct from old.status and new.status in ('پەسەندکرا','ڕەتکرا')
    and public.ex_staff_has('approve_orders') then new.handled_by:=auth.uid();
  else new.handled_by:=old.handled_by;end if;
 end if;
 return new;
end $fn$;
revoke all on function public.ex_order_handler_guard() from public,anon,authenticated;
drop trigger if exists trg_ex_order_handler on public.ex_orders;
create trigger trg_ex_order_handler before insert or update on public.ex_orders for each row execute function public.ex_order_handler_guard();
create or replace function public.ex_staff_monthly_activity() returns jsonb
language plpgsql stable security definer set search_path='' as $fn$
declare v_start timestamptz; v_end timestamptz; v_result jsonb;
begin
 if not public.ex_staff_has('view') then raise exception 'STAFF_PERMISSION_REQUIRED' using errcode='42501';end if;
 v_start:=date_trunc('month',now() at time zone 'Asia/Baghdad') at time zone 'Asia/Baghdad';
 v_end:=(date_trunc('month',now() at time zone 'Asia/Baghdad')+interval '1 month') at time zone 'Asia/Baghdad';
 select jsonb_build_object('month_start',v_start,'handled_orders',count(*),
 'approved_orders',count(*) filter(where status='پەسەندکرا'),
 'rejected_orders',count(*) filter(where status='ڕەتکرا'),
 'deduction_iqd',coalesce(sum(fee) filter(where status='پەسەندکرا'),0),
 'unrecorded_fees',count(*) filter(where status='پەسەندکرا' and fee is null))
 into v_result from public.ex_orders where handled_by=auth.uid() and decided_at>=v_start and decided_at<v_end;
 return v_result;
end $fn$;
revoke all on function public.ex_staff_monthly_activity() from public,anon;
grant execute on function public.ex_staff_monthly_activity() to authenticated;
commit;

