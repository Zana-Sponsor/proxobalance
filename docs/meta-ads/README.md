# Private Meta ads implementation handover

This change extends Proxo's existing Create Advertisement system with a private Meta mode and preserves the existing TikTok flow. Meta ordinary-customer availability is OFF. The migration initializes new-order eligibility and Meta FastPay eligibility to false. Provider delivery objects are constructed paused; this implementation does not authorize or perform paid activation.

The owner supplied revision **v8**, including the latest receipt-only-logo instruction. [Requirement traceability](requirements.md) covers every numbered section and authoritative appendix. The order/workflow contract is separately versioned as **schema 3**.

## Receipt: the latest requested change

The existing advertisement receipt is approved and must not be redesigned. Meta and TikTok share its existing component, renderer, typography, spacing, dimensions, rows, monetary formatting, status, references, Proxo branding and export/share behavior. All Meta placements use Meta identity; Facebook-only and Instagram-only are not separate receipt designs. A wallet transaction still opens its separate financial receipt.

Inspection found **only Proxo branding in the current receipt header, with no existing platform-logo slot**. Consequently, replacing the Proxo logo or inserting a badge, row or new logo slot would contradict v8. The existing renderer is preserved. The platform-logo substitution remains unresolved until the approved existing slot is identified; it is not reported as completed. Advertisement cards still route directly to the existing advertisement receipt through `adDetailsRoute`.

## Actual reused source inventory

Paths are relative to the repository root.

| Existing responsibility | Source reused or extended |
| --- | --- |
| One create shell, AppBar, common fields, existing scheduler and submit flow | `proxo_app/lib/screens/ad_create_screen.dart` |
| Shared design tokens, sections, choices, price/value rows | `proxo_app/lib/widgets/ad_form_components.dart` |
| Draft, quote, pending submission, owner-scoped recovery, wallet/FastPay submission | `proxo_app/lib/services/ad_submission.dart` |
| Center navigation and shared route dispatch | `proxo_app/lib/widgets/bottom_nav.dart`, `proxo_app/lib/main.dart` |
| Advertisement query, pagination, realtime and direct receipt navigation | `proxo_app/lib/screens/ad_screen.dart` |
| Advertisement receipt data and screen | `proxo_app/lib/models/ad_receipt_data.dart`, `proxo_app/lib/screens/ad_detail_screen.dart` |
| Approved advertisement receipt and common receipt tokens/branding/export component | `proxo_app/lib/widgets/receipt/ad_receipt_card.dart`, `proxo_app/lib/widgets/receipt/receipt_kit.dart` |
| Financial history, detail and existing refund language | `proxo_app/lib/widgets/tx_history_page.dart`, `proxo_app/lib/screens/transaction_detail_screen.dart`, `proxo_app/lib/l10n/tx_strings.dart` |
| Existing payment provider artwork and row component | `proxo_app/lib/widgets/payments/payment_option.dart` |
| Supabase settings and authenticated finance/ledger/idempotency infrastructure | Existing `public.pa_settings`, `public.pa_transactions`, `public.pa_ads`, `app_finance`, `proxo_private.ad_submissions`; `20261016174350_secure_financial_operations.sql` |
| API bearer verification, bounded JSON requests and JSON responses | `api/_lib/security.js` |

The additions are small shared widgets/services (`ad_feature_config.dart`, `meta_ad_draft.dart`, `ad_platform.dart`, `ad_objective_icon.dart`, `ad_brand_logo.dart`, `ad_payment_card.dart`, `ad_help_notice.dart`), a Node contract/provider/worker layer under `api/_lib/meta/`, the dispatcher in `api/_lib/advertising.js`, and additive migration `proxo_app/supabase/migrations/20261022235825_meta_ads_private_v3.sql`. No separate Meta receipt architecture is introduced.

Vercel rewrites the unchanged `/api/meta-ads`, `/api/tiktok-dm`, OAuth callback and wallet-refund URLs into the existing `api/proxolink.js` entrypoint with `service=advertising`. The dispatcher retains its own user/worker authentication and platform routing. This keeps eleven API entrypoints and the existing middleware within the current project's function limit. The shared entrypoint retains the advertising worker's 60-second maximum duration; local Express routes use the same dispatcher.

Objective icons are local transparent PNG masters under `proxo_app/assets/icons/objectives/`. The latest labels and colors are Messages `نامە`/green, Views `بینین`/pink-red, Engagement `کارلێک`/pale sky blue. TikTok retains its existing objective set and shares its applicable PNGs. Brand artwork provenance is recorded in `proxo_app/assets/logos/ads/SOURCES.json`; this records bundled third-party vector sources and must not be misrepresented as owner/official brand approval.

