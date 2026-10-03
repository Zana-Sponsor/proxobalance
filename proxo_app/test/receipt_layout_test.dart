import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/l10n/ad_detail_strings.dart';
import 'package:proxo_app/models/ad_receipt_data.dart';
import 'package:proxo_app/screens/transaction_detail_screen.dart';
import 'package:proxo_app/widgets/receipt/ad_receipt_card.dart';
import 'package:proxo_app/widgets/receipt/receipt_kit.dart';

import 'ad_receipt_data_test.dart' show receiptFixture, freeReceiptFixture;
import 'receipt_test_helpers.dart';

Widget receiptHost({
  required AdDetailStrings strings,
  required Map<String, dynamic> data,
  required double scale,
  Future<void> Function()? onPdf,
}) =>
    MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              backgroundColor: ReceiptTokens.page,
              body: Column(
                children: <Widget>[
                  ReceiptAppBar(title: strings.appBarTitle, onBack: () {}),
                  Expanded(
                    child: ReceiptBody(
                      children: <Widget>[
                        ReceiptSurface(
                          child: AdReceiptCard(
                            r: AdReceiptData.from(data, strings),
                            l: strings,
                            onCopy: (_) {},
                          ),
                        ),
                        ReceiptWidth(
                          child: ReceiptPdfButton(
                            label: strings.pdfButton,
                            onPressed: onPdf ?? () async {},
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

// Match production paint: the default test binding disables shadow blur.
class ReceiptPaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

void main() {
  ReceiptPaintBinding();
  final measurements = <Map<String, dynamic>>[];
  const measurementPath = String.fromEnvironment('RECEIPT_MEASUREMENTS');
  tearDownAll(() async {
    if (measurementPath.isNotEmpty) {
      await File(measurementPath).writeAsString(
          const JsonEncoder.withIndent('  ').convert(measurements));
    }
  });

  setUpAll(() async {
    final loader = FontLoader(ReceiptTokens.fontFamily)
      ..addFont(rootBundle.load('assets/fonts/Rabar_021.ttf'));
    await loader.load();
  });

  // Coordinates measured from the supplied receipt, normalized to 393 dp.
  // Checking independent anchors catches cumulative spacing drift that a
  // per-row gap assertion alone would miss.
  for (final width in <double>[280, 393, 430, 963, 964]) {
    testWidgets('reference receipt coordinates at $width dp', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, width * 2);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final strings = AdDetailStrings.of(const Locale('ckb'));
      final data = freeReceiptFixture()
        ..['public_ad_id'] = 'PARZNFHCOKVL'
        ..['title'] = 'New Ad 2021';
      await tester.pumpWidget(
        receiptHost(strings: strings, data: data, scale: 1),
      );
      await tester.pumpAndSettle();
      final factor = width / 393;
      final surface = receiptPaintedRect(tester, find.byType(ReceiptSurface));
      final card = receiptPaintedRect(tester, find.byType(ReceiptCard));
      expect(surface.height, closeTo(627 * factor, 0.01));
      expect(card.left, closeTo(16 * factor, 0.01));
      expect(card.width, closeTo(361 * factor, 0.01));
      expect(card.top - surface.top, closeTo(16 * factor, 0.01));
      expect(card.height, closeTo(591 * factor, 0.01));
      const ruleY = <double>[66, 139, 324, 453, 526];
      final dividers = find.byType(ReceiptDivider);
      expect(dividers, findsNWidgets(ruleY.length));
      for (var i = 0; i < ruleY.length; i++) {
        final rule = receiptPaintedRect(
          tester,
          find.descendant(
            of: dividers.at(i),
            matching: find.byType(ColoredBox),
          ),
        );
        expect(rule.left, closeTo(40 * factor, 0.01));
        expect(rule.width, closeTo(313 * factor, 0.01));
        expect(rule.top - surface.top, closeTo(ruleY[i] * factor, 0.01));
        expect(rule.height, closeTo(factor, 0.01));
      }
      const rowY = <double>[
        79,
        107,
        180,
        208,
        236,
        264,
        292,
        365,
        393,
        421,
        494,
        539,
        567,
      ];
      final rows = find.byType(ReceiptRow);
      expect(rows, findsNWidgets(rowY.length));
      for (var i = 0; i < rowY.length; i++) {
        final row = receiptPaintedRect(tester, rows.at(i));
        expect(row.left, closeTo(32 * factor, 0.01));
        expect(row.right, closeTo(361 * factor, 0.01));
        expect(row.top - surface.top, closeTo(rowY[i] * factor, 0.01));
        expect(row.height, closeTo(20 * factor, 0.01));
      }
      auditReceiptRows(tester);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in <double>[280, 320, 360, 1080 / 2.75, 430, 480, 640]) {
    for (final scale in <double>[1, 1.3, 2]) {
      for (final language in <String>['ckb', 'ar']) {
        testWidgets('RTL receipt at $width dp, scale $scale, $language', (
          tester,
        ) async {
          final density = width == 320
              ? 1.0
              : width == 430
                  ? 3.0
                  : 2.75;
          tester.view.devicePixelRatio = density;
          tester.view.physicalSize = Size(width * density, 900 * density);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final strings = AdDetailStrings.of(Locale(language));
          final data = receiptFixture()
            ..['id'] = '720079a8-9cf7-44de-b3af-f396d1aaf7d8'
            ..['title'] = 'Summer Campaign — ڕیکلامێکی درێژ بۆ تاقیکردنەوە';
          await tester.pumpWidget(
            receiptHost(strings: strings, data: data, scale: scale),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          expect(
            tester.getCenter(find.text(strings.appBarTitle)).dx,
            closeTo(width / 2, 0.01),
          );
          expect(
            tester.getCenter(find.byType(IconButton)).dx,
            greaterThan(width / 2),
          );
          expect(find.byType(BottomNavigationBar), findsNothing);

          final measuredRows = auditReceiptRows(tester);
          final factor = width / ReceiptTokens.referenceWidth;
          final cardBounds =
              receiptPaintedRect(tester, find.byType(ReceiptCard));
          final expectedInset =
              ReceiptTokens.cardInset(cardBounds.width) * factor;
          for (final row in find.byType(ReceiptRow).evaluate()) {
            final bounds =
                receiptPaintedRect(tester, find.byWidget(row.widget));
            expect(bounds.left, closeTo(cardBounds.left + expectedInset, 0.01));
            expect(
                bounds.right, closeTo(cardBounds.right - expectedInset, 0.01));
          }

          final uid = find.text(data['id'] as String);
          final uidText = tester.widget<Text>(uid);
          expect(uidText.textDirection, TextDirection.ltr);
          expect(uidText.maxLines, 1);
          expect(uidText.softWrap, false);
          expect(uidText.style!.fontSize, lessThanOrEqualTo(11 * scale));
          expect(uidText.overflow, isNot(TextOverflow.ellipsis));
          expect(find.text(strings.receiptNo), findsOneWidget);
          final adId = find.text(data['public_ad_id'] as String);
          expect(
              receiptPaintedRect(tester, adId).bottom,
              lessThan(receiptPaintedRect(
                      tester, find.text(AdReceiptData.from(data, strings).date))
                  .top));
          expect(
              receiptPaintedRect(tester, uid).top,
              greaterThan(
                  receiptPaintedRect(tester, find.text(data['title'] as String))
                      .bottom));
          for (final heading in find.byType(ReceiptSectionHeading).evaluate()) {
            final box =
                receiptPaintedRect(tester, find.byWidget(heading.widget));
            final text = receiptPaintedRect(
                tester,
                find.descendant(
                    of: find.byWidget(heading.widget),
                    matching:
                        find.byWidgetPredicate((widget) => widget is Text)));
            expect(box.bottom - text.bottom, closeTo(12 * factor, 0.01));
          }
          expect(ReceiptTokens.page, Colors.white);
          expect(ReceiptTokens.card, Colors.white);
          final decoration = tester
              .widget<DecoratedBox>(find
                  .descendant(
                      of: find.byType(ReceiptCard),
                      matching: find.byType(DecoratedBox))
                  .first)
              .decoration as BoxDecoration;
          expect(decoration.border, isNull);
          expect(decoration.boxShadow!.single.color, const Color(0x0F000000));
          expect(receiptPaintedRect(tester, uid).left, greaterThanOrEqualTo(0));
          expect(
              receiptPaintedRect(tester, uid).right, lessThanOrEqualTo(width));
          for (final icon in tester.widgetList<Icon>(find.byType(Icon))) {
            expect(icon.size, 16);
          }
          expect(ReceiptTokens.rowValue.fontSize, 11);
          for (final divider in find.byType(ReceiptDivider).evaluate()) {
            expect(
                receiptPaintedRect(tester, find.byWidget(divider.widget))
                    .height,
                closeTo(25 * factor, 0.01));
          }
          measurements.add({
            'screen_width': width,
            'text_scale': scale,
            'locale': language,
            'card_width': cardBounds.width,
            'card_height': cardBounds.height,
            'page_margin': cardBounds.left,
            'card_inset': expectedInset,
            'heading_font_size': ReceiptTokens.heading.fontSize! * factor,
            'heading_gap': ReceiptTokens.headingToRow * factor,
            'row_gap': ReceiptTokens.rowToRow * factor,
            'divider_height_with_spacing': 25 * factor,
            'rows': measuredRows,
          });

          final receipt = find.byType(AdReceiptCard);
          final texts = find.descendant(
            of: receipt,
            matching: find.byWidgetPredicate((widget) => widget is Text),
          );
          for (final element in texts.evaluate()) {
            final text = element.widget as Text;
            expect(text.style!.fontFamily, ReceiptTokens.fontFamily);
            expect(text.style!.fontWeight, FontWeight.w400);
            final isHeading = find
                .ancestor(
                  of: find.byWidget(text),
                  matching: find.byType(ReceiptSectionHeading),
                )
                .evaluate()
                .isNotEmpty;
            expect(
              text.style!.color,
              isHeading ? const Color(0xFF046CFA) : const Color(0xFF111111),
            );
          }

          await tester.scrollUntilVisible(find.byType(ReceiptPdfButton), 200,
              scrollable: find.byType(Scrollable));
          await tester.pumpAndSettle();
          final card = receiptPaintedRect(tester, find.byType(ReceiptCard));
          final button =
              receiptPaintedRect(tester, find.byType(ReceiptPdfButton));
          final margin = ReceiptTokens.pageGutter(width);
          expect(card.left, closeTo(margin, 0.01));
          expect(card.width, closeTo(width - margin * 2, 0.01));
          expect(button.left, closeTo(card.left, 0.01));
          expect(button.width, closeTo(card.width, 0.01));
          expect(button.top - card.bottom, closeTo(20 * factor, 0.01));
          await tester.scrollUntilVisible(find.byType(ReceiptPdfButton), 200,
              scrollable: find.byType(Scrollable));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets(
    'long references fit completely on one line and copying preserves the original',
    (tester) async {
      final reference =
          '${List.filled(12, 'long-reference').join('-')}@example.com';
      String? copied;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 228,
                child: ReceiptIdentifierRow(
                  label: 'ژمارەی مامەڵە',
                  value: reference,
                  onLongPress: () => copied = reference,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final value = tester.widget<Text>(find.text(reference));
      expect(value.maxLines, 1);
      expect(value.softWrap, false);
      expect(value.style!.fontSize, lessThan(11));
      auditReceiptRows(tester);
      expect(tester.getSize(find.byType(ReceiptRow)).height, 20);
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(value.overflow, isNot(TextOverflow.ellipsis));
      expect(
        receiptPaintedRect(tester, find.text(reference)).width,
        lessThanOrEqualTo(228.01),
      );
      await tester.longPress(find.text('ژمارەی مامەڵە'));
      expect(copied, reference);
      expect(tester.takeException(), isNull);
    },
  );

  for (final kind in TxReceiptKind.values) {
    for (final status in <String>['approved', 'pending', 'rejected']) {
      for (final width in <double>[280, 393, 640]) {
        testWidgets(
          'transaction $kind / $status at $width preserves complete IDs and neutral amounts',
          (tester) async {
            tester.view.devicePixelRatio = 3;
            tester.view.physicalSize = Size(width * 3, 2700);
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            const txId = 'de08d3c4-bb04-4ac9-a3c0-94a336f60aab';
            const uid = '63f02697-6351-457e-a89e-54241de8461a';
            await tester.pumpWidget(
              MaterialApp(
                home: TransactionDetailScreen(
                  data: TxReceiptData(
                    kind: kind,
                    status: status,
                    txId: txId,
                    uid: uid,
                    date: DateTime.utc(2026, 9, 18),
                    usd: 15,
                    amountIqd: 21000,
                    balanceBefore: 42000,
                    balanceAfter: 21000,
                    method: 'fastpay',
                    gateway: 'fastpay',
                    type: 'ad_payment',
                    adName:
                        'New Ad 2021 — Long sponsor name / ناوی سپۆنسەرێکی درێژ',
                    voucherCode: null,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            measurements.add({
              'screen': 'transaction',
              'kind': kind.name,
              'status': status,
              'screen_width': width,
              'text_scale': 1,
              'locale': 'ckb',
              'rows': auditReceiptRows(tester),
            });
            for (final id in <String>[txId]) {
              final text = tester.widget<Text>(find.text(id));
              expect(text.textDirection, TextDirection.ltr);
              expect(text.maxLines, 1);
              expect(text.softWrap, false);
            }
            final signed = status == 'approved'
                ? (kind == TxReceiptKind.topUp || kind == TxReceiptKind.refund
                    ? '+'
                    : '-')
                : '';
            final totals = find.byWidgetPredicate(
              (widget) =>
                  widget is Text &&
                  widget.data == '${signed}21,000 د.ع' &&
                  widget.style?.fontSize == 12,
            );
            expect(totals, findsOneWidget);
            final total = tester.widget<Text>(totals);
            expect(total.style!.color, const Color(0xFF111111));
            expect(total.style!.fontWeight, FontWeight.w400);
          },
        );
      }
    }
  }

  testWidgets('all field types and explicit line breaks fit without lost text',
      (tester) async {
    const fields = <String, String>{
      'ئایدی ڕیکلام': 'P123456',
      'ڕێکەوت': '2026/09/29 11:59PM',
      'ناوی سپۆنسەر': 'New Ad\n2021\r\nناوی سپۆنسەرێکی زۆر درێژ',
      'ڕێگای پارەدان': 'FastPay Merchant / FIB online payment method',
      'شوێن': 'هەولێر، سلێمانی، دهۆک، کەرکووک، بەغدا',
      'ژمارەی مامەڵەیەکی زۆر درێژ بۆ تاقیکردنەوە':
          '83062db4-47d0-4ce1-a3b4-33a766783553',
    };
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 228,
            child: ReceiptRows(fields.entries
                .map((entry) => ReceiptRow(
                      label: entry.key,
                      value: entry.value,
                      valueDirection: receiptDirOf(entry.value),
                    ))
                .toList()),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    auditReceiptRows(tester);
    expect(tester.widget<Text>(find.text('P123456')).style!.fontSize, 11);
    expect(tester.widget<Text>(find.text('ئایدی ڕیکلام')).style!.fontSize, 11);
    expect(find.text('New Ad 2021 ناوی سپۆنسەرێکی زۆر درێژ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing a discount collapses its entire row and spacing', (
    tester,
  ) async {
    final strings = AdDetailStrings.of(const Locale('ckb'));
    final data = receiptFixture();
    await tester.pumpWidget(
      receiptHost(strings: strings, data: data, scale: 1),
    );
    await tester.pumpAndSettle();
    final before = receiptPaintedRect(tester, find.byType(ReceiptCard)).height;
    final discount = find.ancestor(
      of: find.text(strings.discount),
      matching: find.byType(ReceiptRow),
    );
    final removedHeight = receiptPaintedRect(tester, discount).height +
        ReceiptTokens.rowToRow *
            tester.getSize(find.byType(ReceiptSurface)).width /
            ReceiptTokens.referenceWidth;
    data['pricing_discount_iqd_snapshot'] = 0;
    await tester.pumpWidget(
      receiptHost(strings: strings, data: data, scale: 1),
    );
    await tester.pumpAndSettle();
    expect(find.text(strings.discount), findsNothing);
    expect(
      before - receiptPaintedRect(tester, find.byType(ReceiptCard)).height,
      closeTo(removedHeight, 0.01),
    );
  });

  testWidgets('PDF export cannot start twice while already running', (
    tester,
  ) async {
    final done = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      receiptHost(
        strings: AdDetailStrings.of(const Locale('ckb')),
        data: receiptFixture(),
        scale: 1,
        onPdf: () {
          calls++;
          return done.future;
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(ReceiptPdfButton), 200,
        scrollable: find.byType(Scrollable));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ReceiptPdfButton));
    await tester.pump();
    await tester.tap(find.byType(ReceiptPdfButton));
    expect(calls, 1);
    done.complete();
    await tester.pumpAndSettle();
  });
  testWidgets('100% discount shows zero and no invented payment', (
    tester,
  ) async {
    final strings = AdDetailStrings.of(const Locale('ckb'));
    await tester.pumpWidget(
      receiptHost(strings: strings, data: freeReceiptFixture(), scale: 1),
    );
    await tester.pumpAndSettle();
    expect(find.text('36,000 د.ع'), findsOneWidget);
    expect(find.text('-36,000 د.ع'), findsOneWidget);
    expect(find.text('0 د.ع'), findsOneWidget);
    expect(find.text('پارەدان پێویست نەبوو'), findsOneWidget);
    expect(find.text('FastPay'), findsNothing);
    expect(find.text(strings.transactionId), findsNothing);
    expect(tester.takeException(), isNull);
  });
  const capturePath = String.fromEnvironment('RECEIPT_CAPTURE');
  if (capturePath.isNotEmpty) {
    testWidgets('capture actual Flutter receipt', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      final strings = AdDetailStrings.of(const Locale('ckb'));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: RepaintBoundary(
                key: key,
                child: ReceiptSurface(
                  child: AdReceiptCard(
                    r: AdReceiptData.from(freeReceiptFixture(), strings),
                    l: strings,
                    onCopy: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final image = await (key.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 2.75);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(capturePath).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}
