# Prepared isolated setup commands — 20 October 2026

This is a prepared runbook, not an execution report. The provider request for `proxo-ui-acceptance-20261020` expired with `Invalid or expired requestState` (`INVALID_ARGUMENT`); the subsequent branch inventory is empty. No cost approval or branch is assumed. Do not retry the expired consent flow automatically. Do not run mutations until a successfully provisioned target's returned project reference and healthy state are verified and the coordinator confirms the isolated target. Never use `cojchkwssmasiejcgvbk` or the unrelated Exchange project. No production activation is included.

## Check the provisioned target

Use the Supabase connector with the new branch's returned `project_ref`, not its parent reference, for `list_migrations`, `list_tables` and these metadata-only `execute_sql` checks:

```sql
select table_schema, table_name
from information_schema.tables
where (table_schema = 'public' and table_name in
  ('profiles', 'proxolink_cards', 'proxolink_publish_attempts',
   'proxolink_templates', 'pa_ads', 'pa_ad_contact_links'))
   or (table_schema = 'storage' and table_name in ('buckets', 'objects'))
order by table_schema, table_name;

select column_name, data_type, is_nullable, column_default
from information_schema.columns
where table_schema = 'public' and table_name = 'proxolink_cards'
order by ordinal_position;

select conname, pg_get_constraintdef(oid) as definition
from pg_constraint
where conrelid in ('public.proxolink_cards'::regclass,
                  'public.pa_ads'::regclass,
                  'public.pa_ad_contact_links'::regclass)
order by conrelid, conname;

select schemaname, tablename, policyname, roles, cmd, qual, with_check
from pg_policies
where (schemaname = 'public' and tablename in
  ('proxolink_cards', 'proxolink_publish_attempts', 'proxolink_templates'))
   or (schemaname = 'storage' and tablename = 'objects')
order by schemaname, tablename, policyname;

select id, public, allowed_mime_types
from storage.buckets
where id in ('proxolink-assets', 'proxolink-templates');
```

Do not execute the `regclass` query until the required relations exist. Branching does not copy application or Storage data. Its migration replay may not reconstruct objects originally created outside tracked migrations. The production migration inventory starts with `add_prev_spend_impressions_to_pa_ads`, not a base schema creation. If any prerequisite table, owner policy, request uniqueness constraint, publication dependency, or avatar Storage configuration is missing, stop and prepare a schema-only baseline through supported administration. `test/fixtures/proxolink-v5-database.sql` is a deliberately simplified local fixture and must not be used as that hosted baseline.

Review inherited database triggers/hooks and Edge Function configuration before creating test users or advertisements. Retain ownership/security triggers; ensure fixture mutations cannot send customer email, Telegram messages, or production webhooks. Do not place hook URLs or tokens in evidence. Auth provider placeholders on a new branch do not establish that every application trigger is inert.

## Apply only the reviewed additive migrations

Read each complete file from the current checkout and pass its exact contents to `apply_migration` with the verified isolated `project_id`, in this order:

| Migration name | Repository file |
| --- | --- |
| `proxolink_v6_independent_pages` | `proxo_app/supabase/migrations/20261006220119_proxolink_v6_independent_pages.sql` |
| `proxolink_page_management_contract` | `proxo_app/supabase/migrations/20261008234009_proxolink_page_management_contract.sql` |
| `proxolink_tools_moderation` | `proxo_app/supabase/migrations/20261009131901_proxolink_tools_moderation.sql` |

Then repeat the metadata checks and verify `page_kind`, `settings`, `archived_at`, `moderation_status`, `proxolink_v6_management_guard`, `proxolink_v6_identity_immutable`, the moderation guard, request uniqueness, owner RLS and the advertisement foreign-key restrictions. Preserve existing identifiers and policies. Do not replay unrelated production migrations blindly. Existing CI tests separately cover migration rollback and reruns.

The V6 templates are server-bundled files `pill.html`, `pill-mint.html`, `pill-dark.html`, and `pill-white.html` under `api/_lib/proxolink-templates/`. Their loader verifies checksums and uses the private function bundle. There is no V6 upload step using `seed-proxolink-private.mjs`; that historical script explicitly accepts only eight v1/v2 templates. No source HTML belongs in Flutter or public output.

## Separate server configuration

Create/use a separate Vercel project with a hostname matching the existing runner's strict allowlist: `https://proxolink-staging[-suffix].vercel.app`. Deploy the reviewed branch/commit using its existing `vercel.json`, build command `npm run build`, output `public` and Node 24. Verify the actual returned hostname before use. Record project/deployment/commit identifiers, not secret values. Do not edit the shared `proxobalance` production/preview variables.

| Server setting | Value source |
| --- | --- |
| `PROXO_SUPABASE_URL` | New isolated project URL |
| `PROXO_SUPABASE_SERVICE_ROLE_KEY` | Supported secure retrieval of that isolated project's server credential |
| `PROXO_V6_WRITE_MODE` | Literal `isolated` |
| `PROXO_PUBLIC_BASE_URL` | Confirmed isolated server origin |
| `PROXO_PREVIEW_SIGNING_SECRET` | Newly generated isolated signing value, at least 32 characters |
| `PROXO_ANALYTICS_HASH_SECRET` | Newly generated isolated hash value |

