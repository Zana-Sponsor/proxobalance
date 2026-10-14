# Proxo UI remediation and icon audit — implementation and evidence

**Acceptance: pending.** This is an implemented change with reproducible verification evidence, not a claim of approved pixel-perfect completion. PR #7 remains Draft/Open/Unmerged. No production deployment, database change, financial record edit, real charge, or authorization change was performed.

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
| 3. Consistency | Three primary actions share outline glyphs, 24 logical-pixel icon box, existing 48-pixel accent well, shared AdUi card padding/radius, native Sorani labels and disabled treatment. Labels reflow using actual font metrics; 8 additional logical pixels below the secondary links contain Rabar descenders at scale 3. Receipt controls use the existing app typography roles, 20-pixel glyphs and 48-pixel targets. | Values reuse existing component tokens/navigation conventions. Actual geometry and visual review are recorded below; native Android acceptance remains separate. |
| 4. Quick actions | Latest instruction applied: native icons + titles; no images. Tools and FAQ remain secondary links. All three routes are wired; Add Balance uses DepositScreen. | `home_quick_actions.dart`, Home callbacks and both MainShell Home constructors. |
| 5. Flutter integration | No package changes, no new icon asset files, no runtime icon website requests. RTL labels and explicit LTR values retained. Existing bottom-nav PNG outline/fill mappings preserved, including deliberately reversed `user`/`widget` filenames. | Existing SVG Solar-linear Sidebar, Solar-outline Profile and branded/provider FontAwesome groups retained. |
| 6. Verification | Added responsive action/callback, disabled-state and currency tests; baseline/candidate screenshots and PDF capture harness. Existing tests updated for intentional native-size wrapping rather than the obsolete shrinking contract. | 298 focused Flutter tests and 64 capture cases per source passed; see terminal run evidence below. Visual targets remain unapproved. Selected Android emulator tap/label/keyboard/density checks now pass below; manual TalkBack and physical-device profile measurements remain outstanding. |

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

**Application icon/image asset files added/replaced: none.** `pubspec.yaml` and lockfile remain unchanged. Retained icon groups: nav PNG pairs; Sidebar Solar Linear; Profile Solar Outline; Tools Material outline controls; existing transaction/status and provider brand marks. Some unused raster artwork has different stroke weights; no speculative wholesale replacement was made.

## Specification coverage, point by point

