import '../l10n/proxo_strings.dart';
import 'package:flutter/material.dart';

import '../services/ad_submission.dart';
import '../theme/app_theme.dart';
import '../theme/ad_form_colors.dart';
import '../theme/proxo_surface.dart';
import '../theme/tiktok_ad_tokens.dart';
import 'proxo_text.dart';
import 'receipt/receipt_kit.dart';

abstract final class AdUi {
  static const blue = ReceiptTokens.accent;
  static const ink = ReceiptTokens.ink;
  static const secondary = AppColors.inkMuted;
  static const green = Color(0xFF157347);
  static const greenSoft = Color(0xFFECF8F0);
  static const radius = BorderRadius.all(Radius.circular(18));
  static const controlRadius = BorderRadius.all(Radius.circular(14));
  static const controlSurface = Color(0xFFFCFDFF);
  static const controlLine = Color(0xFFE8EDF4);
  static const selectedLine = Color(0xFFCCDFFF);
  static const sectionGap = ProxoSurface.sectionGap;
  static const cardPadding = EdgeInsets.all(ProxoSurface.padding);
  static const cardShadow = [
    BoxShadow(color: Color(0x0C0F172A), blurRadius: 24, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x040F172A), blurRadius: 4, offset: Offset(0, 2)),
  ];
  // A non-dense dropdown already provides a 48 dp interactive child.
  // Keep its outer inset small so single-line fields have the same rhythm,
  // while long selections can still grow without a fixed text height.
  static const dropdownDecoration = InputDecoration(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4));

  static Color blueOf(BuildContext context) =>
      AdFormColors.of(context)?.primary ?? blue;
  static Color inkOf(BuildContext context) =>
      AdFormColors.of(context)?.ink ?? ink;
  static Color secondaryOf(BuildContext context) =>
      AdFormColors.of(context)?.muted ?? secondary;
  static Color controlLineOf(BuildContext context) =>
      AdFormColors.of(context)?.line ?? controlLine;
  static Color controlSurfaceOf(BuildContext context) =>
      AdFormColors.of(context)?.surface ?? controlSurface;
  static Color selectedLineOf(BuildContext context) =>
      AdFormColors.of(context)?.selectedLine ?? selectedLine;
  static TextStyle text(BuildContext context, {Color? color}) =>
      ProxoSurface.body.copyWith(color: color ?? inkOf(context));
  static TextStyle heading(BuildContext context) =>
      ProxoSurface.section.copyWith(color: AdFormColors.of(context)?.ink);

  static ThemeData theme(BuildContext context) {
    final base = Theme.of(context);
    TextStyle? normal(TextStyle? s) => s?.copyWith(fontWeight: FontWeight.w400);
    final t = base.textTheme;
    final themed = base.copyWith(
      scaffoldBackgroundColor: Colors.white,
      colorScheme:
          base.colorScheme.copyWith(primary: blue, surface: Colors.white),
      textTheme: t.copyWith(
        displayLarge: normal(t.displayLarge),
        displayMedium: normal(t.displayMedium),
        displaySmall: normal(t.displaySmall),
        headlineLarge: normal(t.headlineLarge),
        headlineMedium: normal(t.headlineMedium),
        headlineSmall: normal(t.headlineSmall),
        titleLarge: normal(t.titleLarge),
        titleMedium: normal(t.titleMedium),
        titleSmall: normal(t.titleSmall),
        bodyLarge: normal(t.bodyLarge),
        bodyMedium: normal(t.bodyMedium),
        bodySmall: normal(t.bodySmall),
        labelLarge: normal(t.labelLarge),
        labelMedium: normal(t.labelMedium),
        labelSmall: normal(t.labelSmall),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: controlSurface,
        constraints: BoxConstraints(minHeight: 56),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(borderRadius: controlRadius),
        enabledBorder: OutlineInputBorder(
            borderRadius: controlRadius,
            borderSide: BorderSide(color: controlLine)),
        focusedBorder: OutlineInputBorder(
            borderRadius: controlRadius, borderSide: BorderSide(color: blue)),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        trackHeight: 3,
        activeTrackColor: blue,
        inactiveTrackColor: AppColors.accentSoft,
        thumbColor: blue,
        overlayColor: const Color(0x14046CFA),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
        tickMarkShape: SliderTickMarkShape.noTickMark,
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
        backgroundColor: blue,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(ProxoSurface.controlRadius))),
        textStyle: ProxoSurface.body,
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
        foregroundColor: blue,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        side: const BorderSide(color: controlLine),
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.all(Radius.circular(ProxoSurface.controlRadius))),
        textStyle: ProxoSurface.body,
      )),
    );
    return AdFormColors.of(context) == null
        ? themed
        : TikTokAdTokens.theme(themed);
  }
}

