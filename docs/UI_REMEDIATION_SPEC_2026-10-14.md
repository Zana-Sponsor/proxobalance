# Proxo Flutter — Complete UI/UX Remediation, Functional Stabilization, and Precision-Based Verification

**Developer / AI Coding Agent Execution Specification**  
**Scope:** Home Screen; Transaction History, Transaction Details, and PDF Receipts; Advertisement Creation and Confirmation; Tools and ProxoLink Page Builder.  
**Type:** Inspect → reproduce → measure baseline → implement targeted fixes → measure again → test all affected states → report evidence.

## Non-negotiable objective

Implement and verify a coherent, professional, visually balanced, responsive, and reliable Proxo application across the four areas in scope. The user has supplied screenshots and screen recordings showing uneven layouts, undersized titles, compressed cards, inconsistent spacing, erratic focus/navigation, submission failures, poorly formatted PDF receipts, and Tools/page-builder errors. Treat those materials as the primary visual and behavioral evidence, while confirming their details against the actual current implementation.

**Do not submit another audit-only report.** Inspect the current code, fix demonstrated issues directly when safe, and provide real rendered evidence. Preserve working features, authentication, payment integrity, account isolation, existing Proxo branding, and backend contracts. Avoid unnecessary rewrites or speculative dependencies.

**Crucial sizing instruction: Do not use arbitrary pixel, dp, pt, font, margin, padding, card-height, image-size, or button-size values dictated by this prompt.** The developer must derive and justify suitable final dimensions from the current design language, visual references, measured layout, accessibility, and results on real devices. However, **the actual dimensions of every changed section must be measured, recorded, and verified precisely before and after implementation**. “Looks better” is not sufficient.

---

# PART I — Global design language and shared components

## 1. Audit the existing UI thoroughly

Review the complete screenshots and recordings and their interaction sequences. Confirm which current branch/build the evidence represents. Reproduce the reported issues in the current Flutter application, including the keyboard, loading and failure states, expansion/collapse, navigation, and PDF export.

Inspect the real layout and design tokens for:

- AppBar titles, header padding, icons, action positions, and safe areas.
- Primary headings, section headings, explanatory text, labels, values, and metadata.
- Cards, shadows, borders, radii, dividers, section groups, and internal/external spacing.
- Text fields, counters, dropdowns, selection chips, date/time pickers, buttons, and footer actions.
- Currency, numerical values, dates/times, RTL Sorani typography, and LTR codes/URLs.
- Empty/loading/success/error/pending states and their visual transitions.
- Scroll behavior, bottom navigation, sidebar, keyboard insets, and font scaling.

Identify shared components that are responsible for repeated inconsistencies. Refine those centrally when justified, but assess all consumers so a shared change does not break unrelated screens. Prefer a consistent design-token system and semantic spacing hierarchy (within a row, between rows, between sections, between major screen regions) instead of unrelated magic spacers.

The user expressly authorizes correcting bad visual layouts, adjusting font sizes, reorganizing awkward sections, and improving card/button proportions. Preserve the Proxo identity, main colors and established functionality; do not redesign unrelated parts of the application.

## 2. AppBar consistency

The AppBar titles are visibly too small in Transaction History, Transaction Details, Advertisement Creation, Advertisement Confirmation, and Tools/Page Creation. Make them readable and coherent across these screens. Check actual visual centering, title width, weight, line-height, RTL back-arrow placement, secondary actions, safe-area padding, and varying screen widths. Do not shrink text simply to fit a poorly constrained row.

---

# PART II — Home Screen: required new structure

## 3. Exact requested composition and ordering

Refine the Home Screen into the following primary vertical sections in this order:

1. **Header** — existing welcome/account identity, profile/menu, and notification entry points, as applicable.
2. **Top image banner** — a polished visual promotional/informational banner; carousel behavior only if supported and beneficial.
3. **Exactly THREE primary image-based quick-action cards** — each shows a meaningful picture/illustration and a clearly readable Sorani title.
4. **Best Results section** — a distinct image-based feature banner **together with selected/featured advertisement cards**, arranged as one visually coherent region.

Do not replace the Best Results cards with a banner alone. Do not add a fourth primary quick-action button. Preserve secondary functionality by keeping it discoverable through existing Tools, Sidebar, FAQ/help, or other established navigation rather than silently deleting features.

