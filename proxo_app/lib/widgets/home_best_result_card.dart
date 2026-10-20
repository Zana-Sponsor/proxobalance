import 'package:flutter/material.dart';
import 'package:solar_iconkit/solar_iconkit.dart';

import '../services/ad_categories.dart';
import '../services/best_metrics_service.dart';
import '../theme/proxo_ui.dart';
import 'ad_thumbnail.dart';
import 'proxo_text.dart';

/// A compact summary that keeps secondary information in the same card.
class HomeBestResultCard extends StatefulWidget {
  final BestMetricAd ad;
  final int rank;
  final VoidCallback? onOpenDetails;
  final ImageProvider? thumbnailProvider;

  const HomeBestResultCard({
    super.key,
    required this.ad,
    required this.rank,
    this.onOpenDetails,
    this.thumbnailProvider,
  });

  @override
  State<HomeBestResultCard> createState() => _HomeBestResultCardState();
}

class _HomeBestResultCardState extends State<HomeBestResultCard> {
  bool _expanded = false;
  BestMetricAd get ad => widget.ad;

  String _number(int value) => value.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]},',
      );
  String _usd(double value) =>
      '\$${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)}';

  @override
  void didUpdateWidget(covariant HomeBestResultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ad.id != ad.id) _expanded = false;
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(ProxoUi.radius),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(ProxoUi.radius),
            child: Padding(
              padding: const EdgeInsets.all(ProxoUi.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InkWell(
                    key: ValueKey('result-open-${ad.id}'),
                    onTap: widget.onOpenDetails,
                    borderRadius: BorderRadius.circular(ProxoUi.controlRadius),
                    child: _header(),
                  ),
                  const SizedBox(height: ProxoUi.gap12),
                  _metrics(context),
                  const SizedBox(height: ProxoUi.gap8),
                  Semantics(
                    button: true,
                    expanded: _expanded,
                    child: TextButton(
                      key: ValueKey('result-toggle-${ad.id}'),
                      onPressed: () => setState(() => _expanded = !_expanded),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, ProxoUi.controlHeight),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        foregroundColor: const Color(0xFF046CFA),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                              child: ProxoText(
                            _expanded ? 'شاردنەوەی وردەکاری' : 'وردەکاری زیاتر',
                            style: ProxoUi.label
                                .copyWith(color: const Color(0xFF046CFA)),
                            textAlign: TextAlign.center,
                          )),
                          const SizedBox(width: ProxoUi.gap8),
                          AnimatedRotation(
                            turns: _expanded ? .5 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: const SolarIcon(SolarIcons.altArrowDown,
                                style: SolarIconStyle.linear,
                                size: 18,
                                color: Color(0xFF046CFA)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // No fixed height: longer Kurdish labels and system text scaling
                  // reflow naturally, and the carousel measures the actual result.
                  if (_expanded) ...[
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: ProxoUi.gap12),
                    _detail(
                        'ئامانج',
                        ad.goal == 'messages'
                            ? 'نامە و فرۆش'
                            : 'بینین و کارلێک'),
                    _detail('بودجەی گشتی', _usd(ad.originalBudgetUsd)),
                    _detail('بودجەی ڕۆژانە', _usd(ad.dailyBudgetUsd)),
                    _detail('ماوە', '${ad.days} ڕۆژ'),
                    if (widget.onOpenDetails != null)
                      OutlinedButton(
                        key: ValueKey('result-view-${ad.id}'),
                        onPressed: widget.onOpenDetails,
                        child: const ProxoText('بینینی ئەنجام',
                            style: ProxoUi.label),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );

  Widget _header() => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 80,
            child: AdThumbnail(
                url: ad.thumbnailUrl, imageProvider: widget.thumbnailProvider),
          ),
          const SizedBox(width: ProxoUi.gap12),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProxoText(adCategoryLabel(ad.category), style: ProxoUi.cardTitle),
              const SizedBox(height: ProxoUi.gap8),
              Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ProxoText('#${widget.rank}',
                        style: ProxoUi.status
                            .copyWith(color: const Color(0xFF046CFA))),
                    const ProxoText('هەڵبژێردراوی هەفتە',
                        style: ProxoUi.secondary),
                  ]),
            ],
          )),
        ],
      );

  Widget _metrics(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final rows = <(String, String)>[
            ('بینین', _number(ad.impressions)),
            ('کرتە', _number(ad.clicks)),
            ('تێچوو', _usd(ad.spendUsd)),
          ];
          final scaler = MediaQuery.textScalerOf(context);
          final cellWidth = (constraints.maxWidth - 16) / 3;
          bool fits(String text) {
            final painter = TextPainter(
                text: TextSpan(text: text, style: ProxoUi.body),
                textDirection: ProxoTextDirection.of(text),
                textScaler: scaler)
              ..layout();
            final result = painter.width + 8 <= cellWidth;
            painter.dispose();
            return result;
          }

          final horizontal = rows.every((row) => fits(row.$1) && fits(row.$2));
          final cells = rows
              .map((row) => _ResultMetric(
                  label: row.$1, value: row.$2, horizontal: !horizontal))
              .toList();
          return Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(ProxoUi.controlRadius)),
            child: horizontal
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (var i = 0; i < cells.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: cells[i]),
                    ]
                  ])
                : Column(children: [
                    for (var i = 0; i < cells.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      cells[i],
                    ]
                  ]),
          );
        },
      );

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 16,
            runSpacing: 4,
            children: [
              ProxoText(label, style: ProxoUi.secondary),
              ProxoText(value, style: ProxoUi.body)
            ]),
      );
}

class _ResultMetric extends StatelessWidget {
  final String label, value;
  final bool horizontal;
  const _ResultMetric(
      {required this.label, required this.value, this.horizontal = false});

  @override
  Widget build(BuildContext context) {
    final labelText =
        ProxoText(label, textAlign: TextAlign.center, style: ProxoUi.secondary);
    final valueText =
        ProxoText(value, textAlign: TextAlign.center, style: ProxoUi.body);
    return horizontal
        ? Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 4,
            children: [labelText, valueText])
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [labelText, const SizedBox(height: 4), valueText]);
  }
}
