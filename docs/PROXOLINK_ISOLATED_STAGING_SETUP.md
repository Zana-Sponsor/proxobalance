# Isolated ProxoLink lifecycle verification

The prepared runner is `node scripts/run-proxolink-staging.mjs`. It refuses the production Proxo Supabase reference, production domains and the current feature Preview. It requires a separate Supabase project and a separate Vercel project named `proxolink-staging` (or `proxolink-staging-<suffix>`). No new staging service has been created, billed or configured by this pass. No production customer fixture is permitted.

## Provider setup

1. Choose or create an isolated Supabase project in your intended organization. Use the provider's cost review before creating a paid project or branch. Use synthetic data only; do not copy production Auth users, cards, advertisements or customer images. Record its project reference privately in the testing configuration.
2. Apply the reviewed ProxoLink schema/migrations in that isolated project, including owner RLS, private templates, asset-folder ownership, updated timestamps and service-only publication/analytics tables. Do not run `proxolink_verified_cutover.sql` against production. Confirm the local migration filenames and live migration registry are reconciled before applying anything; the previous report lists their different historical timestamps.
3. Set up a separate Vercel project named `proxolink-staging`, linked only to the reviewed feature branch at the repository root. Use Preview/isolated deployment targets. Retain deployment protection. In that project's protected Environment Variables, configure `PROXO_SUPABASE_URL`, `PROXO_SUPABASE_SERVICE_ROLE_KEY`, `PROXO_PUBLIC_BASE_URL`, `PROXO_PREVIEW_SIGNING_SECRET` and `PROXO_ANALYTICS_HASH_SECRET` with this staging project's values. Do not reuse the production or Exchange server credentials. There is no ProxoLink Telegram setting.
4. Privately seed the reviewed v2 objects using `seed-proxolink-private.mjs` with **staging** server configuration. Verify all eight downloaded hashes. Activate and show v2 only in the isolated staging metadata. Keep production v1 objects, catalog flags, customer pins and legacy fields untouched. Never commit the private sources or upload them as CI artifacts.
5. Create one ordinary, non-admin fixture account in **staging Auth**. Store its password directly in the runner's protected environment. If a dedicated Vercel automation bypass is needed, create it in the isolated staging project, keep protection enabled and revoke it after testing.

## Runner settings

Enter these in a protected terminal environment or a dedicated reviewed GitHub environment named `proxolink-staging-verification`. If using GitHub, restrict its branch rule to `feat/proxolink-private-renderer-migration`, require an appropriate reviewer and disable administrator bypass. The current repository does not automatically dispatch this staging runner; invoke it only after the isolated deployment is configured and reviewed.

| Exact setting | Type | Purpose |
| --- | --- | --- |
| `PROXO_STAGING_PROJECT_REF` | Variable | The isolated project's 20-letter reference; production reference is refused |
| `PROXO_STAGING_SUPABASE_URL` | Variable | Exact `https://<isolated-reference>.supabase.co` origin |
| `PROXO_STAGING_BASE_URL` | Variable | The isolated `https://proxolink-staging[-suffix].vercel.app` origin, with no path/query |
| `PROXO_STAGING_ANON_KEY` | Variable | Publishable or legacy anon key from this staging project; secret/service-role keys are refused |
| `PROXO_STAGING_TEST_EMAIL` | Secret | The staging fixture account's email |
| `PROXO_STAGING_TEST_PASSWORD` | Secret | Its password |
| `PROXO_STAGING_VERCEL_BYPASS` | Optional secret | Temporary automation capability for the isolated staging project |

Install locked dependencies with `npm ci`, then run `node scripts/run-proxolink-staging.mjs`. Secret values are not CLI arguments, output, source, manifests or artifacts. Requests reject redirects; the bypass is sent only to the staging Vercel origin and never to Supabase.

## Proof and limits

For each of the eight v2 styles, the runner exercises real HTTP application APIs: create with a not-yet-uploaded avatar, genuine recoverable publish failure, duplicate idempotent request, binary avatar upload, same-UUID retry and working public page, matching public avatar bytes, same-URL name/bio/template/theme/language/contact/avatar edit, invalid edit preserving published values, deactivate/public denial, signed owner preview while inactive and same-link reactivation. It retains only its eight new fictional fixtures for review; it does not delete data, alter template metadata or generate advertisements.

Safe results go to `build/proxolink-staging-verification/results.json` and contain test booleans and the new fixture UUIDs. The file is written only after all eight cases pass. A configuration/partial failure is not a staging pass; inspect the isolated provider dashboard for partial fictional fixtures before a deliberate retry.

The runner's orchestration was tested through the actual application handlers with controlled provider fixtures. **That is a unit/integration fixture test, not a completed live Supabase staging run.** Native visual rendering, OS Copy/Share, real external-app handoffs, exact two-ad live analytics and iOS remain separate checks. The Android runner compares the deployed v1 catalog until an explicitly reviewed isolated-native configuration is added; do not point its production-project read-only credentials at staging or claim it certifies prepared v2.

After review, remove only named fictional staging fixtures through the ordinary owner flow if desired, revoke temporary bypass/password settings and retain a safe test report. Production cutover, legacy deletion, credential rotation affecting existing consumers, merge and production promotion remain separate gates.
