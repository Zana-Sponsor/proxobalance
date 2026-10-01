import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
//   • ڕەنگی سەردێر و دوگمەی PDF یەک تۆکنە: `accent` = #046CFA.
//   • کارت: سپی، گۆشەی خڕی 16dp، بێ سنوور، سێبەری زۆر نەرم.
// ═════════════════════════════════════════════════════════════════════════════

abstract final class ReceiptTokens {
  // User-selected Rabar_021, requested at normal Flutter weight (w400).
  // The supplied font itself has Bold outlines/metadata; w400 does not
  // manufacture a Regular face or alter those outlines.
  static const String fontFamily = 'Rabar';
  // ── ڕەنگ ─────────────────────────────────────────────────────────────────
  /// White receipt page; the white card is separated only by its soft shadow.
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
  static const Color label = ink;
  static const Color title = ink; // shared neutral for titles and values
  static const Color divider = Color(0xFFE5E7EB);
  static const Color positive = Color(0xFF15803D); // + / داشکاندن
  static const Color negative = Color(0xFFDC2626); // -

  /// سێبەری زۆر نەرم — بەرزبوونەوەیەکی سووک، نەک سێبەرێکی دیار.
  static const List<BoxShadow> cardShadow = <BoxShadow>[
    BoxShadow(color: Color(0x0F000000), blurRadius: 18, offset: Offset(0, 5)),
  ];

  // ── AppBar ───────────────────────────────────────────────────────────────
  static const double iconSize = 16;
  static const double iconBox = 20;
  static const double barHeight = 56;
  static const double barTap = 44;
  static const double barSidePad = 6;

  // ── پەڕە و کارت ──────────────────────────────────────────────────────────
  static const double gutter = 16;
  // Retained for the history list; receipt cards use all available width.
  static const double contentMaxWidth = 398;
  static const double pageTop = 16;
  static const double pageBottom = 28;
  static const double cardRadius = 16;
  static const double cardVerticalPadding = 20;

  /// Measured reference canvas. One proportional transform preserves every
  /// fractional coordinate; rounding individual gaps would accumulate drift.
  static const double referenceWidth = 393;
  static double pageGutter(double width) => width * gutter / referenceWidth;
  static double cardInset(double width) => 16;

  // ── جیاکەرەوە ─────────────────────────────────────────────────────────────
  /// Divider inset within the responsive card padding.
  static const double dividerInset = 8;
  static const double dividerThickness = 1;

  // ── ڕیتمی ستوونی ─────────────────────────────────────────────────────────
  static const double contentToDivider = 12;
  static const double dividerToContent = 12;
  static const double headingToRow = 12;
  static const double rowToRow = 8;
  static const double labelToValue = 8;
  static const double rowMinHeight = 20;
  static const double rowVerticalPadding = 2;
  static const double labelMaxFraction = 0.4;

  // ── سەرووی پسوولە ────────────────────────────────────────────────────────
  static const double logoHeight = 18;
  static const String logoAsset = 'assets/images/proxo_logo.png';

  // ── دوگمەی PDF ───────────────────────────────────────────────────────────
  static const double cardToButton = 20;
  static const double buttonHeight = 48;
  static const double buttonRadius = 12;

  // ── تایپۆگرافی — قەبارەی دیاریکراو، هەمووی w400 ──────────────────────────
  static const FontWeight weight = FontWeight.w400;

  static TextStyle _s(double size, Color color, {double height = 1.25}) =>
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

  // Compact scale requested after the V2 review. This supersedes the original
  // spec's larger type table and is shared by both receipt detail screens.
  static const double appBarTitleSize = 13;
  static const double receiptTitleSize = 13;
  static const double sectionTitleSize = 13;
  static const double labelSize = 11;
  static const double valueSize = 11;
  static const double totalSize = 12;
  static const double uidSize = valueSize;
  static const double pdfButtonSize = 12;

