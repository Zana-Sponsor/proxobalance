import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/widgets/receipt/receipt_kit.dart';

/// Includes the canonical canvas transform when auditing physical bounds.
Rect receiptPaintedRect(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return MatrixUtils.transformRect(
      box.getTransformTo(null), Offset.zero & box.size);
}

/// Audit painted text bounds, complete glyph coverage, common baselines,
/// physical edges and row rhythm, rather than only checking widget flags.
List<Map<String, dynamic>> auditReceiptRows(WidgetTester tester) {
  final measured = <Map<String, dynamic>>[];
  const factor = 1.0;
  for (final element in find.byType(ReceiptRow).evaluate()) {
    final row = element.widget as ReceiptRow;
    final finder = find.byWidget(row);
    final texts = find.descendant(
        of: finder,
        matching: find.byWidgetPredicate((widget) => widget is Text));
    expect(texts, findsNWidgets(2));
    final labelFinder = texts.at(0);
    final valueFinder = texts.at(1);
    final bounds = receiptPaintedRect(tester, finder);
    final labelBounds = receiptPaintedRect(tester, labelFinder);
    final valueBounds = receiptPaintedRect(tester, valueFinder);
    final stacked = valueBounds.top >= labelBounds.bottom;
    expect(labelBounds.right, closeTo(bounds.right, 0.01));
    expect(valueBounds.left, closeTo(bounds.left, 0.01));
    if (stacked) {
      expect(valueBounds.top - labelBounds.bottom, closeTo(ReceiptTokens.rowToRow, 0.01));
    } else {
      expect(labelBounds.left - valueBounds.right, closeTo(ReceiptTokens.labelToValue, 0.01));
    }

    final baselines = <double>[];
    for (var i = 0; i < 2; i++) {
      final textFinder = texts.at(i);
      final text = tester.widget<Text>(textFinder);
      final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: textFinder, matching: find.byType(RichText)));
      expect(text.data, i == 0 ? row.label : row.value);
      expect(text.maxLines, isNull);
      expect(text.softWrap, true);
      expect(
          text.textDirection, i == 0 ? receiptDirOf(row.label) : row.valueDirection);
      expect(text.style!.fontWeight, FontWeight.w400);
      expect(text.style!.fontFamily, ReceiptTokens.fontFamily);
      expect(text.style!.fontSize, i == 0 ? ReceiptTokens.labelSize : (row.valueStyle ?? ReceiptTokens.rowValue).fontSize);
      expect(paragraph.didExceedMaxLines, false);
      final rendered =
          paragraph.text.toPlainText(includeSemanticsLabels: false);
      final glyphs = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: rendered.length));
      for (final box in glyphs) {
        expect(box.left, greaterThanOrEqualTo(-0.05));
        expect(box.right, lessThanOrEqualTo(paragraph.size.width + 0.05));
      }
      // The final character is still laid out, even for a very long UUID/name.
      var finalCharacter = rendered.length - 1;
      while (finalCharacter >= 0 &&
          rendered.codeUnitAt(finalCharacter) >= 0x2066 &&
          rendered.codeUnitAt(finalCharacter) <= 0x2069) {
        finalCharacter--;
      }
      if (finalCharacter >= 0) {
        expect(
            paragraph.getBoxesForSelection(TextSelection(
                baseOffset: finalCharacter, extentOffset: finalCharacter + 1)),
            isNotEmpty);
      }
      final baseline = paragraph.getDryBaseline(
          paragraph.constraints, TextBaseline.alphabetic)!;
      baselines.add(paragraph.localToGlobal(Offset(0, baseline)).dy);
    }
    if (!stacked) expect(baselines[0], closeTo(baselines[1], 0.01));
    measured.add({
      'label': row.label,
      'value': row.value,
      'row_width': bounds.width,
      'row_height': bounds.height,
      'label_width': labelBounds.width,
      'value_width': valueBounds.width,
      'label_value_gap': labelBounds.left - valueBounds.right,
      'baseline_error': (baselines[0] - baselines[1]).abs(),
      'center_error': (labelBounds.center.dy - valueBounds.center.dy).abs(),
      'label_font_size': tester.widget<Text>(labelFinder).style!.fontSize,
      'value_font_size': tester.widget<Text>(valueFinder).style!.fontSize,
      'stacked': stacked,
    });
  }
  expect(measured, isNotEmpty);
  for (final group in find.byType(ReceiptRows).evaluate()) {
    final rows = find.descendant(
        of: find.byWidget(group.widget), matching: find.byType(ReceiptRow));
    for (var i = 1; i < rows.evaluate().length; i++) {
      expect(
          receiptPaintedRect(tester, rows.at(i)).top -
              receiptPaintedRect(tester, rows.at(i - 1)).bottom,
          closeTo(ReceiptTokens.rowToRow * factor, 0.01));
    }
  }
  return measured;
}