## 4. Exactly three quick actions and correct navigation

The three quick actions are:

- **دروستکردنی ڕیکلام** — Create Advertisement → existing advertisement creation flow.
- **زیادکردنی باڵانس** — Add Balance → existing deposit/top-up flow.
- **دروستکردنی پەڕە** — Create Page → correct Tools/ProxoLink page creation flow.

Each card must include **an image and its title**; do not substitute tiny icon-only buttons. Use consistent image presentation, title alignment, interaction feedback, visual weight and component proportions. All three cards must be functional; verify destination routes, back navigation, state restoration and keyboard behavior after entering the destination. Use approved/available assets; if required image assets are absent, clearly identify that dependency rather than shipping fake or unrelated images.

## 5. Top visual banner

Use the supplied image references for the intended **image-led composition** and polish, not as a requirement to copy their brand, images, or business content. Keep the banner responsive and legible. Verify image aspect ratio, crop/focal point, text readability, loading, fallback state, frame stability, optional carousel indicators, accessibility and tap destination if interactive. Avoid heavy image decoding or unnecessary reloading.

If a banner data/configuration source already exists, inspect and reuse it when fit for purpose. Do not invent promotions, promises, discounts, or performance claims. Do not build a dead button into the banner.

## 6. Best Results: image banner AND selected advertisement cards

Keep this section below the quick actions. The **image banner** is the visual introduction/feature for Best Results; the **selected ad cards** provide the actual relevant advertisement examples/results. Both must belong to the same design system and visually connect through typography, grouping, margins, alignment, image presentation and section spacing.

For featured advertisement cards:

- Use legitimate records from the existing data source and verified selection criteria.
- Check title, thumbnail, relevant performance information, status and destination where supported.
- Prevent clipped thumbnails, overflowed numbers, inconsistent card sizes and scattered metadata.
- Use suitable loading, empty, error and offline states.
- Do not invent rankings, ad metrics or advertiser identities.
- Ensure tapping the card opens its valid detail page, if supported and authorized.

Existing Home overview metrics may be retained in a compact supporting form or moved to the appropriate existing destination **without deleting access to working metrics**. Do not introduce unrelated large blocks that crowd the new banner/actions/results hierarchy.

## 7. Home-specific visual and runtime verification

Check the screen on first launch, warm return, manual refresh, slow network, empty results, populated results, image loading and failed-image states. Confirm exactly three visible primary quick actions. Verify that the banner and cards do not jump as data loads, that bottom navigation does not cover content, and that scrolling/tap feedback remains smooth. Reuse valid caches selectively and never leak account data after sign-out/switch.

---

# PART III — Transaction History, details and PDF receipts

## 8. Transaction History cards and layout

The history cards are too small/compressed, with amount, time and date tightly fitted into a single row. Correct AppBar legibility, card size/proportions, padding, row layout, amount typography, date/time presentation, touchability and spacing between items. Organize transaction type, amount, status and secondary metadata into a clear hierarchy when appropriate, rather than shrinking text with `FittedBox` to satisfy an unsuitable row layout.

Preserve positive/negative semantics and transaction navigation. Test long amounts, long dates/locales, different transaction types, very narrow/wide devices, large text scale, loading and empty states. Maintain correct sorting, refresh, scrolling, lazy building and account isolation.

Inspect in particular:

- `proxo_app/lib/widgets/tx_history_page.dart`
- `proxo_app/lib/widgets/receipt/tx_history_layout.dart`

## 9. Transaction Details: receipt design from top to bottom

Fully refine the on-screen receipt, not just its external margin. The screenshot demonstrates weak proportions between the Proxo logo/receipt title, transaction ID, date, blue section headings, divider lines, financial rows, optional payment details, closing rows, and PDF download button.

Correct the **relationships** between components:

- Receipt header/logo proportions, card horizontal and vertical insets.
- Clear separation of header metadata, transaction summary and payment information.
- Appropriate space **before AND after** section headings and dividers.
- Consistent row baselines, row spacing, text wrapping, label/value alignment and value emphasis.
- Readable date/time and complete, copyable LTR transaction identifiers.
- Appropriate presentation of missing or inapplicable fields; do not display unexplained decorative dashes.
- Logical spacing and alignment between receipt card and export action.
- Correct safe-area behavior, scrolling and text scaling.

