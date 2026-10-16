-- Internal diagnostics only: no owner/user SELECT grants, no public dashboard.
begin;
create schema if not exists app_telemetry;
revoke all on schema app_telemetry from public,anon,authenticated;
grant usage on schema app_telemetry to authenticated;
create table if not exists app_telemetry.installations (
 user_id uuid not null references auth.users(id) on delete cascade,installation_id uuid not null,
 device_model text,os text,os_version text,app_version text,build_number text,platform text,
 first_seen_at timestamptz not null default now(),last_seen_at timestamptz not null default now(),
 primary key(user_id,installation_id)
);
create table if not exists app_telemetry.sessions (
 user_id uuid not null,installation_id uuid not null,run_id uuid not null,auth_session_id uuid not null,
 sequence bigint not null default -1,started_at timestamptz not null default now(),last_seen_at timestamptz not null default now(),
 foreground boolean not null default false,section text not null default 'unknown',active_seconds integer not null default 0 check(active_seconds>=0),
 primary key(user_id,run_id),foreign key(user_id,installation_id) references app_telemetry.installations(user_id,installation_id) on delete cascade
);
create index if not exists telemetry_sessions_presence on app_telemetry.sessions(last_seen_at desc) where foreground;
create index if not exists telemetry_sessions_device on app_telemetry.sessions(user_id,installation_id,last_seen_at desc);
create table if not exists app_telemetry.events (
 user_id uuid not null references auth.users(id) on delete cascade,event_id uuid not null,installation_id uuid not null,run_id uuid not null,
 kind text not null check(kind in ('section','error','action','performance')),section text not null,code text not null,
 outcome text check(outcome in ('success','failure','incomplete')),duration_ms integer check(duration_ms between 0 and 600000),
 app_version text,device_model text,received_at timestamptz not null default now(),primary key(user_id,event_id)
);
create index if not exists telemetry_events_time on app_telemetry.events(received_at);
create index if not exists telemetry_events_errors on app_telemetry.events(section,code,app_version,received_at desc) where kind='error';
create table if not exists app_telemetry.daily_usage (
 day date not null,user_id uuid not null references auth.users(id) on delete cascade,installation_id uuid not null,section text not null,
 active_seconds bigint not null default 0 check(active_seconds>=0),visits bigint not null default 0,
 primary key(day,user_id,installation_id,section)
);
create table if not exists app_telemetry.daily_events (
 day date not null,kind text not null,section text not null,code text not null,app_version text not null,
 occurrences bigint not null default 0,duration_ms bigint not null default 0,
 primary key(day,kind,section,code,app_version)
);
create table if not exists app_telemetry.audit_events (
 id uuid primary key default gen_random_uuid(),actor_id uuid,subject_id uuid,action text not null,reference text,outcome text,
 created_at timestamptz not null default now()
);
create index if not exists telemetry_audit_subject on app_telemetry.audit_events(subject_id,created_at desc);

