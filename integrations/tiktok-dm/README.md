# Proxo TikTok Direct Message workflows

The six v15 workflow exports poll the authenticated Proxo backend. The backend owns authenticated user requests, identity verification, authoritative quotes and funding, durable job leases, TikTok requests, status normalization and ledger refunds. n8n sends no user-selected identity, spend, price, order ID or refund amount. The only ad-creation workflow is `proxo_tiktok_conversation_fulfill.json`, and its backend worker must claim only `tiktok_conversation_auto` work. Other TikTok objectives remain in the existing manual flow.

All exports are **inactive**. No target n8n instance was accessed or changed, no workflow was imported remotely, and no TikTok account, advertisement, payment or refund was changed during repository checks. Node/code verification below does not establish a configured provider integration.

## Six exports and backend mapping

Every HTTP operation below is `POST /api/tiktok-dm?op=<operation>` with body `{}` and dedicated worker authentication. The schedules use `Asia/Baghdad`. Each workflow also has a manual trigger for isolated controlled verification.

| Export / prepared workflow | Schedule | Backend operation | Responsibility | State |
|---|---|---|---|---|
| [proxo_tiktok_account_connect.json](proxo_tiktok_account_connect.json) — Proxo TikTok — account connection | Every two minutes | `worker-account-connect` | Process persisted, user-bound authorization requests only when supported correlation can be established | Inactive; not imported |
| [proxo_tiktok_account_videos.json](proxo_tiktok_account_videos.json) — Proxo TikTok — account videos | Every 15 minutes | `worker-account-videos` | Refresh due server-owned verified identity video caches through read-only provider operations | Inactive; not imported |
| [proxo_tiktok_account_disconnect.json](proxo_tiktok_account_disconnect.json) — Proxo TikTok — account disconnection | Every minute | `worker-account-disconnect` | Claim persisted owner-authorized requests, reconcile advertiser unlink, preserve audit/history | Inactive; not imported |
| [proxo_tiktok_conversation_fulfill.json](proxo_tiktok_conversation_fulfill.json) — Proxo TikTok — Conversation fulfillment | Every minute | `worker-create` | Revalidate and fulfill only funded Conversation jobs, persisting partial IDs and keeping objects paused | Inactive; not imported |
| [proxo_tiktok_conversation_spend_guard.json](proxo_tiktok_conversation_spend_guard.json) — Proxo TikTok — Conversation spend guard | Every minute | `worker-budget` | Observe authoritative spend and enforce the persisted 95% early-stop policy without reactivation or extra customer charges | Inactive; not imported |
| [proxo_tiktok_status_metrics_sync.json](proxo_tiktok_status_metrics_sync.json) — Proxo TikTok — status, metrics and final reconciliation | Every two minutes | `worker-status` → `worker-reconcile` → `worker-refund` | Synchronize status/metrics, reconcile uncertain outcomes, then process only eligible final-spend refunds | Inactive; not imported |

The final workflow combines status, reconciliation and compensation to retain the requested six-file set. Each stage invokes a separate authenticated backend operation and checks its response before continuing. Each backend operation independently claims eligible durable work; the flow never passes a previous order, provider response or amount into the next operation. A transient execution error stops the remaining steps for that poll and does not authorize a refund.

These are background workers. User-facing connection start/status, account list, paginated video and disconnect endpoints remain separately protected by the user's authenticated session and ownership checks. A disconnect worker must load a persisted request that follows the user's confirmation. Scheduled execution itself is not a new disconnect authorization. There is no public n8n webhook and no mobile worker secret.

## Required configuration

| Location | Name / type | Configuration |
|---|---|---|
| n8n Credentials | `Proxo TikTok DM worker` / `httpHeaderAuth` | Header name `Authorization`; bearer authentication using the server's `TIKTOK_DM_WORKER_SECRET`. Enter the value only in the credential store and bind the imported reference to the local credential ID. |
| n8n Variables | `PROXO_TIKTOK_DM_BACKEND_ORIGIN` | Public HTTPS origin of the Proxo Node backend, with no path, credentials, query or trailing slash. This is not a Supabase origin. |
| Backend environment | `TIKTOK_DM_WORKER_SECRET` | Service credential matching the n8n Header Auth credential. |
| Backend environment | `PROXO_SUPABASE_URL` | Intended existing Proxo Supabase project. |
| Backend environment | `PROXO_SUPABASE_SERVICE_ROLE_KEY` | Proxo server credential; never put it in Flutter or these exports. |
| Backend protected configuration | Verified TikTok connection, token reference, BC and advertiser | Effective token/app grants, exact advertiser and BC relationships, owner-bound verified identity and supported Conversation capabilities. Configure using the backend's protected connection contract, not an n8n caller payload. |
| Backend release controls | TikTok DM private gate / tester eligibility | Default OFF. New connection/creation must fail closed when eligibility or provider evidence is absent. Private testing does not authorize paid activation. |

