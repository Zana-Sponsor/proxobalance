import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ad_categories.dart';
import 'proxo_pricing.dart';

DateTime adScheduleNow() =>
    DateTime.now().toUtc().add(const Duration(hours: 3));

String adIqd(num value, {bool discount = false}) {
  final number = value.abs().round().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  return '${discount ? '−' : value < 0 ? '−' : ''}$number د.ع';
}

@immutable
class AdDraft {
  final String title, link, code, note;
  final String? goal,
      category,
      assetId,
      assetName,
      paymentMethod,
      promoId,
      promoCode;
  final List<String> ages;
  final String gender, location, device;
  final int dailyBudget, days;
  final DateTime? schedule;
  final bool immediate;

  const AdDraft({
    this.title = '',
    this.link = '',
    this.code = '',
    this.note = '',
    this.goal,
    this.category,
    this.assetId,
    this.assetName,
    this.paymentMethod,
    this.promoId,
    this.promoCode,
    this.ages = const ['all'],
    this.gender = 'all',
    this.location = 'all',
    this.device = 'all',
    this.dailyBudget = 10,
    this.days = 1,
    this.schedule,
    this.immediate = false,
  });

  Map<String, String> validate({DateTime? now}) {
    final errors = <String, String>{};
    if (title.trim().isEmpty || title.trim().length > 120) {
      errors['title'] = 'ناوی ڕیکلام بنووسە؛ زۆرترین 120 پیت';
    }
    if (!const ['messages', 'views'].contains(goal)) {
      errors['goal'] = 'ئامانجی ڕیکلام هەڵبژێرە';
    }
    if (!isSupportedAdCategory(category)) {
      errors['category'] = 'بەشی ڕیکلام هەڵبژێرە';
    }
    if (goal == 'messages' && (assetId == null || assetId!.isEmpty)) {
      errors['asset'] = 'کەرەستەی پەیوەندی هەڵبژێرە';
    }
    final uri = Uri.tryParse(link.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        !(uri.host.toLowerCase() == 'tiktok.com' ||
            uri.host.toLowerCase().endsWith('.tiktok.com')) ||
        uri.path.isEmpty ||
        uri.path == '/' ||
        link.length > 2048) {
      errors['link'] = 'بەستەرێکی دروستی ڤیدیۆی TikTok بنووسە';
    }
    if (code.trim().isEmpty || code.trim().length > 200) {
      errors['code'] = 'کۆدی ڤیدیۆ بنووسە؛ زۆرترین 200 پیت';
    }
    if (schedule == null ||
        (!immediate && schedule!.isBefore(now ?? adScheduleNow()))) {
      errors['schedule'] = 'بەروار و کاتێکی داهاتوو هەڵبژێرە';
    }
    if (!const ['app_balance', 'fastpay'].contains(paymentMethod)) {
      errors['payment'] = 'ڕێگای پارەدان هەڵبژێرە';
    }
    if (!const [10, 20, 50, 100, 200, 500, 1000].contains(dailyBudget) ||
        days < 1 ||
        days > 7) {
      errors['budget'] = 'بودجە و ماوەی ڕیکلام بپشکنەوە';
    }
    if (ages.isEmpty ||
        ages.any((v) => !const [
              'all',
              '18-24',
              '25-34',
              '35-44',
              '45-54',
              '55+',
            ].contains(v)) ||
        (ages.length > 1 && ages.contains('all')) ||
        !const ['all', 'male', 'female'].contains(gender) ||
        !const ['all', 'kurdistan', 'iraq'].contains(location) ||
        !const ['all', 'iphone', 'android'].contains(device)) {
      errors['audience'] = 'هەڵبژاردەکانی ئامانجی ڕیکلام بپشکنەوە';
    }
    if (note.trim().length > 500) {
      errors['note'] = 'تێبینی نابێت لە 500 پیت زیاتر بێت';
    }
    return errors;
  }

