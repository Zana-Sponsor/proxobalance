import 'package:flutter/material.dart';

import '../l10n/proxo_strings.dart';
import '../services/best_metrics_service.dart';
import 'best_results_design.dart';
import 'proxo_symbol.dart';
import 'proxo_text.dart';

class ResultMetrics extends StatelessWidget {
  const ResultMetrics({super.key, required this.ad});
  final BestMetricAd ad;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final metrics = <(ProxoSymbolName, String, String)>[
          (ProxoSymbolName.eye, 'بینین', ResultsUi.number(ad.impressions)),
          (ProxoSymbolName.click, 'کرتە', ResultsUi.number(ad.clicks)),
          (ProxoSymbolName.wallet, 'تێچوو', ResultsUi.usd(ad.spendUsd)),
        ];
        double width(String text, double size) {
          final painter = TextPainter(
              text: TextSpan(text: text, style: ResultsUi.text(size: size)),
              textDirection: TextDirection.rtl,
              textScaler: MediaQuery.textScalerOf(context))
            ..layout();
          final result = painter.width;
          painter.dispose();
          return result;
        }

        final available = (constraints.maxWidth - 32) / 3;
        final fits = metrics.every((m) =>
            width(m.$3, 15) <= available &&
            width(ProxoStrings.text(m.$2), 12) <= available);
        Widget amount((ProxoSymbolName, String, String) m) => ProxoText(m.$3,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            style: ResultsUi.text(size: 15));
        Widget cell((ProxoSymbolName, String, String) m) =>
            Column(mainAxisSize: MainAxisSize.min, children: [
              amount(m),
              const SizedBox(height: 4),
              ProxoText(m.$2,
                  translate: true,
                  textAlign: TextAlign.center,
                  style: ResultsUi.text(size: 12, color: ResultsUi.muted)),
            ]);
        Widget row((ProxoSymbolName, String, String) m) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                ProxoSymbol(m.$1, size: 20, color: ResultsUi.muted),
                const SizedBox(width: 8),
                Expanded(
                    child: ProxoText(m.$2,
                        translate: true,
                        style:
                            ResultsUi.text(size: 12, color: ResultsUi.muted))),
                const SizedBox(width: 8),
                Flexible(child: amount(m)),
              ]),
            );
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(12)),
          child: fits
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (var i = 0; i < metrics.length; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(child: cell(metrics[i])),
                  ],
                ])
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: metrics.map(row).toList()),
        );
      });
}
