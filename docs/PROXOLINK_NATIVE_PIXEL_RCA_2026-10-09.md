# ProxoLink V6: per-case analysis of the eight native pixel failures

**Android status: FAILED. Root cause: NOT PROVEN.** This is an analysis of existing evidence, not a fix or a new native execution. No product, template, CSS, font, asset, capture logic, comparator, workflow or environment setting was changed. No retry or protected run was started.

Protected [run 37844040950](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37844040950), attempt **2**, revision **6c7e6c634cfe0bceb2c43ceb485aba12cd78417c**, runtime job **113568639222**. Artifact **11586077978** was downloaded again and its SHA-256 independently matched **4ae48def82e5a931ed79779ee75a272634d53202370376862734660e50b92ec8**. Analysis uses the original `render-diagnostics.json`, native observations, fixed captures, PixelCopy results, and pinned source. Local source blob hashes were checked against the pinned GitHub tree before interpreting its CSS.

The run executed **240/240** behavior cases (**240 passed, 0 failed**), captured **240 candidate + 240 baseline**, with **0 missing cases/captures**, **480 stable roles / 0 unstable**, and **232 exact / 8 failed** first-frame pairs. The eight failures contain **1,750 changed pixels**, maximum absolute channel difference **1**. Native builder chooser **12/12 passed** on this pinned, pre-management-refactor revision. The earlier HTTP 401 did not recur. These remain the native results; the later page-management screens are not certified by this run.

## What was actually recorded

The instrumented probe targeted six *historical* case IDs and points. Only **three current failures** have hit-test/ancestry observations at their actual changed pixel: order/ku/pill/768, order/ku/mint/430, and order/en/mint/768. The contact/en/pill/768 case has observations for seven named elements, but its hit test was at **(380,222)**; its current changed pixels are elsewhere. The other four failed cases have captures and pixel metadata but **no per-role DOM/native diagnostic state**. A pixel-neighborhood entry for a new failure is not a DOM hit test for that failure.

This distinction prevents substituting Kurdish geometry for English geometry, borrowing another width's layout, or inventing computed styles or draw timestamps. Exact missing measurements are listed per case in [per-case-root-cause-analysis.json](evidence/proxolink-v6-2026-10-06/native-6c7e6c6-rca-2026-10-09/per-case-root-cause-analysis.json). All eight first-frame comparisons were recomputed from original artifact PNGs again for this analysis. Full 1,750 coordinates/RGB deltas remain in the earlier `independent-audit.json`; original diagnostic neighborhoods for the large failure were explicitly truncated to 64 samples, not 64 changed pixels.

## Eight failures and affected paint regions

Coordinates are zero-based. Screen coordinates equal crop coordinate plus saved viewport origin. RGB delta is candidate minus baseline. Identifying a visible paint region does **not** establish the mechanism producing different channel values.