| Specification | Change / result | Remaining acceptance work |
|---|---|---|
| 1 Global language | Shared receipt rows stop shrinking; app typography roles reused. | Review all shared consumers at all supported scales. |
| 2 AppBars | ReceiptAppBar title 13→16, glyph 16→20, target 44→48; disabled back visible as disabled. This reaches History, transaction/ad receipts, ad form/confirmation, Tools/page creation. | Actual measured register supplied; native device review remains pending. |
| 3 Home order | Header → existing configurable ProxoBanner → exactly three actions → real selected-results section → expandable existing overview metrics. | Populated configured banner/real-thumbnail fixtures, full-screen visual review. |
| 4 Routes | Create Ad, DepositScreen, Tools(initialCreate:true); secondary Tools and FAQ retained. | Native keyboard/Back fixture checks passed; full route/state/restart journeys remain open. |
| 5 Top banner | Reuses existing Firebase/Supabase banner/cache/lifecycle. Known routes mapped, HTTPS external targets validated, unsupported targets get recoverable message. | Actual configured promotional artwork is not supplied; existing static fallback is retained, not invented. Loading transition geometry still to measure. |
| 6 Best Results | Existing selected ad carousel retained; real first selected thumbnail introduces the group when present. | Records without a thumbnail have no fabricated feature image. Missing-thumbnail/failed-image presentation and all data states need visual review. |
| 7 Home states | Existing refresh/cache/controller behavior retained. | Full first/warm/slow/offline state matrix. |
| 8 History | Amount separated from time/date; transaction label and nonsettled state exposed; no FittedBox shrinking. | Actual large datasets/scroll, runtime screen evidence. |
| 9 Receipt | Responsive surface with a 600-dp maximum readable column, wrapping label/value rows, complete copyable IDs, native hierarchy and explained missing fields. | Phone/tablet, large-text and both receipt types reviewed; arbitrary live-record and native-device coverage remains pending. |
| 10 Money | Removed numeric-magnitude currency inference, current-rate ad-price fallback, reconstructed wallet history, and pending→approved coercions. Historical amount conversion requires explicit currency and stored FX. Verified wallet snapshot writers preserve USD decimals. | Legacy records without proven units display unavailable. Audit other legacy writers before populating more historical balances; no database history was rewritten. |
| 11 PDF | Flutter-shaped raster preserved at 4x; A4 pages, half-inch printable margins, row-aware page breaks, section heading kept with first row. | Exported files were opened and raster pages inspected; exceptionally tall atomic rows may scale on their own page. No searchable-text PDF claim. |
| 12 Ad form | Shared readable heading and focus fixes; existing fields/validation retained. | Whole form visual matrix. |
| 13 Focus | Dismiss existing focus for title/code/link/note/coupon outside-taps, choices, dropdown taps, age selection, date/time selection. | Android keyboard reproduction for every control, not just source review. |
| 14 Confirmation | Error/unknown heading and icon now distinguish uncertainty from ready/progress. | Ready, failure and unknown states captured at all four configurations; live gateway transitions remain separate. |
| 15 Recovery | Uncertain failure permits safe return while frozen request/id remains persisted; same-ID retry preserved. Verified insufficient available/required USD amounts shown. | Native background/restart and isolated FastPay journeys. No RPC/RLS/payment changes. |
| 16 Ad tests | Existing wallet/FastPay repository tests retained; uncertain safe-navigation test added. | Focused suite passed; authorized real Android/payment runtime remains outstanding. |
| 17 Tools | Shared AppBar/receipt token improvements reach Tools/create flow. Existing controller and API behavior retained. | Recorded generic reopen error lacks network trace; no speculative backend fix claimed. |
| 18 Three page types | Existing Contact/Restaurant/App Download and stable page UUID contracts retained; existing tests run in CI. | Live create/upload/edit/preview/publish with isolated staging accounts. |
| 19 Tools failures/cache | Existing owner isolation/mounted guards retained. | Actual failing trace and missing isolated staging settings. |
| 20–21 Measurements | Harness records bounds/font data per screen/state; baseline and candidate kept separate. | Measured CSV and compressed JSON supplied; no guessed measurements or approved target claimed. |
| 22 Pixel comparison | No automatic golden replacement or relaxed threshold. | Review intended changes; exact parity for unaffected regions. |
| 23 Responsive/accessibility | Four rendering configurations; action reflow/tap tests; plus semantics and disabled back state. | Selected native density/keyboard cases passed below; physical-device TalkBack and remaining controls/routes remain open. |
| 24 Runtime profiling | Not measured. | Profile-mode P50/P95/frame/memory traces; test speed is not product latency. |
| 25–26 Sequence/coverage | Source inventory, targeted changes, hosted widget captures and focused tests complete. | Incomplete states remain explicitly open. |
| 27 Safety | PR Draft/Open/Unmerged, no production or financial mutation, no weakened authorization. | Maintain these constraints through review. |
| 28 Handoff | This report, original specification, icon manifest, tests, workflow and artifacts. | Evidence supplied; design baseline approval and listed runtime acceptance remain pending. |

## Measurements and approval

The baseline/candidate JSON files are the source for actual transformed per-component bounding boxes. Matrix transforms include RTL reflection and the baseline FittedBox scaling. A source token change is not a rendered measurement. The register supplies before/after coordinates and deltas; added or removed components remain explicitly unmatched. No approved updated target exists yet; deliberately changed screenshots need review before exact golden acceptance.

## Verification method changes and findings

