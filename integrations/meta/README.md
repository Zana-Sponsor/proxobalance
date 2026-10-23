# Proxo Meta background workflows

These three inactive exports poll the authenticated Proxo backend. The backend owns order validation, funding, database leases, Meta Graph v26.0 calls, stage persistence, reconciliation and wallet compensation. n8n never receives a mobile payment payload, performs a second charge or calls Meta directly. Campaigns, ad sets and ads are created paused; private tester access does not authorize paid activation.

**Repository verification is complete for the checks listed below. Target n8n import, credential binding and controlled end-to-end execution remain unverified.** No n8n instance was accessed or modified, and no live Meta object, payment or refund was created by these checks.

## Exports and route mapping

| File / prepared workflow name | Schedule | Authenticated backend route | Purpose | State |
|---|---|---|---|---|
| [proxo_meta_ads_create.json](proxo_meta_ads_create.json) — Proxo Meta — create paused ads | Every minute | `POST /api/meta-ads?op=worker-create` | Claim one eligible, funded order and construct its paused delivery chain | Inactive; not imported |
| [proxo_meta_ads_status_sync.json](proxo_meta_ads_status_sync.json) — Proxo Meta — status sync | Every five minutes | `POST /api/meta-ads?op=worker-status` | Observe recorded provider objects and synchronize actual review/delivery state | Inactive; not imported |
| [proxo_meta_ads_reconcile_refund.json](proxo_meta_ads_reconcile_refund.json) — Proxo Meta — reconcile and compensate | Every two minutes | `POST /api/meta-ads?op=worker-reconcile` | Reconcile unknown/partial outcomes, then compensate only when the backend establishes that doing so is safe | Inactive; not imported |

Reconciliation and compensation share a workflow because they are consecutive decisions in the same durable backend state machine. There is no independent n8n refund amount or customer identifier to trust. Wallet compensation uses the existing authenticated `POST /api/v1/wallet/refund` contract and the authoritative original debit. Unknown provider outcomes must be resolved before recreation or refund.

Every call sends `{}`. The backend claims eligible work instead of accepting a caller-selected order or price. No inbound n8n webhook or callback URL is required: polling the durable queue avoids losing dispatch when a checkout response or webhook is lost. App quote/submit requests continue to use `/api/meta-ads?op=quote` and `/api/meta-ads?op=submit`; mobile clients must not receive the worker credential.

Successful worker responses have the contract:

```json
{"ok":true,"processed":0,"status":"idle"}
```

`processed` is zero or one. The allowed status values are `idle`, `paused`, `observed`, `reconcile`, and `refunded`; an optional uppercase `error_code` is sanitized. A successful polling response is not evidence of ad approval or delivery.

## Configuration

| Location | Name | Required configuration |
|---|---|---|
| n8n Credentials | `Proxo Meta worker` / `httpHeaderAuth` | Header name `Authorization`; bearer authentication using the server's `META_WORKER_SECRET`. Enter the value only in the credential store. Rebind the name to the local credential ID after import. |
| n8n Variables | `PROXO_META_BACKEND_ORIGIN` | Public HTTPS origin of the deployed Proxo Node backend, without a path, query, credentials or trailing slash. This is not a Supabase origin. |
| Backend environment | `PROXO_SUPABASE_URL` | Intended Proxo Supabase project URL; do not fall back to an unrelated project. |
| Backend environment | `PROXO_SUPABASE_SERVICE_ROLE_KEY` | Proxo service credential, stored only on the backend. |
| Backend environment | `META_WORKER_SECRET` | Service authentication secret matching the n8n credential. |
| Backend environment | Name referenced by `app_meta.connections.access_token_env` | Effective Meta system-user token. Only the approved server connection selects this environment variable. |
| Backend environment | `META_APP_SECRET` | Optional server-side application secret for `appsecret_proof`, when configured for the Meta application. |
| Database | `app_meta.settings.enabled` and `app_meta.testers` | Default OFF and explicit private tester eligibility; the worker rechecks new creation eligibility when claiming work. |
| Database | `app_meta.settings.fastpay_enabled` | Default OFF. Requires verified compatibility of the existing FastPay workflow before use for Meta. |

Approved server connections require the actual ad account, Page, applicable linked Instagram account and WhatsApp business number, verification timestamps, and account-specific capability evidence. The executing system user must hold the required asset tasks. The [provider preflight](../../api/_lib/meta/provider.js) and [configuration contract](../../api/_lib/meta/contract.js) are the executable source of truth. An account-specific creative/optimization/destination tuple must be verified; merely connecting a token or pasting a post URL does not satisfy preflight. Connection records contain a secret reference, never the access token itself.

For an n8n installation without Variables, generate exports with a non-secret public origin:

```sh
node integrations/meta/build-workflows.mjs https://your-public-backend.example
```