| Case ID | Changed pixels / crop / screen | Candidate → baseline RGB | Element or paint region and evidence strength | Causal result |
|---|---|---|---|---|
| `pill-contact-en-portrait-768` | **1,743**; bbox **(225,386)–(546,394)**; first **(225,386)** / **(441,604)** | First **(254,254,254) → (253,254,254)** | Faint **shadow/background band** on white `main#buttons.btns` between WhatsApp and Viber `.pl-btn`. Image and recorded card bounds locate the band. No button-specific native hit test, computed shadow or paint-layer trace at these pixels; individual overlapping shadow ownership is not uniquely measured. | NOT PROVEN; not a text/image region. Shadow rasterization/composition is a hypothesis, not an established cause. |
| `pill-order-ku-portrait-768` | **1**; **(380,222)** / **(596,440)** | **(220,227,240) → (220,226,240)** | Direct hit is **`p#bio.ubio`**. Neighborhood contains exact text ink **(82,97,129)** immediately left. Changed sample is an **antialiased Kurdish glyph edge over the background gradients**. | NOT PROVEN; cannot distinguish glyph coverage rounding from background/blend rounding at this edge. |
| `pill-mint-contact-ku-portrait-768` | **1**; **(290,228)** / **(506,446)** | **(234,245,241) → (234,246,241)** | **Smooth header background** in bio region; neighboring text ink occurs above-left, but changed sample is near background colors. `.wrap` linear gradient plus `.aura` radial gradient is the source/image attribution. Exact runtime hit element was **not recorded**. | NOT PROVEN; native layout/style/timing comparison unavailable for this case. |
| `pill-mint-order-ku-portrait-320` | **1**; **(257,88)** / **(697,306)** | **(239,249,245) → (239,248,245)** | **Smooth header background to the right of avatar**, outside visible avatar/ring. Pinned template and image identify the background region, not a captured DOM hit. | NOT PROVEN; no per-role runtime geometry/style/draw observations. |
| `pill-mint-order-ku-portrait-430` | **1**; **(282,184)** / **(667,402)** | **(237,247,244) → (237,247,243)** | Direct hit is **`h1#name.uname`**, a transparent box. Point is outside visible title glyphs; full 5×5 is background colors. Paint contributors are **`.wrap` linear + `.aura` radial gradients**, not H1 text, border radius, image or H1 shadow. | NOT PROVEN; matching geometry/styles do not isolate gradient interpolation, quantization, raster-cache state or composition. |
| `pill-mint-order-ku-portrait-768` | **1**; **(583,90)** / **(799,308)** | **(235,247,242) → (236,247,242)** | **Smooth background near right edge of wrap**, away from avatar. Source/image attribution to wrap/aura; no direct runtime hit test. | NOT PROVEN; no per-role runtime geometry/style/draw observations. |
| `pill-mint-order-en-portrait-430` | **1**; **(282,184)** / **(667,402)** | **(237,247,244) → (237,247,243)** | **Smooth background in title region**, outside visible glyphs. Same RGB pattern as ku/430 is an observation; ku DOM state is **not** used as this case's native geometry. | NOT PROVEN; no per-role runtime geometry/style/draw observations. |
| `pill-mint-order-en-portrait-768` | **1**; **(290,228)** / **(506,446)** | **(234,245,241) → (234,246,241)** | Direct hit **`p#bio.ubio`**, transparent; all 25 neighborhood samples are near background, far from computed text ink **(71,104,92)**. Paint region is **wrap/aura gradients behind the bio box**, not visible glyph ink. | NOT PROVEN; no specific interpolation/raster/compositor/lifecycle mechanism isolated. |

The large band is not eight single-pixel errors. Its changed rows/counts are **386:291, 387:279, 388:287, 389:293, 390:290, 391:285, 392:12, 393:4, 394:2**. Multiple channels can change at a pixel; each absolute channel difference is still at most 1. Its 1,743 delta distribution is: (-1,0,-1):547; (-1,0,0):326; (0,0,-1):288; (0,-1,0):284; (-1,-1,-1):269; (-1,-1,0):10; (0,-1,-1):9; (1,0,1):8; (1,0,0):1; (0,0,1):1.

Recorded card bounds are **[195,259.1875,378,484]** in both roles. With pinned padding/gaps/min-height, source-derived WhatsApp bounds are **[217,325.1875,334,56]**, Viber **[217,393.1875,334,56]**. These button rectangles are **derived**, not saved `boundingClientRect` observations. The band lies in their exterior shadow region, with a few corner samples near Viber's rounded edge. It does not demonstrate a changed radius or shifted rectangle. Button-specific style/layer evidence is missing, so changing its shadow or snapping its fractional Y coordinate would be speculative.

## DOM, boundingClientRect, styles and transforms

For all six instrumented pairs, every recorded DOM field matches candidate/baseline except `time_origin`, `now_ms` and navigation timing. This includes all seven named elements, ancestry, covering elements, text/style hashes, computed styles and pseudo styles, document/body bounds, hit bounds, visual viewport, DPR, scroll, font/CSS hashes, visibility and animation state. Before/after observations within each role differ only in `now_ms`. No active animations were recorded.

