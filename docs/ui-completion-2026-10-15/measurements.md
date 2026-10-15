# Measured geometry

Bounds are `[x, y, width, height]` in logical pixels, from actual laid-out RenderObjects. Unless marked otherwise, these are Sorani at 393×852dp, DPR3, text scale1.0. Values are rounded to two decimal places here; raw values and full typography/colors remain in the JSON files.

| Element | Before | After |
|---|---|---|
| login: field 1 | [16, 317, 361, 50] | [16, 266, 361, 48] |
| login: field 2 | [16, 401, 361, 50] | [16, 348, 361, 48] |
| signup: field 1 | [16, 297, 361, 50] | [16, 192, 361, 48] |
| signup: field 2 | [16, 381, 361, 50] | [16, 280, 361, 52] |
| Home banner | [16, 72, 361, 146]; BorderRadius.circular(22.0); EdgeInsets.all(22.0) | [16, 72, 361, 107]; BorderRadius.circular(18.0); EdgeInsets.all(22.0) |
| Home Create Ad action | [264.67, 284, 112.33, 140]; BorderRadius.circular(18.0) | [263.33, 201, 113.67, 134]; RoundedRectangleBorder(BorderSide(color: Color(alpha: 1.0000, red: 0.8980, green: 0.9216, blue: 0.9569, colorSpace: ColorSpace.sRGB)), BorderRadius.circular(18.0)) |
| Navigation + hit target | [157.2, 772, 78.6, 80] | [157.2, 772, 78.6, 80] |
| Login heading, 280dp/2x | [16, 216, 248, 42]; font 16.00; line-height 1.3; text-scale 2.0 | [16, 142, 248, 64]; font 24.79; line-height 1.3; text-scale 2.0 |
| Profile balance text | [32, 304, 105.08, 25]; font 24.00; line-height 1.05; text-scale 1.0 | [34, 242, 105.08, 36]; font 24.00; line-height 1.5; text-scale 1.0 |
| Profile first account icon | [323, 584, 40, 40]; BorderRadius.circular(12.0) | [323, 429, 40, 40]; BorderRadius.circular(12.0) |

The [selected raw measurements](selected-measurements.json) include all rendered text, Container decoration and Material shape data for the gallery cases. The [complete compressed register](all-measurements.json.gz) retains every capture and lifecycle record across all 15 sections, three languages and both sizes. It can be expanded with `gzip -dk all-measurements.json.gz`.

Additional implemented dimensions: Home banner and action radii18dp; central + surface56×56dp/radius18dp and32dp glyph; payment-logo containment88×32dp; Profile avatar56dp. These are source-defined dimensions, not inferred pixel positions.

Timing checks: at400ms/4900ms both Create Ad notices remain fully present; at5500ms/10200ms the second notice remains fully present; by10800ms the stack is empty. The strict FIRST capture/opacity and size-factor checks remain enforced.
