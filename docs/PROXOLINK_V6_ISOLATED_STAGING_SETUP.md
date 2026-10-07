# ProxoLink V6 isolated staging configuration

Status: BLOCKED. No isolated target exists in the currently connected inventories. Production Zana and the unrelated Exchange project are not staging substitutes.

Use a separate Supabase project and separate server deployment with two ordinary fictional test accounts. Provision the existing V5 schema/private-template prerequisites and the additive migration `proxo_app/supabase/migrations/20261006220119_proxolink_v6_independent_pages.sql` only on that isolated project. Preserve the existing private server renderer and four prepared keys. Set the server's `PROXO_V6_WRITE_MODE=isolated`; the production-reference rejection must remain.

The runner requires these staging-scoped settings:

| Setting | Meaning |
|---|---|
| PROXO_STAGING_PROJECT_REF | Separate staging Supabase project reference |
| PROXO_STAGING_SUPABASE_URL | URL for that same isolated project |
| PROXO_STAGING_BASE_URL | Server URL for that isolated deployment |
| PROXO_STAGING_ANON_KEY | Publishable/anon key for the isolated project |
| PROXO_STAGING_TEST_EMAIL | First ordinary fictional account |
| PROXO_STAGING_TEST_PASSWORD | Its protected credential |
| PROXO_STAGING_OTHER_EMAIL | Second ordinary fictional account for ownership checks |
| PROXO_STAGING_OTHER_PASSWORD | Its protected credential |
| PROXO_STAGING_VERCEL_BYPASS | Optional protection bypass scoped to that isolated deployment |

Server service-role and preview signing secrets belong only in the isolated server environment. Do not place them in Flutter, public artifacts or runner output. No secret values are included here.

Run the existing `node scripts/run-proxolink-staging.mjs` against those settings. It verifies the 12 combinations of 3 page types and 4 prepared designs, including database-generated PAGE UUIDs, distinct owner/request UUIDs, create/edit/preview/public rendering, stable URLs, other-owner denial, typed routes, retry and activate/deactivate behavior. It retains fictional staging fixtures for review. Do not run it against production or delete legacy customer data.

The previously executed missing-configuration invocation rejected before mutations with exit code 1. Current result is 0/12 BLOCKED. The disposable PostgreSQL/API checks and read-only native catalog previews are separate evidence and do not satisfy this hosted gate.

See [executed report](PROXOLINK_V6_EXECUTION_2026-10-07.md) for the precise current results and blockers.
