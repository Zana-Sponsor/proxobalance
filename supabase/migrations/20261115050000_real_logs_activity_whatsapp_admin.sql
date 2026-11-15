-- ═════════════════════════════════════════════════════════════════
-- v51 — real error log, user activity, WhatsApp notifications for admins
--
-- 1. The error log gets real failures, not only browser noise:
--      · WhatsApp order notifications that Wevlix did not deliver become
--        rows (source 'whatsapp'); a later successful send resolves them.
--      · A queue that stops moving (n8n worker down) raises one critical row
--        and resolves it again when the queue moves.
--      · Old browser noise (cross-origin "Script error.", in-app browser
--        bridges) is resolved; network drops on the visitor's side become
--        warnings instead of errors.
--    Code-sending failures (WhatsApp / e-mail) and server errors are written
--    by the API (api-handlers/auth.js, admin.js, notify-order.js).
-- 2. Activity: which screen each signed-in account is on and for how long
--    (only while the page is visible). Kept 90 days.
-- 3. WhatsApp notifications: admins see who turned them on and can turn
--    them off / on again (only with a verified number); every change is
--    logged with who made it.
-- All admin reads/writes are service_role only and go through /api/admin
-- (super admin). The only browser-callable function is ex_activity_ping.
-- ═════════════════════════════════════════════════════════════════

-- ── 1. error log ──────────────────────────────────────────────────
alter table public.ex_error_logs drop constraint if exists ex_error_logs_source_check;
alter table public.ex_error_logs add constraint ex_error_logs_source_check
  check (source in ('client', 'server', 'whatsapp'));

create or replace function public.ex_error_log_upsert(
  p_key text, p_source text, p_severity text, p_operation text, p_code text,
  p_message text, p_user uuid, p_metadata jsonb
) returns void
language plpgsql security definer set search_path to '' as $$
declare v_id uuid; v_email text;
begin
  select id into v_id from public.ex_error_logs
   where dedupe_key = p_key and resolved_at is null order by last_seen desc limit 1;
  if v_id is not null then
    update public.ex_error_logs
       set occurrences = occurrences + 1, last_seen = now(),
           message = left(coalesce(nullif(btrim(p_message), ''), message), 2000),
           metadata = coalesce(p_metadata, metadata)
     where id = v_id;
    return;
  end if;
  if p_user is not null then select p.email into v_email from public.ex_profiles p where p.id = p_user; end if;
  insert into public.ex_error_logs (user_id, user_email, source, severity, operation, error_code, message, metadata, dedupe_key)
  values (p_user, v_email, p_source, p_severity, left(p_operation, 100), left(p_code, 120),
          left(coalesce(nullif(btrim(p_message), ''), p_code), 2000), coalesce(p_metadata, '{}'::jsonb), left(p_key, 128));
end $$;
revoke all on function public.ex_error_log_upsert(text, text, text, text, text, text, uuid, jsonb) from public, anon, authenticated;
grant execute on function public.ex_error_log_upsert(text, text, text, text, text, text, uuid, jsonb) to service_role;

-- WhatsApp order notifications: failed → a row; sent later → resolved
create or replace function public.ex_whatsapp_message_log()
returns trigger language plpgsql security definer set search_path to '' as $$
declare v_code text;
begin
  if new.status = 'failed' and (tg_op = 'INSERT' or old.status is distinct from 'failed') then
    select o.order_code into v_code from public.ex_orders o where o.id = new.order_id;
    perform public.ex_error_log_upsert(
      'wa:' || new.id::text, 'whatsapp', 'error', 'whatsapp_notification', 'WHATSAPP_NOT_DELIVERED',
      coalesce(nullif(btrim(new.last_error), ''), 'Wevlix did not accept the message'),
      new.user_id,
      jsonb_strip_nulls(jsonb_build_object('kind', new.kind, 'order_code', v_code, 'attempts', new.attempts, 'template', new.template_id)));
  elsif tg_op = 'UPDATE' and new.status = 'sent' and old.status is distinct from 'sent' then
    update public.ex_error_logs set resolved_at = now()
     where dedupe_key = 'wa:' || new.id::text and resolved_at is null;
  end if;
  return null;
end $$;
revoke all on function public.ex_whatsapp_message_log() from public, anon, authenticated;
drop trigger if exists trg_ex_whatsapp_message_log on public.ex_whatsapp_messages;
create trigger trg_ex_whatsapp_message_log
  after insert or update of status on public.ex_whatsapp_messages
  for each row execute function public.ex_whatsapp_message_log();

