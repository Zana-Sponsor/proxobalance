import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/l10n/ad_detail_strings.dart';
import 'package:proxo_app/screens/ad_detail_screen.dart';
import 'package:proxo_app/theme/app_locale.dart';
import 'package:proxo_app/widgets/receipt/receipt_kit.dart';

import 'ad_receipt_data_test.dart' show receiptFixture;

void main() {
  setUp(() => ProxoLocale.current.value = const Locale('ckb'));

  testWidgets('a deleted ad clears the cached receipt and PDF action', (
    tester,
  ) async {
    final response = Completer<Map<String, dynamic>?>();
    final data = receiptFixture();
    await tester.pumpWidget(
      MaterialApp(
        home: AdDetailScreen(
          adId: data['id'] as String,
          initialAd: data,
          loadAd: (_) => response.future,
        ),
      ),
    );
    expect(find.text('720079a8-9cf7-44de-b3af-f396d1aaf7d8'), findsOneWidget);
    response.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('720079a8-9cf7-44de-b3af-f396d1aaf7d8'), findsNothing);
    expect(find.text(AdDetailStrings.current.notFoundTitle), findsOneWidget);
    expect(find.text(AdDetailStrings.current.pdfButton), findsNothing);
  });

  testWidgets('an unrelated cached ad is never displayed', (tester) async {
    final response = Completer<Map<String, dynamic>?>();
    final data = receiptFixture();
    await tester.pumpWidget(
      MaterialApp(
        home: AdDetailScreen(
          adId: 'a2ae89e7-163c-4f0d-acaa-3782185e74d9',
          initialAd: data,
          loadAd: (_) => response.future,
        ),
      ),
    );
    expect(find.text('720079a8-9cf7-44de-b3af-f396d1aaf7d8'), findsNothing);
    expect(find.byType(ReceiptSpinner), findsOneWidget);
    response.complete(null);
    await tester.pumpAndSettle();
  });

  testWidgets('switching Sorani to Arabic updates the open receipt', (
    tester,
  ) async {
    final data = receiptFixture();
    await tester.pumpWidget(
      MaterialApp(
        home: AdDetailScreen(
          adId: data['id'] as String,
          loadAd: (_) async => data,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('وردەکاری ڕیکلام'), findsOneWidget);
    ProxoLocale.current.value = const Locale('ar');
    await tester.pumpAndSettle();
    expect(find.text('تفاصيل الإعلان'), findsOneWidget);
    expect(find.text('وردەکاری ڕیکلام'), findsNothing);
    expect(find.text('استهداف الإعلان'), findsOneWidget);
    expect(find.text('كلاهما'), findsOneWidget);
  });

  testWidgets('a late response cannot overwrite another ad', (tester) async {
    final first = Completer<Map<String, dynamic>?>();
    final second = Completer<Map<String, dynamic>?>();
    final data = receiptFixture();
    final other = receiptFixture()
      ..['id'] = 'a2ae89e7-163c-4f0d-acaa-3782185e74d9'
      ..['public_ad_id'] = 'PSECONDAD';
    Future<Map<String, dynamic>?> load(String id) =>
        id == data['id'] ? first.future : second.future;
    Widget host(String id) => MaterialApp(
          home: AdDetailScreen(adId: id, loadAd: load),
        );
    await tester.pumpWidget(host(data['id'] as String));
    await tester.pumpWidget(host(other['id'] as String));
    second.complete(other);
    await tester.pumpAndSettle();
    first.complete(data);
    await tester.pumpAndSettle();
    expect(find.text('a2ae89e7-163c-4f0d-acaa-3782185e74d9'), findsOneWidget);
    expect(find.text('720079a8-9cf7-44de-b3af-f396d1aaf7d8'), findsNothing);
  });
}
