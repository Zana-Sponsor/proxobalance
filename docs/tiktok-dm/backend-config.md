# TikTok DM server configuration and evidence boundaries

This document describes the private account contract consumed by [provider.js](../../api/_lib/tiktok/provider.js), [handler.js](../../api/_lib/tiktok/handler.js), and the [TikTok DM migration](../../proxo_app/supabase/migrations/20261023193522_tiktok_dm_private_v1.sql). It is not a ready-to-enable account configuration. No authorized production connection, owner-binding procedure or live provider settlement source was established or verified in this implementation.

Keep `app_tiktok_dm.settings.enabled`, `fastpay_enabled` and `activation_enabled` OFF. A tester allowlist is an additional eligibility check, not evidence of TikTok authorization or permission to run paid ads. Do not create example accounts, provider IDs, capability attestations or settlement reports to satisfy the checks below.

## Server-only account record

`app_tiktok_dm.accounts` is private. The service reads full records; user-facing endpoints return a restricted account view. Neither the token reference, capability evidence nor owner-binding proof belongs in Flutter, n8n input bodies, a customer-readable table or a workflow export.

| Field | Required meaning / checks |
|---|---|
| `id`, `user_id` | Local account UUID and authenticated Proxo owner UUID. The unique provider identity must not be reassigned through another user's request. |
| `requested_username`, `verified_username` | Original intended handle and exact provider-verified handle. Comparison trims a leading `@` and normalizes case; the full normalized handles must match. A typed handle is not identity proof. |
| `identity_id`, `identity_type` | Real numeric provider identity ID; supported identity type is `BC_AUTH_TT` or `TT_USER`. The selected creation route must independently support that type. |
| `business_center_id`, `advertiser_id`, `asset_id` | Actual verified BC, advertiser and account asset. The database preserves these relationships and the provider checks the applicable advertiser link. |
| `identity_authorized_bc_id` | For `BC_AUTH_TT`, this equals `business_center_id`. It is the BC ID, not the identity ID. |
| `access_token_env` | Secret reference matching `^TIKTOK_[A-Z0-9_]{1,100}$`. The effective token is read from that backend environment variable and sent only in the provider `Access-Token` header. The account record does not contain the token. |
| `status` | `CONNECTED`, `REVOKING`, `DISCONNECTED` or `EXPIRED`. Readiness requires `CONNECTED`. Disconnect first commits `REVOKING`, then verifies exact advertiser unlink before completion. |
| `available_status`, `can_pull_video`, `can_manage_message`, `message_ads_eligible` | Cached server observations, not client authority. Current provider identity reads must still establish `AVAILABLE`, video permission, messaging permission and eligibility. |
| `can_push_video` | Preserved capability observation; it is not a requirement to rehost or upload the selected existing video. |
| `last_verified_at`, `connected_at`, `disconnected_at` | Server verification/lifecycle timestamps. Cached readiness expires and must not replace provider preflight. |
| `display_name`, `profile_image_url` | Provider profile metadata. Neither is ownership evidence. |
| `owner_binding_proof` | Independent immutable binding evidence described below. This is an account-level field, **not** `capabilities.owner_binding`. |
| `capabilities` | Account-specific eligibility evidence described below. These values are not accepted from the mobile request. |

Lease, refresh and disconnect-request fields are worker state managed by the backend. User-facing APIs must derive ownership from the verified session before reading or mutating an account. The migration protects the account owner/identity binding and accepted order snapshot against reassignment.

## Owner-binding proof

The account-level `owner_binding_proof` object has this contract:

| Field | Required value / meaning |
|---|---|
| `verified` | Boolean `true` only after the reviewed verification procedure succeeded. Setting it manually is not proof. |
| `reference` | Nonempty reference to the restricted, archived verification evidence and reviewer decision. Never a token or reusable authorization URL. |
| `proxo_user_id` | Exactly the account's `user_id`. |
| `identity_id` | Exactly the account's verified `identity_id`. |
| `asset_id`, `business_center_id`, `advertiser_id` | Each exactly matches the corresponding stored account field, binding the proof to the intended account asset, BC and advertiser. |
| `method` | `PROVIDER_CORRELATED_AUTHORIZATION` or `INDEPENDENT_OWNER_VERIFICATION`. Neither label makes an unsupported procedure valid. |
| `verified_at` | Valid server timestamp, not in the future, less than 30 days old. |
| `verified_username` | Provider-verified handle matching the originally requested username under the same full-handle normalization. |

The reviewed procedure must establish that the authenticated Proxo user controls the exact TikTok identity and authorized the intended BC/advertiser relationship. Archive its authorization scope, identity, Proxo owner, timestamp, evidence reference and review outcome. Restrict access to the archive and preserve immutable audit history. A generic BC QR, provider request-log ID, local nonce, matching username, list difference or successful advertiser query is insufficient by itself.

