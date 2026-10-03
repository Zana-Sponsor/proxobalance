import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'receipt_kit.dart';
import 'package:proxo_app/widgets/proxo_text.dart';

/// Receipt styling with LTR controls and correctly shaped Kurdish text.
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
    final mq = MediaQuery.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: ReceiptTokens.bar,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(
              minScaleFactor: ReceiptTokens.minTextScale,
              maxScaleFactor: ReceiptTokens.maxTextScale,
            ),
          ),
          child: Scaffold(
            backgroundColor: ReceiptTokens.page,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ReceiptAppBar(
                  title: title,
                  onBack: onBack,
                  backTooltip: backLabel,
                  action: IconButton(
                    tooltip: refreshLabel,
                    onPressed: onRefresh,
                    icon: refreshing
                        ? const SizedBox(
                            width: ReceiptTokens.iconSize,
                            height: ReceiptTokens.iconSize,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.6,
                              color: ReceiptTokens.accent,
                            ),
                          )
                        : ReceiptIcon(
                            Icons.refresh_rounded,
                            color: onRefresh == null
                                ? ReceiptTokens.divider
                                : ReceiptTokens.accent,
                          ),
                  ),
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Preserves the reference's physical order: amount, time, date.
class TxHistoryCard extends StatelessWidget {
  final String date;
  final String time;
  final String amount;
  final Color amountColor;
  final VoidCallback onTap;

  const TxHistoryCard({
    super.key,
    required this.date,
    required this.time,
    required this.amount,
    required this.amountColor,
    required this.onTap,
  });

  static const double gap = ReceiptTokens.rowToRow;
  static const EdgeInsets padding = EdgeInsets.all(ReceiptTokens.gutter);
  static const BorderRadius radius =
      BorderRadius.all(Radius.circular(ReceiptTokens.cardRadius));

  Widget _value(String text, Alignment alignment, TextStyle style) => Expanded(
        child: Align(
          alignment: alignment,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: ProxoText(
              text,
              textDirection: TextDirection.ltr,
              maxLines: 1,
              softWrap: false,
              style: style,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          color: ReceiptTokens.card,
          borderRadius: radius,
          boxShadow: ReceiptTokens.cardShadow,
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
                  minHeight: ReceiptTokens.rowMinHeight,
                ),
                child: Row(
                  textDirection: TextDirection.ltr,
                  children: <Widget>[
                    _value(amount, Alignment.centerLeft,
                        ReceiptTokens.rowValue.copyWith(color: amountColor)),
                    _value(
                        time,
                        Alignment.center,
                        ReceiptTokens.rowLabel
                            .copyWith(color: const Color(0xFF6B7280))),
                    _value(date, Alignment.centerRight, ReceiptTokens.rowValue),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

/// The loading rows occupy the same bounds as the finished cards.
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
          ReceiptTokens.gutter,
          ReceiptTokens.pageTop,
          ReceiptTokens.gutter,
          ReceiptTokens.pageBottom,
        ),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: TxHistoryCard.gap),
        itemBuilder: (_, __) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ReceiptTokens.contentMaxWidth,
            ),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: ReceiptTokens.card,
                borderRadius: TxHistoryCard.radius,
                boxShadow: ReceiptTokens.cardShadow,
              ),
              child: Padding(
                padding: TxHistoryCard.padding,
                child: SizedBox(
                  height: ReceiptTokens.rowMinHeight,
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
