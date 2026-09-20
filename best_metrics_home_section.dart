import 'dart:async';

import 'package:flutter/material.dart';
import 'package:solar_iconkit/solar_iconkit.dart';

import '../theme/app_theme.dart' show kAppFont;
import '../screens/best_metrics_screen.dart';
import '../services/best_metrics_service.dart';
import 'best_metric_card.dart';

const Color _ink = Color(0xFF0B0B32);
const Color _muted = Color(0xFF5D6677);
const Color _accent = Color(0xFF0365FF);
const Color _line = Color(0xFFE6EAF0);

class BestMetricsHomeSection extends StatefulWidget {
  const BestMetricsHomeSection({super.key});

  @override
  State<BestMetricsHomeSection> createState() =>
      BestMetricsHomeSectionState();
}

class BestMetricsHomeSectionState extends State<BestMetricsHomeSection> {
  final PageController _pageController = PageController(viewportFraction: 0.88);
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
      final rows = await BestMetricsService.fetchHomePreview(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _ads = rows;
        _loading = false;
        _error = null;
        if (_page >= _ads.length) _page = 0;
      });
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
          child: BestMetricsScreen(
            initialAds: _ads,
            initialAdId: initialAdId,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            canOpen: _ads.isNotEmpty,
            onOpen: _openAll,
          ),
          const SizedBox(height: 12),
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
                        : Column(
                            key: const ValueKey('content'),
                            children: [
                          SizedBox(
                            height: 318,
                            child: PageView.builder(
                              controller: _pageController,
                              clipBehavior: Clip.none,
                              padEnds: false,
                              physics: const BouncingScrollPhysics(),
                              itemCount: _ads.length,
                              onPageChanged: (value) {
                                if (mounted) setState(() => _page = value);
                              },
                              itemBuilder: (context, index) {
                                final ad = _ads[index];
                                return Padding(
                                  padding: const EdgeInsets.only(left: 12),
                                  child: TweenAnimationBuilder<double>(
                                    key: ValueKey('weekly-' + ad.id),
                                    tween: Tween<double>(begin: 0, end: 1),
                                    duration: Duration(
                                      milliseconds: 360 + (index * 55),
                                    ),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, value, child) {
                                      return Opacity(
                                        opacity: value,
                                        child: Transform.translate(
                                          offset: Offset(0, 18 * (1 - value)),
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: BestMetricCard(
                                      ad: ad,
                                      rank: index + 1,
                                      compact: true,
                                      onOpenDetails: () =>
                                          _openAll(initialAdId: ad.id),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (_ads.length > 1) ...[
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List<Widget>.generate(
                                _ads.length,
                                (index) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 3),
                                  width: index == _page ? 18 : 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: index == _page
                                        ? _accent
                                        : const Color(0xFFD7DCE5),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final bool canOpen;
  final VoidCallback onOpen;

  const _SectionHeader({
    required this.canOpen,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF6E8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const SolarIcon(
            SolarIcons.medalStar,
            style: SolarIconStyle.linear,
            size: 21,
            color: Color(0xFFE19A13),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'باشترین ئەنجامەکانی هەفتە',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: kAppFont,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
        ),
        TextButton(
          onPressed: canOpen ? onOpen : null,
          style: TextButton.styleFrom(
            foregroundColor: _accent,
            disabledForegroundColor: _muted,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'بینینی هەموو',
                style: TextStyle(
                  fontFamily: kAppFont,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(width: 4),
              SolarIcon(
                SolarIcons.altArrowLeft,
                style: SolarIconStyle.linear,
                size: 16,
                matchTextDirection: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeLoading extends StatelessWidget {
  const _HomeLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 222,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: const Center(
        child: SizedBox(
          width: 23,
          height: 23,
          child: CircularProgressIndicator(
            color: _accent,
            strokeWidth: 2.3,
          ),
        ),
      ),
    );
  }
}

class _HomeEmpty extends StatelessWidget {
  const _HomeEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0B0B32),
            blurRadius: 14,
            spreadRadius: -5,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'هێشتا ئەنجامی ئەم هەفتەیە هەڵنەبژێردراوە',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: kAppFont,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _muted,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _HomeError extends StatelessWidget {
  final VoidCallback onRetry;

  const _HomeError({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          const SolarIcon(
            SolarIcons.dangerTriangle,
            style: SolarIconStyle.linear,
            size: 21,
            color: Color(0xFFE5484D),
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Text(
              'ئەنجامەکان بار نەبوون',
              style: TextStyle(
                fontFamily: kAppFont,
                fontSize: 12,
                color: _muted,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              'دووبارە',
              style: TextStyle(fontFamily: kAppFont, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}
