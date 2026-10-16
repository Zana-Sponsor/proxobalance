-- Disposable database only: no real accounts, sessions, keys or messages.
create role anon nologin;
create role authenticated nologin;
create role supabase_auth_admin nologin;
create schema auth;
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid;
$$;
create function auth.jwt() returns jsonb language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb;
$$;
grant usage on schema auth to authenticated,anon,supabase_auth_admin;
create table auth.users(id uuid primary key,last_sign_in_at timestamptz);
create table auth.sessions(id uuid primary key,user_id uuid references auth.users on delete cascade,
  created_at timestamptz not null default now(),updated_at timestamptz,not_after timestamptz,ip inet,user_agent text);
grant select,insert,update,delete on auth.sessions to supabase_auth_admin;
create table public.profiles(id uuid primary key references auth.users on delete cascade);
create table public.pa_activity_log(id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users on delete cascade,action text,description text,created_at timestamptz default now());
create table public.pa_login_history(id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users on delete cascade,session_id text,success boolean,login_status text,
  created_at timestamptz default now(),login_time timestamptz,logout_time timestamptz,session_duration integer,last_seen_at timestamptz,
  device_info text,device_name text,device_model text,os text,os_version text,platform text,ip_address text,user_agent text);
alter table public.profiles enable row level security;
alter table public.pa_activity_log enable row level security;
alter table public.pa_login_history enable row level security;
create policy profile_owner on public.profiles to authenticated using(id=auth.uid()) with check(id=auth.uid());
create policy history_owner_read on public.pa_login_history for select to authenticated using(user_id=auth.uid());
create policy history_owner_insert on public.pa_login_history for insert to authenticated with check(user_id=auth.uid());
create policy activity_owner_read on public.pa_activity_log for select to authenticated using(user_id=auth.uid());
grant select,update on public.profiles to authenticated;
grant select,insert on public.pa_login_history to authenticated;
grant select on public.pa_activity_log to authenticated;
insert into auth.users values
 ('11111111-1111-4111-8111-111111111111','2026-10-01T12:00:00Z'),
 ('22222222-2222-4222-8222-222222222222',null);
insert into public.profiles select id from auth.users;
create function public.test_assert(ok boolean,message text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'FAIL: %',message; end if; end $$;
