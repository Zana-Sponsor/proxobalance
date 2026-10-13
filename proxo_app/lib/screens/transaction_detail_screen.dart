import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/tx_strings.dart';
import '../models/receipt_pricing.dart';
import '../theme/app_locale.dart';
import '../widgets/receipt/receipt_kit.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TransactionDetailScreen — پسوولەی مامەڵە (Proxo Transaction Detail — V1)
// ═════════════════════════════════════════════════════════════════════════════
//
// هەمان کیتی `receipt_kit.dart` ـی وردەکاری ڕیکلام: AppBar، کارت، جیاکەرەوە،
// ڕیز، سەردێری شین، دوگمەی PDF، هەمووی w400.
//
//   پسوولەی مامەڵە ················· [Proxo]
//   ─────────────
//   ئایدی مامەڵە · ڕێکەوت (· دۆخ — تەنها ئەگەر تەواو نەبووبێت)
//   ─────────────
//   پوختە / پوختەی زیادکردنی پارە / پوختەی گەڕانەوەی پارە
//   ─────────────
//   زانیاری پارەدان  (ڕێگای پارەدان، ژ.م پسوولە)
//   ─────────────
//   ناوی ڕیکلام  یان  سەرچاوەی زیادکردنی پارە
//
//   [ داوڵۆند بکە بە PDF ]
// ═════════════════════════════════════════════════════════════════════════════

enum TxReceiptKind { adPayment, topUp, refund, deduction }

/// هەموو بەهاکانی پسوولەیەک — لە مێژووی مامەڵەکانەوە دروست دەکرێت.
@immutable
class TxReceiptData {
  final TxReceiptKind kind;

  /// approved | pending | rejected | ...
  final String status;

  /// ئایدیی کورت (`public_transaction_id` → `tx_id` → `deposit_number`).
  final String txId;

  /// UIDی تەواو (`pa_transactions.id`).
  final String uid;

  final DateTime date;
  final double? usd;
  final int? amountIqd;
  final int? balanceBefore;
  final int? balanceAfter;

  /// بەهای خاوی داتابەیس.
  final String method;
  final String gateway;
  final String type;

  final String? adName;
  final String? voucherCode;

  const TxReceiptData({
    required this.kind,
    required this.status,
    required this.txId,
    required this.uid,
    required this.date,
    required this.usd,
    required this.amountIqd,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.method,
    required this.gateway,
    required this.type,
    required this.adName,
    required this.voucherCode,
  });

  bool get isSettled => status == 'approved' || status == 'spent';
}

class TransactionDetailScreen extends StatefulWidget {
  final TxReceiptData data;

  const TransactionDetailScreen({super.key, required this.data});

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  final GlobalKey _receiptKey = GlobalKey(debugLabel: 'tx_receipt');

  @override
  void initState() {
    super.initState();
    ProxoLocale.current.addListener(_onLocaleChanged);
  }

  void _onLocaleChanged() => setState(() {});