  Map<String, dynamic> toAd() {
    String two(int n) => '$n'.padLeft(2, '0');
    return {
      'title': title.trim(),
      'video_link': link.trim(),
      'video_code': code.trim(),
      'post_code': code.trim(),
      'goal': goal,
      'category': category,
      'asset_id': goal == 'messages' ? assetId : null,
      'age_groups': ages,
      'gender': gender,
      'location': location,
      'device_type': device,
      'customer_note': note.trim(),
      'daily_budget': dailyBudget,
      'days': days,
      'payment_method': paymentMethod,
      'start_date': schedule == null
          ? null
          : '${schedule!.year}-${two(schedule!.month)}-${two(schedule!.day)}',
      'start_time': schedule == null
          ? null
          : '${two(schedule!.hour)}:${two(schedule!.minute)}',
      'start_immediately': immediate,
    };
  }

  Map<String, dynamic> toJson() => {
        ...toAd(),
        'asset_name': assetName,
        'promo_id': promoId,
        'promo_code': promoCode
      };

  static List<String> _agesFromJson(dynamic raw) {
    if (raw is List) return raw.map((v) => '$v').toList();
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded.map((v) => '$v').toList();
      } catch (_) {/* Older records may store a single range. */}
      return raw
          .split(',')
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty)
          .toList();
    }
    return const ['all'];
  }

  factory AdDraft.fromJson(Map<String, dynamic> j) => AdDraft(
        title: j['title']?.toString() ?? '',
        link: j['video_link']?.toString() ?? '',
        code: (j['video_code'] ?? j['post_code'])?.toString() ?? '',
        note: j['customer_note']?.toString() ?? '',
        goal: j['goal'] as String?,
        category: j['category'] as String?,
        assetId: j['asset_id']?.toString(),
        assetName: j['asset_name']?.toString(),
        paymentMethod: j['payment_method'] as String?,
        promoId: j['promo_id']?.toString(),
        promoCode: j['promo_code']?.toString(),
        ages: _agesFromJson(j['age_groups']),
        gender: j['gender']?.toString() ?? 'all',
        location: j['location']?.toString() ?? 'all',
        device: j['device_type']?.toString() ?? 'all',
        dailyBudget: num.tryParse('${j['daily_budget']}')?.toInt() ?? 10,
        days: num.tryParse('${j['days']}')?.toInt() ?? 1,
        immediate: j['start_immediately'] == true,
        schedule: j['start_date'] == null || j['start_time'] == null
            ? null
            : DateTime.tryParse('${j['start_date']}T${j['start_time']}'),
      );
}

