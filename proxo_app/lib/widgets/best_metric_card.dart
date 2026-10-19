import 'package:flutter/material.dart';

import '../services/best_metrics_service.dart';
import 'home_best_result_card.dart';

/// Shared result presentation keeps Home and the full results list aligned.
class BestMetricCard extends StatelessWidget {
  const BestMetricCard({
    super.key,
    required this.ad,
    required this.rank,
    this.compact = false,
    this.expanded = false,
    this.onOpenDetails,
    this.onToggleExpanded,
    this.onExpandedChanged,
  });
  final BestMetricAd ad;
  final int rank;
  final bool compact, expanded;
  final VoidCallback? onOpenDetails, onToggleExpanded;
  final ValueChanged<bool>? onExpandedChanged;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: HomeBestResultCard(
            ad: ad,
            rank: rank,
            initiallyExpanded: expanded,
            onOpenDetails: onOpenDetails,
            onExpandedChanged: (value) {
              onExpandedChanged?.call(value);
              onToggleExpanded?.call();
            }),
      );
}
