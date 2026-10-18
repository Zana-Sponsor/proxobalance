part of 'proxo_sidebar.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TxHistoryPage — مێژووی مامەڵەکان (Proxo Transaction History — V1)
// ═════════════════════════════════════════════════════════════════════════════
//
// Receipt AppBar, white page, rounded receipt cards and Rabar w400.
// The page and controls are LTR; Kurdish text keeps its own reading direction.
// Transaction loading, balances and detail routing remain in this controller.

class _TxItem {
  final String
  kind; // deposit|spend|refund|coin_exchange|reward|admin_deduct|voucher
  final String label;
  final String sub;
  final String status; // pending|approved|rejected|spent
  final double? amtIqd;
  final DateTime date;
  final bool coinsRow;
  final int coinsAmt;
  final int? balanceAfter; // running IQD balance after this tx
  final String? depositNum;

  // ── بۆ پسوولە ──────────────────────────────────────────────────────────
  final String? receiptAdId;
  final int? receiptAmountIqd;
  final String? receiptStatus;
  final String uid; // UIDی تەواو
  final String txId; // ئایدیی کورت
  final double? usd;
  final String method;
  final String gateway;
  final String type;
  final String? adName;
  final String? voucherCode;
  final int? rawBalanceBeforeIqd, rawBalanceAfterIqd;
  final double? rawBalanceBefore;
  final double? rawBalanceAfter;

  const _TxItem({
    required this.kind,
    required this.label,
    required this.sub,
    required this.status,
    required this.amtIqd,
    required this.date,
    this.coinsRow = false,
    this.coinsAmt = 0,
    this.balanceAfter,
    this.depositNum,
    this.receiptAdId,
    this.receiptAmountIqd,
    this.receiptStatus,
    this.uid = '',
    this.txId = '',
    this.usd,
    this.method = '',
    this.gateway = '',
    this.type = '',
    this.adName,
    this.voucherCode,
    this.rawBalanceBeforeIqd,
    this.rawBalanceAfterIqd,
    this.rawBalanceBefore,
    this.rawBalanceAfter,
  });

  _TxItem withBalanceAfter(int? v) => _TxItem(
    kind: kind,
    label: label,
    sub: sub,
    status: status,
    amtIqd: amtIqd,
    date: date,
    coinsRow: coinsRow,
    coinsAmt: coinsAmt,
    balanceAfter: v,
    depositNum: depositNum,
    receiptAdId: receiptAdId,
    receiptAmountIqd: receiptAmountIqd,
    receiptStatus: receiptStatus,
    uid: uid,
    txId: txId,
    usd: usd,
    method: method,
    gateway: gateway,
    type: type,
    adName: adName,
    voucherCode: voucherCode,
    rawBalanceBeforeIqd: rawBalanceBeforeIqd,
    rawBalanceAfterIqd: rawBalanceAfterIqd,
    rawBalanceBefore: rawBalanceBefore,
    rawBalanceAfter: rawBalanceAfter,
  );

  bool get isIn => const <String>{
    'deposit',
    'refund',
    'reward',
    'coin_exchange',
    'voucher',
  }.contains(kind);

  /// هەمان یاسای باڵانسی ڕۆیشتوو: پارەی زیادکراو تەنها کاتێک `approved`
  /// بێت، پارەی بڕدراو هەمیشە جگە لە `rejected`.
  bool get isSettled => status == 'approved' || status == 'spent';

  TxReceiptData toReceipt() {
    final TxReceiptKind k = switch (kind) {
      'spend' => TxReceiptKind.adPayment,
      'admin_deduct' => TxReceiptKind.deduction,
      'refund' => TxReceiptKind.refund,
      _ => TxReceiptKind.topUp,
    };
    final int? amt = receiptAmountIqd;
    return TxReceiptData(
      kind: k,
      status: receiptStatus ?? status,
      txId: txId,
      uid: uid,
      date: date,
      usd: usd,
      amountIqd: amt,
      balanceBefore: rawBalanceBeforeIqd,
      balanceAfter: rawBalanceAfterIqd,
      balanceBeforeUsd: rawBalanceBefore,
      balanceAfterUsd: rawBalanceAfter,
      method: method,
      gateway: gateway,
      type: type,
      adName: adName,
      voucherCode: voucherCode,
    );
  }
}

