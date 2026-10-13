# Protected Android evidence and pixel cause analysis — 2026-10-09

**Android runtime: FAILED. Pixel root cause: NOT PROVEN.** This is the terminal audit of [protected run 37960639713](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37960639713), attempt 1, revision `e61bc1a93f4acdc7ad75e9f44e79e6d73f110f11`, runtime job **113924422975**. The authorized environment review cleared, KVM setup passed, and real Android WebView execution completed. APK job 113922296033 passed. Runtime ended at 2026-10-09 18:10 UTC; evidence upload succeeded. No rendering fix or another native execution follows this audit.

Artifact **11635652972**, `proxolink-native-runtime-evidence`, 164,833,243 bytes, SHA-256 **aa87d63d5af0da2db638150f5bac432250f5841570a553d5f6fcfb8a4806c36f**. ZIP digest verified before inspection. Its 2,339 entries comprise 2,328 PNGs and 11 safe JSON files. [Safe manifest](evidence/proxolink-v6-2026-10-06/native-e61bc1a-attempt1/safe-file-manifest.json) retains each original file digest.

| Current measurement | Result |
| --- | ---: |
| Expected / executed behavior cases | 240 / 240 |
| Behavior passed / failed | 240 / 0 |
| FIRST candidate / baseline captures | 240 / 240 |
| Missing cases / FIRST captures | 0 / 0 |
| Stable / unstable acceptance roles | 480 / 0 |
| Predetermined samples per role | 3 |
| Exact / failed FIRST pixel pairs | **236 / 4** |
| Changed pixels / maximum RGB channel delta | **4 / 1** |
| Deep target/control acceptance roles | 20, diagnostic gate passed |
| Additional fixed fresh-view roles | 16, all stable; diagnostic only |
| Chooser setup results passed / failed | **0 / 12** |
| Actual chooser thumbnail taps / live-preview captures | **0 / 0 — NOT VERIFIED** |

The matrix still covers four designs × contact/order/download × Kurdish/English × portrait/landscape viewport shapes × 320/375/393/430/768. Android 35, WebView **124.0.6367.219**, DPR 1, density 160 and native geometry are recorded. Every native paint barrier and behavior flag passed. The old catalog HTTP 401 did not recur during the complete matrix; the safe artifact does not establish an exact session-renewal count or JWT-expiry timeline.

[Independent audit](evidence/proxolink-v6-2026-10-06/native-e61bc1a-attempt1/independent-audit.json) recomputed all 240 FIRST comparisons, 480 crop/screen correspondences, 960 acceptance repeat crops and 240 diff PNGs. All match the uploaded metadata. It also checked 36 PixelCopy/surface correspondences and targeted WebContents pairs. The original validator replay rejects `native_pixel_parity_failed`; the independently saved chooser gate also rejects `native_chooser_failed`. The diagnostic gate passes. `results.json` is absent because strict acceptance failed, rather than because captures are missing.

## Exact current failures

Every row differs at one pixel, in the green channel only. RGB values below are the original FIRST frames; later observations never substitute for them.

| Case ID | Crop coordinate | Screen coordinate | Candidate RGB | Baseline RGB | Candidate minus baseline |
| --- | --- | --- | --- | --- | --- |
| pill-order-ku-portrait-768 | 380,222 | 596,440 | 220,227,240 | 220,226,240 | 0,+1,0 |
| pill-mint-contact-ku-portrait-768 | 290,228 | 506,446 | 234,246,241 | 234,245,241 | 0,+1,0 |
| pill-mint-order-ku-portrait-768 | 290,228 | 506,446 | 234,245,241 | 234,246,241 | 0,-1,0 |
| pill-mint-order-en-portrait-768 | 290,228 | 506,446 | 234,245,241 | 234,246,241 | 0,-1,0 |

Full coordinates, original RGB/channel deltas and both 5×5 neighborhoods are retained in [pixel-failures.json](evidence/proxolink-v6-2026-10-06/native-e61bc1a-attempt1/pixel-failures.json), with all twelve failed candidate/baseline/diff crops. For all four, crop origin is 216,218, WebView/viewport 768×1520, document/body rect 0,0,768,1520, scroll 0,0 and native transform identity.

