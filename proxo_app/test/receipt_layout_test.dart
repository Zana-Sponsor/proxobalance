import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/l10n/ad_detail_strings.dart';
import 'package:proxo_app/l10n/tx_strings.dart';
import 'package:proxo_app/models/ad_receipt_data.dart';
import 'package:proxo_app/screens/transaction_detail_screen.dart';
import 'package:proxo_app/theme/proxo_ui.dart';
import 'package:proxo_app/widgets/receipt/ad_receipt_card.dart';
import 'package:proxo_app/widgets/receipt/receipt_kit.dart';

import 'ad_receipt_data_test.dart' show receiptFixture, freeReceiptFixture;
import 'receipt_test_helpers.dart';
import 'support/visual_capture.dart';

Widget receiptHost(
        {required AdDetailStrings strings,
        required Map<String, dynamic> data,
        double scale = 1,
        EdgeInsets padding = EdgeInsets.zero,
        Future<void> Function()? onPdf}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildProxoTheme(),
      home: Builder(
          builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    padding: padding,
                    viewPadding: padding),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Scaffold(
                      backgroundColor: ReceiptTokens.page,
                      body: Column(children: [
                        ReceiptAppBar(
                            title: strings.appBarTitle, onBack: () {}),
                        Expanded(
                            child: SafeArea(
                                top: false,
                                bottom: false,
                                child: ReceiptBody(children: [
                                  ReceiptSurface(
                                      child: AdReceiptCard(
                                          r: AdReceiptData.from(data, strings),
                                          l: strings,
                                          onCopy: (_) {})),
                                  ReceiptWidth(
                                      child: ReceiptPdfButton(
                                          label: strings.pdfButton,
                                          onPressed: onPdf ?? () async {})),
                                ]))),
                      ])),
                ),
              )),
    );

