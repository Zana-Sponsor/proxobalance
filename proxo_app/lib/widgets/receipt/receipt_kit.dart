import '../../theme/app_locale.dart';
import '../../l10n/proxo_strings.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:proxo_app/widgets/proxo_text.dart';
import '../proxo_symbol.dart';
import '../proxo_toast.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Receipt Kit — دیزاین سیستەمی هاوبەشی پسوولەکان
// ═════════════════════════════════════════════════════════════════════════════
//
// تاقە سەرچاوەی هەموو ژمارەیەکی دیزاینی پسوولە: AppBar، کارت، جیاکەرەوە،
// ڕیز، سەردێری شین و دوگمەی PDF. Ad Detail ئێستا ئەمانە بەکاردەهێنێت؛
// Transaction Detail دەبێت هەمان ئەمانە بەکاربهێنێت بۆ ئەوەی هەردوو
// شاشەکە پیکسڵ بە پیکسڵ وەک یەک بن.
//
// یاساکان (بەپێی Proxo Ad Detail — V2):
//   • هەموو دەقێک w400؛ بێ قەڵەوکردنی زیادە لە Flutter.
//   • Preserve the original blue headings and borderless white receipt.
//   • Balance regular Kurdish typography without changing the receipt identity.
// ═════════════════════════════════════════════════════════════════════════════

abstract final class ReceiptTokens {
  // The same genuinely regular Kurdish face used by the redesigned Auth UI.
  static const String fontFamily = 'RabarAuthRegular';
  static const String fontAsset = 'assets/fonts/Rabar_022.ttf';
  // ── ڕەنگ ─────────────────────────────────────────────────────────────────
  /// Original white receipt, separated by a restrained shadow.
  static const Color page = Color(0xFFFFFFFF);
  static const Color historyPage = Color(0xFFF2F2F7);
  static const Color bar = Color(0xFFFFFFFF);
  static const Color barLine = Color(0xFFF2F3F5);
  static const Color card = Color(0xFFFFFFFF);

  /// شینی سەرەکی — سەردێری بەشەکان و دوگمەی PDF (هەمان تۆکن).
  static const Color accent = Color(0xFF046CFA);
  static const Color accentPressed = Color(0xFF035ED9);
  static const Color onAccent = Color(0xFFFFFFFF);

  static const Color ink = Color(0xFF111111);
  static const Color label = Color(0xFF667085);
  static const Color title = ink; // shared neutral for titles and values
  static const Color divider = Color(0xFFE5E7EB);
  static const Color positive = Color(0xFF15803D); // + / داشکاندن
  static const Color negative = Color(0xFFDC2626); // -

  /// سێبەری زۆر نەرم — بەرزبوونەوەیەکی سووک، نەک سێبەرێکی دیار.
  static const List<BoxShadow> cardShadow = <BoxShadow>[
    BoxShadow(color: Color(0x060F172A), blurRadius: 12, offset: Offset(0, 3)),
  ];

  // ── AppBar ───────────────────────────────────────────────────────────────
  static const double iconSize = 22;
  static const double iconBox = 22;
  static const double barHeight = 56;
  static const double barTap = 48;
  static const double barSidePad = 6;

  // ── پەڕە و کارت ──────────────────────────────────────────────────────────
  static const double gutter = 20;
  // One readable content width for history and both receipt types.
  static const double contentMaxWidth = 600;
  static const double pageTop = 20;
  static const double pageBottom = 28;
  static const double cardRadius = 16;
  static const double cardVerticalPadding = 16;

  /// Measured reference canvas. One proportional transform preserves every
  /// fractional coordinate; rounding individual gaps would accumulate drift.
  static const double referenceWidth = 393;
  // Same readable column limit used by Home actions and the ad form.
  static const double receiptMaxWidth = 600;
  static const double surfaceMaxWidth = receiptMaxWidth + 2 * gutter;
  static double pageGutter(double width) => gutter;
  static double cardInset(double width) => 16;

  // ── جیاکەرەوە ─────────────────────────────────────────────────────────────
  /// Divider inset within the responsive card padding.
  static const double dividerInset = 0;
  static const double dividerThickness = 1;

  // ── ڕیتمی ستوونی ─────────────────────────────────────────────────────────
  static const double contentToDivider = 12;
  static const double dividerToContent = 11;
  static const double headingToRow = 12;
  static const double rowToRow = 8;
  static const double labelToValue = 8;
  static const double rowMinHeight = 20;
  static const double rowVerticalPadding = 2;
  static const double labelMaxFraction = 0.4;

