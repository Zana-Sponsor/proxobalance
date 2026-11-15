-- v54: banners and pause switches reach signed-in customers at once.
-- One tiny public row per topic; every change to ex_banners or
-- ex_site_controls raises its number, and Supabase Realtime sends that row
-- (key, version, changed_at — no content) to the open apps, which then read
-- the banners or the switches again. The banners and switches themselves
-- stay private.

create table if not exists public.ex_live_versions (
  key        text primary key check (key in ('banners', 'site_controls')),
  version    bigint not null default 0,
  changed_at timestamptz not null default now()
);
insert into public.ex_live_versions (key) values ('banners'), ('site_controls') on conflict (key) do nothing;

alter table public.ex_live_versions enable row level security;
revoke all on public.ex_live_versions from anon, authenticated;
grant select on public.ex_live_versions to authenticated;
drop policy if exists ex_live_versions_read on public.ex_live_versions;
create policy ex_live_versions_read on public.ex_live_versions for select to authenticated using (true);

create or replace function public.ex_live_bump()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.ex_live_versions set version = version + 1, changed_at = now() where key = tg_argv[0];
  return null;
end;
$$;
revoke all on function public.ex_live_bump() from public, anon, authenticated;

drop trigger if exists trg_ex_banners_live on public.ex_banners;
create trigger trg_ex_banners_live
  after insert or update or delete on public.ex_banners
  for each statement execute function public.ex_live_bump('banners');

drop trigger if exists trg_ex_site_controls_live on public.ex_site_controls;
create trigger trg_ex_site_controls_live
  after insert or update or delete on public.ex_site_controls
  for each statement execute function public.ex_live_bump('site_controls');

do $pub$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'ex_live_versions') then
    alter publication supabase_realtime add table public.ex_live_versions;
  end if;
end $pub$;