The hostname above is illustrative and does not identify a configured backend. Use the actual reviewed origin. Running the generator without an argument restores the portable `$vars.PROXO_META_BACKEND_ORIGIN` exports. Neither form uses `$env`, embeds authentication values, or requires loosening n8n's environment-access controls.

The existing FastPay order-create route is `https://email.proxopages.com/webhook/fastpay/order-create`. Its Meta extension must bind `meta_quote_id` to the immutable transaction relationship through the accepted quote RPC input `ad: {platform: "META", quote_id, configuration}`. This integration does not create a new payment flow. Keep Meta FastPay disabled until that existing workflow's funding, callback, duplicate and compensation behavior is tested against the immutable quote. No live FastPay callback was tested here.

## Retry and failure behavior

The HTTP Request nodes allow at most three transport attempts, separated by five seconds, with a 60-second request timeout. Redirects are disabled so worker authentication cannot be forwarded to another host. HTTP responses are read as text with `neverError`, allowing the following node to classify even a non-JSON 401/403 without an automatic transport retry. HTTP 4xx/5xx failures stop that execution with a static error code; the next scheduled poll is a new queue claim, not a replay of a provider POST.

Durable provider-stage backoff, attempt limits, completed-stage reuse and uncertain-outcome reconciliation belong to the backend. The workflow has no retry loop and no alternate direct provider path. A lost HTTP response may have completed a worker action; lease/state reconciliation makes repeated polling safe. Temporary status failures cannot establish terminal ad failure. New-order gates must not prevent historical status, reconciliation or legitimate refunds.

Execution payload persistence is disabled for successful, failed, manual and in-progress executions. Pinned data is empty. The last Code node emits only the small worker summary; it never returns request headers, raw provider diagnostics, connection data or order contents. These exports contain credential references only and no secret values. Keep deployment, reverse-proxy and n8n logging redaction enabled as well.

## Import and controlled verification

1. Inspect the actual target n8n version and available nodes. Export a backup before replacing any existing Proxo workflow; these files do not modify the existing OTP or payment workflows.
2. Sign in through the protected credential form, or enter credentials directly on n8n's own login page. Do not send passwords in chat, source files or exports.
3. Import all three files, bind `Proxo Meta worker`, and configure the public backend origin. Verify the generated URLs, credential binding, schedule timezone and node versions. Keep every workflow inactive.
4. Use an isolated backend/database and an approved private Meta connection. Verify absent/invalid worker credentials are rejected before job claims; missing origin fails before HTTP. Use the manual trigger for controlled execution.
5. Exercise accepted funding, duplicate polls, withdrawn tester eligibility, loss of a provider response, saved partial IDs, review/status changes, polling errors, safe cleanup, lost refund responses and original-debit refund state. Confirm one original funding operation, no duplicate provider stages and no duplicate compensation. Verify all delivery objects remain paused.
6. Record the exact target version, imported workflow IDs, credential bindings and test evidence. Publish only after the intended environment and the owner's release rules permit it. Publishing these schedules does not authorize live ad activation.

No target version or authenticated n8n session was available in this implementation environment. Therefore imports, bindings, target node availability, schedule execution, Meta permissions/tuples, and real financial/provider end-to-end behavior have not been verified. Those are setup blockers, not successful tests.

## Repository verification and rollback

`node --test test/meta-workflows.test.js` passes five tests. They parse all three actual exports, verify connected finite routes and disabled execution storage, execute the exported configuration/result JavaScript and URL expressions, reject missing/local/credential-bearing origins, discard caller-selected order/payment data, check allowed summaries, and cover 401/403/429/503/422/redirect, malformed JSON, malformed success and transport failures. All transports are simulated; no external request is made by these tests.

Node names, versions and relevant parameter shapes were compared with published `n8n-nodes-base@2.15.1` source: Schedule Trigger 1.2, Manual Trigger 1, Code 2 and HTTP Request 4.2. This is source/schema inspection, not an n8n runtime import. **No n8n runtime version is claimed as validated.**

Rollback starts by disabling new Meta order eligibility and the create schedule. Keep authorized status/reconciliation processing available for already accepted work. Inspect durable order/provider state before compensation; do not delete original debits, partial provider IDs or idempotency records. Restore any previous workflow export only after backing up the configured replacement, and retain appropriate historical recovery. Removing these inactive exports alone does not reverse funded orders or provider objects.

Official references: [Schedule Trigger](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.scheduletrigger/), [HTTP Request](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.httprequest/), [HTTP credentials](https://docs.n8n.io/integrations/builtin/credentials/httprequest/), [HTTP retry handling](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.httprequest/common-issues/), and [n8n v2 environment-access change](https://github.com/n8n-io/n8n-docs/blob/main/docs/changelog/v20-breaking-changes.md).
