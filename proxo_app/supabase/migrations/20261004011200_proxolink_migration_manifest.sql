-- Operator-only checkpoint. It contains structured customer data, never
-- reusable template HTML, and is excluded from all client API schemas/grants.
create table proxolink_private.card_migration_manifest_20261004(
  card_id uuid primary key,
  user_id uuid not null,
  expected_legacy_html_md5 text not null,
  expected_avatar_md5 text not null,
  expected_fields jsonb not null,
  recovered_fields jsonb not null,
  verified_avatar_sha256 text,
  verified_at timestamptz not null default now()
);
alter table proxolink_private.card_migration_manifest_20261004 enable row level security;
revoke all on proxolink_private.card_migration_manifest_20261004 from public,anon,authenticated;
grant all on proxolink_private.card_migration_manifest_20261004 to service_role;
