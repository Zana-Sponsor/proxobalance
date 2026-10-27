> **Historical visual evidence:** this appearance was rejected in the later 25 October prompt. Use the [new balanced UI correction](../tiktok-balanced-ui/implementation-report.md) for the current design.

# TikTok Create Ad — strict v3 implementation and verification

Source baseline: `4e755dd8c48b248df6b6534f63388d4cb693e376`. The already-published historical gallery is parent commit `d1e1eba6d5d0dc6a95c399263a5061064d8ad713`; this strict-v3 report and its new screenshots are separate from that earlier evidence. The [supplied specification](specification.md) is preserved verbatim. This report separates source implementation, automated fixture evidence, and live production acceptance.

**Initial full validation at `b6bdac7`: 1,318 Flutter tests passed, 0 failed, 1 intentionally skipped.** The 85-case focused regression, 313 Node tests, and 33 isolated PostgreSQL checks also passed. All 34 requested screenshots were captured and visually reviewed. A final 9-test capture/control rerun passed after waiting for the fallback bitmap to decode; production source stayed unchanged from the full-suite run. The follow-up review below adds 186 passing focused tests and 10 passing narrow-screen confirmation tests. Production release and physical-device acceptance remain outstanding as described in item 28.

| # | Requested report item | Implementation and evidence |
|---|---|---|
| 1 | Exact files changed | [Exact intended file manifest](changed-files.txt), relative to publication parent `d1e1eba`. Generated SDK/platform artifacts and historical preview regenerations are excluded. |
| 2 | Shared components | `AdFormSection` and `AdChoice` have opt-in variants; their standard Meta appearance remains the default. Receipt widgets and bottom-navigation implementation are unchanged. |
| 3 | Flat sections | TikTok uses `AdSectionStyle.open`: no outer fill, border, shadow, or inset padding. Existing default sections keep their cards. |
| 4 | Two choice systems | `AdChoiceStyle.primary`: gray text/border when inactive, solid blue/white text without a visible border when selected. `secondary`: black text/gray border when inactive, pale blue/blue text/blue border when selected. Both animate 180 ms with easeOutCubic; control tests assert exact color roles and unchanged geometry. Captures 03–14 demonstrate their separate states. |
| 5 | Exact ad-type labels | `نامە و پەیوەندی`, `بینینەکان`, `خواردنگە`, `دابەزاندنی ئەپ`. The same typed selection is shown on confirmation; legacy and Meta labels retain their existing behavior. |
| 6 | Conditional behavior | Contact exposes two destinations; Direct Message exposes the account/video picker; views omit pages; restaurant and app download expose only order/download resources. TikTok ad type is retained in the draft contract. |
| 7 | Contact destination | `هەموو پلاتفۆڕمەکان` and `نامەی تیک تۆک` use secondary controls. Compatible same-selection taps preserve the existing resource. |
| 8 | Platform icons | Existing bundled brand assets render the selected contact page's supported communication channels; a neutral link appears before selection. TikTok uses its bundled brand logo. |
| 9 | Page accordion | Compact disclosure expands with 180 ms size/rotation transitions. Choosing a page preserves it when collapsed and reopened. |
| 10 | Image, name, status | Rows show stored names and mapped stored publish/status values. HTTPS avatars use a fixed square image area; missing/failed images use the explicit Proxo fallback. State 17 verifies an actual HTTPS `Image.network` decode with an intercepted fixture image; states 16/18/19/20/30 verify the bundled fallback. Page-name/status text retains accessibility scaling. |
| 11 | Resource filtering | Repository queries enforce authenticated owner, actual page kind, active/ready state, and nonarchived records. Server submission eligibility validates matching page kind again. |
| 12 | Wealth/category field removal | TikTok no longer renders `جۆری پۆل`; removed UI is not required by TikTok client validation. |
| 13 | Device field removal | TikTok no longer renders `جۆری ئامێر`; its draft uses the safe all-devices value. |
| 14 | Automatic ad name | New TikTok sessions use `New Ad DD-MM-YYYY`. Temporary create-page navigation preserves edits; durable pending recovery preserves its original request title. |
| 15 | Typography and spacing | Open sections use medium hierarchy, moderate corner radius, small control shadows, and equal measured choice heights at large text sizes. |
| 16 | Floating final price | The price panel is positioned above the existing bottom navigation, with content clearance and a restrained shadow. |
| 17 | Expand and collapse | Icon disclosure expands details upward; the total remains pinned while long details scroll. Collapse retains the same bottom anchor and navigation position. Narrow layouts stack the complete monetary value under the label; keyboard tests verify actual Sponsor reachability. |
| 18 | Price loading | TikTok hides stale totals during recalculation and displays a compact loader. Revision checks reject late quote responses. |
| 19 | Sponsor separation | `سپۆنسەرکردن` remains a normal form button outside the price panel. |
| 20 | Failed-submit reset | Definitive failure is returned explicitly on Back/Cancel and cleared from form recovery. A durable terminal marker prevents failed storage removal from resurrecting the request. Unknown outcomes retain recovery. |
| 21 | Duplicate protection | Checkout disables while opening; pending/reconciliation preserves the original request identifier. Existing atomic server submission remains in place. |
| 22 | Page creation error | Failed saved publication remains editable and retries the same page/request. Only an authoritatively available page returns as success. Typed create routes lock the correct page kind. |
| 23 | Page persistence | The creation flow uses the server save contract and refreshes the filtered repository list. Fixture screenshots prove UI return behavior, not a live production write. Database/API tests separately verify server eligibility and atomicity. |
| 24 | Navigation | Create Page pushes directly from Create Ad; Back pops to the existing form; successful save returns and selects the refreshed compatible page. |
| 25 | Tests executed | Follow-up: **186 focused tests passed**, plus **10 final confirmation tests at 280px / 200% text** (overlapping counts). Initial focused regression: **85 passed**, including all 34 captures, primary/secondary matrix, fixed geometry, quote races, page return, failure reset, long rows, and keyboard/Sponsor gestures. Final full suite: **1,318 passed, 0 failed, 1 intentionally skipped**; includes Meta, navigation/payment, and receipt reference/parity checks. |
| 26 | Screenshots | **All 34 requested states are captured** by the actual Flutter widget renderer using controlled repositories. Each has a PNG, SHA-256, dimensions, and requirement/test mapping. See the [evidence gallery](../evidence/tiktok-strict-v3-2026-10-25/README.md). |
| 27 | Screenshot review | **All 34 originals reviewed** through six labeled contact sheets, with full-size checks of main, selection, avatar, final price, Sponsor, and narrow views. Discovered money splitting, keyboard overflow, and fallback-logo clipping were fixed before final captures. No remaining captured-state overflow or mixed control color roles was found; existing large-text navigation scroll is retained. |
| 28 | Remaining blockers | Physical Android and authenticated live TikTok/page persistence remain unverified. The new database migration is unapplied and explicit production write flags have not been enabled by this patch. Production release and acceptance remain separate outstanding steps; the historical 24 October configuration-only attempt was rolled back. The [24 October readiness record](../evidence/tiktok-dm-2026-10-23/production-readiness-2026-10-24.json) reports `TIKTOK_DM_BACKEND_ORIGIN_NOT_CONFIGURED`: both backend-origin variables and dedicated worker credentials were missing. The attempted connection workflow was unpublished again; the remaining six workflows stayed inactive. No new live production check was performed on 25 October. See [page persistence/release details](../tiktok-dm/strict-v3-page-persistence.md). |