| Instrumented failed case | Exact measured bounds `[x,y,w,h]` in both roles | Styles in both roles | Native/crop comparison |
|---|---|---|---|
| contact/en/pill/768 | wrap **[169,0,430,1520]**; card **[195,259.1875,378,484]**; historical bio hit **[239,208,290,25.1875]** | Named-element opacity **1**, transform **none**, matching styles/pseudos/hashes. Provider-button computed styles at band are missing. | WebView/crop **768×1520**, screen origin **(216,218)**; identical native transforms/scales/scroll. |
| order/ku/pill/768 | actual bio hit **[239,208,290,25.1875]**; wrap **[169,0,430,1520]**; aura **[169,0,430,300]** | Font **ProxoBahij, 14px, weight400**, line-height **25.2px**, ink **rgb(82,97,129)**; transparent background, transform/filter **none**, shadow **none**, matching inherited gradients. | Same **768×1520**, origin **(216,218)**. |
| order/ku/mint/430 | actual H1 hit **[25.796875,170,378.40625,30]**; wrap **[0,0,430,1520]**; aura **[0,0,430,300]** | Font **ProxoBahij,20px,weight400**, line-height **30px**; transparent H1 background, transform/filter **none**, shadow **none**. Fractional x/width are exactly equal. | Same **430×1520**, origin **(385,218)**. |
| order/en/mint/768 | actual bio hit **[239,208,290,25.1875]**; wrap **[169,0,430,1520]**; aura **[169,0,430,300]** | Font **ProxoBahij,14px,weight400**, line-height **25.2px**, ink **rgb(71,104,92)**; transparent background, transform/filter **none**, shadow **none**. | Same **768×1520**, origin **(216,218)**. |

The wrap's measured linear-gradient endpoints are pill **(237,242,254) → (223,232,253) at48% → (232,237,252)**; mint **(237,248,244) → (221,239,232) at48% → (232,245,240)**. Aura is the same top-centered radial white alpha gradient in both roles. Matching gradient definitions establish matching recorded inputs; they do not prove matching intermediate raster values or a particular color-interpolation defect.

All recorded native geometry fields match: **DPR1**, density160, page scale1, WebView124.0.6367.219, Android35, native matrix identity, alpha1, scaleX/Y1, translation0, scroll0, attached/hardware-accelerated true, layerType0, window1200×1900. Exact original fullscreen-to-crop correspondence was previously checked for all240 pairs. Additional width320 failed crop origin is **(440,218)**. For uninstrumented cases, viewport dimensions/origins are measured capture metadata; DPR1 and scroll-reset describe configured probe behavior, not an independently saved per-role DOM measurement.

Pinned local candidate/baseline template blobs match the GitHub tree. Their CSS—including embedded fonts—is byte-identical, SHA-256 **2ede7600af7b12b67414879d07eb7db272f65cdaaa8f352221a9738b3626f424**, as is static markup before executable script. Runtime hashes match for instrumented pairs. This does not assert complete post-script DOM or every provider inline style is identical: those were not all captured.

## Draw/compositor timing and lifecycle

Every instrumented role recorded visual-state, onDraw, frame-commit and two animation callbacks. Frame commit proves submission, **not presentation**. Native geometry and barrier booleans match; absolute timestamps and load durations differ as expected for separate fresh views. Approximate host-to-device timing uses each saved uptime anchor; anchor half-interval is about9–10ms, with uptime quantization, so these are not presentation latency measurements.

| Saved case | Pixel result | Candidate / baseline FIRST screenshot start after onDraw, approximately ms |
|---|---|---|
| contact/en/pill/768 | 1,743 changed | **507.3 /270.6** |
| order/ku/pill/768 | 1 changed | **661.9 /165.5** |
| order/en/pill/768 (control) | exact | **630.8 /1030.6** |
| contact/ku/mint/430 (control) | exact | **953.3 /330.2** |
| order/ku/mint/430 | 1 changed | **174.9 /831.9** |
| order/en/mint/768 | 1 changed | **697.3 /237.8** |

