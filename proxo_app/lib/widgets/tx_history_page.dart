part of 'proxo_sidebar.dart';

// ═════════════════════════════════════════════════════════════════════════════
// TxHistoryPage — مێژووی مامەڵەکان (Proxo Transaction History — V1)
// ═════════════════════════════════════════════════════════════════════════════
//
//   ProxoTopBar
//   مێژووی مامەڵەکان        ← شین، w500
//   نوێکردنەوە               ← شین، سووک
//   ┌──────────────────────────────────┐
//   │ 18/09/2026   12:24 PM   -19,650 د.ع │   ← کارتی بچووک، بێ ئایکۆن
//   └──────────────────────────────────┘
//   ProxoBottomNav
//
// ⚠ لۆژیکی داتا (هێنان، دووبارەنەبوونەوەی ad_payment، باڵانسی ڕۆیشتوو)
// وەک خۆی ماوەتەوە — تەنها زانیاری زیادە بۆ پسوولەکە کۆکراوەتەوە.
// ═════════════════════════════════════════════════════════════════════════════

class _TxItem {
  final String
      kind; // deposit|spend|refund|coin_exchange|reward|admin_deduct|voucher
  final String label;
  final String sub;
  final String status; // pending|approved|rejected|spent
  final double amtIqd;
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
  final int? rawBalanceBefore;
  final int? rawBalanceAfter;

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
  bool get isSettled => isIn ? status == 'approved' : status != 'rejected';

  TxReceiptData toReceipt() {
    final TxReceiptKind k = switch (kind) {
      'spend' => TxReceiptKind.adPayment,
      'admin_deduct' => TxReceiptKind.deduction,
      'refund' => TxReceiptKind.refund,
      _ => TxReceiptKind.topUp,
    };
    final int? amt = receiptAmountIqd;
    final int? after = rawBalanceAfter;
    final int? before = rawBalanceBefore;
    return TxReceiptData(
      kind: k,
      status: receiptStatus ?? status,
      txId: txId,
      uid: uid,
      date: date,
      usd: usd,
      amountIqd: amt,
      balanceBefore: (before != null && before >= 0) ? before : null,
      balanceAfter: after,
      method: method,
      gateway: gateway,
      type: type,
      adName: adName,
      voucherCode: voucherCode,
    );
  }
}

