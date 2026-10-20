import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../screens/best_metrics_screen.dart';
import '../services/best_metrics_service.dart';
import '../theme/proxo_ui.dart';
import '../theme/app_theme.dart';
import 'package:solar_iconkit/solar_iconkit.dart';
import 'best_metric_card.dart';
import 'proxo_text.dart';

typedef HomeResultsLoader = Future<List<BestMetricAd>> Function({
  bool forceRefresh,
});

class BestMetricsHomeSection extends StatefulWidget {
  final HomeResultsLoader? loadPreview;
  const BestMetricsHomeSection({super.key, this.loadPreview});
  @override
  State<BestMetricsHomeSection> createState() => BestMetricsHomeSectionState();
}

class BestMetricsHomeSectionState extends State<BestMetricsHomeSection> {
  final PageController _pageController = PageController(viewportFraction: 0.94);
  final Map<String, double> _cardHeights = {};
  double? _layoutWidth;
  TextScaler? _textScaler;
  List<BestMetricAd> _ads = const <BestMetricAd>[];
  bool _loading = true;
  Object? _error;
  int _page = 0;
  Future<void>? _pendingRefresh;
  bool _detailsOpen = false;
  @override
  void initState() {
    super.initState();
    unawaited(refresh());
  }

  Future<void> refresh({bool forceRefresh = true}) => _pendingRefresh ??=
      _loadPreview(forceRefresh: forceRefresh).whenComplete(() => _pendingRefresh = null);

