# Sidebar, profile, navigation and app bar

> Historical first-stage report. The current external SVG, language, auth, notification and native verification follow-up is in [the complete visual polish report](visual-polish-2026-10-15/README.md). The original images and source-specific findings below remain historical evidence.

Requested follow-up: use external icons, harmonize typography/size, correct observed layout/navigation/performance issues, and publish actual screenshots. Baseline is `e61144904f5f9986b8d3a2f486ca7756a3ba267a`. PR remains a draft; production is unchanged.

## Implementation

| Surface | Before | Change |
|---|---|---|
| Sidebar | Solar Linear SVG; width shrank to 78%; fonts scaled down; home always selected | Existing Solar Outline font, wider panel up to 336dp, 24dp icons, 14sp wrapping labels, current tab selection |
| Sidebar loading | Profile waited for two unused loyalty reads and the unread query | Profile appears after its own query; removed unused points/levels reads; unread fetch independent of identity display; signed-out loading completes |
| Sidebar routes | Home/help only closed the drawer | Home selects tab 0; help opens existing FAQ; settings retains profile route |
| Profile | Tight fixed quick cards/balance, text scale capped at 1.05, perpetual shine | Natural-height balance, explicit top-up control, responsive quick cards, full system text scale, no perpetual shine |
| Profile labels | Tools named “materials”; single-line truncation | “ئامرازەکان” matches navigation; wrapping names/menu labels; consistent blue and rounded surfaces |
| Bottom navigation | PNG pairs, custom plus, 11.5sp shrunk labels | Solar Outline home2/clapperboardPlay/widget_2/userRounded; Solar Bold addCircle; 24dp tab icons, 12sp labels; active blue capsule; 48dp minimum targets |
| Large-text navigation | Labels shrunk with FittedBox | Measured labels retain system size; horizontal scrolling only when five readable tabs cannot fit; selected tab brought into view |
| App bar | Mixed hand-drawn/Material icons, 36dp buttons, bell target only21dp | Solar hamburgerMenu/bell/magnifier/altArrowRight; 24dp glyphs; 48dp actions; 56dp bar; 24dp logo; descriptive semantics/tooltips |
| Notification motion | Infinite unread pulse | One pulse on count update; respects reduced motion |

No package/version change, icon download, runtime icon website, or new image asset. Uses the existing bundled `solar_icons: 0.1.0` font. Existing home quick actions remain icons and Sorani labels without images. Original raster assets remain available for untouched consumers; no unrelated template/payment/backend redesign.

### Exact icon changes

All names below are from `SolarIconsOutline`, except the emphasized central action.

| Component | Exact glyphs | Treatment |
|---|---|---|
| Sidebar | `home2`, `clapperboardPlay`, `history`, `tagPrice`, `wallet2`, `bell`, `settings`, `questionCircle`, `userRounded`, `logout` | Replaces the corresponding Solar Linear SVGs with the already installed outline font |
| Bottom navigation | `home2`, `clapperboardPlay`, `widget_2`, `userRounded` | Replaces raster navigation pairs; selected state uses color/container, keeping the same glyph |
| Central create action | `SolarIconsBold.addCircle` | Replaces the hand-drawn plus and circle; intentional 48dp primary-action emphasis |
| App bar | `hamburgerMenu`, `bell`, `magnifier`, `altArrowRight` | Replaces mixed hand-drawn and Material glyphs; the notification component shares `bell` |
| Profile balance | `addCircle` | Added to the explicit top-up button; existing `wallet2`, `eye`, `eyeClosed` retained |
| Profile About | `infoCircle` | Added for the source/license attribution row |
| Other Profile actions | Existing outline glyphs retained | Sizes/containers/spacing adjusted; no needless replacement of appropriate icons |

## Icon source and licenses

- Package: https://pub.dev/packages/solar_icons — BSD-3-Clause, © 2023 Sebastine Odeh; license retained in the dependency and `docs/SOLAR_ICON_LICENSE.txt`.
- Original artwork: Solar Icons by 480 Design, https://www.figma.com/community/file/1166831539721848736 . Original artwork attribution under CC BY 4.0: https://creativecommons.org/licenses/by/4.0/ . Attribution visible in Profile → About. Icons resized/recolored; paths not modified.
- Collection third-party notice checked: https://github.com/saoudi-h/solar-icons/blob/main/LICENSE-THIRD-PARTY . The separate solar_iconkit wrapper reports MIT; this change uses solar_icons, and does not assume that a wrapper's license replaces artwork attribution.

## Verification

Executable source: `22db3425ec15e218053c2fa5844e1fb1c08fa885`.

- [Focused capture and behavior run](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38644003380): **20/20 before captures, 20/20 after captures, 3/3 behavior regressions passed**. 35 original PNGs per side, 70 total. ZIP SHA-256 and CRC checked. All 35 baseline PNGs also reproduce byte-for-byte across an independent prior run.
- [Existing UI suite](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38644003426): both 64-case capture jobs and **298/298** candidate behavior tests passed. The harness now loads the actual Solar font as well as the app font.
- [Complete source CI](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38644003365): **all five jobs passed**, including release APK build; backend, database, edge and responsive checks passed.
- [Original before/after images](chrome-redesign-2026-10-15/README.md), [per-image hashes and verification](chrome-redesign-2026-10-15/verification.json).
- Analyzer reported no errors. Existing and retired sidebar unused declarations remain nonfatal warnings; this is not a claim of warning-free analysis.

