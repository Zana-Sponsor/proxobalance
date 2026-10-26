import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';

import '../services/ad_submission.dart';
import '../theme/tiktok_ad_tokens.dart';
import 'ad_form_components.dart';
import 'proxo_text.dart';

/// A flush, full-width bottom bar matching the supplied final-price reference.
/// Cached quote data is used only to retain
/// row geometry while loading; all stale amounts are hidden from paint and
/// semantics until an authoritative replacement arrives.
class TikTokAdPriceCard extends StatefulWidget {
  const TikTokAdPriceCard(
      {super.key,
      required this.quote,
      required this.loading,
      required this.error,
      required this.expanded,
      required this.onToggle,
      required this.onRetry,
      required this.viewportHeight});
  final AdQuote? quote;
  final bool loading, expanded;
  final String? error;
  final VoidCallback onToggle, onRetry;
  final double viewportHeight;

  static double clearance(BuildContext context, double viewportHeight) =>
      math.max(200 * MediaQuery.textScalerOf(context).scale(14) / 14,
          math.min(360, viewportHeight * .62)) +
      24;

  @override
  State<TikTokAdPriceCard> createState() => _TikTokAdPriceCardState();
}

class _TikTokAdPriceCardState extends State<TikTokAdPriceCard> {
  AdQuote? _geometryQuote;
  final _detailsScroll = ScrollController();

  @override
  void dispose() {
    _detailsScroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _rememberGeometry();
  }

  @override
  void didUpdateWidget(covariant TikTokAdPriceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _rememberGeometry();
  }

  void _rememberGeometry() {
    if (!widget.loading && widget.error == null && widget.quote != null) {
      _geometryQuote = widget.quote;
    }
  }