For installations without n8n Variables, regenerate with the reviewed public origin:

```sh
node integrations/tiktok-dm/build-workflows.mjs https://your-public-backend.example
```

That illustrative hostname is not a configured service. Running the generator without an argument restores portable `$vars.PROXO_TIKTOK_DM_BACKEND_ORIGIN` exports. No export uses `$env`; no environment-access security setting needs to be relaxed. Origin validation rejects HTTP, local hostnames, literal IPs, credential-bearing URLs and URLs containing paths or queries. HTTP redirects are disabled so service authentication cannot be forwarded to a different destination.

Each worker returns a small application summary, for example:

```json
{"ok":true,"processed":0,"status":"idle"}
```

`processed` is zero or one. The exported contract permits `idle`, `blocked`, `paused`, `observed`, `reconcile`, `refunded`, `connected`, `disconnected`, `videos_ready` and `guarded`, with an optional sanitized uppercase `error_code`. Worker summaries are operational results, not raw TikTok delivery statuses or proof of approval.

## Provider prerequisites and honest blocked behavior

Read [provider evidence](../../docs/tiktok-dm/provider-evidence.md) and the [server-only capability and proof contract](../../docs/tiktok-dm/backend-config.md) before configuring the integration. The documented BC QR authorization URLs do not currently establish provider-correlated completion tied to a specific Proxo user. A local nonce, requested username or newly observed BC identity cannot supply that missing proof. The account-connect worker therefore returns the explicit blocked result:

```json
{"ok":true,"processed":0,"status":"blocked","error_code":"TIKTOK_AUTH_CORRELATION_UNAVAILABLE"}
```

It must not fabricate an authorization URL, QR bitmap, session expiry, verified username or successful connection. Other workers cannot bypass that boundary by accepting an identity from an n8n event. Connection completion requires a supported provider-correlated flow or an independently verified owner-binding procedure before enablement.

Actual Conversation route eligibility also remains account-specific: manual `TT_USER` and Upgraded Smart+ BC flows have different requirements. The actual advertiser's Conversation/identity allowlists, Iraq targeting, required controls, welcome message, commercial music and existing-post compatibility must be proven. Never silently substitute Click, Traffic or another optimization. No provider geographical IDs, callback fields, permission claims or current minimum values are invented in these workflows.

The spend guard starts from the stored 95% threshold of the customer's Proxo advertising budget. The provider's declared minimum must be separately verified; it must not increase the accepted customer charge. Native automated rules are conditional on advertiser eligibility and cannot be assumed available to a SaaS platform. Reporting and native rules are delayed, so a minute schedule does not guarantee an exact spending ceiling. An overrun does not authorize another customer debit. The backend must never automatically re-enable an ad group stopped for the budget policy.

## Status and refund boundaries

The backend reads actual provider operation/secondary states and updates existing Proxo canonical statuses. Budget-stop evidence may support `completed`; an unrelated/manual `DISABLE` remains `paused`. Provider IDs, timestamps, terminal-state rules and durable stop evidence protect against stale responses. A temporary polling failure preserves the last known canonical state. The app receives existing Supabase state through its existing realtime flow; these workflows add no customer status controls.

Unused-budget refunds for a confirmed completed Conversation ad require all of the following server-side evidence:

- Persisted `completed_at` and at least two hours elapsed according to server time.
- A fresh authoritative final-spend read after eligibility, with settlement evidence appropriate to TikTok's reporting delay.
- An original accepted customer budget and original funding transaction relationship.
- Transactional, idempotent compensation of `max(customer budget − final spend, 0)` through the existing ledger.

The schedule is not the two-hour timer: `worker-refund` must enforce the authoritative `refund_eligible_at` boundary each time it claims work. It may return blocked/pending while spend remains unsettled. No estimate, client clock, stale report or caller-provided refund amount is sufficient. Duplicate polls must return the same committed result without a second credit. No refund occurs merely because two hours passed, and a later spend adjustment must not silently reverse an already committed refund. Confirmed pre-delivery failure compensation remains subject to its own existing safe original-funding policy; unknown provider outcomes must be reconciled first.