- The original four-row quick-action layout was replaced by three equal primary cards and two secondary links. On a 393-dp viewport the primary row has three 112.33333333333333-dp cards, 140-dp height and 12-dp gaps. The icon wells are 48×48 dp and the glyph boxes 24×24 dp. At 393 dp with text scale 2 the primary cards stack, preserving native font size. Native icon assets replace no image files.
- Rendered scale-3 Home text exposed a 3.623-dp descender escape below the secondary links. Product padding was corrected; the existing glyph-containment assertion and tolerance were retained. Secondary icons now use Proxo blue explicitly instead of inheriting the test host's purple seed.
- Receipt typography intentionally no longer follows the old fixed-393-dp shrinking contract. Tests now assert native font sizes, 600-dp maximum column, exact physical margins, complete IDs, row baselines, wrapping and whole glyph coverage. The old reference anchors remain in the immutable before evidence; no golden was overwritten or approved.
- Rabar wrapped selection boxes can extend 4.621 dp beyond their advance box while remaining visibly within the padded card. The test now checks the actual card paint boundary instead of falsely equating advance width with clipping. The numeric tolerance remains 0.05 dp; baseline/gap precision remains 0.01 dp. This is a changed containment criterion, explicitly documented, not an unchanged assertion.
- Tablet PDF inspection exposed unnecessary downscaling from a full 768-dp capture. The on-screen column is now capped at the existing 600-dp app content width, and export crops only the empty horizontal outer space. A 13-dp row font therefore prints at approximately 11.34 pt on that A4 case, rather than 8.85 pt. Phone capture sizes are not enlarged. PDF text is a Flutter-shaped 4x raster, not selectable/searchable text.
- The uncertainty recovery test now uses the actual visible “check the same request” control after returning to the locked form, rather than attempting to tap the deliberately disabled normal review control. Frozen request identity and submission-count assertions remain enforced.
- The expanded capture fixture now passes the receipt's real fixture UUID to AdDetailScreen. The production identity validation correctly rejected the earlier mismatched fixture; no product validation was removed.
- Captures use the production Sorani locale scope, Arabic framework-localization mapping, blue color seed, white fallback scaffold and Rabar font. Baseline alone omits the newly introduced Add Balance callback argument; both capture the available actions as enabled.

## Modified production files

| Files | Purpose |
|---|---|
| `lib/theme/proxo_icons.dart`, `lib/widgets/home_quick_actions.dart` | Reused Material outline registry, three native action cards, secondary links, adaptive layout and semantics. |
| `lib/screens/home_screen.dart`, `lib/main.dart`, `lib/widgets/best_metrics_home_section.dart` | Home composition, destination wiring and existing banner/results integration. |
| `lib/widgets/bottom_nav.dart` | Accessible label for existing center add control; preserved drawing and PNG mappings. |
| `lib/widgets/receipt/receipt_kit.dart`, `lib/widgets/receipt/tx_history_layout.dart` | Shared heading/controls, native-size receipt wrapping, readable column, history hierarchy and printable PDF pagination. |
| `lib/models/receipt_pricing.dart`, `lib/widgets/tx_history_page.dart`, `lib/screens/transaction_detail_screen.dart`, `lib/l10n/tx_strings.dart` | Explicit historical units, proven USD/IQD balance snapshots, unavailable data and transaction labels. |
| `lib/screens/ad_create_screen.dart`, `lib/screens/ad_confirmation_screen.dart` | Focus dismissal, verified insufficient-funds message, truthful failure/uncertain state and safe return. |

Paths above are relative to `proxo_app/`. No application image/SVG/icon asset, dependency, database schema, transaction writer, payment RPC or RLS policy was changed by this remediation.

## Terminal verification and review evidence

Product source last changed at `2e7f1850228f6e41dba99523c70b49e45e0fe477`; subsequent code commits refine only the capture/measurement harness and test synchronization. No product code was changed to force a screenshot match.

