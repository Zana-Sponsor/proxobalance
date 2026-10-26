# FastPay readiness — 27 October 2026

The checkout and recovery fixes are prepared for review. **Live payment readiness is not established.** No real QR, payment, refund, production migration, workflow activation or deployment was performed for this follow-up. The restored Create Ad design is unchanged.

## Fixes in this revision

- **Immutable Meta/TikTok checkout:** a prepared attempt can now close permanently when the database proves that no gateway creation intent, QR, wallet credit or ad result exists. Configuration failures before dispatch, a closed creation gate and an elapsed QR window no longer leave the user stuck indefinitely. Closure and gateway intent use the same row lock. Only strict, matching `payment_not_started:true` proof on HTTP 200 lets the app clear the original pending submission; unknown responses and started payments retain their identity for reconciliation. The database prevents reopening a closed authorization and keeps its unpaid transaction history consistent.
- **Wallet checkout:** success requires an owner-bound receipt with `approved`, `PAID`, `wallet_credited:true` and the original IQD amount. QR creation checks the HTTP result, exact order ID and reviewed HTTPS origin. Owner changes hide the checkout, including its web view; bounded status checks are coalesced and expiry performs one final reconciliation. A durable owner-specific pending record preserves the original order, amount and note before dispatch, so reopening or a lost response cannot silently create another payment identity. Closing the sheet is recorded as a pause, not provider rejection. QR data and credentials are not stored in that record.
- **Recovery remains conservative:** a gateway-started, expired, declined or uncertain payment still requires independent verification; callback and redirect data cannot credit money. Existing late-payment settlement and duplicate protection remain in place. See the [adapter contract](../integrations/fastpay-ad/README.md).

## Read-only environment findings

| Component | Observed state | Consequence |
|---|---|---|
| Legacy n8n workflow | `FastPay Checkout + Supabase v12`, ID `jV7Zj5bSDebM1Izq`, is published and uses `https://qr.fast-pay.iq`. The Generate QR node has a Custom Auth account selected. Credential values were not read or copied. | A selected legacy credential does not prove a successful payment or provide credentials for the new sandbox adapter. |
| Immutable n8n worker | `Fzrt9neqyzRRrJZC` is inactive and its credential binding is unconfigured. | Automatic immutable-payment reconciliation is not ready to run. |
| Vercel configuration | New `FASTPAY_AD_*` variables were absent at the last check on 26 October. | The new adapter lacks its protected merchant, worker and callback configuration. |
| Supabase availability | Only the main project `cojchkwssmasiejcgvbk` was available on 27 October; no isolated staging project was available. Earlier inspection found the new private finance/ad integration schemas absent. | An isolated database and reviewed migration preflight are required before sandbox testing. |
| Existing public legacy FastPay RPCs | Execute permission is limited to `service_role`; `anon` and `authenticated` do not have it. | Preserve this boundary; clients must use authenticated backend routes. |

The wallet still deliberately blocks its legacy production transport when the app is configured for staging. It needs an isolated legacy endpoint before staging acceptance. The published legacy graph creates the provider QR before its pending database transaction: a lost response with no ledger row therefore remains ambiguous. The app durably marks dispatch before HTTP and does not replay QR creation in this case; the original order requires backend/operator reconciliation. This revision does not establish automatic recovery for that legacy gap. No existing production webhook, gateway, credential or workflow was changed.

## Database installation order

All filenames below are under `proxo_app/supabase/migrations/`. Inspect the existing checkout/idempotency baseline first: `20260913210000_fastpay_ad_checkout.sql`, then `20261003043057_ad_confirmation_idempotency.sql`. Do not blindly replay those historical migrations.

The minimum new payment dependency chain is:

1. `20261016174350_secure_financial_operations.sql`
2. `20261022235825_meta_ads_private_v3.sql`
3. `20261023193522_tiktok_dm_private_v1.sql`
4. `20261023202139_immutable_ad_fastpay_attempts.sql`
5. `20261026213026_fastpay_unstarted_attempt_closure.sql`