  @override
  void dispose() {
    ProxoLocale.current.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _back() => Navigator.of(context).maybePop();

  Future<void> _copy(String text) async {
    final String raw = text.trim();
    if (raw.isEmpty || raw == '—') return;
    try {
      await Clipboard.setData(ClipboardData(text: raw));
      if (!mounted) return;
      HapticFeedback.selectionClick();
      showReceiptMessage(context, TxStrings.current.copied);
    } catch (_) {
      if (mounted) showReceiptMessage(context, TxStrings.current.copyFailed);
    }
  }

  Future<void> _exportPdf(TxStrings l) async {
    final String stem =
        widget.data.txId.isNotEmpty ? widget.data.txId : widget.data.uid;
    final bool ok = await exportReceiptPdf(
      boundaryKey: _receiptKey,
      title: l.receiptTitle,
      fileStem: stem,
    );
    if (!ok && mounted) {
      showReceiptMessage(context, TxStrings.current.pdfFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TxStrings l = TxStrings.of(ProxoLocale.current.value);
    final MediaQueryData mq = MediaQuery.of(context);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: MediaQuery(
        data: mq,
        child: Scaffold(
          backgroundColor: ReceiptTokens.page,
          body: Column(
            children: <Widget>[
              ReceiptAppBar(title: l.detailTitle, onBack: _back),
              Expanded(
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: ReceiptBody(
                    children: <Widget>[
                      RepaintBoundary(
                        key: _receiptKey,
                        child: ReceiptSurface(
                          child: _TxReceiptCard(
                              d: widget.data,
                              l: l,
                              onCopy: (String v) => _copy(v)),
                        ),
                      ),
                      _fullWidth(
                        ReceiptPdfButton(
                          label: l.pdfButton,
                          onPressed: () => _exportPdf(l),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fullWidth(Widget child) => ReceiptWidth(child: child);
}

// ═════════════════════════════════════════════════════════════════════════════
// کارتی پسوولە
// ═════════════════════════════════════════════════════════════════════════════

class _TxReceiptCard extends StatelessWidget {
  final TxReceiptData d;
  final TxStrings l;
  final void Function(String value) onCopy;

  const _TxReceiptCard({
    required this.d,
    required this.l,
    required this.onCopy,
  });

  static const TextDirection _ltr = TextDirection.ltr;

  String _money(int? v) => v == null ? '—' : formatIqd(v);

  bool get _free => d.kind == TxReceiptKind.adPayment && d.amountIqd == 0;

  /// ڕێگای پارەدان — تەنها لە بەهای ڕاستەقینەی داتابەیسەوە.
  String _methodLabel() {
    if (_free) return l.noPaymentRequired;
    final String m = receiptText(d.method);
    final String ml = m.toLowerCase();
    final String type = d.type;
    if (ml == 'fastpay' || d.gateway.toLowerCase() == 'fastpay') {
      return 'FastPay';
    }
    if (ml == 'fib') return 'FIB';
    if (ml == 'qicard') return 'Qicard';
    if (ml == 'app_balance') return l.methodBalance;
    if (type == 'voucher') return l.methodVoucher;
    if (type == 'reward') return l.methodReward;
    if (type == 'coin_exchange') return l.methodCoins;
    if (type == 'balance_added' ||
        type == 'balance_deducted' ||
        type == 'admin_adjustment' ||
        type == 'admin_debit' ||
        d.kind == TxReceiptKind.deduction) {
      return l.methodAdmin;
    }
    if (ml == 'admin_panel') return l.methodAdmin;
    return m.isEmpty ? '—' : m;
  }

  /// سەرچاوەی زیادکردنی پارە.
  String _sourceLabel() {
    final String type = d.type;
    final String ml = d.method.toLowerCase();
    if (type == 'voucher') return l.sourceVoucher(d.voucherCode ?? '');
    if (type == 'reward') return l.sourceReward;
    if (type == 'coin_exchange') return l.sourceCoins;
    if (ml == 'fastpay' || d.gateway.toLowerCase() == 'fastpay') {
      return l.sourceOnline;
    }
    if (type == 'balance_added' || type == 'admin_adjustment') {
      return l.sourceAdmin;
    }
    if (ml.isNotEmpty) return l.sourceManual;
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final bool settled = d.isSettled;
    final String method = _methodLabel();

    // ── بەشی پوختە بەپێی جۆر ─────────────────────────────────────────────
    final String heading;
    final String finalLabel;
    final String sign;
    switch (d.kind) {
      case TxReceiptKind.adPayment:
        heading = l.summary;
        finalLabel = l.totalPaid;
        sign = '-';
      case TxReceiptKind.deduction:
        heading = l.summary;
        finalLabel = l.totalDeducted;
        sign = '-';
      case TxReceiptKind.refund:
        heading = l.refundSummary;
        finalLabel = l.totalRefunded;
        sign = '+';
      case TxReceiptKind.topUp:
        heading = l.topUpSummary;
        finalLabel = l.totalAdded;
        sign = '+';
    }

    // مامەڵەی ڕەتکراو/چاوەڕوان هیچ پارەیەکی نەجوڵاندووە — بۆیە بێ نیشانە و
    // بێ ڕەنگ.
    final String signedValue =
        settled && d.amountIqd != null && d.amountIqd != 0
            ? formatIqd(d.amountIqd!, sign: sign)
            : _money(d.amountIqd);

    final List<Widget?> summaryRows = <Widget?>[
      if (d.kind == TxReceiptKind.adPayment) ...<Widget?>[
        if (d.balanceAfter != null)
          ReceiptRow(
            label: l.accountBalance,
            value: _money(d.balanceAfter!),
            valueDirection: _ltr,
          ),
      ] else ...<Widget?>[
        if (d.balanceBefore != null)
          ReceiptRow(
            label: l.balanceBefore,
            value: _money(d.balanceBefore!),
            valueDirection: _ltr,
          ),
        if (d.balanceAfter != null)
          ReceiptRow(
            label: l.balanceAfter,
            value: _money(d.balanceAfter!),
            valueDirection: _ltr,
          ),
      ],
      ReceiptRow(
        label: finalLabel,
        value: signedValue,
        valueDirection: _ltr,
        valueStyle: ReceiptTokens.totalValue,
      ),
    ];

    // ── کۆتایی ───────────────────────────────────────────────────────────
    final Widget? finalRow = switch (d.kind) {
      TxReceiptKind.adPayment => ReceiptRow(
          label: l.adName,
          value: receiptText(d.adName).isEmpty ? '—' : receiptText(d.adName),
          valueDirection: receiptDirOf(d.adName ?? ''),
        ),
      TxReceiptKind.refund when receiptText(d.adName).isNotEmpty => ReceiptRow(
          label: l.adName,
          value: receiptText(d.adName),
          valueDirection: receiptDirOf(d.adName!),
        ),
      TxReceiptKind.topUp => ReceiptRow(
          label: l.topUpSource,
          value: _sourceLabel(),
          valueDirection: receiptDirOf(_sourceLabel()),
        ),
      _ => null,
    };

    final String statusText =
        d.status == 'rejected' ? l.statusRejected : l.statusPending;

    return ReceiptCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // ── ٥) سەرووی پسوولە ────────────────────────────────────────────
          ReceiptHeader(title: l.receiptTitle),
          const ReceiptDivider(),

          // ── ١١) زانیاری مامەڵە ──────────────────────────────────────────
          ReceiptRows(<Widget?>[
            if (!_free &&
                (receiptText(d.txId).isNotEmpty ||
                    receiptText(d.uid).isNotEmpty))
              ReceiptIdRow(
                label: l.txId,
                value: receiptText(d.txId).isNotEmpty
                    ? receiptText(d.txId)
                    : receiptText(d.uid),
                onLongPress: () => onCopy(
                  receiptText(d.txId).isNotEmpty
                      ? receiptText(d.txId)
                      : receiptText(d.uid),
                ),
              ),
            ReceiptRow(
              label: l.date,
              value: receiptDateTime(d.date),
              valueDirection: _ltr,
            ),
            if (!settled && !_free)
              ReceiptRow(label: l.status, value: statusText),
          ]),
          const ReceiptDivider(),

          // ── ١٢/١٥/١٦) پوختە ─────────────────────────────────────────────
          ReceiptSectionHeading(heading),
          ReceiptRows(summaryRows),
          const ReceiptDivider(),

          // ── ١٣) زانیاری پارەدان ─────────────────────────────────────────
          ReceiptSectionHeading(l.paymentInfo),
          ReceiptRows(<Widget?>[
            ReceiptRow(
              label: l.paymentMethod,
              value: method,
              valueDirection: receiptDirOf(method),
            ),
          ]),

          // ── ١٤/١٥) کۆتایی ───────────────────────────────────────────────
          if (finalRow != null) ...<Widget>[const ReceiptDivider(), finalRow],
        ],
      ),
    );
  }
}
