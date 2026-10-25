# TikTok Final Price — supplied-image correction

The user supplied [1000095918.jpg](../evidence/tiktok-price-reference-2026-10-25/reference-user.jpg) and identified **السعر النهائي** as the required design. That image shows a flat white bottom bar spanning the phone content width, square edges, a right-aligned label, and a segmented loading indicator on the left. This follow-up applies those visible characteristics to Proxo's Kurdish price breakdown.

It supersedes the earlier inset 10dp-radius / 72dp-height / 2dp-gap interpretation. The [earlier 69-point report](../tiktok-balanced-ui/implementation-report.md) remains the form specification, with price geometry replaced by this later image.

## Exact implementation

| Detail | Current implementation |
|---|---|
| Outer width | Full viewport: 393dp, 320dp, 280dp and 768dp verified |
| Outer horizontal margin | 0dp |
| Corners | Square, 0dp radius |
| Navigation gap | 0dp; bottom edge touches the existing navigation |
| Collapsed height | 64dp at normal text; grows to 116dp at 320/280dp with 200% text |
| Inner horizontal padding | 20dp on phones; centered 600dp content on tablets |
| Surface | White; soft upward shadow, #0A0F172A, blur 10dp, offset (0,-2) |
| Top edge | 1dp #F1F3F5 line, painted without changing layout |
| Label | Kurdish کۆی گشتی, Auth face, 15sp / 600 / line height 1.5, right aligned |
| Amount | 16sp / 600 / line height 1.5, existing medium blue, left aligned |
| Loader | 20dp segmented indicator at the same left amount position |
| Disclosure | Internal 22dp chevron / 48dp target, fades during loading while retaining geometry and semantics |
| Header interaction | Whole header still toggles while loading; no layout jump |
| Expansion | Same surface grows upward, 200ms easeOutCubic; fixed bottom, divider, total and navigation |
| Breakdown | Existing unit price, service fee, real optional discount; consistently aligned amounts |
| Sponsor | Separate scrollable form button; remains reachable above the expanded price |

The reference does not show expanded rows. Those retain the previously specified breakdown contents, upward expansion, authoritative quote handling and accessible narrow-screen behavior inside the new flush surface.

## Whole-screen review

The picture's other visible design cues were checked against the existing Proxo form: open white sections, solid-blue primary selections, gray inactive primary choices, pale-blue secondary selections, and right-aligned headings. The Auth font, Kurdish labels, four supported ad types, existing ad-name field and destination interactions retain the prior form structure. This follow-up changes the price component; it does not add the reference app's additional objectives or branding.

Five comparable captures (top, selected objective, destination, collapsed page and expanded page) are **pixel-identical above the old/new price region** to the prior revision. The comparison bounds are `(0, 0, 786, 1320)` in the 2x PNGs. All 27 measured form transitions remain unchanged: 20dp gutters, 16dp heading gaps, 32dp section gaps and 8dp field/helper gaps.

## Verification

- **48 focused tests passed**: actual price rendering, quote/error recovery, disclosure during loading, page/navigation behavior, narrow screens, 300% text/keyboard conditions and the receipt reference golden.
- Analysis of all four edited source/test files: no errors or warnings; one pre-existing informational interpolation finding.
- **39 fresh PNGs and 7 review sheets** were visually reviewed, including phone, tablet, loading, expansion, discount, error recovery and large-text detail scrolling.
- Receipt, backend/provider/payment service files, fonts, navigation implementation and Meta defaults were not changed.
- GitHub checks for the published revision are recorded on PR #46; previous commit results are not used as proof for this source revision.

[Current gallery](../evidence/tiktok-price-reference-2026-10-25/README.md) · [Actual measurements](../evidence/tiktok-price-reference-2026-10-25/measurements.json) · [Verification and log hashes](verification.json) · [Exact file manifest](changed-files.txt)

The captures render actual app widgets with fictional fixture data. The supplied photo is a visual reference, not an identical-size raster golden: it includes another app's branding, Arabic text and a cropped device frame. The implemented price geometry and loading layout are explicitly measured above.