create or replace function app_telemetry.ingest(p_batch jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=app_finance.actor(); installation uuid; run uuid; sid uuid; seq bigint;
 old app_telemetry.sessions%rowtype; now_at timestamptz:=clock_timestamp(); fg boolean; section_name text; meta jsonb; event jsonb;
 seconds integer:=0; inserted integer; v_event_id uuid; event_kind text; event_code text; event_section text; ms integer; outcome_value text;
begin
 if p_batch is null or jsonb_typeof(p_batch)<>'object' or octet_length(p_batch::text)>32768 then raise exception 'INVALID_TELEMETRY'; end if;
 begin
  installation:=(p_batch->>'installation_id')::uuid; run:=(p_batch->>'run_id')::uuid;
  sid:=(auth.jwt()->>'session_id')::uuid; seq:=(p_batch->>'sequence')::bigint; fg:=(p_batch->>'foreground')::boolean;
 exception when invalid_text_representation then raise exception 'INVALID_TELEMETRY'; end;
 section_name:=coalesce(p_batch->>'section','unknown'); meta:=coalesce(p_batch->'device','{}'::jsonb);
 if installation is null or run is null or seq is null or seq<0 or fg is null or section_name!~'^[a-z0-9_/-]{1,80}$'
  or jsonb_typeof(meta)<>'object' or jsonb_typeof(coalesce(p_batch->'events','[]'::jsonb))<>'array'
  or jsonb_array_length(coalesce(p_batch->'events','[]'::jsonb))>20 then raise exception 'INVALID_TELEMETRY'; end if;
 if not app_finance.rate_allowed(u,'telemetry',180) then return jsonb_build_object('ok',false,'code','RATE_LIMITED'); end if;
 insert into app_telemetry.installations(user_id,installation_id,device_model,os,os_version,app_version,build_number,platform,last_seen_at)
 values(u,installation,left(meta->>'device_model',100),left(meta->>'os',40),left(meta->>'os_version',40),left(meta->>'app_version',40),left(meta->>'build_number',30),left(meta->>'platform',20),now_at)
 on conflict(user_id,installation_id) do update set last_seen_at=excluded.last_seen_at,
 device_model=coalesce(excluded.device_model,installations.device_model),os=coalesce(excluded.os,installations.os),
 os_version=coalesce(excluded.os_version,installations.os_version),app_version=coalesce(excluded.app_version,installations.app_version),
 build_number=coalesce(excluded.build_number,installations.build_number),platform=coalesce(excluded.platform,installations.platform);
 insert into app_telemetry.sessions(user_id,installation_id,run_id,auth_session_id,last_seen_at)
 values(u,installation,run,sid,now_at) on conflict(user_id,run_id) do nothing;
 select * into old from app_telemetry.sessions where user_id=u and run_id=run for update;
 if old.installation_id<>installation or old.auth_session_id<>sid then raise exception 'SESSION_CONFLICT' using errcode='42501'; end if;
 if seq>old.sequence then
  -- Count only observed foreground intervals. A long offline gap is unknown,
  -- not activity. A killed app cannot report its exact closing timestamp.
  if old.foreground and now_at-old.last_seen_at<=interval '90 seconds' then seconds:=least(45,greatest(0,floor(extract(epoch from now_at-old.last_seen_at))::integer)); end if;
  if seconds>0 then
   insert into app_telemetry.daily_usage(day,user_id,installation_id,section,active_seconds)
   values((now_at at time zone 'Asia/Baghdad')::date,u,installation,old.section,seconds)
   on conflict(day,user_id,installation_id,section) do update set active_seconds=daily_usage.active_seconds+excluded.active_seconds;
  end if;
  if fg and (not old.foreground or old.section<>section_name) and not exists(
   select 1 from jsonb_array_elements(coalesce(p_batch->'events','[]'::jsonb)) e
   where e->>'kind'='section' and e->>'code'='enter' and e->>'section'=section_name) then
   insert into app_telemetry.daily_usage(day,user_id,installation_id,section,visits)
   values((now_at at time zone 'Asia/Baghdad')::date,u,installation,section_name,1)
   on conflict(day,user_id,installation_id,section) do update set visits=daily_usage.visits+1;
  end if;
  update app_telemetry.sessions set sequence=seq,last_seen_at=now_at,foreground=fg,section=section_name,active_seconds=active_seconds+seconds
  where user_id=u and run_id=run;
 end if;
 for event in select value from jsonb_array_elements(coalesce(p_batch->'events','[]'::jsonb)) loop
  v_event_id:=(event->>'id')::uuid; event_kind:=event->>'kind'; event_code:=event->>'code'; event_section:=event->>'section';
  ms:=(event->>'duration_ms')::integer; outcome_value:=event->>'outcome';
  if v_event_id is null or event_kind not in ('section','error','action','performance') or event_kind is null
    or event_code is null or event_code!~'^[A-Za-z0-9_.:-]{1,100}$' or event_section is null or event_section!~'^[a-z0-9_/-]{1,80}$'
    or (ms is not null and ms not between 0 and 600000) or (outcome_value is not null and outcome_value not in ('success','failure','incomplete')) then raise exception 'INVALID_EVENT'; end if;
  insert into app_telemetry.events(user_id,event_id,installation_id,run_id,kind,section,code,outcome,duration_ms,app_version,device_model,received_at)
  values(u,v_event_id,installation,run,event_kind,event_section,event_code,outcome_value,ms,left(meta->>'app_version',40),left(meta->>'device_model',100),now_at)
  on conflict(user_id,event_id) do nothing;
  get diagnostics inserted=row_count;
  if inserted=1 then
   if event_kind='section' and event_code='enter' then
    insert into app_telemetry.daily_usage(day,user_id,installation_id,section,visits)
    values((now_at at time zone 'Asia/Baghdad')::date,u,installation,event_section,1)
    on conflict(day,user_id,installation_id,section) do update set visits=daily_usage.visits+1;
   end if;
   insert into app_telemetry.daily_events(day,kind,section,code,app_version,occurrences,duration_ms)
   values((now_at at time zone 'Asia/Baghdad')::date,event_kind,event_section,event_code,coalesce(left(meta->>'app_version',40),'unknown'),1,coalesce(ms,0))
   on conflict(day,kind,section,code,app_version) do update set occurrences=daily_events.occurrences+1,duration_ms=daily_events.duration_ms+excluded.duration_ms;
  end if;
 end loop;
 return jsonb_build_object('ok',true,'received_at',now_at,'sequence',seq);
end $$;
create or replace function public.pa_record_app_telemetry(p_batch jsonb) returns jsonb
language sql security invoker set search_path='' as $$ select app_telemetry.ingest(p_batch); $$;

-- Views are private, with no client grants. Presence also checks that the
-- associated Auth session still exists (logout/revocation immediately removes presence).
create or replace view app_telemetry.device_presence as
select d.*,exists(select 1 from app_telemetry.sessions s join auth.sessions a on a.id=s.auth_session_id and a.user_id=s.user_id
 where s.user_id=d.user_id and s.installation_id=d.installation_id and s.foreground and s.last_seen_at>now()-interval '90 seconds'
 and (a.not_after is null or a.not_after>now())) as active,
 (select s.section from app_telemetry.sessions s where s.user_id=d.user_id and s.installation_id=d.installation_id order by s.last_seen_at desc limit 1) as last_reported_section
from app_telemetry.installations d;
create or replace view app_telemetry.account_presence as
select user_id,count(*) as registered_installations,count(*) filter(where active) as active_installations,bool_or(active) as active,max(last_seen_at) as last_seen_at
from app_telemetry.device_presence group by user_id;

create or replace function app_telemetry.report(p_days integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare since_day date:=(now() at time zone 'Asia/Baghdad')::date-least(90,greatest(1,coalesce(p_days,30)))+1;
begin
 perform app_finance.actor();
 if not public.pa_is_admin() then raise exception 'ADMIN_REQUIRED' using errcode='42501'; end if;
 return jsonb_build_object(
 'generated_at',now(),'timezone','Asia/Baghdad','since',since_day,
 'most_used_sections',(select coalesce(jsonb_agg(x),'[]') from (select section,sum(visits) visits,sum(active_seconds) active_seconds from app_telemetry.daily_usage where day>=since_day group by section order by sum(visits) desc,sum(active_seconds) desc limit 30)x),
 'most_active_accounts',(select coalesce(jsonb_agg(x),'[]') from (select user_id,sum(active_seconds) active_seconds,sum(visits) visits,count(distinct installation_id) installations from app_telemetry.daily_usage where day>=since_day group by user_id order by sum(active_seconds) desc limit 100)x),
 'most_active_devices',(select coalesce(jsonb_agg(x),'[]') from (select user_id,installation_id,sum(active_seconds) active_seconds,sum(visits) visits from app_telemetry.daily_usage where day>=since_day group by user_id,installation_id order by sum(active_seconds) desc limit 100)x),
 'daily',(select coalesce(jsonb_agg(x),'[]') from (select day,count(distinct user_id) users,count(distinct (user_id,installation_id)) devices,sum(active_seconds) active_seconds from app_telemetry.daily_usage where day>=since_day group by day order by day)x),
 'errors',(select coalesce(jsonb_agg(x),'[]') from (select section,code,app_version,sum(occurrences) occurrences from app_telemetry.daily_events where day>=since_day and kind='error' group by section,code,app_version order by sum(occurrences) desc limit 100)x),
 'performance',(select coalesce(jsonb_agg(x),'[]') from (select section,code,app_version,sum(occurrences) samples,sum(duration_ms)/greatest(sum(occurrences),1) mean_ms from app_telemetry.daily_events where day>=since_day and kind='performance' group by section,code,app_version order by section limit 100)x)
 );
end $$;
create or replace function public.pa_admin_app_report(p_days integer default 30) returns jsonb
language sql security invoker set search_path='' as $$ select app_telemetry.report(p_days); $$;

create or replace function app_telemetry.audit_operation() returns trigger
language plpgsql security definer set search_path='' as $$ begin
 insert into app_telemetry.audit_events(actor_id,subject_id,action,reference,outcome)
 values(new.actor_id,new.actor_id,new.operation,new.request_key::text,case when new.result->>'ok'='true' then 'success' else 'failure' end);
 return new; end $$;
drop trigger if exists telemetry_financial_actions on app_finance.operations;
create trigger telemetry_financial_actions after insert on app_finance.operations for each row execute function app_telemetry.audit_operation();
create or replace function app_telemetry.audit_login_failure() returns trigger
language plpgsql security definer set search_path='' as $$ begin
 if new.failed_login_attempts>old.failed_login_attempts then
  insert into app_telemetry.audit_events(subject_id,action,outcome) values(new.id,'login_attempt','failure');
 end if;return new;end $$;
drop trigger if exists telemetry_login_failure on public.profiles;
create trigger telemetry_login_failure after update of failed_login_attempts on public.profiles for each row execute function app_telemetry.audit_login_failure();

create or replace function app_telemetry.prune() returns void language plpgsql security definer set search_path='' as $$ begin
 delete from app_telemetry.events where received_at<now()-interval '30 days';
 delete from app_telemetry.sessions where last_seen_at<now()-interval '90 days';
 delete from app_telemetry.installations where last_seen_at<now()-interval '365 days';
 delete from app_telemetry.daily_usage where day<current_date-365;
 delete from app_telemetry.daily_events where day<current_date-365;
 delete from app_telemetry.audit_events where created_at<now()-interval '365 days';
end $$;
-- pg_cron is optional in isolated tests; operational deployment must schedule
-- app_telemetry.prune() daily if cron is unavailable. Never prune financial ledger.
do $$ declare t text; r record; begin
 foreach t in array array['installations','sessions','events','daily_usage','daily_events','audit_events'] loop
  execute format('alter table app_telemetry.%I enable row level security',t);
  execute format('revoke all on app_telemetry.%I from public,anon,authenticated',t);
 end loop;
 revoke all on app_telemetry.device_presence,app_telemetry.account_presence from public,anon,authenticated;
 for r in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='app_telemetry' loop
  execute format('revoke all on function %s from public,anon,authenticated',r.sig);
 end loop;
 if exists(select 1 from pg_extension where extname='pg_cron') then
  perform cron.schedule('proxo-private-telemetry-retention','20 2 * * *','select app_telemetry.prune()');
 end if;
end $$;
grant execute on function app_telemetry.ingest(jsonb),app_telemetry.report(integer) to authenticated;
revoke all on function public.pa_record_app_telemetry(jsonb),public.pa_admin_app_report(integer) from public,anon;
grant execute on function public.pa_record_app_telemetry(jsonb),public.pa_admin_app_report(integer) to authenticated;
commit;