## Contract and money boundaries

New Meta configuration requires both the submitted Facebook Page URL and post/video URL. The exact three objective enums are `MESSAGES`, `VIDEO_VIEWS`, `VIDEO_ENGAGEMENT`. Placements are a nonempty unique subset of `facebook`, `instagram`; Messages destinations are a nonempty unique subset of `WHATSAPP`, `MESSENGER`, `INSTAGRAM_DIRECT`. Messenger requires Facebook; Instagram Direct requires Instagram. Both video objectives exclude messaging fields entirely, including empty arrays. Unknown client fields, singular destination fields, client asset IDs, client user/account claims and fabricated payment flags are rejected.

Normalization sorts semantic sets and object keys before fingerprinting, trims the name and validates URLs without inventing resolved assets. `pfbid` stays opaque until the provider resolver matches an accessible permalink and ownership. URL syntax validation never grants permission. Historical v1 singleton and v2 destination-array meanings have explicit read adapters; incomplete legacy creation must fail with a migration/connection error rather than invent Page URLs, quotes or payment evidence.

`POST /api/meta-ads?op=quote` verifies the authenticated owner, current private gate, authorized connection and preflight evidence, then stores an immutable read-only quote. Its fields include the server quote ID, canonical configuration fingerprint, expiry, method, authoritative pricing, intended schedule and an independent forecast. It does not debit/reserve funds, create provider advertising objects or enqueue an order. Quotes are connection/owner scoped and time limited.

`POST /api/meta-ads?op=submit` passes the normalized configuration, stable submission ID, quote reference and displayed totals to `pa_meta_accept`. The database owns the charge, funding eligibility, accepted snapshots and durable job. Authenticated recovery finds an already accepted submission before checking new-order gate or quote expiry; it returns the original accepted amount and effective schedule. Reusing an idempotency key with changed business configuration is a conflict, not a new charge. New acceptance must match a valid owner-bound quote.

USD arithmetic uses integer minor units. With no approved adjustment, $5/day × 3 days is 1,500 cents once, including all three destinations. Media spend and customer payable values are separate typed fields even when equal. IQD conversion is recorded by the accepted quote; neither Flutter nor n8n sets the authoritative charge. Meta adds no new fee. The shared summary renders only actual price components and discounts.

The later [TikTok v15 shared-payment requirements](../tiktok-dm/requirements.md) override earlier inline payment wording for both platforms: confirmed Account Balance by default, a compact selected-method card, Change opens one shared bottom sheet, and Confirm alone commits its temporary selection. Dismissal preserves the prior method; only the selected sheet row shows a check. Choosing/confirming/changing a method only changes selection state. Meta FastPay is **disabled by default** until the existing external order-create/callback flow binds the immutable `meta_quote_id`, validates funding once and compensates the original payment correctly. A direct payment must never also debit the wallet. Top-up and advertisement purchase remain separate financial operations.

## Scheduling and forecasts

The business timezone is `Asia/Baghdad`. Explicit schedules must be offset-qualified valid calendar instants strictly after trusted server time, within the supported advance window. A three-day duration means exactly three 24-hour periods with an exclusive end; waiting until a future start is not a paid day. Impossible dates are rejected instead of normalized into another month.

An immediate quote binds mode/timezone/duration without a fabricated fixed client start. Acceptance assigns the effective start/end once. Retries recover those times without a fresh charge or shifted start. An accepted schedule is not repriced merely because the original quote expired. The UI must revalidate on resume, midnight, picker confirmation and payment/top-up return; a stale explicit schedule cannot silently become immediate. If a delayed job cannot execute its accepted window safely, preserve it for the documented reconciliation/compensation path rather than extending its billable duration.

The forecast is deliberately `UNAVAILABLE` with `SUPPORTED_ESTIMATE_NOT_AVAILABLE` and null bounds/source/metric. No real supported outcome-forecast source is configured here. Audience size is not relabeled as expected views/messages/engagement; missing estimates are not zero and do not change financial amounts. The provider API is pinned to `v26.0`, with no dependency on removed estimate fields.

## Preflight, workers and compensation

The backend provider client uses an environment-held token selected by an approved connection reference. Preflight checks fresh connection evidence, executing system-user identity, required permissions, actual assigned Page/ad-account advertising tasks, USD active ad account, Page/content ownership, linked Instagram and selected messaging assets. It checks the whole selected set. Missing one selected channel blocks the order; no channel is silently dropped.