  Future<void> _loadPreview({required bool forceRefresh}) async {
    if (mounted && _ads.isEmpty) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final rows =
          await (widget.loadPreview ?? BestMetricsService.fetchHomePreview)(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      final resetPage = _page >= rows.length;
      setState(() {
        _ads = rows;
        _loading = false;
        _error = null;
        _cardHeights.removeWhere((id, _) => !rows.any((ad) => ad.id == id));
        if (resetPage) _page = 0;
      });
      if (resetPage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients) {
            _pageController.jumpToPage(0);
          }
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  void _openAll({String? initialAdId}) {
    if (_detailsOpen) return;
    _detailsOpen = true;
    Navigator.of(context).push(ProxoPageRoute<void>(
      builder: (_) =>
          BestMetricsScreen(initialAds: _ads, initialAdId: initialAdId),
    )).whenComplete(() => _detailsOpen = false);
  }

  void _recordHeight(String id, Size size) {
    if (!mounted || ((_cardHeights[id] ?? 0) - size.height).abs() < 0.1) return;
    setState(() => _cardHeights[id] = size.height);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionHeader(canOpen: _ads.isNotEmpty, onOpen: _openAll),
                const SizedBox(height: ProxoUi.gap12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _loading && _ads.isEmpty
                      ? const _HomeLoading(key: ValueKey('loading'))
                      : _error != null && _ads.isEmpty
                          ? _HomeError(
                              key: const ValueKey('error'),
                              onRetry: () => refresh(),
                            )
                          : _ads.isEmpty
                              ? const _HomeEmpty(key: ValueKey('empty'))
                              : _carousel(),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _carousel() => LayoutBuilder(
        key: const ValueKey('content'),
        builder: (context, constraints) {
          final scaler = MediaQuery.textScalerOf(context);
          if (_layoutWidth != constraints.maxWidth || _textScaler != scaler) {
            _layoutWidth = constraints.maxWidth;
            _textScaler = scaler;
            _cardHeights.clear();
          }
          final height = _cardHeights[_ads[_page].id] ?? 270.0;
          return Column(
            children: [
              SizedBox(
                height: height,
                child: PageView.builder(
                  key: const ValueKey('home-results-carousel'),
                  controller: _pageController,
                  clipBehavior: Clip.hardEdge,
                  padEnds: false,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _ads.length,
                  onPageChanged: (value) {
                    if (mounted) setState(() => _page = value);
                  },
                  itemBuilder: (context, index) {
                    final ad = _ads[index];
                    // Measure the actual unbounded card rather than truncate scaled
                    // text to a fixed carousel height. The outer Home scroll stays in charge.
                    return SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: _CardSizeObserver(
                        onSize: (size) => _recordHeight(ad.id, size),
                        child: Padding(
                          // Leave enough room for the shared soft shadow below
                          // the card while keeping the carousel inside its width.
                          padding: const EdgeInsetsDirectional.only(
                              end: 8, bottom: 8),
                          child: BestMetricCard(
                            key: ValueKey('weekly-${ad.id}'),
                            ad: ad,
                            rank: index + 1,
                            compact: true,
                            onOpenDetails: () => _openAll(initialAdId: ad.id),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_ads.length > 1) ...[
                const SizedBox(height: 4),
                Semantics(
                  label: 'ڕیکلامی ${_page + 1} لە ${_ads.length}',
                  child: Row(
                    key: const ValueKey('home-results-dots'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _ads.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: index == _page ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color:
                              index == _page ? ProxoUi.primary : ProxoUi.border,
                          borderRadius:
                              BorderRadius.circular(ProxoUi.controlRadius),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      );
}

class _SectionHeader extends StatelessWidget {
  final bool canOpen;
  final VoidCallback onOpen;
  const _SectionHeader({required this.canOpen, required this.onOpen});
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 0,
              children: [
                const ProxoText('باشترین ئەنجامەکان',
                    style: ProxoUi.sectionTitle),
                TextButton(
                    key: const ValueKey('home-results-view-all'),
                    onPressed: canOpen ? onOpen : null,
                    style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 8)),
                    child: ProxoText('بینینی هەموو',
                        style: ProxoUi.label.copyWith(
                            color: canOpen ? ProxoUi.primary : ProxoUi.muted))),
              ]),
          const ProxoText('ڕیکلامە هەڵبژێردراوەکانی ئەم هەفتەیە',
              style: ProxoUi.secondary),
        ],
      );
}

class _StateCard extends StatelessWidget {
  final Widget child;
  const _StateCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(ProxoUi.cardPadding),
        decoration: ProxoUi.cardDecoration,
        child: child,
      );
}

class _HomeLoading extends StatelessWidget {
  const _HomeLoading({super.key});
  @override
  Widget build(BuildContext context) => const _StateCard(
        child: SizedBox(
            height: 104,
            child: Center(
                child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: ProxoUi.primary, strokeWidth: 2)))),
      );
}

class _HomeEmpty extends StatelessWidget {
  const _HomeEmpty({super.key});
  @override
  Widget build(BuildContext context) => const _StateCard(
        child: Column(children: [
          SolarIcon(SolarIcons.medalStar,
              style: SolarIconStyle.linear, size: 28, color: ProxoUi.primary),
          SizedBox(height: 12),
          ProxoText('هێشتا ئەنجامی ئەم هەفتەیە هەڵنەبژێردراوە',
              textAlign: TextAlign.center, style: ProxoUi.secondary),
        ]),
      );
}

class _HomeError extends StatelessWidget {
  final VoidCallback onRetry;
  const _HomeError({super.key, required this.onRetry});
  @override
  Widget build(BuildContext context) => _StateCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const ProxoText('ئەنجامەکان بار نەبوون', style: ProxoUi.secondary),
          const SizedBox(height: 12),
          Align(
              alignment: AlignmentDirectional.centerEnd,
              child: OutlinedButton(
                  key: const ValueKey('home-results-retry'),
                  onPressed: onRetry,
                  child: const ProxoText('دووبارە', style: ProxoUi.label))),
        ]),
      );
}

class _CardSizeObserver extends SingleChildRenderObjectWidget {
  final ValueChanged<Size> onSize;
  const _CardSizeObserver({required this.onSize, required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _CardSizeRender(onSize);
  @override
  void updateRenderObject(BuildContext context, _CardSizeRender renderObject) {
    renderObject.onSize = onSize;
  }
}

class _CardSizeRender extends RenderProxyBox {
  ValueChanged<Size> onSize;
  bool _queued = false;
  _CardSizeRender(this.onSize);
  @override
  void performLayout() {
    super.performLayout();
    if (_queued) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (attached) onSize(size);
    });
  }
}
