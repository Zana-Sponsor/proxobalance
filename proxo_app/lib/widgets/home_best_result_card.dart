import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/ad_categories.dart';
import '../services/best_metrics_service.dart';
import 'ad_form_components.dart';
import 'proxo_text.dart';

/// Home's compact result card. Data and navigation are supplied by the
/// existing BestMetricCard; the full results screen keeps its existing UI.
class HomeBestResultCard extends StatelessWidget {
  final BestMetricAd ad;
  final int rank;
  final VoidCallback? onOpenDetails;

  const HomeBestResultCard({
    super.key,
    required this.ad,
    required this.rank,
    this.onOpenDetails,
  });

  String _number(int value) => value.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );

  // Retain the existing result metric's currency and precision. Home does not
  // receive a quoted exchange rate, so it must not invent an IQD conversion.
  String _usd(double value) =>
      '\$${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)}';

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: AdUi.radius,
        boxShadow: AdUi.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AdUi.radius,
        child: InkWell(
          onTap: onOpenDetails,
          borderRadius: AdUi.radius,
          child: Padding(
            padding: AdUi.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(context),
                const SizedBox(height: 20),
                _metrics(context),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _header(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final category = adCategoryLabel(ad.category);
      final title = ProxoText(category, style: AdUi.text(context));
      final goal = ProxoText(
        ad.goal == 'messages' ? 'نامە و فرۆش' : 'بینین و کارلێک',
        style: AdUi.text(context, color: AdUi.secondary),
      );
      final details = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [title, const SizedBox(height: 8), goal],
      );
      final rankBadge = Semantics(
        label: 'پلەی ڕێزبەندی $rank',
        child: ProxoText('#$rank', style: AdUi.text(context, color: AdUi.blue)),
      );
      final thumb = SizedBox(
        width: 72,
        height: 96,
        child: _ResultThumbnail(url: ad.thumbnailUrl),
      );
      // Measure inherited type with the real system text scale rather
      // than shrinking text or forcing it into a fixed-height header.
      final minimumTextWidth = _minimumWidth(context, category);
      if (constraints.maxWidth < minimumTextWidth + 88) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [thumb, const Spacer(), rankBadge]),
            const SizedBox(height: 16),
            details,
          ],
        );
      }
      return Row(
        children: [
          thumb,
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(alignment: Alignment.centerRight, child: rankBadge),
                const SizedBox(height: 8),
                details,
              ],
            ),
          ),
        ],
      );
    },
  );

  double _minimumWidth(BuildContext context, String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: AdUi.text(context)),
      textDirection: ProxoTextDirection.of(text),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = painter.minIntrinsicWidth;
    painter.dispose();
    return width;
  }

  Widget _metrics(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final rows = <(String, String)>[
        ('بینین', _number(ad.impressions)),
        ('کرتە', _number(ad.clicks)),
        ('تێچوو', _usd(ad.spendUsd)),
      ];
      final cellWidth = (constraints.maxWidth - 24) / 3;
      final fits = rows.every(
        (row) =>
            _minimumWidth(context, row.$1) + 24 <= cellWidth &&
            _minimumWidth(context, row.$2) + 24 <= cellWidth,
      );
      if (!fits) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _ResultMetric(label: rows[i].$1, value: rows[i].$2),
            ],
          ],
        );
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                child: _ResultMetric(label: rows[i].$1, value: rows[i].$2),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _ResultMetric extends StatelessWidget {
  final String label, value;
  const _ResultMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: AdUi.controlRadius,
      boxShadow: AdUi.cardShadow,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ProxoText(
          label,
          textAlign: TextAlign.center,
          style: AdUi.text(context, color: AdUi.secondary),
        ),
        const SizedBox(height: 8),
        ProxoText(
          value,
          textAlign: TextAlign.center,
          style: AdUi.text(context),
        ),
      ],
    ),
  );
}

class _ResultThumbnail extends StatelessWidget {
  final String? url;
  const _ResultThumbnail({required this.url});

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(url ?? '');
    final valid =
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
    return ClipRRect(
      borderRadius: AdUi.controlRadius,
      child: valid
          ? CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.cover,
              memCacheWidth: 300,
              fadeInDuration: const Duration(milliseconds: 180),
              placeholder: (_, __) => const _BrandedFallback(),
              errorWidget: (_, __, ___) => const _BrandedFallback(),
            )
          : const _BrandedFallback(),
    );
  }
}

class _BrandedFallback extends StatelessWidget {
  const _BrandedFallback();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AdUi.controlSurface,
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Opacity(
        opacity: 0.12,
        child: Column(
          children: [
            for (var row = 0; row < 5; row++)
              Expanded(
                child: Row(
                  children: [
                    for (var col = 0; col < 2; col++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: Image.asset(
                            'assets/images/proxo_logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
