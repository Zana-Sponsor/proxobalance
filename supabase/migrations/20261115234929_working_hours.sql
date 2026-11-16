-- v55: working hours. Any switch (the whole site or one section) can open and
-- close by itself at set times (Asia/Baghdad) on chosen days.
--   • It acts only when the time crosses an opening or closing time, so an
--     admin who opens or closes by hand is not undone until the next one.
--   • At opening it reopens only what the hours closed; a section the admin
--     closed by hand stays closed.
--   • Customers see the change at once (ex_site_controls → ex_live_versions).
-- Checked every minute by pg_cron ('ex-site-schedule').

alter table public.ex_site_controls
  add column if not exists paused_source text not null default 'admin';
alter table public.ex_site_controls drop constraint if exists ex_site_controls_paused_source_check;
alter table public.ex_site_controls add constraint ex_site_controls_paused_source_check check (paused_source in ('admin', 'schedule'));
alter table public.ex_site_control_log
  add column if not exists source text not null default 'admin';
alter table public.ex_site_control_log drop constraint if exists ex_site_control_log_source_check;
alter table public.ex_site_control_log add constraint ex_site_control_log_source_check check (source in ('admin', 'schedule'));

create table if not exists public.ex_site_schedules (
  key        text primary key references public.ex_site_controls(key) on delete cascade,
  open_at    time not null,
  close_at   time not null,
  days       smallint[] not null default '{0,1,2,3,4,5,6}',   -- 0 = Sunday … 6 = Saturday (extract(dow))
  message    text,
  is_active  boolean not null default true,
  last_state text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  constraint ex_site_schedules_times_check check (open_at <> close_at),
  constraint ex_site_schedules_days_check check (days <@ '{0,1,2,3,4,5,6}'::smallint[] and cardinality(days) between 1 and 7),
  constraint ex_site_schedules_message_check check (message is null or char_length(message) <= 300),
  constraint ex_site_schedules_state_check check (last_state is null or last_state in ('open', 'closed'))
);
alter table public.ex_site_schedules enable row level security;
revoke all on public.ex_site_schedules from anon, authenticated;

-- open right now? A closing time at or before the opening time ends the next day (09:00 → 00:00, 18:00 → 02:00).
create or replace function public.ex_site_schedule_is_open(p_open time, p_close time, p_days smallint[], p_now timestamptz default now())
returns boolean
language sql
stable
set search_path = ''
as $$
  with t as (
    select (p_now at time zone 'Asia/Baghdad') as local
  ), x as (
    select extract(dow from local)::smallint as d, ((extract(dow from local)::int + 6) % 7)::smallint as yd, local::time as tm from t
  )
  select case
    when p_close > p_open then x.d = any(p_days) and x.tm >= p_open and x.tm < p_close
    else (x.d = any(p_days) and x.tm >= p_open) or (x.yd = any(p_days) and x.tm < p_close)
  end
  from x;
$$;
revoke all on function public.ex_site_schedule_is_open(time, time, smallint[], timestamptz) from public, anon, authenticated;

-- the text customers read while it is closed by the hours
create or replace function public.ex_site_schedule_text(p_open time, p_close time, p_days smallint[])
returns text
language sql
immutable
set search_path = ''
as $$
  select 'کاتی کار: '
    || case when cardinality(p_days) = 7 then ''
            when cardinality(p_days) = 6 then 'جگە لە '
              || (select (array['یەکشەممە','دووشەممە','سێشەممە','چوارشەممە','پێنجشەممە','هەینی','شەممە'])[d + 1]
                    from generate_series(0, 6) as d where not (d::smallint = any(p_days))) || '، '
            else (select string_agg((array['یەکشەممە','دووشەممە','سێشەممە','چوارشەممە','پێنجشەممە','هەینی','شەممە'])[d + 1], '، ' order by (d + 1) % 7)
                    from unnest(p_days) as d) || '، ' end
    || to_char(p_open, 'HH24:MI') || ' تا ' || to_char(p_close, 'HH24:MI');
$$;
revoke all on function public.ex_site_schedule_text(time, time, smallint[]) from public, anon, authenticated;

