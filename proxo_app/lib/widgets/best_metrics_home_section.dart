import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../screens/best_metrics_screen.dart';
import '../services/best_metrics_service.dart';
import 'ad_form_components.dart';
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
  @override
  void initState() {
    super.initState();
    unawaited(refresh());
  }

  Future<void> refresh({bool forceRefresh = true}) async {
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
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: BestMetricsScreen(initialAds: _ads, initialAdId: initialAdId),
        ),
      ),
    );
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
          child: Theme(
            data: AdUi.theme(context),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionHeader(canOpen: _ads.isNotEmpty, onOpen: _openAll),
                  const SizedBox(height: 20),
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
          final height = _cardHeights.isEmpty
              ? 272.0
              : _cardHeights.values.reduce(math.max);
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
                      padding: const EdgeInsets.fromLTRB(0, 6, 12, 24),
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
                          color: index == _page ? AdUi.blue : AdUi.controlLine,
                          borderRadius: AdUi.controlRadius,
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
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          const title = 'باشترین ئەنجامەکانی هەفتە';
          const action = 'بینینی هەموو';
          double width(String text, TextStyle style) {
            final painter = TextPainter(
              text: TextSpan(text: text, style: style),
              textDirection: TextDirection.rtl,
              textScaler: MediaQuery.textScalerOf(context),
            )..layout();
            final result = painter.width;
            painter.dispose();
            return result;
          }

          final heading = ProxoText(title, style: AdUi.heading(context));
          final button = TextButton(
            key: const ValueKey('home-results-view-all'),
            onPressed: canOpen ? onOpen : null,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              shape: const RoundedRectangleBorder(
                  borderRadius: AdUi.controlRadius),
            ),
            child: ProxoText(
              action,
              style: AdUi.text(
                context,
                color: canOpen ? AdUi.blue : AdUi.secondary,
              ),
            ),
          );
          if (width(title, AdUi.heading(context)) +
                  width(action, AdUi.text(context)) +
                  48 >
              constraints.maxWidth) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: button),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: heading),
              button,
            ],
          );
        },
      );
}

class _StateCard extends StatelessWidget {
  final Widget child;
  const _StateCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        padding: AdUi.cardPadding,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: AdUi.radius,
          boxShadow: AdUi.cardShadow,
        ),
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
              child:
                  CircularProgressIndicator(color: AdUi.blue, strokeWidth: 2),
            ),
          ),
        ),
      );
}

class _HomeEmpty extends StatelessWidget {
  const _HomeEmpty({super.key});
  @override
  Widget build(BuildContext context) => _StateCard(
        child: ProxoText(
          'هێشتا ئەنجامی ئەم هەفتەیە هەڵنەبژێردراوە',
          textAlign: TextAlign.center,
          style: AdUi.text(context, color: AdUi.secondary),
        ),
      );
}

class _HomeError extends StatelessWidget {
  final VoidCallback onRetry;
  const _HomeError({super.key, required this.onRetry});
  @override
  Widget build(BuildContext context) => _StateCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProxoText(
              'ئەنجامەکان بار نەبوون',
              style: AdUi.text(context, color: AdUi.secondary),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                key: const ValueKey('home-results-retry'),
                onPressed: onRetry,
                child: ProxoText(
                  'دووبارە',
                  style: AdUi.text(context, color: AdUi.blue),
                ),
              ),
            ),
          ],
        ),
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