@immutable
class AdQuote {
  final double grossUsd, costUsd, promoUsd, levelUsd, rate, balanceUsd;
  final double? historicalViewRate;
  final double levelPercent, levelFixedIqd, promoPercent, promoFixedIqd;
  final int days;
  final int? quotedIqd;
  const AdQuote(
      {required this.grossUsd,
      required this.costUsd,
      required this.rate,
      this.promoUsd = 0,
      this.levelUsd = 0,
      this.balanceUsd = 0,
      this.days = 1,
      this.historicalViewRate,
      this.quotedIqd,
      this.levelPercent = 0,
      this.levelFixedIqd = 0,
      this.promoPercent = 0,
      this.promoFixedIqd = 0});
  int get totalIqd => quotedIqd ?? (costUsd * rate).round();
  int get grossIqd => (grossUsd * rate).round();
  int get serviceIqd =>
      (grossUsd * rate * ProxoPricing.serviceFeePercent).round();
  int get sponsorIqd => grossIqd - serviceIqd;
  int get promoIqd => (promoUsd * rate).round();
  int get levelIqd => (levelUsd * rate).round();
  Map<String, dynamic> toJson() => {
        'gross_usd': grossUsd,
        'cost_usd': costUsd,
        'amount_iqd': totalIqd,
        'rate': rate,
        'promo_discount_usd': promoUsd,
        'level_discount_usd': levelUsd,
        'balance_usd': balanceUsd,
        'days': days,
        'historical_view_rate': historicalViewRate,
        'level_percent': levelPercent,
        'level_fixed_iqd': levelFixedIqd,
        'promo_percent': promoPercent,
        'promo_fixed_iqd': promoFixedIqd
      };
  AdQuote forBudget(int daily, int duration, {bool clearPromo = false}) {
    double round6(double value) => double.parse(value.toStringAsFixed(6));
    final gross = daily * duration * 1.0;
    final level =
        (round6(gross * levelPercent / 100) + round6(levelFixedIqd / rate))
            .clamp(0.0, gross)
            .toDouble();
    final promo = clearPromo
        ? 0.0
        : round6(gross * promoPercent / 100 + promoFixedIqd / rate)
            .clamp(0.0, gross)
            .toDouble();
    return AdQuote(
        grossUsd: gross,
        costUsd: round6(gross - level - promo).clamp(0.0, gross).toDouble(),
        rate: rate,
        promoUsd: promo,
        levelUsd: level,
        balanceUsd: balanceUsd,
        days: duration,
        historicalViewRate: historicalViewRate,
        levelPercent: levelPercent,
        levelFixedIqd: levelFixedIqd,
        promoPercent: clearPromo ? 0 : promoPercent,
        promoFixedIqd: clearPromo ? 0 : promoFixedIqd);
  }