- [Full repository verification at 36c0581](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38608235135): **all five jobs passed** (Flutter, backend, database/RLS, edge functions, responsive). This includes the existing controlled lifecycle comparisons and APK/privacy checks.
- [Android verification APK build at 36c0581](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38608234947): **passed**. Native runtime and isolated hosted execution were **skipped**; building an APK is not running it on an Android device.
- [Settled-scroll evidence run at 80938eb](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38608968080): **64/64 capture cases on baseline, 64/64 on candidate, 298/298 focused tests**. Visual inspection caught an initial capture of a transient overscroll frame from lazy-list height estimates; the harness now settles the measured end and asserts the PDF button is visible. No scroll behavior was changed in the product.
- Eight final candidate PDFs (nine pages) were opened and rendered for inspection: transaction/ad receipt at each of the four configurations. All are A4, with at least 36-pt printable margins, complete IDs and shaped Kurdish. The large-text advertisement receipt splits into two pages between complete sections. No printer-device or selectable-text claim.
- Exact navigation image comparison: **0 changed pixels in all four configurations**. Pixel counts: 238,560; 3,013,524; 334,836; 2,617,344. The unchanged bottom navigation retains its original custom icon artwork and state mapping.
- Before/after records use fictional deterministic data. Home evidence has the existing banner fallback and empty weekly-results state, not claimed populated promotional artwork. No real payment, wallet mutation, live page publication, production migration or deployment occurred.

### Actual measurement register

[Full CSV](ui-remediation-2026-10-14/measurements.csv) · [Full JSON, gzip](ui-remediation-2026-10-14/measurements.json.gz). The CSV stores unrounded `[x, y, width, height]` logical-pixel bounds, before/after deltas and style font sizes. Font sizes are pre-text-scaling style values; transformed bounds are the painted measurement. The JSON also records exact pixel-difference counts and PDF image bounds in points. A changed pixel count is evidence, not a pass threshold.

Representative measurements below are from width 393 dp, height 852 dp, scale 1, DPR 3, unless stated. Structural tests passed; deliberately changed visual targets still require review.

| Screen / component | Before, actual | After, actual | Delta | Reason / evidence | Result |
|---|---|---|---|---|---|
| Actions / Create Ad card | 361×88 dp at (16,60) | 112.33333333333333×140 dp at (264.66666666666674,60) | width −248.66666666666669; height +52 dp | Equal three-column primary row; `actions-393-s1.0-d3.0` | Structure passed; review pending |
| Actions / Add Balance | Absent | 112.33333333333333×140 dp at (140.33333333333337,60) | Added | Existing deposit route made primary | Callback/structure passed |
| Actions / Create Page card | 361×88 dp at (16,268) | 112.33333333333333×140 dp at (16.000000000000057,60) | height +52; y −208 dp | Same row and visual weight as neighbors | Structure passed; review pending |
| Shared receipt / AppBar | 393×56 dp; title 13 sp | 393×56 dp; title 16 sp | title +3 sp; height unchanged | Larger existing typography role; centered at x=196.5 dp | Center/layout passed |
| Shared receipt / back control | 44×44 dp; glyph16×16 | 48×48 dp; glyph20×20 | +4 dp each dimension | Accessible target and optical visibility | Target/disabled-state passed |
| Transaction receipt / card | 361×322 dp at (16,72) | 361×329 dp at (16,72) | height +7 dp | Native 13-sp rows replace 11-sp shrinking layout | Wrap/ID/baseline tests passed |
| Transaction receipt / PDF button | 361×48 dp at (16,414) | 361×48 dp at (16,421) | y +7 dp; card gap remains20 | Preserve card-to-button relationship | Alignment passed |
| History / transaction card | 361×52 dp at (16,72) | 361×77 dp at (16,72) | height +25 dp | Amount gets its own readable row | Layout passed; review pending |
| Ad receipt / card | 361×619 dp at (16,72) | 361×629 dp at (16,72) | height +10 dp | Readable rows/section typography; complete IDs | Layout/PDF passed |
| Tablet receipt / card, width768 | See full transformed baseline register | 568×329 dp at (100,72) | See register | 600-dp readable column including16-dp gutters | Margin/alignment passed |
| Bottom navigation / pixels | Reference image | Identical image | 0 pixels in all4 cases | `navigation-*` screenshots | Exact pixel parity passed |

### Before and after screenshots