## Automated verification

The [machine-readable verification record](verification.json) contains completed command outcomes and evidence hashes. The final full suite completed successfully in 3m22s: **1,318 passed, 0 failed, 1 intentionally skipped**.

| Check | Observed result |
|---|---|
| Full Flutter suite | 1,318 passed; 0 failed; 1 guarded-staging case skipped |
| Final capture/control rerun | 9 passed after fixture-only fallback decode wait; production source unchanged from full suite |
| Focused UI regressions and captures | 85 passed; no hit-test warnings |
| Submission, confirmation, storage, recovery and repository regressions | 74 passed (included again in full run) |
| Typed resources, direct creator and creation recovery | 42 passed (included again in full run) |
| Full Node suite, `npm test` | 313 passed, 0 failed |
| Isolated PostgreSQL eligibility/atomicity script | 33 checks passed |
| `npm run lint` and `npm run build` | Passed; build verified 17 assets |
| `git diff --check` | Passed after final evidence generation |
| QA test-file analyzer | No issues after removing one unnecessary import |
| UI/service scoped analyzers | No errors/warnings; UI retains existing interpolation-style info |

Runtime: Flutter **3.47.8**, Dart **3.13.7**, Linux `flutter_tester`. `pub get --enforce-lockfile` passed and did not change `pubspec.lock`. The runtime setup used this compatible SDK after the pinned 3.47.2 setup failed; no claim is made that 3.47.2 was tested locally.