There is no consistent rule that the faster/slower role produces the difference. Exact controls also have different timings. Candidate/baseline lifecycle and navigation durations differ, but all recorded finite visual state/geometry is stable before and after capture. Timing therefore remains a possible input, **not a demonstrated cause**. Raw safe timestamps, anchors, load phases and barrier ordering for these roles are preserved in the analysis JSON.

All 480 roles' three predetermined acceptance frames are exact repeats. All 12 post-acceptance PixelCopy crops match their own FIRST ADB crop; the four failing instrumented pairs' PixelCopy comparisons retain the same differences. This constrains an ADB-only read/PNG/crop artifact and an ordinary transient settling explanation. PixelCopy reads Flutter's existing surface; it does **not** isolate WebView raster output from Flutter composition or reveal a raster task, cache entry or display presentation fence. Stable output is not evidence that a particular GPU operation is nondeterministic.

## Pixel neighborhoods and causal limits

The paired 5×5 RGB neighborhoods for every failed case are in the JSON, recomputed from artifact PNGs. Single-pixel background failures leave the other24 samples identical. Alternating adjacent one-level values occur within both images; e.g. mint/en/768 row228 green is **[245,246,245,246,245]** candidate versus **[245,246,246,246,245]** baseline. That is compatible with quantization/dither/interpolation, but no intermediate color values or dithering/raster state were recorded, so **color interpolation is not proven**. The Kurdish glyph sample has neighboring exact ink, so attributing it exclusively to gradient interpolation or exclusively to text rasterization would also overstate the evidence.

| Possible cause | Evidence and limit |
|---|---|
| Layout / subpixel placement | No recorded candidate/baseline rectangle, transform, scale or scroll mismatch in the four instrumented failures. Four others lack these measurements; button rectangles/styles for the large band are also incomplete. No layout fix established. |
| Crop / screenshot read | Full crop correspondence checked; targeted PixelCopy equals own first crop and retains mismatch. No demonstrated wrong crop or ADB-only artifact. |
| Transient compositor settling | Three frames and later PixelCopy stay unchanged. This does not support a simple late-settle explanation; persistent composition state remains unisolated. |
| Gradient/text/shadow rasterization or color rounding | Failure locations and one-level values identify affected paint regions, not a specific arithmetic/raster mechanism. No raster-stage trace or intermediate pixels exist. |
| Lifecycle / load timing | Timing differs, including exact controls. Geometry/visual state does not change between before/after observations. No causal timing variable isolated. |
| GPU/WebView nondeterminism | **Not established.** Existing repeats remain stable; no same-input fresh-view A/A experiment or renderer trace is present. No such claim is made. |

The artifact permits a materially narrower analysis than “unknown”: a shadow band, one glyph edge, six smooth backgrounds; exact recorded geometry/styles; persistent own-surface differences; and specific measurement gaps. It does **not** contain enough information to prove one causal mechanism for all eight or prescribe a correct source fix. Missing facts cannot be recovered from the RGB crops or substituted from another case.

No fix or new execution is justified by this analysis. Zero changed pixels, complete240 pairs and all stable captures remain mandatory. Any next acquisition would need actual failed-coordinate hit/layer observations for the four missing cases and button shadows, plus a controlled measurement of raster/composition state—not a blind rerun or a changed acceptance frame. This report does not initiate that acquisition. PR#7 remains **Draft/open/unmerged**; no production actions occurred.

Source CI at the preserved report head **cb59d98fb9ae3d0bd70bd1fa55b4849f0d376e01** was rechecked: [37863191000](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37863191000) **SUCCESS**, all five jobs. Current management implementation remains intact. This publication changes documentation/evidence only; it requires no new product test run to substantiate a source change because there is no source change.