  // ── سەرووی پسوولە ────────────────────────────────────────────────────────
  static const double logoHeight = 18;
  static const double logoWidth = 64;
  static const String logoAsset = 'assets/images/proxo_logo.png';

  // ── دوگمەی PDF ───────────────────────────────────────────────────────────
  static const double cardToButton = 24;
  static const double buttonHeight = 48;
  static const double buttonRadius = 18;

  // ── تایپۆگرافی — قەبارەی دیاریکراو، هەمووی w400 ──────────────────────────
  static const FontWeight weight = FontWeight.w400;

  static TextStyle _s(double size, Color color, {double height = 1.5}) =>
      TextStyle(
        inherit: false,
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
        fontStyle: FontStyle.normal,
        color: color,
        height: height,
        decoration: TextDecoration.none,
        letterSpacing: 0,
      );

  static const double appBarTitleSize = 18;
  static const double receiptTitleSize = 16;
  static const double sectionTitleSize = 15;
  static const double labelSize = 13;
  static const double valueSize = 14;
  static const double totalSize = 16;
  static const double uidSize = 13;
  static const double pdfButtonSize = 14;

  static final TextStyle barTitle = _s(appBarTitleSize, title, height: 1.4);
  static final TextStyle receiptTitle =
      _s(receiptTitleSize, title, height: 1.4);
  static final TextStyle heading = _s(sectionTitleSize, accent);
  static final TextStyle rowLabel = _s(labelSize, label);
  static final TextStyle rowValue = _s(valueSize, ink);
  static final TextStyle uidValue = _s(uidSize, ink);
  static final TextStyle metadataValue = _s(13, ink);
  static final TextStyle moneyValue = _s(valueSize, ink);
  static final TextStyle totalValue = _s(totalSize, ink);
  // Preserve the separate transaction-history balance summary.
  static final TextStyle historyAmountValue = _s(20, ink);
  static final TextStyle discountValue = _s(valueSize, ink);
  static final TextStyle button = _s(pdfButtonSize, onAccent, height: 1.5);

  /// سنووری قەبارەی نووسینی سیستەم — تا 1.3× بە بێ تێکچوونی دیزاین.
  static const double minTextScale = 1.0;
  static const double maxTextScale = 1.3;
}

// ─────────────────────────────────────────────────────────────────────────────
// ReceiptAppBar — directional Back, physically centered title.
// ─────────────────────────────────────────────────────────────────────────────

class ReceiptAppBar extends StatelessWidget {
  final String title;
  final bool translateTitle;
  final VoidCallback? onBack;
  final String? backTooltip;
  final Widget? action;

