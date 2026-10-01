# Single-line receipt implementation

Applies to Ad Detail (`ad_detail_screen.dart`) and Transaction Detail (`transaction_detail_screen.dart`, the transaction screen referred to as translation_detail). Both already consume the same receipt kit, so the shared implementation fixes every row in both screens.

## Row layout

- Normal labels, values, and identifiers use Rabar_021 at 11sp, w400, #111111. The bundled font is unchanged. Totals retain the existing modest 12sp emphasis. Section headings remain 13sp, #046CFA.
- Labels stay at the physical right card inset, values at the physical left card inset, with an 8dp column gap.
- A label gets its measured natural width, capped at 40% of the row. The value gets all remaining width through Expanded.
- Both cells are measured using TextPainter. A cell keeps its natural size whenever it fits; otherwise its font is reduced just enough to display the entire string. No minimum-size floor forces clipping or truncation.
- Every cell explicitly uses maxLines: 1, softWrap: false, and no ellipsis. Embedded newlines/tabs become spaces for display, retaining every word. Stored and copied identifiers remain unchanged.
- A shared forced strut keeps the same line height and baseline for labels, normal values, totals, and fitted identifiers. All rows are 20dp at normal text scale; larger system text scales enlarge the common line box, while cells still fit their available widths.
- Long strings cannot increase row height or shift their label. The row gap remains 8dp; card padding, section order, headings, divider spacing, logo and shadow retain the shared design tokens.
- Identifiers, dates and amounts retain explicit LTR rendering inside the RTL layout. Public P-prefixed Ad ID, receipt UUID and payment transaction ID remain separate original values.

## Screen and PDF

The existing production PDF exporter captures the complete on-screen ReceiptSurface at 4x resolution. There is no separate text layout to wrap or resize fields differently in PDF. The card, whitespace, shadow, line fitting and proportions are identical. The PDF remains an image-based receipt; text is not independently selectable.

## Verification

109 receipt-related Flutter tests passed with Flutter 3.47.5 / Dart 3.13.4:

- Seven Ad Detail widths (280, 320, 360, about 393, 430, 480, 640dp), three text scales (1, 1.3, 2), Kurdish and Arabic.
- All four transaction kinds, three statuses, and widths 280/393/640dp.
- Complete UUID 720079a8-9cf7-44de-b3af-f396d1aaf7d8, P-prefixed public IDs, transaction IDs, long mixed-language names, long labels/payment methods, and explicit line breaks.
- Rendered glyph bounds and final-character coverage; no overflow, truncation, or missing last character in the tested rows. Exact copy behavior retained.
- 78 recorded screen cases containing 846 rows. Baseline and vertical-center differences were zero; the column gap was 8dp throughout.
- Four production PDF exports: standard/narrow Ad and Transaction receipts, including an Arabic transaction sample. Each is one complete page; extracted PDF image pixels exactly match the corresponding Flutter capture.
- Rendered PDFs were visually reviewed. Very long strings on narrow screens necessarily use smaller type to satisfy the complete single-line requirement.

Scoped analysis reported no errors or warnings and one brace-style informational lint in a test; that brace was corrected. The SDK was no longer available after the session resumed, so analysis was not rerun after that formatting-only change. No native APK/iOS build or device share-dialog verification is claimed for this revision.

See RECEIPT_MEASUREMENTS.md, receipt_measurements.json, receipt_pdf_comparison.json, and single_line_audit/ for fixtures and detailed measurements. All samples use synthetic fixture data and are not live receipts. No backend/payment logic was changed.
