import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/proxo_strings.dart';
import '../services/ad_categories.dart';
import '../services/best_metrics_service.dart';
import 'best_results_design.dart';
import 'home_best_result_card.dart';
import 'proxo_text.dart';
import 'result_metrics.dart';
import 'result_thumbnail.dart';

class BestMetricCard extends StatelessWidget {
  const BestMetricCard({
    super.key,
    required this.ad,
    required this.rank,
    this.compact = false,
    this.expanded = false,
    this.onOpenDetails,
    this.onToggleExpanded,
  });
  final BestMetricAd ad;
  final int rank;
  final bool compact, expanded;
  final VoidCallback? onOpenDetails, onToggleExpanded;

  Future<void> _openVideo(BuildContext context) async {
    if (!ad.hasPlayableVideo) return;
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(ad.videoLink!),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      /* Platform/app unavailable: keep the result and show a retryable message. */
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: ProxoText(
            'ڤیدیۆکە نەکرایەوە',
            translate: true,
            style: ResultsUi.text(color: Colors.white),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (compact)
      return HomeBestResultCard(
        ad: ad,
        rank: rank,
        onOpenDetails: onOpenDetails,
      );
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: ResultsUi.radius,
          border: Border.all(
            color: expanded
                ? ResultsUi.blue.withValues(alpha: .35)
                : ResultsUi.line,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ResultRank(rank: rank),
                  const Spacer(),
                  const ResultIcon('fire', size: 26, color: Color(0xFFE87832)),
                ],
              ),
              const SizedBox(height: 16),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ResultThumbnail(url: ad.thumbnailUrl),
              ),
              const SizedBox(height: 18),
              ProxoText(
                adCategoryLabel(ad.category),
                translate: true,
                style: ResultsUi.text(size: 18),
              ),
              const SizedBox(height: 6),
              ProxoText(
                ad.goal == 'messages' ? 'نامە و فرۆش' : 'بینین و کارلێک',
                translate: true,
                style: ResultsUi.text(color: ResultsUi.muted),
              ),
              const SizedBox(height: 18),
              ResultMetrics(ad: ad),
              const SizedBox(height: 18),
              const Divider(height: 1, color: ResultsUi.line),
              const SizedBox(height: 16),
              _detail('کۆی بودجە', ResultsUi.usd(ad.originalBudgetUsd)),
              const SizedBox(height: 10),
              _detail(
                'ماوەی ڕیکلام',
                ProxoStrings.format('{count} ڕۆژ', {'count': ad.days}),
              ),
              if (ad.hasPlayableVideo) ...[
                const SizedBox(height: 20),
                FilledButton(
                  key: ValueKey('result-video-${ad.id}'),
                  onPressed: () => _openVideo(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: ResultsUi.blue,
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const ResultIcon('play', size: 20, color: Colors.white),
                      const SizedBox(width: 10),
                      Flexible(
                        child: ProxoText(
                          'بینینی ڤیدیۆ',
                          translate: true,
                          textAlign: TextAlign.center,
                          style: ResultsUi.text(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(String label, String value) => LayoutBuilder(
    builder: (context, constraints) {
      final name = ProxoText(
        label,
        translate: true,
        style: ResultsUi.text(size: 13, color: ResultsUi.muted),
      );
      final amount = ProxoText(value, style: ResultsUi.text(size: 14));
      if (constraints.maxWidth < 250 ||
          MediaQuery.textScalerOf(context).scale(14) > 21) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [name, const SizedBox(height: 4), amount],
        );
      }
      return Row(
        children: [
          Expanded(child: name),
          const SizedBox(width: 12),
          amount,
        ],
      );
    },
  );
}
