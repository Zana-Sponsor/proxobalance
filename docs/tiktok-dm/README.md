# TikTok Direct Message v15 handover

This extends the existing Proxo Create Ad, account, payment, finance/outbox, receipt and realtime flows. The combined PR also includes [Meta v8](../meta-ads/README.md). The owner's later v15 shared-payment instructions govern both platforms: a compact selected-method card, confirmed Account Balance by default, and Change opening the shared bottom sheet. A row choice is temporary until Confirm; dismissing preserves the previous method.

**The feature remains OFF.** A separate private approval-bound activation path now exists, with independent DB/environment gates OFF and no activation scheduler. All three Smart+ creation stages explicitly request `DISABLE`; every n8n export is inactive. No production database migration, external workflow publication, live account authorization, paid ad or real payment/refund was performed by these local checks.

The current 25-section continuation status supersedes earlier baseline acceptance claims: [completion ledger](../tiktok-dm-completion-status-2026-10-23.md).

## Implementation and authoritative scope

- [Full v15 requirement traceability](requirements.md) covers all 4,204 source lines, base sections and authoritative appendices, including which wording was superseded.
- [Combined local verification](validation.md) records the final Flutter, Node, PostgreSQL, analyzer, build and receipt checks and their limits.
- [Backend configuration and evidence boundaries](backend-config.md) describes private owner proof, account capabilities, credentials, rollout gates and final-spend settlement proof.
- [Official provider evidence](provider-evidence.md) records inspected current TikTok references, exact supported fields and unresolved account-specific requirements.
- [Mobile components](mobile-components.md) describes account/video/cache/QR UI responsibilities and fixture limitations.
- [Six inactive n8n exports and setup](../../integrations/tiktok-dm/README.md) gives the actual imports, fixed worker routes, credentials and controlled verification procedure.

TikTok has exactly two objectives, Messages and Views. Messages branches into Direct Message or External Contact. Only Direct Message/Conversation uses the automatic identity/video flow; External Contact and Views retain existing manual fulfillment. Customer-facing messages remain in the selected TikTok account's native inbox. The account connector does not fabricate a QR or connection when official completion cannot be safely correlated.

Backend code is under [api/_lib/tiktok](../../api/_lib/tiktok). The additive [TikTok migration](../../proxo_app/supabase/migrations/20261023193522_tiktok_dm_private_v1.sql) extends the existing `app_finance.outbox`; it does not create a second wallet or financial queue. Accepted orders retain owner-bound quotes, original debits, durable stage intent/IDs and recovery. Unknown provider outcomes are reconciled before another create or refund.

## Financial and status behavior

TikTok keeps its $10 customer minimum. Gross daily budget × duration determines the 95% early-stop threshold. Provider declared budget/minimum is separately verified and may be higher. Reporting delay means this is an early-stop policy, not an exact spending cap; provider overrun never creates an additional customer charge.

Any fresh status observation can enforce a due budget/end stop, and a persisted stop whose acknowledgment was lost is confirmed without another pause POST when the group is already disabled. A known-ad failure or explicit rejection records a failure stop and disables delivery before the settlement wait. Unavailable spend does not block an already justified stop, and never becomes zero or refund evidence. Database claims keep incomplete creation with reconciliation and prevent ordinary status polling from taking final-refund work. Raw provider status stays server-side; existing canonical statuses and Supabase Realtime drive the current UI. Manual/unknown-cause disable is paused, not automatically completed.

Unused-budget settlement requires a confirmed stop, at least two hours and an immutable provider-supported completeness record. Current offline report candidates remain nonfinal; manual archived attestations and capability arrays cannot authorize refunds. Two hours or two equal reports alone are insufficient. The amount is `max(original captured paid media after discounts − settled spend, 0)`, bounded by the original debit; the gross campaign allocation is not refunded as a discount subsidy. A known ad's zero-spend report cannot bypass waiting/finality. A failed chain with no possible created ad can use the separate safe pre-delivery compensation path after durable state and disabled-ancestor checks. Original debits and linked credits remain in the existing ledger/history.

## Design evidence and receipt preservation

These are actual Flutter widget captures using controlled fixtures, not invented product mockups or live provider accounts:

| View | Capture |
| --- | --- |
| Shared payment sheet, common phone | [393px / 1× text](../../proxo_app/docs/meta_ads_evidence/payment_sheet_393_1x.png) |
| Shared payment sheet, narrow / large text | [280px / 2× text](../../proxo_app/docs/meta_ads_evidence/payment_sheet_280_2x.png) |
| TikTok Direct form | [393px / 2× text](../../proxo_app/docs/meta_ads_evidence/tiktok_direct_form_393_2x.png) |
| TikTok connected accounts | [280px / 2× text](../../proxo_app/docs/meta_ads_evidence/tiktok_direct_accounts_280_2x.png) |
| Meta shared form | [393px / 1× text](../../proxo_app/docs/meta_ads_evidence/meta_393_1x.png) |
| Shared launcher | [280px / 2× text](../../proxo_app/docs/meta_ads_evidence/launcher_280_2x.png) |

The approved advertisement receipt renderer, dimensions, typography, Proxo branding, rows, amounts, reference placement, PDF/image/share/export appearance remain unchanged. The prompt permits only changing an **existing** platform-logo slot. The inspected receipt contains Proxo branding and no separate platform-logo slot; none was invented and Proxo was not replaced. Correct platform/order/financial data use the existing renderer.

## Release blockers

| Unresolved prerequisite | Required before enablement |
| --- | --- |
| Owner-correlated authorization | Real Accounts OAuth now verifies the provider owner and username. A provider-supported immutable Accounts-to-Marketing/BC asset join is still required; success remains unlinked. Generic QR, username/list differences and manual rows cannot complete it. |
| Actual account eligibility | Credentials/scopes, BC and advertiser relationship, supported Conversation/identity allowlists, Iraq targeting, language/device/age controls, current budget minimum/timezone, approved welcome message and creative/music eligibility. |
| Automatic settlement evidence | A real protected source of per-ad-group provider settlement proof. It was not established here; refund remains pending without it. |
| FastPay | Immutable quote/payment attempts and independent gateway validation are implemented. Actual sandbox credentials, callback execution and staging verification remain required; paid production remains disabled. |
| n8n and deployed services | Import the six exports into the intended runtime, map credentials, run controlled failure/retry/idempotency scenarios, and verify database/API/realtime behavior. JSON/Node checks are not target-runtime execution. |
| Final acceptance | Safe real-account checks, actual native-inbox destination, spend-stop/report latency, physical-device RTL/safe-area/keyboard tests and the prompt's complete staging matrix. Local screenshots are not proof of pixel equality to an unavailable reference. |

Local command results and their scope are recorded in [requirements](requirements.md#recorded-local-verification). They do not remove these external gates. Keep rollout, FastPay and activation flags OFF and exports inactive until the applicable release evidence is complete. When disabling future creation, preserve monitoring/reconciliation for already accepted work; never delete funding history or abandon an uncertain provider operation.