The receipt and history card should feel like the same Proxo product without being forced into identical layouts.

Inspect in particular:

- `proxo_app/lib/screens/transaction_detail_screen.dart`
- `proxo_app/lib/widgets/receipt/receipt_kit.dart`

## 10. Financial values and units — correctness before appearance

The screenshots display `+18,000 IQD` in Transaction History and `10` labelled as IQD under the receipt's balance-after-transaction field. Different fields need not have equal numbers, but their **currency units must be correct**. Inspect authoritative columns and mapping from `pa_transactions`, `pa_wallets`, historical exchange rates, and the source of `amountIqd`, `balance_before`, `balance_after` and transaction types.

The current history implementation includes an amount-magnitude heuristic (values above/below a threshold being treated as different currencies). **Never infer a currency from the numeric magnitude.** Replace unreliable inference with explicit validated financial semantics when supported by the backend contract. Handle older records with documented transitional behavior rather than guesswork.

Ensure the history amount, receipt amount, balance-before/after, and PDF values reflect their exact field meanings and units. Pending/rejected transactions must not look settled. Distinguish USD and IQD clearly. Preserve original historical financial records and auditability; **do not edit balances or past transactions to make screenshots match**.

## 11. PDF export — separate verification and print-aware design

The current shared receipt code exports a PDF by capturing the on-screen `RepaintBoundary` as an image and placing it on a page sized from the captured widget. The user reports that the downloaded PDF is particularly disorganized. Investigate and fix **the actual exported file**, not only the Flutter receipt widget.

Inspect real exported PDF pages for page size, outer margins, scaling, typography sharpness, Kurdish shaping/RTL ordering, image resolution, logo, section spacing, divider positions, long values, overflow, excessive blank areas, multipage behavior, and print preview. If warranted, implement a dedicated PDF/print layout rather than blindly scaling the mobile card. Use a proven Kurdish-capable font/renderer strategy with verified legibility; retain the same authoritative transaction data. Keep amounts, labels, IDs and dates consistent with the UI while allowing print-appropriate layout differences.

Test PDFs for approved, pending and rejected deposits, admin credits/deductions, ad payments, refunds, and relevant optional fields. Open the generated PDFs on a PDF viewer and validate at ordinary zoom and print view. Deliver sample exported PDFs as evidence if the runtime permits. Do not claim PDF quality from a successful export call or a code review alone.

---

# PART IV — Advertisement Creation, confirmation and submission

## 12. Advertisement creation form — full flow

Inspect the complete flow for title/video URL or code, goal/objective, page asset, category, location, ages, gender, device, daily budget, duration, schedule, promo code, payment method, price/quote, and confirmation.

Correct inconsistent headings, misgrouped fields, excessive vertical gaps, cramped labels, mismatched controls, oversized dropdown overlays, poorly aligned values, inconsistent buttons, and keyboard overlap. Reorganize fields only when needed for a clearer journey without losing data, validation or existing options. Ensure selections and form content remain stable after async quote updates and navigation.

## 13. Critical: unexpected focus and scroll jumps

Reproduce the reported bug where choosing an unrelated option suddenly jumps to or focuses the **video URL/video code** input. Inspect `FocusNode`, autofocus, `GlobalKey`, form validation, scroll controllers, `ensureVisible`, widget rebuilds, focus restoration, selection callbacks and route lifecycle. A category, age, device, schedule or payment selection must never jump to the video field without a justified user-requested action. Test every control individually with the keyboard opened and closed.

## 14. Confirmation screen — complete visual correction

Treat the confirmation screen as a **separate screen requiring full design and behavioral verification**, not merely a continuation of the form.

Correct:

- AppBar title legibility and back-action layout.
- Countdown/status visual proportions and status text hierarchy.
- Spacing around main heading, explanation, error notice and action buttons.
- Total price panel and the relationship to ad summary.
- Ad summary rows and long TikTok identifiers in a Sorani RTL interface.
- Targeting section and its expand/collapse behavior, age labels and scrolling.
- Pricing breakdown, fees, discounts and payment-method values.
- Divider and card consistency, safe-area footer, disabled/loading button appearance.

Use meaningful visual distinction between preparing, countdown, processing, waiting for payment, success, recoverable failure and uncertain outcome. Do not show a success-oriented heading when the operation is unknown or failed. The countdown is an auto-submission timer, **not proof of backend progress**.

