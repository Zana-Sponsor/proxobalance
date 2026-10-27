import 'account_cache.dart';
import '../config/backend_config.dart';
import 'app_telemetry_service.dart';
import 'owner_storage_queue.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ad_categories.dart';
import 'meta_ad_draft.dart';
import 'tiktok_dm_accounts.dart' show tiktokDmMessage;
import 'proxo_pricing.dart';

/// Baghdad calendar fields, carried as UTC to avoid the device's time zone or
/// daylight-saving rules. This value is wall-clock time, not a UTC instant.
DateTime adScheduleNow({DateTime? instant}) =>
    (instant ?? DateTime.now()).toUtc().add(const Duration(hours: 3));

DateTime _adScheduleFields(DateTime value) => DateTime.utc(
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond);

String adIqd(num value, {bool discount = false}) {
  final number = value.abs().round().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  return '${discount ? '−' : value < 0 ? '−' : ''}$number د.ع';
}

@immutable
class AdDraft {
  final String title, link, code, note;
  final String platform, pageUrl;
  final String messageDestination;

  /// Customer-facing TikTok flow, persisted locally without inventing a new
  /// provider objective. Null preserves the frozen contract of older attempts.
  final String? tiktokAdType;
  bool get hasTypedTikTokFlow => !isMeta && tiktokAdType != null;
  String? get effectiveCategory => hasTypedTikTokFlow
      ? switch (tiktokAdType) {
          'restaurant' => 'food_beverage',
          'app_download' => 'games_apps',
          _ => 'other',
        }
      : category;
  final String? tiktokAccountId, tiktokItemId, tiktokUsername;
  final String tiktokVideoCaption;
  bool get isTikTokDirect =>
      platform == 'TIKTOK' &&
      goal == 'messages' &&
      messageDestination == 'direct_message' &&
      (tiktokAdType == null || tiktokAdType == 'contact');
  final Set<String> placements, destinations;
  final int ageMin, ageMax;
  bool get isMeta => platform == 'META';
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
    this.platform = 'TIKTOK',
    this.pageUrl = '',
    this.messageDestination = 'external_contact',
    this.tiktokAdType,
    this.tiktokAccountId,
    this.tiktokItemId,
    this.tiktokUsername,
    this.tiktokVideoCaption = '',
    this.placements = const {'facebook', 'instagram'},
    this.destinations = const {'WHATSAPP', 'MESSENGER', 'INSTAGRAM_DIRECT'},
    this.ageMin = 18,
    this.ageMax = 65,
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
    if (title.trim().isEmpty || title.trim().runes.length > 120) {
      errors['title'] = 'ناوی ڕیکلام بنووسە؛ زۆرترین 120 پیت';
    }
    if (!(isMeta ? metaObjectiveLabels.keys : const ['messages', 'views'])
        .contains(goal)) {
      errors['goal'] =
          isMeta ? 'ئامانجی ڕیکلام هەڵبژێرە' : 'جۆری ڕیکلام هەڵبژێرە';
    }
    if (hasTypedTikTokFlow &&
        (!const {
              'contact',
              'views',
              'restaurant',
              'app_download',
            }.contains(tiktokAdType) ||
            goal != (tiktokAdType == 'views' ? 'views' : 'messages'))) {
      errors['goal'] = 'جۆری ڕیکلام هەڵبژێرە';
    }
    if (!isMeta && !isSupportedAdCategory(effectiveCategory)) {
      errors['category'] = 'بەشی ڕیکلام هەڵبژێرە';
    }
    if (!isMeta &&
        !isTikTokDirect &&
        goal == 'messages' &&
        (assetId == null || assetId!.isEmpty)) {
      errors['asset'] = 'کەرەستەی پەیوەندی هەڵبژێرە';
    }
    final uri = Uri.tryParse(link.trim());
    if (!isMeta &&
        !isTikTokDirect &&
        (uri == null ||
            uri.scheme != 'https' ||
            uri.userInfo.isNotEmpty ||
            !(uri.host.toLowerCase() == 'tiktok.com' ||
                uri.host.toLowerCase().endsWith('.tiktok.com')) ||
            uri.path.isEmpty ||
            uri.path == '/' ||
            link.length > 2048)) {
      errors['link'] = 'بەستەرێکی دروستی ڤیدیۆی TikTok بنووسە';
    }
    if (!isMeta &&
        !isTikTokDirect &&
        (code.trim().isEmpty || code.trim().length > 200)) {
      errors['code'] = 'کۆدی ڤیدیۆ بنووسە؛ زۆرترین 200 پیت';
    }
    if ((!immediate && schedule == null) ||
        (!immediate &&
            _adScheduleFields(schedule!)
                .isBefore(_adScheduleFields(now ?? adScheduleNow())))) {
      errors['schedule'] = 'بەروار و کاتێکی داهاتوو هەڵبژێرە';
    }
    if (!const ['app_balance', 'fastpay'].contains(paymentMethod)) {
      errors['payment'] = 'ڕێگای پارەدان هەڵبژێرە';
    }
    if (!(isMeta
            ? dailyBudget >= 2 && dailyBudget <= 1000
            : const [10, 20, 50, 100, 200, 500, 1000].contains(dailyBudget)) ||
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
        !(isMeta
                ? const ['all', 'erbil', 'sulaymaniyah', 'duhok', 'baghdad']
                : const ['all', 'kurdistan', 'iraq'])
            .contains(location) ||
        (!hasTypedTikTokFlow &&
            !const ['all', 'iphone', 'android'].contains(device))) {
      errors['audience'] = 'هەڵبژاردەکانی ئامانجی ڕیکلام بپشکنەوە';
    }
    if (note.trim().length > 500) {
      errors['note'] = 'تێبینی نابێت لە 500 پیت زیاتر بێت';
    }
    if (!isMeta &&
        goal == 'messages' &&
        !const {'direct_message', 'external_contact'}
            .contains(messageDestination)) {
      errors['destination'] = 'شوێنی پەیوەندی هەڵبژێرە';
    }
    if (hasTypedTikTokFlow &&
        tiktokAdType != 'contact' &&
        messageDestination != 'external_contact') {
      errors['destination'] = 'شوێنی پەیوەندی هەڵبژێرە';
    }
    if (isTikTokDirect) {
      if (tiktokAccountId == null || tiktokAccountId!.isEmpty) {
        errors['tiktok_account'] = 'هەژمارێکی پەیوەستکراوی تیک تۆک هەڵبژێرە';
      }
      if (tiktokItemId == null || tiktokItemId!.isEmpty) {
        errors['tiktok_video'] = 'ڤیدیۆیەکی گونجاو هەڵبژێرە';
      }
    }
    if (isMeta) {
      if (!validMetaUrl(link)) errors['link'] = 'لینکی پۆست / ڤیدیۆ بپشکنەوە';
      if (!validMetaUrl(pageUrl, page: true)) {
        errors['page'] = 'لینکی پەیجی فەیسبووک بپشکنەوە';
      }
      if (placements.isEmpty ||
          placements.any((p) => !const {'facebook', 'instagram'}.contains(p))) {
        errors['placements'] = 'لانیکەم یەک شوێنی پیشاندان هەڵبژێرە';
      }
      final selection =
          MetaAdSelection(placements: placements, destinations: destinations);
      if (goal == 'messages' &&
          (destinations.isEmpty ||
              destinations.any((d) => !selection.available(d)))) {
        errors['destinations'] = 'لانیکەم یەک ڕێگای نامەی بەردەست هەڵبژێرە';
      }
      if (ageMin < 18 || ageMax > 65 || ageMin > ageMax) {
        errors['audience'] = 'مەودای تەمەن بپشکنەوە';
      }
    }
    return errors;
  }

  Map<String, dynamic> toMetaContract() => {
        'schema_version': 3,
        'platform': 'META',
        'ad_name': title.trim(),
        'objective': metaObjectiveCodes[goal],
        'page_url': pageUrl.trim(),
        'post_url': link.trim(),
        'placements': MetaAdSelection.canonical(placements),
        if (goal == 'messages')
          'destinations': MetaAdSelection.canonical(destinations),
        'currency': 'USD',
        'budget_daily': dailyBudget,
        'duration_days': days,
        'payment_method': paymentMethod == 'fastpay' ? 'FASTPAY' : 'WALLET',
        'schedule': {
          'mode': immediate ? 'IMMEDIATE' : 'SCHEDULED',
          'timezone': 'Asia/Baghdad',
          if (!immediate && schedule != null)
            'start_at': _adScheduleFields(schedule!)
                .subtract(const Duration(hours: 3))
                .toIso8601String()
        },
        'targeting': {
          'location': location,
          'gender': gender.toUpperCase(),
          'age_min': ageMin,
          'age_max': ageMax
        },
      };

  Map<String, dynamic> toAd() {
    String two(int n) => '$n'.padLeft(2, '0');
    return {
      'title': title.trim(),
      if (!isTikTokDirect) ...{
        'video_link': link.trim(),
        'video_code': code.trim(),
        'post_code': code.trim(),
      },
      'goal': goal,
      if (hasTypedTikTokFlow && !isTikTokDirect) 'tiktok_ad_type': tiktokAdType,
      if (!isMeta && goal == 'messages')
        'message_destination': messageDestination,
      if (isTikTokDirect) ...{
        'tiktok_account_id': tiktokAccountId,
        'tiktok_item_id': tiktokItemId,
      },
      'category': effectiveCategory,
      if (!isTikTokDirect) 'asset_id': goal == 'messages' ? assetId : null,
      'age_groups': ages,
      'gender': gender,
      'location': location,
      'device_type': hasTypedTikTokFlow ? 'all' : device,
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
        if (hasTypedTikTokFlow) 'tiktok_ad_type': tiktokAdType,
        if (isMeta) ...{
          'platform': platform,
          'page_url': pageUrl,
          'placements': MetaAdSelection.canonical(placements),
          'destinations': MetaAdSelection.canonical(destinations),
          'age_min': ageMin,
          'age_max': ageMax
        },
        'asset_name': assetName,
        if (isTikTokDirect) 'tiktok_username': tiktokUsername,
        if (isTikTokDirect) 'tiktok_video_caption': tiktokVideoCaption,
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
        platform: j['platform']?.toString() ?? 'TIKTOK',
        tiktokAdType: j['tiktok_ad_type']?.toString(),
        pageUrl: j['page_url']?.toString() ?? '',
        messageDestination:
            j['message_destination']?.toString() ?? 'external_contact',
        tiktokAccountId: j['tiktok_account_id']?.toString(),
        tiktokItemId: j['tiktok_item_id']?.toString(),
        tiktokUsername: j['tiktok_username']?.toString(),
        tiktokVideoCaption: j['tiktok_video_caption']?.toString() ?? '',
        placements: Set<String>.from(
            j['placements'] ?? const ['facebook', 'instagram']),
        destinations: Set<String>.from(j['destinations'] ?? const []),
        ageMin: (j['age_min'] as num?)?.toInt() ?? 18,
        ageMax: (j['age_max'] as num?)?.toInt() ?? 65,
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
            : DateTime.tryParse('${j['start_date']}T${j['start_time']}Z'),
      );
}

