import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/l10n/ad_detail_strings.dart';
import 'package:proxo_app/models/ad_receipt_data.dart';
import 'package:proxo_app/models/receipt_pricing.dart';
import 'package:proxo_app/widgets/receipt/receipt_kit.dart';

Map<String, dynamic> receiptFixture() => <String, dynamic>{
      'id': '720079a8-9cf7-44de-b3af-f396d1aaf7d8',
      'public_ad_id': 'PFCHDUCSYAKO',
      'title': 'Summer Campaign',
      'created_at': '2026-09-18T23:45:00Z',
      'age_groups': <String>['18-24', '25-34'],
      'gender': 'all',
      'location': 'kurdistan',
      'device_type': 'iphone',
      'category': 'cosmetics_beauty',
      'payment_method': 'fastpay',
      'payment_status': 'paid',
      'payment_transaction_id': '83062db4-47d0-4ce1-a3b4-33a766783553',
      'pricing_ad_budget_iqd_snapshot': 16800,
      'pricing_service_fee_iqd_snapshot': 4200,
      'pricing_payment_method_snapshot': 'fastpay',
      'pricing_snapshot_at': '2026-09-18T23:45:00Z',
      'total_budget': 15,
      'charged_price_iqd': 21000,
      'pricing_total_iqd_snapshot': 19650,
      'pricing_discount_iqd_snapshot': 1350,
      'thumbnail_url': 'https://example.com/thumbnail.png',
    };

Map<String, dynamic> freeReceiptFixture() => receiptFixture()
  ..['pricing_ad_budget_iqd_snapshot'] = 28800
  ..['pricing_service_fee_iqd_snapshot'] = 7200
  ..['pricing_discount_iqd_snapshot'] = 36000
  ..['pricing_total_iqd_snapshot'] = 0
  ..['charged_price_iqd'] = 0
  ..['payment_transaction_id'] = null
  ..['payment_method'] = 'app_balance'
  ..['pricing_payment_method_snapshot'] = 'app_balance';

