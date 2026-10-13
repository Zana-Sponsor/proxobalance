# ProxoLink V6 isolated staging configuration

Status: BLOCKED. No isolated target exists in the currently connected inventories. Production Zana and the unrelated Exchange project are not staging substitutes.

Use a separate Supabase project and separate server deployment with two ordinary fictional test accounts. Provision the existing V5 schema/private-template prerequisites and the three ordered additive migrations `20261006220119_proxolink_v6_independent_pages.sql`, `20261008234009_proxolink_page_management_contract.sql` and `20261009131901_proxolink_tools_moderation.sql` only on that isolated project. Preserve the existing private server renderer and four prepared keys. Set the server's `PROXO_V6_WRITE_MODE=isolated`; the production-reference rejection must remain.

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

The previously executed missing-configuration invocation rejected before mutations with exit code 1. Current hosted result is 0/12 compatibility and 0/12 current Tools cases, BLOCKED before credentials or mutations. Mocked orchestration is separate passing evidence. The disposable PostgreSQL/API checks and read-only native catalog previews are separate evidence and do not satisfy this hosted gate.

See [executed report](PROXOLINK_V6_EXECUTION_2026-10-07.md) for the precise current results and blockers.

## Current Tools/Create hosted acceptance

The same runner now adds twelve current Tools API cases after the twelve existing compatibility lifecycles. It uploads as the ordinary owner before authenticated create, checks the database-generated page UUID and stored pending default, rejects client and direct-REST moderation decisions, verifies authoritative refresh, and loads actual public HTML and exact avatar bytes from the newly created page. It checks all four restaurant label/key mappings and destinations, foreign API/RLS reads, foreign uploads/deletes, two authenticated owner scopes, idempotency and nine actual owner deletions. HTTP session changes are labeled API evidence, not app account-switch UI evidence.

Three fictional pages are retained in `build/proxolink-staging-verification/tools-results.json`, each with a generated page UUID and explicit expected action. An authorized staging administrator must use ONLY the confirmed isolated project to set the first pending page to approved, the second to rejected, and create an actual isolated advertisement referencing the third via the existing ad schema/RESTRICT FK. Derive the owner from the retained page; keep its owner intact. Use existing trusted service-role/database administration, not a new RPC, customer role, UI or public transition endpoint. Do not copy production rows or remove any FK. Ordinary accounts stay ordinary.

Then run `node scripts/run-proxolink-staging.mjs --tools-transitions`. This read/deny phase observes both persisted decisions through the ordinary account and verifies that deleting the third page returns `409 ad_dependency` while preserving its row. It does not perform any trusted setup mutation. Missing decisions or an absent real ad cause failure. Neither phase claims native/browser verification.

Use one retained page's actual public path for three external-browser return cycles from the authenticated app. Capture the real test page, actual external browser package/lifecycle, retained Tools route/list/scroll and unchanged collection-read count. Independently run authenticated app create/image selection/upload/refresh/delete, account switching, refresh motion and error lifecycle. API fixture success is not hosted app evidence. Keep sessions, bypass values and server secrets out of artifacts.

Current provisioning blockers: the Supabase `get_cost` capability returned UNAVAILABLE (tool not returned by server tools/list), so its required cost confirmation/project creation cannot proceed; no isolated project is connected. Vercel lists only the existing `proxobalance` project; deployment inventory for its explicit team/project returns 403 forbidden and no authenticated CLI fallback is available. Resolve provider access/provisioning or supply an already provisioned isolated project, preview deployment and two ordinary accounts through protected configuration. Production is never a substitute.