  static final TextStyle barTitle = _s(appBarTitleSize, title, height: 1.25);
  static final TextStyle receiptTitle = _s(receiptTitleSize, title);
  static final TextStyle heading = _s(sectionTitleSize, accent);
  static final TextStyle rowLabel = _s(labelSize, label);
  static final TextStyle rowValue = _s(valueSize, ink);
  static final TextStyle uidValue = _s(uidSize, ink);
  static final TextStyle totalValue = _s(totalSize, ink);
  static final TextStyle discountValue = _s(valueSize, ink);
  static final TextStyle button = _s(pdfButtonSize, onAccent, height: 1.20);

  /// سنووری قەبارەی نووسینی سیستەم — تا 1.3× بە بێ تێکچوونی دیزاین.
  static const double minTextScale = 1.0;
  static const double maxTextScale = 1.3;
}

// ─────────────────────────────────────────────────────────────────────────────
// ReceiptAppBar — directional Back, physically centered title.
// ─────────────────────────────────────────────────────────────────────────────

class ReceiptAppBar extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final String? backTooltip;
  final Widget? action;

  const ReceiptAppBar({
    super.key,
    required this.title,
    required this.onBack,
    this.backTooltip,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.paddingOf(context).top;
    final titlePainter = TextPainter(
      text: TextSpan(text: title, style: ReceiptTokens.barTitle),
      textDirection: TextDirection.rtl,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(
        maxWidth: (MediaQuery.sizeOf(context).width -
                2 * (ReceiptTokens.barTap + ReceiptTokens.barSidePad + 4))
            .clamp(1.0, double.infinity));
    final barHeight = (titlePainter.height + 16)
        .clamp(ReceiptTokens.barHeight, double.infinity);
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
              child: Text(
                title,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: ReceiptTokens.barTitle,
              ),
            ),
          ),
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
                  tooltip: backTooltip,
                  icon: ReceiptIcon(
                    Directionality.of(context) == TextDirection.ltr
                        ? Icons.arrow_back_ios_rounded
                        : Icons.arrow_forward_ios_rounded,
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
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          width: constraints.maxWidth,
          child: FittedBox(
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: ReceiptTokens.referenceWidth,
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
            parent: AlwaysScrollableScrollPhysics()),
        padding: EdgeInsets.only(
            bottom: ReceiptTokens.pageBottom +
                MediaQuery.paddingOf(context).bottom),
        children: children,
      );
}

/// Aligns the separate PDF button with the card inside the capture surface.
class ReceiptWidth extends StatelessWidget {
  final Widget child;
  const ReceiptWidth({super.key, required this.child});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => Padding(
          padding: EdgeInsets.symmetric(
              horizontal: ReceiptTokens.pageGutter(constraints.maxWidth)),
          child: SizedBox(width: double.infinity, child: child),
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
    return Row(
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.start,
            style: ReceiptTokens.receiptTitle,
          ),
        ),
        const SizedBox(width: ReceiptTokens.labelToValue),
        Image.asset(
          ReceiptTokens.logoAsset,
          height: ReceiptTokens.logoHeight,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          semanticLabel: 'Proxo',
        ),
      ],
    );
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ReceiptTokens.headingToRow),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          text,
          style: ReceiptTokens.heading,
          textAlign: TextAlign.start,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ReceiptRow — Label لە ڕاست، Value لە چەپ
// ─────────────────────────────────────────────────────────────────────────────

class ReceiptRow extends StatelessWidget {
  final String label;
  final String value;

  /// ئاراستەی ناوەوەی بەهاکە. `ltr` بۆ UID، ژمارە، دراو، بەروار و ناوی
  /// لاتینی — بۆ ئەوەی پێچەوانە نەبنەوە. شوێنی بینراوی هەمیشە چەپە.
  final TextDirection valueDirection;
  final TextStyle? valueStyle;
  final VoidCallback? onLongPress;

