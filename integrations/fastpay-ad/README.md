# Immutable Meta/TikTok FastPay payments

The authenticated Proxo payment adapter prepares one durable attempt from an existing immutable Meta or TikTok quote. The attempt owns the original IQD amount, USD charge, FX rate, merchant, environment, transaction, quote and submission ID. A verified payment commits the deposit, ad debit, ad order and existing fulfillment outbox atomically through the finance RPC. The client must not submit the ad a second time.

Creation defaults **OFF**. This change made no live FastPay QR, payment, refund or advertising request. Unit tests use intercepted transport and a mock ledger; PostgreSQL integration coverage is maintained with the finance migration. Real merchant sandbox credentials, sandbox evidence and controlled runtime verification remain required before enabling creation. An inactive imported workflow does not establish these prerequisites.

## Official gateway contract

The current [FastPay developer site](https://developer.fast-pay.iq/) links its QR integration guide at `/qr-integration`. The guide's deployed JavaScript asset, [`/static/js/main.b58e2caa.js`](https://developer.fast-pay.iq/static/js/main.b58e2caa.js), was inspected read-only on 2026-10-23; SHA-256 `a49802fc78f351befb88bfbe523b97f114567152219385aab1a354dad0f50163`. The guide identifies these exact origins; the server has no arbitrary gateway base-URL option:

| Environment | Origin | Routes and method |
|---|---|---|
| Sandbox | `https://staging-qr.fast-pay.iq` | `POST /api/v1/public/vending/qr`, `/validate`, `/status` |
| Production | `https://qr.fast-pay.iq` | Same three paths |

The guide specifies JSON `storeId` and `storePassword` credentials. QR creation uses `orderId`, `billAmount` in IQD, `currency`, and an expiry of 3–15 minutes; `callbackUrl`, `successUrl` and `cancelUrl` are supported. Successful QR data contains `qrUrl` and `qrText`. The adapter derives all order/money values from the persisted attempt and records its request hash before making this mutation.

Status must return the exact `merchant_order_id` and documented `payment_status`. Funding requires `PAID`, then an independent `/validate` response with `status: "success"`, the same nonempty `gw_transaction_id`, exact order, exact `received_amount`, and explicit `currency: "IQD"`. Both responses must have a valid success envelope. No case folding, field aliases, missing-currency defaults or malformed-JSON repair supplies payment evidence. The guide's sample JSON has punctuation defects; actual malformed responses remain unverified.

The documented responses do not echo a merchant ID. Merchant binding therefore requires the attempt's frozen merchant reference to match the server's configured store ID, and both reads use that merchant's credentials at the pinned environment origin. A fresh provider validation response hash and server verification time are sent only through the service RPC. Provider customer name/phone fields are neither returned to the client nor used as proof.

`UNPAID` and `DECLINED` status reads do not authorize funding. The service-only `observe_status` action records authenticated `/status` evidence as `FASTPAY_STATUS`, distinct from paid `FASTPAY_VALIDATE` evidence. Decline is persisted and releases an unused promo reservation; unpaid does not overwrite a captured payment. Neither observation establishes irreversible finality: late-payment reconciliation continues. The observation's amount/currency bind the immutable attempt; they are not invented provider fields for a nonpaid response. UI cancellation records customer intent; it is not a gateway cancellation. Cancelled/declined attempts hide their QR, and a late independently validated payment can still settle or compensate according to the immutable finance contract.

## Server and n8n configuration

| Location | Name | Required value or purpose |
|---|---|---|
| Backend | `PROXO_SUPABASE_URL`, `PROXO_SUPABASE_SERVICE_ROLE_KEY` | Existing intended Proxo project and server credential. User RPCs use the authenticated user's JWT; service actions remain private. |
| Backend | `FASTPAY_AD_ENVIRONMENT` | `sandbox` by default; `production` only for a separately authorized release. Controls new creation, not recovery of frozen attempts. |
| Backend | `FASTPAY_AD_CREATE_ENABLED` | Defaults OFF. Literal `true` permits creation only when the database gate and all other checks also pass. |
| Backend | `FASTPAY_AD_PRODUCTION_ENABLED` | Defaults OFF; additionally required for production creation. |
| Backend | `FASTPAY_AD_SANDBOX_STORE_ID`, `FASTPAY_AD_SANDBOX_STORE_PASSWORD` | Dedicated sandbox merchant credentials, entered only in the server secret store. |
| Backend | `FASTPAY_AD_PRODUCTION_STORE_ID`, `FASTPAY_AD_PRODUCTION_STORE_PASSWORD` | Production merchant credentials, required only for that environment. Retain credentials needed to reconcile existing frozen attempts. |
| Backend | `PROXO_AD_PAYMENTS_BACKEND_ORIGIN` | Public HTTPS backend origin, no path, query, credentials, port or trailing slash. |
| Backend | `FASTPAY_AD_CALLBACK_URL` | Same origin, exact `/api/meta-ads?platform=payments&op=callback`; no additional query fields. |
| Backend | `FASTPAY_AD_SUCCESS_URL`, `FASTPAY_AD_CANCEL_URL` | Optional reviewed return URLs on the same backend origin. Redirect results are not payment verification. |
| Backend | `FASTPAY_AD_QR_ORIGINS` | Optional comma-separated reviewed HTTPS origins for provider QR images. Default allows only the pinned gateway origin. Establish actual sandbox QR hosting before adding an origin; never allow a client-supplied host. |
| Backend | `FASTPAY_AD_WORKER_SECRET` | Dedicated high-entropy worker secret, at least 32 characters. Never place it in Flutter, workflow JSON, notes or public callbacks. |
| Database | `app_finance.ad_payment_settings` | `enabled=false`, `environment='sandbox'`, empty merchant reference by default. Merchant reference must exactly equal the selected configured store ID. Meta/TikTok private/tester and FastPay gates also apply to new attempts. |
| n8n Variables | `PROXO_AD_PAYMENTS_BACKEND_ORIGIN` | The same public backend origin; this is not the Supabase URL. |
| n8n Credentials | `Proxo FastPay ad worker` / `httpHeaderAuth` | Header `Authorization`, value `Bearer` followed by the dedicated worker secret. Bind the imported name to the local credential ID. |

The merchant reference is not a credential, but it is server-owned. Enabling the private tester gate alone does not authorize production payment creation or paid ad activation. Changing current gates/environment must not discard accepted attempts; reads use the frozen environment and its matching credentials. Completed attempts return their durable result without provider calls or quote revalidation.

## n8n 2.23.4 credential import boundary

The exports deliberately use `httpHeaderAuth: {"id": null, "name": "UNCONFIGURED — Proxo FastPay ad worker"}`. This is an **unbound marker**, not a new credential or a grant. Keep the marker name absent from the credential store. Before a separately authorized controlled test, explicitly replace the marker by selecting the intended dedicated worker credential. Never select an unrelated production credential or create a real credential named `UNCONFIGURED` to silence the warning.

Actual inactive import exposed n8n's automatic selection behavior: a name-only reference with the `id` property omitted can be removed during import; opening the HTTP node can then select the most recently updated credential of the same type. A fabricated non-null missing ID is also removed. Leaving the field absent is therefore insufficient. The explicit `id: null` marker survives the version's importer, keeps the credential map nonempty so the dropdown's default-selection watcher does not run, and cannot execute without a real credential ID. Both frontend and server can resolve a unique exact credential name, which is why the unmistakable marker name must not match an existing credential.

This behavior was verified from the official **`n8n@2.23.4`** source:

- [`useCanvasOperations.ts`](https://github.com/n8n-io/n8n/blob/n8n%402.23.4/packages/frontend/editor-ui/src/app/composables/useCanvasOperations.ts): `removeUnknownCredentials` preserves `id === null` but deletes unknown non-null IDs; `importWorkflowData` adds imported nodes to the existing graph.
- [`useNodeHelpers.ts`](https://github.com/n8n-io/n8n/blob/n8n%402.23.4/packages/frontend/editor-ui/src/app/composables/useNodeHelpers.ts): `matchCredentials` retains the unbound reference when no exact credential name matches.
- [`NodeCredentials.vue`](https://github.com/n8n-io/n8n/blob/n8n%402.23.4/packages/frontend/editor-ui/src/features/credentials/components/NodeCredentials.vue): the most-recent-credential watcher requires an empty credential map; the normal dropdown has no clear-selection control.
- [`workflow-helpers.ts`](https://github.com/n8n-io/n8n/blob/n8n%402.23.4/packages/cli/src/workflow-helpers.ts): `replaceInvalidCredentials` preserves the null-ID reference when no unique matching name exists.
- [`credentials-helper.ts`](https://github.com/n8n-io/n8n/blob/n8n%402.23.4/packages/cli/src/credentials-helper.ts): execution requires a real ID and resolves that exact ID/type; a missing ID is rejected.

For an already imported inactive workflow with an unintended credential association, first retain its reviewed backup and settings. **Import from File appends nodes; it does not replace the existing graph or apply imported settings.** Remove only that new workflow's graph nodes, import the corrected export into the same workflow, then save. Recheck the exact node count and connections, inactive/unpublished state, execution-data privacy settings, and every HTTP node's unconfigured marker. Re-export and verify all worker credential IDs remain null and no unrelated credential name/ID remains. Do not execute or publish during this cleanup; disabling HTTP nodes is an additional containment option if the UI does not preserve the expected marker. No existing credential is deleted or modified by this procedure.

## Authenticated application contract

All application operations use `POST /api/meta-ads?platform=payments&op=<operation>` with a user bearer token.

| Operation | JSON body | Behavior |
|---|---|---|
| `prepare` | `{submission_id, platform: "META" or "TIKTOK", quote_id, expected_cost_usd, expected_amount_iqd}` | Owner-bound quote validation or recovery of the same submission. No caller order ID, merchant, rate, verification flag or gateway payload. |
| `status` | `{submission_id}` | Owner-bound recovery after restart. Reads and verifies an existing attempt without another QR creation or ad submission. |
| `cancel` | `{attempt_id}` | Records the owner's cancellation intent and returns the same attempt; does not claim a gateway cancellation or refund. |

The public result includes `attempt_id`, `order_id`, `transaction_id`, frozen money/environment, `status`, `expires_at`, `qr_url`, `qr_text`, `result`, `ad_id`, `terminal`, `uncertain`, `compensated` and a persistent `cancel_requested` flag when applicable. Completed `result` includes the existing ad/receipt identifiers. `funded` and `compensated` are terminal; expiry or a declined observation alone cannot discard late payment recovery. Expired/terminal attempts do not expose a usable QR.

Once a durable attempt exists, a configuration, service or gateway failure preserves its owner-bound public snapshot with `uncertain=true`. Transport errors and unknown RPC envelopes are retryable/uncertain backend errors. Only an explicit successful RPC response declaring a business rejection is treated as a definite conflict. The app retains the submission ID and polls status instead of creating a replacement submission.

An initial `prepare` rejection may additionally return `attempt_created:false`, but only for the known quote, availability, pricing, account or rate-limit checks that run **after** the RPC has searched for an existing immutable attempt and **before** it creates one. The client accepts that proof only in a strict HTTP 409 `{ok:false, uncertain:false}` response with an allowed rejection code. This lets the user obtain a new quote or choose another payment method after a confirmed pre-payment rejection. Conflicts, missing/older response markers, unknown schemas, network errors, provider failures and every `status` response retain the original pending identity; none authorize another payment.

The unauthenticated `callback` operation accepts only `merchant_order_id` as a scheduling hint. It ignores supplied status, amount, user and verification flags, returns a generic acknowledgment, and schedules the private verifier. A callback or app redirect never credits money. Polling provides recovery if the callback is missed.

## Private reconciliation workflow

Import [proxo_fastpay_ad_reconcile.json](proxo_fastpay_ad_reconcile.json) **inactive**. Its Schedule Trigger runs once per minute, with an additional Manual Trigger for controlled tests. Both validate the backend origin, call `POST /api/meta-ads?platform=payments&op=worker-reconcile` with `{}` and the dedicated Header Auth credential, then retain only a sanitized summary. No customer, attempt, order, amount or verification result can be supplied by the trigger.

The backend claims one durable attempt lease, independently reads FastPay status and validation, and commits verified payment idempotently. This worker never starts a prepared QR order. A timed-out QR call is reconciled before any subsequent action; the adapter never blindly retries QR creation. A lost verification-commit response is safe to recover by the same order/provider transaction ID. The finance ledger owns duplicate-payment and original-funding guarantees.

HTTP nodes disable redirects, use a 60-second timeout and at most three transport attempts with five-second spacing. HTTP errors use `neverError` plus a result checker, so an HTTP 4xx does not trigger a transport retry. The only accepted summaries are `idle`, `pending`, `funded`, `compensated` and `reconcile`, with optional sanitized `error_code`. Successful, failed, manual and in-progress execution payload storage is disabled; pinned data is empty. Do not enable proxy or application logging of request credentials/provider customer payloads.

For n8n installations without Variables, regenerate with the reviewed public origin:

```sh
node integrations/fastpay-ad/build-workflow.mjs https://your-public-backend.example
```

The illustrative hostname is not configured. Running without an argument restores the portable variable expression. The export uses actual Schedule Trigger 1.2, Manual Trigger 1, Code 2 and HTTP Request 4.2 nodes; no unsupported pseudo-node or embedded secret is included.

Before controlled sandbox verification, install the immutable payment migration and the [legacy isolation guards](../legacy-isolation/README.md). Legacy FastPay paths must reject reserved immutable ad order IDs **before** any gateway QR/refund POST, as well as at the database mutation boundary. Keep existing manual ad/top-up flows on their current route. Do not route automatic attempts through a standalone replacement checkout or the old caller-asserted paid path.

Keep creation disabled until actual sandbox QR/validation shape, QR origin, merchant binding, callback routing and interrupted/duplicate payment recovery are verified with authorized test credentials. Confirm late payment after app termination, expiry and gate changes produces exactly one deposit, debit, ad and receipt—or the existing compensation result. Rollback disables new creation first while preserving reconciliation and ledger history for accepted attempts.

## Repository verification

`node --test test/fastpay-ad-payments.test.js` executes 21 tests with mocked gateway/database transport. Coverage includes durable intent/concurrent QR suppression, lost QR outcomes, strict status-plus-validation binding, malformed/redirect/error responses, late payment and duplicate commit, untrusted callback injection, owner JWT/service separation, restart recovery, changed creation settings, durable decline observations, cancellation QR suppression, RPC ambiguity, explicit no-attempt rejection proof, and actual exported workflow Code/URL expressions and graph traversal. Flutter coverage in `ad_fastpay_attempt_test.dart` checks definitive pre-payment cleanup for both platforms and preserves pending identities for ambiguous or post-prepare failures. These checks make no external payment requests and do not substitute for merchant sandbox or n8n runtime evidence.
