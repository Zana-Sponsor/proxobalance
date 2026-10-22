import '../l10n/proxo_strings.dart';
import 'package:flutter/material.dart';

import '../services/ad_submission.dart';
import '../theme/app_theme.dart';
import '../theme/proxo_surface.dart';
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

  static TextStyle text(BuildContext context, {Color color = ink}) =>
      ProxoSurface.body.copyWith(color: color);
  static TextStyle heading(BuildContext context) => ProxoSurface.section;

  static ThemeData theme(BuildContext context) {
    final base = Theme.of(context);
    TextStyle? normal(TextStyle? s) => s?.copyWith(fontWeight: FontWeight.w400);
    final t = base.textTheme;
    return base.copyWith(
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
  }
}

class AdFormSection extends StatelessWidget {
  final String title;
  final Widget child;
  final String? subtitle;
  const AdFormSection(
      {super.key, required this.title, required this.child, this.subtitle});
  @override
  Widget build(BuildContext context) => Container(
        padding: AdUi.cardPadding,
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: AdUi.radius,
            boxShadow: AdUi.cardShadow),
        child: Material(
            type: MaterialType.transparency,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProxoText(title,
                      translate: true,
                      style: AdUi.heading(context),
                      textAlign: TextAlign.right),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    ProxoText(subtitle!,
                        translate: true,
                        style: AdUi.text(context, color: AdUi.secondary)),
                  ],
                  const SizedBox(height: 20),
                  child,
                ])),
      );
}

class AdChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const AdChoice(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: AdUi.controlRadius,
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                constraints: const BoxConstraints(minHeight: 48),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                    color: selected ? AppColors.accentSoft : Colors.white,
                    borderRadius: AdUi.controlRadius,
                    border: Border.all(
                        color:
                            selected ? AdUi.selectedLine : AdUi.controlLine)),
                child: Center(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: ProxoText(label,
                        translate: true,
                        textAlign: TextAlign.center,
                        style: AdUi.text(context,
                            color: selected ? AdUi.blue : AdUi.ink))),
              ),
            )),
      );
}

class AdPriceDetails extends StatelessWidget {
  final AdQuote quote;
  final bool showTotal;
  const AdPriceDetails({super.key, required this.quote, this.showTotal = true});
  @override
  Widget build(BuildContext context) => Column(children: [
        AdValueRow(label: 'نرخی لاوەکی', value: adIqd(quote.sponsorIqd)),
        const SizedBox(height: 12),
        AdValueRow(label: 'کرێی خزمەتگوزاری', value: adIqd(quote.serviceIqd)),
        const SizedBox(height: 12),
        AdValueRow(label: 'ماوەی ڕیکلام', value: '${quote.days} ڕۆژ'),
        if (quote.promoUsd > 0 && quote.promoIqd > 0) ...[
          const SizedBox(height: 12),
          AdValueRow(
              key: const ValueKey('coupon-discount'),
              label: 'داشکاندن',
              value: adIqd(quote.promoIqd, discount: true),
              color: AdUi.green),
        ],
        if (quote.levelUsd > 0 && quote.levelIqd > 0) ...[
          const SizedBox(height: 12),
          AdValueRow(
              label: 'داشکاندن',
              value: adIqd(quote.levelIqd, discount: true),
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
          final style = AdUi.text(context, color: color)
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
            style: style.copyWith(color: valueColor ?? color),
            textAlign: TextAlign.left,
          );
          final labelText = ProxoText(
            label,
            translate: true,
            style: style.copyWith(
                fontSize: emphasis ? 15 : 13,
                color: color == AdUi.ink ? AdUi.secondary : color),
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
