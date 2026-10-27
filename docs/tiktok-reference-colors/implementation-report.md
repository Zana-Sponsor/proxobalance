# TikTok Create Ad — reference colors

The request “All colors same picture” applies the palette in [1000095918.jpg](../evidence/tiktok-reference-colors-2026-10-25/reference-user.jpg) to the existing balanced TikTok form. Colors were sampled inside the embedded white app screen, excluding the blue promotional background and phone frame. The earlier full-width final-price design remains in place.

## Reference palette

| Role | Implemented color | Application |
|---|---|---|
| Primary blue | `#0278FE` | Selected objectives, audience and schedule choices; Sponsor; sliders; links; total and loader; navigation create button |
| Secondary fill | `#EEF7FF` | Selected destination, connected account and payment option |
| Secondary border | `#2663B4` | Selected destination and expanded contact selector |
| Secondary text | `#3D7EC2` | Destination label/icon and contact selector label/arrow |
| Main ink | `#121215` | Headings, field text, account names and price label |
| Neutral gray | `#747578` | Inactive objective labels, helper text and navigation icons/labels |
| Neutral line | `#EEEEEE` | Inactive controls, fields, dividers and price/navigation edges |
| Coral badge | `#FE6F61` | The Kurdish “نوێ” badge, with white lettering |
| Contact surface | `#F6F9FE` | Contact selector and supporting panels |
| Contact border | `#CCD9E6` | Collapsed contact selector |
| White | `#FFFFFF` | Screen, unselected controls, fields, price bar and sheets |

[Sample coordinates, filters and medians](palette-samples.json) reproduce all eleven colors exactly. Run `python docs/tiktok-reference-colors/sample-reference.py` with Pillow installed to verify them. JPEG compression and antialiasing produce variations around edges, so the palette uses median interior or glyph-core samples rather than claiming every source-image pixel is one flat color.

## Scope and retained design

`TikTokAdTokens` defines the palette. An optional `AdFormColors` theme extension carries it into the shared payment, help, schedule and TikTok account/video controls, including captured modal themes. The Create Ad app bar and bottom navigation receive explicit color overrides. Shared defaults remain in place when the extension or overrides are absent.

All measured geometry matches the preceding price-reference revision: **27 spacing measurements**, 20dp gutters, 16dp heading gaps, 32dp section gaps, 50dp choices, 56dp fields, 64dp normal collapsed price, square price corners and zero navigation gap. Phone/tablet bounds, typography, large-text expansion, transitions, price anchoring and the separate Sponsor position are unchanged. Kurdish Sorani copy and the bundled Auth typeface remain intact.

The reference does not show every lower form section or expanded breakdown state. Those surfaces now use the same sampled palette consistently. Original provider/platform artwork remains untinted. Existing semantic discount green and error colors remain meaningful; the photo provides no corresponding error or discount sample. No receipt, Auth, backend, payment-service or provider behavior is redesigned.

## Verification

- **83 focused tests passed** across the complete capture flow, selection controls, form/recovery behavior, responsive layouts, payment sheets, account/video/QR behavior, Meta and the receipt reference golden.
- **Eight actual rendered-pixel assertions** verify primary fill, navigation create blue, secondary fill, contact fill, coral badge, both modal payment selections and modal confirm blue. The coordinates and pixel values are saved with the [rendered measurements](../evidence/tiktok-reference-colors-2026-10-25/measurements.json).
- **44 new PNGs and 8 review sheets** cover the full form, reference price states, discounts/errors/retry, 280/320/393dp phones, 200% text, 768dp tablet, both payment selections, Direct Message account/video selection and the video sheet.
- Re-rendered Meta form/payment/launcher captures match their committed baseline bytes. The exact receipt reference test passes. Historical galleries are preserved separately.
- Analysis of all sixteen edited Dart source/test files reports **zero errors and warnings**, with two pre-existing informational findings.
- [Verification record and log hashes](verification.json). Exact published-commit CI and native Android results are recorded on [PR #46](https://github.com/Zana-Sponsor/proxobalance/pull/46).

[Screenshot gallery](../evidence/tiktok-reference-colors-2026-10-25/README.md) · [Changed-file manifest](changed-files.txt) · [Prior final-price geometry](../tiktok-price-reference/implementation-report.md) · [Underlying 69-point form specification](../tiktok-balanced-ui/specification.md)

The captures use actual Flutter widgets and fictional fixtures. This is a palette match within the Kurdish Proxo screen; the reference includes different branding, Arabic copy and a cropped device frame. The PR remains draft, and this change does not publish production workflows or activate paid ads. The previously recorded backend/configuration and production acceptance blockers remain outstanding.
