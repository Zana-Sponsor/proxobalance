import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../l10n/proxo_strings.dart';
import '../theme/app_locale.dart';
import '../screens/best_metrics_screen.dart';
import '../services/best_metrics_service.dart';
import '../services/featured_image_cache.dart';
import 'best_metric_card.dart';
import 'best_results_design.dart';
import '../theme/proxo_design_tokens.dart';
import 'proxo_text.dart';
import 'proxo_symbol.dart';

typedef HomeResultsLoader = Future<List<BestMetricAd>> Function({
  bool forceRefresh,
});

class BestMetricsHomeSection extends StatefulWidget {
  const BestMetricsHomeSection({
    super.key,
    this.loadPreview,
    this.autoPlay = true,
  });
  final HomeResultsLoader? loadPreview;
  final bool autoPlay;
  @override
  State<BestMetricsHomeSection> createState() => BestMetricsHomeSectionState();
}

class BestMetricsHomeSectionState extends State<BestMetricsHomeSection>
    with WidgetsBindingObserver {
  final PageController _pages = PageController();
  final Map<String, double> _heights = {};
  ScrollPosition? _parentScroll;
  Timer? _timer;
  double? _width;
  TextScaler? _scale;
  List<BestMetricAd> _ads = const [];
  bool _loading = true,
      _touching = false,
      _scrolling = false,
      _opening = false,
      _active = true;
  Object? _error;
  int _page = 0, _request = 0;
  static const slideDelay = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(refresh(forceRefresh: false));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final parent = Scrollable.maybeOf(context)?.position;
    if (parent != _parentScroll) {
      _parentScroll?.removeListener(_parentMoved);
      _parentScroll?.isScrollingNotifier.removeListener(_parentMoved);
      _parentScroll = parent;
      parent?.addListener(_parentMoved);
      parent?.isScrollingNotifier.addListener(_parentMoved);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _schedule();
    });
  }

  @override
  void didUpdateWidget(BestMetricsHomeSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoPlay != widget.autoPlay) _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _schedule();
  }

  void _parentMoved() => _schedule();

  bool get _canSlide {
    if (!mounted ||
        !widget.autoPlay ||
        !_active ||
        _opening ||
        _touching ||
        _scrolling ||
        _ads.length < 2 ||
        !_pages.hasClients ||
        !TickerMode.of(context) ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context) ||
        !(ModalRoute.of(context)?.isCurrent ?? true) ||
        (_parentScroll?.isScrollingNotifier.value ?? false)) return false;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return false;
    final origin = box.localToGlobal(Offset.zero);
    return origin.dy < MediaQuery.sizeOf(context).height &&
        origin.dy + box.size.height > 0;
  }

  void _schedule() {
    _timer?.cancel();
    _timer = null;
    if (!_canSlide) return;
    _timer = Timer(slideDelay, () async {
      if (!_canSlide || _pages.position.isScrollingNotifier.value) return;
      // Forward-only virtual pages avoid an abrupt last-to-first rewind.
      await _pages.animateToPage(
        _page + 1,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
      if (mounted) _schedule();
    });
  }

  void _warmNext() {
    if (!mounted || _ads.isEmpty) return;
    unawaited(
      FeaturedImageCache.warm(
        context,
        _ads[(_page + 1) % _ads.length].thumbnailUrl,
      ),
    );
  }

  Future<void> refresh({bool forceRefresh = true}) async {
    final request = ++_request;
    if (_ads.isEmpty)
      setState(() {
        _loading = true;
        _error = null;
      });
    try {
      final rows =
          await (widget.loadPreview ?? BestMetricsService.fetchHomePreview)(
        forceRefresh: forceRefresh,
      );
      if (!mounted || request != _request) return;
      final currentId = _ads.isEmpty ? null : _ads[_page % _ads.length].id;
      final next = math.max(0, rows.indexWhere((ad) => ad.id == currentId));
      setState(() {
        _ads = rows;
        _loading = false;
        _error = null;
        _page = next;
        _heights.removeWhere((id, _) => !rows.any((ad) => ad.id == id));
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_pages.hasClients) _pages.jumpToPage(next);
        _warmNext();
        _schedule();
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _error = error;
      });
      _schedule();
    }
  }

  Future<void> _openAll({String? initialAdId}) async {
    if (_opening) return;
    _opening = true;
    _schedule();
    final reduced = MediaQuery.disableAnimationsOf(context);
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        settings: const RouteSettings(name: 'best_metrics'),
        transitionDuration:
            reduced ? Duration.zero : const Duration(milliseconds: 240),
        reverseTransitionDuration:
            reduced ? Duration.zero : const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) =>
            BestMetricsScreen(initialAds: _ads, initialAdId: initialAdId),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: child,
        ),
      ),
    );
    if (!mounted) return;
    _opening = false;
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _parentScroll?.removeListener(_parentMoved);
    _parentScroll?.isScrollingNotifier.removeListener(_parentMoved);
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Theme(
          data: ResultsUi.theme(context),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              key: const ValueKey('home-results-banner'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _heading(),
                const SizedBox(height: 12),
                if (_loading && _ads.isEmpty)
                  const SizedBox(
                    height: 180,
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (_ads.isEmpty)
                  ResultsStateCard(
                    error: _error != null,
                    onRefresh: () => refresh(),
                  )
                else
                  _carousel(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heading() => LayoutBuilder(builder: (context, constraints) {
        final title = Row(mainAxisSize: MainAxisSize.min, children: [
          const ProxoSymbol(ProxoSymbolName.trophy,
              size: 22, color: ResultsUi.blue),
          const SizedBox(width: 8),
          Flexible(
              child: ProxoText('باشترین ئەنجامەکان',
                  translate: true, style: ProxoDesign.heading)),
        ]);
        final action = TextButton(
          key: const ValueKey('home-results-view-all'),
          onPressed: _ads.isEmpty ? null : () => _openAll(),
          style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
                child: ProxoText('بینینی ئامارەکان',
                    translate: true,
                    style: ResultsUi.text(
                        size: 13,
                        color:
                            _ads.isEmpty ? ResultsUi.muted : ResultsUi.blue))),
            const SizedBox(width: 4),
            ProxoSymbol(ProxoSymbolName.forward,
                size: 18,
                color: _ads.isEmpty ? ResultsUi.muted : ResultsUi.blue),
          ]),
        );
        double measure(String text, double size) {
          final painter = TextPainter(
              text: TextSpan(
                  text: ProxoStrings.text(text),
                  style: ResultsUi.text(size: size)),
              textDirection: TextDirection.rtl,
              textScaler: MediaQuery.textScalerOf(context))
            ..layout();
          final width = painter.width;
          painter.dispose();
          return width;
        }

        if (measure('باشترین ئەنجامەکان', 18) +
                measure('بینینی ئامارەکان', 13) +
                76 >
            constraints.maxWidth) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                Align(alignment: AlignmentDirectional.centerEnd, child: action)
              ]);
        }
        return Row(children: [
          Expanded(child: title),
          const SizedBox(width: 8),
          action
        ]);
      });

  Widget _carousel() => LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context);
          if (_width != constraints.maxWidth || _scale != scale) {
            _width = constraints.maxWidth;
            _scale = scale;
            _heights.clear();
          }
          final height = _heights[_ads[_page % _ads.length].id] ?? 246.0;
          return Column(
            children: [
              Listener(
                onPointerDown: (_) {
                  _touching = true;
                  _schedule();
                },
                onPointerUp: (_) {
                  _touching = false;
                  _schedule();
                },
                onPointerCancel: (_) {
                  _touching = false;
                  _schedule();
                },
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.depth != 0) return false;
                    if (notification is ScrollStartNotification) {
                      _scrolling = true;
                      _schedule();
                    }
                    if (notification is ScrollEndNotification) {
                      _scrolling = false;
                      _schedule();
                    }
                    return false;
                  },
                  child: SizedBox(
                    height: height,
                    child: PageView.builder(
                      key: const ValueKey('home-results-carousel'),
                      controller: _pages,
                      padEnds: false,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _ads.length == 1 ? 1 : null,
                      onPageChanged: (page) {
                        setState(() => _page = page);
                        _warmNext();
                      },
                      itemBuilder: (context, index) {
                        final ad = _ads[index % _ads.length];
                        return SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: _CardSizeObserver(
                            onSize: (size) {
                              if (!mounted ||
                                  ((_heights[ad.id] ?? 0) - size.height).abs() <
                                      .1) return;
                              setState(() => _heights[ad.id] = size.height);
                            },
                            child: Padding(
                              padding: EdgeInsets.zero,
                              child: BestMetricCard(
                                key: ValueKey('weekly-${ad.id}'),
                                ad: ad,
                                rank: index % _ads.length + 1,
                                compact: true,
                                onOpenDetails: () =>
                                    _openAll(initialAdId: ad.id),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (_ads.length > 1) ...[
                const SizedBox(height: 12),
                Semantics(
                  label: ProxoStrings.format('ڕیکلامی {index} لە {count}', {
                    'index': _page % _ads.length + 1,
                    'count': _ads.length,
                  }),
                  child: Row(
                    key: const ValueKey('home-results-dots'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Keep pagination bounded even if the curator selects many adverts.
                      for (var i = 0; i < math.min(5, _ads.length); i++)
                        AnimatedContainer(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 180),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i ==
                                  (_page % _ads.length) %
                                      math.min(5, _ads.length)
                              ? 18
                              : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i ==
                                    (_page % _ads.length) %
                                        math.min(5, _ads.length)
                                ? ResultsUi.ink
                                : const Color(0xFFD5CEC4),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
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