  factory AdQuote.fromJson(Map<String, dynamic> j) {
    double n(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return AdQuote(
        grossUsd: n('gross_usd'),
        costUsd: n('cost_usd'),
        quotedIqd: num.tryParse('${j['amount_iqd']}')?.round(),
        rate: n('rate'),
        promoUsd: n('promo_discount_usd'),
        levelUsd: n('level_discount_usd'),
        balanceUsd: n('balance_usd'),
        days: (j['days'] as num?)?.toInt() ?? 1,
        historicalViewRate: (j['historical_view_rate'] as num?)?.toDouble(),
        levelPercent: n('level_percent'),
        levelFixedIqd: n('level_fixed_iqd'),
        promoPercent: n('promo_percent'),
        promoFixedIqd: n('promo_fixed_iqd'));
  }
}

class AdSubmissionFailure implements Exception {
  final String code;
  final bool uncertain;
  final bool paymentCredited;
  const AdSubmissionFailure(this.code,
      {this.uncertain = false, this.paymentCredited = false});
  String get message => paymentCredited
      ? '$_message پارەدانی FastPay لە باڵانسی هەژمارەکەت پارێزراوە؛ بۆ دەستکاری بگەڕێوە و بە باڵانس پارە بدە.'
      : _message;
  String get _message => switch (code) {
        'INSUFFICIENT_FUNDS' => 'باڵانسی پێویستت بەردەست نییە',
        'INVALID_PROMO' => 'کۆدی داشکاندن نادروستە یان بەسەرچووە',
        'INVALID_SCHEDULE' => 'کاتی ڕیکلام تێپەڕیوە؛ کاتێکی دواتر هەڵبژێرە',
        'INVALID_ASSET' => 'کەرەستەی پەیوەندی بەردەست نییە؛ دووبارە هەڵیبژێرە',
        'PRICE_CHANGED' => 'نرخ گۆڕاوە؛ وردەکاری نرخ دووبارە بپشکنەوە',
        'NOT_AUTHENTICATED' => 'دووبارە بچۆ ژوورەوە',
        'FASTPAY_TERMINAL' => 'پارەدانی FastPay تەواو نەکرا',
        'AMOUNT_TOO_SMALL' => 'بڕی پارەدان بۆ FastPay زۆر کەمە',
        'STORAGE_UNAVAILABLE' => 'داواکاریەکە نەپارێزرا؛ دووبارە هەوڵ بدەرەوە',
        'IDEMPOTENCY_CONFLICT' => 'داواکاریەکی پێشوو پێویستی بە پشکنین هەیە',
        _ => uncertain
            ? 'وەڵامی کۆتایی نەگەیشت؛ هەمان داواکاری دووبارە بپشکنەوە'
            : 'زانیارییەکان یان پەیوەندی بپشکنەوە و دووبارە هەوڵ بدەرەوە',
      };
}

@immutable
class AdPendingSubmission {
  final String id;
  final AdDraft draft;
  final AdQuote quote;
  const AdPendingSubmission(
      {required this.id, required this.draft, required this.quote});
  factory AdPendingSubmission.create(AdDraft draft, AdQuote quote) {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return AdPendingSubmission(
        id: '${h.substring(0, 8)}-${h.substring(8, 12)}-'
            '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}',
        draft: draft,
        quote: quote);
  }
  String get fastPayOrderId =>
      'AD${id.replaceAll('-', '').substring(0, 28).toUpperCase()}';
  Map<String, dynamic> toJson() =>
      {'id': id, 'draft': draft.toJson(), 'quote': quote.toJson()};
  factory AdPendingSubmission.fromJson(Map<String, dynamic> j) =>
      AdPendingSubmission(
          id: j['id'] as String,
          draft: AdDraft.fromJson(Map<String, dynamic>.from(j['draft'] as Map)),
          quote:
              AdQuote.fromJson(Map<String, dynamic>.from(j['quote'] as Map)));
}

@immutable
class AdPaymentProgress {
  final String message;
  final String? qrUrl, deepLink;
  final bool waitingForPayment;
  const AdPaymentProgress(
      {this.message = 'داواکاریەکە تۆمار دەکرێت…',
      this.qrUrl,
      this.deepLink,
      this.waitingForPayment = false});
}

abstract class AdCreationRepository {
  Future<List<Map<String, dynamic>>> loadAssets();
  Future<AdQuote> quote(AdDraft draft);
  Future<AdPendingSubmission?> pending();
  Future<String> submit(
      AdPendingSubmission request, ValueNotifier<AdPaymentProgress> progress);
  Future<void> openPayment(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !const ['https', 'appfpp', 'fastpay']
            .contains(uri.scheme.toLowerCase())) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// All money mutations live in pa_submit_ad / pa_create_ad, never in Flutter.
class SupabaseAdCreationRepository extends AdCreationRepository {
  static final Map<String, (String, Future<String>)> _activeSubmissions = {};
  final SupabaseClient client;
  SupabaseAdCreationRepository(this.client);
  String get _user =>
      client.auth.currentUser?.id ??
      (throw const AdSubmissionFailure('NOT_AUTHENTICATED'));
  String get _storageKey => 'proxo.pending-ad.v1.$_user';
  Map<String, dynamic> _map(dynamic raw) =>
      Map<String, dynamic>.from(raw as Map);

  @override
  Future<List<Map<String, dynamic>>> loadAssets() async =>
      List<Map<String, dynamic>>.from(await client
          .from('proxolink_cards')
          .select('id,name,style,color_theme,card_number,avatar_b64')
          .eq('user_id', _user)
          .order('created_at', ascending: false));

  @override
  Future<AdQuote> quote(AdDraft draft) async {
    final j = _map(await client.rpc('pa_preview_ad', params: {
      'p_ad': draft.toAd(),
      'p_promo_id': draft.promoId,
      'p_promo_code': draft.promoCode,
    }).timeout(const Duration(seconds: 20)));
    if (j['ok'] != true) throw AdSubmissionFailure('${j['code']}');
    return AdQuote.fromJson({...j, 'days': draft.days});
  }

  @override
  Future<AdPendingSubmission?> pending() async {
    final raw = (await SharedPreferences.getInstance()).getString(_storageKey);
    if (raw == null) return null;
    return AdPendingSubmission.fromJson(_map(jsonDecode(raw)));
  }