-- the queue stopped moving: messages waiting more than 15 minutes
create or replace function public.ex_whatsapp_queue_watch()
returns void language plpgsql security definer set search_path to '' as $$
declare v_waiting integer; v_oldest timestamptz;
begin
  select count(*), min(created_at) into v_waiting, v_oldest
    from public.ex_whatsapp_messages
   where status in ('queued', 'sending') and created_at < now() - interval '15 minutes';
  if v_waiting > 0 then
    perform public.ex_error_log_upsert(
      'wa-queue-stuck', 'whatsapp', 'critical', 'whatsapp_queue', 'WHATSAPP_QUEUE_STUCK',
      v_waiting || ' WhatsApp message(s) waiting since ' || to_char(v_oldest at time zone 'Asia/Baghdad', 'YYYY-MM-DD HH24:MI'),
      null, jsonb_build_object('waiting', v_waiting));
  else
    update public.ex_error_logs set resolved_at = now()
     where dedupe_key = 'wa-queue-stuck' and resolved_at is null;
  end if;
end $$;
revoke all on function public.ex_whatsapp_queue_watch() from public, anon, authenticated;
grant execute on function public.ex_whatsapp_queue_watch() to service_role;

-- old noise: nothing an admin can act on
update public.ex_error_logs set resolved_at = now()
 where resolved_at is null and source = 'client'
   and (error_code = 'Script error.' or message ~* '(java object is gone|SCDynimacBridge|ResizeObserver loop|extension://)');
update public.ex_error_logs set severity = 'warning'
 where source = 'client' and severity = 'error'
   and (coalesce(error_code, '') || ' ' || message) ~* '(failed to fetch|load failed|networkerror|network request failed|_NETWORK(_ERROR)?\M)';
-- refused for a reason the customer can fix (receipt already used, 4xx): warnings too
update public.ex_error_logs set severity = 'warning'
 where source = 'client' and severity = 'error'
   and (http_status between 400 and 499 or (coalesce(error_code, '') || ' ' || message) ~* '(RECEIPT_ALREADY_USED|already used|_HTTP_4[0-9][0-9])');

-- ── 2. activity ───────────────────────────────────────────────────
create table if not exists public.ex_user_activity (
  id             bigint generated always as identity primary key,
  user_id        uuid not null references auth.users(id) on delete cascade,
  session_id     uuid not null,
  route          text not null check (route ~ '^[a-z][a-z-]{1,30}$'),
  day            date not null,
  started_at     timestamptz not null default now(),
  last_seen_at   timestamptz not null default now(),
  active_seconds integer not null default 0 check (active_seconds >= 0),
  device         text check (device is null or char_length(device) <= 20),
  unique (session_id, route, day)
);
create index if not exists ex_user_activity_user_seen_idx on public.ex_user_activity (user_id, last_seen_at desc);
create index if not exists ex_user_activity_seen_idx on public.ex_user_activity (last_seen_at desc);

create table if not exists public.ex_user_presence (
  user_id            uuid primary key references auth.users(id) on delete cascade,
  session_id         uuid not null,
  route              text not null,
  device             text,
  last_seen_at       timestamptz not null default now(),
  session_started_at timestamptz not null default now()
);
create index if not exists ex_user_presence_seen_idx on public.ex_user_presence (last_seen_at desc);

alter table public.ex_user_activity enable row level security;
alter table public.ex_user_presence enable row level security;
revoke all on public.ex_user_activity, public.ex_user_presence from anon, authenticated;

-- called by the signed-in browser while a screen is visible (at most every 30s)
create or replace function public.ex_activity_ping(p_session uuid, p_route text, p_seconds integer, p_device text default null)
returns void language plpgsql security definer set search_path to '' as $$
declare
  v_uid   uuid := auth.uid();
  v_route text := lower(btrim(coalesce(p_route, '')));
  v_dev   text := nullif(left(btrim(coalesce(p_device, '')), 20), '');
  v_sec   integer := greatest(0, least(coalesce(p_seconds, 0), 120));
  v_day   date := (now() at time zone 'Asia/Baghdad')::date;
  v_prev  public.ex_user_presence;