The current public connection-start and connection-status routes return `TIKTOK_AUTH_CORRELATION_UNAVAILABLE`. No completion path, fake session expiry or authorization URL is synthesized. Before changing that behavior, establish and review a provider-supported correlated flow or an independent owner-verification procedure, then implement its protected evidence-writing path. There is no instruction here to bypass the blocker with a SQL insert.

## Exact `capabilities` contract

The runtime currently implements the non-catalog **Upgraded Smart+ DM** route; it does not silently substitute the distinct manual DM API tuple. Required readiness fields are:

| Field | Required configuration and evidence |
|---|---|
| `evidence_reference` | Nonempty private archive reference for the account-specific capability review. It must resolve to real evidence, not an arbitrary string. |
| `flow` | `UPGRADED_SMART_PLUS_DM`. |
| `api_version` | `v1.3`, the version pinned by this adapter for the documented DM/identity routes. |
| `verified_at` | Valid timestamp less than 24 hours old and not in the future. |
| `conversation_allowlisted` | `true` only with verified Conversation eligibility for this advertiser/route. |
| `adgroup_identity_allowlisted` | `true` only with verified support for selecting the intended identity at ad-group level. |
| `iraq_conversation_verified` | `true` only after the actual advertiser/route is verified to support the requested Iraq Conversation targeting. General Ads availability in Iraq does not establish this. |
| `targeting_country`, `iraq_location_id` | `IQ` and the actual supported numeric location ID returned/validated for the account. Do not copy a sample geographic ID. |
| `manual_targeting_verified` | Verified support for the exact location, age, gender, device and language controls transmitted by this flow. |
| `dm_receiving_verified` | Verified native TikTok DM destination behavior for the selected identity. Proxo is not the recipient and does not provide an inbox. |
| `auto_message_id`, `auto_message_verified_at` | Actual numeric welcome-message ID and verification timestamp less than 24 hours old. Preflight separately reads this exact message and requires the provider's supported welcome-message type and approval state. |
| `advertiser_timezone` | Exact verified provider `display_timezone`; live advertiser preflight must agree. Customer schedule semantics remain `Asia/Baghdad`, with normalized provider instants. |
| `budget.currency` | `USD`, matching the actual advertiser currency. |
| `budget.mode` | `BUDGET_MODE_TOTAL` for this adapter. |
| `budget.minimum_minor` | Positive safe integer containing the currently verified applicable provider minimum in USD cents. It is not a new customer price or a permanently hardcoded `$20` value. |
| `budget.verified_at` | Valid provider-budget verification timestamp less than 24 hours old. |
| `spend_guard_verified` | Verified monitoring/stop behavior for this account and flow. It does not assert that TikTok native automated rules are available or instantaneous. |
| `settled_reports` | Optional private per-ad-group settlement evidence; required before final unused-budget settlement can be established. Its separate contract is below. |

The archive referenced by `evidence_reference` must bind findings to the exact BC, advertiser, identity, API version, route, geographic targeting and creative/configuration scope. Retain current primary-source references, provider/account validation evidence, timestamp, reviewer and controlled-test outcome. Preserve only sanitized provider diagnostics; tokens and sensitive authorization URLs belong in the secret boundary, not the evidence archive.

Readiness checks can validate field shapes, relationships and freshness. They cannot turn an arbitrary `true` value, timestamp or reference into a real provider grant. Privileged provisioning must therefore review the archived evidence before setting readiness fields. No verified account-specific evidence was established here; the feature remains blocked until that work is completed. Expired, unsupported or revoked evidence must block new work rather than relax the checks.

## Current provider reads and disabled construction

All provider paths below are relative to `https://business-api.tiktok.com/open_api/v1.3/`. The current documentation findings and links are preserved in [provider-evidence.md](provider-evidence.md). This table describes the repository adapter, not a claim that these reads were executed against a connected account.

| Read-only path | Purpose |
|---|---|
| `identity/info/` | Re-read exact identity/type, verified username, BC relationship, availability, permissions and account eligibility. |
| `bc/asset/advertiser/assigned/` | Verify the intended BC account's advertiser link with bounded pagination. |
| `bc/asset/get/` | Verify the exact assets in the same BC: the `TT_ACCOUNT` asset requires both `POST` and `DIRECT_MESSAGE`; the `ADVERTISER` asset requires `ADMIN` or `OPERATOR`. Full administrator access is not required when the verified operator role is sufficient. |
| `identity/video/get/` | Page through accessible organic video records for the verified identity. Only the documented public visibility enum is selectable. |
| `identity/video/info/` | Revalidate the selected exact existing post before creation. |
| `identity/music/authorization/` | Validate music permission for the target location and actual schedule; public visibility alone is insufficient. |
| `advertiser/info/` | Verify advertiser identity, USD currency and timezone. |
| `creative/auto_message/get/` | Verify the configured existing welcome message for the actual advertiser. |
| `tool/language/` | Retrieve current targeting language codes. The adapter does not invent Turkish's code. |
| `smart_plus/campaign/get/`, `smart_plus/adgroup/get/`, `smart_plus/ad/get/` | Observe saved IDs and reconcile unknown outcomes; omission or mismatch is not permission to recreate blindly. |
| `report/integrated/get/` | Read authoritative lifetime ad-group spend for the persisted ad-group ID. A returned spend number is not a provider settlement marker. |