  const ReceiptAppBar({
    super.key,
    required this.title,
    this.translateTitle = false,
    required this.onBack,
    this.backTooltip,
    this.action,
  });

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(builder: _buildBar),
      );

  Widget _buildBar(BuildContext context, BoxConstraints constraints) {
    ProxoLocale.watch(context);
    final displayTitle = translateTitle ? ProxoStrings.text(title) : title;
    final double top = MediaQuery.paddingOf(context).top;
    final titlePainter = TextPainter(
      text: TextSpan(text: displayTitle, style: ReceiptTokens.barTitle),
      textDirection: receiptDirOf(displayTitle),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(
        maxWidth: (constraints.maxWidth -
                2 * (ReceiptTokens.barTap + ReceiptTokens.barSidePad + 4))
            .clamp(1.0, double.infinity),
      );
    final barHeight = (titlePainter.height + 16).clamp(
      ReceiptTokens.barHeight,
      double.infinity,
    );
    titlePainter.dispose();
    return Container(
      height: barHeight + top,
      padding: EdgeInsets.only(top: top),
      decoration: const BoxDecoration(
        color: ReceiptTokens.bar,
        border: Border(
          bottom: BorderSide(color: ReceiptTokens.barLine, width: 1),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // ناونیشان: بە فیزیکی لە ناوەڕاستی بارەکەدایە، نەک لە ناوەڕاستی
          // بۆشایی دوای دوگمەکە — بۆیە هەردوو لا پەدینگی یەکسانیان هەیە.
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ReceiptTokens.barTap + ReceiptTokens.barSidePad + 4,
            ),
            child: Center(
              child: ProxoText(
                displayTitle,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: ReceiptTokens.barTitle,
              ),
            ),
          ),
          if (onBack != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: ReceiptTokens.barSidePad,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: SizedBox(
                  width: ReceiptTokens.barTap,
                  height: ReceiptTokens.barTap,
                  child: IconButton(
                    onPressed: onBack,
                    tooltip: backTooltip ?? ProxoStrings.text('گەڕانەوە'),
                    icon: ReceiptIcon(
                      Directionality.of(context) == TextDirection.ltr
                          ? Icons.arrow_back_ios_rounded
                          : Icons.arrow_forward_ios_rounded,
                      color: ReceiptTokens.ink,
                    ),
                  ),
                ),
              ),
            ),
          if (action != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                end: ReceiptTokens.barSidePad,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: SizedBox(
                  width: ReceiptTokens.barTap,
                  height: ReceiptTokens.barTap,
                  child: action,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ReceiptCard — سپی، گۆشەی خڕ، بێ سنوور، سێبەری نەرم
// ─────────────────────────────────────────────────────────────────────────────

class ReceiptCard extends StatelessWidget {
  final Widget child;

  const ReceiptCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => DecoratedBox(
        decoration: BoxDecoration(
          color: ReceiptTokens.card,
          borderRadius: BorderRadius.circular(ReceiptTokens.cardRadius),
          boxShadow: ReceiptTokens.cardShadow,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: ReceiptTokens.cardInset(constraints.maxWidth),
            vertical: ReceiptTokens.cardVerticalPadding,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// The same opaque white page fragment is painted on screen and captured for
/// PDF. Its insets preserve the card's actual outer shadow, not just its fill.
class ReceiptSurface extends StatelessWidget {
  final Widget child;
  const ReceiptSurface({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: ReceiptTokens.surfaceMaxWidth,
          ),
          child: ColoredBox(
            color: ReceiptTokens.page,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                ReceiptTokens.gutter,
                ReceiptTokens.pageTop,
                ReceiptTokens.gutter,
                ReceiptTokens.cardToButton,
              ),
              child: SizedBox(width: double.infinity, child: child),
            ),
          ),
        ),
      );
}

/// Full-width viewport: the capture surface owns its exact white page insets.
class ReceiptBody extends StatelessWidget {
  final List<Widget> children;
  const ReceiptBody({super.key, required this.children});
  @override
  Widget build(BuildContext context) => ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.only(
          bottom:
              ReceiptTokens.pageBottom + MediaQuery.paddingOf(context).bottom,
        ),
        children: children,
      );
}

/// Aligns the separate PDF button with the card inside the capture surface.
class ReceiptWidth extends StatelessWidget {
  final Widget child;
  const ReceiptWidth({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: ReceiptTokens.surfaceMaxWidth,
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: ReceiptTokens.gutter),
            child: SizedBox(width: double.infinity, child: child),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// ReceiptHeader — ناونیشانی پسوولە (ڕاست) + لۆگۆی Proxo (چەپ)
// ─────────────────────────────────────────────────────────────────────────────

class ReceiptHeader extends StatelessWidget {
  final String title;

  const ReceiptHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final titleText = ProxoText(
        title,
        translate: true,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.start,
        style: ReceiptTokens.receiptTitle,
      );
      final logo = Image.asset(
        ReceiptTokens.logoAsset,
        width: ReceiptTokens.logoWidth,
        height: ReceiptTokens.logoHeight,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        semanticLabel: 'Proxo',
      );
      final painter = TextPainter(
        text: TextSpan(
            text: ProxoStrings.text(title), style: ReceiptTokens.receiptTitle),
        textDirection: TextDirection.rtl,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final stacked =
          painter.width + ReceiptTokens.logoWidth + ReceiptTokens.labelToValue >
              constraints.maxWidth;
      painter.dispose();
      if (stacked) {
        // Keep the title's full reading width at large text sizes instead of
        // forcing Kurdish/Arabic words into the space beside a fixed logo.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(alignment: Alignment.centerLeft, child: logo),
            const SizedBox(height: 12),
            titleText,
          ],
        );
      }
      return Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: titleText),
          const SizedBox(width: ReceiptTokens.labelToValue),
          logo,
        ],
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ReceiptDivider — تەنک، خۆڵەمێشی، سەرچوارگۆشە، دوور لە لێواری کارت
// ─────────────────────────────────────────────────────────────────────────────

class ReceiptDivider extends StatelessWidget {
  const ReceiptDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        ReceiptTokens.dividerInset,
        ReceiptTokens.contentToDivider,
        ReceiptTokens.dividerInset,
        ReceiptTokens.dividerToContent,
      ),
      // `ColoredBox` نەک `Divider`: هیچ گۆشەیەکی خڕ و هیچ indent ـێکی
      // theme نییە — لاکێشەیەکی ڕووتە.
      child: SizedBox(
        height: ReceiptTokens.dividerThickness,
        width: double.infinity,
        child: ColoredBox(color: ReceiptTokens.divider),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ReceiptSectionHeading — سەردێری شین
// ─────────────────────────────────────────────────────────────────────────────

class ReceiptSectionHeading extends StatelessWidget {
  final String text;

  const ReceiptSectionHeading(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: ReceiptTokens.headingToRow),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: ProxoText(text,
              style: ReceiptTokens.heading, textAlign: TextAlign.start),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// ReceiptRow — Label لە ڕاست، Value لە چەپ
// ─────────────────────────────────────────────────────────────────────────────

class ReceiptRow extends StatelessWidget {
  final String label;
  final String value;

  /// ئاراستەی ناوەوەی بەهاکە. `ltr` بۆ UID، ژمارە، دراو، بەروار و ناوی
  /// لاتینی — بۆ ئەوەی پێچەوانە نەبنەوە. شوێنی بینراوی هەمیشە چەپە.
  final TextDirection _fallbackValueDirection;
  TextDirection get valueDirection =>
      ProxoTextDirection.of(value, fallback: _fallbackValueDirection);
  final TextStyle? valueStyle;
  final VoidCallback? onLongPress;

  const ReceiptRow({
    super.key,
    required this.label,
    required this.value,
    TextDirection valueDirection = TextDirection.rtl,
    this.valueStyle,
    this.onLongPress,
  }) : _fallbackValueDirection = valueDirection;

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = valueStyle ?? ReceiptTokens.rowValue;
    final row = LayoutBuilder(
      builder: (context, constraints) {
        double naturalWidth(String text, TextStyle style, TextDirection dir) {
          final p = TextPainter(
            text: TextSpan(
              text: ProxoTextDirection.display(text),
              style: style,
            ),
            textDirection: dir,
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          final result = p.width;
          p.dispose();
          return result;
        }

        final labelWidget = ProxoText(
          label,
          textAlign: TextAlign.right,
          textDirection: receiptDirOf(label),
          softWrap: true,
          style: ReceiptTokens.rowLabel,
        );
        final valueWidget = ProxoText(
          value,
          textAlign: TextAlign.left,
          textDirection: valueDirection,
          softWrap: true,
          style: effectiveStyle,
        );
        final labelWidth = naturalWidth(
          label,
          ReceiptTokens.rowLabel,
          receiptDirOf(label),
        );
        final valueWidth = naturalWidth(value, effectiveStyle, valueDirection);
        final fits = labelWidth + ReceiptTokens.labelToValue + valueWidth <=
            constraints.maxWidth;
        return Padding(
          padding: const EdgeInsets.symmetric(
            vertical: ReceiptTokens.rowVerticalPadding,
          ),
          child: fits
              ? Row(
                  textDirection: TextDirection.rtl,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    labelWidget,
                    const SizedBox(width: ReceiptTokens.labelToValue),
                    Expanded(child: valueWidget),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    labelWidget,
                    const SizedBox(height: ReceiptTokens.rowToRow),
                    valueWidget,
                  ],
                ),
        );
      },
    );
    if (onLongPress == null) return row;
    return Semantics(
      onLongPress: onLongPress,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: onLongPress,
        child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Center(child: row)),
      ),
    );
  }
}

class ReceiptIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const ReceiptIcon(this.icon, {super.key, this.color = ReceiptTokens.ink});
  @override
  Widget build(BuildContext context) => SizedBox(
        width: ReceiptTokens.iconBox,
        height: ReceiptTokens.iconBox,
        child: Center(
          child: ProxoSymbol(
              switch (icon) {
                Icons.arrow_back_ios_rounded => ProxoSymbolName.forward,
                Icons.arrow_forward_ios_rounded => ProxoSymbolName.back,
                Icons.refresh_rounded => ProxoSymbolName.refresh,
                _ => ProxoSymbolName.info,
              },
              size: ReceiptTokens.iconSize,
              color: color),
        ),
      );
}

class ReceiptMoneyRow extends StatelessWidget {
  final String label;
  final String value;
  final bool important;
  const ReceiptMoneyRow({
    super.key,
    required this.label,
    required this.value,
    this.important = false,
  });
  @override
  Widget build(BuildContext context) => ReceiptRow(
        label: label,
        value: value,
        valueDirection: TextDirection.ltr,
        valueStyle:
            important ? ReceiptTokens.totalValue : ReceiptTokens.moneyValue,
      );
}

/// Full references get their own width. The screen scrolls long identifiers
/// horizontally at the user's text size; copy always receives the raw value.
class ReceiptIdRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onLongPress;
  const ReceiptIdRow({
    super.key,
    required this.label,
    required this.value,
    this.onLongPress,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final hasCopy =
              onLongPress != null && value.isNotEmpty && value != '—';
          double measure(
              String text, TextStyle style, TextDirection direction) {
            final painter = TextPainter(
              text: TextSpan(text: text, style: style),
              textDirection: direction,
              textScaler: MediaQuery.textScalerOf(context),
              maxLines: 1,
            )..layout();
            final width = painter.width;
            painter.dispose();
            return width;
          }

          final labelWidth =
              measure(label, ReceiptTokens.rowLabel, TextDirection.rtl);
          final valueWidth =
              measure(value, ReceiptTokens.uidValue, TextDirection.ltr);
          final inline = labelWidth +
                  valueWidth +
                  ReceiptTokens.labelToValue +
                  (hasCopy ? 48 : 0) <=
              constraints.maxWidth;
          final labelText = ProxoText(label,
              textAlign: TextAlign.right, style: ReceiptTokens.rowLabel);
          final copy = hasCopy
              ? IconButton(
                  tooltip: ProxoStrings.text('کۆپیکردن'),
                  onPressed: onLongPress,
                  constraints:
                      const BoxConstraints.tightFor(width: 48, height: 48),
                  padding: const EdgeInsets.all(14),
                  icon: const ProxoSymbol(ProxoSymbolName.copy,
                      size: 20, color: ReceiptTokens.accent),
                )
              : null;
          if (inline) {
            // Keep short public references in the original compact detail row.
            // Long references retain their full width and export marker below.
            return Row(
              textDirection: TextDirection.rtl,
              children: [
                labelText,
                const SizedBox(width: ReceiptTokens.labelToValue),
                Expanded(child: _ReceiptIdViewport(value: value)),
                if (copy != null) copy,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  Expanded(child: labelText),
                  if (copy != null) copy,
                ],
              ),
              _ReceiptIdViewport(value: value),
            ],
          );
        },
      );
}

