-- Auth owns event times and session identity. The app supplies descriptive
-- device metadata only; no OTP, password, access token or refresh token is logged.
create schema if not exists app_auth_audit;
revoke all on schema app_auth_audit from public, anon;
grant usage on schema app_auth_audit to authenticated;

alter table public.profiles add column if not exists last_login_at timestamptz;
alter table public.profiles add column if not exists last_logout_at timestamptz;
alter table public.pa_activity_log add column if not exists session_id text;
create unique index if not exists pa_activity_log_session_event_uidx
  on public.pa_activity_log(user_id, session_id, action) where session_id is not null;
create unique index if not exists pa_login_history_session_uidx
  on public.pa_login_history(user_id, session_id) where session_id is not null;

-- Backfill only the authoritative Auth timestamp; do not invent old logouts
-- or attempt to infer a phone model from an IP address/user agent.
update public.profiles p set last_login_at = u.last_sign_in_at
from auth.users u where u.id=p.id and u.last_sign_in_at is not null
  and (p.last_login_at is null or p.last_login_at<u.last_sign_in_at);

create or replace function app_auth_audit.protect_server_fields()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
  if current_user in ('anon','authenticated') then
    if tg_table_name='profiles' then
      new.last_login_at:=old.last_login_at;
      new.last_logout_at:=old.last_logout_at;
    elsif new.session_id is not null then
      raise exception 'Use pa_record_app_session for session-linked history' using errcode='42501';
    end if;
  end if;
  return new;
end $$;
revoke all on function app_auth_audit.protect_server_fields() from public,anon,authenticated;
drop trigger if exists pa_protect_auth_activity_times on public.profiles;
create trigger pa_protect_auth_activity_times before update on public.profiles
for each row execute function app_auth_audit.protect_server_fields();
drop trigger if exists pa_protect_session_history_identity on public.pa_login_history;
create trigger pa_protect_session_history_identity before insert on public.pa_login_history
for each row execute function app_auth_audit.protect_server_fields();

-- Auth event logging runs in Auth's own transaction. A failed sign-out never
-- fabricates a logout; global/local revocations follow the actual deleted rows.
create or replace function app_auth_audit.session_event()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_time timestamptz;
begin
  if tg_op='INSERT' then
    v_time:=coalesce(new.created_at,now());
    insert into public.pa_activity_log(user_id,action,description,session_id,created_at)
      values(new.user_id,'login','چوونەژوورەوە بۆ هەژمار',new.id::text,v_time)
      on conflict (user_id,session_id,action) where session_id is not null do nothing;
    update public.profiles set last_login_at=greatest(last_login_at,v_time)
      where id=new.user_id;
    return new;
  end if;
  -- Account deletion retains the existing cascade/erasure behavior.
  if not exists(select 1 from auth.users where id=old.user_id) then return old; end if;
  v_time:=greatest(old.created_at,least(now(),coalesce(old.not_after,now())));
  update public.pa_login_history set logout_time=v_time,
    session_duration=greatest(0,extract(epoch from (v_time-coalesce(login_time,created_at)))::integer)
    where user_id=old.user_id and session_id=old.id::text and logout_time is null;
  insert into public.pa_activity_log(user_id,action,description,session_id,created_at)
    values(old.user_id,'logout','چوونەدەرەوە یان کۆتایی سێشن',old.id::text,v_time)
    on conflict (user_id,session_id,action) where session_id is not null do nothing;
  update public.profiles set last_logout_at=greatest(last_logout_at,v_time)
    where id=old.user_id;
  return old;
end $$;
revoke all on function app_auth_audit.session_event() from public,anon,authenticated;
drop trigger if exists pa_auth_session_activity on auth.sessions;
create trigger pa_auth_session_activity after insert or delete on auth.sessions
for each row execute function app_auth_audit.session_event();

create or replace function app_auth_audit.record_app_session(p_session_id uuid,p_device jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid(); v_session record; v_id uuid;
begin
  if v_uid is null or p_session_id is null or
      coalesce(auth.jwt()->>'session_id','')<>p_session_id::text then
    raise exception 'An authenticated matching session is required' using errcode='42501';
  end if;
  if jsonb_typeof(p_device) is distinct from 'object' or octet_length(p_device::text)>4096 then
    raise exception 'Invalid device metadata' using errcode='22023';
  end if;
  -- Lock against concurrent revocation: logout must close a newly inserted
  -- history row, rather than racing it and leaving a stale open record.
  select s.id,s.created_at,s.ip,s.user_agent into v_session from auth.sessions s
    where s.id=p_session_id and s.user_id=v_uid
      and (s.not_after is null or s.not_after>now()) for key share;
  if not found then raise exception 'Session is no longer active' using errcode='42501'; end if;

  insert into public.pa_login_history(user_id,session_id,success,login_status,
    created_at,login_time,last_seen_at,device_info,device_name,device_model,os,os_version,platform,
    ip_address,user_agent)
  values(v_uid,p_session_id::text,true,'success',v_session.created_at,v_session.created_at,now(),
    nullif(left(btrim(p_device->>'device_name'),160),''),
    nullif(left(btrim(p_device->>'device_name'),160),''),
    nullif(left(btrim(p_device->>'device_model'),120),''),
    nullif(left(btrim(p_device->>'os'),40),''),
    nullif(left(btrim(p_device->>'os_version'),40),''),
    nullif(left(btrim(p_device->>'platform'),30),''),
    host(v_session.ip),left(v_session.user_agent,512))
  on conflict (user_id,session_id) where session_id is not null do nothing returning id into v_id;
  if v_id is null then
    select id into v_id from public.pa_login_history
      where user_id=v_uid and session_id=p_session_id::text;
  end if;
  -- A pre-migration restored session gets its original start time, never now().
  update public.profiles set last_login_at=greatest(last_login_at,v_session.created_at)
    where id=v_uid;
  return v_id;
end $$;
revoke all on function app_auth_audit.record_app_session(uuid,jsonb) from public,anon;
grant execute on function app_auth_audit.record_app_session(uuid,jsonb) to authenticated;

-- Exposed wrapper keeps caller privileges. The guarded implementation alone
-- can read Auth's private session row and write server-owned audit fields.
create or replace function public.pa_record_app_session(p_session_id uuid,p_device jsonb default '{}'::jsonb)
returns uuid language sql security invoker set search_path='' as $$
  select app_auth_audit.record_app_session(p_session_id,p_device);
$$;
revoke all on function public.pa_record_app_session(uuid,jsonb) from public,anon;
grant execute on function public.pa_record_app_session(uuid,jsonb) to authenticated;

comment on column public.profiles.last_login_at is 'Server Auth sign-in time; refresh and app reopening do not count as a new login.';
comment on column public.pa_login_history.device_model is 'Device-reported hardware model; descriptive only, never an authorization claim.';
comment on column public.pa_activity_log.session_id is 'Auth session UUID only, never an access or refresh token.';