/// دۆخی لیست — لە `ValueNotifier`ێکدایە بۆ ئەوەی نوێکردنەوە تەنها
/// لیستەکە دووبارە دروست بکاتەوە، نەک AppBar یان ناونیشان.
@immutable
class _TxListState {
  final List<_TxItem> items;
  final bool loading; // یەکەم بارکردن
  final bool refreshing; // نوێکردنەوەی بێدەنگ
  final bool failed;

  const _TxListState({
    this.items = const <_TxItem>[],
    this.loading = true,
    this.refreshing = false,
    this.failed = false,
  });

  _TxListState copyWith({
    List<_TxItem>? items,
    bool? loading,
    bool? refreshing,
    bool? failed,
  }) => _TxListState(
    items: items ?? this.items,
    loading: loading ?? this.loading,
    refreshing: refreshing ?? this.refreshing,
    failed: failed ?? this.failed,
  );
}

// Keep old name as alias for backwards compatibility if referenced elsewhere
typedef TxHistorySheet = TxHistoryPage;

class TxHistoryPage extends StatefulWidget {
  final String? initialTxId;
  const TxHistoryPage({super.key, this.initialTxId});

  @override
  State<TxHistoryPage> createState() => TxHistorySheetState();
}

class TxHistorySheetState extends State<TxHistoryPage> {
  int _loadRevision = 0;
  final ValueNotifier<_TxListState> _state = ValueNotifier<_TxListState>(
    const _TxListState(),
  );

  @override
  void initState() {
    super.initState();
    ProxoLocale.current.addListener(_onLocaleChanged);
    _load();
  }

  @override
  void dispose() {
    ProxoLocale.current.removeListener(_onLocaleChanged);
    _state.dispose();
    super.dispose();
  }

  void _onLocaleChanged() {
    if (mounted) setState(() {});
  }

  static double? _toIqd(Map<String, dynamic> t) =>
      storedTransactionIqd(t)?.toDouble();
  static double? _toUsd(Map<String, dynamic> t) => storedTransactionUsd(t);

  static String _s(dynamic v) => (v ?? '').toString().trim();

  static String? _extractAdNum(String text) {
    final hashMatch = RegExp(r'#(\d+)').firstMatch(text);
    if (hashMatch != null) return hashMatch.group(1);
    final labeledMatch = RegExp(r'ئایدی\s*ڕیکلام[:\s]*?(\d+)').firstMatch(text);
    return labeledMatch?.group(1);
  }

  /// «ڕیکلام: NAME | …» → NAME
  static String? _extractAdName(String note) {
    final Match? m = RegExp(r'ڕیکلام:\s*(.+?)\s*(\||$)').firstMatch(note);
    final String name = (m?.group(1) ?? '').trim();
    return name.isEmpty ? null : name;
  }

  /// «ڤووچەر: CODE» / «فاوچەر: CODE» → CODE
  static String? _extractVoucher(String note) {
    final Match? m = RegExp(r':\s*([A-Za-z0-9_-]+)').firstMatch(note);
    return m?.group(1);
  }

  static const _methodName = {
    'fib': 'FIB',
    'fastpay': 'FastPay',
    'qicard': 'Qicard',
  };

  // کۆین → IQD rate  (هەمان COINS_TO_IQD لە HTML)
  static const _coinsToIqd = 10.0;

  Future<void> _refresh() async {
    final _TxListState s = _state.value;
    if (s.loading || s.refreshing) return;
    HapticFeedback.selectionClick();
    _state.value = s.copyWith(refreshing: true);
    await _load();
  }

  Future<void> _load() async {
    final revision = ++_loadRevision, owner = supabase.auth.currentUser?.id;
    bool current() => mounted && revision == _loadRevision && owner == supabase.auth.currentUser?.id;
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        _state.value = _state.value.copyWith(loading: false, refreshing: false);
        return;
      }

      final results = await Future.wait([
        supabase
            .from('pa_transactions')
            .select('*')
            .eq('user_id', user.id)
            .order('created_at', ascending: false),
        supabase
            .from('pa_ads')
            .select('id,title,budget,created_at,ad_number,status')
            .eq('user_id', user.id)
            .order('created_at', ascending: false),
        supabase
            .from('pa_coin_transactions')
            .select('*')
            .eq('user_id', user.id)
            .order('created_at', ascending: false),
      ]);

