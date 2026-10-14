# Proxo UI remediation and icon audit — review in progress

**Acceptance: pending.** This is an implementation with verification evidence in progress, not a claim of pixel-perfect completion. PR #7 remains Draft/Open/Unmerged. No production deployment, database change, financial record edit, real charge, or authorization change was performed.

The latest direct user instruction, “not use image for quick actions”, overrides the image-card clauses of the attached specification. Exactly three primary actions use native icons and Sorani labels: Create Advertisement, Add Balance, Create Page. Other banner requirements remain applicable.

## Baseline and reproducibility

Repository: `Zana-Sponsor/proxobalance`; branch: `feat/proxolink-private-renderer-migration`.
Immutable source baseline: `b77ec5202ed37c179fa52c4c447a4c3719a4c9d8`.
The supplied screenshots are visual references; their exact source build cannot be proven. The original four JPEG paths are unavailable; the inline images remain inspectable. The latest attached specification is preserved in `UI_REMEDIATION_SPEC_2026-10-14.md`.

The new `UI remediation evidence` workflow checks out baseline and candidate independently and runs the identical capture harness. It records actual production widgets, full viewport and scrolled-bottom PNGs, exported PDFs, and RenderBox/RenderParagraph measurements. Baseline captures are reconstructed from the immutable source after implementation, not falsely described as captures made before editing. Fixtures are fictional and transports reject real backend access.

Conditions: Flutter 3.47.2, Linux widget-test renderer, Rabar_021 + bundled Material font, 852 logical-pixel viewport height; width/text-scale/DPR cases 280/1/1, 393/1/3, 393/2/1, 768/1/2. These are **not native Android device or profile measurements**. Geometry uses logical pixels; PNG dimensions multiply by recorded DPR. New captures are unapproved references, not replacement goldens. No pixel threshold or golden tolerance was relaxed.

Local Flutter startup was rejected by automatic approval review because it attempted access to a sensitive cloud instance-metadata endpoint. That startup was not retried or bypassed. GitHub CI uses the project's established hosted Flutter setup. The downloaded standalone Dart runtime was usable offline: 24 assertions passed against the actual historical-money projection source. That check is not a Flutter build or visual verification.

## Global icon audit: six requested points

| Point | Implementation / decision | Evidence and limit |
|---|---|---|
| 1. Inspect existing | 258 non-comment lexical glyph references in 36 Dart files; 55 local PNG/SVG icon assets. Inspected the raster contact sheet, package declarations, semantic registry and component groups. | `icon-inventory-2026-10-14.json`; reproducible `proxo_app/tool/audit_icon_inventory.py`. Lexical references are not a count of rendered icons. |
| 2. Research / licensing | Reused Flutter's bundled Material glyphs. Google's official Material source identifies Apache-2.0. No downloaded icon assets or dependencies. | https://github.com/google/material-design-icons ; https://developers.google.com/fonts/docs/material_icons . Existing custom raster provenance was not supplied; no new rights claim is made for it. |
| 3. Consistency | Three primary actions share outline glyphs, 24 logical-pixel icon box, existing 48-pixel accent well, shared AdUi card padding/radius, native Sorani labels and disabled treatment. Labels reflow using actual font metrics. Receipt controls use the existing app typography roles, 20-pixel glyphs and 48-pixel targets. | Values derive from existing component tokens/navigation conventions and accessibility; rendered measurements still require completed capture review. |
| 4. Quick actions | Latest instruction applied: native icons + titles; no images. Tools and FAQ remain secondary links. All three routes are wired; Add Balance uses DepositScreen. | `home_quick_actions.dart`, Home callbacks and both MainShell Home constructors. |
| 5. Flutter integration | No package changes, no new icon asset files, no runtime icon website requests. RTL labels and explicit LTR values retained. Existing bottom-nav PNG outline/fill mappings preserved, including deliberately reversed `user`/`widget` filenames. | Existing SVG Solar-linear Sidebar, Solar-outline Profile and branded/provider FontAwesome groups retained. |
| 6. Verification | Added responsive action/callback, disabled-state and currency tests; baseline/candidate screenshots and PDF capture harness. Existing tests updated for intentional native-size wrapping rather than the obsolete shrinking contract. | Final CI results and visual review must be recorded before acceptance. Native Android touch/accessibility and real profile measurements remain outstanding. |

### Exact icon changes

| Location | Before | After | Reason/source |
|---|---|---|---|
| Home create ad | `Icons.add_rounded` | `Icons.campaign_outlined` via `ProxoIcons.createAd` | Distinguish advertisement creation from unrelated add actions; bundled Material, Apache-2.0. |
| Home add balance | Missing primary action | `Icons.account_balance_wallet_outlined` via `ProxoIcons.wallet` | Required top-up destination; same family/license. |
| Home create page | `Icons.add_link` | `Icons.add_link_outlined` via `ProxoIcons.createPage` | Outline group consistency; same family/license. |
| Home secondary pages | `Icons.link_rounded` | `Icons.link_outlined` via `ProxoIcons.pages` | Preserve page-management access, same family/license. |
| Home FAQ | `Icons.question_mark_rounded` | `Icons.help_outline_rounded` via `ProxoIcons.help` | Recognizable help action, same family/license. |
| Confirmation failure/unknown | Countdown graphic remained visible | `Icons.info_outline` in the existing status region | Failure/unknown is not countdown progress; bundled Material, Apache-2.0. |
| Shared receipt back/refresh | Existing Material glyphs | Glyphs preserved; size/target and disabled back color corrected | No replacement asset. |
| Bottom center add | Existing custom-painted plus | Drawing preserved; added localized button semantics | Accessibility only; no pixel change intended. |

