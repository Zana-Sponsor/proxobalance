# Receipt reference measurements

The supplied references are 963 x 1536 and 964 x 1536 pixels. They show the same ad receipt with a one-pixel width difference. The canonical Flutter surface is 393 x 627 dp at normal system text size. Measurements below are relative to the receipt surface, excluding the app bar and PDF button.

Both Ad Detail and Transaction Detail use `ReceiptSurface` and the shared receipt widgets. The surface lays out at 393 dp and uses one proportional paint transform to fit the available width. Margins, font sizes, shadow, radius, rules, and row spacing therefore retain fractional coordinates together. The transaction keeps its own fields and has a shorter height.

| Property | Canonical measurement |
| --- | --- |
| Receipt surface | 393 x 627 dp for the pictured ad |
| Card bounds (left, top, width, height) | 16, 16, 361, 591 dp |
| Row left / right edge | 32 / 361 dp |
| Divider left / right edge | 40 / 353 dp |
| Divider thickness | 1 dp |
| Divider top positions | 66, 139, 324, 453, 526 dp |
| Row top positions | 79, 107, 180, 208, 236, 264, 292, 365, 393, 421, 494, 539, 567 dp |
| Row height / gap | 20 / 8 dp |
| Card radius / horizontal padding | 16 / 16 dp |
| Card vertical padding | 20 dp |
| Surface top / bottom margin | 16 / 20 dp |
| Header / section font size | 13 sp |
| Labels, values, identifiers | 11 sp |
| Final total | 12 sp |
| Font family / Flutter weight | Rabar / w400 |
| Section color | #046CFA |
| Page / card | White |

The body uses the existing Rabar_021 font bytes. `w400` does not change the outlines of the bundled font. Identifiers remain complete on one line and preserve their original copied value. Larger system text is applied during canonical layout before proportional fitting.

## Verification

The coordinate regression covers widths 280, 393, 430, 963, and 964 dp with a 0.01 dp tolerance. Existing layout tests additionally cover seven widths, three text scales, Kurdish and Arabic, four transaction kinds, three statuses, and long mixed-language fields. Bounds and baselines are measured after the canvas transform.

PDF export captures the complete production surface at 4x resolution, including the card shadow and margins. Its page dimensions equal the displayed surface dimensions (1 dp = 1 PDF point); it adds no A4 margins or separate PDF typography. Pixel comparisons inspect the embedded image against the Flutter capture, then Poppler renders are reviewed visually.

The attached references are resized images, so their RGB pixels also reflect resampling/compression. The coordinate checks measure layout precision; screenshot RGB comparison is reported separately in `receipt_pdf_comparison.json`.

## Reproduce

```sh
CI=true flutter pub get
CI=true flutter test test/receipt_layout_test.dart test/receipt_pdf_test.dart test/ad_receipt_data_test.dart test/ad_detail_loading_test.dart --dart-define=RECEIPT_MEASUREMENTS=docs/receipt_measurements.json --dart-define=RECEIPT_PDF_CAPTURE=docs/single_line_audit --reporter expanded
```