      if (!current()) return;
      final txRes = results[0] as List<dynamic>;
      final adRes = results[1] as List<dynamic>;
      final coinRes = results[2] as List<dynamic>;
      final items = <_TxItem>[];
      final adNumsWithPaymentTx = <String>{};
      final adIdByNumber = <String, String>{
        for (final a in adRes)
          if (a['ad_number'] != null && receiptText(a['id']).isNotEmpty)
            a['ad_number'].toString(): receiptText(a['id']),
      };

      // ── pa_transactions ──────────────────────────────────────────────────
      for (final dynamic raw in txRes) {
        final Map<String, dynamic> t = Map<String, dynamic>.from(raw as Map);
        final type = _s(t['type']);
        final kind2 = _s(t['kind']);
        final status = t['status'] == null ? 'pending' : _s(t['status']);
        final note = _s(t['note']);
        final method = _s(t['method']);
        final adNum = t['ad_number']?.toString();
        final depNum = t['deposit_number']?.toString();
        final date = DateTime.tryParse(_s(t['created_at'])) ?? DateTime.now();

        // ── زانیاری پسوولە ──────────────────────────────────────────────
        final String uid = _s(t['id']);
        final String txId = _s(t['public_transaction_id']).isNotEmpty
            ? _s(t['public_transaction_id'])
            : (_s(t['tx_id']).isNotEmpty ? _s(t['tx_id']) : (depNum ?? ''));
        final String gateway = _s(t['gateway']);
        final String? adTitle = _s(t['ad_title']).isNotEmpty
            ? _s(t['ad_title'])
            : _extractAdName(note);
        final rawBefore = storedWalletBalanceUsd(t, 'balance_before');
        final rawAfter = storedWalletBalanceUsd(t, 'balance_after');

        if (type == 'ad_payment') {
          final adNumInNote = _extractAdNum(note);
          final effectiveAdNum = adNum ?? adNumInNote;
          if (effectiveAdNum != null) adNumsWithPaymentTx.add(effectiveAdNum);
          items.add(
            _TxItem(
              kind: 'spend',
              receiptAdId: receiptText(t['ad_id']).isNotEmpty
                  ? receiptText(t['ad_id'])
                  : adIdByNumber[effectiveAdNum],
              receiptAmountIqd: storedTransactionIqd(t),
              receiptStatus: status,
              label:
                  'ڕیکلام${effectiveAdNum != null ? " #$effectiveAdNum" : ""}',
              sub: note,
              status: status,
              amtIqd: _toIqd(t),
              date: date,
              depositNum: effectiveAdNum,
              uid: uid,
              txId: txId,
              usd: _toUsd(t),
              method: method,
              gateway: gateway,
              type: type,
              adName: adTitle,
              rawBalanceBeforeIqd: storedWalletBalanceIqd(t, 'balance_before'),
              rawBalanceAfterIqd: storedWalletBalanceIqd(t, 'balance_after'),
              rawBalanceBefore: rawBefore,
              rawBalanceAfter: rawAfter,
            ),
          );
          continue;
        }

        if (type == 'withdrawal' &&
            kind2 != 'refund' &&
            !note.contains('ئادمین')) {
          continue;
        }

        String kind, label;
        String effectiveStatus = status;

        if (kind2 == 'refund' || type == 'refund') {
          kind = 'refund';
          final effectiveAdNum = adNum ?? _extractAdNum(note);
          label =
              'گەڕانەوەی پارە${effectiveAdNum != null ? " — ڕیکلام #$effectiveAdNum" : ""}';
        } else if (type == 'balance_added') {
          kind = 'deposit';
          label = 'زیادکردنی باڵانس لەلایەن ئادمینەوە';
        } else if (type == 'balance_deducted' ||
            type == 'admin_debit' ||
            ((type == 'withdrawal' || type == 'admin_adjustment') &&
                note.contains('ئادمین') &&
                !note.contains('زیاد'))) {
          kind = 'admin_deduct';
          label = 'بڕدرا لەلایەن ئادمینەوە';
        } else if (type == 'reward') {
          kind = 'reward';
          label = 'خەڵاتی تیروپشکی هەفتانە';
        } else {
          kind = 'deposit';
          if (type == 'voucher') {
            label =
                'ڤووچەر${note.isNotEmpty ? ": ${note.replaceFirst("ڤووچەر: ", "")}" : ""}';
          } else if (status == 'approved' && type != 'withdrawal') {
            label = 'زیادکردنی باڵانس لەلایەن ئادمینەوە';
          } else {
            label = _methodName[method] ?? (method.isNotEmpty ? method : '—');
          }
        }

        items.add(
          _TxItem(
            kind: kind,
            receiptAmountIqd: storedTransactionIqd(t),
            receiptStatus: status,
            label: label,
            sub: '',
            status: effectiveStatus,
            amtIqd: _toIqd(t),
            date: date,
            depositNum: depNum,
            uid: uid,
            txId: txId,
            usd: _toUsd(t),
            method: method,
            gateway: gateway,
            type: type,
            adName: adTitle,
            voucherCode: type == 'voucher' ? _extractVoucher(note) : null,
            rawBalanceBeforeIqd: storedWalletBalanceIqd(t, 'balance_before'),
            rawBalanceAfterIqd: storedWalletBalanceIqd(t, 'balance_after'),
            rawBalanceBefore: rawBefore,
            rawBalanceAfter: rawAfter,
          ),
        );
      }

