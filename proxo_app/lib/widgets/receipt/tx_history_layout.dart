import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'receipt_kit.dart' show ReceiptAppBar, ReceiptIcon, receiptDirOf;
import 'package:proxo_app/widgets/proxo_text.dart';

/// History keeps its existing regular typography and spacious list geometry.
/// Receipt-only styling must not change this screen or its loading/error states.
abstract final class TxHistoryTokens {
  static const String fontFamily = 'RabarAuthRegular';
  static const String fontAsset = 'assets/fonts/Rabar_022.ttf';

  static const Color page = Color(0xFFFFFFFF);
  static const Color bar = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color accent = Color(0xFF046CFA);
  static const Color accentPressed = Color(0xFF035ED9);
  static const Color onAccent = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF111111);
  static const Color label = Color(0xFF667085);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color positive = Color(0xFF15803D);
  static const Color negative = Color(0xFFDC2626);
  static const List<BoxShadow> cardShadow = <BoxShadow>[
    BoxShadow(color: Color(0x060F172A), blurRadius: 12, offset: Offset(0, 3)),
  ];

  static const double iconSize = 22;
  static const double gutter = 20;
  static const double contentMaxWidth = 600;
  static const double pageTop = 20;
  static const double pageBottom = 28;
  static const double cardRadius = 16;
  static const double cardInset = 16;
  static const double cardVerticalPadding = 16;
  static const double rowMinHeight = 20;
  static const double rowToRow = 8;
  static const double headingToRow = 12;
  static const double labelToValue = 8;
  static const double cardToButton = 24;
  static const double buttonHeight = 48;
  static const double buttonRadius = 18;

  static TextStyle _s(double size, Color color, {double height = 1.5}) =>
      TextStyle(
        inherit: false,
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.normal,
        color: color,
        height: height,
        decoration: TextDecoration.none,
        letterSpacing: 0,
      );

  static final TextStyle rowLabel = _s(13, label);
  static final TextStyle rowValue = _s(14, ink);
  static final TextStyle amountValue = _s(20, ink);
  static final TextStyle stateTitle = _s(16, ink, height: 1.4);
  static final TextStyle button = _s(14, onAccent);
}

/// History styling with LTR controls and correctly shaped Kurdish text.
class TxHistoryLayout extends StatelessWidget {
  final String title;
  final String backLabel;
  final String refreshLabel;
  final VoidCallback? onBack;
  final VoidCallback? onRefresh;
  final bool refreshing;
  final Widget body;

  const TxHistoryLayout({
    super.key,
    required this.title,
    required this.backLabel,
    required this.refreshLabel,
    required this.onBack,
    required this.onRefresh,
    required this.refreshing,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: TxHistoryTokens.bar,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(
          backgroundColor: TxHistoryTokens.page,
          body: SafeArea(
              top: false,
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ReceiptAppBar(
                    title: title,
                    translateTitle: false,
                    onBack: onBack,
                    backTooltip: backLabel,
                    action: IconButton(
                      tooltip: refreshLabel,
                      onPressed: onRefresh,
                      icon: refreshing
                          ? const SizedBox(
                              width: TxHistoryTokens.iconSize,
                              height: TxHistoryTokens.iconSize,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.6,
                                color: TxHistoryTokens.accent,
                              ),
                            )
                          : ReceiptIcon(
                              Icons.refresh_rounded,
                              color: onRefresh == null
                                  ? TxHistoryTokens.divider
                                  : TxHistoryTokens.accent,
                            ),
                    ),
                  ),
                  Expanded(child: body),
                ],
              )),
        ),
      ),
    );
  }
}

/// Preserves the reference's physical order: amount, time, date.
class TxHistoryCard extends StatelessWidget {
  final String? label, status;
  final String date;
  final String time;
  final String amount;
  final Color amountColor;
  final VoidCallback onTap;

  const TxHistoryCard({
    super.key,
    this.label,
    this.status,
    required this.date,
    required this.time,
    required this.amount,
    required this.amountColor,
    required this.onTap,
  });