enum AdSectionStyle { card, open }

enum AdChoiceStyle { standard, primary, secondary }

class AdFormSection extends StatelessWidget {
  final String title;
  final Widget child;
  final String? subtitle;
  final AdSectionStyle style;
  const AdFormSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.style = AdSectionStyle.card,
  });
  @override
  Widget build(BuildContext context) => Container(
        padding:
            style == AdSectionStyle.open ? EdgeInsets.zero : AdUi.cardPadding,
        decoration: style == AdSectionStyle.open
            ? null
            : const BoxDecoration(
                color: Colors.white,
                borderRadius: AdUi.radius,
                boxShadow: AdUi.cardShadow,
              ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProxoText(
                title,
                translate: true,
                style: style == AdSectionStyle.open
                    ? TikTokAdTokens.heading
                    : AdUi.heading(context),
                textAlign: TextAlign.right,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                ProxoText(
                  subtitle!,
                  translate: true,
                  style: style == AdSectionStyle.open
                      ? TikTokAdTokens.helper
                      : AdUi.text(context, color: AdUi.secondary),
                ),
              ],
              SizedBox(
                  height: style == AdSectionStyle.open
                      ? TikTokAdTokens.headingGap
                      : 20),
              child,
            ],
          ),
        ),
      );
}

class AdChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? icon;
  final AdChoiceStyle style;
  final double minimumHeight;
  const AdChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.style = AdChoiceStyle.standard,
    this.minimumHeight = 48,
  });
  @override
  Widget build(BuildContext context) {
    final primary = style == AdChoiceStyle.primary;
    final scoped = style != AdChoiceStyle.standard;
    final blue = scoped
        ? (primary ? TikTokAdTokens.blue : TikTokAdTokens.secondaryBlue)
        : AdUi.blueOf(context);
    final radius = scoped ? TikTokAdTokens.controlRadius : AdUi.controlRadius;
    final foreground = primary
        ? (selected ? Colors.white : TikTokAdTokens.muted)
        : (selected
            ? blue
            : scoped
                ? TikTokAdTokens.ink
                : AdUi.ink);
    return Semantics(
      selected: selected,
      enabled: onTap != null,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            constraints: BoxConstraints(minHeight: minimumHeight),
            padding: EdgeInsets.symmetric(
                horizontal: scoped ? 12 : 16, vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? (primary
                      ? blue
                      : scoped
                          ? TikTokAdTokens.blueSoft
                          : AppColors.accentSoft)
                  : Colors.white,
              borderRadius: radius,
              border: Border.all(
                color: primary && selected
                    ? Colors.transparent
                    : selected
                        ? (scoped
                            ? TikTokAdTokens.selectedLine
                            : AdUi.selectedLineOf(context))
                        : scoped
                            ? TikTokAdTokens.line
                            : AdUi.controlLine,
              ),
              boxShadow: scoped
                  ? (selected
                      ? TikTokAdTokens.selectedShadow
                      : TikTokAdTokens.controlShadow)
                  : null,
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    IconTheme(
                      data: IconThemeData(color: foreground, size: 21),
                      child: icon!,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: TweenAnimationBuilder<Color?>(
                      tween: ColorTween(
                        end: onTap == null
                            ? (scoped
                                ? TikTokAdTokens.muted
                                : AdUi.secondaryOf(context))
                            : foreground,
                      ),
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      builder: (context, color, _) => ProxoText(
                        label,
                        translate: true,
                        textAlign: TextAlign.center,
                        style: (scoped
                                ? TikTokAdTokens.choice
                                : AdUi.text(context))
                            .copyWith(color: color ?? foreground),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdPriceDetails extends StatelessWidget {
  final AdQuote quote;
  final bool showTotal;
  final bool balanced, loading, stackRows;
  final double amountWidth, leadingWidth;
  const AdPriceDetails(
      {super.key,
      required this.quote,
      this.showTotal = true,
      this.balanced = false,
      this.loading = false,
      this.stackRows = false,
      this.amountWidth = 110,
      this.leadingWidth = 48});
  @override
  Widget build(BuildContext context) {
    if (balanced) {
      Widget row(String id, String label, String value, {Color? color}) {
        final amount = SizedBox(
            width: stackRows ? null : amountWidth,
            child: Stack(alignment: Alignment.centerLeft, children: [
              Visibility(
                  visible: !loading,
                  maintainState: true,
                  maintainAnimation: true,
                  maintainSize: true,
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: ProxoText(value,
                              key: ValueKey('price-value-$id'),
                              softWrap: false,
                              textAlign: TextAlign.left,
                              style: TikTokAdTokens.priceAmount
                                  .copyWith(color: color))))),
              if (loading)
                const SizedBox(
                    width: 36,
                    height: 6,
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            color: TikTokAdTokens.fieldLine,
                            borderRadius:
                                BorderRadius.all(Radius.circular(3))))),
            ]));
        final name = ProxoText(label,
            key: ValueKey('price-label-$id'),
            translate: true,
            textAlign: TextAlign.right,
            style: TikTokAdTokens.priceLabel.copyWith(color: color));
        if (stackRows) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [name, const SizedBox(height: 6), amount]);
        }
        return Row(
            textDirection: TextDirection.ltr,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: leadingWidth),
              amount,
              const SizedBox(width: 12),
              Expanded(child: name)
            ]);
      }

      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        row('unit', 'نرخی لاوەکی', adIqd(quote.sponsorIqd)),
        const SizedBox(height: 12),
        row('fee', 'کرێی خزمەتگوزاری', adIqd(quote.serviceIqd)),
        if (quote.promoIqd + quote.levelIqd > 0) ...[
          const SizedBox(height: 12),
          KeyedSubtree(
              key: const ValueKey('coupon-discount'),
              child: row('discount', 'داشکاندن',
                  adIqd(quote.promoIqd + quote.levelIqd, discount: true),
                  color: AdUi.green)),
        ],
      ]);
    }
    return Column(children: [
      AdValueRow(label: 'نرخی لاوەکی', value: adIqd(quote.sponsorIqd)),
      const SizedBox(height: 12),
      AdValueRow(label: 'کرێی خزمەتگوزاری', value: adIqd(quote.serviceIqd)),
      if (quote.promoIqd + quote.levelIqd > 0) ...[
        const SizedBox(height: 12),
        AdValueRow(
            key: const ValueKey('coupon-discount'),
            label: 'داشکاندن',
            value: adIqd(quote.promoIqd + quote.levelIqd, discount: true),
            color: AdUi.green),
      ],
      if (showTotal) ...[
        const Divider(height: 24, color: ReceiptTokens.divider),
        AdValueRow(
            key: const ValueKey('ad-total'),
            label: 'کۆی گشتی',
            value: adIqd(quote.totalIqd),
            color: AdUi.blue,
            emphasis: true),
      ],
    ]);
  }
}

