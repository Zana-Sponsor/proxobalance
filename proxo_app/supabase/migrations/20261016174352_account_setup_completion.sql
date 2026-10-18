-- Authoritative, resumable provisioning. No optional network preload is a gate.
begin;
create schema if not exists app_setup;
revoke all on schema app_setup from public,anon,authenticated;
grant usage on schema app_setup to authenticated;
create table if not exists app_setup.completions (
 user_id uuid primary key references auth.users(id) on delete cascade,
 version integer not null check(version>0),completed_at timestamptz not null default now()
);
alter table app_setup.completions enable row level security;
revoke all on app_setup.completions from public,anon,authenticated;
create or replace function app_setup.ensure_account() returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=app_finance.actor(); account auth.users%rowtype;
begin
 perform pg_advisory_xact_lock(hashtextextended('setup:'||u::text,0));
 select * into account from auth.users where id=u;
 if not found or (account.email_confirmed_at is null and account.phone_confirmed_at is null) then
  return jsonb_build_object('ready',false,'code','VERIFICATION_REQUIRED');
 end if;
 insert into public.profiles(id,full_name,email,phone)
 values(u,left(coalesce(account.raw_user_meta_data->>'full_name',''),120),
  case when account.email ~* '@phone[.]proxo[.]local$|@phone[.]proxopages[.]com$' then null else account.email end,
  case when account.phone_confirmed_at is not null then account.phone else null end)
 on conflict(id) do nothing;
 insert into public.pa_wallets(user_id,balance) values(u,0) on conflict(user_id) do nothing;
 insert into public.pa_user_points(user_id,points) values(u,0) on conflict(user_id) do nothing;
 insert into public.pa_coins(user_id,coins_balance) values(u,0) on conflict(user_id) do nothing;
 -- Marker is useful for operations, but every call repairs/checks the records.
 insert into app_setup.completions(user_id,version) values(u,1)
 on conflict(user_id) do update set version=excluded.version;
 return jsonb_build_object('ready',true,'user_id',u,'version',1);
end $$;
create or replace function public.pa_ensure_account_ready() returns jsonb
language sql security invoker set search_path='' as $$ select app_setup.ensure_account(); $$;
revoke all on function app_setup.ensure_account(),public.pa_ensure_account_ready() from public,anon;
grant execute on function app_setup.ensure_account(),public.pa_ensure_account_ready() to authenticated;
-- Provisioning is server-owned. Existing profile editing remains available;
-- creating a row cannot be used to set identity, ban or admin fields.
revoke insert,delete on public.profiles from public,anon,authenticated;
commit;