  @override
  Future<String> submit(
      AdPendingSubmission request, ValueNotifier<AdPaymentProgress> progress) {
    final user = _user;
    final active = _activeSubmissions[user];
    if (active != null) {
      return active.$1 == request.id
          ? active.$2
          : Future.error(const AdSubmissionFailure('IDEMPOTENCY_CONFLICT',
              uncertain: true));
    }
    final operation = _submit(request, progress)
        .whenComplete(() => _activeSubmissions.remove(user));
    _activeSubmissions[user] = (request.id, operation);
    return operation;
  }

  Future<String> _submit(AdPendingSubmission request,
      ValueNotifier<AdPaymentProgress> progress) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _storageKey;
    final existing = prefs.getString(key);
    if (existing != null &&
        AdPendingSubmission.fromJson(_map(jsonDecode(existing))).id !=
            request.id) {
      throw const AdSubmissionFailure('IDEMPOTENCY_CONFLICT', uncertain: true);
    }
    if (!await prefs.setString(key, jsonEncode(request.toJson()))) {
      throw const AdSubmissionFailure('STORAGE_UNAVAILABLE');
    }
    String? paymentId;
    try {
      // Recover a committed operation before checking dates or spending again.
      final recovered =
          _map(await client.rpc('pa_ad_submission_status', params: {
        'p_submission_id': request.id,
      }).timeout(const Duration(seconds: 20)));
      if (recovered['ok'] == true) {
        await prefs.remove(key);
        final adId = recovered['ad_id'] as String;
        _ensureThumbnail(adId);
        return adId;
      }
      if (recovered['code'] != 'NOT_FOUND') {
        // A failed status lookup cannot prove that an earlier request failed.
        throw AdSubmissionFailure('${recovered['code']}', uncertain: true);
      }
      final errors = request.draft.validate();
      if (errors.isNotEmpty) {
        throw AdSubmissionFailure(
            errors.containsKey('schedule') ? 'INVALID_SCHEDULE' : 'INVALID_AD');
      }
      if (request.draft.paymentMethod == 'fastpay') {
        paymentId = await _payWithFastPay(request, progress);
      }
      progress.value = const AdPaymentProgress();
      final result = _map(await client.rpc('pa_submit_ad', params: {
        'p_submission_id': request.id,
        'p_ad': {...request.draft.toAd(), 'payment_transaction_id': paymentId},
        'p_expected_cost_usd': request.quote.costUsd,
        'p_expected_price_iqd': request.quote.totalIqd,
        'p_promo_id': request.draft.promoId,
        'p_promo_code': request.draft.promoCode,
      }).timeout(const Duration(seconds: 30)));
      if (result['ok'] != true) throw AdSubmissionFailure('${result['code']}');
      final adId = result['ad_id'] as String;
      await prefs.remove(key);
      _ensureThumbnail(adId);
      return adId;
    } on AdSubmissionFailure catch (e) {
      if (!e.uncertain) await prefs.remove(key);
      if (!e.uncertain && paymentId != null) {
        throw AdSubmissionFailure(e.code, paymentCredited: true);
      }
      rethrow;
    } catch (_) {
      // Keep the SAME id and frozen payload on timeout, disconnect or app kill.
      throw const AdSubmissionFailure('NETWORK', uncertain: true);
    }
  }

  void _ensureThumbnail(String adId) {
    unawaited(client.functions
        .invoke('generate-ad-thumbnail', body: {'ad_id': adId}).then<void>(
            (_) {}, onError: (Object e, StackTrace s) {
      debugPrint('Ad thumbnail generation deferred: ${e.runtimeType}');
    }));
  }

