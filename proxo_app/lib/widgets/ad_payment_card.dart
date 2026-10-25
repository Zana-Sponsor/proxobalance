import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/proxo_surface.dart';
import '../l10n/proxo_strings.dart';
import 'ad_form_components.dart';
import 'payments/payment_option.dart';
import 'proxo_symbol.dart';
import 'proxo_text.dart';

const _walletLabel = 'باڵانسی هەژمار';
Widget _paymentLogo(String value) => value == 'fastpay'
    ? const ProviderLogo(provider: 'fastpay', width: 44, height: 24)
    : const ProxoSymbol(ProxoSymbolName.wallet, size: 26, color: AdUi.blue);

// Measure both labels so switching methods cannot resize either surface.
double _paymentRowHeight(BuildContext context, double labelWidth) {
  var height = 72.0;
  for (final label in [_walletLabel, 'FastPay']) {
    final painter = TextPainter(
        text:
            TextSpan(text: ProxoStrings.text(label), style: ProxoSurface.body),
        textDirection: TextDirection.rtl,
        textScaler: MediaQuery.textScalerOf(context))
      ..layout(maxWidth: math.max(1, labelWidth));
    height = math.max(height, painter.height + 24);
    painter.dispose();
  }
  return height;
}

/// Shared selected-payment card. Only Change opens the editor; its temporary
/// selection lives in the sheet and is committed by Confirm alone.
class AdPaymentCard extends StatefulWidget {
  const AdPaymentCard(
      {super.key,
      required this.value,
      required this.onChanged,
      this.busy = false,
      this.fastPayEnabled = true,
      this.balanced = false});
  final String value;
  final ValueChanged<String> onChanged;
  final bool busy, fastPayEnabled;
  final bool balanced;
  @override
  State<AdPaymentCard> createState() => _AdPaymentCardState();
}

class _AdPaymentCardState extends State<AdPaymentCard> {
  bool _opening = false;
  Future<void> _change() async {
    if (_opening || widget.busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _opening = true);
    try {
      final selected = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        constraints: const BoxConstraints(maxWidth: 600),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(ProxoSurface.radius))),
        builder: (_) => Directionality(
            textDirection: TextDirection.rtl,
            child: _AdPaymentSheet(
                initialValue: widget.value,
                fastPayEnabled: widget.fastPayEnabled)),
      );
      if (mounted && selected != null && selected != widget.value) {
        widget.onChanged(selected);
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final change = TextPainter(
            text: TextSpan(
                text: ProxoStrings.text('گۆڕین'), style: ProxoSurface.body),
            textDirection: TextDirection.rtl,
            textScaler: MediaQuery.textScalerOf(context))
          ..layout();
        final changeWidth = math.max(48.0, change.width + 16);
        change.dispose();
        final labelWidth = constraints.maxWidth - 24 - 44 - 8 - 8 - changeWidth;
        final labelMeasure = TextPainter(
            text: TextSpan(
                text: ProxoStrings.text(_walletLabel),
                style: ProxoSurface.body),
            textDirection: TextDirection.rtl,
            textScaler: MediaQuery.textScalerOf(context))
          ..layout();
        final stacked = labelWidth <
            (widget.balanced ? labelMeasure.minIntrinsicWidth : 48);
        labelMeasure.dispose();
        final height = _paymentRowHeight(
            context, stacked ? constraints.maxWidth - 24 - 44 - 8 : labelWidth);
        final identity = <Widget>[
          SizedBox(
              width: 44,
              height: 32,
              child: Center(child: _paymentLogo(widget.value))),
          const SizedBox(width: 8),
          Expanded(
              child: ProxoText(
                  widget.value == 'fastpay' ? 'FastPay' : _walletLabel,
                  style: ProxoSurface.body)),
        ];
        final changeButton = SizedBox(
            width: stacked
                ? math.min(changeWidth, constraints.maxWidth - 24)
                : changeWidth,
            child: TextButton(
                key: const ValueKey('change-payment'),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(48, 48),
                    textStyle: ProxoSurface.body),
                onPressed: widget.busy || _opening ? null : _change,
                child: const ProxoText('گۆڕین')));
        return Material(
          key: const ValueKey('selected-payment-card'),
          color: Colors.white,
          shape: const RoundedRectangleBorder(
              borderRadius: AdUi.controlRadius,
              side: BorderSide(color: AdUi.controlLine)),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: height),
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: stacked
                      ? Column(mainAxisSize: MainAxisSize.min, children: [
                          SizedBox(
                              height: height - 24,
                              child: Row(children: identity)),
                          const SizedBox(height: 8),
                          Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: changeButton),
                        ])
                      : Row(children: [
                          ...identity,
                          const SizedBox(width: 8),
                          changeButton,
                        ]))),
        );
      });
}

class _AdPaymentSheet extends StatefulWidget {
  const _AdPaymentSheet(
      {required this.initialValue, required this.fastPayEnabled});
  final String initialValue;
  final bool fastPayEnabled;
  @override
  State<_AdPaymentSheet> createState() => _AdPaymentSheetState();
}

class _AdPaymentSheetState extends State<_AdPaymentSheet> {
  late String _selected =
      widget.initialValue == 'fastpay' ? 'fastpay' : 'app_balance';
  @override
  Widget build(BuildContext context) => SafeArea(
      top: false,
      child: SingleChildScrollView(
          key: const ValueKey('payment-method-sheet'),
          padding: EdgeInsets.fromLTRB(
              ProxoSurface.gutter,
              24,
              ProxoSurface.gutter,
              24 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProxoText('شێوازەکانی پارەدان', style: AdUi.heading(context)),
                const SizedBox(height: 20),
                Material(
                    color: Colors.white,
                    clipBehavior: Clip.antiAlias,
                    shape: const RoundedRectangleBorder(
                        borderRadius: AdUi.controlRadius,
                        side: BorderSide(color: AdUi.controlLine)),
                    child: LayoutBuilder(builder: (context, constraints) {
                      final rowHeight = _paymentRowHeight(
                          context, constraints.maxWidth - 128);
                      return Column(children: [
                        PaymentOption(
                            key: const ValueKey('payment-app_balance'),
                            grouped: true,
                            minimumHeight: rowHeight,
                            selectedOnlyCheck: true,
                            label: _walletLabel,
                            leading: _paymentLogo('app_balance'),
                            selected: _selected == 'app_balance',
                            onTap: () =>
                                setState(() => _selected = 'app_balance')),
                        const Divider(
                            height: 1,
                            thickness: 1,
                            indent: 12,
                            endIndent: 12,
                            color: AdUi.controlLine),
                        PaymentOption(
                            key: const ValueKey('payment-fastpay'),
                            grouped: true,
                            minimumHeight: rowHeight,
                            selectedOnlyCheck: true,
                            label: 'FastPay',
                            leading: _paymentLogo('fastpay'),
                            selected: _selected == 'fastpay',
                            onTap: widget.fastPayEnabled
                                ? () => setState(() => _selected = 'fastpay')
                                : null),
                      ]);
                    })),
                if (!widget.fastPayEnabled) ...[
                  const SizedBox(height: 8),
                  ProxoText('FastPay ئێستا بەردەست نییە',
                      style: AdUi.text(context, color: AdUi.secondary)),
                ],
                const SizedBox(height: 20),
                FilledButton(
                    key: const ValueKey('confirm-payment'),
                    onPressed: _selected == 'fastpay' && !widget.fastPayEnabled
                        ? null
                        : () => Navigator.of(context).pop(_selected),
                    child: const ProxoText('دڵنیاکردنەوە')),
              ])));
}
