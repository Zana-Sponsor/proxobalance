# Proxo mobile refinement

Review date: 20 October 2026. Base: `3c457e4ec1a326f33814d1cf5f19caa826e27fd0`.

This change repairs page saving and navigation, and brings the requested mobile surfaces into the authentication screens' visual system. Kurdish text, RTL layout, existing workflows, and the existing IQD/USD amount contract are preserved.

## Changes by requirement

| Requirement | Implementation |
| --- | --- |
| Pages | Separate loading, empty, and retrieval-error states; explicit Create Page action; validation, duplicate-tap protection, save recovery, and saved-list refresh. Default navigation remains the overview/list. |
| Shared design | Authentication-derived colors and typography; shared 4/8/12/16/24/32 spacing, 16px cards, 12px controls, 48px actions, 20px interface icons; reusable empty states. |
| Home | Removed the separate advertisement summary and bottom statistics panels. Compact Best Results and three aligned quick actions. View Statistics opens a dedicated screen using the existing cumulative counters. |
| Result cards | Compact collapsed summaries; expandable/collapsible objective, budget, and duration; shared thumbnail frame and exact existing patterned “Proxo” fallback for missing or failed images. |
| Add Balance | Ordered amount, method, instructions, details, proof, and submit flow; clear selection; readable accounts; numeric normalization; validation and busy/error states. |
| Brands and icons | Official FIB, FastPay, and Qi assets in balanced containers. Solar SVG interface icons across the updated surfaces, with RTL-appropriate arrows. |
| App bar | Consistent 56px height, 48px touch targets, proportionate logo, centered icons, contained notification badges. |
| Menu | Scrollable small-screen layout, correct selected item and destinations, guarded repeated navigation, reliable close/scrim controls and logout. |
| Receipts | Reflowing label/value rows, full references, status and prominent amounts, readable Kurdish text. The actual PDF export uses the redesigned receipt widgets. |
| Profile | Balanced identity/details/actions, long and missing-value handling, data retry state, smaller icons and wallet amount, explicit authentication routing after logout/deletion. |
| Advertisements | Shared deliberate empty and retrieval-error states; separate filtered-empty result; clear creation action. |
| Verification | Regression tests and actual Flutter widget renders at narrow and wide mobile sizes, with enlarged text, mixed scripts, and simulated keyboard insets. See the verified results below. |
| Evidence | Labeled screenshots and actual receipt PDFs, with viewport, dimensions, and SHA-256 hashes in `ui_audit/manifest.json`. |

## Page-creation findings

The original client treated saving and a second list fetch as one operation. A successful POST/PATCH could persist the page, then a failing GET made the UI report the entire save as failed. A delayed older list request could also overwrite the newly saved item. Local draft-cleanup failures were another possible false failure after a successful write. Frontend validation additionally rejected a TikTok-only contact configuration that the backend already accepted.

The authenticated create/edit handlers now return a complete, explicitly whitelisted saved record. The client uses that record directly, keeps it visible if refreshing fails, ignores stale list responses, and treats local draft cleanup as best effort. Existing idempotency keys are retained; conflicts preserve the saved page ID for recovery. Compatibility with older summary-only API responses is retained, with an explicit “saved, refresh failed” outcome. Owner responses do not expose creation hashes or encoded images.

The current source already defaulted to Home and the Pages list; an unconditional first-visit create redirect was not reproducible in this checkout. The explicit creation entry from the advertisement workflow is retained. Regression coverage checks that an empty Pages account opens the list until its creation action is tapped. Authentication token refresh/user updates no longer reset navigation. The kept-alive Pages tab only handles Back while it is active.

## Other functional repairs

- A failed statistics retry previously returned a Future from `setState`; the callback is now synchronous.
- Menu Home and Help destinations and selected states are corrected. Repeated route taps are guarded.
- The authentication SDK clears its local session before server logout completes. A network failure after that point now still clears authenticated routes and opens authentication.
- Manual deposits commit the canonical Supabase request before writing its deterministic Firebase mirror. A notification/mirror failure does not present a committed request as a failed submission.
- Receipt layout no longer scales a fixed-width canvas down into unreadable text. Wrapped mixed-script values keep their content and remain separated from labels, including enlarged text.

## Verification results

- Full Flutter suite: **327 passed, 0 failed** on Flutter 3.47.2 / Dart 3.13.2. This includes the two new isolated deposit-submission tests.
- Node backend suite: **240 passed, 0 failed**.
- Static analysis: **0 errors, 65 warnings, 167 informational findings**. The baseline had 88 warnings and 172 informational findings. No new warning category/count was introduced; remaining findings include existing warnings and four new style-only informational findings. The analyzer exits nonzero because warnings remain.
- Evidence: **101 PNG renders and 4 actual receipt PDFs**, with narrow/wide viewport labels and hashes. Actual exported PDFs were rendered and visually checked.
- `git diff --check` passes. Android/iOS release builds have not been run locally; the PR workflow includes an Android APK build.

See `ui_audit/README.md` for reproduction commands and `ui_audit/manifest.json` for the delivered capture inventory.

The regression suite covers saved-page reload through a controlled repository; validation, failed refresh and stale replies; empty/loading/error states; result expansion/collapse and thumbnail failure; quick actions/statistics; payment selection/copy/validation, single insert despite repeated taps, canonical persistence before mirrors, success navigation, server-failure field retention and identical retry; menu routes and logout; Profile actions; and receipt layout/export. Screenshot sizes include 320px, 393px, and 430px wide mobile layouts. Existing advertisement creation/submission tests are retained.

## Official asset sources

- FIB: https://fib.iq/wp-content/themes/FIB/assets/images/header-mobile-logo.svg
- FastPay: https://www.fast-pay.iq/img/clogo.png
- Qi: https://www.qi.iq/images/logo.svg?1=1

Assets were retrieved from their official websites on 20 October 2026 and retain their original proportions and colors. See `assets/logos/OFFICIAL_SOURCES.md`.

## What remains unverified

The screenshots are actual Flutter renderings of production widgets with synthetic records, not physical-device screenshots or design mockups. Payment destinations are replaced with all-zero test values. Full Home captures compose the production widgets with fixture data; remote initialization is covered separately. Pages preview fixtures deliberately demonstrate the real unavailable/retry state.

No live database write, real account page persistence, financial transfer/settlement, OTP, notification delivery, account deletion, or production deployment was performed. Reopening Pages is verified with a controlled persisted repository response, not a live backend. Physical keyboards, native WebView preview, Android/iOS share/print sheets, and device-level accessibility still need a staging/device smoke test. Public Best Results data contains category/rank, not private campaign titles/status; no private fields were fabricated or exposed.

## Release notes

Deploy the compatible API change before the mobile release to avoid the legacy post-save readback. No database schema, RLS, pricing, or exchange-rate change is included. The pull request is a review boundary; it does not deploy the app. Run a staging account smoke test for page save/reopen, payment submission, authentication, native preview, and receipt sharing before release.
