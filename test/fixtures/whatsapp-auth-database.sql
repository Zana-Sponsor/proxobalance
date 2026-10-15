-- Disposable Postgres fixture: no production keys, users or messages.
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
create schema auth;
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid;
$$;
grant usage on schema auth to authenticated,anon,service_role;
create table auth.users(id uuid primary key,phone text,phone_confirmed_at timestamptz);
create table public.otp_whatsapp (
  id uuid primary key default gen_random_uuid(), user_id uuid,
  phone text not null, code text not null, wevlix_message_id text not null,
  purpose text default 'login', is_used boolean default false,
  expires_at timestamptz not null, verified_at timestamptz,
  created_at timestamptz default now(), message_status text, status_updated_at timestamptz,
  send_count integer not null default 1, last_sent_at timestamptz,
  verify_attempts integer not null default 0, locked_at timestamptz
);
-- Reproduce the pre-migration exposed function grants.
create function public.verify_otp_whatsapp(text,text) returns json language sql as $$ select '{}'::json $$;
grant execute on function public.verify_otp_whatsapp(text,text) to anon,authenticated,service_role;
insert into auth.users values
 ('11111111-1111-4111-8111-111111111111','9647500000001',now()),
 ('22222222-2222-4222-8222-222222222222','9647500000002',now()),
 ('33333333-3333-4333-8333-333333333333','9647500000003',null);
