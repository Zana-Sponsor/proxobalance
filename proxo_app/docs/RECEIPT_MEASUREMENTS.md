# Receipt reference measurements

The current supplied reference is 1283 × 2048 pixels. It is a resized version of the existing 1572 × 2508 PNG in `receipt_preview.png`. The canonical Flutter surface is **393 × 627 logical pixels at normal text size**, captured at 4× resolution. Measurements exclude the app bar and PDF button.

Both advertisement and transaction receipts use the same receipt components. At the reference width, the pictured advertisement matches the original PNG exactly. Other widths retain native text sizing: long fields wrap, enlarged text can stack labels and values, and overflowing identifiers use a full-width single-line scroll area. Transaction receipts retain their own fields and status; their height follows their content.

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
| Font family / Flutter weight | ProxoReceipt (Rabar_021 bytes) / w400 |
| Section color | #046CFA |
| Page / card | White |

The receipt-only `ProxoReceipt` family uses the existing Rabar_021 font bytes. The font has its original bold outlines; Flutter requests w400 without synthesizing extra weight. Shared app headers and transaction history retain their existing Rabar_022 typography.

Fitting identifiers occupy the original compact row and can be copied by long press. An overflowing identifier gets a full-width horizontal viewport and a visible copy action. All identifiers preserve their complete raw value.

## Verification

`receipt_reference_match_test.dart` compares the actual production card against the unchanged historical PNG at 4× resolution. It also asserts the surface, card, five divider positions and thirteen row rectangles above exactly. Do not regenerate the reference to accept a design change.

The wider layout suite covers Kurdish and Arabic, representative 280–964dp widths, 100%, 130% and 200% text, and long mixed-language fields. Separate responsive tests include 240dp at 300% text. Glyph coverage, baselines, wrapping, copied IDs and control recovery are checked.

PDF export captures the production surface at 4× resolution. It places that artwork on A4 pages with 36-point margins and splits long receipts between protected rows. Fitting identifiers remain untouched in the captured artwork; only overflowing identifier viewports are repainted with the complete code for export. Full identifiers also remain in PDF metadata.

The supplied attachment has resampling differences relative to its original PNG. Exact canonical matching and the separate uploaded-image comparison are recorded in [the reference report](../../docs/evidence/receipt-reference-match-2026-10-23/README.md).

## Reproduce

```sh
flutter test --no-pub test/receipt_reference_match_test.dart --dart-define=RECEIPT_REFERENCE_CAPTURE=build/receipt-reference/canonical.png --reporter expanded
flutter test --no-pub test/receipt_layout_test.dart test/receipt_pdf_test.dart test/ad_receipt_data_test.dart test/ad_detail_loading_test.dart --dart-define=RECEIPT_PDF_CAPTURE=build/receipt-reference/exports --reporter expanded
```
