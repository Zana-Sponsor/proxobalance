import 'dart:async';

import 'package:flutter/material.dart';
import 'package:solar_iconkit/solar_iconkit.dart';

import '../theme/app_theme.dart' show kAppFont;
import '../services/ad_categories.dart';
import '../services/best_metrics_service.dart';
import '../widgets/best_metric_card.dart';

const Color _page = Colors.white;
const Color _ink = Color(0xFF0B0B32);
const Color _muted = Color(0xFF5D6677);
const Color _accent = Color(0xFF0365FF);
const Color _line = Color(0xFFE6EAF0);
const List<BoxShadow> _softCardShadow = <BoxShadow>[
  BoxShadow(
    color: Color(0x0F000000),
    blurRadius: 18,
    offset: Offset(0, 5),
  ),
];

class BestMetricsScreen extends StatefulWidget {
  final List<BestMetricAd> initialAds;
  final String? initialAdId;

  const BestMetricsScreen({
    super.key,
    this.initialAds = const <BestMetricAd>[],
    this.initialAdId,
  });

  @override
  State<BestMetricsScreen> createState() => _BestMetricsScreenState();
}

class _BestMetricsScreenState extends State<BestMetricsScreen> {
  List<BestMetricAd> _ads = const <BestMetricAd>[];
  String _category = 'all';
  String? _expandedId;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _ads = widget.initialAds;
    _expandedId = widget.initialAdId;
    _loading = _ads.isEmpty;
    unawaited(_load());
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (mounted && _ads.isEmpty) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final rows = await BestMetricsService.fetchWeeklyResults(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _ads = rows;
        _loading = false;
        _error = null;
        if (_expandedId != null &&
            !_ads.any((ad) => ad.id == _expandedId)) {
          _expandedId = null;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  List<BestMetricAd> get _filteredAds {
    if (_category == 'all') return _ads;
    return _ads.where((ad) => ad.category == _category).toList(growable: false);
  }

  void _selectCategory(String value) {
    if (_category == value) return;
    setState(() {
      _category = value;
      if (_expandedId != null &&
          !_filteredAds.any((ad) => ad.id == _expandedId)) {
        _expandedId = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredAds;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _page,
        body: SafeArea(
          child: Column(
            children: [
              _Header(onBack: () => Navigator.of(context).maybePop()),
              if (_ads.isNotEmpty) _CategoryFilter(
                value: _category,
                onChanged: _selectCategory,
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _loading && _ads.isEmpty
                      ? const _LoadingView(key: ValueKey('loading'))
                      : _error != null && _ads.isEmpty
                          ? _ErrorView(
                              key: const ValueKey('error'),
                              onRetry: () => _load(forceRefresh: true),
                            )
                          : filtered.isEmpty
                              ? const _EmptyView(key: ValueKey('empty'))
                              : RefreshIndicator(
                                  key: const ValueKey('list'),
                                  color: _accent,
                                  onRefresh: () => _load(forceRefresh: true),
                                  child: ListView.separated(
                                    physics: const AlwaysScrollableScrollPhysics(
                                      parent: BouncingScrollPhysics(),
                                    ),
                                    cacheExtent: 900,
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      8,
                                      16,
                                      28,
                                    ),
                                    itemCount: filtered.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 14),
                                    itemBuilder: (context, index) {
                                      final ad = filtered[index];
                                      final rank =
                                          _ads.indexWhere((row) => row.id == ad.id) + 1;
                                      return BestMetricCard(
                                        key: ValueKey(ad.id),
                                        ad: ad,
                                        rank: rank,
                                        expanded: _expandedId == ad.id,
                                        onToggleExpanded: () {
                                          setState(() {
                                            _expandedId =
                                                _expandedId == ad.id ? null : ad.id;
                                          });
                                        },
                                      );
                                    },
                                  ),
                                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;

  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'گەڕانەوە',
            onPressed: onBack,
            icon: const SolarIcon(
              SolarIcons.altArrowRight,
              style: SolarIconStyle.linear,
              size: 22,
              color: _ink,
              matchTextDirection: true,
            ),
          ),
          const SizedBox(width: 4),
          const SolarIcon(
            SolarIcons.medalStar,
            style: SolarIconStyle.linear,
            size: 22,
            color: Color(0xFFE19A13),
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Text(
              'باشترین ئەنجامەکانی هەفتە',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: kAppFont,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _CategoryFilter({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = <AdCategoryOption>[
      const AdCategoryOption('all', 'هەموو'),
      ...kAdCategories,
    ];
    return Container(
      height: 58,
      color: Colors.white,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = options[index];
          final selected = option.slug == value;
          return ChoiceChip(
            label: Text(option.label),
            selected: selected,
            showCheckmark: false,
            onSelected: (_) => onChanged(option.slug),
            backgroundColor: const Color(0xFFF7F9FC),
            selectedColor: const Color(0xFFEAF2FF),
            side: BorderSide(
              color: selected ? _accent : _line,
              width: selected ? 1.2 : 1,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            labelStyle: TextStyle(
              fontFamily: kAppFont,
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? _accent : _muted,
            ),
          );
        },
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: _accent,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorView({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _line),
            boxShadow: _softCardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SolarIcon(
                SolarIcons.dangerTriangle,
                style: SolarIconStyle.linear,
                size: 28,
                color: Color(0xFFE5484D),
              ),
              const SizedBox(height: 10),
              const Text(
                'ئەنجامەکان بار نەبوون',
                style: TextStyle(
                  fontFamily: kAppFont,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: onRetry,
                child: const Text(
                  'دووبارە هەوڵ بدەرەوە',
                  style: TextStyle(fontFamily: kAppFont),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'لەو بەشەدا هیچ ئەنجامێک نییە',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: kAppFont,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: _muted,
          ),
        ),
      ),
    );
  }
}