      // ── pa_ads — تەنها ڕیکلامی کۆنی بێ تۆماری ad_payment ──────────────────
      for (final a in adRes) {
        final adNum = a['ad_number']?.toString() ?? '—';
        if (adNumsWithPaymentTx.contains(adNum)) continue;
        final budget = receiptNum(a['budget'])?.toDouble() ?? 0;
        final adStatus = (a['status'] ?? 'spent').toString();
        final date =
            DateTime.tryParse((a['created_at'] ?? '').toString()) ??
            DateTime.now();
        items.add(
          _TxItem(
            kind: 'spend',
            receiptAdId: receiptText(a['id']),
            label: 'ڕیکلام #$adNum',
            sub: '',
            status: adStatus,
            amtIqd: null,
            date: date,
            depositNum: adNum,
            // ⚠ ئەم ڕیزە لە pa_adsـەوە دێت و هیچ تۆمارێکی مامەڵەی نییە، بۆیە
            // UIDی مامەڵەی نییە. `pa_ads.id` UIDی ڕیکلامە، نەک مامەڵە —
            // بۆیە لێرە بەکارنایەت و پسوولەکە «—» پیشان دەدات.
            uid: '',
            usd: budget > 0 ? budget : null,
            type: 'ad_payment',
            adName: _s(a['title']).isEmpty ? null : _s(a['title']),
          ),
        );
      }

      // ── pa_coin_transactions (negative amount = exchange to balance) ─────
      for (final c in coinRes) {
        final amt = receiptNum(c['amount'])?.toInt() ?? 0;
        final reason = (c['reason'] ?? '').toString();
        if (amt >= 0 || !reason.contains('گۆڕینەوە')) continue;
        final coins = amt.abs();
        final date =
            DateTime.tryParse((c['created_at'] ?? '').toString()) ??
            DateTime.now();
        items.add(
          _TxItem(
            kind: 'coin_exchange',
            receiptAmountIqd: (coins * _coinsToIqd).round(),
            label: 'کۆین گۆڕدرا بۆ باڵانس',
            sub: '',
            status: 'approved',
            amtIqd: coins * _coinsToIqd,
            date: date,
            coinsRow: true,
            coinsAmt: coins,
            uid: _s(c['id']),
            type: 'coin_exchange',
          ),
        );
      }

      items.sort((a, b) => b.date.compareTo(a.date));