/// Marker for export: only this viewport is re-painted with the entire value.
/// No screen state or scroll position is changed while producing the PDF.
class _ReceiptIdViewport extends StatelessWidget {
  const _ReceiptIdViewport({required this.value});
  final String value;
  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: ReceiptTokens.card,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            primary: false,
            child: ProxoText(value,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                softWrap: false,
                maxLines: 1,
                style: ReceiptTokens.uidValue),
          ),
        ),
      );
}

/// The same understated status row in advertisement and payment receipts.
class ReceiptStatusRow extends StatelessWidget {
  const ReceiptStatusRow(
      {super.key,
      required this.label,
      required this.value,
      this.positive = false,
      this.negative = false});
  final String label, value;
  final bool positive, negative;
  @override
  Widget build(BuildContext context) => ReceiptRow(
        label: label,
        value: value,
        valueStyle: ReceiptTokens.rowValue.copyWith(
            color: negative
                ? ReceiptTokens.negative
                : positive
                    ? ReceiptTokens.positive
                    : ReceiptTokens.label),
      );
}

/// Compatibility name for existing callers.
class ReceiptIdentifierRow extends ReceiptIdRow {
  const ReceiptIdentifierRow({
    super.key,
    required super.label,
    required super.value,
    super.onLongPress,
  });
}