  static const double gap = TxHistoryTokens.rowToRow;
  static const EdgeInsets padding = EdgeInsets.all(TxHistoryTokens.gutter);
  static const BorderRadius radius =
      BorderRadius.all(Radius.circular(TxHistoryTokens.cardRadius));

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          color: TxHistoryTokens.card,
          borderRadius: radius,
          boxShadow: TxHistoryTokens.cardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            splashColor: const Color(0x0A046CFA),
            highlightColor: const Color(0x08000000),
            child: Padding(
              padding: padding,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: TxHistoryTokens.rowMinHeight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (label != null) ...[
                      ProxoText(label!,
                          textAlign: TextAlign.right,
                          style: TxHistoryTokens.rowLabel),
                      const SizedBox(height: TxHistoryTokens.rowToRow),
                    ],
                    ProxoText(amount,
                        textAlign: TextAlign.left,
                        style: TxHistoryTokens.amountValue
                            .copyWith(color: amountColor)),
                    if (status != null) ...[
                      const SizedBox(height: TxHistoryTokens.rowToRow),
                      ProxoText(status!,
                          textAlign: TextAlign.right,
                          style: TxHistoryTokens.rowLabel),
                    ],
                    const SizedBox(height: TxHistoryTokens.headingToRow),
                    Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        alignment: WrapAlignment.spaceBetween,
                        spacing: TxHistoryTokens.labelToValue,
                        runSpacing: TxHistoryTokens.rowToRow,
                        children: [
                          ProxoText(time,
                              textDirection: TextDirection.ltr,
                              style: TxHistoryTokens.rowLabel
                                  .copyWith(color: const Color(0xFF6B7280))),
                          ProxoText(date,
                              textDirection: TextDirection.ltr,
                              style: TxHistoryTokens.rowValue),
                        ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

/// A two-line amount/metadata placeholder; loaded labels can expand naturally.
class TxHistorySkeletonList extends StatelessWidget {
  const TxHistorySkeletonList({super.key});

  Widget _bar(double width, Alignment alignment) => Expanded(
        child: Align(
          alignment: alignment,
          child: FractionallySizedBox(
            widthFactor: width,
            child: Container(
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFFEEF0F3),
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          TxHistoryTokens.gutter,
          TxHistoryTokens.pageTop,
          TxHistoryTokens.gutter,
          TxHistoryTokens.pageBottom,
        ),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: TxHistoryCard.gap),
        itemBuilder: (_, __) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TxHistoryTokens.contentMaxWidth,
            ),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: TxHistoryTokens.card,
                borderRadius: TxHistoryCard.radius,
                boxShadow: TxHistoryTokens.cardShadow,
              ),
              child: Padding(
                padding: TxHistoryCard.padding,
                child: SizedBox(
                  height: TxHistoryTokens.rowMinHeight * 2 +
                      TxHistoryTokens.headingToRow,
                  child: Row(
                    children: <Widget>[
                      _bar(0.7, Alignment.centerLeft),
                      _bar(0.5, Alignment.center),
                      _bar(0.8, Alignment.centerRight),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

/// History empty/error rendering stays independent of receipt restoration.
class TxHistoryStateView extends StatelessWidget {
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const TxHistoryStateView({
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
          horizontal: TxHistoryTokens.gutter,
          vertical: 24,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: TxHistoryTokens.contentMaxWidth,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Preserve the history screen's existing state-card styling.
              _TxHistoryStateCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ProxoText(
                      title,
                      translate: true,
                      textAlign: TextAlign.center,
                      style: TxHistoryTokens.stateTitle.copyWith(
                        color: TxHistoryTokens.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ProxoText(
                      message,
                      textAlign: TextAlign.center,
                      style: TxHistoryTokens.rowValue,
                    ),
                  ],
                ),
              ),
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(height: TxHistoryTokens.cardToButton),
                _TxHistoryRetryButton(
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

class _TxHistoryStateCard extends StatelessWidget {
  final Widget child;

  const _TxHistoryStateCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: TxHistoryTokens.card,
        borderRadius: BorderRadius.circular(TxHistoryTokens.cardRadius),
        boxShadow: TxHistoryTokens.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TxHistoryTokens.cardInset,
          vertical: TxHistoryTokens.cardVerticalPadding,
        ),
        child: child,
      ),
    );
  }
}

class _TxHistoryRetryButton extends StatefulWidget {
  final String label;
  final Future<void> Function() onPressed;

  const _TxHistoryRetryButton({
    required this.label,
    required this.onPressed,
  });

  @override
  State<_TxHistoryRetryButton> createState() => _TxHistoryRetryButtonState();
}

class _TxHistoryRetryButtonState extends State<_TxHistoryRetryButton> {
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
          text: TextSpan(text: widget.label, style: TxHistoryTokens.button),
          textDirection: receiptDirOf(widget.label),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(
            // Match the text-only button's actual horizontal padding.
            maxWidth: (constraints.maxWidth - 32).clamp(
              1.0,
              double.infinity,
            ),
          );
        final buttonHeight = (painter.height + TxHistoryTokens.headingToRow * 2)
            .clamp(TxHistoryTokens.buttonHeight, double.infinity);
        painter.dispose();
        return Semantics(
          button: true,
          enabled: !_busy,
          label: widget.label,
          child: Material(
            color: TxHistoryTokens.accent,
            borderRadius: BorderRadius.circular(TxHistoryTokens.buttonRadius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _busy ? null : _tap,
              splashFactory: InkRipple.splashFactory,
              splashColor: const Color(0x1FFFFFFF),
              highlightColor: TxHistoryTokens.accentPressed.withValues(
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
                                TxHistoryTokens.onAccent,
                              ),
                            ),
                          )
                        : ProxoText(
                            widget.label,
                            softWrap: true,
                            textAlign: TextAlign.center,
                            style: TxHistoryTokens.button,
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
