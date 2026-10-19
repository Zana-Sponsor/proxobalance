import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/proxo_strings.dart';
import '../services/ad_categories.dart';
import '../services/best_metrics_service.dart';
import 'best_results_design.dart';
import 'proxo_symbol.dart';
import 'proxo_text.dart';
import 'result_metrics.dart';
import 'result_thumbnail.dart';

/// One compact advert card on Home and Results. Goal, budget and duration stay
/// in the same card, disclosed only when the reader asks for more detail.
class HomeBestResultCard extends StatefulWidget {
  const HomeBestResultCard({
    super.key,
    required this.ad,
    required this.rank,
    this.initiallyExpanded = false,
    this.onOpenDetails,
    this.onExpandedChanged,
  });
  final BestMetricAd ad;
  final int rank;
  final bool initiallyExpanded;
  final VoidCallback? onOpenDetails;
  final ValueChanged<bool>? onExpandedChanged;

  @override
  State<HomeBestResultCard> createState() => _HomeBestResultCardState();
}

class _HomeBestResultCardState extends State<HomeBestResultCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  void didUpdateWidget(HomeBestResultCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ad.id != widget.ad.id ||
        oldWidget.initiallyExpanded != widget.initiallyExpanded) {
      _expanded = widget.initiallyExpanded;
    }
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    widget.onExpandedChanged?.call(_expanded);
  }

  Future<void> _openVideo() async {
    if (!widget.ad.hasPlayableVideo) return;
    var opened = false;
    try {
      opened = await launchUrl(Uri.parse(widget.ad.videoLink!),
          mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: ProxoText('ڤیدیۆکە نەکرایەوە',
            translate: true, style: ResultsUi.text(color: Colors.white)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: ResultsUi.radius,
            border: Border.all(color: ResultsUi.line)),
        child: Material(
          color: Colors.transparent,
          borderRadius: ResultsUi.radius,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  key: ValueKey('result-open-${ad.id}'),
                  onTap: widget.onOpenDetails,
                  borderRadius: ResultsUi.radius,
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                            width: 56,
                            height: 64,
                            child: ResultThumbnail(
                                url: ad.thumbnailUrl, radius: 12)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              ResultRank(rank: widget.rank),
                              const SizedBox(height: 6),
                              ProxoText(adCategoryLabel(ad.category),
                                  translate: true,
                                  style: ResultsUi.text(size: 14)),
                            ])),
                        if (widget.onOpenDetails != null) ...[
                          const SizedBox(width: 8),
                          const ProxoSymbol(ProxoSymbolName.forward,
                              size: 18, color: ResultsUi.muted),
                        ],
                      ]),
                ),
                const SizedBox(height: 12),
                ResultMetrics(ad: ad),
                const SizedBox(height: 8),
                Semantics(
                  expanded: _expanded,
                  child: TextButton(
                    key: ValueKey('result-details-${ad.id}'),
                    onPressed: _toggle,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      alignment: AlignmentDirectional.centerStart,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 8),
                      foregroundColor: ResultsUi.blue,
                    ),
                    child: Row(children: [
                      Expanded(
                          child: ProxoText(
                              _expanded ? 'وردەکاری کەمتر' : 'وردەکاری زیاتر',
                              translate: true,
                              style: ResultsUi.text(
                                  size: 13, color: ResultsUi.blue))),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                          turns: _expanded ? .5 : 0,
                          duration: reduced
                              ? Duration.zero
                              : const Duration(milliseconds: 180),
                          child: const ProxoSymbol(ProxoSymbolName.chevronDown,
                              size: 18, color: ResultsUi.blue)),
                    ]),
                  ),
                ),
                _detailTransition(
                  child: _expanded
                      ? Column(
                          key: ValueKey('result-expanded-${ad.id}'),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Divider(height: 1, color: ResultsUi.line),
                            const SizedBox(height: 12),
                            _detail(
                                'ئامانج',
                                ProxoStrings.text(ad.goal == 'messages'
                                    ? 'نامە و فرۆش'
                                    : 'بینین و کارلێک')),
                            const SizedBox(height: 8),
                            _detail('کۆی بودجە',
                                ResultsUi.usd(ad.originalBudgetUsd)),
                            const SizedBox(height: 8),
                            _detail(
                                'ماوەی ڕیکلام',
                                ProxoStrings.format(
                                    '{count} ڕۆژ', {'count': ad.days})),
                            if (ad.hasPlayableVideo) ...[
                              const SizedBox(height: 12),
                              OutlinedButton(
                                key: ValueKey('result-video-${ad.id}'),
                                onPressed: _openVideo,
                                style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                    side:
                                        const BorderSide(color: ResultsUi.line),
                                    shape: const RoundedRectangleBorder(
                                        borderRadius: ResultsUi.radius),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10)),
                                child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const ProxoSymbol(ProxoSymbolName.play,
                                          size: 20, color: ResultsUi.blue),
                                      const SizedBox(width: 8),
                                      Flexible(
                                          child: ProxoText('بینینی ڤیدیۆ',
                                              translate: true,
                                              textAlign: TextAlign.center,
                                              style: ResultsUi.text(
                                                  size: 13,
                                                  color: ResultsUi.blue))),
                                    ]),
                              ),
                            ],
                          ],
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailTransition({required Widget child}) {
    // A zero-duration RenderAnimatedSize can dirty itself during layout when
    // a thumbnail also resolves. Reduced motion needs no animated render box.
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: child,
    );
  }

  Widget _detail(String label, String value) =>
      LayoutBuilder(builder: (context, constraints) {
        final title = ProxoText(label,
            translate: true,
            style: ResultsUi.text(size: 13, color: ResultsUi.muted));
        final text = ProxoText(value, style: ResultsUi.text(size: 14));
        if (constraints.maxWidth < 240 ||
            MediaQuery.textScalerOf(context).scale(14) > 21) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 2), text]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: title),
          const SizedBox(width: 12),
          Flexible(child: text),
        ]);
      });
}