begin
  if v_uid is null or p_session is null or v_route !~ '^[a-z][a-z-]{1,30}$' then return; end if;
  select * into v_prev from public.ex_user_presence where user_id = v_uid;
  -- never more seconds than have passed since this session's last ping
  if v_prev.user_id is not null and v_prev.session_id = p_session then
    v_sec := least(v_sec, greatest(0, ceil(extract(epoch from now() - v_prev.last_seen_at))::integer + 5));
  end if;
  insert into public.ex_user_activity as a (user_id, session_id, route, day, active_seconds, device)
  values (v_uid, p_session, v_route, v_day, v_sec, v_dev)
  on conflict (session_id, route, day) do update
     set last_seen_at = now(), active_seconds = a.active_seconds + excluded.active_seconds
   where a.user_id = v_uid;                       -- a session id belongs to one account
  insert into public.ex_user_presence as pr (user_id, session_id, route, device)
  values (v_uid, p_session, v_route, v_dev)
  on conflict (user_id) do update
     set route = excluded.route,
         device = coalesce(excluded.device, pr.device),
         last_seen_at = now(),
         session_started_at = case when pr.session_id = excluded.session_id then pr.session_started_at else now() end,
         session_id = excluded.session_id;
end $$;
revoke all on function public.ex_activity_ping(uuid, text, integer, text) from public, anon;
grant execute on function public.ex_activity_ping(uuid, text, integer, text) to authenticated, service_role;

-- admin: who is here, who was here, which screens hold people
create or replace function public.ex_admin_activity_overview(p_days integer default 7)
returns jsonb language sql stable security definer set search_path to '' as $$
  with cfg as (
    select greatest(1, least(coalesce(p_days, 7), 90)) as days,
           (now() at time zone 'Asia/Baghdad')::date as today
  ), win as (
    select a.* from public.ex_user_activity a, cfg where a.day > cfg.today - cfg.days
  ), per_user as (
    select w.user_id,
           sum(w.active_seconds) filter (where w.day = (select today from cfg)) as today_seconds,
           sum(w.active_seconds) as window_seconds,
           count(distinct w.session_id) as sessions
      from win w group by w.user_id
  )
  select jsonb_build_object(
    'days', (select days from cfg),
    'active_now', (select count(*) from public.ex_user_presence where last_seen_at > now() - interval '2 minutes'),
    'active_today', (select count(distinct user_id) from public.ex_user_activity where day = (select today from cfg)),
    'seconds_today', (select coalesce(sum(active_seconds), 0) from public.ex_user_activity where day = (select today from cfg)),
    'users', coalesce((select jsonb_agg(to_jsonb(u) order by u.last_seen_at desc) from (
        select pr.user_id, pr.last_seen_at, pr.route as last_route, pr.device, pr.session_started_at,
               p.full_name, p.email, p.phone,
               coalesce(pu.today_seconds, 0) as today_seconds,
               coalesce(pu.window_seconds, 0) as window_seconds,
               coalesce(pu.sessions, 0) as sessions
          from public.ex_user_presence pr
          left join public.ex_profiles p on p.id = pr.user_id
          left join per_user pu on pu.user_id = pr.user_id
         order by pr.last_seen_at desc
         limit 300) u), '[]'::jsonb),
    'sections', coalesce((select jsonb_agg(to_jsonb(s) order by s.seconds desc) from (
        select w.route, count(distinct w.user_id) as users, sum(w.active_seconds) as seconds, count(*) as visits
          from win w group by w.route) s), '[]'::jsonb)
  );
$$;

create or replace function public.ex_admin_activity_user(p_user uuid, p_days integer default 30)
returns jsonb language sql stable security definer set search_path to '' as $$
  with cfg as (
    select greatest(1, least(coalesce(p_days, 30), 90)) as days,
           (now() at time zone 'Asia/Baghdad')::date as today
  ), win as (
    select a.* from public.ex_user_activity a, cfg where a.user_id = p_user and a.day > cfg.today - cfg.days
  )
  select jsonb_build_object(
    'days', (select days from cfg),
    'profile', (select jsonb_build_object('full_name', p.full_name, 'email', p.email, 'phone', p.phone, 'created_at', p.created_at)
                  from public.ex_profiles p where p.id = p_user),
    'presence', (select to_jsonb(pr) - 'user_id' - 'session_id' from public.ex_user_presence pr where pr.user_id = p_user),
    'total_seconds', (select coalesce(sum(active_seconds), 0) from win),
    'sections', coalesce((select jsonb_agg(to_jsonb(s) order by s.seconds desc) from (
        select w.route, sum(w.active_seconds) as seconds, count(distinct w.session_id) as sessions, max(w.last_seen_at) as last_seen_at
          from win w group by w.route) s), '[]'::jsonb),
    'daily', coalesce((select jsonb_agg(to_jsonb(d) order by d.day desc) from (
        select w.day, sum(w.active_seconds) as seconds from win w group by w.day) d), '[]'::jsonb),
    'sessions', coalesce((select jsonb_agg(to_jsonb(x) order by x.started_at desc) from (
        select min(w.started_at) as started_at, max(w.last_seen_at) as ended_at, sum(w.active_seconds) as seconds,
               max(w.device) as device,
               jsonb_agg(jsonb_build_object('route', w.route, 'seconds', w.active_seconds) order by w.started_at) as screens
          from win w group by w.session_id
          order by min(w.started_at) desc
          limit 30) x), '[]'::jsonb)
  );
