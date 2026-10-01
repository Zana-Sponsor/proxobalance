import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:solar_iconkit/solar_iconkit.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart' show kAppFont;
import '../services/ad_categories.dart';
import '../services/best_metrics_service.dart';

const Color _ink = Color(0xFF0B0B32);
const Color _muted = Color(0xFF5D6677);
const Color _accent = Color(0xFF0365FF);
const Color _line = Color(0xFFE6EAF0);
const Color _surface = Colors.white;
const List<BoxShadow> _softCardShadow = <BoxShadow>[
  BoxShadow(
    color: Color(0x0F000000),
    blurRadius: 18,
    offset: Offset(0, 5),
  ),
];

class BestMetricCard extends StatelessWidget {
  final BestMetricAd ad;
  final int rank;
  final bool compact;
  final bool expanded;
  final VoidCallback? onOpenDetails;
  final VoidCallback? onToggleExpanded;

  const BestMetricCard({
    super.key,
    required this.ad,
    required this.rank,
    this.compact = false,
    this.expanded = false,
    this.onOpenDetails,
    this.onToggleExpanded,
  });

  String _number(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => (match[1] ?? '') + ',',
    );
  }

  String _usd(double value) {
    final digits = value == value.roundToDouble() ? 0 : 2;
    return String.fromCharCode(36) + value.toStringAsFixed(digits);
  }

  String get _goalLabel {
    return ad.goal == 'messages' ? 'نامە و فرۆش' : 'بینین و کارلێک';
  }

  Future<void> _openVideo(BuildContext context) async {
    final uri = Uri.tryParse(ad.videoLink ?? '');
    if (uri == null || !ad.hasPlayableVideo) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ڤیدیۆکە نەکرایەوە')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MetricThumbnail(ad: ad, rank: rank),
        Padding(
          padding: EdgeInsets.fromLTRB(14, compact ? 12 : 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CategoryPill(label: adCategoryLabel(ad.category)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricValue(
                      icon: SolarIcons.eye,
                      label: 'بینین',
                      value: _number(ad.impressions),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricValue(
                      icon: SolarIcons.cursorSquare,
                      label: 'کرتە',
                      value: _number(ad.clicks),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricValue(
                      icon: SolarIcons.dollarMinimalistic,
                      label: 'تێچوو',
                      value: _usd(ad.spendUsd),
                    ),
                  ),
                ],
              ),
              if (!compact) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (ad.hasPlayableVideo)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _openVideo(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _accent,
                            side: const BorderSide(color: _line),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SolarIcon(
                                SolarIcons.arrowRightUp,
                                style: SolarIconStyle.linear,
                                size: 18,
                                color: _accent,
                              ),
                              SizedBox(width: 7),
                              Text(
                                'بینینی ڤیدیۆ',
                                style: TextStyle(
                                  fontFamily: kAppFont,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (ad.hasPlayableVideo) const SizedBox(width: 8),
                    Expanded(
                      child: TextButton(
                        onPressed: onToggleExpanded,
                        style: TextButton.styleFrom(
                          foregroundColor: _ink,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'بینینی زیاتر',
                              style: TextStyle(
                                fontFamily: kAppFont,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 6),
                            AnimatedRotation(
                              turns: expanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOutCubic,
                              child: const SolarIcon(
                                SolarIcons.altArrowDown,
                                style: SolarIconStyle.linear,
                                size: 17,
                                color: _ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                ClipRect(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: expanded
                        ? Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _DetailCapsule(
                                    label: 'ئامانج',
                                    value: _goalLabel,
                                    icon: SolarIcons.target,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _DetailCapsule(
                                    label: 'بودجە',
                                    value: _usd(ad.originalBudgetUsd),
                                    icon: SolarIcons.wallet,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: radius,
          border: Border.all(color: _line.withValues(alpha: 0.9)),
          boxShadow: _softCardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: compact ? onOpenDetails : null,
            child: body,
          ),
        ),
      ),
    );
  }
}

class _MetricThumbnail extends StatefulWidget {
  final BestMetricAd ad;
  final int rank;

  const _MetricThumbnail({required this.ad, required this.rank});

  @override
  State<_MetricThumbnail> createState() => _MetricThumbnailState();
}

class _MetricThumbnailState extends State<_MetricThumbnail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shine;
  bool _shineStarted = false;

  @override
  void initState() {
    super.initState();
    _shine = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
  }

  @override
  void didUpdateWidget(covariant _MetricThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ad.thumbnailUrl != widget.ad.thumbnailUrl) {
      _shine.stop();
      _shine.value = 0;
      _shineStarted = false;
    }
  }

  void _startShineOnce() {
    if (_shineStarted) return;
    _shineStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _shine.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  Widget _fallback() {
    return const ColoredBox(
      color: Color(0xFFF1F4F8),
      child: Center(
        child: SolarIcon(
          SolarIcons.gallery,
          style: SolarIconStyle.linear,
          size: 34,
          color: Color(0xFF98A2B3),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.ad.thumbnailUrl;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url == null)
            _fallback()
          else
            CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 180),
              memCacheWidth: 900,
              placeholder: (_, __) => _fallback(),
              errorWidget: (_, __, ___) => _fallback(),
              imageBuilder: (context, provider) {
                _startShineOnce();
                return DecoratedBox(
                  decoration: BoxDecoration(
                    image: DecorationImage(image: provider, fit: BoxFit.cover),
                  ),
                );
              },
            ),
          if (url != null)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _shine,
                builder: (context, child) {
                  final x = -1.4 + (_shine.value * 2.8);
                  return FractionalTranslation(
                    translation: Offset(x, 0),
                    child: Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 74,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Color(0x36FFFFFF),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          Positioned(
            top: 10,
            right: 10,
            child: _RankBadge(rank: widget.rank),
          ),
          if (widget.rank <= 3)
            const Positioned(
              top: 10,
              left: 10,
              child: _FireBadge(),
            ),
        ],
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;

  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'پلەی ڕێزبەندی ' + rank.toString(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(color: Color(0x22000000), blurRadius: 8),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SolarIcon(
              SolarIcons.cupStar,
              style: SolarIconStyle.linear,
              size: 16,
              color: Color(0xFFE19A13),
            ),
            const SizedBox(width: 5),
            Text(
              '#' + rank.toString(),
              style: const TextStyle(
                fontFamily: kAppFont,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FireBadge extends StatelessWidget {
  const _FireBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E7).withValues(alpha: 0.96),
        shape: BoxShape.circle,
      ),
      child: const SolarIcon(
        SolarIcons.fire,
        style: SolarIconStyle.linear,
        size: 18,
        color: Color(0xFFFF6B2C),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final String label;

  const _CategoryPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F5FF),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: kAppFont,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _accent,
          ),
        ),
      ),
    );
  }
}

class _MetricValue extends StatelessWidget {
  final String icon;
  final String label;
  final String value;

  const _MetricValue({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SolarIcon(
            icon,
            style: SolarIconStyle.linear,
            size: 16,
            color: _muted,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: const TextStyle(
              fontFamily: kAppFont,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              fontFamily: kAppFont,
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: _muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCapsule extends StatelessWidget {
  final String label;
  final String value;
  final String icon;

  const _DetailCapsule({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          SolarIcon(
            icon,
            style: SolarIconStyle.linear,
            size: 18,
            color: _accent,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(
                    fontFamily: kAppFont,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: kAppFont,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