  const ReceiptRow({
    super.key,
    required this.label,
    required this.value,
    this.valueDirection = TextDirection.rtl,
    this.valueStyle,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    // A common line box keeps every row (including fitted IDs and totals) at
    // the same height and alphabetic baseline. Shrinking a value never moves
    // its label or changes the spacing of the next row.
    final StrutStyle strut = StrutStyle(
      fontFamily: ReceiptTokens.fontFamily,
      fontWeight: ReceiptTokens.weight,
      fontSize: scaler.scale(ReceiptTokens.totalSize),
      height: 1.25,
      leading: 0,
      forceStrutHeight: true,
    );
    final linePainter = TextPainter(
      text: TextSpan(text: ' ', style: ReceiptTokens.totalValue),
      textDirection: TextDirection.rtl,
      textScaler: TextScaler.noScaling,
      strutStyle: strut,
      maxLines: 1,
    )..layout();
    final double rowHeight =
        (linePainter.height + ReceiptTokens.rowVerticalPadding * 2)
            .clamp(ReceiptTokens.rowMinHeight, double.infinity)
            .toDouble();
    linePainter.dispose();
    final Widget row = LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(
              text: receiptSingleLine(label), style: ReceiptTokens.rowLabel),
          textDirection: TextDirection.rtl,
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        // Labels use their natural width up to 40%. Short labels therefore
        // leave more room for complete UUIDs; long labels fit down as well.
        final double labelWidth = (painter.width + 0.5)
            .clamp(0.0, constraints.maxWidth * ReceiptTokens.labelMaxFraction)
            .toDouble();
        painter.dispose();
        return SizedBox(
          height: rowHeight,
          child: Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: labelWidth,
                child: _ReceiptFittedLine(
                  text: label,
                  direction: TextDirection.rtl,
                  alignment: TextAlign.right,
                  style: ReceiptTokens.rowLabel,
                  strut: strut,
                ),
              ),
              const SizedBox(width: ReceiptTokens.labelToValue),
              Expanded(
                child: _ReceiptFittedLine(
                  text: value,
                  direction: valueDirection,
                  alignment: TextAlign.left,
                  style: valueStyle ?? ReceiptTokens.rowValue,
                  strut: strut,
                ),
              ),
            ],
          ),
        );
      },
    );

    if (onLongPress == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: onLongPress,
      child: row,
    );
  }
}

/// Fit the complete string at layout time, never truncate or introduce breaks.
/// Measuring the actual font also preserves the shared strut/baseline, unlike
/// scaling the entire text box, which would scale its baseline and height too.
class _ReceiptFittedLine extends StatelessWidget {
  final String text;
  final TextDirection direction;
  final TextAlign alignment;
  final TextStyle style;
  final StrutStyle strut;

  const _ReceiptFittedLine({
    required this.text,
    required this.direction,
    required this.alignment,
    required this.style,
    required this.strut,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final String line = receiptSingleLine(text);
          final double naturalSize =
              MediaQuery.textScalerOf(context).scale(style.fontSize!);
          final naturalStyle = style.copyWith(fontSize: naturalSize);
          final painter = TextPainter(
            text: TextSpan(text: line, style: naturalStyle),
            textDirection: direction,
            textScaler: TextScaler.noScaling,
            maxLines: 1,
          )..layout();
          // A tiny inset absorbs floating-point glyph measurement rounding.
          // No minimum font-size floor: even very long references stay whole.
          final double fit = painter.width == 0
              ? 1
              : ((constraints.maxWidth - 0.25).clamp(0.0, double.infinity) /
                      painter.width)
                  .clamp(0.0, 1.0)
                  .toDouble();
          painter.dispose();
          return Text(
            line,
            semanticsLabel: text,
            textDirection: direction,
            textAlign: alignment,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            textScaler: TextScaler.noScaling,
            strutStyle: strut,
            style: naturalStyle.copyWith(fontSize: naturalSize * fit),
          );
        },
      );
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
          child: Icon(icon, size: ReceiptTokens.iconSize, color: color),
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
            important ? ReceiptTokens.totalValue : ReceiptTokens.rowValue,
      );
}