Inspect at minimum:

- `proxo_app/lib/screens/ad_create_screen.dart`
- `proxo_app/lib/screens/ad_confirmation_screen.dart`
- `proxo_app/lib/services/ad_submission.dart`
- Related shared ad-form components.

## 15. Critical: insufficient funds, timeouts and trapped retry state

The user reports that when balance is insufficient or the server does not finish, the screen stalls on “check again/retry”, locks editing, and sometimes prevents back navigation. Diagnose the actual state machine, including persisted pending requests, `PopScope`, `IgnorePointer`, RPC status checks, payment status, timeouts and lifecycle resumption.

Required distinctions and recovery paths:

- **Insufficient balance:** show verified available/required amounts, provide safe return-to-edit or Add Balance, preserve the draft.
- **Definite failure or form rejection:** explain the exact reason, allow correction and retry where safe.
- **Network failure/server unavailable:** preserve the draft and offer recovery, without misrepresenting an unknown transaction as failed.
- **Unknown payment/submission result:** retain the frozen request payload and original idempotency/submission ID, allow safe navigation away and later status reconciliation, but do not let a fresh request double-charge or duplicate an ad.
- **FastPay paid/credited:** reconcile the existing payment and follow the established authorized flow, never charging again on timeout.
- **Success:** confirm actual backend completion and navigate to the relevant advertisement record.

Avoid endless polling, permanently disabled controls, duplicate wallet deductions, duplicate advertisements and misleading loading text. A safe separate editable draft may be offered while the prior operation remains unresolved; do not mutate the submitted immutable payload.

Keep valid server-side quote/price verification, authorization, `pa_submit_ad`, `pa_ad_submission_status`, idempotency and user-data separation intact. **Do not solve `permission denied for table pa_ads` by granting unrestricted direct INSERT access.** Reproduce and trace any old client path that bypasses the approved RPC, then fix the client/backend contract safely in a non-production environment as authorized.

## 16. Ad-specific visual and behavioral test cases

Test form validation, all dropdowns, keyboard focus, quote refreshes, date/time selection, audience expansion, long video codes, initial confirmation, countdown completion, insufficient balance, server timeout, unresolved request, recovery after app background/restart, safe retry of the **same** submission ID, valid success, and both wallet/FastPay paths using isolated authorized test conditions. Do not perform real paid test charges or unapproved production mutations.

---

# PART V — Tools, ProxoLink page builder and page management

## 17. Tools — fix functionality AND layout

Review Tools screen, tool cards, navigation, ProxoLink page list, creation/editing forms, previews, templates and publication status. The recorded Tools flow shows irregular component proportions and a generic error when returning/reopening page creation. Diagnose the real cause using Flutter/network/backend traces rather than replacing it with another vague message.

Correct AppBar titles, section hierarchy, page-type selectors, form fields, counters, buttons, platform controls, image picker, card spacing, shadows, RTL rendering, keyboard insets, scroll jumps, selection states, and loading/error UX. Standardize with the other Proxo screens without flattening purposeful differences.

Inspect at minimum:

- `proxo_app/lib/screens/tools_screen.dart`
- `proxo_app/lib/services/proxolink_service.dart`
- Related page models, templates, previews, validators and authorized APIs.

## 18. Three independently functioning page types

Verify **Contact**, **Restaurant/Order** and **App Download** page types. Preserve the established shared top profile area while mapping labels and data correctly to each type: image/logo/icon, name, biography, buttons and provider requirements. Preserve **distinct stable public page UUIDs**, never expose an account UUID as a public page identifier.

Test type selection, name/bio validation, picture upload, platform-button configuration, template/theme, preview, create, save, edit, publish/moderation state, refresh, copy/share, deactivate/delete where supported, and back navigation. Do not leave visible buttons inert. Make draft recovery and retries safe against duplicate creation.

## 19. Tools failure, state, and caching

Investigate API auth/session expiry, provider validation, template catalog retrieval, image-upload errors, request cancellation, stale async responses, errors after back/reopen, repeated initialization and incorrect state restoration. Explain the real error and recovery actions in Sorani without revealing tokens, account secrets or internal stack traces to end users.

Where beneficial, reuse valid template or page data, cancel obsolete work, preserve draft/scroll state and refresh after mutation. Do not cache stale permissions, user-specific data after logout, or publication/moderation status indefinitely.

