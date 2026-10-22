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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: ReceiptTokens.bar,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(
          backgroundColor: ReceiptTokens.page,
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

  static const double gap = ReceiptTokens.rowToRow;
  static const EdgeInsets padding = EdgeInsets.all(ReceiptTokens.gutter);
  static const BorderRadius radius =
      BorderRadius.all(Radius.circular(ReceiptTokens.cardRadius));

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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (label != null) ...[
                      ProxoText(label!,
                          textAlign: TextAlign.right,
                          style: ReceiptTokens.rowLabel),
                      const SizedBox(height: ReceiptTokens.rowToRow),
                    ],
                    ProxoText(amount,
                        textAlign: TextAlign.left,
                        style: ReceiptTokens.historyAmountValue
                            .copyWith(color: amountColor)),
                    if (status != null) ...[
                      const SizedBox(height: ReceiptTokens.rowToRow),
                      ProxoText(status!,
                          textAlign: TextAlign.right,
                          style: ReceiptTokens.rowLabel),
                    ],
                    const SizedBox(height: ReceiptTokens.headingToRow),
                    Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        alignment: WrapAlignment.spaceBetween,
                        spacing: ReceiptTokens.labelToValue,
                        runSpacing: ReceiptTokens.rowToRow,
                        children: [
                          ProxoText(time,
                              textDirection: TextDirection.ltr,
                              style: ReceiptTokens.rowLabel
                                  .copyWith(color: const Color(0xFF6B7280))),
                          ProxoText(date,
                              textDirection: TextDirection.ltr,
                              style: ReceiptTokens.rowValue),
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
                  height: ReceiptTokens.rowMinHeight * 2 +
                      ReceiptTokens.headingToRow,
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