  Size _measure(BuildContext context, String text, TextStyle style,
      [double width = double.infinity]) {
    final painter = TextPainter(
        text: TextSpan(text: ProxoTextDirection.display(text), style: style),
        textDirection: ProxoTextDirection.of(text),
        textScaler: MediaQuery.textScalerOf(context))
      ..layout(maxWidth: width);
    final size = painter.size;
    painter.dispose();
    return size;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final quote =
            widget.loading ? widget.quote ?? _geometryQuote : widget.quote;
        final rawTotal = quote == null ? '—' : adIqd(quote.totalIqd);
        // The white surface spans the screen; tablet content still aligns with
        // the form's 600dp maximum content width and 20dp phone gutters.
        final innerWidth = math.min(box.maxWidth, 640.0);
        final contentWidth =
            math.max(1.0, innerWidth - 2 * TikTokAdTokens.gutter);
        final totalSize =
            _measure(context, rawTotal, TikTokAdTokens.totalAmount);
        final labelSize =
            _measure(context, 'کۆی گشتی', TikTokAdTokens.totalLabel);
        final stacked = totalSize.width + labelSize.width + 60 > contentWidth;
        // Share an exact amount column across every detail row and the total.
        var amountWidth = totalSize.width;
        if (quote != null) {
          for (final value in [
            adIqd(quote.sponsorIqd),
            adIqd(quote.serviceIqd),
            if (quote.promoIqd + quote.levelIqd > 0)
              adIqd(quote.promoIqd + quote.levelIqd, discount: true)
          ]) {
            amountWidth = math.max(amountWidth,
                _measure(context, value, TikTokAdTokens.priceAmount).width);
          }
        }
        amountWidth = math.min(amountWidth,
            stacked ? contentWidth * .53 : contentWidth - 60 - labelSize.width);
        amountWidth = math.max(20, amountWidth);
        final labelPainter = TextPainter(
          text: const TextSpan(
              text: 'کرێی خزمەتگوزاری', style: TikTokAdTokens.priceLabel),
          textDirection: TextDirection.rtl,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final stackRows =
            contentWidth - amountWidth - 12 < labelPainter.minIntrinsicWidth;
        labelPainter.dispose();
        final labelHeight = _measure(context, 'کۆی گشتی',
                TikTokAdTokens.totalLabel, math.max(1, contentWidth - 48))
            .height;
        final headerHeight = math.max(
            TikTokAdTokens.priceCollapsedHeight,
            stacked
                ? math.max(48.0, labelHeight) + 4 + totalSize.height + 16
                : math.max(48.0, math.max(labelSize.height, totalSize.height)) +
                    16);
        final maxHeight = math.max(
            headerHeight + 48, math.min(360.0, widget.viewportHeight * .62));
        final duration = MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : TikTokAdTokens.priceTransition;
        final disclosure = AnimatedOpacity(
          // The reference loading state contains just the right-hand label and
          // left-hand spinner. Keep the disclosure's geometry and semantics.
          opacity: widget.loading ? 0 : 1,
          alwaysIncludeSemantics: true,
          duration: duration,
          child: IconButton(
            key: const ValueKey('sticky-price-disclosure'),
            tooltip: widget.expanded ? 'داخستن' : 'پوختەی نرخ',
            onPressed: widget.onToggle,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            padding: const EdgeInsets.all(12),
            icon: AnimatedRotation(
                turns: widget.expanded ? .5 : 0,
                duration: duration,
                curve: Curves.easeOutCubic,
                child: const Icon(Icons.expand_less,
                    size: 22, color: TikTokAdTokens.blue)),
          ),
        );
        const label = ProxoText('کۆی گشتی',
            key: ValueKey('sticky-price-label'),
            style: TikTokAdTokens.totalLabel,
            textAlign: TextAlign.right);
        final total = SizedBox(
          key: const ValueKey('sticky-price-amount-area'),
          height: totalSize.height,
          width: stacked ? contentWidth : amountWidth,
          child: Align(
            alignment: Alignment.centerLeft,
            child: widget.loading
                ? const SizedBox(
                    key: ValueKey('sticky-price-loading'),
                    width: 20,
                    height: 20,
                    child: CupertinoActivityIndicator(
                        radius: 10, color: TikTokAdTokens.blue))
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ProxoText(
                        widget.error == null && widget.quote != null
                            ? rawTotal
                            : '—',
                        key: const ValueKey('sticky-price-total'),
                        softWrap: false,
                        textAlign: TextAlign.left,
                        style: TikTokAdTokens.totalAmount)),
          ),
        );
        return Container(
          key: const ValueKey('sticky-ad-price'),
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: TikTokAdTokens.priceRadius,
              boxShadow: TikTokAdTokens.priceShadow),
          foregroundDecoration: const BoxDecoration(
              border: Border(top: BorderSide(color: TikTokAdTokens.line))),
          child: Align(
            alignment: Alignment.bottomCenter,
            heightFactor: 1,
            child: SizedBox(
              width: innerWidth,
              child: AnimatedSize(
                duration: duration,
                curve: Curves.easeOutCubic,
                alignment: Alignment.bottomCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: TikTokAdTokens.gutter),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.expanded)
                            Flexible(
                                child: Scrollbar(
                                    controller: _detailsScroll,
                                    thumbVisibility: stackRows,
                                    thickness: 3,
                                    child: SingleChildScrollView(
                                      key: const ValueKey(
                                          'sticky-price-details'),
                                      controller: _detailsScroll,
                                      padding: const EdgeInsets.only(top: 16),
                                      child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            if (widget.error != null &&
                                                !widget.loading) ...[
                                              ProxoText(widget.error!,
                                                  style: TikTokAdTokens.helper
                                                      .copyWith(
                                                          color: const Color(
                                                              0xFFB74956))),
                                              Align(
                                                  alignment:
                                                      AlignmentDirectional
                                                          .centerEnd,
                                                  child: TextButton(
                                                      onPressed: widget.onRetry,
                                                      child: const ProxoText(
                                                          'دووبارە پشکنین',
                                                          translate: true))),
                                            ] else if (quote != null)
                                              AdPriceDetails(
                                                  quote: quote,
                                                  showTotal: false,
                                                  balanced: true,
                                                  stackRows: stackRows,
                                                  loading: widget.loading,
                                                  amountWidth: amountWidth,
                                                  leadingWidth: 0)
                                            else
                                              const SizedBox(
                                                  height: 54,
                                                  child: Align(
                                                      alignment:
                                                          Alignment.centerRight,
                                                      child: ProxoText(
                                                          'نرخ هێشتا بەردەست نییە',
                                                          style: TikTokAdTokens
                                                              .helper))),
                                          ]),
                                    ))),
                          if (widget.expanded)
                            const Divider(
                                key: ValueKey('sticky-price-divider'),
                                height: 24,
                                thickness: 1,
                                color: TikTokAdTokens.fieldLine),
                          ConstrainedBox(
                              key: const ValueKey('sticky-price-header'),
                              constraints:
                                  BoxConstraints(minHeight: headerHeight),
                              child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  excludeFromSemantics: true,
                                  onTap: widget.onToggle,
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    child: stacked
                                        ? Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                                Row(children: [
                                                  const Expanded(child: label),
                                                  disclosure
                                                ]),
                                                const SizedBox(height: 4),
                                                total
                                              ])
                                        : Row(
                                            textDirection: TextDirection.ltr,
                                            children: [
                                                total,
                                                disclosure,
                                                const SizedBox(width: 12),
                                                const Expanded(child: label)
                                              ]),
                                  ))),
                        ]),
                  ),
                ),
              ),
            ),
          ),
        );
      });
}