---

# PART VI — Mandatory precise measurement after EVERY changed section

## 20. Measurement policy: baseline and final measurements

**Precise layout measurement is a required deliverable for every modified screen, component group and relevant UI state.** Measurement must not be substituted by subjective statements (“balanced”, “fixed”, “looks good”), and it must not be satisfied merely by running unit tests.

**Before editing**, record the current rendered baseline in reproducible conditions: device model/emulator, viewport in logical dp and physical pixels, pixel ratio, OS, Flutter/build mode, text scale, locale/direction, theme, keyboard state, dataset/test fixtures, navigation path and screenshot file/recording timestamp.

**After editing**, record the same information under equivalent conditions. Choose final component sizes from evidence; then document their actual measurements and compare against the verified intended design and shared tokens. Do not invent numbers.

For every changed section measure as relevant:

- Exact component bounding box (x, y, width, height) in logical dp; physical pixels when needed for screenshot parity.
- Left/right/top/bottom screen margins and safe-area offsets.
- Section-to-section, heading-to-content, row-to-row and divider-to-content spacing.
- Card internal padding, radii, borders, separators and shadow bounds when material.
- AppBar size, title placement/centering, icon alignment, label/value baselines.
- Text font family, actual effective size, weight, line height, wrap lines and whether auto-scaling occurred.
- Button/hit-region dimensions, focus/hover/disabled/loading layout and touch accessibility.
- Banner/card image aspect ratio, crop behavior, visible content bounds and layout shifts during loading.
- Total scroll extent, first viewport composition, sticky/footer/bottom-nav overlap, keyboard reflow.
- PDF page dimensions, print margins, content bounds, row/section placement and text sharpness/RTL output.

Use geometry inspection, Flutter DevTools/RenderObject diagnostics, structured widget tests, calibrated screenshot overlays or equivalent reproducible techniques. Document method and units for each measurement.

**Do not prescribe final dimensions in advance.** The aim is accurate and justified choices, not hardcoding the numbers from an arbitrary example.

## 21. Per-section visual measurement register (mandatory)

Maintain a register for **every changed section**. Use a table equivalent to:

| Screen / state | Component or relationship measured | Before (actual value + unit) | After (actual value + unit) | Delta | Intended relationship / reason | Visual evidence ID | Pass / fail |
|---|---|---|---|---|---|---|---|
| Home / loaded | Header to top banner gap | | | | | | |
| Home / loaded | Banner to quick actions gap | | | | | | |
| Home / loaded | Three image-card dimensions and title alignment | | | | | | |
| Home / loaded | Best Results banner to selected ad cards | | | | | | |
| History / populated | AppBar typography and card bounds | | | | | | |
| History / populated | Card padding and row layout | | | | | | |
| Receipt / top-up | Each section heading, row and divider gap | | | | | | |
| Receipt PDF / exported | Page geometry, margins and content bounds | | | | | | |
| Ad Creation / keyboard open | Field position, focus and visible area | | | | | | |
| Ad Confirmation / error | Status hierarchy, controls and safe footer | | | | | | |
| Tools / page creation | Selector and form hierarchy | | | | | | |

**Expand this register with all actual changed components, not only the example rows above.** No modified section may be marked visually complete with an empty or guessed measurement entry.

Measure and inspect the **whole affected screen** after each local change, because changing a shared heading or row can shift surrounding regions. Verify both local geometry and overall composition. If a change affects multiple screens, measure all consumers.

## 22. Screenshot comparison, pixel precision and baselines

Collect **before/after full-screen captures**, relevant scrolled states, interaction recordings and comparison overlays for every modified area. Normalize device, pixel ratio, UI state, data, timing, fonts and screenshot capture method.

Distinguish these cases:

1. **Intentionally redesigned regions:** old screenshots must differ. Review the actual geometric changes and compare the final capture with an **approved updated target/reference baseline**, not the obsolete original pixels.
2. **Unchanged regions/screens:** preserve existing visual pixel parity where the baseline and device/environment are identical; investigate unexpected differences.
3. **Dynamic regions:** use deterministic fixture data/states when possible and report any unavoidable nondeterminism rather than masking visual defects.

