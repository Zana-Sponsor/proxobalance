import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/widgets/receipt/receipt_kit.dart';

Rect receiptPaintedRect(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return MatrixUtils.transformRect(
      box.getTransformTo(null), Offset.zero & box.size);
}

/// Inspect actual laid-out glyph bounds, retained text and readable sizes.
/// Rows may grow to wrap long references or translated labels.
List<Map<String, dynamic>> auditReceiptRows(WidgetTester tester) {
  final measured = <Map<String, dynamic>>[];
  for (final element in find.byType(ReceiptRow).evaluate()) {
    final row = element.widget as ReceiptRow;
    final finder = find.byWidget(row);
    final texts = find.descendant(
        of: finder,
        matching: find.byWidgetPredicate((widget) => widget is Text));
    expect(texts, findsNWidgets(2));
    final bounds = receiptPaintedRect(tester, finder);
    final labelBounds = receiptPaintedRect(tester, texts.at(0));
    final valueBounds = receiptPaintedRect(tester, texts.at(1));
    expect(labelBounds.right, closeTo(bounds.right, 0.01));
    expect(valueBounds.left, closeTo(bounds.left, 0.01));
    expect(labelBounds.left - valueBounds.right,
        closeTo(ReceiptTokens.labelToValue, 0.01));
    final cardBounds = receiptPaintedRect(tester,
        find.ancestor(of: finder, matching: find.byType(ReceiptCard)).first);
    final inkBounds = <Rect>[];
    for (var i = 0; i < 2; i++) {
      final textFinder = texts.at(i);
      final text = tester.widget<Text>(textFinder);
      final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: textFinder, matching: find.byType(RichText)));
      expect(text.data, receiptSingleLine(i == 0 ? row.label : row.value));
      expect(text.maxLines, isNull);
      expect(text.softWrap, true);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      expect(text.style!.fontSize, greaterThanOrEqualTo(13));
      expect(text.style!.fontFamily, ReceiptTokens.fontFamily);
      expect(paragraph.didExceedMaxLines, false);
      final rendered =
          paragraph.text.toPlainText(includeSemanticsLabels: false);
      // Flutter includes hanging trailing whitespace outside the paragraph in
      // mixed RTL/LTR selections. Audit visible runs individually, retaining
      // strict bounds for every non-whitespace character.
      final visibleRuns = RegExp(r'[^\s\u2066-\u2069]+').allMatches(rendered);
      Rect? ink;
      for (final box in visibleRuns.expand((run) =>
          paragraph.getBoxesForSelection(
              TextSelection(baseOffset: run.start, extentOffset: run.end)))) {
        final glyph = Rect.fromPoints(
            paragraph.localToGlobal(Offset(box.left, box.top)),
            paragraph.localToGlobal(Offset(box.right, box.bottom)));
        ink = ink == null ? glyph : ink.expandToInclude(glyph);
        // Rabar's glyph ink can overhang its advance box (e.g. Kurdish ن),
        // so audit the actual padded card edges and the neighboring label,
        // rather than incorrectly requiring ink inside the advance width.
        expect(glyph.left, greaterThanOrEqualTo(cardBounds.left + 8));
        expect(glyph.right, lessThanOrEqualTo(cardBounds.right - 8));
        expect(glyph.top, greaterThanOrEqualTo(bounds.top - 0.1));
        expect(glyph.bottom, lessThanOrEqualTo(bounds.bottom + 0.1));
      }
      inkBounds.add(ink!);
      expect(receiptPaintedRect(tester, textFinder).bottom,
          lessThanOrEqualTo(bounds.bottom + 0.1));
    }
    expect(inkBounds[0].left - inkBounds[1].right, greaterThanOrEqualTo(4),
        reason: 'Label and value ink must remain visibly separated');
    measured.add({
      'label': row.label,
      'value': row.value,
      'row_width': bounds.width,
      'row_height': bounds.height,
      'label_font_size': tester.widget<Text>(texts.at(0)).style!.fontSize,
      'value_font_size': tester.widget<Text>(texts.at(1)).style!.fontSize
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
          closeTo(ReceiptTokens.rowToRow, 0.01));
    }
  }
  return measured;
}
