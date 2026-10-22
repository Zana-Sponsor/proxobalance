# Proxo: current 15-point audit

Started October 20, resumed October 22, 2026. This work updates PR #44 from `2a98e20d33f37fd1b6357a21a8758192806361dd`; it does not use the separate PR #45 implementation. The latest 15-point request is the scope.

**Verification checkpoint:** source review and backend tests are complete. Consolidated Flutter tests, current screenshots and the Android profile run are pending at this checkpoint. This document will be updated with their actual results. Live page creation remains blocked by the deployed backend, as described below.

| Requirement | Implementation |
| --- | --- |
| 1. Best Results | Home renders summary-only cards. Dedicated results retain expansion, with equal objective/budget columns and aligned labels/values at large text sizes. |
| 2. Profile | Compact identity, balance, account/support/settings groups; reused language options; official WhatsApp glyph; preserved account actions and session guards. |
| 3. App bars | Home and Advertisements share the same locale-aware toolbar, 77×22 proportional logo, notification/menu controls and 48dp targets. Secondary titles retain a 56dp minimum and grow for larger text. |
| 4. Empty states | Shared restrained content-sized component, 48dp icon well/24dp SVG, concise copy and primary action; no oversized outer card or decorative page-type chips. Loading and request failure remain separate. |
| 5. Create Page | Failed saves release editing; corrected retries retain the same request UUID; late committed conflicts return the owner's saved page. Initialization, storage and avatar waits are bounded. Confirmed saves survive failed/stalled local cleanup. |
| 6. Create Advertisement | Removed the pending-request blanket form lock; restored editable values/payment selection/scrolling after failure; cancellation and bounded waits release temporary state. Confirmed success resets the completed form. Uncertain requests retain their original identity. |
| 7. Pricing | Flat, aligned rows use the actual quote calculation, consistent currency formatting and a restrained total. |
| 8. Submission button | Moderate 12dp corners, shared form edges, 48dp minimum height and stable label/icon/loading geometry. |
| 9. Notifications | One compact SVG notice replaces the old 3D queues. Exactly 2,000ms after its first rendered frame; no duplicate deadline extension; replacement/navigation/tab/disposal cleanup; pointer-transparent passive notices. |
| 10. Ad payment choice | Shared full-row payment options, consistent logo/indicator frames and selected styling; preserved wallet/FastPay submission contracts. |
| 11. Receipts | Shared receipt layout/status/amount hierarchy. Full-width, single-line LTR identifiers scroll within narrow viewports and offer copy. PDF export repaints the complete identifier independently of its current scroll position. |
| 12. Add Balance | Exactly FastPay and FIB, amount-first sequence, provider details/instructions, actual checkout/manual-review flow and recoverable submission. Stable loading geometry and durable retry keys. |
| 13. Menu | Fixed compact header/close control, scrollable safe-area rows, compact contact summary without synthetic phone-email wrapping, and Profile navigation through the existing tab. |
| 14. Consistency/navigation | Shared regular Kurdish typography, surface/control values, SVG family, headers/payment choices/notifications; bounded reads and retained screen state. |
| 15. Verification | Added recovery, timer, UUID export, large-text, header, menu, provider and storage-ordering regression coverage. Current full execution and profile measurements are recorded below when available. |

## Causes and recovery

- **Create Page startup:** the configured `https://www.proxobalance.app/api/page-providers` returns HTTP 404, verified by read-only checks on October 20 and again October 22 at 18:25:57 UTC. This fails catalog initialization before the form or submission can run. Retry makes another real request but cannot deploy the missing route. See [page evidence](pages.md).
- **Page form lock:** retained `_submitted` data made fields read-only after uncertain failure. Editing now resumes while the request UUID is preserved for idempotent recovery. Local cleanup no longer masks a confirmed result.
- **Advertisement lock:** persisted pending requests wrapped the whole form in `IgnorePointer`; the resume navigation path lacked its own guaranteed cleanup, and broad network classification retained locks after definitive database rejection. Form state is now independent of pending-request reconciliation; only verified rollback codes clear the pending identity. Connection errors and unknown transaction outcomes keep it.
- **Late cleanup race:** timing out a platform storage cleanup must not allow it to erase a later request. Page/ad storage operations are serialized per owner; caller deadlines do not abandon the durable operation queue. Top-up keys keep their existing serialized ordering.
- **Notifications:** overlapping queued cards, long deadlines and multiple animation/timer paths were replaced by a single content-sized surface with a first-frame deadline and screen-lifecycle cleanup.

## Checks completed at this checkpoint

- Node.js **24.19.0**, Linux x86_64: `npm test` — **180 passed, 0 failed**, October 22.
- `npm run build` — passed; generated unrelated Exchange outputs were excluded from this app change.
- `git diff --check` and Python syntax compilation of the Android profile runner — passed.
- Standalone Dart storage-queue checks — passed ordering after timeout, independent owners and recovery after failure.
- Previous PR44 baseline results and previous screenshots are historical evidence only; they are not claimed as verification of these changes.

## Remaining verification and deployment limits

- The current full Flutter suite, rendered screen review and Android35 profile fixture are pending at this source checkpoint. The runtime fixture uses actual Android rendering/keyboard/Back and synthetic transport fixtures; it does not charge payment providers or write customer records.
- The production page API/schema/environment rollout is not completed. The existing isolated-write guard remains intact. October22 Supabase inventory contains no development branch for the app project. Follow the [existing isolated rollout plan](../home-payment-remediation-2026-10-19/isolated-rollout-plan.md) before claiming authenticated create/refresh/reopen success against a hosted backend.
- No live FastPay charge, bank transfer, actual device camera/gallery, customer-data write, production migration or production release is claimed.
- Solar SVG provenance is in `assets/icons/solar/SOURCES.json`; the official Meta WhatsApp asset provenance is in `assets/icons/WHATSAPP_SOURCE.md`. FastPay original bytes were rechecked October20. FIB retains its recorded official SVG; the October20 asset refresh was blocked with403, so current-day byte identity is not claimed.
