# Proportions, retained screen state and shared refresh

[Final requirement audit and Profile data-freshness follow-up](completion-audit.md).

This follow-up addresses the reported oversized Auth/payment marks and logout icon, crowded visual weight, repeat screen creation, and inconsistent refresh behavior.

Application source: `8c0f3645e94300f89371c95b953fe75e0f2e277d`.
Immediate baseline: `211abe49a8969fa8d250e727736a07668eeee594`.
Native input harness: `8905c7f14cc5097f2304e88e23306f5987b2378c`; application library, assets, Android files and dependencies are identical to the application source above.

## Deliberate sizing

The logout icon declared 24dp but inherited a tight 38dp parent. The same constraint problem stretched navigation and receipt-upload SVGs. `ProxoSymbol` now centers the requested glyph size inside its control, matching ordinary `Icon` behavior. Profile logout also uses the same 40dp rounded well and row padding as its neighbours.

| Element | Before | After |
|---|---:|---:|
| Shared Auth logo box | 132 × 38dp | 84 × 24dp |
| Official provider logo envelope | 88 × 32dp | 64 × 24dp |
| Provider card at text scale 1 | 112.8dp high | 102.8dp high |
| Logout SVG box | 38 × 38dp | 24 × 24dp |
| Navigation SVG box | 48 × 32dp | 24 × 24dp |
| Create glyph | 32dp | 28dp, in the existing 56dp control |
| Receipt upload SVG box | 52 × 52dp | 24 × 24dp, in the existing 52dp control |

These are logical layout dimensions. SVG envelopes are distinguished from artwork bounds: provider aspect ratios remain intact. Card labels reserve the same status-line height, so configured and disabled providers align along each row. Official source assets, account numbers, disabled methods, fees and submission behavior remain unchanged. FastPay bitmap decoding now follows displayed width and device pixel ratio.

[Original before/after screenshots and Android evidence](gallery.md) · [Measured geometry](measurements.md) · [Verification record](verification.json)

## Refresh and navigation

All ten refresh surfaces use `ProxoRefresh`: Home, Ads, Tools, Profile, weekly results, notifications, page details, tutorials, tasks and levels. Pull gestures and active-tab re-selection share a 22dp spinner, 60dp reveal, spring motion and one in-flight guard. Ads retains that wrapper across content/empty/error states, and a successful empty/unchanged response now clears a previous error or offline state. Responses for a former account are discarded before applying or caching. Tasks, Levels and Tutorials keep their loaded list during a refresh instead of replacing it with an initial loading screen.

Gesture handling excludes horizontal/nested/ballistic notifications and uses the current pull distance to allow cancellation. Completing work after route disposal no longer calls a disposed animation controller. Exercising the actual Ads network-error state also exposed a pre-existing unbounded-width retry button. Its card now provides bounded width, wrapping message/button text and a minimum 48dp retry target. Recovery is exercised at 393dp and 280dp with requested 1×/2× system text, with original error/recovered screenshots. Campaigns retains its existing content text-scale cap of 1×; this test does not claim uncapped large-text accessibility for that screen.

Successful ad creation no longer changes Home/Ads keys or destroys their State. Existing activation refresh supplies fresh Ads data; returning to an already-active Ads tab triggers one explicit refresh. Rapid repeated create taps cannot stack duplicate routes. Retained tabs keep their existing scroll positions, lazy first mount and inactive ticker suppression.

Home now joins simultaneous initial/activation/manual reads for the same authenticated owner. A subsequent explicit refresh makes a fresh request, and results from a former owner cannot update the screen. This complements the existing public results cache and owner-scoped Tools cache without adding persistent balance/account caches.

## Verification

The focused behavior suite checks actual rendered SVG bounds, Auth/provider scaling, both bouncing and clamping pull gestures, one request across gesture/tab refresh, canceling a pull, refresh completion after disposal, retained secondary lists, owner-scoped Home request coalescing, and actual MainShell route/state/scroll retention. The screen matrix uses bundled fonts at 393dp/1× text/DPR3 and 280dp/2× text/DPR2 in Sorani, Arabic and Badini.

Final-source workflow outcomes and independently verified artifact hashes are recorded in `verification.json`. Counts from different suites overlap; they are not a total of unique tests.

| Final-source check | Outcome |
|---|---|
| [Auth/localization/polish](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38779982416) | 90 capture cases and 44 behavior tests pass |
| [UI/receipt regression](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38779982397) | 64 capture cases and 298 behavior tests pass |
| [Profile/navigation](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38779982375) | 20 capture cases and 3 behavior tests pass |
| [Full regression and release](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38779982542) | All five jobs pass, including Flutter release APK/privacy checks |
| [Credential-free native build](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38779982369) | APK passes; protected native-runtime and isolated-hosted jobs skipped |
| [Android API35 with real pointer input](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38786262385) | Phone, narrow and tablet pass; 111 original PNGs, two real taps and one real Back per configuration |

During implementation, the first added behavior run exposed two harness mistakes: default Ahem test glyphs did not match the bundled app font, and a 240dp reverse pointer move did not return the bouncing viewport below its 60dp threshold. The tests now load the app fonts and assert the actual scroll position before release. All 90 font-loaded captures already passed on that intermediate source; the corrected behavior suite passed 42 tests at `6c1f8fb`, before the final row-alignment refinement. The original harness failure remains available at [38775754055](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38775754055).

The subsequent recovery test correctly caught the retry-card layout failure; [diagnostic run 38779041943](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38779041943) retains the failure. Its cascading rendering assertions made the ordinary log endpoint unavailable, so behavior logs are now retained with screenshot artifacts. The failure was fixed in application code, and the test now fails immediately on a layout exception.

The [initial native run](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38779982294) passed on phone, while narrow and tablet timed out connecting the driver before executing tests. A targeted retry produced 35 narrow rendering frames, then failed the keyboard assertion: Android logged `PHASE_CLIENT_VIEW_SERVED`. Inspecting the original [Android system screenshot](diagnostics/narrow-launcher-anr.png) revealed a Pixel Launcher not responding dialog covering the app; widget captures alone did not show that system overlay. Tablet again timed out before test execution. These attempts remain recorded as failures.

The native harness now sends two actual Android pointer taps at the measured title-field coordinates before asserting keyboard insets, in addition to the existing real Back event. Its [first real-tap run](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38784546299) correctly reached the title coordinates, but the live binding consumed the taps as finder diagnostics: the [documented device-event setting](https://api.flutter.dev/flutter/flutter_test/TestWidgetsFlutterBinding/shouldPropagateDevicePointerEvents.html) defaults to false. The final harness explicitly enables it for this phase and restores it afterward. Visible/hidden keyboard transitions and preserved form state are still required, with OS input/window/logcat diagnostics retained on failure. No application workaround or weakened keyboard assertion was added.

On the final harness, narrow and tablet completed with 37 PNGs each. Phone also passed every in-app assertion, but the emulator became offline before the driver could collect its results. Retrying only that phone job completed successfully with its 37 PNGs and observations. The final native workflow is successful for all three configurations. Each downloaded archive passed independent SHA-256 and ZIP CRC checks; the gallery preserves 27 original comparison/recovery/native frames, with the additional system-failure frame retained separately for diagnosis.

The verification uses fictional transports and does not send OTPs, payments or production database writes. Android emulator debug execution validates rendering/keyboard/back behavior, not physical-device latency. No P50/P95, CPU, heap or percentage speed improvement is claimed. The previously documented isolated-staging and strict WebView pixel-parity blockers are separate and remain open. PR #7 remains Draft/Open/Unmerged.
