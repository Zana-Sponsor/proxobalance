import 'package:flutter/material.dart';

import '../services/ad_categories.dart';
import '../services/best_metrics_service.dart';
import 'best_results_design.dart';
import 'proxo_text.dart';
import 'result_metrics.dart';
import 'result_thumbnail.dart';

/// Compact summary; video, campaign goal and budget live on Results only.
class HomeBestResultCard extends StatelessWidget {
  const HomeBestResultCard({
    super.key,
    required this.ad,
    required this.rank,
    this.onOpenDetails,
  });
  final BestMetricAd ad;
  final int rank;
  final VoidCallback? onOpenDetails;
  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: ResultsUi.radius,
        border: Border.all(color: const Color(0xFFE8E5E0)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: ResultsUi.radius,
        child: InkWell(
          onTap: onOpenDetails,
          borderRadius: ResultsUi.radius,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final thumb = SizedBox(
                      width: 76,
                      height: 86,
                      child: ResultThumbnail(url: ad.thumbnailUrl),
                    );
                    final title = ProxoText(
                      adCategoryLabel(ad.category),
                      translate: true,
                      style: ResultsUi.text(size: 16),
                    );
                    final details = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ResultRank(rank: rank),
                        const SizedBox(height: 10),
                        title,
                      ],
                    );
                    if (constraints.maxWidth < 240 ||
                        MediaQuery.textScalerOf(context).scale(16) > 24) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              thumb,
                              const SizedBox(width: 12),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: ResultRank(rank: rank),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          title,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        thumb,
                        const SizedBox(width: 16),
                        Expanded(child: details),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                ResultMetrics(ad: ad),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