      if (!current()) return;
      _state.value = _TxListState(items: items, loading: false);
    } catch (e) {
      debugPrint('TxHistory: load failed: $e');
      if (!current()) return;
      _state.value = _state.value.copyWith(
        loading: false,
        refreshing: false,
        failed: true,
      );
    }
  }

  // ── ڕێڕەو ─────────────────────────────────────────────────────────────────

  void _openDetail(_TxItem t) {
    if (t.kind == 'spend' && (t.receiptAdId ?? '').isNotEmpty) {
      Navigator.of(context).push(adDetailsRoute(adId: t.receiptAdId));
      return;
    }
    Navigator.of(context).push(
      ProxoPageRoute<void>(
        builder: (_) => TransactionDetailScreen(data: t.toReceipt()),
      ),
    );
  }

  // ── بنیاتنان ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    final TxStrings l = TxStrings.of(ProxoLocale.current.value);
    final bool canPop = Navigator.of(context).canPop();
    return ValueListenableBuilder<_TxListState>(
      valueListenable: _state,
      builder: (BuildContext _, _TxListState s, Widget? __) => TxHistoryLayout(
        title: l.historyTitle,
        backLabel: l.back,
        refreshLabel: l.refresh,
        onBack: canPop ? () => Navigator.of(context).maybePop() : null,
        onRefresh: s.loading || s.refreshing ? null : _refresh,
        refreshing: s.refreshing,
        body: _buildList(s, l),
      ),
    );
  }

  Widget _buildList(_TxListState s, TxStrings l) {
    if (s.loading) return const TxHistorySkeletonList();

    if (s.items.isEmpty && s.failed) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: ReceiptStateView(
          title: l.loadErrorTitle,
          message: l.loadErrorBody,
          actionLabel: l.retry,
          onAction: () {
            _state.value = const _TxListState();
            _load();
          },
        ),
      );
    }

    if (s.items.isEmpty) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: ReceiptStateView(title: l.emptyTitle, message: l.emptyBody),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(
        ReceiptTokens.gutter,
        ReceiptTokens.pageTop,
        ReceiptTokens.gutter,
        ReceiptTokens.pageBottom,
      ),
      itemCount: s.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: TxHistoryCard.gap),
      itemBuilder: (BuildContext _, int i) {
        final _TxItem t = s.items[i];
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ReceiptTokens.contentMaxWidth,
            ),
            child: _TxCard(item: t, onTap: () => _openDetail(t)),
          ),
        );
      },
    );
  }
}

/// Keeps formatting and transaction semantics outside the visual card.
class _TxCard extends StatelessWidget {
  final _TxItem item;
  final VoidCallback onTap;

  const _TxCard({required this.item, required this.onTap});

  String _localizedLabel(String value) {
    // Only app-generated labels are translated; persisted notes and codes stay intact.
    final ad = RegExp(r'^ڕیکلام #(.+)$').firstMatch(value);
    if (ad != null) return ProxoStrings.format('ڕیکلام #{number}', {'number':ad.group(1)!});
    final refund = RegExp(r'^گەڕانەوەی پارە — ڕیکلام #(.+)$').firstMatch(value);
    if (refund != null) return ProxoStrings.format('گەڕانەوەی پارە — ڕیکلام #{number}', {'number':refund.group(1)!});
    if (value.startsWith('ڤووچەر: ')) return ProxoStrings.format('ڤووچەر: {code}', {'code':value.substring('ڤووچەر: '.length)});
    return ProxoStrings.text(value);
  }

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    final _TxItem t = item;
    final DateTime b = receiptBaghdad(t.date) ?? t.date;
    final sign = t.isSettled ? (t.isIn ? '+' : '-') : '';
    final String amount = t.amtIqd != null
        ? receiptIqd(t.amtIqd!.round(), sign: sign)
        : t.usd != null
        ? '$sign${t.usd!.toStringAsFixed(2)} USD'
        : TxStrings.current.amountUnavailable;
    final Color amountColor =
        !t.isSettled || (t.amtIqd == null && t.usd == null)
        ? const Color(0xFF6B7280)
        : t.isIn
        ? ReceiptTokens.positive
        : ReceiptTokens.negative;
    return TxHistoryCard(
      label: _localizedLabel(t.label),
      status: t.isSettled
          ? null
          : t.status == 'rejected'
          ? TxStrings.current.statusRejected
          : TxStrings.current.statusPending,
      date: receiptDay(b),
      time: receiptTime(b, spaced: true),
      amount: amount,
      amountColor: amountColor,
      onTap: onTap,
    );
  }
}