**Asset files added/replaced: none.** `pubspec.yaml` and lockfile remain unchanged. Retained icon groups: nav PNG pairs; Sidebar Solar Linear; Profile Solar Outline; Tools Material outline controls; existing transaction/status and provider brand marks. Some unused raster artwork has different stroke weights; no speculative wholesale replacement was made.

## Specification coverage, point by point

| Specification | Change / result | Remaining acceptance work |
|---|---|---|
| 1 Global language | Shared receipt rows stop shrinking; app typography roles reused. | Review all shared consumers at all supported scales. |
| 2 AppBars | ReceiptAppBar title 13→16, glyph 16→20, target 44→48; disabled back visible as disabled. This reaches History, transaction/ad receipts, ad form/confirmation, Tools/page creation. | Rendered centering/spacing register. |
| 3 Home order | Header → existing configurable ProxoBanner → exactly three actions → real selected-results section → expandable existing overview metrics. | Populated configured banner/real-thumbnail fixtures, full-screen visual review. |
| 4 Routes | Create Ad, DepositScreen, Tools(initialCreate:true); secondary Tools and FAQ retained. | Native back/state/keyboard journeys. |
| 5 Top banner | Reuses existing Firebase/Supabase banner/cache/lifecycle. Known routes mapped, HTTPS external targets validated, unsupported targets get recoverable message. | Actual configured promotional artwork is not supplied; existing static fallback is retained, not invented. Loading transition geometry still to measure. |
| 6 Best Results | Existing selected ad carousel retained; real first selected thumbnail introduces the group when present. | Records without a thumbnail have no fabricated feature image. Missing-thumbnail/failed-image presentation and all data states need visual review. |
| 7 Home states | Existing refresh/cache/controller behavior retained. | Full first/warm/slow/offline state matrix. |
| 8 History | Amount separated from time/date; transaction label and nonsettled state exposed; no FittedBox shrinking. | Actual large datasets/scroll, runtime screen evidence. |
| 9 Receipt | Responsive full-width surface, wrapping label/value rows, complete copyable IDs, native hierarchy and explained missing fields. | Whole-screen measurements and review of every affected consumer. |
| 10 Money | Removed numeric-magnitude currency inference, current-rate ad-price fallback, reconstructed wallet history, and pending→approved coercions. Historical amount conversion requires explicit currency and stored FX. Verified wallet snapshot writers preserve USD decimals. | Legacy records without proven units display unavailable. Audit other legacy writers before populating more historical balances; no database history was rewritten. |
| 11 PDF | Flutter-shaped raster preserved at 4x; A4 pages, half-inch printable margins, row-aware page breaks, section heading kept with first row. | Open and inspect actual generated files; exceptionally tall atomic rows may scale on their own page. No searchable-text PDF claim. |
| 12 Ad form | Shared readable heading and focus fixes; existing fields/validation retained. | Whole form visual matrix. |
| 13 Focus | Dismiss existing focus for text outside-taps, choices, dropdown taps, age selection, date/time selection. | Android keyboard reproduction for every control, not just source review. |
| 14 Confirmation | Error/unknown heading and icon now distinguish uncertainty from ready/progress. | All rendered state captures. |
| 15 Recovery | Uncertain failure permits safe return while frozen request/id remains persisted; same-ID retry preserved. Verified insufficient available/required USD amounts shown. | Native background/restart and isolated FastPay journeys. No RPC/RLS/payment changes. |
| 16 Ad tests | Existing wallet/FastPay repository tests retained; uncertain safe-navigation test added. | Final current-source test outcome and authorized real runtime. |
| 17 Tools | Shared AppBar/receipt token improvements reach Tools/create flow. Existing controller and API behavior retained. | Recorded generic reopen error lacks network trace; no speculative backend fix claimed. |
| 18 Three page types | Existing Contact/Restaurant/App Download and stable page UUID contracts retained; existing tests run in CI. | Live create/upload/edit/preview/publish with isolated staging accounts. |
| 19 Tools failures/cache | Existing owner isolation/mounted guards retained. | Actual failing trace and missing isolated staging settings. |
| 20–21 Measurements | Harness records bounds/font data per screen/state; baseline and candidate kept separate. | Complete actual before/after register from successful artifacts; no guessed measurements. |
| 22 Pixel comparison | No automatic golden replacement or relaxed threshold. | Review intended changes; exact parity for unaffected regions. |
| 23 Responsive/accessibility | Four rendering configurations; action reflow/tap tests; plus semantics and disabled back state. | Native Android densities/TalkBack/keyboard. |
| 24 Runtime profiling | Not measured. | Profile-mode P50/P95/frame/memory traces; test speed is not product latency. |
| 25–26 Sequence/coverage | Source inventory and targeted code implemented; CI baseline/candidate checks in progress. | Incomplete states remain explicitly open. |
| 27 Safety | PR Draft/Open/Unmerged, no production or financial mutation, no weakened authorization. | Maintain these constraints through review. |
| 28 Handoff | This report, original specification, icon manifest, tests, workflow and artifacts. | Final rendered evidence and acceptance review. |

## Measurements and approval

The baseline/candidate JSON files are the source for actual per-component bounding boxes. A source token change is not a rendered measurement. Until those artifacts are collected and inspected, no row is marked visually complete and no empty measurement is presented as a pass. No approved updated target exists yet; new screenshots need review before exact golden acceptance.