Do not lower thresholds, add arbitrary screenshot tolerances, mask content, or silently regenerate goldens to hide differences. When the project enforces zero-pixel acceptance for relevant unchanged or approved-baseline components, keep that standard. For deliberately changed screens, obtain an explicit review/approval of the new baseline and then check against it precisely.

Inspect clipping, overflow, baseline misalignment, unexpected text shrinkage, excessive whitespace, inconsistent radii, shifted dividers and incorrect RTL/LTR rendering. Record screenshots with identifiable device/state labels so findings are independently reviewable.

**A precise measurement report must say what was measured, how it was measured, what changed and whether the outcome met its explicit criterion.** Do not assert pixel-perfect results without executing the required pixel comparisons.

## 23. Responsive and accessibility verification

Test a representative range of **actual available devices/viewport sizes** (small, medium, large; typical Android densities) and multiple system text-scale configurations, including the app's supported limits. Test with and without keyboard, with long Sorani labels, LTR codes, loading/error states and expanded panels.

Verify no unexpected overflow/clipping, touch-target problems, bottom bar overlap, excessive layout movement or inaccessible controls. Document responsive cases and any device-specific limitations. Use measured bounds rather than assuming a screen is responsive because it builds.

## 24. Runtime measurements separate from visual precision

Where profile builds and appropriate devices are available, collect **tap-to-first-visible-frame**, **tap-to-interactive-readiness**, UI/raster frame times, jank, memory, CPU where relevant, and state/caching behavior. Define readiness per screen and keep before/after conditions equivalent. Record P50/P95 when sufficient samples exist. If real profiling is unavailable, explicitly state that runtime speed remains unmeasured; do not present passing tests or static screenshots as proof of faster navigation.

Visual measurement (geometry/pixels) and runtime measurement (time/performance) are different deliverables; report both honestly.

---

# PART VII — Execution, test matrix, safety and final handoff

## 25. Mandatory implementation sequence

1. Confirm current repository, branch, HEAD SHA and PR #7 state.
2. Inventory provided images/videos and match each reported issue to a screen/state/reproduction step.
3. Inspect actual source and all relevant shared components/data mappings.
4. Establish screenshots, geometry register and reliable runtime baselines where possible.
5. Categorize each issue: confirmed functional bug, confirmed visual defect, already correct, or unverified.
6. Implement minimal, justified fixes on a safe isolated development branch.
7. After **each changed section**, measure geometry, review the full affected screen, inspect before/after evidence, and test affected interactions.
8. Re-run adjacent/shared-component consumers and check for unintended regressions.
9. Export and inspect actual transaction PDFs independently.
10. Run applicable Flutter static analysis, widget/integration tests, responsive tests and project-specific checks.
11. Run authorized runtime flows on suitable Android devices/emulators; isolate tests from production charges and user data.
12. Update goldens only for deliberate approved visual changes; preserve zero-pixel criteria for unaffected baselines.
13. Produce exact file list, evidence, outcomes, limitations and unresolved items. Do not claim completion while reproduced defects remain open.

## 26. Required coverage — functional and visual

| Screen / flow | Required test states |
|---|---|
| Home | First load, loaded, empty results, slow images, warm return, banners, **exactly 3** quick actions, selected ad cards, scrolling |
| Transaction History | Populated, many records, empty/error/loading, different amounts/statuses, scrolling, refresh, navigation |
| Transaction Details | Different transaction types, long IDs, missing values, currencies, small/large text, copy and PDF button |
| PDF | Actual exported examples, different record lengths/types, RTL shaping, viewer/print geometry and data parity |
| Advertisement Creation | All fields/dropdowns, keyboard, unexpected focus bug, targeting, schedule, budget, errors and quotes |
| Advertisement Confirmation | Countdown, processing, success, insufficient funds, uncertain outcome, back/edit, safe retry, expansion, scroll |
| Payment/backend | Authorized wallet/FastPay test scenarios; idempotency, no duplicate charge, correct RPC and RLS behavior |
| Tools | All 3 page types, form validation, upload, template/preview, save, edit, publish status, errors, reopen/refresh |
| Shared components | RTL, font scaling, navigation, memory/subscription lifecycle, unaffected-screen visual regression |

If a test cannot run, record exactly **why**, what configuration/evidence is missing, and what can still be verified independently. Do not replace the test with a success claim.

## 27. Strict safety and repository constraints