## Investigation of each of the eight historical failures

These rows investigate the failures in run 37844040950 using the new controlled artifact. A now-exact pair is an observation, **not** proof of a remedy. Historical 232/8 and current 236/4 remain separate.

| Historical case | Historical changed pixels / point | Measured layer at that point | Current FIRST changed pixels | Current controlled observations |
| --- | --- | --- | ---: | --- |
| pill-contact-en-portrait-768 | 1743; band225,386–546,394 | Button shadow region over white `.btns`, between WhatsApp and Viber; hit `.list` | 0 | Fixed candidate A/A and fresh candidate/baseline differ by one pixel at380,222 instead. |
| pill-order-ku-portrait-768 | 1;380,222 | `.ubio` Kurdish glyph edge, blended over `.wrap`/`.aura` gradients | 1 | Candidate A/A changes the same green level; fresh pair exact; original pair remains failed. |
| pill-mint-contact-ku-portrait-768 | 1;290,228 | Transparent `.ubio` area over `.wrap`/`.aura` gradients | 1 | Baseline A/A changes this green level; fresh pair exact. |
| pill-mint-order-ku-portrait-320 | 1;257,88 | Transparent `.av-wrap` outside avatar over `.wrap`/`.aura` gradients | 0 | Original/fresh A/A and fresh pair exact. |
| pill-mint-order-ku-portrait-430 | 1;282,184 | Transparent `.uname` area over `.wrap`/`.aura` gradients | 0 | Candidate A/A and fresh pair differ at the historical point by one blue level. |
| pill-mint-order-ku-portrait-768 | 1;583,90 | Transparent `.av-wrap` outside avatar over `.wrap`/`.aura` gradients | 1 | Current failure moved to290,228 beneath transparent `.ubio`; fresh pair also differs there. |
| pill-mint-order-en-portrait-430 | 1;282,184 | Transparent `.uname` area over `.wrap`/`.aura` gradients | 0 | Candidate A/A and fresh pair differ at the historical point by one blue level. |
| pill-mint-order-en-portrait-768 | 1;290,228 | Transparent `.ubio` area over `.wrap`/`.aura` gradients | 1 | Candidate A/A and baseline A/A exact; fresh pair retains the green-level difference. |

[Per-case index and eight detailed files](evidence/proxolink-v6-2026-10-06/native-e61bc1a-attempt1/per-case-root-cause-analysis.json) record paired bounds, boundingClientRect, client/offset/text-range geometry, computed and pseudo styles, transforms, measured subpixels, DPR/scroll/crops, draw/frame/window observations, clocks and three fixed sample neighborhoods. Retained element/style/text hashes match across both roles for all eight. Native parent geometry, sizes, insets, scale, translations and matrices match. Subpixel values such as `.ubio` height25.1875 and provider top325.1875 are identical across roles.

At768, `.ubio` boundingClientRect is239,208,290,25.1875; its background is transparent, transform/filter/shadow are none, opacity1. The pill glyph has color82,97,129 and the mint text color71,104,92. The pill `.wrap`/`.aura` gradients is237,242,254 →223,232,253 at48% →232,237,252; the mint gradient237,248,244 →221,239,232 at48% →232,245,240. An overlapping `.aura` has bounds169,0,430,300, z-index-1, no transform/filter, and radial-gradient(at center top,rgba(255,255,255,0.65),rgba(0,0,0,0)72%). These retained linear/radial computed values match exactly. For the historical shadow band, WhatsApp bounds217,325.1875,334,56; Viber217,393.1875,334,56. WhatsApp outer shadow is rgba(8,125,67,0.36)0px6px14px-8px; both roles retain the same rounded50px button and shadow.