The current reporting read has no verified finality marker. The backend requires an independently verified, archived `PROVIDER_SETTLEMENT_EXPORT` attestation for the exact ad group and final amount, in addition to delayed stable observations. Two equal samples are not settlement proof. No live automated settlement-evidence source was established here; unused-budget settlement remains pending without that evidence. See the [settlement contract and blocker](../../docs/tiktok-dm/backend-config.md#final-spend-settlement-evidence).

## Retries and logging

HTTP Request nodes make at most three transport attempts with five seconds between attempts and a 60-second request timeout. HTTP responses use text plus `neverError`, so even a non-JSON HTTP 401/403 is classified without an automatic transport retry. HTTP 4xx/5xx responses, malformed results and transport failures become static sanitized errors; no workflow-level retry cycle exists. Durable lease recovery, bounded exponential provider-stage backoff, permanent error handling and rate limits belong to the backend.

A timeout may occur after the backend or provider completed an operation. A subsequent poll must reconcile persisted state rather than repeat an unknown provider mutation. No workflow retries TikTok directly. Credentials remain in the backend and n8n credential stores. The exports disable successful, failed, manual and in-progress execution payload storage; pinned data is empty. Final Code nodes strip headers, authorization URLs, raw diagnostics and customer/identity records. Also retain redaction in deployment and reverse-proxy logs.

## Import, controlled tests and rollback

1. Inspect the target n8n version and supported nodes. Export backups before replacing existing Proxo workflows; these exports do not modify OTP, Meta or payment workflows.
2. Use the protected credential form or sign in directly on n8n's own login page. Never place an n8n password in chat, source, notes or exports.
3. Import all six files, bind the dedicated worker credential and configure the backend origin. Verify every fixed route, connection, credential, schedule and node setting. Keep workflows inactive.
4. Against an isolated backend/database, confirm missing/invalid service credentials fail before claims; user-facing APIs enforce ownership; connection correlation stays blocked until proven; videos paginate only verified identities; disconnect requires the persisted owner's confirmed request.
5. Exercise duplicate claims, partial creation IDs, lost provider responses, permanent versus transient errors and manual-versus-Conversation fulfillment isolation. Verify delivery objects remain paused and no activation request is sent.
6. Exercise provider status mappings and stale updates, 95% stop evidence, no automatic re-enable and no extra debit. Test final refund before two hours, at/after two hours with settled spend, unavailable/stale reports, exact-budget spend, overspend and duplicate compensation. Inspect linked authoritative ledger records.
7. Record target version, imported IDs, bindings and controlled test evidence. Publish only when the intended environment and the owner's release rules permit it. Publishing a worker schedule is not paid activation authorization.

Target n8n import, credential binding, scheduler execution, account correlation, provider eligibility and real provider/financial end-to-end tests were not performed in this environment. Those remain setup and release blockers.

Rollback starts by disabling new automatic fulfillment and its creation schedule. Preserve authorized status, spend monitoring, reconciliation and financial recovery for already accepted orders; do not abandon a possibly spending ad. Review pending disconnects and accepted requests before disabling their workers. Export the configured replacements before restoring prior workflows. Do not delete original debits, accepted prices, provider IDs, connection audits or idempotency records, and do not treat removal of a JSON file as reversal of a provider operation.

## Repository checks

`node --test test/tiktok-dm-workflows.test.js` passes six tests. The harness parses all six actual exports, follows both triggers through their finite graph, executes the exported Code and URL expressions with intercepted HTTP, verifies exact operation ordering and `{}` bodies, tests the blocked correlation result, rejects unsafe/unconfigured origins and prevents raw account/auth data from leaking. It covers HTML 401, 403, 429, 503, 422, redirects, malformed JSON, invalid statuses and transport errors; a failed status/reconciliation stage cannot proceed to refund in the same execution. No external request is made by these tests.

Node definitions were inspected from published `n8n-nodes-base@2.15.1`: Schedule Trigger 1.2, Manual Trigger 1, Code 2 and HTTP Request 4.2. This is source/schema and isolated execution validation, not an n8n runtime import. **No target n8n runtime version is claimed as validated.** Exported JSON contains credential names only and no secret values.

Official node references: [Schedule Trigger](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.scheduletrigger/), [HTTP Request](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.httprequest/), [HTTP credentials](https://docs.n8n.io/integrations/builtin/credentials/httprequest/), [retry handling](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.httprequest/common-issues/). Provider sources and their precise implementation limits are linked in the [evidence report](../../docs/tiktok-dm/provider-evidence.md).