@immutable
class AdQuote {
  final double grossUsd, costUsd, promoUsd, levelUsd, rate, balanceUsd;
  final double? historicalViewRate;
  final double levelPercent, levelFixedIqd, promoPercent, promoFixedIqd;
  final int days;
  final int? quotedIqd;
  final Map<String, dynamic>? metaContract;
  final Map<String, dynamic>? tiktokContract;
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
      this.metaContract,
      this.tiktokContract,
      this.levelPercent = 0,
      this.levelFixedIqd = 0,
      this.promoPercent = 0,
      this.promoFixedIqd = 0});
  int get totalIqd => quotedIqd ?? (costUsd * rate).round();
  int get grossIqd => (grossUsd * rate).round();
  int get serviceIqd => metaContract != null
      ? 0
      : (grossUsd * rate * ProxoPricing.serviceFeePercent).round();
  int get sponsorIqd => grossIqd - serviceIqd;
  int get promoIqd => (promoUsd * rate).round();
  int get levelIqd => (levelUsd * rate).round();
  Map<String, dynamic> toJson() => {
        if (metaContract != null) 'meta_contract': metaContract,
        if (tiktokContract != null) 'tiktok_contract': tiktokContract,
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
        metaContract: metaContract == null ? null : {'preview_only': true},
        tiktokContract: tiktokContract == null ? null : {'preview_only': true},
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
        metaContract: (j['meta_contract'] as Map?)?.cast<String, dynamic>(),
        tiktokContract: (j['tiktok_contract'] as Map?)?.cast<String, dynamic>(),
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
  /// Set only by a strict initial-prepare rejection proving no durable payment
  /// attempt exists. Missing/ambiguous responses never set this marker.
  final bool paymentAttemptAbsent;
  /// A durable attempt was irrevocably closed before any gateway request could
  /// start. This is different from expiry/decline of a dispatched payment.
  final bool paymentAttemptClosedUnstarted;
  const AdSubmissionFailure(this.code,
      {this.uncertain = false,
      this.paymentCredited = false,
      this.paymentAttemptAbsent = false,
      this.paymentAttemptClosedUnstarted = false});

  /// A brief reason for temporary feedback. Financial recovery instructions
  /// remain in [message] so they stay readable after the notice expires.
  String get briefMessage => _message;
  String get message => paymentCredited
      ? '$_message پارەدانی FastPay لە باڵانسی هەژمارەکەت پارێزراوە؛ بۆ دەستکاری بگەڕێوە و بە باڵانس پارە بدە.'
      : _message;
  String get _message => switch (code) {
        'INSUFFICIENT_FUNDS' => 'باڵانسی پێویستت بەردەست نییە',
        'INVALID_PROMO' => 'کۆدی داشکاندن نادروستە یان بەسەرچووە',
        'INVALID_SCHEDULE' => 'کاتی ڕیکلام تێپەڕیوە؛ کاتێکی دواتر هەڵبژێرە',
        'INVALID_ASSET' => 'کەرەستەی پەیوەندی بەردەست نییە؛ دووبارە هەڵیبژێرە',
        'PRICE_CHANGED' => 'نرخ گۆڕاوە؛ پوختەی نرخ دووبارە بپشکنەوە',
        'QUOTE_EXPIRED' ||
        'QUOTE_MISMATCH' ||
        'INVALID_QUOTE' =>
          'پوختەی نرخ نوێ بکەرەوە و دووبارە پشتڕاستی بکەرەوە',
        'META_DISABLED' ||
        'FEATURE_DISABLED' ||
        'NOT_ELIGIBLE' =>
          'دروستکردنی ڕیکلامی Meta ئێستا بەردەست نییە',
        'FASTPAY_DISABLED' ||
        'PAYMENT_NOT_ENABLED' ||
        'AD_FASTPAY_UNAVAILABLE' ||
        'META_FASTPAY_UNAVAILABLE' ||
        'TIKTOK_DM_FASTPAY_UNAVAILABLE' =>
          'پارەدانی FastPay بۆ ئەم ڕیکلامە ئێستا بەردەست نییە؛ باڵانسی هەژمار هەڵبژێرە',
        'TIKTOK_DM_DISABLED' ||
        'CONVERSATION_UNAVAILABLE' ||
        'DM_NOT_ELIGIBLE' =>
          'ڕیکلامی نامەی ڕاستەوخۆ بۆ ئەم هەژمارە بەردەست نییە',
        'VIDEO_UNAVAILABLE' =>
          'ڤیدیۆی هەڵبژێردراو چیتر بەردەست نییە؛ ڤیدیۆیەکی تر هەڵبژێرە',
        'ACCOUNT_NOT_LINKED' ||
        'ACCOUNT_UNAVAILABLE' ||
        'MESSAGE_PERMISSION_REQUIRED' ||
        'VIDEO_PERMISSION_REQUIRED' =>
          'هەژمار یان مۆڵەتەکانی تیک تۆک پشتڕاست نەکرانەوە؛ پەیوەندییەکە نوێ بکەرەوە',
        'BUDGET_BELOW_PROVIDER_MINIMUM' ||
        'PROVIDER_BUDGET_MINIMUM' =>
          'بودجە لە کەمترین بڕی ڕێگەپێدراوی تیک تۆک کەمترە؛ بودجەی زیاتر هەڵبژێرە',
        'UNSUPPORTED_LOCATION' ||
        'TARGETING_UNAVAILABLE' =>
          'ناوچەی هەڵبژێردراو بۆ ئەم ڕیکلامە پشتڕاست نەکراوەتەوە',
        'PAGE_UNRESOLVED' ||
        'PAGE_ACCESS_REQUIRED' =>
          'پەیجەکە یان دەسەڵاتی ڕیکلامکردنی پشتڕاست نەکرایەوە؛ لینکی پەیج بپشکنەوە',
        'POST_UNRESOLVED' ||
        'POST_PAGE_MISMATCH' =>
          'پۆستەکە و پەیوەندی بە پەیجەکە پشتڕاست نەکرایەوە؛ لینکەکان بپشکنەوە',
        'INCOMPATIBLE_DESTINATIONS' ||
        'INVALID_DESTINATIONS' =>
          'ڕێگاکانی نامە لەگەڵ شوێنی پیشاندان بپشکنەوە',
        'WHATSAPP_NOT_LINKED' ||
        'INSTAGRAM_NOT_LINKED' =>
          'هەژماری پەیوەستکراو بە پەیجەکە پشتڕاست نەکرایەوە',
        'UNSUPPORTED_CONFIGURATION' ||
        'CAPABILITY_UNVERIFIED' =>
          'ئەم هەڵبژاردنانە هێشتا بۆ هەژماری ڕیکلام پشتڕاست نەکراونەتەوە',
        'SERVER_TIME_UNAVAILABLE' =>
          'کاتی سێرڤەر پشتڕاست نەکرایەوە؛ دووبارە هەوڵ بدەرەوە',
        'NOT_AUTHENTICATED' => 'دووبارە بچۆ ژوورەوە',
        'FASTPAY_TERMINAL' => 'پارەدانی FastPay تەواو نەکرا',
        'FASTPAY_NOT_STARTED' =>
          'پارەدان دەستی پێ نەکردووە؛ بگەڕێوە و دووبارە هەوڵ بدەوە.',
        'AMOUNT_TOO_SMALL' => 'بڕی پارەدان بۆ FastPay زۆر کەمە',
        'STORAGE_UNAVAILABLE' => 'داواکاریەکە نەپارێزرا؛ دووبارە هەوڵ بدەرەوە',
        'CANCELLED' =>
          'پشکنین ڕاگیرا؛ ئەنجامی داواکارییەکە دەتوانیت دواتر بپشکنیتەوە',
        'SERVER_REJECTED' =>
          'سێرڤەر داواکارییەکەی قبوڵ نەکرد؛ زانیارییەکان بپشکنە و دووبارە هەوڵ بدەرەوە',
        'IDEMPOTENCY_CONFLICT' => 'داواکاریەکی پێشوو پێویستی بە پشکنین هەیە',
        _ => uncertain
            ? 'وەڵامی کۆتایی نەگەیشت؛ هەمان داواکاری دووبارە بپشکنەوە'
            : code.startsWith('TIKTOK_')
                ? tiktokDmMessage(code)
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

  /// Existing test/custom repositories keep their contract; production filters
  /// by stored page kind before the database returns rows.
  Future<List<Map<String, dynamic>>> loadAssetsForType(String pageKind) async {
    if (!const {'contact', 'order', 'download'}.contains(pageKind)) {
      throw const AdSubmissionFailure('INVALID_REQUEST');
    }
    return (await loadAssets())
        .where(
          (row) =>
              (row['page_kind'] ?? 'contact') == pageKind &&
              (row['status'] == null || row['status'] == 'active') &&
              (row['publish_status'] == null ||
                  row['publish_status'] == 'ready'),
        )
        .toList();
  }

  Future<AdQuote> quote(AdDraft draft);
  Future<AdPendingSubmission?> pending();
  Future<bool> metaAvailable() async => false;
  Future<bool> metaFastPayAvailable() async => false;
  Future<bool> tiktokDmAvailable() async => false;
  Future<bool> tiktokDmFastPayAvailable() async => false;
  Future<bool> tiktokDmSeen() async => true;
  Future<void> markTikTokDmSeen() async {}
  Future<DateTime?> serverTime() async => null;
  Future<String> submit(
      AdPendingSubmission request, ValueNotifier<AdPaymentProgress> progress);

  /// Stop client polling / further writes. An already sent request cannot be
  /// recalled: its persisted id is retained until its result is reconciled.
  void cancelPendingOperation(String submissionId) {}

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
  static final Set<String> _cancelledSubmissions = {};
  static final _pendingStorage = OwnerStorageQueue();
  final SupabaseClient client;
  final BackendConfig _backend;
  SupabaseAdCreationRepository(this.client, {BackendConfig? backendConfig})
      : _backend = backendConfig ?? BackendConfig.current;
  String get _user =>
      client.auth.currentUser?.id ??
      (throw const AdSubmissionFailure('NOT_AUTHENTICATED'));
  @override
  Future<bool> metaAvailable() async {
    try {
      return (await client.rpc('pa_ad_capabilities'))['meta_enabled'] == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<DateTime?> serverTime() async {
    try {
      return DateTime.tryParse(
          '${(await client.rpc('pa_ad_capabilities'))['server_time']}');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> metaFastPayAvailable() async {
    try {
      return (await client.rpc('pa_ad_capabilities'))['meta_fastpay_enabled'] ==
          true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> _metaCall(
          String op, Map<String, dynamic> body) =>
      _adsCall('meta-ads', op, body);

  Future<Map<String, dynamic>> _tiktokCall(
          String op, Map<String, dynamic> body) =>
      _adsCall('tiktok-dm', op, body);

  Future<Map<String, dynamic>> _paymentCall(
          String op, Map<String, dynamic> body) =>
      _adsCall('meta-ads', op, body, platform: 'payments');

  @override
  Future<bool> tiktokDmAvailable() async {
    try {
      return (await client.rpc('pa_ad_capabilities'))['tiktok_dm_enabled'] ==
          true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> tiktokDmFastPayAvailable() async {
    try {
      return (await client
              .rpc('pa_ad_capabilities'))['tiktok_dm_fastpay_enabled'] ==
          true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> tiktokDmSeen() async {
    try {
      return (await client.rpc('pa_ad_capabilities'))['tiktok_dm_seen'] !=
          false;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> markTikTokDmSeen() async {
    await _tiktokCall('seen', const {});
  }

  Future<Map<String, dynamic>> _adsCall(
      String service, String op, Map<String, dynamic> body,
      {String? platform}) async {
    final token = client.auth.currentSession?.accessToken;
    if (token == null) throw const AdSubmissionFailure('NOT_AUTHENTICATED');
    final response = await http
        .post(
            Uri.parse('${_backend.publicBase}/api/$service').replace(
                queryParameters: {
                  'op': op,
                  if (platform != null) 'platform': platform
                }),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json'
            },
            body: jsonEncode(body))
        .timeout(Duration(seconds: op == 'quote' ? 60 : 25));
    final value = _map(jsonDecode(utf8.decode(response.bodyBytes)));
    if (response.statusCode >= 500 ||
        (platform == 'payments' && value['ok'] == true &&
            response.statusCode != 200)) {
      throw const AdSubmissionFailure('NETWORK', uncertain: true);
    }
    if (value['ok'] != true) {
      throw AdSubmissionFailure(
        '${value['code']}',
        paymentAttemptAbsent: platform == 'payments' &&
            op == 'prepare' &&
            response.statusCode == 409 &&
            value['ok'] == false &&
            value['uncertain'] == false &&
            value['attempt_created'] == false &&
            const {
              'AD_FASTPAY_UNAVAILABLE',
              'META_FASTPAY_UNAVAILABLE',
              'TIKTOK_DM_FASTPAY_UNAVAILABLE',
              'QUOTE_NOT_FOUND',
              'QUOTE_EXPIRED',
              'QUOTE_CHANGED',
              'CONNECTION_EXPIRED',
              'TIKTOK_ACCOUNT_UNAVAILABLE',
              'PRICE_CHANGED',
              'INVALID_PROMO',
              'RATE_LIMITED',
            }.contains(value['code']),
        uncertain: value['uncertain'] == true ||
            (op == 'submit' &&
                (value['ok'] != false ||
                    value['code'] is! String ||
                    (value['code'] as String).isEmpty ||
                    value['code'] == 'IDEMPOTENCY_CONFLICT')),
      );
    }
    return value;
  }

  String get _storageKey => 'proxo.pending-ad.v1.$_user';
  Map<String, dynamic> _map(dynamic raw) =>
      Map<String, dynamic>.from(raw as Map);

  @override
  Future<List<Map<String, dynamic>>> loadAssets() =>
      loadAssetsForType('contact');

  @override
  Future<List<Map<String, dynamic>>> loadAssetsForType(String pageKind) async {
    if (!const {'contact', 'order', 'download'}.contains(pageKind)) {
      throw const AdSubmissionFailure('INVALID_REQUEST');
    }
    final owner = _user;
    var query = client
        .from('proxolink_cards')
        .select(
          'id,name,template_key,template_version,style,color_theme,card_number,avatar_path,status,publish_status,page_kind,settings,platforms,moderation_status',
        )
        .eq('status', 'active')
        .eq('publish_status', 'ready')
        .eq('user_id', owner)
        .isFilter('archived_at', null);
    // Null is the explicit legacy Contact adapter, never a restaurant/app.
    query = pageKind == 'contact'
        ? query.or('page_kind.eq.contact,page_kind.is.null')
        : query.eq('page_kind', pageKind);
    final rows = await query
        .order('created_at', ascending: false)
        .timeout(const Duration(seconds: 20));
    if (_user != owner) throw const AdSubmissionFailure('UNAUTHORIZED');
    return [
      for (final row in rows)
        <String, dynamic>{
          ...row,
          if (row['avatar_path'] != null)
            'avatar_url': Uri.parse(BackendConfig.current.publicBase)
                .resolve(
                  '/${row['page_kind'] ?? 'contact'}/${row['id']}/avatar',
                )
                .toString(),
        },
    ];
  }

  @override
  Future<AdQuote> quote(AdDraft draft) async {
    if (draft.isTikTokDirect) {
      final j = await _tiktokCall('quote', {
        'ad': draft.toAd(),
        'promo_id': draft.promoId,
        'promo_code': draft.promoCode,
      });
      return AdQuote.fromJson({...j, 'tiktok_contract': j, 'days': draft.days});
    }
    if (draft.isMeta) {
      final j =
          await _metaCall('quote', {'configuration': draft.toMetaContract()});
      return AdQuote.fromJson({...j, 'meta_contract': j, 'days': draft.days});
    }
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
    final owner = _user, key = _storageKey;
    final raw = await _pendingStorage.run(owner, () async {
      final prefs = await SharedPreferences.getInstance();
      // Failed platform writes may still mutate the plugin's cache. Only
      // a durable read can establish that no unresolved request remains.
      await prefs.reload();
      return prefs.getString(key);
    }).timeout(const Duration(seconds: 10));
    if (client.auth.currentUser?.id != owner || raw == null) return null;
    final saved = _map(jsonDecode(raw));
    if (saved['resolution'] == 'definite_failure') return null;
    return AdPendingSubmission.fromJson(saved);
  }

  @override
  Future<String> submit(
      AdPendingSubmission request, ValueNotifier<AdPaymentProgress> progress) {
    if (request.draft.paymentMethod == 'fastpay' &&
        !request.draft.isMeta &&
        !request.draft.isTikTokDirect) {
      _backend.requireProductionTransport();
    }
    final user = _user;
    final active = _activeSubmissions[user];
    if (active != null) {
      return active.$1 == request.id
          ? active.$2
          : Future.error(const AdSubmissionFailure('IDEMPOTENCY_CONFLICT',
              uncertain: true));
    }
    _cancelledSubmissions.remove(request.id);
    final operation = _submit(request, progress, user).whenComplete(() {
      _activeSubmissions.remove(user);
      _cancelledSubmissions.remove(request.id);
    });
    _activeSubmissions[user] = (request.id, operation);
    return operation;
  }

  @override
  void cancelPendingOperation(String submissionId) {
    if (_activeSubmissions.values.any((active) => active.$1 == submissionId)) {
      _cancelledSubmissions.add(submissionId);
    }
  }

  void _checkCancellation(String submissionId) {
    if (_cancelledSubmissions.contains(submissionId)) {
      throw const AdSubmissionFailure('CANCELLED', uncertain: true);
    }
  }

  Future<String> _submit(AdPendingSubmission request,
      ValueNotifier<AdPaymentProgress> progress, String owner) async {
    void checkOwner() {
      if (client.auth.currentUser?.id != owner) {
        throw const AdSubmissionFailure('NOT_AUTHENTICATED', uncertain: true);
      }
    }

    final key = 'proxo.pending-ad.v1.$owner';
    var wasPending = false;
    final prefs = await _pendingStorage.run(owner, () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      checkOwner();
      final existing = prefs.getString(key);
      final saved = existing == null ? null : _map(jsonDecode(existing));
      wasPending = saved != null && saved['resolution'] != 'definite_failure';
      if (saved != null &&
          saved['resolution'] != 'definite_failure' &&
          AdPendingSubmission.fromJson(saved).id != request.id) {
        throw const AdSubmissionFailure('IDEMPOTENCY_CONFLICT',
            uncertain: true);
      }
      if (!await prefs.setString(key, jsonEncode(request.toJson()))) {
        await prefs.reload();
        throw AdSubmissionFailure('STORAGE_UNAVAILABLE', uncertain: wasPending);
      }
      return prefs;
    }).timeout(const Duration(seconds: 10));
    final telemetry = AppTelemetryService.active;
    final telemetryScope = telemetry?.sessionScope;
    String? paymentId;
    var submitting = false;
    var legacyPaymentMayExist = wasPending &&
        request.draft.paymentMethod == 'fastpay' &&
        !request.draft.isMeta &&
        !request.draft.isTikTokDirect;
    // A storage error after a confirmed server result must not turn success
    // into a failed financial operation. A stale record safely reconciles later.
    Future<bool> clearPending({bool definitiveFailure = false}) async {
      var marked = false;
      try {
        return await _pendingStorage.run(owner, () async {
          final raw = prefs.getString(key);
          // Only clear this completed identity, never a newer pending request.
          if (raw == null ||
              AdPendingSubmission.fromJson(_map(jsonDecode(raw))).id !=
                  request.id) {
            return true;
          }
          if (definitiveFailure) {
            // Persist the known outcome before deletion. If removal fails,
            // a restart must not restore a definitively rejected attempt.
            try {
              marked = await prefs.setString(
                key,
                jsonEncode({
                  ...request.toJson(),
                  'resolution': 'definite_failure',
                }),
              );
            } catch (_) {
              /* Try removal even if marking was unavailable. */
            }
          }
          var removed = false;
          try {
            removed = await prefs.remove(key);
          } catch (_) {
            /* A durable terminal marker is sufficient. */
          }
          if (!removed && !marked) {
            // SharedPreferences can mutate its memory cache even when the
            // platform write returns false. Restore the actual durable state.
            await prefs.reload();
          }
          return removed || marked;
        }).timeout(const Duration(seconds: 3));
      } catch (_) {
        debugPrint('Completed ad pending record cleanup deferred');
        return marked;
      }
    }

    try {
      checkOwner();
      // Recover a committed operation before checking dates or spending again.
      final recovered =
          _map(await client.rpc('pa_ad_submission_status', params: {
        'p_submission_id': request.id,
      }).timeout(const Duration(seconds: 20)));
      checkOwner();
      if (recovered['ok'] == true) {
        final adId = _acceptedAdId(recovered);
        await clearPending();
        AppDataCache.forClient(client).financialChanged();
        if (!request.draft.isMeta && !request.draft.isTikTokDirect) {
          _ensureThumbnail(adId);
        }
        return adId;
      }
      if (recovered['code'] != 'NOT_FOUND') {
        // A failed status lookup cannot prove that an earlier request failed.
        throw AdSubmissionFailure('${recovered['code']}', uncertain: true);
      }
      _checkCancellation(request.id);
      final automated = request.draft.isMeta || request.draft.isTikTokDirect;
      if (automated && request.draft.paymentMethod == 'fastpay') {
        // The server recovers an existing immutable attempt before checking
        // quote expiry, dates or flags. A verified payment also accepts the ad
        // and inserts its outbox atomically, including when this app is closed.
        final adId = await _payAutomatedAd(request, progress, owner);
        checkOwner();
        await clearPending();
        AppDataCache.forClient(client).financialChanged();
        return adId;
      }
      if (!automated && request.draft.paymentMethod == 'fastpay') {
        // Recover a previously created order before applying today's mutable
        // date/page checks. A paid order must reach the authoritative submit
        // transaction; an expired QR can still receive a late payment.
        final existingPayment = await _paymentRow(request.fastPayOrderId);
        checkOwner();
        if (existingPayment != null) {
          legacyPaymentMayExist = true;
          if (existingPayment['status'] == 'approved' &&
              '${existingPayment['gateway_status']}'.toUpperCase() == 'PAID' &&
              existingPayment['wallet_credited'] == true) {
            paymentId = await _payWithFastPay(request, progress, owner);
          }
        }
      }
      final trustedTime = automated ? await serverTime() : null;
      if (automated && trustedTime == null) {
        throw const AdSubmissionFailure('SERVER_TIME_UNAVAILABLE');
      }
      checkOwner();
      final errors = paymentId != null
          ? <String, String>{}
          : request.draft.validate(
              now: trustedTime == null
                  ? null
                  : adScheduleNow(instant: trustedTime));
      if (errors.isNotEmpty) {
        throw AdSubmissionFailure(
            errors.containsKey('schedule') ? 'INVALID_SCHEDULE' : 'INVALID_AD');
      }
      if (paymentId == null &&
          request.draft.hasTypedTikTokFlow &&
          !request.draft.isTikTokDirect &&
          request.draft.tiktokAdType != 'views') {
        final pageKind = switch (request.draft.tiktokAdType) {
          'restaurant' => 'order',
          'app_download' => 'download',
          _ => 'contact',
        };
        final eligible = await loadAssetsForType(pageKind);
        checkOwner();
        if (!eligible.any(
          (asset) => '${asset['id']}' == request.draft.assetId,
        )) {
          throw const AdSubmissionFailure('INVALID_ASSET');
        }
      }
      if (request.draft.isTikTokDirect) {
        if (request.draft.paymentMethod == 'fastpay') {
          paymentId = await _payWithFastPay(request, progress, owner);
        }
        checkOwner();
        _checkCancellation(request.id);
        progress.value = const AdPaymentProgress();
        submitting = true;
        final result = await _tiktokCall('submit', {
          'submission_id': request.id,
          'ad': request.draft.toAd(),
          'quote_id': request.quote.tiktokContract?['quote_id'],
          'expected_cost_usd': request.quote.costUsd,
          'expected_price_iqd': request.quote.totalIqd,
          'promo_id': request.draft.promoId,
          'promo_code': request.draft.promoCode,
          if (paymentId != null) 'payment_transaction_id': paymentId,
        });
        checkOwner();
        final adId = _acceptedAdId(result);
        await clearPending();
        AppDataCache.forClient(client).financialChanged();
        return adId;
      }
      if (request.draft.isMeta) {
        // Recovery above is deliberately first: flags/quotes may have expired.
        if (request.draft.paymentMethod == 'fastpay') {
          paymentId = await _payWithFastPay(request, progress, owner);
        }
        checkOwner();
        _checkCancellation(request.id);
        progress.value = const AdPaymentProgress();
        submitting = true;
        final result = await _metaCall('submit', {
          'submission_id': request.id,
          'configuration': request.draft.toMetaContract(),
          'quote_id': request.quote.metaContract?['quote_id'],
          'expected_total_iqd': request.quote.totalIqd,
          'expected_total_minor': (request.quote.costUsd * 100).round(),
          if (paymentId != null) 'payment_transaction_id': paymentId,
        });
        checkOwner();
        final adId = _acceptedAdId(result);
        await clearPending();
        AppDataCache.forClient(client).financialChanged();
        return adId;
      }
      if (request.draft.paymentMethod == 'fastpay' && paymentId == null) {
        legacyPaymentMayExist = true;
        paymentId = await _payWithFastPay(request, progress, owner);
      }
      checkOwner();
      _checkCancellation(request.id);
      progress.value = const AdPaymentProgress();
      submitting = true;
      final result = _map(await client.rpc('pa_submit_ad', params: {
        'p_submission_id': request.id,
        'p_ad': {...request.draft.toAd(), 'payment_transaction_id': paymentId},
        'p_expected_cost_usd': request.quote.costUsd,
        'p_expected_price_iqd': request.quote.totalIqd,
        'p_promo_id': request.draft.promoId,
        'p_promo_code': request.draft.promoCode,
      }).timeout(const Duration(seconds: 30)));
      checkOwner();
      if (result['ok'] != true) {
        throw AdSubmissionFailure(
          '${result['code']}',
          uncertain: result['ok'] != false ||
              result['uncertain'] == true ||
              result['code'] is! String ||
              (result['code'] as String).isEmpty ||
              result['code'] == 'IDEMPOTENCY_CONFLICT',
        );
      }
      final adId = _acceptedAdId(result);
      await clearPending();
      AppDataCache.forClient(client).financialChanged();
      telemetry?.event('action', 'ad_submit',
          outcome: 'success', expectedScope: telemetryScope);
      _ensureThumbnail(adId);
      return adId;
    } on AdSubmissionFailure catch (e) {
      telemetry?.event('action', 'ad_submit',
          outcome: 'failure', expectedScope: telemetryScope);
      if (!e.uncertain && legacyPaymentMayExist && paymentId == null) {
        // An existing or interrupted payment order has no final financial
        // outcome yet. Keep its identity even if the current form is invalid.
        throw AdSubmissionFailure(e.code, uncertain: true);
      }
      if (!e.uncertain && !await clearPending(definitiveFailure: true)) {
        throw AdSubmissionFailure(
          'STORAGE_UNAVAILABLE',
          uncertain: true,
          paymentCredited: paymentId != null,
        );
      }
      if (!e.uncertain && paymentId != null) {
        throw AdSubmissionFailure(e.code, paymentCredited: true);
      }
      rethrow;
    } on PostgrestException catch (error) {
      // Only explicit validation / transaction rollback errors prove rejection.
      // Connection errors (08xxx), 40003 and unknown gateway codes can arrive
      // after a commit; those MUST retain the same identity for reconciliation.
      final sqlState = error.code ?? '';
      final definiteRejection =
          const {'22', '23', '42'}.any(sqlState.startsWith) ||
              const {'0A000', 'P0001', 'P0002', 'P0003', '40001', '40P01'}
                  .contains(sqlState);
      if (submitting && definiteRejection) {
        if (!await clearPending(definitiveFailure: true)) {
          throw AdSubmissionFailure(
            'STORAGE_UNAVAILABLE',
            uncertain: true,
            paymentCredited: paymentId != null,
          );
        }
        const knownCodes = {
          'NOT_AUTHENTICATED',
          'INSUFFICIENT_FUNDS',
          'INVALID_PROMO',
          'INVALID_SCHEDULE',
          'INVALID_ASSET',
          'PRICE_CHANGED',
        };
        throw AdSubmissionFailure(
            knownCodes.contains(error.message)
                ? error.message
                : 'SERVER_REJECTED',
            paymentCredited: paymentId != null);
      }
      throw const AdSubmissionFailure('NETWORK', uncertain: true);
    } catch (_) {
      // Keep the SAME id and frozen payload on timeout, disconnect or app kill.
      throw const AdSubmissionFailure('NETWORK', uncertain: true);
    }
  }

  String _acceptedAdId(Map<String, dynamic> result) {
    final id = result['ad_id'];
    if (id is! String || id.trim().isEmpty) {
      throw const AdSubmissionFailure('NETWORK', uncertain: true);
    }
    return id;
  }

  void _ensureThumbnail(String adId) {
    unawaited(client.functions
        .invoke('generate-ad-thumbnail', body: {'ad_id': adId}).then<void>(
            (_) {}, onError: (Object e, StackTrace s) {
      debugPrint('Ad thumbnail generation deferred: ${e.runtimeType}');
    }));
  }

  Future<String> _payAutomatedAd(AdPendingSubmission request,
      ValueNotifier<AdPaymentProgress> progress, String owner) async {
    void checkOwner() {
      if (client.auth.currentUser?.id != owner) {
        throw const AdSubmissionFailure('NOT_AUTHENTICATED', uncertain: true);
      }
    }

    bool closedBeforePayment(Map<String, dynamic> attempt,
        {String? expectedId}) =>
        attempt['ok'] == true &&
        attempt['payment_not_started'] == true &&
        attempt['uncertain'] == false &&
        const ['cancelled', 'expired'].contains(attempt['status']) &&
        attempt['attempt_id'] is String &&
        (attempt['attempt_id'] as String).isNotEmpty &&
        (expectedId == null || attempt['attempt_id'] == expectedId) &&
        attempt['currency'] == 'IQD' &&
        num.tryParse('${attempt['amount_iqd']}') == request.quote.totalIqd &&
        attempt['environment'] ==
            (_backend.isStaging ? 'sandbox' : 'production') &&
        attempt['qr_url'] == null &&
        attempt['qr_text'] == null &&
        attempt['ad_id'] == null &&
        attempt['result'] == null;

    checkOwner();
    _checkCancellation(request.id);
    progress.value =
        const AdPaymentProgress(message: 'پارەدانی FastPay ئامادە دەکرێت…');
    // Once an attempt exists, all interrupted reads retain the same frozen
    // request. An expired QR is not proof that a late payment cannot arrive.
    try {
      var attempt = await _paymentCall('prepare', {
        'submission_id': request.id,
        'platform': request.draft.isMeta ? 'META' : 'TIKTOK',
        'quote_id': (request.draft.isMeta
            ? request.quote.metaContract
            : request.quote.tiktokContract)?['quote_id'],
        'expected_cost_usd': request.quote.costUsd,
        'expected_amount_iqd': request.quote.totalIqd,
      });
      final deadline = DateTime.now().add(const Duration(minutes: 11));
      while (true) {
        checkOwner();
        if (attempt['currency'] != 'IQD' ||
            num.tryParse('${attempt['amount_iqd']}') !=
                request.quote.totalIqd ||
            attempt['environment'] !=
                (_backend.isStaging ? 'sandbox' : 'production')) {
          throw const AdSubmissionFailure('PAYMENT_ATTEMPT_MISMATCH',
              uncertain: true);
        }
        final status = '${attempt['status']}';
        if (closedBeforePayment(attempt)) {
          throw const AdSubmissionFailure('FASTPAY_NOT_STARTED',
              paymentAttemptClosedUnstarted: true);
        }
        if (status == 'funded' || status == 'compensated') {
          final result = attempt['result'];
          final adId = result is Map ? result['ad_id'] : attempt['ad_id'];
          if (adId is! String || adId.trim().isEmpty) {
            throw const AdSubmissionFailure('FASTPAY_WAIT', uncertain: true);
          }
          return adId;
        }
        if (_cancelledSubmissions.contains(request.id)) {
          final attemptId = attempt['attempt_id'];
          if (attemptId is String && attemptId.isNotEmpty) {
            final cancelled =
                await _paymentCall('cancel', {'attempt_id': attemptId});
            checkOwner();
            if (closedBeforePayment(cancelled, expectedId: attemptId)) {
              throw const AdSubmissionFailure('CANCELLED',
                  paymentAttemptClosedUnstarted: true);
            }
          }
          throw const AdSubmissionFailure('CANCELLED', uncertain: true);
        }
        if (const ['expired', 'declined', 'cancelled'].contains(status) ||
            !DateTime.now().isBefore(deadline)) {
          throw const AdSubmissionFailure('FASTPAY_WAIT', uncertain: true);
        }
        final orderId = attempt['order_id'];
        final qr = attempt['qr_text'];
        progress.value = AdPaymentProgress(
          message: 'پارەدان بکە؛ پشتڕاستکردنەوە بە خۆکارە',
          waitingForPayment: true,
          qrUrl: attempt['qr_url'] as String?,
          deepLink: qr is String && qr.isNotEmpty && orderId is String
              ? 'appFpp://fast-pay.cash/qrpay'
                  '?qrdata=${Uri.encodeQueryComponent(qr)}&clientUri=appfpclientProxo'
                  '&transactionId=${Uri.encodeQueryComponent(orderId)}'
              : null,
        );
        await Future<void>.delayed(const Duration(seconds: 3));
        checkOwner();
        // Poll only our server. Its trusted gateway validation and durable
        // worker own settlement; Flutter never marks paid or submits again.
        attempt = await _paymentCall('status', {'submission_id': request.id});
      }
    } on AdSubmissionFailure catch (error) {
      if (error.paymentAttemptAbsent || error.paymentAttemptClosedUnstarted) {
        rethrow;
      }
      throw AdSubmissionFailure(error.code, uncertain: true);
    }
  }

  Future<String> _payWithFastPay(AdPendingSubmission r,
      ValueNotifier<AdPaymentProgress> progress, String owner) async {
    _backend.requireProductionTransport();
    void checkOwner() {
      if (client.auth.currentUser?.id != owner) {
        throw const AdSubmissionFailure('NOT_AUTHENTICATED', uncertain: true);
      }
    }

    checkOwner();
    _checkCancellation(r.id);
    if (r.quote.totalIqd < 1000) {
      throw const AdSubmissionFailure('AMOUNT_TOO_SMALL');
    }
    const base = 'https://email.proxopages.com/webhook/fastpay';
    final orderId = r.fastPayOrderId;
    Map<String, dynamic>? row = await _paymentRow(orderId);
    checkOwner();
    if (row == null) {
      _checkCancellation(r.id);
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
                  if (r.draft.isMeta) ...{
                    'platform': 'META',
                    'quote_id': r.quote.metaContract?['quote_id'],
                    'configuration': r.quote.metaContract?['configuration'] ??
                        r.draft.toMetaContract(),
                  },
                  if (r.draft.isTikTokDirect) ...{
                    'platform': 'TIKTOK',
                    'message_destination': 'direct_message',
                    'tiktok_quote_id': r.quote.tiktokContract?['quote_id'],
                  },
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
        throw const AdSubmissionFailure('PRICE_CHANGED', uncertain: true);
      }
      row = await _paymentRow(orderId);
    }
    final deadline = DateTime.now().add(const Duration(minutes: 11));
    while (DateTime.now().isBefore(deadline)) {
      checkOwner();
      _checkCancellation(r.id);
      row ??= await _paymentRow(orderId);
      checkOwner();
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
          throw const AdSubmissionFailure('FASTPAY_WAIT', uncertain: true);
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
      checkOwner();
      _checkCancellation(r.id);
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
          .maybeSingle()
          .timeout(const Duration(seconds: 20));
}
