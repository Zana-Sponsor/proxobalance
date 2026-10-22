# Page creation readiness — rechecked 20 October 2026

The client recovery fixes are implemented. **Production page creation in the current independent-page APK is not enabled:** its API contract and required schema are not deployed to its configured server. This is a verified release/configuration mismatch, not evidence of a phone connectivity problem. No customer page, account, Storage object, migration or production setting was written for this audit.

## Actual cause

`ProxoLinkService` uses `https://www.proxobalance.app` by default. At 08:02 UTC on 20 October, after publishing the updated source, anonymous GETs returned:

| Path | Result | Meaning |
| --- | --- | --- |
| `/api/page-providers` | 404, JSON `The page could not be found` | Required provider/capability route is absent. |
| `/api/proxolink?op=providers` | 404, JSON `not_found` | The direct operation is absent too. |
| `/api/contact-templates` | 401, JSON `unauthorized` | Route exists and requires authentication; authenticated success was not tested. |

Authenticated Vercel metadata confirms the live domain still serves `main` commit `3c457e4ec1a326f33814d1cf5f19caa826e27fd0`. The newly published client/backend source `9fdd08d14f982e40221455cc4ab5dac0f3c368e3` is READY only as a Preview, deployment `dpl_4Tm55uKBwNWUUT1R6ky8xRcBWypQ`. Its anonymous provider request returned HTTP 401 with `Protected deployment`; no bypass was attempted. That response does not verify application authentication or page creation. The earlier preview's login HTML and HTTP 200 are retained as historical blocked evidence. [Deployment and HTTP evidence](vercel-readiness.md) · [Machine-readable audit](vercel-readiness.json).

The live source already has **template version 6**, four pill styles and three legacy page types. Calling this merely an old template version would be incorrect. Its create handler accepts `page_type` (`contact`, `food`, `download`) plus `platforms`; the request UUID is also the page UUID. The current APK sends `page_kind` (`contact`, `order`, `download`) plus `settings.providers`, expects a separately generated page UUID, typed public paths and moderation/management fields. The owner/avatar namespace and response/recovery contracts differ as well.

A metadata-only query at 07:23 UTC of `public.proxolink_cards` on the live Zana project confirms `page_type`, `platforms`, `client_request_id` and `creation_request_hash` exist, while required independent-page columns `page_kind`, `settings`, `archived_at` and `moderation_status` are absent. No customer records were read. A matching legacy client may still create successfully; this audit did not attempt authenticated production creation and does not claim every legacy flow is broken.

## Client fixes already included

- Ordinary Home/Tools entry opens the page list first. Creating a page requires the explicit action.
- Loading, the designed empty collection, retrieval error and creation-unavailable states remain distinct.
- Missing capability routes and explicit server refusal show an availability message and retry instead of a misleading invalid-JSON/offline error or unusable form.
- Retry reloads disabled provider metadata. Catalog loading is single-flight.
- A pending owner request is reconciled against the saved list before catalog loading; a saved page can be recovered without another submission.
- An uncertain submission retains its original payload and request ID. Known validation failures allow corrections; a late idempotency conflict recovers the matching owner/request page.
- Fields become read-only and the keyboard closes while the uncertain request is retained. Owner changes invalidate uploads and responses.
- Completion returns only through its originating current route, preventing a delayed response from dismissing another screen.
- A locally inserted page whose publication is still `creating` continues polling until ready. Success refreshes the authoritative owner list.

The published branch's `proxolink_creation_recovery_test.dart` covers 21 recovery/layout cases. The main CI at [source `5a6167e`](https://github.com/Zana-Sponsor/proxobalance/actions/runs/39279374548) passed; new UI changes receive another final combined check. The full Node suite was rerun on 20 October: **179 passed, 0 failed**, including the 23-case V6 API suite and isolated-staging orchestration tests. These are controlled fixture results, not hosted production writes or app persistence against a live isolated server.

## Why the remaining fix requires a coordinated rollout

`assertIsolatedWrites()` in `api/_lib/proxolink-pages.js` requires `PROXO_V6_WRITE_MODE=isolated`, an allowed server URL, and a Supabase project other than the production reference `cojchkwssmasiejcgvbk`. The gate protects create/edit/delete and upload capabilities. It is unchanged. Deploying only the APK, adding only a rewrite or removing only the client check cannot provide a working compatible server.

Discarding the new settings and silently sending a legacy payload would change the requested page, UUID/ownership expectations and moderation behavior. It is not a safe repair for this contract. The new client therefore exposes the actual unavailable state until a compatible tested API and schema are released.

The connected inventory still contains only production Zana and unrelated Exchange. The 19 October branch-provisioning request expired. A fresh 20 October request named `proxo-ui-acceptance-20261020` also returned `Invalid or expired requestState` (`INVALID_ARGUMENT`) from the provider-managed cost-consent flow; `list_branches` returned `[]` again after that result. No cost approval or branch creation was recorded, and the expired flow was not retried. The old setup guide's claim that Vercel was unavailable no longer applies: authenticated metadata reads now work. No isolated server/account pair has been supplied.

[The concrete isolated rollout plan](isolated-rollout-plan.md) identifies the remaining provision, migrations, protected settings and acceptance cases. Existing [release instructions](../../PROXOLINK_V5_EXECUTION_2026-10-05.md) keep customer migration, main merge and ProxoLink production activation behind a separate reviewed release. The current audit neither bypasses that gate nor claims the live creation problem is fully resolved.

The prepared source now also includes a central guarded `BackendConfig` for foreground Supabase, background Supabase and the page API origin. Production defaults and the existing public anon key remain identical. An explicit staging build requires all isolated settings together and rejects a production project, missing inputs, service/foreign-project JWT keys or an incompatible API origin before initialization. Validated URLs normalize to their origins before SDK path concatenation. Fourteen dedicated configuration cases cover these boundaries. The staging build disables production OTP/email-change delivery, FastPay creation/polling and Firebase initialization/token/topic traffic; signup is blocked before creating an identity. Counting HTTP fixtures cover these delivery boundaries, and a dedicated compile-time staging case exercises background/foreground push helpers without Firebase initialization. Staging page acceptance uses an injected ordinary synthetic session. Hosted provisioning and authenticated app execution remain separate gates. [Exact configuration runbook](isolated-setup-runbook.md).

Email authentication remains on the owner's configured `https://email.proxopages.com/webhook/send_otp` API; no email provider or SMTP change is part of this work.
