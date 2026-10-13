# ProxoLink Android diagnostic continuation — 2026-10-08

This revision adds harness-only observations and actual builder thumbnail coverage. It contains **no claimed pixel remedy**. Root cause remains **NOT PROVEN** until protected Android evidence establishes it. Historical run 37759310377 at c06bd3dccf9b0ea124447a2fc2ff4a47a6e096f1 remains FAILED: 240 behavior passes, complete/stable 240+240 captures, 234 exact and six one-pixel/one-channel failures. Its artifact is 11548551620, SHA-256 97192f255e06ea104088f8f7220fd8f7690b983e6fdcf8cb35cb10bf32cf4b79. Historical chooser count is zero.

The user's subsequent authorization permits further evidence-driven protected executions when reasonably necessary. Every execution uses the existing workflow and `proxolink-preview-verification` gate; required approval is never supplied or bypassed by the agent. Stop at an approval gate and report its exact run/job/revision. PR #7 stays Draft/open/unmerged. No publishing, production customer writes or migrations.

## Unchanged acceptance and environment

- Existing 240 cases: 4 designs × 3 page types × Kurdish/English × portrait/landscape viewport shapes × widths 320/375/393/430/768.
- Same production ProxoLinkPreview, baseline/candidate endpoints, CSS, fonts, assets, animation preparation and native visual-state/onDraw/two-animation-callback barrier.
- Same Android 35 / x86_64 / google_apis / SwiftShader emulator workflow, 1200×1900 screen, density 160 and DPR 1. No WebView update, renderer/layer-type switch or workflow change.
- The old artifact did not retain the exact system WebView package version. Historical package-version equality cannot be retrospectively certified. This probe records it for both roles and rejects version changes within the diagnostic cohort.
- Exactly three predetermined ADB screenshots per role; FIRST candidate against FIRST baseline; all repeats exact; every required capture present; all 240 pixel pairs must have ZERO changed pixels.
- Existing one-channel/one-pixel regression tests still reject a deliberate difference. No tolerance, pixel masking, averaging, best-frame search or adaptive pixel retries.

## Targeted observations

The six historical case IDs/coordinates are fixed in `nativeDiagnosticPoints` and `DIAGNOSTIC_POINTS`. For both roles, the probe records pre/post-capture DOM and native state without modifying the document: fractional element/global/view geometry, crop/screen coordinates, scroll/viewport/zoom/density, display/window dimensions, elementFromPoint ancestry and covering elements, computed color/gradient/transform/radius/shadow/font/transition properties, pseudo-element properties, animation timing, navigation/load lifecycle and safe state hashes. URL-valued CSS is redacted; no DOM text, document source, credentials or capability URLs are retained.

The existing visual-state and onDraw barriers record event times, two animation callbacks and an observational frame-commit callback. A native frame commit indicates submission for rendering, **not** display presentation; two animation callbacks are not proof of presentation either. Their absence/presence is recorded honestly. Host screenshot intervals and an Android uptime clock anchor allow bounded clock correlation.

After the three acceptance frames, exactly one diagnostic PixelCopy reads Flutter's existing hardware SurfaceView for each targeted role. It does not request a redraw, change GPU/layer settings, use software rendering, or substitute a frame. Its origin/dimensions/timestamps, full PNG and the historical 5×5 neighborhood are retained alongside all three original ADB neighborhoods. This distinguishes observed surface/screen differences but a difference alone must not be overinterpreted as causal proof. Pre/post state is retained to check intervening layout/draw changes.

`render-diagnostics.json` includes exact changed-pixel coordinates and RGB/channel deltas for all newly failed pairs, historical-point neighborhoods even when those points now match, and SHA-256 hashes. Full difference coordinates and original PNGs are retained; for unexpectedly large failures JSON neighborhoods are bounded to the first 64 changed pixels with an explicit truncation flag. That diagnostic limit never affects whole-image acceptance.

Probe JSON files publish by atomic rename so the larger observational records cannot be read half-written. This is publication hygiene, not a proposed explanation for the historical six pixel differences.

## Real Android builder chooser

After the original matrix has finished (so builder activity cannot contaminate its preceding surface history), the APK mounts the **actual ToolsScreen initial-create builder**, its unchanged ProxoLinkDesignSelector, its actual onSelected/key binding and its large production ProxoLinkPreview. A read-only repository adapter supplies existing authenticated server-rendered preview capabilities for the selected design/type; save/upload/action methods throw. This tests builder UI binding and real server WebView rendering, not a database create/edit/save journey.

Android `adb shell input tap` selects each page type and then each design in fixed order mint → dark → white → pill, ensuring every design tap changes the initial pill selection. There are **12 required chooser cases**: all four designs for contact/order/download. The probe decodes the existing PNG thumbnail, checks actual selected state and the builder's preview request, observes a fresh actual WebView controller, validates loaded page `data-theme`, language/direction, assets/provider type/width/overflow and native draw, and saves a screen capture acknowledged by the host. No widget-test callback invocation substitutes for Android input.

The final gate requires all 12 Android taps, 12 preview captures and all chooser assertions. Matrix, diagnostic-completeness and chooser outcomes are saved separately in `acceptance-gates.json` even if another gate fails. No overall VERIFIED result is allowed unless all gates and the full 240-pair strict pixel check pass.

## Exact changed source files

1. `proxo_app/integration_test/proxolink_native_probe.dart`
2. `proxo_app/integration_test/proxolink_native_diagnostics.dart` (new)
3. `proxo_app/integration_test/proxolink_native_chooser.dart` (new)
4. `proxo_app/android/app/src/debug/kotlin/com/proxo/proxoapp/ProxoLinkNativeProbeActivity.kt`
5. `scripts/run-proxolink-native.mjs`
6. `scripts/proxolink-native-diagnostics.mjs` (new)
7. `test/proxolink-native-diagnostics.test.js` (new)

This document is the eighth changed file. No production renderer, prepared template, thumbnail, font, product widget/editor, authentication lifecycle, workflow, environment or original pixel comparator/acceptance validator is modified. Relevant local verification/security/pixel/diagnostic tests: 14 passed; Dart/Kotlin compilation and source CI must pass before the protected execution is triggered. Current run identifiers and terminal counts are published in Draft PR #7 after fresh GitHub reads; never copy the historical 234/6 as a new result.
