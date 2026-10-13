import '../main.dart' show supabase;

import 'ad_categories.dart';

class BestMetricAd {
  final String id;
  final String goal;
  final String category;
  final String? videoLink;
  final String? thumbnailUrl;
  final int clicks;
  final int impressions;
  final double spendUsd;
  final double dailyBudgetUsd;
  final int days;
  final double serviceBudgetUsd;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime weekStart;

  const BestMetricAd({
    required this.id,
    required this.goal,
    required this.category,
    required this.videoLink,
    required this.thumbnailUrl,
    required this.clicks,
    required this.impressions,
    required this.spendUsd,
    required this.dailyBudgetUsd,
    required this.days,
    required this.serviceBudgetUsd,
    required this.sortOrder,
    required this.createdAt,
    required this.weekStart,
  });

  double get originalBudgetUsd {
    if (serviceBudgetUsd > 0) return serviceBudgetUsd;
    return dailyBudgetUsd * days;
  }

  bool get hasPlayableVideo {
    final uri = Uri.tryParse(videoLink ?? '');
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  factory BestMetricAd.fromMap(Map<String, dynamic> map) {
    return BestMetricAd(
      id: _text(map['id']),
      goal: _text(map['goal'], fallback: 'views'),
      category: isSupportedAdCategory(_text(map['category']))
          ? _text(map['category'])
          : 'other',
      videoLink: _nullableText(map['video_link']),
      thumbnailUrl: _nullableText(map['thumbnail_url']),
      clicks: _int(map['clicks']),
      impressions: _int(map['impressions']),
      spendUsd: _double(map['spend']),
      dailyBudgetUsd: _double(map['daily_budget']),
      days: _int(map['days'], fallback: 1),
      serviceBudgetUsd: _double(map['service_budget_usd']),
      sortOrder: _int(map['featured_sort'], fallback: 999),
      createdAt: DateTime.tryParse(_text(map['created_at'])),
      weekStart: DateTime.tryParse(_text(map['featured_week_start'])) ??
          BestMetricsService.currentBaghdadWeekStart(),
    );
  }

  static String _text(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String? _nullableText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static int _int(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class BestMetricsService {
  BestMetricsService._();

  static const Duration _cacheTtl = Duration(minutes: 10);
  static const int homePreviewLimit = 5;

  static String? _previewCacheWeek;
  static DateTime? _previewCachedAt;
  static List<BestMetricAd>? _cachedPreviewAds;

  static String? _cacheWeek;
  static DateTime? _cachedAt;
  static List<BestMetricAd>? _cachedAds;

  static DateTime currentBaghdadWeekStart() {
    final baghdadNow = DateTime.now().toUtc().add(const Duration(hours: 3));
    final day = DateTime(baghdadNow.year, baghdadNow.month, baghdadNow.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  static String _dateKey(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return value.year.toString() +
        '-' +
        two(value.month) +
        '-' +
        two(value.day);
  }

  /// Lightweight query used only by Home. It deliberately requests a maximum
  /// of five rows so the complete weekly list is not downloaded or built while
  /// the user is scrolling the dashboard.
  static Future<List<BestMetricAd>> fetchHomePreview({
    bool forceRefresh = false,
  }) async {
    final weekStart = currentBaghdadWeekStart();
    final weekKey = _dateKey(weekStart);
    final cacheIsFresh = !forceRefresh &&
        _cachedPreviewAds != null &&
        _previewCacheWeek == weekKey &&
        _previewCachedAt != null &&
        DateTime.now().difference(_previewCachedAt!) < _cacheTtl;
    if (cacheIsFresh) {
      return List<BestMetricAd>.unmodifiable(_cachedPreviewAds!);
    }

    final raw = await supabase
        .from('pa_featured_ads_public')
        .select(
          'id,goal,category,video_link,thumbnail_url,clicks,impressions,'
          'spend,daily_budget,days,service_budget_usd,featured_sort,'
          'created_at,featured_week_start,is_featured',
        )
        .eq('is_featured', true)
        .eq('featured_week_start', weekKey)
        .order('featured_sort', ascending: true)
        .order('impressions', ascending: false)
        .limit(homePreviewLimit);

    final rows = _parseRows(raw);
    _previewCacheWeek = weekKey;
    _previewCachedAt = DateTime.now();
    _cachedPreviewAds = rows;
    return List<BestMetricAd>.unmodifiable(rows);
  }

  static Future<List<BestMetricAd>> fetchWeeklyResults({
    bool forceRefresh = false,
  }) async {
    final weekStart = currentBaghdadWeekStart();
    final weekKey = _dateKey(weekStart);
    final cacheIsFresh = !forceRefresh &&
        _cachedAds != null &&
        _cacheWeek == weekKey &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _cacheTtl;
    if (cacheIsFresh) return List<BestMetricAd>.unmodifiable(_cachedAds!);

    final raw = await supabase
        .from('pa_featured_ads_public')
        .select(
          'id,goal,category,video_link,thumbnail_url,clicks,impressions,'
          'spend,daily_budget,days,service_budget_usd,featured_sort,'
          'created_at,featured_week_start,is_featured',
        )
        .eq('is_featured', true)
        .eq('featured_week_start', weekKey)
        .order('featured_sort', ascending: true)
        .order('impressions', ascending: false)
        .limit(100);

    final rows = _parseRows(raw);

    _cacheWeek = weekKey;
    _cachedAt = DateTime.now();
    _cachedAds = rows;
    return List<BestMetricAd>.unmodifiable(rows);
  }

  static List<BestMetricAd> _parseRows(dynamic raw) {
    return (raw as List)
        .map((row) => BestMetricAd.fromMap(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList(growable: false);
  }

  static void invalidateCache() {
    _previewCacheWeek = null;
    _previewCachedAt = null;
    _cachedPreviewAds = null;
    _cacheWeek = null;
    _cachedAt = null;
    _cachedAds = null;
  }
}