Original PNGs are retained without rescaling or editing. These are reconstructed baseline/current widget renders, not photographs of Android hardware. The complete artifact includes Tools, all three page types, details/editor, ad form, confirmation states, both receipts, History, Home/actions and navigation across four configurations, with scrolled-bottom captures where applicable.

| Section | Before | After |
|---|---|---|
| Home / three quick actions | [PNG](ui-remediation-2026-10-14/before/home-393-s1-d3.png) | [PNG](ui-remediation-2026-10-14/after/home-393-s1-d3.png) |
| Transaction History | [PNG](ui-remediation-2026-10-14/before/history-393-s1-d3.png) | [PNG](ui-remediation-2026-10-14/after/history-393-s1-d3.png) |
| Transaction receipt | [PNG](ui-remediation-2026-10-14/before/receipt-393-s1-d3.png) | [PNG](ui-remediation-2026-10-14/after/receipt-393-s1-d3.png) |
| Unknown submission result | [PNG](ui-remediation-2026-10-14/before/confirmation-unknown-393-s1-d3.png) | [PNG](ui-remediation-2026-10-14/after/confirmation-unknown-393-s1-d3.png) |

### Still open

1. Explicit visual approval of the intentionally changed screenshots. The attached specification §22 requires approval of a new target; none is inferred from successful tests.
2. Physical-device TalkBack and profile-mode P50/P95/frame/memory checks, plus native coverage of the remaining controls/routes/restart states. The selected Android emulator density/keyboard/back cases now pass below. Prior native WebView pixel-parity failures from the existing PR are not resolved by this icon work.
3. Isolated two-account hosted/create/upload/publish/payment journeys. The last completed audit found eight required staging settings absent; the new recheck awaits GitHub environment review, so their current presence is not yet known. Production was not substituted. The reported generic Tools reopen error still needs its failing network trace.
4. Full populated Home banner/results data, first/warm/slow/offline/error transitions and all secondary-screen states. Source audit of retained Sidebar/Profile icon groups is complete; exhaustive native visual coverage is not claimed.

PR #7 remains **Draft / Open / Unmerged**. This report does not mark the larger remediation specification complete.

### Final transformed-geometry capture run

[Run 38609756237](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38609756237), evidence source `9fb428426c90deae6acdecb39158981db9b875b4`: both jobs passed, with 64 capture cases per source and 298 focused tests. This is the source of the committed measurement register: **4,453 component rows across 106 candidate captures**, including matching baseline values where available. Baseline has 108 captures; its two additional scroll-bottom views remain in the raw artifact.

| Artifact | Contents | SHA-256 |
|---|---|---|
| [Baseline 11916164288](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38609756237/artifacts/11916164288) | 108 PNGs, 108 geometry JSONs, 8 PDFs | `786e03a5eae927ec280f6efcf63d55e133a67f7532ae075fd978d0e4a94c97d8` |
| [Candidate 11917411933](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38609756237/artifacts/11917411933) | 106 PNGs, 106 geometry JSONs, 8 PDFs | `4c5eb58419045f18bb679e516e2c7ea95cd361f2e00d44f0a205041afbf659b6` |

Both ZIP CRCs and SHA-256 digests were verified after download. All eight committed screenshot originals match the final artifacts byte-for-byte. All eight final candidate PDFs render identically to the nine inspected PDF pages. Artifact retention currently ends 12 January 2027; selected screenshots and the measurement register are committed in the repository.

**Historical preview readiness limitation, superseded by the decoded capture below:** comparison with the previous identical-product capture found six candidate and five baseline page-type scroll-bottom images with different preview-content readiness. For example, the dark Contact thumbnail is blank in one earlier capture and decoded in the later one. Those earlier page-preview images were observations, not accepted zero-pixel references. No renderer/template change or pixel tolerance was introduced.

### Decoded-asset verification — remaining capture gap resolved

