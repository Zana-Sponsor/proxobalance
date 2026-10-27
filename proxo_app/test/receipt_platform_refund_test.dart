import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/l10n/ad_detail_strings.dart';
import 'package:proxo_app/models/ad_receipt_data.dart';
import 'package:proxo_app/screens/transaction_detail_screen.dart';
import 'package:proxo_app/theme/app_locale.dart';
import 'package:proxo_app/widgets/receipt/ad_receipt_card.dart';
import 'package:proxo_app/widgets/receipt/receipt_kit.dart';

import 'ad_receipt_data_test.dart' show receiptFixture;

void main() {
  setUpAll(() async {
    await (FontLoader(ReceiptTokens.fontFamily)
          ..addFont(rootBundle.load(ReceiptTokens.fontAsset)))
        .load();
  });
  setUp(() => ProxoLocale.current.value = const Locale('ckb'));

  testWidgets('Meta placements retain every pixel of the approved receipt',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final key = GlobalKey();
    final strings = AdDetailStrings.current;
    Future<Uint8List> render(Map<String, dynamic> data) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: ReceiptBody(
        children: [
          RepaintBoundary(
              key: key,
              child: ReceiptSurface(
                child: AdReceiptCard(
                    r: AdReceiptData.from(data, strings),
                    l: strings,
                    onCopy: (_) {}),
              ))
        ],
      ))));
      await tester.pumpAndSettle();
      await tester.runAsync(() => precacheImage(
            const AssetImage(ReceiptTokens.logoAsset),
            tester.element(find.byType(ReceiptHeader)),
          ));
      await tester.pumpAndSettle();
      return (await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        try {
          return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
              .buffer
              .asUint8List();
        } finally {
          image.dispose();
        }
      }))!;
    }

    final approved = await render(receiptFixture()..['platform'] = 'TIKTOK');
    for (final placements in [
      ['facebook'],
      ['instagram'],
      ['facebook', 'instagram']
    ]) {
      final meta = receiptFixture()
        ..['platform'] = 'META'
        ..['receipt_uid'] = receiptFixture()['payment_transaction_id']
        ..['meta_configuration'] = {'placements': placements};
      expect(await render(meta), orderedEquals(approved));
      expect(find.byType(ReceiptHeader), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    // This approved renderer has only the Proxo brand. There is no existing
    // platform-logo slot to change; this test protects against inventing one.
    final direct = receiptFixture()
      ..['platform'] = 'TIKTOK'
      ..['fulfillment_kind'] = 'tiktok_conversation_auto'
      ..['receipt_uid'] = receiptFixture()['payment_transaction_id'];
    expect(await render(direct), orderedEquals(approved));
  });

  test('Meta advertisement links its debit, separately from FastPay funding',
      () {
    final data = receiptFixture()
      ..['platform'] = 'META'
      ..['payment_transaction_id'] = 'funding-credit-id'
      ..['receipt_uid'] = 'captured-debit-id';
    expect(AdReceiptData.from(data, AdDetailStrings.current).transactionId,
        'captured-debit-id');
    data.remove('receipt_uid');
    expect(AdReceiptData.from(data, AdDetailStrings.current).transactionId,
        isNull);
    data['receipt_transaction_id'] = 'verified-linked-debit';
    expect(AdReceiptData.from(data, AdDetailStrings.current).transactionId,
        'verified-linked-debit');
  });

  test('automatic TikTok receipt links its captured debit after partial refund',
      () {
    final data = receiptFixture()
      ..['platform'] = 'TIKTOK'
      ..['fulfillment_kind'] = 'tiktok_conversation_auto'
      ..['payment_status'] = 'partially_refunded'
      ..['payment_transaction_id'] = 'funding-credit-id'
      ..['receipt_uid'] = 'captured-debit-id';
    expect(AdReceiptData.from(data, AdDetailStrings.current).transactionId,
        'captured-debit-id');
  });

  for (final entry in {
    'refund_pending': 'چاوەڕێی گەڕاندنەوە',
    'refunded': 'گەڕاوە',
    'partially_refunded': 'بەشێکی گەڕاوەتەوە',
  }.entries) {
    testWidgets('original debit ${entry.key} keeps its amount and identity',
        (tester) async {
      final data = TxReceiptData(
          kind: TxReceiptKind.adPayment,
          status: entry.key,
          txId: 'T-ORIGINAL',
          uid: 'original-debit-id',
          date: DateTime.utc(2026, 10, 23),
          usd: 15,
          amountIqd: 21000,
          balanceBefore: 42000,
          balanceAfter: 21000,
          method: 'app_balance',
          gateway: '',
          type: 'ad_payment',
          adName: 'Meta ad',
          voucherCode: null);
      expect(data.isSettled, isTrue);
      await tester
          .pumpWidget(MaterialApp(home: TransactionDetailScreen(data: data)));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      expect(find.text('T-ORIGINAL'), findsOneWidget);
      expect(find.text('original-debit-id'), findsOneWidget);
      expect(find.text('-21,000 د.ع'), findsOneWidget);
      expect(find.text('+21,000 د.ع'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
