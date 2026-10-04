import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/widgets/auth/auth_widgets.dart';
import 'package:proxo_app/widgets/proxo_text.dart';
import 'package:proxo_app/widgets/receipt/receipt_kit.dart';

const textKey = ValueKey('direction-text');
const previewKey = ValueKey('direction-preview');

Widget host(Widget child, {TextDirection direction = TextDirection.rtl}) =>
    MaterialApp(
      home: Directionality(
        textDirection: direction,
        child:
            Scaffold(body: Center(child: SizedBox(width: 280, child: child))),
      ),
    );

RenderParagraph paragraphOf(WidgetTester tester, Finder parent) =>
    tester.renderObject<RenderParagraph>(
        find.descendant(of: parent, matching: find.byType(RichText)).first);

void expectLtrToken(RenderParagraph paragraph, String token) {
  final rendered = paragraph.text.toPlainText(includeSemanticsLabels: false);
  expectLtrBoxes(rendered, token, paragraph.getBoxesForSelection);
}

void expectLtrBoxes(String rendered, String token,
    List<ui.TextBox> Function(TextSelection) boxesForSelection) {
  final offset = rendered.indexOf(token);
  expect(offset, greaterThanOrEqualTo(0));
  final centers = <double>[];
  for (var i = 0; i < token.length; i++) {
    final boxes = boxesForSelection(
        TextSelection(baseOffset: offset + i, extentOffset: offset + i + 1));
    expect(boxes, isNotEmpty, reason: 'Every character of $token is visible');
    centers.add((boxes.first.left + boxes.first.right) / 2);
  }
  for (var i = 1; i < centers.length; i++) {
    expect(centers[i], greaterThanOrEqualTo(centers[i - 1] - 0.01),
        reason: '$token retains its character order');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Rabar')
          ..addFont(rootBundle.load('assets/fonts/Rabar_021.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  const directions = <String, TextDirection>{
    'مێژووی مامەڵەکان': TextDirection.rtl,
    'تفاصيل المعاملة': TextDirection.rtl,
    'New Ad 2021': TextDirection.ltr,
    'PARZNFHCOKVL': TextDirection.ltr,
    '720079a8-9cf7-44de-b3af-f396d1aaf7d8': TextDirection.ltr,
    '19/09/2026 02:45 AM': TextDirection.ltr,
    '+9647501234567': TextDirection.ltr,
    '-36,000 د.ع': TextDirection.ltr,
    '١٢٣٬٤٥٦ د.ع': TextDirection.ltr,
    '١٢٣٤٥': TextDirection.ltr,
    '۱۲۳۴۵': TextDirection.ltr,
    '36,000': TextDirection.ltr,
    '🎉 مامەڵە 123': TextDirection.rtl,
    '123 مامەڵە': TextDirection.rtl,
    'Proxo ڕیکلام': TextDirection.ltr,
    'ڕیکلام Proxo': TextDirection.rtl,
  };
  for (final entry in directions.entries) {
    test('shared receipt/app direction for ${entry.key}', () {
      expect(ProxoTextDirection.of(entry.key), entry.value);
      expect(receiptDirOf(entry.key), entry.value);
    });
  }

  test('display isolation preserves raw content and is idempotent', () {
    const raw = 'کۆد ABC-123 و بڕ -12,345.67 IQD لە 19/09/2026';
    final display = ProxoTextDirection.display(raw);
    expect(display.replaceAll(RegExp(r'[\u2066-\u2069]'), ''), raw);
    expect(display, contains('\u2066-12,345.67 IQD\u2069'));
    expect(ProxoTextDirection.display(display), display);
    expect(ProxoTextDirection.display('English 123'), 'English 123');
  });

  test('rich styles share an isolate across adjacent spans', () {
    const span = TextSpan(children: [
      TextSpan(text: 'بڕ: '),
      TextSpan(text: 'USD ', style: TextStyle(color: Colors.blue)),
      TextSpan(
          text: '-12,345.67', style: TextStyle(fontWeight: FontWeight.w400)),
      TextSpan(text: ' بۆ ڕیکلام'),
    ]);
    final display = ProxoTextDirection.displaySpan(span, mixed: true);
    expect(display.toPlainText(includeSemanticsLabels: false),
        'بڕ: \u2066USD -12,345.67\u2069 بۆ ڕیکلام');
    final children = (display as TextSpan).children!;
    expect(
        (children[1] as TextSpan).style, (span.children![1] as TextSpan).style);
  });

  for (final direction in TextDirection.values) {
    for (final token in <String>[
      'ABC-123',
      '-12,345.67 IQD',
      '19/09/2026',
      '03:26 PM',
      '@zana_123',
      '١٢٣٬٤٥٦',
    ]) {
      testWidgets('$token stays LTR within RTL words / $direction',
          (tester) async {
        final raw = 'مامەڵە $token تەواوە';
        await tester.pumpWidget(host(
          ProxoText(raw, key: textKey, style: ReceiptTokens.rowValue),
          direction: direction,
        ));
        final text = tester.widget<ProxoText>(find.byKey(textKey));
        expect(text.data, raw);
        expect(text.textDirection, TextDirection.rtl);
        expectLtrToken(paragraphOf(tester, find.byKey(textKey)), token);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('language-specific alignment preserves explicit center alignment',
      (tester) async {
    for (final text in ['Kurdistan', 'کوردستان', 'كردستان', '123456']) {
      await tester.pumpWidget(host(ProxoText(
        text,
        key: textKey,
        textDirection: TextDirection.rtl,
        style: ReceiptTokens.rowValue,
      )));
      final paragraph = paragraphOf(tester, find.byKey(textKey));
      expect(paragraph.textDirection, ProxoTextDirection.of(text));
      expect(paragraph.textAlign, TextAlign.start);
    }
    await tester.pumpWidget(host(ProxoText(
      'English',
      key: textKey,
      textAlign: TextAlign.center,
      style: ReceiptTokens.rowValue,
    )));
    expect(
        paragraphOf(tester, find.byKey(textKey)).textAlign, TextAlign.center);
  });

  testWidgets('native text geometry and typography remain unchanged',
      (tester) async {
    for (final text in ['New Ad 2021', 'مێژووی مامەڵەکان', '-36,000 د.ع']) {
      await tester.pumpWidget(host(Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text,
              key: const ValueKey('native'),
              textDirection: ProxoTextDirection.of(text),
              style: ReceiptTokens.rowValue),
          ProxoText(text, key: textKey, style: ReceiptTokens.rowValue),
        ],
      )));
      final native = paragraphOf(tester, find.byKey(const ValueKey('native')));
      final shared = paragraphOf(tester, find.byKey(textKey));
      expect(shared.size.width, closeTo(native.size.width, 0.01));
      expect(shared.size.height, closeTo(native.size.height, 0.01));
      expect(
          shared.getDryBaseline(shared.constraints, TextBaseline.alphabetic),
          closeTo(
              native.getDryBaseline(native.constraints, TextBaseline.alphabetic)!, 0.01));
    }
  });

  testWidgets(
      'auth names switch direction without modifying input or selection',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final changes = <String>[];
    await tester.pumpWidget(host(AuthTextField(
      controller: controller,
      label: 'ناوی تەواو',
      hint: 'Name / ناو',
      icon: Icons.person_outline,
      keyboardType: TextInputType.name,
      onChanged: changes.add,
    )));
    for (final text in ['Zana Adam', 'زانا ئادەم', 'محمد', 'ABC-123']) {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump();
      expect(
          tester.widget<EditableText>(find.byType(EditableText)).textDirection,
          ProxoTextDirection.of(text));
      expect(controller.text, text);
      expect(changes.last, text);
    }
    const value = TextEditingValue(
      text: 'زانا ABC-123',
      selection: TextSelection.collapsed(offset: 8),
      composing: TextRange(start: 5, end: 8),
    );
    controller.value = value;
    await tester.pump();
    expect(controller.value, value);
    expect(changes.length, 4);
    final editable = tester.state<EditableTextState>(find.byType(EditableText));
    expectLtrBoxes(
      editable.renderEditable.text!.toPlainText(includeSemanticsLabels: false),
      'ABC-123',
      editable.renderEditable.getBoxesForSelection,
    );
  });

  testWidgets('phone, email, code and number fields keep LTR values',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    for (final type in [
      TextInputType.phone,
      TextInputType.emailAddress,
      TextInputType.url,
      const TextInputType.numberWithOptions(decimal: true, signed: true),
    ]) {
      await tester.pumpWidget(host(ProxoDirectionalInput(
        controller: controller,
        keyboardType: type,
        builder: (context, direction) => TextField(
          controller: controller,
          keyboardType: type,
          textDirection: direction,
          textAlign: TextAlign.start,
        ),
      )));
      await tester.enterText(find.byType(TextField), '-123456');
      await tester.pump();
      expect(
          tester.widget<EditableText>(find.byType(EditableText)).textDirection,
          TextDirection.ltr);
      expect(controller.text, '-123456');
    }
  });

  testWidgets('render direction examples with the receipt typography',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 440);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: RepaintBoundary(
        key: previewKey,
        child: Scaffold(
          backgroundColor: ReceiptTokens.page,
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                ProxoText('مێژووی مامەڵەکان', style: ReceiptTokens.barTitle),
                const SizedBox(height: 24),
                const ReceiptCard(
                  child: ReceiptRows([
                    ReceiptRow(label: 'ناو', value: 'New Ad 2021'),
                    ReceiptRow(label: 'کۆد', value: 'ABC-123'),
                    ReceiptRow(
                        label: 'ڕێکەوت', value: '19/09/2026 03:26 PM'),
                    ReceiptRow(label: 'بڕ', value: '-36,000 د.ع'),
                  ]),
                ),
                const SizedBox(height: 24),
                ProxoText('تفاصيل المعاملة', style: ReceiptTokens.barTitle),
                const SizedBox(height: 12),
                ProxoText('مامەڵە ABC-123 بە بڕی -36,000 IQD تەواوە',
                    style: ReceiptTokens.rowValue),
                const SizedBox(height: 12),
                ProxoText('Payment ABC-123 • 19/09/2026',
                    style: ReceiptTokens.rowValue),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    const output = String.fromEnvironment('TEXT_DIRECTION_PREVIEW');
    if (output.isNotEmpty) {
      await tester.runAsync(() async {
        final boundary =
            tester.renderObject<RenderRepaintBoundary>(find.byKey(previewKey));
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(output).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
