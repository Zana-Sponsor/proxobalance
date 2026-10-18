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
      weekStart:
          DateTime.tryParse(_text(map['featured_week_start'])) ??
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

typedef FeaturedPageLoader = Future<List<BestMetricAd>> Function(
  String week,
  int offset,
  int limit,
);

/// One bounded, immutable in-memory snapshot shared by Home and Results.
/// Requests coalesce; invalidated/previous-week responses cannot replace it.
class BestMetricsRepository {
  BestMetricsRepository({required this.loadPage, DateTime Function()? now})
    : now = now ?? DateTime.now;
  final FeaturedPageLoader loadPage;
  final DateTime Function() now;
  static const ttl = Duration(minutes: 10);
  static const pageSize = 100;
  List<BestMetricAd>? _rows;
  String? _week;
  DateTime? _savedAt;
  Future<List<BestMetricAd>>? _pending;
  String? _pendingWeek;
  int _generation = 0;

  static DateTime weekStart(DateTime instant) {
    final local = instant.toUtc().add(const Duration(hours: 3));
    final day = DateTime.utc(local.year, local.month, local.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  Future<List<BestMetricAd>> fetch({bool forceRefresh = false}) {
    final clock = now();
    final week = weekStart(clock).toIso8601String().substring(0, 10);
    if (!forceRefresh &&
        _week == week &&
        _rows != null &&
        _savedAt != null &&
        clock.difference(_savedAt!) < ttl)
      return Future.value(_rows);
    if (_pending != null && _pendingWeek == week) return _pending!;
    final generation = ++_generation;
    _pendingWeek = week;
    final request = _readAll(week)
        .then((rows) {
          if (generation == _generation) {
            _rows = rows;
            _week = week;
            _savedAt = now();
          }
          return rows;
        })
        .whenComplete(() {
          if (generation == _generation) {
            _pending = null;
            _pendingWeek = null;
          }
        });
    _pending = request;
    return request;
  }

  Future<List<BestMetricAd>> _readAll(String week) async {
    final rows = <String, BestMetricAd>{};
    for (var offset = 0; ; offset += pageSize) {
      final page = await loadPage(week, offset, pageSize);
      for (final ad in page) {
        rows[ad.id] = ad;
      }
      if (page.length < pageSize) break;
    }
    return List<BestMetricAd>.unmodifiable(rows.values);
  }

  void invalidate() {
    _generation++;
    _rows = null;
    _week = null;
    _savedAt = null;
    _pending = null;
    _pendingWeek = null;
  }
}

class BestMetricsService {
  BestMetricsService._();
  static final _repository = BestMetricsRepository(loadPage: _loadPage);
  static DateTime currentBaghdadWeekStart() =>
      BestMetricsRepository.weekStart(DateTime.now());

  static Future<List<BestMetricAd>> fetchHomePreview({
    bool forceRefresh = false,
  }) => _repository.fetch(forceRefresh: forceRefresh);
  static Future<List<BestMetricAd>> fetchWeeklyResults({
    bool forceRefresh = false,
  }) => _repository.fetch(forceRefresh: forceRefresh);

  static Future<List<BestMetricAd>> _loadPage(
    String week,
    int offset,
    int limit,
  ) async {
    final raw = await supabase
        .from('pa_featured_ads_public')
        .select(
          'id,goal,category,video_link,thumbnail_url,clicks,impressions,'
          'spend,daily_budget,days,service_budget_usd,featured_sort,'
          'created_at,featured_week_start,is_featured',
        )
        .eq('is_featured', true)
        .eq('featured_week_start', week)
        .order('featured_sort', ascending: true)
        .order('impressions', ascending: false)
        .order('id')
        .range(offset, offset + limit - 1);
    return raw.map((row) => BestMetricAd.fromMap(row)).toList(growable: false);
  }

  static void invalidateCache() => _repository.invalidate();
}