-- reopen a section only if the hours closed it
create or replace function public.ex_site_schedule_release(p_key text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.ex_site_controls
     set paused = false, message = null, paused_source = 'admin', updated_at = now(), updated_by = null
   where key = p_key and paused and paused_source = 'schedule';
  if found then
    insert into public.ex_site_control_log (key, paused, message, changed_by, source) values (p_key, false, null, null, 'schedule');
  end if;
end;
$$;
revoke all on function public.ex_site_schedule_release(text) from public, anon, authenticated;

create or replace function public.ex_site_schedule_tick()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  s public.ex_site_schedules;
  v_state text;
  v_msg text;
begin
  for s in select * from public.ex_site_schedules where is_active for update loop
    v_state := case when public.ex_site_schedule_is_open(s.open_at, s.close_at, s.days) then 'open' else 'closed' end;
    continue when s.last_state is not distinct from v_state;
    if v_state = 'closed' then
      v_msg := coalesce(nullif(btrim(s.message), ''), public.ex_site_schedule_text(s.open_at, s.close_at, s.days));
      update public.ex_site_controls
         set paused = true, message = v_msg, paused_source = 'schedule', updated_at = now(), updated_by = null
       where key = s.key and not paused;
      if found then
        insert into public.ex_site_control_log (key, paused, message, changed_by, source) values (s.key, true, v_msg, null, 'schedule');
      end if;
    else
      perform public.ex_site_schedule_release(s.key);
    end if;
    update public.ex_site_schedules set last_state = v_state where key = s.key;
  end loop;
end;
$$;
revoke all on function public.ex_site_schedule_tick() from public, anon, authenticated;
grant execute on function public.ex_site_schedule_tick() to service_role;

-- panel (/api/admin, super admin)
create or replace function public.ex_admin_site_schedule_save(
  p_key text, p_open time, p_close time, p_days smallint[], p_message text, p_active boolean, p_admin uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare v_row public.ex_site_schedules;
begin
  if p_open is null or p_close is null or p_open = p_close then raise exception 'times_invalid' using errcode = 'P0001'; end if;
  insert into public.ex_site_schedules as s (key, open_at, close_at, days, message, is_active, last_state, updated_at, updated_by)
  values (p_key, p_open, p_close, p_days, nullif(btrim(coalesce(p_message, '')), ''), coalesce(p_active, true), null, now(), p_admin)
  on conflict (key) do update
     set open_at = excluded.open_at, close_at = excluded.close_at, days = excluded.days, message = excluded.message,
         is_active = excluded.is_active, last_state = null, updated_at = now(), updated_by = p_admin
  returning * into v_row;
  if not v_row.is_active then perform public.ex_site_schedule_release(p_key); end if;
  perform public.ex_site_schedule_tick();
  select * into v_row from public.ex_site_schedules where key = p_key;
  return to_jsonb(v_row);
end;
$$;
create or replace function public.ex_admin_site_schedule_delete(p_key text, p_admin uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.ex_site_schedules where key = p_key;
  perform public.ex_site_schedule_release(p_key);
end;
$$;
revoke all on function public.ex_admin_site_schedule_save(text, time, time, smallint[], text, boolean, uuid) from public, anon, authenticated;
revoke all on function public.ex_admin_site_schedule_delete(text, uuid) from public, anon, authenticated;
grant execute on function public.ex_admin_site_schedule_save(text, time, time, smallint[], text, boolean, uuid) to service_role;
grant execute on function public.ex_admin_site_schedule_delete(text, uuid) to service_role;

-- a hand change by the admin is marked as such (and resets "closed by the hours")
create or replace function public.ex_admin_site_control_set(p_key text, p_paused boolean, p_message text, p_admin uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_msg text := nullif(btrim(regexp_replace(coalesce(p_message, ''), '\s+', ' ', 'g')), '');
  v_row public.ex_site_controls%rowtype;
begin
  if p_paused is null then raise exception 'paused_required' using errcode = 'P0001'; end if;
  if v_msg is not null and char_length(v_msg) > 300 then raise exception 'message_too_long' using errcode = 'P0001'; end if;
  update public.ex_site_controls
     set paused = p_paused,
         message = case when p_paused then v_msg else null end,
         paused_source = 'admin',
         updated_at = now(),
         updated_by = p_admin
   where key = p_key
  returning * into v_row;
  if not found then raise exception 'unknown_section' using errcode = 'P0001'; end if;
  insert into public.ex_site_control_log (key, paused, message, changed_by, source)
  values (v_row.key, v_row.paused, v_row.message, p_admin, 'admin');
  return to_jsonb(v_row);
end;
$$;
revoke all on function public.ex_admin_site_control_set(text, boolean, text, uuid) from public, anon, authenticated;
grant execute on function public.ex_admin_site_control_set(text, boolean, text, uuid) to service_role;

do $cron$
begin
  perform cron.unschedule(jobid) from cron.job where jobname = 'ex-site-schedule';
  perform cron.schedule('ex-site-schedule', '* * * * *', 'select public.ex_site_schedule_tick()');
end $cron$;
