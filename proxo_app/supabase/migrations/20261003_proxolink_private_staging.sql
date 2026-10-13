-- ProxoLink phase 1: additive-only staging migration.
-- Do not apply until the eight original templates and a secure database backup
-- are available, and the matching renderer/API has passed preview tests.
-- Legacy columns and cards are deliberately preserved.

create table if not exists public.proxolink_templates (
  id uuid primary key default gen_random_uuid(),
  template_key text not null,
  version integer not null check (version > 0),
  display_name_ckb text not null,
  display_name_en text,
  storage_path text not null,
  checksum_sha256 text,
  requires_avatar boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (template_key, version)
);
alter table public.proxolink_templates enable row level security;
-- No client RLS policies: service-role access only. Expose a separate
-- non-sensitive catalog RPC if needed.

alter table public.proxolink_cards
  add column if not exists template_key text,
  add column if not exists template_version integer not null default 1,
  add column if not exists avatar_path text,
  add column if not exists card_language text not null default 'ku',
  add column if not exists publish_status text not null default 'creating',
  add column if not exists last_publish_error_code text,
  add column if not exists last_publish_error_at timestamptz,
  add column if not exists published_at timestamptz,
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists client_request_id uuid;

create unique index if not exists proxolink_cards_owner_request_unique
  on public.proxolink_cards(user_id, client_request_id)
  where client_request_id is not null;

create table if not exists public.proxolink_publish_attempts (
  id uuid primary key default gen_random_uuid(),
  card_id uuid not null references public.proxolink_cards(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  operation text not null check (operation in ('create','retry','activate','edit_publish')),
  result text not null check (result in ('started','success','failed')),
  error_code text,
  created_at timestamptz not null default now()
);
create index if not exists proxolink_publish_attempts_card_date_idx
  on public.proxolink_publish_attempts(card_id, created_at desc);
alter table public.proxolink_publish_attempts enable row level security;
create policy "Owner reads own ProxoLink publish history"
  on public.proxolink_publish_attempts for select to authenticated
  using (auth.uid() = user_id);
-- Client insert/update/delete is intentionally not permitted.

create table if not exists public.pa_ad_contact_links (
  id uuid primary key default gen_random_uuid(),
  ad_id uuid not null references public.pa_ads(id) on delete restrict,
  card_id uuid not null references public.proxolink_cards(id) on delete restrict,
  owner_user_id uuid not null references auth.users(id) on delete cascade,
  public_token text not null unique,
  version integer not null default 1 check (version > 0),
  is_current boolean not null default true,
  status text not null default 'active'
    check (status in ('active','inactive')),
  created_at timestamptz not null default now(),
  deactivated_at timestamptz
);
create unique index if not exists pa_ad_contact_links_current_ad_idx
  on public.pa_ad_contact_links(ad_id) where is_current;
create index if not exists pa_ad_contact_links_card_date_idx
  on public.pa_ad_contact_links(card_id, created_at desc);
alter table public.pa_ad_contact_links enable row level security;
create policy "Owner reads own ad contact links"
  on public.pa_ad_contact_links for select to authenticated
  using (auth.uid() = owner_user_id);
-- Only trusted backend creates/changes tokens.

create table if not exists public.pa_contact_events (
  id uuid primary key default gen_random_uuid(),
  ad_contact_link_id uuid not null
    references public.pa_ad_contact_links(id) on delete restrict,
  event_type text not null check (event_type in ('page_view','button_click')),
  button_type text check (
    button_type is null or button_type in
    ('whatsapp','viber','telegram','instagram','phone','email','website','tiktok')
  ),
  session_id uuid,
  visitor_hash text,
  ip_address inet,
  ip_hash text,
  user_agent text,
  device_type text,
  browser text,
  os text,
  referrer text,
  request_path text,
  created_at timestamptz not null default now(),
  constraint pa_contact_event_type_consistent check (
    (event_type = 'page_view' and button_type is null)
    or (event_type = 'button_click' and button_type is not null)
  )
);
create index if not exists pa_contact_events_link_date_idx
  on public.pa_contact_events(ad_contact_link_id, created_at desc);
create index if not exists pa_contact_events_link_kind_date_idx
  on public.pa_contact_events(
    ad_contact_link_id, event_type, button_type, created_at desc
  );
alter table public.pa_contact_events enable row level security;
-- No client read/write on raw visitor-level events. Aggregate server-side.

-- Create through approved Supabase Storage API / dashboard if SQL permissions
-- do not permit bucket registration. Do not upload any HTML to a public bucket.
insert into storage.buckets (id, name, public)
values ('proxolink-templates', 'proxolink-templates', false)
on conflict (id) do nothing;
insert into storage.buckets (id, name, public, allowed_mime_types)
values (
  'proxolink-assets', 'proxolink-assets', true,
  array['image/jpeg','image/png','image/webp']
)
on conflict (id) do nothing;

-- Template objects are service-role-only. No anonymous/authenticated policies
-- are created for the private template bucket.
-- Profile images are intentionally public READ assets, but owner-only WRITE.
create policy "ProxoLink asset owner insert" on storage.objects
  for insert to authenticated
  with check (
    bucket_id='proxolink-assets'
    and (storage.foldername(name))[1]=auth.uid()::text
  );
create policy "ProxoLink asset owner update" on storage.objects
  for update to authenticated
  using (
    bucket_id='proxolink-assets'
    and (storage.foldername(name))[1]=auth.uid()::text
  )
  with check (
    bucket_id='proxolink-assets'
    and (storage.foldername(name))[1]=auth.uid()::text
  );
create policy "ProxoLink asset owner delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id='proxolink-assets'
    and (storage.foldername(name))[1]=auth.uid()::text
  );

-- Never backfill publish_status='ready' until each migrated row has been
-- tested by the private renderer. Do not delete legacy HTML or Base64 here.