The measured element/overlapping-layer classification is supported, but the exact contributing paint operation is not isolated and the artifact does not isolate whether glyph coverage, gradient interpolation/dither, native rasterization or an embedding/composition operation changes the final channel. No border-radius, image or geometric shift is measured at the four current points. Calling the effect GPU/WebView nondeterminism would overstate the evidence.

## What the stage evidence establishes and what is missing

* All **36** post-acceptance SurfaceView PixelCopy crops exactly match their own FIRST ADB screenshot crops. A simple ADB PNG-only discrepancy is unsupported.
* All **10** target/control candidate/baseline WebContents readback pairs are exact. However, each readback differs from its own earlier ADB crop by hundreds of thousands of RGB pixels. It is a different path and later time, not interchangeable original-surface evidence.
* **13 of36** roles change exactly one pixel after the bundled Page/LayerTree/screenshot/resource/DOM observations, while retained geometry/styles stay unchanged. Later Window FrameMetrics record new frames. This correlation does not isolate which operation or render pass caused the change.
* Fixed same-role fresh-view A/A observations change on five of eight cases. The candidate-endpoint identity alone cannot explain those observations. The acceptance roles remain independently stable across three fixed samples.
* Every first-capture acknowledgement follows visual-state/onDraw/two-animation callbacks; the clock anchors place the samples after the observed draw. Callbacks/window timings do not identify the exact raster buffer or establish a presentation fence.
* Normalized config-field SHA-256 hashes match across target roles. DOM SHA-256 differs, while every retained element/text/style fingerprint matches. The artifact cannot enumerate unretained differing markup.
* **Proven diagnostic limitation:** cached CDP Document bodies are zero bytes; their SHA-256 is the empty-input digest. That cannot establish HTML/CSS/embedded-font byte parity. Retained DOM CSS fingerprints match, but a follow-up must hash actual live style/font inputs and identify markup differences without retaining private source.

The next useful diagnostic step must isolate an operation or paint record and retain valid live-source identities; replaying the unchanged full matrix or selecting later matching frames cannot establish causality. No product rendering change is justified by this audit.

## Chooser root cause — PROVEN harness/current-UI mismatch

All twelve saved chooser entries fail `chooser_builder_setup`; **zero** thumbnail taps and zero preview screenshots exist. The pinned harness traverses descendants of NativeProxoLinkChooser and expects three OutlinedButtons. Pinned ToolsScreen(initialCreate:true) instead pushes a separate Navigator route; the create route uses AdChoice controls and intentionally contains no live WebView or formPreview request. Its selector lives outside the traversed subtree. [Exact safe diagnosis](evidence/proxolink-v6-2026-10-06/native-e61bc1a-attempt1/chooser-contract-diagnosis.json).

Correcting route/control lookup alone would still leave the required thumbnail→large-live-WebView behavior absent from the current Create contract. The twelve old chooser passes on6c7e6c6 do not verify this new UI. This diagnosis does not authorize restoring/remodelling product UI, inventing a preview in a test adapter or certifying thumbnail taps alone. The unchanged chooser gate remains failed.

## Readiness, source checks and change scope

The original KVM command sequence passed on this runner: /dev/kvm existed with mode0660 but was initially unreadable/unwritable to UID1001; after the existing rule/reload/trigger sequence it was0666, readable/writable, and readonly KVM API version12 was observed. This establishes current readiness; it does **not** prove the reason the prior untraced attempt failed.

[Source CI37960639711](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37960639711) passed all five jobs, including Flutter release/privacy; the credential-free native APK also passed. The run included diagnostic instrumentation, **no proven rendering fix**. Before execution,4bff changed nine diagnostic paths ande61 changed six readiness/report/workflow-command paths documented in their scope files. After native testing this publication changes only this report, the current V6 report and safe evidence. No source, product UI, template, CSS, font, asset, original comparator, protection or acceptance change is made.

PR#7 remains **Draft/open/unmerged**. Production publishing, customer data and migrations are untouched. Remaining requirements are four strict pixel failures with unproven causal mechanism and current native chooser coverage0/12. Controlled evidence-driven diagnosis remains pending; no blind retry was made.