/// Identifiers use the exact same opposite-edge row as every other field.
/// Their full LTR value fits down on one line; copying keeps the original ID.
class ReceiptIdRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onLongPress;
  const ReceiptIdRow(
      {super.key, required this.label, required this.value, this.onLongPress});
  @override
  Widget build(BuildContext context) => ReceiptRow(
        label: label,
        value: value,
        valueDirection: TextDirection.ltr,
        valueStyle: ReceiptTokens.uidValue,
        onLongPress: onLongPress,
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
    return Semantics(
      button: true,
      label: widget.label,
      child: Material(
        color: ReceiptTokens.accent,
        borderRadius: BorderRadius.circular(ReceiptTokens.buttonRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _busy ? null : _tap,
          splashFactory: InkRipple.splashFactory,
          splashColor: const Color(0x1FFFFFFF),
          highlightColor: ReceiptTokens.accentPressed.withValues(alpha: 0.35),
          child: SizedBox(
            height: ReceiptTokens.buttonHeight,
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
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
                    : Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ReceiptTokens.button,
                      ),
              ),
            ),
          ),
        ),
      ),
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
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: ReceiptTokens.receiptTitle.copyWith(
                        color: ReceiptTokens.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
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
void showReceiptMessage(BuildContext context, String message) {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: ReceiptTokens.card,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      content: Directionality(
        textDirection: TextDirection.rtl,
        child: Text(message, style: ReceiptTokens.rowValue),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// exportReceiptPdf — PDF = هەمان کارت، pixel for pixel
// ─────────────────────────────────────────────────────────────────────────────
//
// وێنەی `RepaintBoundary`ـی کارتەکە بە ٤× دەگیرێت و دەخرێتە سەر پەڕەیەک کە
// ڕێک بە قەبارەی ReceiptSurfaceـە (1 dp = 1 pt)، لەگەڵ سێبەر و لێوار. پیتە
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
    Object? logoError;
    await precacheImage(const AssetImage(ReceiptTokens.logoAsset), context,
        onError: (error, stackTrace) => logoError = error);
    if (logoError != null || boundaryKey.currentContext == null) return false;
    await WidgetsBinding.instance.endOfFrame;
    final RenderObject? ro = boundaryKey.currentContext?.findRenderObject();
    if (ro is! RenderRepaintBoundary) return false;

    final ui.Image image = await ro.toImage(pixelRatio: 4.0);
    final ByteData? png = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    if (png == null) return false;

    final pw.MemoryImage shot = pw.MemoryImage(png.buffer.asUint8List());
    final pw.Document doc = pw.Document(
      title: title,
      author: 'Proxo',
      creator: 'Proxo',
    );
    final double w = ro.size.width;
    final double h = ro.size.height;
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(w, h, marginAll: 0),
        margin: pw.EdgeInsets.zero,
        build: (pw.Context _) =>
            pw.Image(shot, width: w, height: h, fit: pw.BoxFit.fill),
      ),
    );

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

final RegExp _rtlChar = RegExp(r'[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]');
final RegExp _ltrChar = RegExp(r'[A-Za-z\u00C0-\u024F]');

/// ئاراستەی دەقێک بەپێی یەکەم پیتی بەهێز.
TextDirection receiptDirOf(String s) {
  for (int i = 0; i < s.length; i++) {
    final String c = s[i];
    if (_rtlChar.hasMatch(c)) return TextDirection.rtl;
    if (_ltrChar.hasMatch(c)) return TextDirection.ltr;
  }
  return TextDirection.rtl;
}

/// Imported multi-line names/labels still display all words on a single line.
/// IDs and their stored/copyable values are never shortened or rewritten.
String receiptSingleLine(String text) =>
    text.replaceAll(RegExp(r'[\r\n\t\v\f\u0085\u2028\u2029]+'), ' ');

/// Compatibility helper: receipt identifiers no longer receive break markers.
String receiptBreakableUid(String uid) => uid;
