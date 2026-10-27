# Durable legacy FastPay checkout — inactive sandbox draft

The repaired wallet/manual-checkout [sandbox draft](https://email.proxopages.com/workflow/pA8Zn5xnDitCmDiP) was imported into n8n on **27 October 2026** and remains inactive with unbound credentials. **It has not been activated or payment-tested against FastPay.** The published `FastPay Checkout + Supabase v12` workflow remains unchanged. The [sandbox export](proxo_fastpay_durable_sandbox.json) uses separate webhook paths and requires an isolated Supabase project. Refund and Telegram nodes are disabled; refund acceptance is outside this checkout change.

## Behavior

Authenticated checkout retains the existing user lookup and server ad-quote branch. `pa_legacy_fastpay_checkout('prepare', …)` creates the original pending transaction with no QR and journals the frozen owner, order, IQD amount, currency, merchant, environment, return URLs, note and expiry before any gateway POST. SQL returns `create_authorized:true` once. The workflow reaches Generate QR only through that response; a timeout or repeated request returns the same order without authorizing another provider request. QR attachment updates the reserved receipt without repricing or extending its expiry.

The migration preserves the original USD/FX receipt values, denies legacy create re-entry for journaled orders, and keeps their reconciliation eligible after display expiry. A verified decline is an observation, not irreversible finality: the receipt stays pending, hides its QR and remains eligible for late independently validated payment. Historical rows without a frozen merchant are not adopted into the new protocol and require explicit reconciliation; no current credential is silently assigned to them.

All five immutable `AP…` isolation guards remain in the graph. Callbacks carry only an order hint. Poll/app status must provide exact HTTP 200, valid JSON, a successful envelope, exact order and documented status. PAID then requires independent `/validate` evidence with the same gateway transaction ID, exact IQD amount and explicit currency. IPN credit uses only independently validated receipt fields. Every paid RPC result is checked for the original owner/transaction and approved PAID state before the workflow reports success or advances fulfillment. Failed HTTP, redirects, malformed JSON, aliases, absent currency and callback-supplied receipt values cannot authorize credit. Public IPN acknowledgments contain no balance or customer data.

## Dependencies and isolated setup

Apply the [reviewed financial dependency chain](../../docs/fastpay-readiness-2026-10-27.md#database-installation-order), including `20261026213026_fastpay_unstarted_attempt_closure.sql`, then `20261026214905_legacy_fastpay_durable_checkout.sql`, on the isolated database after preflight. The latter requires the inspected legacy `fastpay_create_order` baseline; it is not a substitute for existing checkout tables/functions. Keep legacy provider credentials separate from the immutable-ad worker credentials.

The connected n8n plan rejected saving Variables with `Plan lacks license for this feature`. The sandbox export therefore uses ordinary **compile-time Code/expression constants**, with no dependency on n8n Variables, environment access or a paid upgrade. It does not read configuration from webhook bodies or input items. The default export leaves the isolated URL and merchant reference empty and fails closed before any external request.

When the isolated target and protected credentials are available, create a local JSON file containing only these three **nonsecret** fields:

| Public configuration field | Required value |
|---|---|
| `supabaseUrl` | Isolated `https://<20-character-project-ref>.supabase.co` origin. The main project is rejected. Inspect the target and grants independently. |
| `publicOrigin` | `https://email.proxopages.com`; the draft uses only the dedicated paths below. |
| `merchantReference` | Exact sandbox store ID matching the protected FastPay Custom Auth credential. This is a binding reference, not a password. |

Pass that file as the optional final builder argument:

```bash
node integrations/legacy-fastpay/build-patch.mjs /absolute/path/legacy-snapshot.json /absolute/path/review-output /absolute/path/sandbox-public-config.json
```

The builder rejects unknown fields, incomplete configuration and the main database, then stamps the same checked object into all 30 configuration expressions. Review the generated inactive file and import it through the normal n8n UI. Do not edit copies independently or place store passwords, service keys or tokens in this file. Credentials are still selected separately in n8n's protected credential UI. The generic production review patch retains its existing `$vars` contract; only the isolated sandbox export uses these constants.

The export forces the provider environment to sandbox, even if an unrelated environment variable selects production. It uses `https://staging-qr.fast-pay.iq`, and permits QR URLs only at that reviewed origin. A different real sandbox QR hosting origin requires evidence and explicit review before changing the allowlist.

Map each **null-ID `UNCONFIGURED`** marker explicitly through n8n's credential UI: isolated Supabase service Custom Auth, isolated Supabase publishable-key Header Auth, and sandbox FastPay merchant Custom Auth. Do not create a real credential named `UNCONFIGURED`, reuse production merchant credentials, or copy values into JSON/chat/commits. Confirm the merchant reference matches the credential's store ID; Custom Auth injects the protected provider fields, so this mapping also needs runtime acceptance. Node redirects and automatic retries are disabled; network timeouts are bounded.

The inactive export defines:

- POST `/webhook/proxo-fastpay-staging/order-create`
- POST `/webhook/proxo-fastpay-staging/order-status`
- POST `/webhook/proxo-fastpay-staging/ipn`
- GET `/webhook/proxo-fastpay-staging/success` and `/cancel`, which only tell the user to return to the app; redirects never prove payment.

Register the exact dedicated IPN callback with the sandbox merchant. The app transport is disabled by default. Build with the complete isolated `BackendConfig` settings and `PROXO_FASTPAY_STAGING_WEBHOOK_BASE=https://email.proxopages.com/webhook/proxo-fastpay-staging` only after the draft's isolated target and credential bindings are reviewed. Fresh pending records bind `journal-staging-v1`, this webhook base and the isolated Supabase origin. Only this protocol may retry the identical order after a pre-backend interruption. Existing production/unknown records never upgrade or cross environments. No staging target or merchant credentials have been configured by this change.

## Reproduction and verification

The supplied RFC6902 [patch](reviewed-durable-patch.json) records the inspected source digest and preserves source activation. It is a review artifact, not a workflow import. Generate the separately sanitized inactive export from a freshly authorized snapshot:

```bash
node integrations/legacy-fastpay/build-patch.mjs /absolute/path/legacy-snapshot.json /absolute/path/review-output
node --test test/legacy-fastpay-checkout.test.js test/legacy-fastpay-contracts.test.js test/legacy-fastpay-verification-patch.test.js
node scripts/test-legacy-fastpay-database.mjs
```

The 26 Node checks execute the embedded contract/checkout/verification code with synthetic responses, validate graph gates and inspect the actual generated export, including continuing a polling batch after one unavailable binding. They also verify the manual-only harness boundary and strict compile-time configuration. The database suite passes 86 PGlite assertions. GitHub additionally runs a real PostgreSQL concurrency suite; its result must be read from the current revision's CI. Local fixtures do not establish n8n import/runtime compatibility or provider acceptance.

### Manual n8n runtime checks

The separate [manual-only runtime harness](proxo_fastpay_runtime_harness.json) contains a Manual Trigger and one Code node. The [generator](runtime-harness.mjs) derives a configured synthetic fixture from the actual sandbox export, replacing only the marked nonsecret constants. It embeds those Code snippets, expressions and original contract factories without changing validation logic, then supplies synthetic responses. It first checks that the default blank template fails closed, and records separate template and configured-fixture digests. It contains no HTTP, webhook, schedule, credential or notification nodes and makes no provider request or ledger write. This permits checking n8n JavaScript runtime compatibility without selecting a database or merchant credential.

```bash
node integrations/legacy-fastpay/runtime-harness.mjs
node --test test/legacy-fastpay-runtime-harness.test.js
```

On **27 October 2026**, the updated constant-based export was reimported into the inactive sandbox draft, and the updated [runtime harness in n8n](https://email.proxopages.com/workflow/8fLksW8MXDWJQ810) ran manually and visibly returned **PASS: 56 checks**. Its code also requires the blank-template guard before producing PASS; local rehearsal confirms `defaultConfigurationRejected:true`. The exported draft was verified to retain 152 nodes, exact Code snippets/connections, zero bound credentials and no `$vars`/`$env` dependency. The harness emits named checks and both source digests, with `providerRequests:0`, `ledgerWrites:0` and `livePaymentAccepted:false`. See the [runtime audit and screenshots](../../docs/fastpay-runtime-2026-10-27/README.md).

For reproduction, import the harness as a separate inactive workflow and use its manual trigger only. This successful n8n run establishes Code/expression runtime compatibility for the synthetic cases. It does not establish HTTP-node transport, actual credential injection, database migration compatibility, callback delivery or real payment acceptance; those require the isolated integration test described above.

Before any controlled activation, inspect the exact draft and credential map, confirm the main database cannot be selected, and test authenticated ownership, same-order duplicate requests, interruption before/after dispatch, lost QR response, callback-before-QR-save, restart, gate/merchant changes, expiry, decline followed by late payment, duplicate payment evidence, and forged/non-200/mismatched responses. Confirm exactly one wallet credit and the original receipt values. Never resume a historical execution with the old graph. Production rollout, domain changes, production routing and refunds require separate review.