The first full run found five failures: missing visible insufficient-balance feedback, one obsolete wrapper assertion, and three cases of a decorative fallback word clipping at large text. The implementation now emits shared payment feedback and uses a fitted bundled fallback image; the name test checks actual label/order. The subsequent 85-case regression passed. The cancel test also enters a distinct edited name and verifies that exact name in confirmation and after Cancel. The final full rerun passed all 1,318 executed cases. All 15 regenerated historical tracked PNGs were restored to the published parent; receipt renderer/reference sources and tracked historical PNGs have no diff.

The one expected skip is `test/staging_transport_test.dart`, “staging foreground/background push helpers avoid Firebase and tokens”: it requires the complete guarded staging-build defines. No live push test was implied.

Commands (from `proxo_app/`, using the installed Flutter executable or direct tool snapshot):

```sh
flutter --no-version-check test --no-pub --concurrency=4 --reporter expanded
flutter --no-version-check test --no-pub --concurrency=4 --reporter expanded test/tiktok_strict_v3_controls_test.dart test/tiktok_strict_v3_form_test.dart test/ad_creation_flow_test.dart test/tiktok_dm_form_test.dart test/responsive_ad_ui_test.dart
```

Backend commands (repository root):

```sh
npm test
npm run lint
npm run build
PGLITE_MODULE=/workspace/scratch/43a583048faa/pgtools/node_modules/@electric-sql/pglite/dist/index.js node scripts/test-tiktok-typed-pages-database.mjs
```

## Follow-up review — 25 October 2026

The second point-by-point review repaired the malformed Android fixture edit on the newer branch. The test now checks the generated name format and preserves the exact initial title in the saved request and after Cancel. The unused sidebar import was already removed; the exact CI screen-analysis command exits 0 with no errors or warnings. Existing informational style findings remain.

The visual review found one label mismatch: typed restaurant/app-download choices were still summarized as generic messages on confirmation. Confirmation now uses the same four requested labels, with `جۆری ڕیکلام` as the row heading. Meta and legacy drafts retain their original labels. Six regression cases cover the four types, Meta, and legacy recovery at 280px with 200% text, including text-fit checks.

All 34 screenshots were inspected again. Re-rendering preserved 33 PNGs byte-for-byte. State 31 changes only its ad-type text: 1,659 pixels within `[64, 1014, 722, 1042)` of the 786 × 1704 image. The rest of that screenshot, the receipt reference bitmap/geometry, fonts, navigation, and form layout remain unchanged. The six review sheets and screenshot hash manifest are current.

Local follow-up verification: **186 focused tests passed**, **10 final narrow confirmation tests passed**, and **7 profile-runner tests passed**. Counts overlap. Changed-file analysis has no errors/warnings; its 13 informational findings are in the existing Android fixture. The [verification record](verification.json) includes log hashes and the measured pixel bounds. GitHub's subsequent full-suite, Android profile, and APK results are recorded on [PR #46](https://github.com/Zana-Sponsor/proxobalance/pull/46); local screenshots remain controlled widget renders, not physical-device or live-production proof.

## Evidence limits

The capture suite renders production Flutter widgets and bundled fonts at 393 × 852 logical pixels (2× PNG output), plus a 280 × 700 logical-pixel case with 200% text. API data, accounts, videos, balances, page saves and failure responses are deterministic fixtures. These are not physical Android captures, a live TikTok transaction, or proof of production deployment. No pixel reference image accompanied this markdown specification; visual acceptance is against its written state and hierarchy requirements.
