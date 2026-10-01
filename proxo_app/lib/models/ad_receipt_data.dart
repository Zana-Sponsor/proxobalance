import 'package:flutter/widgets.dart';

import '../l10n/ad_detail_strings.dart';
import 'receipt_pricing.dart';
import '../widgets/receipt/receipt_kit.dart';

String _str(dynamic v) => receiptText(v);

// ── تەمەن ────────────────────────────────────────────────────────────────────

/// `age_groups` jsonbـە، بەڵام هەندێک ڕیزی کۆن String یان پاشماوەی
/// JSONـی شکاو («[») تێدایە — هەمووی لێرە پاک دەکرێتەوە.
List<String> _ageList(dynamic raw) {
  if (raw == null) return const <String>[];
  final Iterable<String> items = raw is List
      ? raw.map((dynamic e) => receiptText(e))
      : receiptText(raw).split(',');
  return items
      .map((String e) => e.replaceAll(RegExp(r'[\[\]"]'), '').trim())
      .where((String e) => e.isNotEmpty)
      .toList();
}

/// کۆمەڵە تەمەنە یەک لە دوای یەکەکان دەکاتە مەودایەک:
/// [18-24, 25-34] → «18–34»، [45-54, 55+] → «45+».
String? _ageRange(List<String> groups) {
  final List<List<int?>> parsed = <List<int?>>[];
  for (final String g in groups) {
    final String normalized =
        g.replaceAll(RegExp(r'\s'), '').replaceAll(RegExp('[–—]'), '-');
    final Match? plus = RegExp(r'^(\d+)\+$').firstMatch(normalized);
    final Match? span = RegExp(r'^(\d+)-(\d+)$').firstMatch(normalized);
    if (plus != null) {
      parsed.add(<int?>[int.parse(plus[1]!), null]);
    } else if (span != null) {
      final int start = int.parse(span[1]!);
      final int end = int.parse(span[2]!);
      if (end < start) return null;
      parsed.add(<int?>[start, end]);
    } else {
      // Preserve unfamiliar legacy values rather than falsely saying all ages.
      return null;
    }
  }
  if (parsed.isEmpty) return null;
  parsed.sort((List<int?> a, List<int?> b) => a[0]!.compareTo(b[0]!));

  final List<String> out = <String>[];
  int start = parsed.first[0]!;
  int? end = parsed.first[1];
  for (int i = 1; i < parsed.length; i++) {
    final List<int?> g = parsed[i];
    if (end == null) {
      continue;
    } else if (g[0]! <= end + 1) {
      if (g[1] == null || g[1]! > end) end = g[1];
    } else {
      out.add('$start–$end');
      start = g[0]!;
      end = g[1];
    }
  }
  out.add(end == null ? '$start+' : '$start–$end');
  return out.join(', ');
}

// ═════════════════════════════════════════════════════════════════════════════
// مۆدێلی پسوولە — یەک جار لە هەر بارکردنێکدا دروست دەکرێت
// ═════════════════════════════════════════════════════════════════════════════

class AdReceiptData {
  final String adId;
  final String date;
  final String age;
  final TextDirection ageDir;
  final String gender;
  final String location;
  final String device;
  final TextDirection deviceDir;
  final String category;
  final String? originalIqd;
  final String? transactionId;
  final bool noPaymentRequired;
  final String? discountIqd; // null = هیچ ڕیزێک پیشان نادرێت
  final String? totalIqd;
  final String payment;
  final TextDirection paymentDir;
  final String adName;
  final TextDirection adNameDir;
  final String uid;

  const AdReceiptData({
    required this.adId,
    required this.date,
    required this.age,
    required this.ageDir,
    required this.gender,
    required this.location,
    required this.device,
    required this.deviceDir,
    required this.category,
    required this.originalIqd,
    required this.transactionId,
    required this.noPaymentRequired,
    required this.discountIqd,
    required this.totalIqd,
    required this.payment,
    required this.paymentDir,
    required this.adName,
    required this.adNameDir,
    required this.uid,
  });

  factory AdReceiptData.from(Map<String, dynamic> ad, AdDetailStrings l) {
    // ── ناسنامە ──────────────────────────────────────────────────────────
    final String uid = _str(ad['id']);
    if (uid.isEmpty) {
      throw const FormatException('An ad receipt requires pa_ads.id.');
    }
    // Public P-prefixed ad identifier and internal receipt UUID are distinct.
    // Never manufacture a P-prefix or substitute a payment transaction ID.
    final String publicAdId = _str(ad['public_ad_id']);
    final String adId = publicAdId.startsWith('P') ? publicAdId : '—';

    // ── ئامانج ───────────────────────────────────────────────────────────
    final List<String> ages = _ageList(ad['age_groups'] ?? ad['target_age']);
    final String age = ages.isEmpty
        ? '—'
        : ages.any((value) => value.toLowerCase() == 'all')
            ? l.allAges
            : (_ageRange(ages) ?? ages.join(', '));

    final String genderCode = _str(ad['gender']).isNotEmpty
        ? _str(ad['gender'])
        : _str(ad['target_gender']);
    final String locationCode = _str(ad['location']).isNotEmpty
        ? _str(ad['location'])
        : _str(ad['target_location']);
    final String device = l.deviceLabel(_str(ad['device_type']));
    final pricing = ReceiptPricing.from(ad);
    final storedMethod = [
      ad['pricing_payment_method_snapshot'],
      ad['payment_method'],
      ad['receipt_payment_method'],
    ].map(receiptText).firstWhere((v) => v.isNotEmpty, orElse: () => '');
    final payment = pricing.noPaymentRequired
        ? l.noPaymentRequired
        : l.paymentLabel(storedMethod);
    final transaction = [
      ad['payment_transaction_id'],
      ad['receipt_transaction_id'],
    ].map(receiptText).firstWhere((v) => v.isNotEmpty, orElse: () => '');

    final String name = _str(ad['title']).isEmpty ? '—' : _str(ad['title']);

    return AdReceiptData(
      adId: adId,
      date: receiptDateTime(ad['created_at']),
      age: age,
      ageDir:
          RegExp(r'^\d').hasMatch(age) ? TextDirection.ltr : receiptDirOf(age),
      gender: l.genderLabel(genderCode),
      location: l.locationLabel(locationCode),
      device: device,
      deviceDir: receiptDirOf(device),
      category: l.categoryLabel(_str(ad['category'])),
      originalIqd:
          pricing.originalIqd == null ? null : formatIqd(pricing.originalIqd!),
      discountIqd: (pricing.discountIqd ?? 0) > 0
          ? formatIqd(pricing.discountIqd!, sign: '-')
          : null,
      totalIqd: pricing.totalIqd == null ? null : formatIqd(pricing.totalIqd!),
      transactionId:
          pricing.noPaymentRequired || transaction.isEmpty ? null : transaction,
      noPaymentRequired: pricing.noPaymentRequired,
      payment: payment,
      paymentDir: receiptDirOf(payment),
      adName: name,
      adNameDir: receiptDirOf(name),
      uid: uid,
    );
  }
}
