# Android native pipeline diagnosis — 2026-10-09

This change is diagnostic instrumentation only. Root cause is **NOT PROVEN** and no rendering remedy is included. It builds on the current branch, preserving the newer Tools/Create implementation and all templates, CSS, fonts, assets, thumbnails, production widgets, authentication renewal, emulator settings, workflow/environment protection and original pixel comparator/validator.

The starting protected evidence is run **37844040950**, attempt **2**, revision **6c7e6c634cfe0bceb2c43ceb485aba12cd78417c**, runtime job **113568639222**. Artifact **11586077978**, SHA-256 **4ae48def82e5a931ed79779ee75a272634d53202370376862734660e50b92ec8**, was independently audited: 240 behavior passes, 240 candidate plus 240 baseline captures, zero missing, 480 stable roles, **232 exact / 8 failed** first-frame pixel pairs, **1,750 changed pixels**, maximum channel delta 1. Its 12 chooser passes apply only to that old revision.

## Predetermined targets

| Starting failed case | Crop point | Starting changed pixels | Starting observed layer, causal classification unproven |
| --- | --- | ---: | --- |
| pill-contact-en-portrait-768 | 225,386 | 1,743 | White button-card shadow band between WhatsApp/Viber; full band bounds 225,386–546,394 |
| pill-order-ku-portrait-768 | 380,222 | 1 | Bio glyph edge |
| pill-mint-contact-ku-portrait-768 | 290,228 | 1 | Header background |
| pill-mint-order-ku-portrait-320 | 257,88 | 1 | Header/avatar-adjacent background |
| pill-mint-order-ku-portrait-430 | 282,184 | 1 | Transparent name element over gradient |
| pill-mint-order-ku-portrait-768 | 583,90 | 1 | Right wrap background |
| pill-mint-order-en-portrait-430 | 282,184 | 1 | Header background |
| pill-mint-order-en-portrait-768 | 290,228 | 1 | Transparent bio element over gradient |

Two previously passing controls remain: `pill-order-en-portrait-768` at 380,222 and `pill-mint-contact-ku-portrait-430` at 282,184. These ten targets require 20 acceptance-role diagnostic sets. The probe additionally makes **one** predetermined fresh candidate and **one** fresh baseline for each of the eight failures, after the original 240-case matrix: **16 diagnostic-only roles**, each with exactly three fixed ADB frames. It compares original/fresh candidate A/A, original/fresh baseline A/A and fresh candidate/baseline. These frames never enter the acceptance pixel map or replace an original frame; no matching-frame search or adaptive retry exists.

## Measurements and boundaries

Every one of the 480 acceptance roles retains read-only DOM/native state in `render-state.json`: hit/covering ancestry, stable allowlisted selectors, all provider-button geometry and styles, text Range rectangles, parent/containing bounds, client/offset dimensions, shadows/radii/clipping/transforms, font state, viewport/DPR/scroll, image intrinsic dimensions and PerformanceResourceTiming. Collection limits are explicit; truncation is recorded. A fixed pair of requestAnimationFrame callbacks is logged before the existing native visual-state/onDraw/two-postOnAnimation barrier. Finite-animation completion, infinite-animation pause, existing two-second settle and all three acceptance samples remain unchanged.

Native observations include measured and laid-out sizes, pending layout, parent geometry/layer types, insets, scaled/display density, rendering-process presence, WebView version, native matrix and the last eight Window FrameMetrics samples. A frame-commit callback reports submission, **not presentation**; Window timing and callbacks do not establish a GPU cause or a presentation fence.

For each target role, only **after** the three acceptance frames:

1. One PixelCopy reads the existing Flutter SurfaceView (original diagnostic retained).
2. Local ADB-forwarded CDP identifies the exact existing Android WebView by a nonvisual case/role marker and takes **one** WebContents compositor screenshot. It reads layout metrics, available LayerTree bounds/transforms/paint counts and cached page resources without fetching replacements. This is Android WebView, not Chromium, and is not raw Skia tile/GPU task evidence. Unsupported/missing measurements are explicit; screenshot dimensions must match exactly, with no scaling/crop adjustment.
3. One fixed ADB frame and a read-only DOM/native snapshot follow CDP to detect whether the observation coincided with changed surface/state. This frame is diagnostic only.

The debug Activity enables WebView debug inspection; production/release entry points are unchanged. No hardware/layer/raster setting, template, DOM style, asset, baseline or crop is altered. Layer IDs, signed target/resource URLs and cached HTML/CSS/resource bodies are discarded after allowlisted measurements and SHA-256 hashing. Rendered source, embedded resource identities, cached response bytes, normalized input fields and provider hrefs are hashed. Exact differing field names and their **possible**, not proven, rendering effects are retained. Native decoded image dimensions are measured by the page; a cached resource body hash is not proof of a particular decode/raster path. URL tokens and text values are never retained. No service-role access, publishing or persistence is added.

`render-diagnostics.json` preserves stage comparisons, full acceptance difference coordinates, RGB/channel deltas, bounded 5×5 neighborhoods, first-frame samples and timing anchors, all fixed reproduction comparisons and unavailable-measurement reasons. Additional small `diagnostic-region-*` crops explain actual failed regions; full original acceptance crops/diffs remain untouched. Diagnostic-only stage comparisons may bound coordinate output at 8,192 with explicit truncation; **acceptance metrics and full acceptance coordinates are never bounded or excluded**.

## Gates and interpretation

The original acceptance remains 240 cases = 4 designs × 3 types × 2 languages × 2 viewport shapes × 5 widths; Android 35, existing x86_64/google_apis/SwiftShader environment, 1200×1900 at density 160/DPR 1; all behavior flags, 240 FIRST candidate/240 FIRST same-emulator baseline, all required crops/diffs/metadata, exactly three samples per role, zero missing, zero instability and zero changed pixels. The original comparator and validator are unchanged. Diagnostic completeness adds full role state, both target roles, same-version native observations, compositor dimensions/readback and all 16 fixed stable fresh-view roles. The existing 12-case native chooser gate remains unchanged. Its old ToolsScreen/live-preview assumptions may expose a current harness/UI contract mismatch; historical passes cannot certify the current UI, and this pixel-only change neither rewrites the product nor silently relaxes that gate.

The earlier source-input audit established avatar-admission/Viber URL-validation branches, but their causal link to pixels remains unproven. Equal DOM/CSS/viewport/resource inputs plus a persistent pre-Flutter surface mismatch locate a pipeline stage; they alone do not prove GPU nondeterminism. A differing resource/layout/timing field is correlation until a controlled causal chain establishes its effect. No product fix is authorized by a mere decrease in failures.

## Validation before protected execution

Eleven focused Node checks pass, covering geometry/selector/privacy allowlists, input/resource hashing, layer hierarchy/transforms, a mocked single native CDP readback, Dart JavaScript syntax/target agreement, exact screen/neighborhood reporting, fixed reproduction completeness, unchanged 12-case chooser requirements, and deliberate one-pixel/one-channel rejection with FIRST-frame retention. Mocks are harness checks, not Android runtime verification. Android integration analysis and debug Kotlin/Dart compilation run in the existing APK job. Source CI runs for this new instrumentation revision; completed prior source checks are not rerun manually.

No new native result or proven fix is claimed by this document. Continue the same protected execution after authorized approval and inspect its actual digest-verified evidence.
