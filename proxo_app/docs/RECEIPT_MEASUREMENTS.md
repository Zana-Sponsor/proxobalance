# Measured single-line receipt audit

Measurements use Flutter render objects and the bundled Rabar_021 font.

| Property | Shared screen/PDF measurement |
| --- | --- |
| AppBar / receipt / section title | 13sp |
| Normal label / value / identifier | 11 / 11 / 11sp |
| Final total | 12sp |
| Flutter font weight | w400, existing font file unchanged |
| Letter spacing | 0 |
| Normal-scale row height | 20dp |
| Row height at text scale 1.3 / 2 | 24 / 34dp |
| Row-to-row gap | 8dp |
| Label/value column gap | 8dp |
| Label column | Natural width, capped at 40% |
| Heading to first row | 12dp |
| Divider | 1dp; inset 8dp; 12dp above/below |
| Card horizontal padding | 14 / 16 / 18dp, responsive |
| Card vertical padding / radius | 20 / 16dp |
| Page horizontal margins | 12 / 16 / 20dp, responsive |
| Surface top / bottom margin | 16 / 20dp |
| Page / card | White; subtle existing shadow |
| Heading color | #046CFA |

Every label and value is a single line. Natural text size includes system text scaling, then reduces only if the available column is too narrow. A common strut aligns the baselines even when a long identifier uses smaller type. No ellipsis, horizontal scrolling, or inserted identifier breaks are used.

## Recorded screen results

- 42 Ad Detail cases: seven widths, three text scales, two languages.
- 36 Transaction Detail cases: four transaction kinds, three statuses, three widths.
- 846 recorded rows: zero baseline error, zero vertical-center error; every column gap is 8dp.
- Card inset alignment and row spacing are asserted by the tests.
- Stress cases additionally cover very long identifiers, mixed-language names, long payment methods/labels and explicit input line breaks.

## PDF results

| Sample | Page size (pt) | Embedded image (px) | Maximum pixel difference |
| --- | --- | --- | --- |
| narrow_paid | 280 x 950 | 1120 x 3800 | 0 |
| standard_free | 393 x 627 | 1572 x 2508 | 0 |
| transaction_narrow | 280 x 519 | 1120 x 2076 | 0 |
| transaction_standard | 393 x 386 | 1572 x 1544 | 0 |

All four samples contain one complete page and were rendered with Poppler for visual review. The captured image inside every PDF exactly matches its Flutter surface. Sample exports and rendered previews are in single_line_audit/.

These tests verify the listed cases, not every possible device or input. Very long text must become small when constrained to one narrow line. PDF text remains rasterized, and native Android/iOS sharing needs device validation.

## Reproduce

From proxo_app:

```sh
flutter pub get
flutter test test/receipt_layout_test.dart test/receipt_pdf_test.dart test/ad_receipt_data_test.dart test/ad_detail_loading_test.dart --dart-define=RECEIPT_MEASUREMENTS=docs/receipt_measurements.json --dart-define=RECEIPT_PDF_CAPTURE=docs/single_line_audit --reporter expanded
```