$$;
revoke all on function public.ex_admin_activity_overview(integer) from public, anon, authenticated;
revoke all on function public.ex_admin_activity_user(uuid, integer) from public, anon, authenticated;
grant execute on function public.ex_admin_activity_overview(integer) to service_role;
grant execute on function public.ex_admin_activity_user(uuid, integer) to service_role;

-- ── 3. WhatsApp notifications for admins ─────────────────────────
alter table public.ex_whatsapp_consent_log
  add column if not exists changed_by uuid references auth.users(id) on delete set null;   -- null: the customer

create or replace function public.ex_admin_whatsapp_subscribers()
returns jsonb language sql stable security definer set search_path to '' as $$
  select coalesce(jsonb_agg(to_jsonb(r) order by r.enabled desc, r.updated_at desc), '[]'::jsonb) from (
    select s.user_id, s.enabled, s.phone, s.created_at, s.updated_at,
           p.full_name, p.email, p.phone as account_phone, (p.phone_verified_at is not null) as phone_verified,
           (select jsonb_build_object('enabled', c.enabled, 'at', c.created_at, 'by_admin', c.changed_by is not null)
              from public.ex_whatsapp_consent_log c where c.user_id = s.user_id order by c.created_at desc limit 1) as last_change,
           (select count(*) from public.ex_whatsapp_messages m where m.user_id = s.user_id and m.status = 'sent') as sent,
           (select count(*) from public.ex_whatsapp_messages m where m.user_id = s.user_id and m.status = 'failed') as failed
      from public.ex_whatsapp_settings s
      left join public.ex_profiles p on p.id = s.user_id
  ) r;
$$;

create or replace function public.ex_admin_whatsapp_set(p_user uuid, p_enabled boolean, p_admin uuid)
returns jsonb language plpgsql security definer set search_path to '' as $$
declare v_phone text; v_cur public.ex_whatsapp_settings;
begin
  if p_user is null or p_enabled is null then raise exception 'bad_input' using errcode = '22023'; end if;
  select * into v_cur from public.ex_whatsapp_settings where user_id = p_user;
  if v_cur.user_id is null then raise exception 'not_subscribed' using errcode = 'P0002'; end if;
  select public.ex_wa_normalize_phone(p.phone) into v_phone
    from public.ex_profiles p where p.id = p_user and p.phone_verified_at is not null;
  if p_enabled and v_phone is null then raise exception 'phone_not_verified' using errcode = '22023'; end if;
  if v_cur.enabled is not distinct from p_enabled and (not p_enabled or v_cur.phone is not distinct from v_phone) then
    return jsonb_build_object('user_id', p_user, 'enabled', p_enabled, 'changed', false);
  end if;
  update public.ex_whatsapp_settings
     set enabled = p_enabled, phone = coalesce(v_phone, phone), updated_at = now()
   where user_id = p_user;
  insert into public.ex_whatsapp_consent_log (user_id, enabled, phone, changed_by)
  values (p_user, p_enabled, coalesce(v_phone, v_cur.phone), p_admin);
  return jsonb_build_object('user_id', p_user, 'enabled', p_enabled, 'changed', true);
end $$;
revoke all on function public.ex_admin_whatsapp_subscribers() from public, anon, authenticated;
revoke all on function public.ex_admin_whatsapp_set(uuid, boolean, uuid) from public, anon, authenticated;
grant execute on function public.ex_admin_whatsapp_subscribers() to service_role;
grant execute on function public.ex_admin_whatsapp_set(uuid, boolean, uuid) to service_role;

-- ── schedules ─────────────────────────────────────────────────────
do $cron$
begin
  perform cron.unschedule(jobid) from cron.job where jobname in ('ex-whatsapp-queue-watch', 'ex-user-activity-retention');
  perform cron.schedule('ex-whatsapp-queue-watch', '*/10 * * * *', 'select public.ex_whatsapp_queue_watch()');
  perform cron.schedule('ex-user-activity-retention', '23 3 * * *',
    $$delete from public.ex_user_activity where day < (now() at time zone 'Asia/Baghdad')::date - 90$$);
end $cron$;