The visible Supabase connector currently exposes `get_publishable_keys`, not a service-key retrieval operation. Check the provisioning result and supported secret-management capability; if no isolated server credential is supplied, server setup remains blocked. Do not copy a production credential, derive privileged credentials from database settings, or substitute an anonymous key. Keep signing/service values server-only. Leave customer notification credentials and TikTok tracking identifiers unconfigured in the separate test server. Preserve deployment protection; only a scoped approved test mechanism may satisfy the runner's optional protection header.

Use trusted isolated Auth administration to create two ordinary synthetic accounts with confirmed test emails and no invitation/email delivery. Confirm normal ownership/profile setup and no administrative application role. The account password step serves the existing isolated verifier and does not change the app's custom email OTP provider.

## Existing executable acceptance

Load these exact setting names through protected runtime configuration: `PROXO_STAGING_PROJECT_REF`, `PROXO_STAGING_SUPABASE_URL`, `PROXO_STAGING_BASE_URL`, `PROXO_STAGING_ANON_KEY`, `PROXO_STAGING_TEST_EMAIL`, `PROXO_STAGING_TEST_PASSWORD`, `PROXO_STAGING_OTHER_EMAIL`, `PROXO_STAGING_OTHER_PASSWORD`, and optionally `PROXO_STAGING_VERCEL_BYPASS`. The anon/publishable key must belong to the new project and be enabled. Do not print the environment or include a secret file in a command transcript, commit, screenshot or artifact.

Run from the repository root, with the protected settings already injected:

```sh
node scripts/proxolink-protected-configuration.mjs
node scripts/run-proxolink-staging.mjs
```

The first command records only configured/missing setting names and validation status. The second must produce passing `results.json` and `tools-results.json` under `build/proxolink-staging-verification/`: twelve lifecycle cases and twelve current Tools cases. It rejects the production reference, unapproved server origins, service keys in client settings and redirects. Read the reports rather than inferring success from process start.

The second report retains three exact fictional page IDs and required trusted fixture actions. In the confirmed isolated project only, approve the first pending page, reject the second and create an actual advertisement using the existing schema/FK for the third. Read required columns/defaults/constraints first and derive the owner from that retained page; do not guess identifiers, grant customer moderation powers, or delete constraints. Then run:

```sh
node scripts/run-proxolink-staging.mjs --tools-transitions
```

Require persisted decisions, a `409 ad_dependency` response and preservation of the referenced row. Keep the three fictional fixtures for review. No automatic cleanup or production mutation is part of this runbook.

Finally configure the actual app to the same isolated API/Supabase project and perform create, avatar upload, owner-list refresh, force-close/reopen, uncertain-request recovery, account switching and external-browser return journeys. The new `lib/config/backend_config.dart` is shared by `main.dart`, the background notification initializer and `ProxoLinkService`. Defaults preserve the production configuration; the staging variant requires all of these compile-time settings together:

| App setting | Isolated value |
| --- | --- |
| `PROXO_BACKEND_MODE` | `staging` |
| `PROXO_SUPABASE_URL` | Same isolated project URL as the server/runner |
| `PROXO_SUPABASE_ANON_KEY` | Enabled publishable/anon key for that project, never the service key |
| `PROXO_PUBLIC_BASE_URL` | Same allowlisted staging API origin as the runner |

Invalid mode, missing settings, production Supabase, unrelated API hosts, credential/path/port tricks and server keys are rejected before foreground or background network initialization. A legacy JWT must have `role=anon` and the same project reference; a modern publishable key's project association is finally verified by hosted Auth, not guessed from its opaque value. The historical protected read-only preview override remains available with production configuration; it is not staging or hosted write acceptance.

Build the staging app using only these public routing/publishable values, supplied from a dedicated noncommitted build configuration. Account passwords, sessions and protection bypass values belong in the trusted test harness's protected runtime, never compile-time settings. Use the ordinary synthetic account's verified injected session for page journeys. The custom production email OTP endpoint is unchanged; the staging guard blocks its login/signup/recovery/WhatsApp sends and Profile email changes before HTTP. It also prevents signup identity creation, FastPay order creation/ad checkout/polling, Firebase initialization and token/topic operations. These unsupported production delivery services are deliberately unavailable in the isolated page acceptance build; no replacement email or payment provider is added.

`test/backend_config_test.dart` contains fourteen configuration cases. `test/staging_transport_test.dart` contains five counting/pre-request guard cases and one foreground/background push case that requires the complete staging compile-time settings above; default production test runs explicitly skip that staging-only case. `test/profile_polish_test.dart` includes a changed-email staging regression with zero mock HTTP requests and no OTP dialog. These tests verify local call boundaries, not successful hosted credentials or a live page write. Retain real screenshots, observed requests and persistence evidence. The 179 passing local Node tests and prior disposable PostgreSQL CI do not prove this hosted/native gate.
