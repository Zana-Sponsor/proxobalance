import 'package:flutter/material.dart';

import '../services/ad_submission.dart';
import '../theme/app_theme.dart';
import 'proxo_text.dart';
import 'receipt/receipt_kit.dart';

abstract final class AdUi {
  static const blue = ReceiptTokens.accent;
  static const ink = ReceiptTokens.ink;
  static const secondary = AppColors.inkMuted;
  static const green = Color(0xFF157347);
  static const greenSoft = Color(0xFFECF8F0);
  static const radius = BorderRadius.all(Radius.circular(16));

  static TextStyle text(BuildContext context, {Color color = ink}) =>
      Theme.of(context)
          .textTheme
          .bodyMedium!
          .copyWith(color: color, fontWeight: FontWeight.w400);
  static TextStyle heading(BuildContext context) => Theme.of(context)
      .textTheme
      .titleMedium!
      .copyWith(color: blue, fontWeight: FontWeight.w400);

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
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: ReceiptTokens.divider)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: blue)),
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
        backgroundColor: blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12))),
        textStyle: t.labelLarge?.copyWith(fontWeight: FontWeight.w400),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
        foregroundColor: blue,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        side: const BorderSide(color: ReceiptTokens.divider),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12))),
        textStyle: t.labelLarge?.copyWith(fontWeight: FontWeight.w400),
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
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: AdUi.radius,
            boxShadow: ReceiptTokens.cardShadow),
        child: Material(
            type: MaterialType.transparency,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProxoText(title,
                      style: AdUi.heading(context), textAlign: TextAlign.right),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    ProxoText(subtitle!,
                        style: AdUi.text(context, color: AdUi.secondary)),
                  ],
                  const SizedBox(height: 18),
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
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                    color: selected ? AppColors.accentSoft : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: selected ? AdUi.blue : ReceiptTokens.divider)),
                child: ProxoText(label,
                    textAlign: TextAlign.center,
                    style: AdUi.text(context,
                        color: selected ? AdUi.blue : AdUi.ink)),
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
        AdValueRow(label: 'نرخی سەرەتایی', value: adIqd(quote.sponsorIqd)),
        const SizedBox(height: 12),
        AdValueRow(label: 'ماوەی ڕیکلام', value: '${quote.days} ڕۆژ'),
        const SizedBox(height: 12),
        AdValueRow(label: 'تێچووی خزمەتگوزاری', value: adIqd(quote.serviceIqd)),
        if (quote.promoUsd > 0 && quote.promoIqd > 0) ...[
          const SizedBox(height: 12),
          Container(
              key: const ValueKey('coupon-discount'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AdUi.greenSoft,
                  borderRadius: BorderRadius.circular(10)),
              child: AdValueRow(
                  label: 'داشکاندنی کۆبۆن',
                  value: adIqd(quote.promoIqd, discount: true),
                  color: AdUi.green)),
        ],
        if (quote.levelUsd > 0 && quote.levelIqd > 0) ...[
          const SizedBox(height: 12),
          AdValueRow(
              label: 'داشکاندنی ئاست',
              value: adIqd(quote.levelIqd, discount: true),
              color: AdUi.green),
        ],
        if (showTotal) ...[
          const Divider(height: 32, color: ReceiptTokens.divider),
          AdValueRow(
              key: const ValueKey('ad-total'),
              label: 'کۆی گشتی',
              value: adIqd(quote.totalIqd),
              color: AdUi.blue),
        ],
      ]);
}

class AdValueRow extends StatelessWidget {
  final String label, value;
  final Color color;
  const AdValueRow(
      {super.key,
      required this.label,
      required this.value,
      this.color = AdUi.ink});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final style = AdUi.text(context, color: color);
      double minimumWidth(String text) {
        final painter = TextPainter(
          text: TextSpan(text: ProxoTextDirection.display(text), style: style),
          textDirection: ProxoTextDirection.of(text),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final width = painter.minIntrinsicWidth;
        painter.dispose();
        return width;
      }

      final valueText = ProxoText(
        value,
        style: style,
        textAlign: TextAlign.left,
      );
      final labelText = ProxoText(
        label,
        style: style,
        textAlign: TextAlign.right,
      );
      final cellWidth = (constraints.maxWidth - 16) / 2;
      if (minimumWidth(value) > cellWidth || minimumWidth(label) > cellWidth) {
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