Full linked-TikTok acceptance also needs the branch's intervening migrations, in filename order before the new closure migration: `20261023202252_tiktok_oauth_private_lifecycle.sql`, `20261023202432_tiktok_activation_approval_journal.sql`, `20261023203029_tiktok_report_evidence_boundary.sql` and `20261025120000_tiktok_typed_page_eligibility.sql`. The last requires the existing ProxoLink typed-page baseline, including `20261006220119_proxolink_v6_independent_pages.sql` and its own prerequisites.

The secure financial baseline changes wallet representation and RPC authority. Rehearse it on the isolated database and run its financial preflight before applying dependent migrations. The new closure migration cannot substitute for this baseline, and fixture success does not establish compatibility with unknown deployed data.

## Verification

| Check | Result for this working revision |
|---|---|
| `npm test` | 492 tests passed; includes 25 immutable FastPay API/worker tests. |
| `node scripts/test-ad-payments-database.mjs` | 128 PostgreSQL assertions passed. |
| `node scripts/test-meta-database.mjs` | 77 PostgreSQL assertions passed. |
| `node scripts/test-tiktok-dm-database.mjs` | 130 PostgreSQL assertions passed. |
| `node scripts/test-tiktok-report-database.mjs` | 29 PostgreSQL assertions passed. |
| Flutter tests, analyzer and APK | Pending GitHub CI for this revision. Added coverage includes 14 immutable closure/malformed-proof cases, 14 wallet cases and 6 pending-order storage cases. Earlier revision results do not establish these checks. |

The database scripts run against disposable PGlite PostgreSQL fixtures. This revision pins `@electric-sql/pglite` to `0.5.12` and adds all four scripts to ProxoLink CI; those CI results remain pending. The local runs used `PGLITE_MODULE` pointing to the installed module. The scripts use synthetic records and make no provider requests. Closure tests cover both serialized lock-winner orders, permission denial, rollback and post-closure mutation rejection; they do not simulate two simultaneous PostgreSQL sessions. Local Flutter dependency bootstrap was blocked by automatic approval review, so it was not retried through another path.

## Remaining sandbox setup and acceptance

1. Provide an isolated backend and Supabase staging target, then run schema preflight and the dependency migrations with payment creation disabled. Inspect grants and verify the reserved immutable `AP…` order isolation against legacy checkout/status/refund routes, using the [reviewed isolation plan](../integrations/legacy-isolation/README.md).
2. Enter `FASTPAY_AD_SANDBOX_STORE_ID` and `FASTPAY_AD_SANDBOX_STORE_PASSWORD` directly in the protected server environment. Configure a dedicated `FASTPAY_AD_WORKER_SECRET`, bind the intended n8n Header Auth credential, set `FASTPAY_AD_ENVIRONMENT=sandbox`, and match the database merchant reference to the sandbox store. Do not place secrets in chat, commits or workflow exports.
3. Set the isolated `PROXO_AD_PAYMENTS_BACKEND_ORIGIN` and register its exact callback `/api/meta-ads?platform=payments&op=callback` with FastPay. Verify actual sandbox QR hosting before adding any QR origin. Keep the immutable worker inactive and creation disabled until the target, bindings and controlled test scope have been reviewed.
4. Complete the revision's Flutter tests, analysis and APK build. In the authorized sandbox, verify real QR/status/validation responses, merchant/order/amount/currency binding, callbacks, interrupted checkout, restart, owner switch, duplicate callbacks, expiry and late payment. Assert exactly one deposit, debit, ad and receipt, or the documented compensation result. Record sanitized provider evidence and n8n runtime results.

The standing scope remains **staging only**. This report does not authorize production promotion, domain/routing changes, automatic credential assignment, workflow activation or paid ad activation. Passing fixtures and published legacy configuration do not establish live payment acceptance.