/// دۆخی لیست — لە `ValueNotifier`ێکدایە بۆ ئەوەی نوێکردنەوە تەنها
/// لیستەکە دووبارە دروست بکاتەوە، نەک AppBar، ناونیشان یان Bottom Nav.
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
  }) =>
      _TxListState(
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
  final ValueNotifier<_TxListState> _state = ValueNotifier<_TxListState>(
    const _TxListState(),
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  // amounts >500 stored as IQD; ≤500 stored as USD (×1800)
  static double _toIqd(Map<String, dynamic> t) {
    final double amt = receiptNum(t['amount'])?.toDouble() ?? 0;
    return amt > 500 ? amt : amt * kIqdRate;
  }

  /// بڕەکە بە دۆلار — تەنها لە بەهای تۆمارکراو.
  static double? _toUsd(Map<String, dynamic> t) {
    final double? amt = receiptNum(t['amount'])?.toDouble();
    if (amt == null || amt <= 0) return null;
    if (amt <= 500) return amt;
    final double? fx = receiptNum(t['fx_rate'])?.toDouble();
    return (fx != null && fx > 0) ? amt / fx : null;
  }

  static int? _int(dynamic v) => receiptNum(v)?.round();

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
        supabase
            .from('pa_wallets')
            .select('balance')
            .eq('user_id', user.id)
            .limit(1),
      ]);

      final txRes = results[0] as List<dynamic>;
      final adRes = results[1] as List<dynamic>;
      final coinRes = results[2] as List<dynamic>;
      final wallets = results[3] as List<dynamic>;
      final walletBal =
          (wallets.isNotEmpty ? receiptNum(wallets.first['balance']) : null)
                  ?.toDouble() ??
              0.0;
      int runBal = (walletBal * kIqdRate).round();

      final items = <_TxItem>[];
      final adNumsWithPaymentTx = <String>{};
      final adBudgetByNum = <String, double>{
        for (final a in adRes)
          if (a['ad_number'] != null)
            a['ad_number'].toString():
                (receiptNum(a['budget'])?.toDouble() ?? 0) * kIqdRate,
      };

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
        final int? rawBefore = _int(t['balance_before']);
        final int? rawAfter = _int(t['balance_after']);

        if (type == 'ad_payment') {
          final payStatus = t['status'] == null ? 'approved' : _s(t['status']);
          final adNumInNote = _extractAdNum(note);
          final effectiveAdNum = adNum ?? adNumInNote;
          if (effectiveAdNum != null) adNumsWithPaymentTx.add(effectiveAdNum);
          var amt = _toIqd(t);
          if (amt <= 0 && effectiveAdNum != null) {
            amt = adBudgetByNum[effectiveAdNum] ?? 0;
          }
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
              status: payStatus == 'pending' ? 'approved' : payStatus,
              amtIqd: amt,
              date: date,
              depositNum: effectiveAdNum,
              uid: uid,
              txId: txId,
              usd: _toUsd(t),
              method: method,
              gateway: gateway,
              type: type,
              adName: adTitle,
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
          if (t['status'] == null || status == 'pending') {
            effectiveStatus = 'approved';
          }
        } else if (type == 'balance_added') {
          kind = 'deposit';
          label = 'زیادکردنی باڵانس لەلایەن ئادمینەوە';
          if (status == 'pending') effectiveStatus = 'approved';
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

        var refundAmt = _toIqd(t);
        if (kind == 'refund' && refundAmt <= 0) {
          final fallbackNum = adNum ?? _extractAdNum(label);
          if (fallbackNum != null) refundAmt = adBudgetByNum[fallbackNum] ?? 0;
        }

        items.add(
          _TxItem(
            kind: kind,
            receiptAmountIqd: storedTransactionIqd(t),
            receiptStatus: status,
            label: label,
            sub: '',
            status: effectiveStatus,
            amtIqd: refundAmt,
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
        final date = DateTime.tryParse((a['created_at'] ?? '').toString()) ??
            DateTime.now();
        items.add(
          _TxItem(
            kind: 'spend',
            receiptAdId: receiptText(a['id']),
            label: 'ڕیکلام #$adNum',
            sub: '',
            status: adStatus == 'pending' ? 'approved' : adStatus,
            amtIqd: budget * kIqdRate,
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
        final date = DateTime.tryParse((c['created_at'] ?? '').toString()) ??
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

      // ── Running balance — newest→oldest (وەک پێشوو) ─────────────────────
      final itemsWithBal = items.map((t) {
        final bal = runBal;
        final iqd = t.amtIqd.round();
        if ((t.kind == 'spend' || t.kind == 'admin_deduct') &&
            t.status != 'rejected') {
          runBal += iqd;
        } else if ((t.kind == 'deposit' ||
                t.kind == 'refund' ||
                t.kind == 'reward' ||
                t.kind == 'coin_exchange' ||
                t.kind == 'voucher') &&
            t.status == 'approved') {
          runBal -= iqd;
        }
        return t.withBalanceAfter(bal.clamp(0, 9999999999).toInt());
      }).toList();

      if (!mounted) return;
      _state.value = _TxListState(items: itemsWithBal, loading: false);
    } catch (e) {
      debugPrint('TxHistory: load failed: $e');
      if (!mounted) return;
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

  /// Bottom Nav: دەگەڕێتەوە بۆ شێڵ و تابەکە دەگۆڕێت.
  void _onNavTap(int index) {
    Navigator.of(context).popUntil((Route<dynamic> r) => r.isFirst);
    mainShellTabRequest.value = index;
  }

  // ── بنیاتنان ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final TxStrings l = TxStrings.of(ProxoLocale.current.value);
    final MediaQueryData mq = MediaQuery.of(context);
    final bool canPop = Navigator.of(context).canPop();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: MediaQuery(
        data: mq.copyWith(
          textScaler: mq.textScaler.clamp(
            minScaleFactor: ReceiptTokens.minTextScale,
            maxScaleFactor: ReceiptTokens.maxTextScale,
          ),
        ),
        child: Scaffold(
          backgroundColor: ReceiptTokens.historyPage,
          appBar: ProxoTopBar(
            topPadding: mq.padding.top,
            onBackTap: canPop ? () => Navigator.of(context).maybePop() : null,
            onNotificationTap: () =>
                navigatorKey.currentState?.pushNamed('/notifications'),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _TxHistoryHeader(l: l, state: _state, onRefresh: _refresh),
              Expanded(
                child: ValueListenableBuilder<_TxListState>(
                  valueListenable: _state,
                  builder: (BuildContext _, _TxListState s, Widget? __) =>
                      _buildList(s, l),
                ),
              ),
            ],
          ),
          bottomNavigationBar: ValueListenableBuilder<int>(
            valueListenable: mainShellTab,
            builder: (BuildContext _, int tab, Widget? __) =>
                ProxoBottomNav(currentIndex: tab, onTap: _onNavTap),
          ),
        ),
      ),
    );
  }

  Widget _buildList(_TxListState s, TxStrings l) {
    if (s.loading) return const _TxSkeletonList();

    if (s.items.isEmpty && s.failed) {
      return ReceiptStateView(
        title: l.loadErrorTitle,
        message: l.loadErrorBody,
        actionLabel: l.retry,
        onAction: () {
          _state.value = const _TxListState();
          _load();
        },
      );
    }

    if (s.items.isEmpty) {
      return ReceiptStateView(title: l.emptyTitle, message: l.emptyBody);
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(
        ReceiptTokens.gutter,
        0,
        ReceiptTokens.gutter,
        ReceiptTokens.pageBottom,
      ),
      itemCount: s.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: _TxCard.gap),
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

// ═════════════════════════════════════════════════════════════════════════════
// ناونیشان + نوێکردنەوە
// ═════════════════════════════════════════════════════════════════════════════

class _TxHistoryHeader extends StatelessWidget {
  final TxStrings l;
  final ValueNotifier<_TxListState> state;
  final Future<void> Function() onRefresh;

  const _TxHistoryHeader({
    required this.l,
    required this.state,
    required this.onRefresh,
  });

  static final TextStyle _title = ReceiptTokens.heading.copyWith(
    fontSize: 14,
    height: 1.30,
  );
  static final TextStyle _refresh = ReceiptTokens.rowLabel.copyWith(
    fontSize: 11.5,
    color: ReceiptTokens.accent,
    height: 1.30,
  );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: ReceiptTokens.contentMaxWidth + ReceiptTokens.gutter * 2,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ReceiptTokens.gutter,
            18,
            ReceiptTokens.gutter,
            14,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(l.historyTitle, style: _title),
              const SizedBox(height: 6),
              ValueListenableBuilder<_TxListState>(
                valueListenable: state,
                builder: (BuildContext _, _TxListState s, Widget? __) {
                  final bool busy = s.refreshing || s.loading;
                  return _PressFade(
                    onTap: busy ? null : onRefresh,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(l.refresh, style: _refresh),
                        if (s.refreshing) ...const <Widget>[
                          SizedBox(width: 8),
                          SizedBox(
                            width: 11,
                            height: 11,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.6,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                ReceiptTokens.accent,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// کاردانەوەیەکی نەرم: کاتی داگرتن تەنها کاڵ دەبێتەوە.
class _PressFade extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _PressFade({required this.child, this.onTap});

  @override
  State<_PressFade> createState() => _PressFadeState();
}

class _PressFadeState extends State<_PressFade> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: widget.onTap == null ? null : (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: AnimatedOpacity(
          opacity: _down ? 0.45 : 1,
          duration: const Duration(milliseconds: 120),
          child: widget.child,
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// کارتی مامەڵە — بەروار · کات · بڕ
// ═════════════════════════════════════════════════════════════════════════════

class _TxCard extends StatelessWidget {
  final _TxItem item;
  final VoidCallback onTap;

  const _TxCard({required this.item, required this.onTap});

  static const double gap = 8;
  static const EdgeInsets _pad = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 14,
  );

  static final TextStyle _date = ReceiptTokens.rowValue.copyWith(
    fontSize: 12.5,
    color: const Color(0xFF27303F),
    height: 1.40,
  );
  static final TextStyle _time = ReceiptTokens.rowLabel.copyWith(
    fontSize: 11.5,
    color: const Color(0xFF6B7280),
    height: 1.40,
  );

  @override
  Widget build(BuildContext context) {
    final _TxItem t = item;
    final DateTime b = receiptBaghdad(t.date) ?? t.date;
    final int iqd = t.amtIqd.round();

    // + سەوز بۆ پارەی زیادکراو، - سوور بۆ پارەی بڕدراو. مامەڵەی
    // ڕەتکراو/چاوەڕوان هیچ پارەیەکی نەجوڵاندووە → بێ نیشانە، بێ ڕەنگ.
    final String amount;
    final TextStyle amountStyle;
    if (!t.isSettled) {
      amount = receiptIqd(iqd);
      amountStyle = _time;
    } else if (t.isIn) {
      amount = receiptIqd(iqd, sign: '+');
      amountStyle = _date.copyWith(color: ReceiptTokens.positive);
    } else {
      amount = receiptIqd(iqd, sign: '-');
      amountStyle = _date.copyWith(color: ReceiptTokens.negative);
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: ReceiptTokens.card,
        borderRadius: BorderRadius.zero,
        boxShadow: ReceiptTokens.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: const Color(0x0A046CFA),
          highlightColor: const Color(0x08000000),
          child: Padding(
            padding: _pad,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                // ڕاست: بەروار
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        receiptDay(b),
                        textDirection: TextDirection.ltr,
                        style: _date,
                      ),
                    ),
                  ),
                ),
                // ناوەڕاست: کات
                Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        receiptTime(b, spaced: true),
                        textDirection: TextDirection.ltr,
                        style: _time,
                      ),
                    ),
                  ),
                ),
                // چەپ: بڕ
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        amount,
                        textDirection: TextDirection.ltr,
                        style: amountStyle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// پلەیسهۆڵدەری بارکردن — هەمان قەبارەی کارتەکان، بێ ئەنیمەیشن.
class _TxSkeletonList extends StatelessWidget {
  const _TxSkeletonList();

  @override
  Widget build(BuildContext context) {
    Widget bar(double w) =>
        Container(width: w, height: 10, color: const Color(0xFFEEF0F3));
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        ReceiptTokens.gutter,
        0,
        ReceiptTokens.gutter,
        0,
      ),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: _TxCard.gap),
      itemBuilder: (_, __) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: ReceiptTokens.contentMaxWidth,
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: ReceiptTokens.card,
              boxShadow: ReceiptTokens.cardShadow,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 19),
              child: Row(
                children: <Widget>[
                  bar(72),
                  const Spacer(),
                  bar(52),
                  const Spacer(),
                  bar(80),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
