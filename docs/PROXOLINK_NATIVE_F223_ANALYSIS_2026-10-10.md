# ProxoLink native f223 terminal analysis — 2026-10-10

## Status

**FAILED. Pixel root cause: NOT PROVEN.**

Protected run [38004288157](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38004288157), attempt 1, revision f223dcf81feb4c6d49744114bdbc57f8d2c57e90, runtime job 114070711797 completed after authorized environment review. KVM passed, the Android 35 emulator and production WebView matrix executed, and the runtime evidence upload succeeded. The run was diagnostic/acceptance-only; it did not include a renderer or product fix.

The executable source is c830a683b6b70ee91f5aebc002b1b4b424d5ac4a. The f223 request revision and this publication change documentation/evidence only; no template, CSS, font, asset, production UI, authentication, comparator, validator, emulator, workflow-protection, or acceptance rule was changed.

## Strict native result

| Gate | Result |
|---|---|
| Matrix | 240 expected / 240 executed; 240 behavior passed / 0 failed |
| FIRST captures | 240 candidate / 240 baseline; 0 missing cases; 0 missing captures |
| Repeatability | 480 acceptance roles stable / 0 unstable; exactly 3 predetermined samples per role |
| Pixel parity | 232 exact / 8 failed; 9 changed pixels total; maximum channel delta 1 |
| Diagnostics | PASS: 480 basic states, 20 deep acceptance roles, 16 stable fresh diagnostic roles |
| Legacy thumbnail → live WebView chooser | PASS: 12/12 actual Android taps and live preview captures |
| Current Create selector | PASS: 12/12 actual Android selections with decoded thumbnails and the current no-live-WebView contract |
| Tools external-browser journey | FAIL: 1/3 passed; 2 aggregate browser-state checks failed |
| Actual production screens | FAIL: 8/16 passed; 8 failed; 46 captures retained |
| Authentication | All 240 completed; the historical template_catalog HTTP 401 did not recur |
| Runtime artifact | 11658690426; SHA-256 10b3dc0a84e39e4ac190b1ab6098a441cac5f3c23af42705865f2661420df23e; digest verified |
| Source CI | [38004288253](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38004288253) SUCCESS, all five jobs |

The original validator fails the strict zero-difference pixel gate. No tolerance, masking, averaging, frame selection, adaptive retry, missing-evidence allowance, or Chromium substitution was used.

## Exact failed pixels and painted layers

| Case | Crop x,y | Screen x,y | Candidate RGB | Baseline RGB | Delta | Exact containing element | Layer classification |
|---|---:|---:|---:|---:|---:|---|---|
| pill-order-ku-portrait-768 | 583,90 | 799,308 | 235,241,254 | 236,241,254 | −1,0,0 | .wrap + .aura beneath transparent .av-wrap | background / linear + radial gradients |
| pill-order-en-portrait-768 | 380,222 | 596,440 | 215,222,236 | 215,221,236 | 0,+1,0 | .ubio | text antialiasing over gradients |
| pill-download-ku-portrait-768 | 583,90 | 799,308 | 236,241,254 | 235,241,254 | +1,0,0 | .wrap + .aura beneath transparent .av-wrap | background / linear + radial gradients |
| pill-download-ku-portrait-768 | 380,222 | 596,440 | 220,227,240 | 220,226,240 | 0,+1,0 | .ubio | text antialiasing over gradients |
| pill-mint-order-ku-portrait-320 | 257,88 | 697,306 | 239,249,245 | 239,248,245 | 0,+1,0 | .wrap + .aura beneath transparent .av-wrap | background / linear + radial gradients |
| pill-mint-order-ku-portrait-430 | 282,184 | 667,402 | 237,247,244 | 237,247,243 | 0,0,+1 | .uname | text antialiasing over gradients |
| pill-mint-order-ku-portrait-768 | 290,228 | 506,446 | 234,245,241 | 234,246,241 | 0,−1,0 | .ubio | text antialiasing over gradients |
| pill-mint-order-en-portrait-430 | 282,184 | 667,402 | 237,247,244 | 237,247,243 | 0,0,+1 | .uname | text antialiasing over gradients |
| pill-mint-order-en-portrait-768 | 290,228 | 506,446 | 234,245,241 | 234,246,241 | 0,−1,0 | .ubio | text antialiasing over gradients |