Application objectives map to account-verified tuples using `OUTCOME_ENGAGEMENT`, `IMPRESSIONS`, and `CONVERSATIONS`, `THRUPLAY` or `POST_ENGAGEMENT` as appropriate. The mapping is not a promise of universal support. The exact post identity, kind/media type, placements and destination set must have fresh supported capability evidence; combined existing-post messaging must be explicitly verified. Absent evidence fails closed with `EXISTING_POST_TUPLE_NOT_VERIFIED`. City targeting likewise needs real verified provider keys; fixtures are not deployable account configuration.

`app_meta.jobs` records accepted work and claim leases. The worker rechecks applicable eligibility, funding, schedule and preflight, then records an inflight intent before each provider POST. Campaign, Ad Set, Creative and Ad IDs persist stage by stage. Existing IDs are reused. All delivery objects remain paused. A timeout or lost persistence response leaves the inflight journal for reconciliation, not a blind repeat POST. Reconciliation verifies a unique matching object before adopting it; no match is not proof of non-creation.

Status polling stores provider observations separately from application state. Creation success is not ACTIVE delivery. Unknown provider results and unknown refunds retain their financial state until resolved. Confirmed no-delivery terminal failures use the authoritative original funding record for compensation; partial IDs and debit history remain. Wallet refund handling retains `/api/v1/wallet/refund`; n8n never supplies a new customer charge or trusts its own amount calculation. Full confirmed refund updates the original debit to `گەڕاوە`; pending refund is `چاوەڕێی گەڕاندنەوە`. A separate financial receipt remains available.

## Protected configuration and private review

| Setting / record | Purpose and default |
| --- | --- |
| `app_meta.settings.enabled` | New Meta eligibility, false on migration. There is no ordinary-customer public-enable switch in this handover. |
| `app_meta.settings.fastpay_enabled` | Meta eligibility for the retained FastPay method, false on migration. |
| `app_meta.testers` | Explicit authorized user membership, enabled flag and optional expiry; required alongside the gate. |
| `app_meta.connections` | Authorized owner/account/Page/Instagram/WhatsApp metadata, fresh verified capabilities, expiry and environment secret reference. No bearer token stored in the row. |
| `app_meta.quotes` / `app_meta.jobs` | Immutable accepted pricing/configuration evidence and durable stage/recovery state; ordinary clients do not write them directly. |
| `pa_ad_capabilities` | Authenticated feature response; client cache cannot grant backend access. Failure hides Meta affordances. |
| `pa_ad_help` / `pa_set_ad_help` | Read active scoped notice / authorized admin update through existing `pa_settings`; ordinary customers cannot modify help or turn on Meta. |

Review in an isolated configured environment: apply the additive migration after the existing finance migration, provide an authorized server connection and fresh capabilities, enroll only approved internal testers, and enable only their private gate. Use controlled synthetic or authorized non-delivering cases. Keep provider objects paused, Meta FastPay disabled unless its retained workflow is proven, and workflows inactive until their controlled tests are completed. Do not copy test UUIDs, tokens, geographic IDs or timestamps into real connection records. There is no supplied public-release action.

The help notice is independent of access control. Authorized administrators can edit its enabled state, Kurdish content, tutorial label/HTTPS URL, ALL/META/TIKTOK scope and priority without rebuilding mobile. Invalid or missing tutorial links hide only that action; failed optional help loading must not block creation.

## n8n exports and mandatory external setup

Three actual inactive exports are provided:

- [`proxo_meta_ads_create.json`](../../integrations/meta/proxo_meta_ads_create.json): polls the create worker.
- [`proxo_meta_ads_status_sync.json`](../../integrations/meta/proxo_meta_ads_status_sync.json): polls recorded provider state.
- [`proxo_meta_ads_reconcile_refund.json`](../../integrations/meta/proxo_meta_ads_reconcile_refund.json): reconciles unknown/partial outcomes and dispatches safe compensation in the same backend state machine.

See [workflow import, configuration, verification and rollback](../../integrations/meta/README.md) for exact prepared names, routes, credential references, variables, node versions inspected and test details. Each trigger sends an empty authenticated worker request; the backend claims trusted durable work. No inbound mobile-to-n8n order webhook is introduced. Secrets stay in backend environment/n8n credentials, not JSON exports.

**No owner's n8n instance was accessed. Target import, actual version compatibility, credential binding and controlled end-to-end execution are not verified.** The specification requires those steps; syntactically valid exports and simulated tests do not complete them. Login must use a protected credential form or n8n's own login page; never paste passwords into chat. Back up affected existing workflows before controlled import. Keep production activation disabled.