class AdValueRow extends StatelessWidget {
  final String label, value;
  final Color color;
  final Color? valueColor;
  final bool emphasis;
  const AdValueRow(
      {super.key,
      required this.label,
      required this.value,
      this.color = AdUi.ink,
      this.valueColor,
      this.emphasis = false});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final effectiveColor =
              color == AdUi.ink ? AdUi.inkOf(context) : color;
          final style = AdUi.text(context, color: effectiveColor)
              .copyWith(fontSize: emphasis ? 16 : 14);
          double minimumWidth(String text) {
            final painter = TextPainter(
              text: TextSpan(
                  text: ProxoTextDirection.display(text), style: style),
              textDirection: ProxoTextDirection.of(text),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout();
            final width = painter.minIntrinsicWidth;
            painter.dispose();
            return width;
          }

          final valueText = ProxoText(
            value,
            style: style.copyWith(color: valueColor ?? effectiveColor),
            textAlign: TextAlign.left,
          );
          final labelText = ProxoText(
            label,
            translate: true,
            style: style.copyWith(
                fontSize: emphasis ? 15 : 13,
                color: color == AdUi.ink ? AdUi.secondaryOf(context) : color),
            textAlign: TextAlign.right,
          );
          final cellWidth = (constraints.maxWidth - 16) / 2;
          if (minimumWidth(value) > cellWidth ||
              minimumWidth(ProxoStrings.text(label)) > cellWidth) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [labelText, const SizedBox(height: 6), valueText],
            );
          }
          return Row(
            textDirection: TextDirection.ltr,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: valueText),
              const SizedBox(width: 16),
              Expanded(child: labelText),
            ],
          );
        },
      );
}