  Future<String> _payWithFastPay(
      AdPendingSubmission r, ValueNotifier<AdPaymentProgress> progress) async {
    if (r.quote.totalIqd < 1000) {
      throw const AdSubmissionFailure('AMOUNT_TOO_SMALL');
    }
    const base = 'https://email.proxopages.com/webhook/fastpay';
    final orderId = r.fastPayOrderId;
    Map<String, dynamic>? row = await _paymentRow(orderId);
    if (row == null) {
      final session = client.auth.currentSession;
      if (session == null) throw const AdSubmissionFailure('NOT_AUTHENTICATED');
      progress.value =
          const AdPaymentProgress(message: 'پارەدانی FastPay ئامادە دەکرێت…');
      final response = await http
          .post(Uri.parse('$base/order-create'),
              headers: {
                'Content-Type': 'application/json; charset=utf-8',
                'Accept': 'application/json',
                'Authorization': 'Bearer ${session.accessToken}',
              },
              body: jsonEncode({
                'purpose': 'ad_checkout',
                'orderId': orderId,
                'currency': 'IQD',
                'note': 'Proxo ad payment',
                'ad': {
                  'daily_budget': r.draft.dailyBudget,
                  'days': r.draft.days
                },
                'promoId': r.draft.promoId,
                'promoCode': r.draft.promoCode,
              }))
          .timeout(const Duration(seconds: 25));
      final data = _map(jsonDecode(utf8.decode(response.bodyBytes)));
      if (response.statusCode != 200 || data['success'] != true) {
        throw const AdSubmissionFailure('FASTPAY_NETWORK', uncertain: true);
      }
      final amount = data['amountIqd'];
      if (num.tryParse('$amount')?.round() != r.quote.totalIqd) {
        // Never ask the user to pay an amount different from the confirmation.
        throw const AdSubmissionFailure('PRICE_CHANGED');
      }
      row = await _paymentRow(orderId);
    }
    final deadline = DateTime.now().add(const Duration(minutes: 11));
    while (DateTime.now().isBefore(deadline)) {
      row ??= await _paymentRow(orderId);
      if (row != null) {
        final status = '${row['gateway_status']}'.toUpperCase();
        if (row['status'] == 'approved' &&
            status == 'PAID' &&
            row['wallet_credited'] == true) {
          return row['id'] as String;
        }
        if (const [
          'EXPIRED',
          'DECLINED',
          'FAILED',
          'CANCELLED',
          'CANCELED',
          'REJECTED'
        ].contains(status)) {
          throw const AdSubmissionFailure('FASTPAY_TERMINAL');
        }
        final qr = row['qr_text']?.toString();
        progress.value = AdPaymentProgress(
            message: 'پارەدان بکە؛ پشتڕاستکردنەوە بە خۆکارە',
            waitingForPayment: true,
            qrUrl: row['qr_url']?.toString(),
            deepLink: qr == null || qr.isEmpty
                ? null
                : 'appFpp://fast-pay.cash/qrpay'
                    '?qrdata=${Uri.encodeQueryComponent(qr)}&clientUri=appfpclientProxo'
                    '&transactionId=${Uri.encodeQueryComponent(orderId)}');
      }
      await Future<void>.delayed(const Duration(seconds: 3));
      final session = client.auth.currentSession;
      if (session == null) throw const AdSubmissionFailure('NOT_AUTHENTICATED');
      try {
        await http
            .post(Uri.parse('$base/order-status'),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer ${session.accessToken}',
                },
                body: jsonEncode({'orderId': orderId}))
            .timeout(const Duration(seconds: 15));
      } catch (_) {
        /* Ledger remains authoritative; transient polling errors retry. */
      }
      row = await _paymentRow(orderId);
    }
    throw const AdSubmissionFailure('FASTPAY_WAIT', uncertain: true);
  }

  Future<Map<String, dynamic>?> _paymentRow(String orderId) async =>
      await client
          .from('pa_transactions')
          .select(
              'id,status,gateway_status,qr_url,qr_text,amount,wallet_credited')
          .eq('user_id', _user)
          .eq('fastpay_order_id', orderId)
          .maybeSingle();
}