A first regression-test attempt asserted the FAQ destination before the existing 250ms drawer-close timer had elapsed. The test now advances that fake clock by 300ms and verifies the real destination plus return to the preserved underlying route. No product navigation timing or assertion was weakened.

The 280dp / 2× text screenshots intentionally show a horizontally scrollable bottom strip. All five destinations are still reachable and individually tested; they are not claimed to fit on screen simultaneously. Long amounts also scroll horizontally so their digits stay on one line.

 `chrome_capture_test.dart` renders real production widgets at 280/393/768dp, DPR1/2/3, text1/2 with read-only fictional profile/wallet fixtures and locally loaded actual fonts. It checks callbacks, 48dp targets, visibility toggle, home navigation, and absence of the removed loyalty requests. Same capture harness runs on immutable baseline. Native suite extends existing Android checks with profile/sidebar/app-bar captures at text1/2 on three configurations. Screenshots are review evidence, not approved goldens.

Removing unused reads and idle animation is a concrete reduction in work, not a measured physical-device FPS/latency claim. Real account/payment flows, physical TalkBack/profile performance and earlier unrelated WebView strict parity blockers remain outside this focused verification.

### Native capture follow-up — historical attempts

The initial [native run](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38644003387) passed three configurations with 75 PNGs, but visual review found a missing logo in its converted-surface app-bar images. Those images were not accepted as final app-bar evidence.

The revised harness checks decoded images and nonzero geometry, captures the ordinary Android surface before conversion, and supplies the same status-bar inset as HomeScreen. [Run 38647780598](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38647780598) completed the phone configuration with 27 PNGs: **the logo is visible in both ordinary Android and converted Flutter captures**, at 83.478 × 24dp. Its artifact `11933772230` has SHA-256 `86e4ceec99fcca610f88c20ccf3b9a46ef2ee45ba99c1cd8bfa4d478536add76`; digest/CRC checked. Production widgets and logo asset were unchanged.

The subsequent narrow configuration repeatedly failed to connect to its Dart VM service before tests started; that sequential run was cancelled to retain its diagnostic results. A 600-second per-driver limit and immediate log flushing now prevent unbounded connection retries. [Run 38650105868](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38650105868) at `74beaa8bc06c7c3c13185d9d0e01bd7078e455bc` uses one fresh emulator per configuration, so configurations do not inherit app/VM state. The final matrix and its exact source are reported in the [current visual polish report](visual-polish-2026-10-15/README.md).

The native keyboard harness also now waits for stable insets before tapping, brings the field back into view, and asserts the choice target is hit-testable. Earlier phone diagnostic logs had a missed-target warning while the native keyboard was still changing geometry. No app keyboard behavior or existing assertion was removed.


## Modified files

- `proxo_app/lib/widgets/proxo_sidebar.dart`, `bottom_nav.dart`, `top_bar.dart`, `notification_bell.dart`.
- `proxo_app/lib/screens/profile_screen.dart`, `proxo_app/lib/main.dart`, shared `proxo_app/lib/theme/proxo_chrome.dart`.
- `proxo_app/test/chrome_capture_test.dart`, `chrome_behavior_test.dart`, updated `ui_remediation_capture_test.dart` font loading.
- `proxo_app/integration_test/ui_iconography_test.dart` and its read-only `support/actual_screen_fixtures.dart`.
- `scripts/run-ui-native.py` captures the ordinary Android surface independently of Flutter's converted screenshot surface.
- `test/proxolink-v6-api.test.js`: deterministic mutation in an existing integrity regression (see below); no backend production code changed.
- `.github/workflows/chrome-evidence.yml`, `.github/workflows/ui-native.yml`, this report, `SOLAR_ICON_LICENSE.txt` and the screenshot/evidence directory.
- **Application icon/image asset files changed: none. Dependency or lockfile changes: none.** PNGs added under `docs/` are actual test evidence only.

## CI regression-test stability

The later [CI run at 25cbe16](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38647780645) passed Flutter/release, database, edge and responsive jobs, but an existing backend integrity test failed: its expected 404 was 200. The test replaced the last two base64url characters with `aa`. That substitution can leave decoded ciphertext unchanged through unused padding bits or an already matching random suffix. An isolated Node AES-GCM reproduction produced a changed text string with identical bytes and a still-valid ciphertext; flipping an actual ciphertext byte was rejected.

Commit `a6592cbe7237deec818ca25dc563fba372e167ef` changes only this test: flip one decoded byte, assert the bytes differ, and retain the same 404 assertion. The [backend rerun](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38649002491) passed **153/153 tests**. No production crypto, authorization, backend route, secret or rejection criterion was changed. Local syntax checking passed; direct local production-module execution was unavailable because the scratch checkout lacks `sharp`, so full backend validation used the hosted dependency-complete job.