void main() {
  final ku = AdDetailStrings.of(const Locale('ckb'));
  final ar = AdDetailStrings.of(const Locale('ar'));

  test(
      'keeps public P Ad ID distinct from receipt UUID and payment transaction',
      () {
    final data = receiptFixture()
      ..['receipt_uid'] = 'wrong-receipt'
      ..['payment_transaction_id'] = 'wrong-payment'
      ..['ad_number'] = 'wrong-short-code';
    final receipt = AdReceiptData.from(data, ku);
    expect(receipt.uid, data['id']);
    expect(receipt.adId, data['public_ad_id']);
    expect(receipt.adId.startsWith('P'), isTrue);
    expect(receipt.adId, isNot(receipt.uid));
    expect(receipt.date, '19/09/2026 02:45AM');
    expect(receipt.age, '18–34');
  });

  test('does not recalculate stored prices from a conflicting daily rate', () {
    final data = receiptFixture()
      ..['daily_budget'] = 999
      ..['days'] = 20
      ..['usd_iqd_rate'] = 99999
      ..['charged_usd_iqd_rate'] = 88888;
    final receipt = AdReceiptData.from(data, ku);
    expect(receipt.originalIqd, '21,000 د.ع');
    expect(receipt.totalIqd, '19,650 د.ع');
    expect(receipt.discountIqd, '-1,350 د.ع');
  });

  test('zero snapshot hides discount even if old columns have a discount', () {
    final data = receiptFixture()
      ..['pricing_discount_iqd_snapshot'] = 0
      ..['level_discount_iqd'] = 500;
    expect(AdReceiptData.from(data, ku).discountIqd, isNull);
  });

  test('legacy fallback uses only saved discount components', () {
    final data = receiptFixture()
      ..remove('pricing_discount_iqd_snapshot')
      ..['global_discount_iqd'] = 250
      ..['direct_discount_iqd'] = 100
      ..['level_discount_iqd'] = 500;
    expect(AdReceiptData.from(data, ku).discountIqd, '-850 د.ع');
    data['global_discount_iqd'] = 0;
    data['direct_discount_iqd'] = 0;
    data['level_discount_iqd'] = 0;
    expect(AdReceiptData.from(data, ku).discountIqd, isNull);
  });

  test('keeps a real zero payment and does not invent missing prices', () {
    final data = receiptFixture()
      ..['total_budget'] = 0
      ..['charged_price_iqd'] = 0
      ..['pricing_total_iqd_snapshot'] = 0;
    var receipt = AdReceiptData.from(data, ku);
    expect(receipt.totalIqd, '0 د.ع');
    data.remove('total_budget');
    data.remove('charged_price_iqd');
    data.remove('pricing_total_iqd_snapshot');
    receipt = AdReceiptData.from(data, ku);
    expect(receipt.totalIqd, isNull);
  });

  test('Arabic target labels and missing values do not become Kurdish/all', () {
    final data = receiptFixture();
    final receipt = AdReceiptData.from(data, ar);
    expect(receipt.gender, 'كلاهما');
    expect(receipt.location, 'كردستان');
    expect(receipt.category, 'التجميل والعناية');
    expect(ku.locationLabel('Erbil'), 'هەولێر');
    expect(ar.locationLabel('Erbil'), 'أربيل');
    expect(ar.locationLabel('Custom City'), 'Custom City');
    expect(ar.deviceLabel('Desktop'), 'Desktop');
    expect(ar.genderLabel(''), '—');
    expect(ar.categoryLabel(''), '—');
    data['age_groups'] = <String>['unknown'];
    expect(AdReceiptData.from(data, ar).age, 'unknown');
    data['age_groups'] = <String>[];
    expect(AdReceiptData.from(data, ar).age, '—');
  });

  test('age unions preserve gaps and merge duplicate/overlapping ranges', () {
    final data = receiptFixture()
      ..['age_groups'] = <String>['25-34', '18-24', '18-24', '45-54', '55+'];
    expect(AdReceiptData.from(data, ku).age, '18–34, 45+');
    data['age_groups'] = <String>['55+', '65+'];
    expect(AdReceiptData.from(data, ku).age, '55+');
  });

  test('missing UID is rejected, and display preserves raw UID without breaks',
      () {
    final data = receiptFixture()..remove('id');
    expect(() => AdReceiptData.from(data, ku), throwsFormatException);
    const uid = '720079a8-9cf7-44de-b3af-f396d1aaf7d8';
    expect(receiptBreakableUid(uid), uid);
    expect(receiptNum('NaN'), isNull);
    expect(receiptNum('Infinity'), isNull);
  });
  test(
    'real 100% discount preserves zero and hides zero-value ledger information',
    () {
      final data = freeReceiptFixture()
        ..['receipt_transaction_id'] = 'zero-ledger-id';
      final r = AdReceiptData.from(data, ku);
      expect(r.originalIqd, '36,000 د.ع');
      expect(r.discountIqd, '-36,000 د.ع');
      expect(r.totalIqd, '0 د.ع');
      expect(r.payment, 'پارەدان پێویست نەبوو');
      expect(r.transactionId, isNull);
      expect(r.noPaymentRequired, isTrue);
    },
  );
  test('normal paid ad without discount retains actual transaction', () {
    final data = receiptFixture()
      ..['pricing_discount_iqd_snapshot'] = 0
      ..['pricing_total_iqd_snapshot'] = 21000;
    final r = AdReceiptData.from(data, ku);
    expect(r.originalIqd, '21,000 د.ع');
    expect(r.discountIqd, isNull);
    expect(r.totalIqd, '21,000 د.ع');
    expect(r.transactionId, data['payment_transaction_id']);
    expect(r.payment, 'FastPay');
  });
  for (final key in [
    'global_discount_iqd',
    'direct_discount_iqd',
    'level_discount_iqd',
  ]) {
    test('legacy stored $key does not consult current percentage', () {
      final pricing = ReceiptPricing.from({
        'charged_price_iqd': 15000,
        key: 10000,
        'level_discount_percent': 99,
        'promo_code': 'NOW_DIFFERENT',
        'price_iqd': 99999,
      });
      expect(pricing.originalIqd, 25000);
      expect(pricing.discountIqd, 10000);
      expect(pricing.totalIqd, 15000);
    });
  }
  test(
    'missing legacy amounts are not invented from gross price or current rates',
    () {
      final pricing = ReceiptPricing.from({
        'price_iqd': 25000,
        'usd_iqd_rate': 1800,
      });
      expect(pricing.totalIqd, isNull);
      expect(pricing.originalIqd, isNull);
      expect(pricing.discountIqd, isNull);
    },
  );
  test('null and invalid optional data never appears as object or NaN', () {
    for (final value in [
      null,
      double.nan,
      double.infinity,
      {},
      'undefined',
      'null',
      'Instance of Test',
    ]) {
      expect(receiptText(value), '');
      expect(storedMoney(value), isNull);
    }
    expect(receiptText(0), '0');
    expect(storedMoney('0'), 0);
  });
  test(
    'transaction projection honors saved currency including small IQD and zero',
    () {
      expect(storedTransactionIqd({'amount': 100, 'currency': 'IQD'}), 100);
      expect(storedTransactionIqd({'amount': 0, 'currency': 'IQD'}), 0);
      expect(
        storedTransactionIqd({
          'amount': 10,
          'currency': 'USD',
          'fx_rate': 1400,
        }),
        14000,
      );
      expect(storedTransactionIqd({'amount': 10, 'currency': 'USD'}), isNull);
      expect(storedTransactionIqd({'amount': 10}), isNull);
    },
  );
  test('optional missing transaction is safely hidden on a paid receipt', () {
    final data = receiptFixture()..remove('payment_transaction_id');
    expect(AdReceiptData.from(data, ku).transactionId, isNull);
  });
  test(
      'missing or invalid public Ad ID never becomes UUID or a manufactured P code',
      () {
    for (final value in [
      null,
      '',
      '123456',
      '720079a8-9cf7-44de-b3af-f396d1aaf7d8'
    ]) {
      final data = receiptFixture()..['public_ad_id'] = value;
      final receipt = AdReceiptData.from(data, ku);
      expect(receipt.adId, '—');
      expect(receipt.uid, data['id']);
    }
  });
}
