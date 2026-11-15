-- v53
-- 1. Every section of the customer site has its own pause switch. The one
--    "account" switch of v52 becomes five (name, phone, email, password,
--    delete); a paused "account" stays paused in all five. New switches:
--    home, transactions, correction, rating, balance_history, whatsapp,
--    changes, rules, profile.
-- 2. Image banners: slides in a fixed place on the dashboard, and screen
--    banners (popup) that the admin shows on chosen sections; a popup is
--    shown once per account. Images are small WebP files in the public
--    bucket "banners", uploaded through a one-time signed URL from /api/admin.
-- Nothing else changes: no prices, no orders, no accounts.

-- ── 1. switches ──────────────────────────────────────────────────
alter table public.ex_site_controls drop constraint if exists ex_site_controls_key_check;

insert into public.ex_site_controls (key, paused, message, updated_at, updated_by)
select k, coalesce(a.paused, false), a.message, coalesce(a.updated_at, now()), a.updated_by
  from unnest(array['name', 'phone', 'email', 'password', 'delete']) as k
  left join public.ex_site_controls a on a.key = 'account'
on conflict (key) do nothing;
insert into public.ex_site_controls (key)
select k from unnest(array['home', 'transactions', 'correction', 'rating', 'balance_history', 'whatsapp', 'changes', 'rules', 'profile']) as k
on conflict (key) do nothing;
delete from public.ex_site_controls where key = 'account';

alter table public.ex_site_controls add constraint ex_site_controls_key_check
  check (key in ('site', 'home', 'exchange', 'transactions', 'correction', 'rating', 'balance', 'balance_history',
                 'support', 'verify', 'whatsapp', 'changes', 'rules', 'profile', 'signup', 'login',
                 'name', 'phone', 'email', 'password', 'delete'));

-- Stops only the signed-in customer's own action (auth.uid() = the row's owner).
create or replace function public.ex_site_pause_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_was boolean;
begin
  if v_uid is null then return new; end if;
  if tg_table_name = 'ex_profiles' then
    v_owner := new.id;
    if new.full_name is not distinct from old.full_name and new.username is not distinct from old.username then
      return new;
    end if;
  elsif tg_table_name = 'ex_whatsapp_settings' then
    v_owner := new.user_id;
    -- only turning notifications on or off is stopped
    if tg_op = 'UPDATE' then
      if new.enabled is not distinct from old.enabled then return new; end if;
    else
      select s.enabled into v_was from public.ex_whatsapp_settings s where s.user_id = new.user_id;
      if found and v_was is not distinct from new.enabled then return new; end if;
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

drop trigger if exists trg_ex_0_pause_delete on public.ex_account_deletions;
create trigger trg_ex_0_pause_delete
  before insert on public.ex_account_deletions
  for each row execute function public.ex_site_pause_guard('delete');

drop trigger if exists trg_ex_0_pause_profile on public.ex_profiles;
create trigger trg_ex_0_pause_profile
  before update of full_name, username on public.ex_profiles
  for each row execute function public.ex_site_pause_guard('name');

drop trigger if exists trg_ex_0_pause_rating on public.ex_order_feedback;
create trigger trg_ex_0_pause_rating
  before insert on public.ex_order_feedback
  for each row execute function public.ex_site_pause_guard('rating');

drop trigger if exists trg_ex_0_pause_whatsapp on public.ex_whatsapp_settings;
create trigger trg_ex_0_pause_whatsapp
  before insert or update of enabled on public.ex_whatsapp_settings
  for each row execute function public.ex_site_pause_guard('whatsapp');

-- ── 2. banners ───────────────────────────────────────────────────
create table if not exists public.ex_banners (
  id             uuid primary key default gen_random_uuid(),
  kind           text not null check (kind in ('slide', 'popup')),
  image_path     text not null check (image_path ~ '^(slides|popups)/[0-9a-f-]{36}\.webp$'),
  image_w        integer not null check (image_w between 100 and 2000),
  image_h        integer not null check (image_h between 100 and 2000),
  action_type    text not null default 'none' check (action_type in ('none', 'section', 'url')),
  action_section text check (action_section is null or action_section ~ '^[a-z][a-z-]{1,30}$'),
  action_url     text check (action_url is null or (action_url ~ '^https://[^\s]+$' and char_length(action_url) <= 500)),
  places         text[] not null default '{}',
  is_active      boolean not null default true,
  sort_order     integer not null default 0,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  created_by     uuid references auth.users(id) on delete set null,
  updated_by     uuid references auth.users(id) on delete set null,
  constraint ex_banners_action_check check (
    (action_type = 'none'    and action_section is null and action_url is null) or
    (action_type = 'section' and action_section is not null and action_url is null) or
    (action_type = 'url'     and action_url is not null and action_section is null)),
  constraint ex_banners_places_check check (
    (kind = 'slide' and cardinality(places) = 0) or
    (kind = 'popup' and cardinality(places) between 1 and 20))
);
create index if not exists ex_banners_kind_order_idx on public.ex_banners (kind, sort_order, created_at);

create table if not exists public.ex_banner_seen (
  user_id   uuid not null references auth.users(id) on delete cascade,
  banner_id uuid not null references public.ex_banners(id) on delete cascade,
  seen_at   timestamptz not null default now(),
  primary key (user_id, banner_id)
);
create index if not exists ex_banner_seen_banner_idx on public.ex_banner_seen (banner_id);

alter table public.ex_banners enable row level security;
alter table public.ex_banner_seen enable row level security;
revoke all on public.ex_banners, public.ex_banner_seen from anon, authenticated;

-- What the signed-in app reads, once on opening: the slides, and the screen
-- banners this account has not seen yet. Short and without personal data.
create or replace function public.ex_my_banners()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'slides', coalesce((
      select jsonb_agg(jsonb_build_object('id', b.id, 'img', b.image_path, 'w', b.image_w, 'h', b.image_h,
                                          'action', b.action_type, 'section', b.action_section, 'url', b.action_url)
                       order by b.sort_order, b.created_at)
        from public.ex_banners b where b.kind = 'slide' and b.is_active), '[]'::jsonb),
    'popups', coalesce((
      select jsonb_agg(jsonb_build_object('id', b.id, 'img', b.image_path, 'w', b.image_w, 'h', b.image_h,
                                          'action', b.action_type, 'section', b.action_section, 'url', b.action_url,
                                          'places', to_jsonb(b.places))
                       order by b.sort_order, b.created_at)
        from public.ex_banners b
       where b.kind = 'popup' and b.is_active and auth.uid() is not null
         and not exists (select 1 from public.ex_banner_seen s where s.user_id = auth.uid() and s.banner_id = b.id)), '[]'::jsonb)
  );
$$;
revoke all on function public.ex_my_banners() from public, anon;
grant execute on function public.ex_my_banners() to authenticated, service_role;

-- The customer closed or opened a screen banner: it does not come back on any device.
create or replace function public.ex_banner_seen_mark(p_banner uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null or p_banner is null then return; end if;
  insert into public.ex_banner_seen (user_id, banner_id)
  select auth.uid(), b.id from public.ex_banners b where b.id = p_banner and b.kind = 'popup'
  on conflict do nothing;
end;
$$;
revoke all on function public.ex_banner_seen_mark(uuid) from public, anon;
grant execute on function public.ex_banner_seen_mark(uuid) to authenticated, service_role;

-- Public images, WebP only, at most 400 KB each (the panel makes them ~60–150 KB).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('banners', 'banners', true, 409600, array['image/webp'])
on conflict (id) do update
  set public = true, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;