## Completion recheck and pinned-source input audit — 2026-10-09

Implementation source CI37940785293 and documentation-head source CI37942374733 at `dbf009ee6dcc74cdd64a9e02bbf6ec5258cf0863` are **SUCCESS**, all five jobs. The latter completed2026-10-09T14:18:23Z. Its ordinary APK37942374605 succeeded with native-runtime **SKIPPED**. These do not supersede the protected Android failure or certify the new Tools/Create external-browser journey.

Artifact11586077978 was downloaded again, SHA-256 verified against `4ae48def82e5a931ed79779ee75a272634d53202370376862734660e50b92ec8`, and all eight failed FIRST RGB pairs were recomputed again:232 exact/8 failed,1750 changed pixels,max channel delta1. The artifact has exactly ten JSON files; no additional hidden per-role DOM or renderer trace exists. The original twelve targeted roles remain the only native DOM/native/PixelCopy observations.

The added [source-input audit](evidence/proxolink-v6-2026-10-06/native-6c7e6c6-rca-2026-10-09/source-input-audit.json) invokes pinned preparedConfig/renderPrepared and the original safeImage/safeUrl functions on the template-preview handler's fictional fixtures, without outbound requests. It stores source hashes, payload/CSS hashes and safe branch results only. **It is a source-function test, not Android execution, a DOM observation, a replacement screenshot or new native acceptance evidence.**

| Source input | Candidate versus baseline | What is established |
|---|---|---|
| Config JSON/CSS for eight failed fixtures | Byte-identical payloads and CSS | No branch-specific config or stylesheet discrepancy in this pinned source replay. Runtime recorded hashes previously match where available. |
| Order relative avatar path | Candidate admits the typed Order avatar path; baseline only admits Contact/ad relative paths and rejects it | **Source branch difference PROVEN.** Candidate can construct an image and later invoke its error fallback; baseline immediately uses the initial fallback. The native request outcome and cache/draw consequences were not retained. Pixel causality **NOT PROVEN**. |
| Contact Viber URL parsing | Under the explicitly modeled opaque-parser condition, candidate validates the link and baseline rejects it; preview render retains both buttons | **Source branch difference PROVEN under that parser condition.** Native candidate checks recorded legacy_viber_url_parser=true for all80 Contact cases. Baseline href/resource/layer state at the failing capture was not retained. Pixel causality **NOT PROVEN**. |

The branch differences are not sufficient explanations: existing pinned pill/pill-mint Contact cases have38 exact/2 failed pairs, Order cases34 exact/6 failed, and Download cases40 exact/0 failed. Different viewports/types are controls, not same-input A/A tests. A resource or link branch may affect lifecycle conditionally; neither this association nor persistent one-level differences establishes that it did.

**Root cause remains NOT PROVEN after the additional source-input investigation.** Recorded layout/style/subpixel/viewport/native transforms match; stable three-frame output and matching post-acceptance PixelCopy rule out a demonstrated wrong crop or screenshot-only discrepancy. No raster-stage/intermediate color evidence separates gradient/text/shadow arithmetic from persistent composition/lifecycle state. GPU/WebView nondeterminism is not claimed.

The measurements needed for a causal fix are specific: actual changed-point ancestry/provider button styles for the four missing cases and shadow band; a per-role resource/result and full render-input hash ledger; WebView raster output before Flutter composition; and predetermined same-input fresh-view A/A observations with one controlled variable. Those native measurements cannot be reconstructed from the current artifact. No product/template/font/CSS/asset change, acceptance change, speculative fix or protected rerun was made. The latest instruction requires the RCA before any fix/rerun and a specific established cause before applying a fix; this publication does not initiate another execution.

The strict240-pair zero-difference requirement remains unchanged. Pinned old-builder chooser12/12 passed; the later new form intentionally has no live WebView and its Android thumbnail/external-browser/return journey remains unexecuted. PR#7 stays Draft/open/unmerged. No production actions occurred.