[Run 38636066159](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38636066159) at `aeeda8aee7332d7b6011ece0d096a0e96903d56b` passed **64/64 capture cases on each source and 298/298 focused tests**. The capture harness now awaits the actual mounted `ImageProvider` (including resized providers), rejects decode failures/timeouts and asserts each mounted `RawImage` has decoded pixels before capture. It does not replace an image, change a template or relax a pixel comparison. Each static selector capture is read twice from the decoded boundary and must match exactly; this is same-boundary repeat verification, not a claim of independent-process reproducibility.

| Source | Verified artifact / SHA-256 | Captures | Mounted-image decode assertions | Exact static-selector repeat pairs |
|---|---|---:|---:|---:|
| Baseline | [11927454660](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38636066159/artifacts/11927454660), `13d7ddd40859c26022307843183868ef808aab18ecfe7abc5519a2327b341470` | 108 | 162 | 24 |
| Candidate | [11928052244](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38636066159/artifacts/11928052244), `29cb2c9abe7fb309c58a720b20f350201a49130cd17b91a6a2f68ef74c360b97` | 106 | 160 | 24 |

Both downloaded ZIP digests and CRCs passed. Compared with the previous capture, 12 baseline and 10 candidate PNGs now show fully decoded assets, including three navigation cases and the narrow Home logo. This corrects the earlier limitation statement, which identified only selector thumbnails. **All four newly decoded baseline/candidate navigation pairs still differ by exactly zero pixels.** The eight selected committed before/after PNGs and the entire 4,453-row CSV remain byte-identical. The compressed JSON now points to decoded captures and includes decode-readiness metadata. All eight PDFs (nine pages) were re-rendered and match the previously inspected pages pixel for pixel; PDF bounds are unchanged. See [machine-readable verification](ui-remediation-2026-10-14/decoded-capture-verification.json).

The protected staging configuration recheck was requested through its existing gated workflow. Run `38636065957`, job `116099434072`, is waiting for review of the `proxolink-preview-verification` environment. Its current secret/settings presence has therefore **not** been inspected in this attempt; the eight absent settings are the last completed audit's finding. No environment protection was removed, no secret copied, and production was not substituted.

To release that already prepared check, its required GitHub environment reviewer must use **Review deployments** on [the waiting run](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38636065957). If the last completed configuration result is still current, the environment needs `PROXO_STAGING_PROJECT_REF`, `PROXO_STAGING_SUPABASE_URL`, `PROXO_STAGING_BASE_URL`, `PROXO_STAGING_ANON_KEY`, `PROXO_STAGING_TEST_EMAIL`, `PROXO_STAGING_TEST_PASSWORD`, `PROXO_STAGING_OTHER_EMAIL`, and `PROXO_STAGING_OTHER_PASSWORD`. These identify an isolated staging project and two ordinary staging accounts; the workflow rejects substituting production or a privileged service key. Account existence/authentication has not been inferred from configuration presence.

A second independent CI capture at `a4498bc192d58b478303a4d6acf49f7e70a8cdc1`, [run 38637446819](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38637446819), reproduces **all 108 baseline and 106 candidate PNGs exactly, with zero changed images/pixels**. Both artifact digests and ZIP CRCs were verified. This includes all selector bottoms and all navigation states in the widget capture matrix. Native test-only edits separate the commits; product code and capture harness are identical. The repeat artifact IDs/hashes are in the machine-readable verification file. This establishes independent-run reproducibility for these fixture captures without approving a new design target.

### Native Android verification method and diagnostic attempts

The new credential-free workflow runs the production quick-action, bottom-navigation, transaction-receipt, Tools and advertisement-form widgets on an Android API 35 x86_64 emulator. It reuses the existing test fixture repositories and SDK `integration_test` dependency. No production startup, real account, payment, page publication or backend write is needed. Flutter taps verify the three distinct callbacks; the host sends a real ADB `KEYCODE_BACK` event only after the test observes an open keyboard. Actual physical size/DPR/keyboard insets are recorded, rather than assuming that the emulator accepted the requested dimensions. Debug-mode captures retain the debug ribbon and are not performance measurements or physical-device/TalkBack certification.