- **Keep PR #7 Draft, Open, Unmerged.** Do not merge automatically.
- **Leave production deployment and production database/financial data unchanged.** Do not apply unrelated or unapproved production migrations.
- No weakening of Supabase RLS, authorization, authentication, wallet protections or user-data isolation.
- No unrestricted direct INSERT into `pa_ads` as a workaround for RPC or permissions problems.
- No duplicate ad/payment submissions, fraudulent or invented transaction values, unapproved real test payments or irreversible operations.
- Preserve existing working features, verified business rules, data freshness and moderation behavior.
- Do not disclose credentials, secret tokens, full sensitive logs or user data in reports/screenshots.
- Avoid broad formatting rewrites, speculative optimization or unnecessary architecture migration.
- Do not claim passing Flutter builds/tests, screenshot parity or APK creation demonstrates runtime performance improvement.

## 28. Mandatory final reports and deliverables

### A. Issue-to-fix report

| Area | Reproduced defect | Root-cause evidence | Exact changed files / change | Functional test result | Visual measurement evidence | Remaining risk |
|---|---|---|---|---|---|---|
| Home header and top banner | | | | | | |
| Home — exactly 3 image quick actions | | | | | | |
| Home Best Results banner + selected ad cards | | | | | | |
| Transaction History cards and AppBar | | | | | | |
| Transaction receipt details and currency mapping | | | | | | |
| PDF layout/export | | | | | | |
| Advertisement Creation form, focus, keyboard | | | | | | |
| Advertisement Confirmation visual layout | | | | | | |
| Advertisement submission/retry/insufficient funds | | | | | | |
| Tools page types and page-builder UI | | | | | | |
| Tools loading, API failures and page management | | | | | | |
| Shared tokens, RTL, responsive and caching | | | | | | |

### B. Exact measurement register

Attach the fully populated **per-component before/after measurements** described in Sections 20–22 for every modified section, using actual units and deltas, plus complete capture metadata. **Do not omit or hand-wave this evidence.** Include before/after whole-screen images and annotated overlays or equivalent repeatable geometry proofs.

### C. Runtime and regression results

Report actual commands/tests, counts, device/test environment, build/commit IDs, screenshot/golden comparison outcomes, PDF artifacts, navigation scenarios, and runtime before/after metrics where available. Distinguish code-level checks, actual visual verification and real performance measurements. Never fabricate unavailable results.

### D. Change and handoff summary

Provide the exact list of files modified, what was intentionally left unchanged, open limitations, risks, unresolved issues, PR status and production status. Include a link or artifact for updated screenshots/recordings and sample PDF exports when available.

## Final acceptance conditions

This work is **not complete** until:

1. Home has the requested **top image banner**, **exactly three image + Sorani title quick-action cards**, and a **Best Results image banner with real selected ad cards** beneath it, all visually balanced and functional.
2. Transaction History cards and AppBar are readable and correctly proportioned.
3. Receipt headings, rows, dividers, logo, spacing, values and PDF action form a coherent visual structure.
4. Actual exported PDFs have been opened, measured, visually inspected, and found acceptable against an approved print layout.
5. Financial values/units across history, receipt and PDF are semantically accurate, without altering historical transaction data for cosmetics.
6. Advertisement Creation is visually consistent, and unrelated selections no longer focus the video URL/code field.
7. Advertisement Confirmation is visually coherent and handles pending/success/failure/insufficient balance/unknown outcomes safely, without trapping users or double charging.
8. Tools and all three ProxoLink page types work correctly, with repaired form layout, proper errors, successful create/edit/preview workflows and user-data isolation.
9. Every **changed section and affected shared-component consumer** has an actual, fully documented **before/after precise measurement and visual review**, including responsive states.
10. Applicable automated tests and real supported runtime scenarios have been performed, with honest results and clearly identified remaining limitations.
11. PR #7 remains Draft, Open, Unmerged, and production remains unchanged.

**Final instruction:** Do not invent or hardcode visual dimensions from this document. Derive balanced sizing through the current Proxo design system and actual reference evidence; once changed, measure every affected layout precisely, verify it at screen and document level, fix any deviations, and only then report the work as complete. Implement the work, not merely describe it.


## Subsequent user override
The user's latest direct instruction is: “not use image for quick actions”.
The three actions therefore use native icons plus Sorani titles. This overrides
the image-card clauses above only; banners and actual selected result cards remain in scope.
