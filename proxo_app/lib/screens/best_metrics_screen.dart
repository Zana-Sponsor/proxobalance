import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/proxo_strings.dart';
import '../theme/app_locale.dart';
import '../services/ad_categories.dart';
import '../services/best_metrics_service.dart';
import '../widgets/best_metric_card.dart';
import '../widgets/best_results_design.dart';
import '../widgets/proxo_app_bar.dart';
import '../widgets/proxo_refresh.dart';
import '../widgets/proxo_text.dart';

typedef ResultsLoader = Future<List<BestMetricAd>> Function({
  bool forceRefresh,
});

class BestMetricsScreen extends StatefulWidget {
  const BestMetricsScreen({
    super.key,
    this.initialAds = const [],
    this.initialAdId,
    this.loadResults,
  });
  final List<BestMetricAd> initialAds;
  final String? initialAdId;
  final ResultsLoader? loadResults;
  @override
  State<BestMetricsScreen> createState() => _BestMetricsScreenState();
}

class _BestMetricsScreenState extends State<BestMetricsScreen> {
  List<BestMetricAd> _ads = const [];
  String _category = 'all';
  String? _anchorId;
  bool _loading = true;
  Object? _error;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _ads = widget.initialAds;
    _anchorId = widget.initialAdId;
    _loading = _ads.isEmpty;
    unawaited(_load());
  }

  Future<void> _load({bool forceRefresh = false}) async {
    final request = ++_request;
    if (_ads.isEmpty)
      setState(() {
        _loading = true;
        _error = null;
      });
    try {
      final rows =
          await (widget.loadResults ?? BestMetricsService.fetchWeeklyResults)(
            forceRefresh: forceRefresh,
          );
      if (!mounted || request != _request) return;
      setState(() {
        _ads = rows;
        _loading = false;
        _error = null;
        if (!_ads.any((ad) => ad.id == _anchorId)) _anchorId = null;
        if (_category != 'all' && !_ads.any((ad) => ad.category == _category))
          _category = 'all';
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    final filtered = _category == 'all'
        ? _ads
        : _ads.where((ad) => ad.category == _category).toList();
    final titleStyle = ResultsUi.text(size: 16);
    final titlePainter = TextPainter(
      text: TextSpan(
        text: ProxoStrings.text('باشترین ئەنجامەکان'),
        style: titleStyle,
      ),
      textDirection: TextDirection.rtl,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: math.max(80, MediaQuery.sizeOf(context).width - 144));
    final toolbarHeight = math.max(64.0, titlePainter.height + 20);
    titlePainter.dispose();
    return Theme(
      data: ResultsUi.theme(context),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFFF8F9FB),
          appBar: ProxoAppBar(
            title: 'باشترین ئەنجامەکان',
            titleStyle: titleStyle,
            titleMaxLines: null,
            toolbarHeight: toolbarHeight,
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                if (_ads.isNotEmpty) _categories(),
                if (_error != null && _ads.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _load(forceRefresh: true),
                    icon: const ResultIcon('refresh', size: 18),
                    label: ProxoText(
                      'ئەنجامەکان بار نەبوون',
                      translate: true,
                      style: ResultsUi.text(color: ResultsUi.muted),
                    ),
                  ),
                Expanded(
                  child: _loading && _ads.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : filtered.isEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) =>
                              SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: ResultsStateCard(
                                      error: _error != null,
                                      onRefresh: () =>
                                          _load(forceRefresh: true),
                                    ),
                                  ),
                                ),
                              ),
                        )
                      : _results(filtered),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _categories() => ColoredBox(
    color: Colors.white,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          for (final option in [
            const AdCategoryOption('all', 'هەموو'),
            ...kAdCategories,
          ])
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                selected: option.slug == _category,
                showCheckmark: false,
                onSelected: (_) => setState(() {
                  _category = option.slug;
                  _anchorId = null;
                }),
                selectedColor: const Color(0xFFEAF2FF),
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                side: BorderSide(
                  color: option.slug == _category
                      ? ResultsUi.blue.withValues(alpha: .35)
                      : ResultsUi.line,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                label: ProxoText(
                  option.label,
                  translate: true,
                  style: ResultsUi.text(
                    size: 13,
                    color: option.slug == _category
                        ? ResultsUi.blue
                        : ResultsUi.muted,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _results(List<BestMetricAd> rows) {
    // Anchor the tapped card without estimating pixel heights or eagerly building
    // earlier cards. The preceding sliver remains reachable by scrolling back.
    final inset = math.max(16.0, (MediaQuery.sizeOf(context).width - 600) / 2);
    final selected = math.max(0, rows.indexWhere((ad) => ad.id == _anchorId));
    final center = ValueKey('results-anchor-$_category-$_anchorId');
    Widget card(BestMetricAd ad) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: BestMetricCard(
        key: ValueKey('result-${ad.id}'),
        ad: ad,
        rank: _ads.indexWhere((row) => row.id == ad.id) + 1,
        expanded: ad.id == _anchorId,
      ),
    );
    return ProxoRefresh(
      pullToRefresh: true,
      onRefresh: () => _load(forceRefresh: true),
      child: CustomScrollView(
        key: center,
        center: center,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        cacheExtent: 500,
        slivers: [
          if (selected > 0)
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: inset),
              sliver: SliverList.builder(
                itemCount: selected,
                itemBuilder: (_, i) => card(rows[selected - 1 - i]),
              ),
            ),
          SliverPadding(
            key: center,
            padding: EdgeInsets.fromLTRB(inset, 16, inset, 24),
            sliver: SliverList.builder(
              itemCount: rows.length - selected,
              itemBuilder: (_, i) => card(rows[selected + i]),
            ),
          ),
        ],
      ),
    );
  }
}