After all gates, accepted funding and deterministic preflight pass, creation uses `smart_plus/campaign/create/`, `smart_plus/adgroup/create/` and `smart_plus/ad/create/` with **`operation_status: "DISABLE"`**. The campaign objective is `LEAD_GENERATION`; the ad group uses native TikTok DM, `CONVERSATION`, `MESSAGE` and `OCPM`; the selected existing identity/item and approved welcome message are carried into the creative. There is no Click fallback and no media rehosting.

The worker persists intent before each mutation and provider IDs immediately after a known successful result. Unknown mutation outcomes go to reconciliation. The adapter can request `DISABLE` through the Smart+ ad-group status endpoint and read back confirmation. It contains no automatic paid-activation path. Changing a release flag or enabling a schedule does not create an `ENABLE` request.

## Final-spend settlement evidence

The reporting endpoint used here has no verified finality marker. Two equal spend reads, elapsed time, a pause response or a local `settled: true` flag cannot independently prove settlement.

Each accepted entry in `capabilities.settled_reports` must have exactly the relevant attestation fields:

| Field | Meaning |
|---|---|
| `adgroup_id` | Exact persisted provider ad-group ID for this job. |
| `final_spend_usd` | Independently verified final USD spend, matching the fresh provider report. Never a client or estimated value. |
| `settled_at` | Authoritative settlement-evidence timestamp, at or after this job's `refund_eligible_at`, not in the future, and less than seven days old. |
| `reference` | Restricted archive reference to the actual provider settlement evidence and its independent verification. |
| `source` | `PROVIDER_SETTLEMENT_EXPORT`. Merely typing this label is insufficient. |
| `verified` | `true` only after the evidence review confirms the exact job's provider-authoritative settlement. |

The worker must match that attestation to the actual job and latest report. The database additionally requires completed status, the server's two-hour minimum, confirmed pause and an unchanged second sample at least 30 minutes after the first before recording settled spend. These are additional consistency checks, **not a substitute for provider settlement evidence**.

No live automatic source for those settlement attestations was established. Automated final-spend settlement and unused-budget refunds therefore remain pending when independent provider proof is absent. Do not fabricate an export/reference or switch a boolean to make a refund complete. Completing this part of the product requires a verified authoritative settlement ingestion/verification mechanism, controlled tests and audit evidence. Existing safe pre-delivery failure compensation follows its separate original-funding policy.

After settlement is established, the backend computes the nonnegative unused amount from the original accepted funding, links compensation to the original transaction and commits it once. Spend above the customer's budget produces no unused refund and no automatic extra debit. An already committed refund is not silently reversed by a later report adjustment.

## Backend and workflow deployment settings

| Setting | Purpose |
|---|---|
| `PROXO_SUPABASE_URL`, `PROXO_SUPABASE_SERVICE_ROLE_KEY` | Intended Proxo project and server-only service credential. |
| `TIKTOK_DM_WORKER_SECRET` | Dedicated bearer credential; the handler requires a configured secret of at least 32 characters and constant-time comparison. |
| `account.access_token_env` | Selects the backend environment variable containing the effective TikTok token. No default token or caller-provided token is accepted. |
| `app_tiktok_dm.settings` | `enabled`, `fastpay_enabled` and `activation_enabled` default OFF. |
| `app_tiktok_dm.testers` | Explicit private eligibility with expiry; does not replace provider or financial evidence. |
| n8n `PROXO_TIKTOK_DM_BACKEND_ORIGIN` | Non-secret public backend origin, used by the six inactive workflow exports. |
| n8n `Proxo TikTok DM worker` / `httpHeaderAuth` | `Authorization` bearer credential bound to `TIKTOK_DM_WORKER_SECRET`; never embed its value in JSON. |

The eight service operations are `worker-account-connect`, `worker-account-videos`, `worker-account-disconnect`, `worker-create`, `worker-budget`, `worker-status`, `worker-reconcile` and `worker-refund`. They accept only `POST {}` at `/api/tiktok-dm?op=...`; worker claims resolve private records server-side. User APIs separately authenticate the Proxo session. Only the Conversation fulfillment worker can create ad objects, and other TikTok objectives remain manual.

See the [six-workflow setup and verification guide](../../integrations/tiktok-dm/README.md) for exact filenames, route ordering, bounded retries, credential binding, inactive state, import blockers and rollback. No target n8n import, real account preflight, controlled provider construction or live financial settlement was verified here. Do not report the setup as complete until those checks and the owner-binding/settlement prerequisites are actually satisfied.