Test-only files: `.github/workflows/ui-native.yml`, `scripts/run-ui-native.py`, `proxo_app/integration_test/ui_iconography_test.dart`, `proxo_app/test_driver/ui_iconography_driver.dart`. Native screenshots use the SDK's [documented integration-test screenshot API](https://api.flutter.dev/flutter/package-integration_test_integration_test/IntegrationTestWidgetsFlutterBinding/takeScreenshot.html). No application assets or packages were added.

- Run `38636066150` failed when the harness searched for a lazy receipt PDF button before scrolling it into the tree. The harness now scrolls until the control exists and is visible, preserving its target-size assertion. Each mounted screen gets a fresh root to avoid carrying scroll state between cases.
- Run `38637443999` produced all 15 phone screenshots and recorded six distinct action callbacks, disabled-action suppression, a 595-physical-pixel keyboard inset, one actual ADB Back event, keyboard dismissal with the form retained, and choice-driven keyboard dismissal. The job still **failed**, because its test semantics handle was disposed in `addTearDown`, after Flutter's end-of-test handle verification. Cleanup now runs in a `finally` block before that verification. No accessibility assertion was removed. This failed attempt is diagnostic evidence, not a passing acceptance result.

The final native-test source at `07c3f3397b88b89d9ea237123fba3abfc2bdb0f0` also passed [full source CI 38638671927](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38638671927): all five jobs (Flutter, backend, database/RLS, edge functions and responsive) succeeded. These disposable CI checks do not execute migrations against production.

### Final native result — passed

[Native run 38638671991](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38638671991), job `116108297424`, passed all **three Android configurations** at source `07c3f3397b88b89d9ea237123fba3abfc2bdb0f0`. Artifact [11929439292](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38638671991/artifacts/11929439292) contains **45 PNGs, six observation/device JSONs and three logs**. SHA-256 `17111fe8c7998a7bd30ff4a8a1fed2e9cedbf59b41f3611bab0c74c28bdf0d92` and ZIP CRC passed. All 45 PNG dimensions match their recorded native viewport.

| Configuration | Actual physical pixels | DPR | Actual logical viewport | Observed positive IME inset, px | Actual ADB Back events |
|---|---|---:|---|---:|---:|
| Phone | 1179×1920 | 3 | 393×640 dp | 444 | 1 |
| Narrow | 840×1920 | 3 | 280×640 dp | 225 | 1 |
| Tablet | 1536×1704 | 2 | 768×852 dp | 665 | 1 |

The emulator limited the requested phone/narrow height to 1920 px; the table reports the observed result, not the requested 2556 px. IME values record the first observed positive inset during opening, not a settled keyboard height. SDK screenshots record the Flutter surface; IME behavior is verified by platform insets and actual ADB input.

Each configuration verified six primary-action callbacks across text scales 1 and 2, disabled-action suppression, accessible labels, at least 48-dp action/PDF targets, four selected navigation appearances, receipt top/bottom at both text scales, populated fixture Tools, the ad form, native keyboard opening, Back dismissing the keyboard while retaining the form, and goal-selection dismissing it. No framework layout exception occurred. The action snapshots follow the taps/ensure-visible operations, so the narrow large-text example is scrolled. This is focused native fixture coverage; it does not certify every application route or a real payment.

[Measured results and hashes for every PNG](ui-remediation-2026-10-14/native-android-verification.json). Unmodified screenshot examples: [phone actions](ui-remediation-2026-10-14/native/phone-actions-scale-1.0.png), [narrow large-text receipt/PDF control](ui-remediation-2026-10-14/native/narrow-receipt-bottom-scale-2.0.png), [tablet actions](ui-remediation-2026-10-14/native/tablet-actions-scale-1.0.png), [tablet large-text receipt](ui-remediation-2026-10-14/native/tablet-receipt-scale-2.0.png). Examples were opened for visual inspection. These are documentation evidence files, not packaged application assets.

The separate existing 240-case WebView strict pixel-parity failure, protected hosted verification, manual TalkBack, full Home data-state coverage and representative physical-device profiling remain open. No golden target was approved, no tolerance relaxed, and PR #7 remains Draft/Open/Unmerged.
