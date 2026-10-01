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
  final surfaces = find.byType(ReceiptSurface);
  final factor = surfaces.evaluate().isEmpty
      ? 1.0
      : tester.getSize(surfaces.first).width / ReceiptTokens.referenceWidth;
  double? rowHeight;
  for (final element in find.byType(ReceiptRow).evaluate()) {
    final row = element.widget as ReceiptRow;
    final finder = find.byWidget(row);
    final texts = find.descendant(of: finder, matching: find.byType(Text));
    expect(texts, findsNWidgets(2));
    final labelFinder = texts.at(0);
    final valueFinder = texts.at(1);
    final bounds = receiptPaintedRect(tester, finder);
    final labelBounds = receiptPaintedRect(tester, labelFinder);
    final valueBounds = receiptPaintedRect(tester, valueFinder);
    rowHeight ??= bounds.height;
    expect(bounds.height, closeTo(rowHeight, 0.01));
    expect(labelBounds.right, closeTo(bounds.right, 0.01));
    expect(valueBounds.left, closeTo(bounds.left, 0.01));
    expect(labelBounds.left - valueBounds.right,
        closeTo(ReceiptTokens.labelToValue * factor, 0.01));
    expect(labelBounds.center.dy, closeTo(bounds.center.dy, 0.01));
    expect(valueBounds.center.dy, closeTo(bounds.center.dy, 0.01));

    final baselines = <double>[];
    for (var i = 0; i < 2; i++) {
      final textFinder = texts.at(i);
      final text = tester.widget<Text>(textFinder);
      final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: textFinder, matching: find.byType(RichText)));
      expect(text.data, receiptSingleLine(i == 0 ? row.label : row.value));
      expect(text.maxLines, 1);
      expect(text.softWrap, false);
      expect(text.overflow, TextOverflow.visible);
      expect(
          text.textDirection, i == 0 ? TextDirection.rtl : row.valueDirection);
      expect(text.style!.fontWeight, FontWeight.w400);
      expect(text.style!.fontFamily, ReceiptTokens.fontFamily);
      expect(paragraph.didExceedMaxLines, false);
      final glyphs = paragraph.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: text.data!.length));
      for (final box in glyphs) {
        expect(box.left, greaterThanOrEqualTo(-0.05));
        expect(box.right, lessThanOrEqualTo(paragraph.size.width + 0.05));
        // All directional runs belong to the same single line.
        expect(box.top, closeTo(glyphs.first.top, 0.01));
        expect(box.bottom, closeTo(glyphs.first.bottom, 0.01));
      }
      // The final character is still laid out, even for a very long UUID/name.
      if (text.data!.isNotEmpty) {
        expect(
            paragraph.getBoxesForSelection(TextSelection(
                baseOffset: text.data!.length - 1,
                extentOffset: text.data!.length)),
            isNotEmpty);
      }
      final baseline = paragraph.getDryBaseline(
          paragraph.constraints, TextBaseline.alphabetic)!;
      baselines.add(paragraph.localToGlobal(Offset(0, baseline)).dy);
    }
    expect(baselines[0], closeTo(baselines[1], 0.01));
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
      'single_line': true,
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
