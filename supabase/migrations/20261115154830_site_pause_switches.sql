-- v52: the admin pauses the whole site or one section and turns it back on.
--
--   site      every customer action (the customer app shows one notice)
--   exchange  new exchange requests
--   balance   sending balance and paying with the balance
--   support   new support cases
--   verify    identity verification submissions
--   signup    new accounts
--   login     signing in and "forgot password"
--   account   name, mobile number, e-mail, password, deleting the account
--
-- The server (api-handlers: orders, balance, support-cases, auth) checks the
-- switches before acting. The three actions the browser sends straight to the
-- database (identity submission, account deletion request, name/username
-- change) are stopped here by triggers. Staff, the server and scheduled jobs
-- are never stopped. Nothing else changes: no prices, no orders, no accounts.

create table if not exists public.ex_site_controls (
  key        text primary key,
  paused     boolean not null default false,
  message    text,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  constraint ex_site_controls_key_check
    check (key in ('site', 'exchange', 'balance', 'support', 'verify', 'signup', 'login', 'account')),
  constraint ex_site_controls_message_check
    check (message is null or char_length(message) <= 300)
);
insert into public.ex_site_controls (key)
values ('site'), ('exchange'), ('balance'), ('support'), ('verify'), ('signup'), ('login'), ('account')
on conflict (key) do nothing;

create table if not exists public.ex_site_control_log (
  id         bigint generated always as identity primary key,
  key        text not null,
  paused     boolean not null,
  message    text,
  changed_by uuid references auth.users(id) on delete set null,
  changed_at timestamptz not null default now()
);
create index if not exists ex_site_control_log_changed_at_idx on public.ex_site_control_log (changed_at desc);

alter table public.ex_site_controls enable row level security;
alter table public.ex_site_control_log enable row level security;
revoke all on public.ex_site_controls, public.ex_site_control_log from anon, authenticated;

-- What the customer app reads: only the paused sections, with the admin's message.
create or replace function public.ex_site_status()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    jsonb_object_agg(c.key, jsonb_build_object('message', c.message, 'since', c.updated_at)) filter (where c.paused),
    '{}'::jsonb)
  from public.ex_site_controls c;
$$;
revoke all on function public.ex_site_status() from public;
grant execute on function public.ex_site_status() to anon, authenticated, service_role;

-- Is this section (or the whole site) paused right now?
create or replace function public.ex_site_paused(p_key text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.ex_site_controls c where c.paused and c.key in ('site', p_key));
$$;
revoke all on function public.ex_site_paused(text) from public;
grant execute on function public.ex_site_paused(text) to anon, authenticated, service_role;

-- The panel (/api/admin, super admin only) switches a section; every change is kept.
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
         updated_at = now(),
         updated_by = p_admin
   where key = p_key
  returning * into v_row;
  if not found then raise exception 'unknown_section' using errcode = 'P0001'; end if;
  insert into public.ex_site_control_log (key, paused, message, changed_by)
  values (v_row.key, v_row.paused, v_row.message, p_admin);
  return to_jsonb(v_row);
end;
$$;
revoke all on function public.ex_admin_site_control_set(text, boolean, text, uuid) from public, anon, authenticated;
grant execute on function public.ex_admin_site_control_set(text, boolean, text, uuid) to service_role;

-- Stops only the signed-in customer's own action (auth.uid() = the row's owner).
-- tg_argv[0] is the section. The "0" in the trigger names makes them run before
-- the tables' other BEFORE triggers, so a paused section answers first.
create or replace function public.ex_site_pause_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_owner uuid;
begin
  if v_uid is null then return new; end if;
  if tg_table_name = 'ex_profiles' then
    v_owner := new.id;
    if new.full_name is not distinct from old.full_name and new.username is not distinct from old.username then
      return new;
    end if;
  else
    v_owner := new.user_id;
  end if;
  if v_owner is distinct from v_uid then return new; end if;
  if public.ex_site_paused(tg_argv[0]) then
    raise exception using errcode = 'P0001', message = 'SECTION_PAUSED', hint = tg_argv[0];
  end if;
  return new;
end;
$$;
revoke all on function public.ex_site_pause_guard() from public, anon, authenticated;

drop trigger if exists trg_ex_0_pause_verify on public.ex_identity_verifications;
create trigger trg_ex_0_pause_verify
  before insert on public.ex_identity_verifications
  for each row execute function public.ex_site_pause_guard('verify');

drop trigger if exists trg_ex_0_pause_delete on public.ex_account_deletions;
create trigger trg_ex_0_pause_delete
  before insert on public.ex_account_deletions
  for each row execute function public.ex_site_pause_guard('account');

drop trigger if exists trg_ex_0_pause_profile on public.ex_profiles;
create trigger trg_ex_0_pause_profile
  before update of full_name, username on public.ex_profiles
  for each row execute function public.ex_site_pause_guard('account');