For each listed coordinate, the retained 5×5 candidate/baseline neighborhoods show that only the stated pixel differs within that neighborhood. The complete neighborhoods, coordinates, and RGB values are in pixel-failures.json. The three safe diagnostic-region images for every failed case are retained beside it.

## Candidate/baseline comparison

For every deep-instrumented failed pair:

- boundingClientRect values, text rectangles, parent/containing-block geometry, computed styles, transforms, transform origins, border radii, shadows, clipping, font properties, and subpixel coordinates match;
- viewport bounds, WebView size, crop origin, DPR 1, scroll position 0/0, native identity matrix, Android 35, 1200×1900 display, WebView 124.0.6367.219, and SwiftShader renderer match;
- visual-state, onDraw, frame-commit-submission and two fixed animation callbacks were observed for both roles. Absolute timestamps differ because candidate and baseline load sequentially, but no changed pixel correlates to a missing barrier or distinct retained lifecycle state;
- normalized input/config hashes, live CSS bytes, and decoded embedded font-byte hashes match;
- live HTML hashes differ. The safe artifact does not retain a normalized markup diff, so the unretained difference cannot be claimed as the pixel cause.

The 36 Flutter SurfaceView PixelCopy crops match their own FIRST ADB screenshots exactly. Where a paired later WebContents readback exists, candidate and baseline are exact at that later stage while the FIRST/SurfaceView pair retains its one-pixel difference. This localizes the observation to an earlier or composition-visible frame, but it does not distinguish paint-operation rounding, raster CTM/clip behavior, color interpolation, framebuffer composition, or presentation timing. The new pill-download-ku-portrait-768 failure was not in the preselected deep-target set and therefore has no paired deep WebContents readback.

Acceptance captures are internally stable, while fixed fresh diagnostic A/A observations vary for a subset of previously targeted cases. That is evidence of stage/time sensitivity, not proof of GPU or WebView nondeterminism.

### Root-cause decision

**NOT PROVEN.** Layout differences are ruled out by matching geometry/styles/transforms/viewport/crop evidence. Asset, CSS, and embedded-font byte differences are ruled out by the live hashes. Lifecycle-barrier omission is not observed. The artifact does not isolate the exact paint operation, raster transform/clip, color-interpolation path, or presented-buffer event that changes the final channel value, and it does not retain the safe normalized HTML difference needed to exclude unobserved markup as a causal input.

No speculative renderer fix is applied. A further protected execution would be justified only after adding one-variable instrumentation that captures a safe normalized markup diff and the exact paint/raster/clip/color path for these coordinates, includes pill-download-ku-portrait-768 as a deep target, and separates each readback operation from elapsed-time/new-frame effects. FIRST-frame acceptance remains unchanged.

## Other gate causes

The six phase-missed actual-screen failures are a **proven harness scheduling defect**, not a product rendering defect: the harness schedules absolute phases but performs synchronous PixelCopy at each phase; when an earlier capture completes after the next absolute deadline, the next phase throws instead of recording the late-but-deterministic capture. The two retained lifecycle failures are not yet causally isolated.

The two Tools browser failures reached Chrome and resumed the app, but the retained evidence contains only an aggregate browser_journey_state failure rather than the per-condition discriminator needed to prove which return-state condition failed. Their exact cause is therefore **NOT PROVEN**.

## Publication and PR state

This publication changes exactly the 30 documentation/evidence paths listed in publication-files.json: this report, the current V6 report, four JSON evidence files, and 24 safe failed-case PNG crops/diffs. It retains no tokens, private URLs, private HTML/CSS, customer data, or raw sensitive logs.

PR #7 remains **Draft, open, and unmerged**. No production publishing, customer mutation, migration, or destructive cleanup occurred.
