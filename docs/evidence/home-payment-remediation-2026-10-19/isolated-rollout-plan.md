# Concrete remaining page-creation acceptance

This plan is prepared for review; it is not an executed deployment. It continues the existing runner and migrations, and does not use production customer rows as fixtures.

## Provisioning boundary

The smallest next resource action is an isolated development branch of the confirmed **Zana** project (`cojchkwssmasiejcgvbk`), requested name `proxo-ui-acceptance-20261020`, without copied customer data. Supabase requires the user's cost consent before creating a billable branch. Both the 19 October and 20 October provider-managed consent requests returned `Invalid or expired requestState` (`INVALID_ARGUMENT`); the fresh `list_branches` check after the second expiry returned `[]`. No cost approval or branch exists in this evidence. Do not repeat the expired flow automatically. The remaining user action is to complete fresh provider consent, or select the organization for an explicit current cost quote and then approve that quoted cost before creation. A separate already provisioned isolated project is also acceptable if supplied through protected configuration.

Use a separate Vercel staging project/host matching the existing runner's allowlist, such as `proxolink-staging-proxo.vercel.app`. Reusing PR 44's currently shared preview environment is insufficient: its returned variables target preview and production together. Do not replace those shared values with staging values. Keep deployment protection enabled; use an already approved scoped authenticated mechanism if the runner needs it.

## Concrete setup after resource authorization

1. Confirm the new branch/project reference differs from production and is healthy. Validate schema-only provisioning rather than assuming every main-project migration replayed successfully.
2. Confirm the existing legacy schema prerequisites. The recorded base migration history begins with an alteration of `pa_ads` and does not show the initial `proxolink_cards` or `pa_ads` creation. Successful replay and a complete base schema must therefore be observed, not assumed. If prerequisites are absent, obtain a schema-only baseline through supported administration; do not install the simplified CI fixture schema or copy customer rows. Apply the three existing additive migrations in order on the isolated target only:
   - `20261006220119_proxolink_v6_independent_pages.sql`
   - `20261008234009_proxolink_page_management_contract.sql`
   - `20261009131901_proxolink_tools_moderation.sql`
3. Verify migration reruns, required columns, RLS/ownership rules, the Storage namespace and advertisement dependency FK. Preserve the production-reference rejection in `assertIsolatedWrites()`.
4. Deploy the reviewed branch API to the separate staging host. The four prepared V6 template sources are already private files in `api/_lib/proxolink-templates/`, bundled by the server; `seed-proxolink-private.mjs` accepts only eight v1/v2 templates and is not the V6 setup command. Set server-only Supabase/service/signing settings to the isolated project and `PROXO_V6_WRITE_MODE=isolated`. Keep real customer notification destinations and production email delivery out of this fixture environment. Check inherited database hooks/Edge Function configuration before fixture creation.
5. Create two ordinary fictional test accounts through trusted isolated administration without sending invitations or customer email. Do not elevate their application roles. Store account credentials and signing/service values only in protected configuration; do not paste them into chat, logs, the APK or this report.
6. Supply the existing runner's eight `PROXO_STAGING_*` settings plus the optional scoped Vercel protection setting as documented in [the existing setup guide](../../PROXOLINK_V6_ISOLATED_STAGING_SETUP.md).

The exact configuration, read-only schema checks and runnable acceptance commands are prepared in [the isolated setup runbook](isolated-setup-runbook.md). These commands are not evidence that provisioning or acceptance has executed.

## Acceptance using the existing implementation

Run `node scripts/run-proxolink-staging.mjs` against the isolated host. It must pass all **12 page-type/style lifecycles** and **12 current Tools cases**, including owner upload, creation, publication failure/retry, stable distinct UUIDs, database persistence, authoritative list refresh, edit, public rendering, exact avatar bytes, provider destinations, cross-owner denial, idempotent replay, moderation restrictions and deletion.

Use only the three retained fictional pages for the documented trusted moderation and advertisement-FK setup, then run `node scripts/run-proxolink-staging.mjs --tools-transitions`. Confirm both persisted moderation decisions and the `409 ad_dependency` denial while preserving the referenced page.

Finally run the authenticated app with its API/Supabase configuration pointing to those same isolated resources. The new central `BackendConfig` validates the complete compile-time staging configuration for the foreground app, background notification initializer and ProxoLink API; defaults preserve the current production URL/public key. Explicit `PROXO_BACKEND_MODE=staging` requires `PROXO_SUPABASE_URL`, `PROXO_SUPABASE_ANON_KEY` and the allowlisted `PROXO_PUBLIC_BASE_URL`; changing only the staging API origin is rejected. Demonstrate initial page-list entry, the empty/create states, invalid input, successful image upload/submission, return to the owner list, refresh, force-close/reopen persistence, repeated taps, interrupted-request recovery, account switching and three external-browser return cycles. Capture actual screens and observed request counts. The passing mock/API/database suites do not substitute for these hosted app journeys.

## Production release is a later reviewed action

Only after the isolated gate passes should a production change be prepared with the exact commit, additive schema changes, legacy-customer compatibility, rollout/rollback sequence and proof that the default APK origin serves the matching contract. The current hard production guard can be revised only as part of that separately approved release. A preview promotion alone is not a complete resolution, and silently dropping new fields to call the legacy API is not an acceptable workaround.

At this checkpoint, the new branch request expired and the branch inventory remains empty; no successful branch creation, staging server, synthetic account, production schema change or production activation is claimed. The user-facing report must keep live page creation marked incomplete until this gate is actually executed.
