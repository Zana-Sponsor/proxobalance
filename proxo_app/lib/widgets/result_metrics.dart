import 'package:flutter/material.dart';

import '../l10n/proxo_strings.dart';
import '../services/best_metrics_service.dart';
import 'best_results_design.dart';
import 'proxo_text.dart';

class ResultMetrics extends StatelessWidget {
  const ResultMetrics({super.key, required this.ad});
  final BestMetricAd ad;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final metrics = <(String, String, String)>[
        ('eye', 'بینین', ResultsUi.number(ad.impressions)),
        ('click', 'کرتە', ResultsUi.number(ad.clicks)),
        ('wallet', 'تێچوو', ResultsUi.usd(ad.spendUsd)),
      ];
      double width(String text, double size) {
        final painter = TextPainter(
          text: TextSpan(
            text: text,
            style: ResultsUi.text(size: size),
          ),
          textDirection: TextDirection.rtl,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final result = painter.width;
        painter.dispose();
        return result;
      }

      final available = (constraints.maxWidth - 16) / 3;
      final fits = metrics.every(
        (m) =>
            width(m.$3, 15) + 16 <= available &&
            width(ProxoStrings.text(m.$2), 12) + 16 <= available,
      );
      Widget cell((String, String, String) metric) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ResultIcon(metric.$1, size: 18, color: ResultsUi.muted),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: ProxoText(
                metric.$3,
                textAlign: TextAlign.center,
                style: ResultsUi.text(size: 15),
              ),
            ),
            const SizedBox(height: 2),
            ProxoText(
              metric.$2,
              translate: true,
              textAlign: TextAlign.center,
              style: ResultsUi.text(size: 12, color: ResultsUi.muted),
            ),
          ],
        ),
      );
      if (!fits)
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < metrics.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              cell(metrics[i]),
            ],
          ],
        );
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < metrics.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(child: cell(metrics[i])),
            ],
          ],
        ),
      );
    },
  );
}
