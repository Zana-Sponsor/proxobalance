-- Additive, disabled by default. Enabling a release requires a genuinely
-- published and verified artifact. This migration never raises a minimum.
create table if not exists public.app_release_policies (
  platform text not null check (platform in ('android', 'ios')),
  channel text not null default 'stable' check (channel in ('stable', 'beta')),
  latest_build integer not null check (latest_build > 0),
  latest_version text not null check (length(latest_version) between 1 and 40),
  minimum_build integer not null default 0 check (minimum_build >= 0),
  update_url text,
  message text not null default '' check (length(message) <= 600),
  revision integer not null default 1 check (revision > 0),
  enabled boolean not null default false,
  required_enabled boolean not null default false,
  release_verified boolean not null default false,
  published_at timestamptz,
  primary key (platform, channel),
  check (minimum_build <= latest_build),
  check (not required_enabled or (enabled and release_verified and minimum_build > 0)),
  check (not enabled or (release_verified and published_at is not null and
    update_url ~ '^https://(play\.google\.com/store/apps/details\?id=com\.proxo\.proxoapp(&|$)|([w]{3}\.)?proxobalance\.app/downloads/)'))
);
alter table public.app_release_policies enable row level security;
revoke all on public.app_release_policies from anon, authenticated;
grant all on public.app_release_policies to service_role;

create or replace function public.proxo_app_update_policy(p_platform text, p_channel text default 'stable')
returns jsonb language sql stable security definer set search_path = public, pg_temp as $$
  select to_jsonb(policy)
  from public.app_release_policies as policy
  where policy.platform = p_platform and policy.channel = p_channel
    and policy.enabled and policy.release_verified
    and policy.published_at <= now()
  limit 1;
$$;
revoke all on function public.proxo_app_update_policy(text, text) from public;
grant execute on function public.proxo_app_update_policy(text, text) to anon, authenticated;
comment on table public.app_release_policies is
  'Public release metadata. Only the trusted release operator may enable a verified, downloadable build. Client/anon writes are prohibited. No policy rows are enabled by this migration.';