/// ڕیزەکان بە بۆشایی `rowToRow` جیا دەکاتەوە. ڕیزی `null` هیچ شوێنێک
/// ناگرێت — نە ڕیزێکی بەتاڵ، نە بۆشایی زیادە.
class ReceiptRows extends StatelessWidget {
  final List<Widget?> rows;

  const ReceiptRows(this.rows, {super.key});

  @override
  Widget build(BuildContext context) {
    final List<Widget> visible = rows.whereType<Widget>().toList();
    final List<Widget> children = <Widget>[];
    for (int i = 0; i < visible.length; i++) {
      if (i > 0) children.add(const SizedBox(height: ReceiptTokens.rowToRow));
      children.add(visible[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ReceiptPdfButton — شین (#046CFA)، دەقی سپی، w400
// ─────────────────────────────────────────────────────────────────────────────
//
// دۆخی «کار دەکات»ی خۆی هەیە، بۆیە کاتی دروستکردنی PDF تەنها ئەم دوگمەیە
// دووبارە دروست دەکرێتەوە — نەک هەموو شاشەکە.

class ReceiptPdfButton extends StatefulWidget {
  final String label;
  final Future<void> Function() onPressed;

  const ReceiptPdfButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  State<ReceiptPdfButton> createState() => _ReceiptPdfButtonState();
}

class _ReceiptPdfButtonState extends State<ReceiptPdfButton> {
  bool _busy = false;

  Future<void> _tap() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.label, style: ReceiptTokens.button),
          textDirection: receiptDirOf(widget.label),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(
            // Match the text-only button's actual horizontal padding.
            maxWidth: (constraints.maxWidth - 32).clamp(
              1.0,
              double.infinity,
            ),
          );
        final buttonHeight = (painter.height + ReceiptTokens.headingToRow * 2)
            .clamp(ReceiptTokens.buttonHeight, double.infinity);
        painter.dispose();
        return Semantics(
          button: true,
          enabled: !_busy,
          label: widget.label,
          child: Material(
            color: ReceiptTokens.accent,
            borderRadius: BorderRadius.circular(ReceiptTokens.buttonRadius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _busy ? null : _tap,
              splashFactory: InkRipple.splashFactory,
              splashColor: const Color(0x1FFFFFFF),
              highlightColor: ReceiptTokens.accentPressed.withValues(
                alpha: 0.35,
              ),
              child: SizedBox(
                height: buttonHeight,
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 16,
                  ),
                  child: Center(
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                ReceiptTokens.onAccent,
                              ),
                            ),
                          )
                        : ProxoText(
                            widget.label,
                            softWrap: true,
                            textAlign: TextAlign.center,
                            style: ReceiptTokens.button,
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ReceiptStateView — بارنەبوون / نەدۆزرانەوە / بەتاڵ — هەمووی w400
// ─────────────────────────────────────────────────────────────────────────────

class ReceiptStateView extends StatelessWidget {
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ReceiptStateView({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: ReceiptTokens.gutter,
          vertical: 24,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: ReceiptTokens.contentMaxWidth,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Same compact card and typography as the receipt.
              ReceiptCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ProxoText(
                      title,
                      translate: true,
                      textAlign: TextAlign.center,
                      style: ReceiptTokens.receiptTitle.copyWith(
                        color: ReceiptTokens.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ProxoText(
                      message,
                      textAlign: TextAlign.center,
                      style: ReceiptTokens.rowValue,
                    ),
                  ],
                ),
              ),
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(height: ReceiptTokens.cardToButton),
                ReceiptPdfButton(
                  label: actionLabel!,
                  onPressed: () async => onAction!(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// بازنەی بارکردنی شین — هەمان شت لە هەموو پسوولەکاندا.
class ReceiptSpinner extends StatelessWidget {
  const ReceiptSpinner({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(ReceiptTokens.accent),
          ),
        ),
      );
}

/// Receipt notices use the same restrained type and the caller's locale.
void showReceiptMessage(BuildContext context, String message,
    {bool isError = true}) {
  showProxoToast(context, message, isError: isError);
}

// ─────────────────────────────────────────────────────────────────────────────
// exportReceiptPdf — shaped receipt content on printable A4 pages
// ─────────────────────────────────────────────────────────────────────────────
//
// وێنەی `RepaintBoundary`ـی کارتەکە بە ٤× دەگیرێت و دەخرێتە سەر پەڕەیەک کە
// A4 with print margins; source typography is preserved. پیتە
// کوردییەکان (ڕ ڵ ێ ۆ ە) بە هەمان shaping ـی Flutter دەردەچن.
//
// `false` دەگەڕێنێتەوە ئەگەر کارتەکە ئامادە نەبێت یان هەڵەیەک ڕووبدات.

Future<bool> exportReceiptPdf({
  required GlobalKey boundaryKey,
  required String title,
  required String fileStem,
}) async {
  try {
    // Wait for the actual header asset before capturing the same on-screen card.
    // Exporting immediately after opening a receipt must not omit its logo.
    final context = boundaryKey.currentContext;
    if (context == null) return false;
    // The shared SVG headings must be ready in an immediate export too.
    final vectors = <Future<ByteData>>[];
    void warmVectors(Element element) {
      final widget = element.widget;
      if (widget is SvgPicture) {
        vectors.add(widget.bytesLoader.loadBytes(element));
      }
      element.visitChildren(warmVectors);
    }

    (context as Element).visitChildren(warmVectors);
    Object? logoError;
    final logoReady = precacheImage(
      const AssetImage(ReceiptTokens.logoAsset),
      context,
      onError: (error, stackTrace) => logoError = error,
    );
    await Future.wait(vectors);
    await logoReady;
    if (logoError != null || boundaryKey.currentContext == null) return false;
    await WidgetsBinding.instance.endOfFrame;
    if (!context.mounted) return false;
    final RenderObject? ro = boundaryKey.currentContext?.findRenderObject();
    if (ro is! RenderRepaintBoundary) return false;

    // Keep Flutter's proven Kurdish shaping at 4x resolution. A4 pages use
    // half-inch print margins and never enlarge phone typography. Split only
    // between rendered rows; section headings stay with their first row.
    final rows = <Rect>[];
    final identifiers = <({Rect bounds, String value})>[];
    Rect? cardBounds;
    final headings = <Rect>[];
    void collect(Element element) {
      final widget = element.widget;
      if (widget is _ReceiptIdViewport) {
        final box = element.findRenderObject();
        if (box is RenderBox && box.hasSize) {
          identifiers.add((
            bounds: box.localToGlobal(Offset.zero, ancestor: ro) & box.size,
            value: widget.value
          ));
        }
      }
      if (widget is ReceiptCard) {
        final card = element.findRenderObject();
        if (card is RenderBox && card.hasSize) {
          cardBounds =
              card.localToGlobal(Offset.zero, ancestor: ro) & card.size;
        }
      }
      if (widget is ReceiptRow ||
          widget is ReceiptIdRow ||
          widget is ReceiptHeader ||
          widget is ReceiptSectionHeading) {
        final box = element.findRenderObject();
        if (box is RenderBox && box.hasSize) {
          final rect = box.localToGlobal(Offset.zero, ancestor: ro) & box.size;
          (widget is ReceiptSectionHeading ? headings : rows).add(rect);
        }
      }
      element.visitChildren(collect);
    }

    context.visitChildren(collect);
    rows.sort((a, b) => a.top.compareTo(b.top));
    final protected = <Rect>[...rows];
    for (final heading in headings) {
      final following = rows.where((row) => row.top >= heading.bottom - 0.1);
      if (following.isNotEmpty) {
        protected.add(heading.expandToInclude(following.first));
      }
    }
    final cuts = <double>[0, ro.size.height];
    for (final rect in [...rows, ...headings]) {
      final y = rect.top;
      if (!protected.any(
        (block) => y > block.top + 0.1 && y < block.bottom - 0.1,
      )) {
        cuts.add(y);
      }
    }
    cuts.sort();
    const margin = 36.0; // Standard half-inch printable inset, in PDF points.
    final availableW = PdfPageFormat.a4.width - margin * 2;
    final availableH = PdfPageFormat.a4.height - margin * 2;
    final captureLeft =
        cardBounds == null ? 0.0 : cardBounds!.left - ReceiptTokens.gutter;
    final captureWidth = cardBounds == null
        ? ro.size.width
        : cardBounds!.width + ReceiptTokens.gutter * 2;
    var scale = (availableW / captureWidth).clamp(0.0, 1.0);
    // Avoid an almost empty second page when the complete card is only a few
    // points taller than A4. Long accessible receipts keep their natural scale
    // and row-safe pagination; the small fit adjustment is bounded to 5%.
    final fullPageScale = availableH / ro.size.height;
    if (fullPageScale < scale && fullPageScale >= scale * .95) {
      scale = fullPageScale;
    }
    final source = await ro.toImage(pixelRatio: 4.0);
    final doc = pw.Document(
      title: title,
      author: 'Proxo',
      creator: 'Proxo',
      // Keep full references machine-readable alongside the shaped artwork.
      keywords: identifiers.map((identifier) => identifier.value).join(' '),
    );
    try {
      double start = 0;
      while (start < ro.size.height - 0.1) {
        final limit = start + availableH / scale;
        final eligible =
            cuts.where((cut) => cut > start + 0.1 && cut <= limit + 0.1);
        final end = eligible.isNotEmpty
            ? eligible.last
            : cuts.firstWhere((cut) => cut > start + 0.1);
        final height = end - start;
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawImageRect(
          source,
          Rect.fromLTWH(
            captureLeft * 4,
            start * 4,
            captureWidth * 4,
            height * 4,
          ),
          Rect.fromLTWH(0, 0, captureWidth * 4, height * 4),
          Paint(),
        );
        // A viewport screenshot would lose an off-screen UUID suffix.
        // Paint full identifiers into this page slice at a fitted single-line
        // size, retaining the screen's scroll state and text scaling. Compose
        // per page so export never allocates a second full-height 4x bitmap.
        canvas.save();
        canvas.scale(4);
        canvas.translate(-captureLeft, -start);
        for (final identifier in identifiers) {
          final bounds = identifier.bounds;
          if (bounds.bottom <= start || bounds.top >= end) continue;
          canvas.drawRect(bounds, Paint()..color = ReceiptTokens.card);
          final text = TextPainter(
            text:
                TextSpan(text: identifier.value, style: ReceiptTokens.uidValue),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout();
          final fit =
              text.width > bounds.width ? bounds.width / text.width : 1.0;
          canvas.save();
          canvas.translate(bounds.left,
              bounds.top + (bounds.height - text.height * fit) / 2);
          canvas.scale(fit);
          text.paint(canvas, Offset.zero);
          canvas.restore();
          text.dispose();
        }
        canvas.restore();
        final picture = recorder.endRecording();
        final slice = await picture.toImage(
          (captureWidth * 4).ceil(),
          (height * 4).ceil(),
        );
        picture.dispose();
        final bytes = await slice.toByteData(format: ui.ImageByteFormat.png);
        slice.dispose();
        if (bytes == null) return false;
        // An exceptionally tall atomic row gets its own page, never clipped.
        final pageScale = (availableH / height).clamp(0.0, scale);
        final shot = pw.MemoryImage(bytes.buffer.asUint8List());
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(margin),
            build: (_) => pw.Align(
              alignment: pw.Alignment.topCenter,
              child: pw.Image(
                shot,
                width: captureWidth * pageScale,
                height: height * pageScale,
                fit: pw.BoxFit.fill,
              ),
            ),
          ),
        );
        start = end;
      }
    } finally {
      source.dispose();
    }

    final String stem = fileStem.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'Proxo-${stem.isEmpty ? 'receipt' : stem}.pdf',
    );
    return true;
  } catch (e) {
    debugPrint('exportReceiptPdf failed — $e');
    return false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// فۆرماتەکان — هاوبەش بۆ هەموو پسوولەکان
// ─────────────────────────────────────────────────────────────────────────────

num? receiptNum(dynamic v) {
  if (v == null) return null;
  final num? parsed = v is num
      ? v
      : v is String
          ? num.tryParse(v.trim())
          : null;
  return parsed != null && parsed.isFinite ? parsed : null;
}

String _pad2(int n) => n.toString().padLeft(2, '0');

/// «21,000»
String receiptThousands(int n) {
  final String s = n.abs().toString();
  final StringBuffer b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '${n < 0 ? '-' : ''}$b';
}

/// «$15.00»
String receiptUsd(double v) {
  final int cents = (v * 100).round();
  return '\$${receiptThousands(cents ~/ 100)}.${_pad2(cents.abs() % 100)}';
}

/// «21,000 د.ع» — بە LTR پیشان بدرێت.
String formatIqd(int v, {String? sign}) =>
    '${sign ?? (v < 0 ? '-' : '')}${receiptThousands(v.abs())} د.ع';

String receiptIqd(int v, {String sign = ''}) => formatIqd(v, sign: sign);

/// کاتی بەغدا (UTC+3، بێ کاتی هاوین).
DateTime? receiptBaghdad(dynamic raw) {
  final DateTime? dt =
      raw is DateTime ? raw : DateTime.tryParse((raw ?? '').toString().trim());
  if (dt == null) return null;
  return dt.toUtc().add(const Duration(hours: 3));
}

/// «19/09/2026»
String receiptDay(DateTime b) => '${_pad2(b.day)}/${_pad2(b.month)}/${b.year}';

/// «02:45AM» یان «02:45 AM»
String receiptTime(DateTime b, {bool spaced = false}) {
  final int h12 = b.hour % 12 == 0 ? 12 : b.hour % 12;
  return '${_pad2(h12)}:${_pad2(b.minute)}${spaced ? ' ' : ''}'
      '${b.hour < 12 ? 'AM' : 'PM'}';
}

/// «19/09/2026 02:45AM»
String receiptDateTime(dynamic raw) {
  final DateTime? b = receiptBaghdad(raw);
  return b == null ? '—' : '${receiptDay(b)} ${receiptTime(b)}';
}

/// ئاراستەی دەقێک بەپێی یەکەم پیتی بەهێز.
TextDirection receiptDirOf(String s) => ProxoTextDirection.of(s);

/// Imported multi-line names/labels still display all words on a single line.
/// IDs and their stored/copyable values are never shortened or rewritten.
String receiptSingleLine(String text) =>
    text.replaceAll(RegExp(r'[\r\n\t\v\f\u0085\u2028\u2029]+'), ' ');

/// Compatibility helper: receipt identifiers no longer receive break markers.
String receiptBreakableUid(String uid) => uid;