void main() {
  ProxoVisualBinding();
  setUpAll(loadVisualFonts);

  for (final width in <double>[280, 320, 393, 430, 640]) {
    for (final scale in <double>[1, 1.3, 2]) {
      for (final language in ['ckb', 'ar']) {
        testWidgets('readable RTL receipt at $width dp / $scale / $language',
            (tester) async {
          setVisualViewport(tester, Size(width, 900));
          final strings = AdDetailStrings.of(Locale(language));
          final data = receiptFixture()
            ..['id'] = '720079a8-9cf7-44de-b3af-f396d1aaf7d8'
            ..['title'] = 'Summer Campaign — ڕیکلامێکی زۆر درێژ بۆ تاقیکردنەوە';
          await tester.pumpWidget(
              receiptHost(strings: strings, data: data, scale: scale));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          auditReceiptRows(tester);
          final card = receiptPaintedRect(tester, find.byType(ReceiptCard));
          expect(card.width, lessThanOrEqualTo(width - 32));
          expect(card.left, greaterThanOrEqualTo(16));
          expect(find.text(data['id'] as String), findsOneWidget);
          expect(find.text(strings.paymentStatus), findsOneWidget);
          expect(tester.getCenter(find.text(strings.appBarTitle)).dx,
              closeTo(width / 2, .1));
          await tester.scrollUntilVisible(find.byType(ReceiptPdfButton), 200,
              scrollable: find.byType(Scrollable));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(tester.getSize(find.byType(ReceiptPdfButton)).height,
              greaterThanOrEqualTo(48));
        });
      }
    }
  }

  testWidgets('long reference wraps at readable size and copy retains original',
      (tester) async {
    const reference =
        '83062db4-47d0-4ce1-a3b4-33a766783553-extra-reference-123456789';
    String? copied;
    await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
            body: Center(
                child: SizedBox(
                    width: 228,
                    child: ReceiptCard(
                        child: ReceiptIdentifierRow(
                            label: 'ژمارەی مامەڵە',
                            value: reference,
                            onLongPress: () => copied = reference)))))));
    await tester.pumpAndSettle();
    auditReceiptRows(tester);
    expect(tester.getSize(find.byType(ReceiptRow)).height, greaterThan(40));
    expect(tester.widget<Text>(find.text(reference)).style!.fontSize,
        ReceiptTokens.valueSize);
    await tester.longPress(find.text('ژمارەی مامەڵە'));
    expect(copied, reference);
  });

  for (final kind in TxReceiptKind.values) {
    for (final status in ['approved', 'pending', 'rejected']) {
      testWidgets('transaction $kind $status preserves money and status',
          (tester) async {
        setVisualViewport(tester, const Size(320, 780));
        await tester.pumpWidget(MaterialApp(
            debugShowCheckedModeBanner: false,
            home: TransactionDetailScreen(
                data: TxReceiptData(
                    kind: kind,
                    status: status,
                    txId: 'TX-83062db4-47d0-4ce1-a3b4-33a766783553',
                    uid: 'DEMO-RECEIPT',
                    date: DateTime.utc(2026, 10, 20),
                    usd: 15,
                    amountIqd: 21000,
                    balanceBefore: 42000,
                    balanceAfter: 21000,
                    method: 'FastPay Merchant',
                    gateway: 'fastpay',
                    type: 'ad_payment',
                    adName: 'ناوی ڕیکلامێکی درێژ / Proxo campaign',
                    voucherCode: null))));
        await tester.pumpAndSettle();
        auditReceiptRows(tester);
        final l = TxStrings.current;
        expect(
            find.text(status == 'approved'
                ? l.statusApproved
                : status == 'rejected'
                    ? l.statusRejected
                    : l.statusPending),
            findsOneWidget);
        final sign = status == 'approved'
            ? (kind == TxReceiptKind.topUp || kind == TxReceiptKind.refund
                ? '+'
                : '-')
            : '';
        expect(
            find.byWidgetPredicate((w) =>
                w is Text &&
                w.data == '${sign}21,000 د.ع' &&
                w.style?.fontSize == ReceiptTokens.totalSize),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('removing discount collapses row without blank gap',
      (tester) async {
    final strings = AdDetailStrings.current;
    final data = receiptFixture();
    await tester.pumpWidget(receiptHost(strings: strings, data: data));
    await tester.pumpAndSettle();
    final before = receiptPaintedRect(tester, find.byType(ReceiptCard)).height;
    final discount = find.ancestor(
        of: find.text(strings.discount), matching: find.byType(ReceiptRow));
    final removed =
        receiptPaintedRect(tester, discount).height + ReceiptTokens.rowToRow;
    data['pricing_discount_iqd_snapshot'] = 0;
    await tester.pumpWidget(receiptHost(strings: strings, data: data));
    await tester.pumpAndSettle();
    expect(find.text(strings.discount), findsNothing);
    expect(before - receiptPaintedRect(tester, find.byType(ReceiptCard)).height,
        closeTo(removed, .1));
  });

  testWidgets('PDF repeated tap starts one export', (tester) async {
    final done = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(receiptHost(
        strings: AdDetailStrings.current,
        data: receiptFixture(),
        onPdf: () {
          calls++;
          return done.future;
        }));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byType(ReceiptPdfButton), 200,
        scrollable: find.byType(Scrollable));
    await tester.tap(find.byType(ReceiptPdfButton));
    await tester.pump();
    await tester.tap(find.byType(ReceiptPdfButton));
    expect(calls, 1);
    done.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('free receipt retains zero amount without invented payment',
      (tester) async {
    final strings = AdDetailStrings.current;
    await tester
        .pumpWidget(receiptHost(strings: strings, data: freeReceiptFixture()));
    await tester.pumpAndSettle();
    expect(find.text('0 د.ع'), findsOneWidget);
    expect(find.text(strings.noPaymentRequired), findsNWidgets(2));
    expect(find.text('FastPay'), findsNothing);
    expect(find.text(strings.transactionId), findsNothing);
  });

  for (final size in [
    const Size(320, 780),
    const Size(393, 852),
    const Size(430, 932)
  ]) {
    testWidgets('capture receipt states at ${size.width}', (tester) async {
      setVisualViewport(tester, size);
      final label = '${size.width.toInt()}x${size.height.toInt()}';
      await tester.pumpWidget(visualCapture(receiptHost(
          strings: AdDetailStrings.current, data: receiptFixture())));
      await tester.pumpAndSettle();
      await captureVisual(tester, 'advertisement-receipt-top-$label');
      await tester.scrollUntilVisible(find.byType(ReceiptPdfButton), 200,
          scrollable: find.byType(Scrollable));
      await tester.pumpAndSettle();
      await captureVisual(tester, 'advertisement-receipt-bottom-$label');
      await tester.pumpWidget(visualCapture(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildProxoTheme(),
          home: TransactionDetailScreen(
              data: TxReceiptData(
                  kind: TxReceiptKind.topUp,
                  status: 'approved',
                  txId: 'DEMO-TX-20261020-001',
                  uid: 'DEMO-RECEIPT-001',
                  date: DateTime.utc(2026, 10, 20, 8),
                  usd: 25,
                  amountIqd: 35000,
                  balanceBefore: 15000,
                  balanceAfter: 50000,
                  method: 'fib',
                  gateway: '',
                  type: 'deposit',
                  adName: null,
                  voucherCode: null)))));
      await tester.pumpAndSettle();
      await captureVisual(tester, 'payment-receipt-top-$label');
      await tester.scrollUntilVisible(find.byType(ReceiptPdfButton), 200,
          scrollable: find.byType(Scrollable));
      await tester.pumpAndSettle();
      await captureVisual(tester, 'payment-receipt-bottom-$label');
    });
  }
}
