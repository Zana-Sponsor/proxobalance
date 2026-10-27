import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/main.dart' as app;
import 'package:proxo_app/screens/ad_detail_screen.dart';
import 'package:proxo_app/screens/transaction_detail_screen.dart';
import 'package:proxo_app/theme/app_locale.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/widgets/proxo_sidebar.dart';
import 'package:proxo_app/widgets/receipt/tx_history_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_repository_test.dart'
    show jsonResponse, mockTransport, signedClient, userId;

void main() {
  testWidgets(
      'partial ad refund keeps one debit and opens separate financial receipts',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    ProxoLocale.current.value = ProxoLocale.kurdishSorani;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final requested = <String>[];
    final transport = mockTransport((request) async {
      requested.add(request.url.path);
      expect(request.url.host, 'test.invalid');
      expect(request.method, 'GET');
      expect(request.url.queryParameters['user_id'], 'eq.$userId');
      return switch (request.url.path) {
        '/rest/v1/pa_transactions' => jsonResponse([
            {
              'id': 'unused-budget-credit',
              'user_id': userId,
              'public_transaction_id': 'TX-REFUND',
              'type': 'ad_unspent_refund',
              'kind': 'ad_unspent_refund',
              'status': 'approved',
              'amount': 5,
              'currency': 'USD',
              'fx_rate': 1400,
              'method': 'app_balance',
              'ad_id': 'linked-ad',
              'ad_number': 742,
              'ad_title': 'Fixture campaign',
              'original_transaction_id': 'original-ad-debit',
              'created_at': '2026-10-23T10:00:00Z',
              'balance_currency': 'USD',
              'balance_before': 85,
              'balance_after': 90,
            },
            {
              'id': 'original-ad-debit',
              'user_id': userId,
              'public_transaction_id': 'TX-ORIGINAL',
              'type': 'ad_payment',
              'kind': 'ad_payment',
              'status': 'partially_refunded',
              'amount': 15,
              'currency': 'USD',
              'fx_rate': 1400,
              'method': 'app_balance',
              'ad_id': 'linked-ad',
              'ad_number': 742,
              'ad_title': 'Fixture campaign',
              'created_at': '2026-10-22T10:00:00Z',
              'balance_currency': 'USD',
              'balance_before': 100,
              'balance_after': 85,
            },
          ]),
        '/rest/v1/pa_ads' => jsonResponse([
            {
              'id': 'linked-ad',
              'title': 'Fixture campaign',
              'budget': 15,
              'ad_number': 742,
              'payment_status': 'partially_refunded',
              'created_at': '2026-10-22T10:00:00Z',
            }
          ]),
        '/rest/v1/pa_coin_transactions' => jsonResponse([]),
        _ => throw StateError('Unexpected mocked request: ${request.url}'),
      };
    });
    final client = (await tester.runAsync(() => signedClient(transport)))!;
    app.supabase = client;
    addTearDown(() async => tester.runAsync(client.dispose));

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      home: const TxHistoryPage(),
    ));
    await tester.pumpAndSettle();

    // The matching pa_ads row must not introduce a legacy fallback debit.
    expect(find.byType(TxHistoryCard), findsNWidgets(2));
    final cards = tester.widgetList<TxHistoryCard>(find.byType(TxHistoryCard));
    final credit = cards.singleWhere((card) => card.amount.startsWith('+'));
    final debit = cards.singleWhere((card) => card.amount.startsWith('-'));
    expect(credit.label, 'گەڕانەوەی پارە — ڕیکلام #742');
    expect(credit.amount, '+7,000 د.ع');
    expect(credit.amountColor, TxHistoryTokens.positive);
    expect(debit.label, 'ڕیکلام #742');
    expect(debit.amount, '-21,000 د.ع');
    expect(debit.amountColor, TxHistoryTokens.negative);
    expect(debit.status, 'بەشێکی گەڕاوەتەوە');
    expect(find.text('زیادکردنی باڵانس لەلایەن ئادمینەوە'), findsNothing);

    await tester.tap(find.byWidget(credit));
    await tester.pumpAndSettle();
    var receipt = tester
        .widget<TransactionDetailScreen>(find.byType(TransactionDetailScreen));
    expect(receipt.data.kind, TxReceiptKind.refund);
    expect(receipt.data.uid, 'unused-budget-credit');
    expect(receipt.data.txId, 'TX-REFUND');
    expect(receipt.data.status, 'approved');
    expect(receipt.data.amountIqd, 7000);
    expect(receipt.data.usd, 5);
    expect(receipt.data.balanceBeforeUsd, 85);
    expect(receipt.data.balanceAfterUsd, 90);
    expect(receipt.data.isSettled, isTrue);
    expect(find.byType(AdDetailScreen), findsNothing);

    Navigator.of(tester.element(find.byType(TransactionDetailScreen))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byWidget(debit));
    await tester.pumpAndSettle();
    receipt = tester
        .widget<TransactionDetailScreen>(find.byType(TransactionDetailScreen));
    expect(receipt.data.kind, TxReceiptKind.adPayment);
    expect(receipt.data.uid, 'original-ad-debit');
    expect(receipt.data.txId, 'TX-ORIGINAL');
    expect(receipt.data.status, 'partially_refunded');
    expect(receipt.data.amountIqd, 21000);
    expect(receipt.data.usd, 15);
    expect(receipt.data.balanceBeforeUsd, 100);
    expect(receipt.data.balanceAfterUsd, 85);
    expect(receipt.data.isSettled, isTrue);
    expect(find.byType(AdDetailScreen), findsNothing);
    // Both routes use the captured financial row without a second data fetch.
    expect(
        requested,
        unorderedEquals([
          '/rest/v1/pa_transactions',
          '/rest/v1/pa_ads',
          '/rest/v1/pa_coin_transactions',
        ]));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