Backend configuration names are `PROXO_SUPABASE_URL`, `PROXO_SUPABASE_SERVICE_ROLE_KEY`, `META_WORKER_SECRET`, the token variable referenced by `app_meta.connections.access_token_env`, and optional `META_APP_SECRET`. n8n requires `Proxo Meta worker` (`httpHeaderAuth`) and `PROXO_META_BACKEND_ORIGIN`. Names alone do not mean values or assets are configured. Exact capability evidence requirements are documented beside the provider source and workflow handover.

## Verification evidence and limitations

The entries below distinguish earlier focused checks from the final post-v15 shared-payment run. The root reports 163 passing Flutter tests across 19 files in the combined final run; earlier overlapping counts must not be added to it. Current payment behavior and actual fixture captures are recorded in the [TikTok v15 handover](../tiktok-dm/requirements.md#recorded-local-verification).

The finance owner reports `PGLITE_MODULE=/workspace/scratch/43a583048faa/meta-db-tools/node_modules/@electric-sql/pglite/dist/index.js node scripts/test-meta-database.mjs` passed **77 assertions** with both additive migrations loaded. Coverage includes grants/gates, immutable quote/read-only pricing, owner/replay recovery, atomic funding rollback, ambiguous provider stage reconciliation, linked original-debit refunds, help administration and legacy TikTok pricing. This is local disposable-database evidence, not a deployed Supabase migration or live provider/payment run.

`node --test test/meta-contract.test.js` passed **33 tests** in this checkout. These are local pure-contract tests with a frozen synthetic clock and fake identifiers; no provider request occurs. They cover all seven destination subsets against all three placement sets, exact objectives, duplicate and singular/plural rejection, stale video fields, URL/pfbid normalization, unsupported profiles/hosts, two independent required URLs, integer money, duration/age bounds, trusted-time scheduling including impossible calendar dates, canonical fingerprints, selected method and legacy destinations, and honest unavailable forecasts.

`node --test test/meta-workflows.test.js` passed **5 tests** against the actual exports. They check connected inactive routes, credential-only configuration, empty trigger payloads, origin validation, small allowlisted worker summaries and sanitized authentication/transport/malformed-response failures. These execute exported JavaScript and expressions locally; they do not import or execute an n8n runtime. Documentation relative links were checked and `git diff --check` passed.

The root implementation also ran `flutter test --no-pub test/ad_submission_test.dart test/ad_repository_test.dart test/meta_ad_draft_test.dart test/meta_ad_repository_test.dart` from `proxo_app`: **34 tests passed**. This covers the shared draft/repository paths and private Meta selection/repository behavior with local fixtures; it does not prove a live Supabase, payment or Meta connection.

The receipt owner reports the original `receipt_reference_match_test.dart` golden remained unchanged and passed against `docs/receipt_labels_preview.png`. The same renderer produced byte-equal RGBA images for TikTok and Meta Facebook-only/Instagram-only/both fixtures with equal bound values. Receipt/platform/refund/model/loading/PDF checks initially passed **33 tests**; the subsequent debit-reference/refund-state and empty-state/UI-balance run passed **44 tests**. The receipt renderers and `receipt_kit.dart` are unchanged from baseline. This proves the exercised receipt fixtures, not every form or device.

The final PR validation record contains the owning implementation's full provider/API/worker, migration and Flutter run commands and limitations. Source presence alone is not a pass. Existing evidence from earlier PRs is a design baseline, not proof that this change passed new visual tests.

Open external acceptance items are the real authorized Meta account/business/system-user/asset assignments; verified exact post/objective/placement/destination tuples and geography; target n8n import/configuration/E2E; the retained FastPay quote-binding/callback/compensation workflow; and the existing approved receipt platform-logo slot. Device-performance claims require measured representative-device evidence. Pixel-for-pixel preservation requires actual before/after rendering comparisons, not unit tests alone. No real campaign delivery, customer debit, live refund, public rollout or production readiness is claimed by these local checks.

## Rollback and later release

Disable new Meta eligibility and the n8n create schedule first. Keep authenticated historical status, reconciliation and legitimate compensation available for accepted orders. Do not delete immutable quotes, debit records, provider IDs or stage intents. Examine unknown provider outcomes before refunding or recreating anything. Restore prior workflow exports only after backing up configured replacements; removing source files does not undo accepted funding or provider objects.

Public availability and paid delivery require a separate owner decision after the outstanding acceptance evidence is complete. Private tester eligibility is not that authorization. This change remains a reviewable private implementation with the above explicit unresolved items.
