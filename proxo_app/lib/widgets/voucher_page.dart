part of 'proxo_sidebar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VoucherPage — فاوچەرەکان
// Mirrors the HTML pgGifts / claimVoucher / _loadGiftsVoucher logic exactly.
// Table: pa_vouchers (code, amount_iqd, is_active, used_by, used_at,
//                     assigned_user_id, expires_at, reason, is_signup_bonus)
// ─────────────────────────────────────────────────────────────────────────────

class VoucherPage extends StatefulWidget {
  const VoucherPage({super.key});
  @override State<VoucherPage> createState() => _VoucherPageState();
}

class _VoucherPageState extends State<VoucherPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  final _codeCtrl = TextEditingController();
  bool   _claiming  = false;
  String _msg       = '';
  bool   _msgOk     = false;

  List<Map<String, dynamic>> _assigned = []; // unclaimed, assigned to me
  List<Map<String, dynamic>> _history  = []; // used by me
  bool _loadingVouchers = true;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 500))..forward();
    _loadAll();
  }

  @override
  void dispose() {
    _anim.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ────────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() => _loadingVouchers = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Active vouchers assigned to this user that haven't been used yet
      final assignedRes = await supabase
          .from('pa_vouchers')
          .select('*')
          .eq('assigned_user_id', user.id)
          .eq('is_active', true)
          .isFilter('used_by', null)
          .order('created_at', ascending: false);

      final now = DateTime.now();
      final assigned = (assignedRes as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .where((v) {
            final exp = v['expires_at'] != null
                ? DateTime.tryParse(v['expires_at'].toString())
                : null;
            return exp == null || exp.isAfter(now);
          }).toList();

      // Vouchers used by this user
      final historyRes = await supabase
          .from('pa_vouchers')
          .select('code, amount_iqd, used_at')
          .eq('used_by', user.id)
          .not('used_at', 'is', null)
          .order('used_at', ascending: false)
          .limit(30);

      if (mounted) {
        setState(() {
          _assigned        = assigned;
          _history         = (historyRes as List<dynamic>)
              .cast<Map<String, dynamic>>();
          _loadingVouchers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingVouchers = false);
    }
  }

  // ── Claim logic — mirrors _claimVoucherCore from HTML ───────────────────────

  Future<void> _claimCode(String code) async {
    if (supabase.auth.currentUser == null) return;

    setState(() { _claiming = true; _msg = ''; });

    try {
      final raw = await supabase.rpc('pa_redeem_voucher', params: {
        'p_code': code.trim(),
      });
      final result = Map<String, dynamic>.from(raw as Map);
      if (result['ok'] != true) {
        final message = switch ((result['code'] ?? '').toString()) {
          'NOT_FOUND' => 'فاوچەرەکە نەدۆزرایەوە. کۆدەکە دووبارە بپشکنە.',
          'ALREADY_USED' => 'ئەم فاوچەرە پێشتر بەکارهێنراوە.',
          'INACTIVE' => 'ئەم فاوچەرە چالاک نییە.',
          'ASSIGNED_TO_OTHER' => 'ئەم فاوچەرە بۆ بەکارهێنەرێکی تر تەرخانکراوە.',
          'EXPIRED' => 'ئەم فاوچەرە بەسەرچووە.',
          _ => 'هەڵەیەک ڕووی دا. دووبارە هەوڵ بدەرەوە.',
        };
        _setMsg(message, false);
        return;
      }
      final amtIqd = (result['amount_iqd'] as num?)?.round() ?? 0;

      _codeCtrl.clear();
      _setMsg(
        '🎉 ${_fmtIqd(amtIqd)} IQD زیادکرا بۆ باڵانسەکەت',
        true,
      );
      await _loadAll();
    } catch (e) {
      debugPrint('VoucherPage: claim failed: $e');
      _setMsg('نەتوانرا فاوچەرەکە بەکاربهێنرێت — دووبارە هەوڵ بدەرەوە', false);
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  void _setMsg(String msg, bool ok) {
    if (mounted) setState(() { _msg = msg; _msgOk = ok; });
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _fmtIqd(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  int? _daysLeft(dynamic expiresAt) {
    if (expiresAt == null) return null;
    final exp = DateTime.tryParse(expiresAt.toString());
    if (exp == null) return null;
    return exp.difference(DateTime.now()).inDays.clamp(0, 9999);
  }

  Map<String, dynamic> _reasonMeta(Map<String, dynamic> v) {
    if (v['is_signup_bonus'] == true) {
      return {'icon': FontAwesomeIcons.handHoldingHeart,
              'color': const Color(0xFF06B6D4), 'label': 'دیاری بەخێرهاتن'};
    }
    final r = (v['reason'] ?? '').toString().trim();
    if (r == 'گەڕانەوەی پارە') {
      return {'icon': FontAwesomeIcons.rotateLeft,
              'color': const Color(0xFF16A34A), 'label': r};
    }
    if (r == 'قەرەبووکردنەوە') {
      return {'icon': FontAwesomeIcons.handshake,
              'color': const Color(0xFFF59E0B), 'label': r};
    }
    if (r == 'پاداشت') {
      return {'icon': FontAwesomeIcons.gift,
              'color': const Color(0xFFA855F7), 'label': r};
    }
    return {'icon': FontAwesomeIcons.ticket,
            'color': const Color(0xFFA855F7),
            'label': r.isNotEmpty ? r : 'فاوچەری تایبەت'};
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).viewPadding.top;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _cBg,
        body: Column(children: [

          // ── Header ──────────────────────────────────────────────────────────
          FadeTransition(
            opacity: CurvedAnimation(parent: _anim, curve: Curves.easeOut),
            child: Container(
              padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 18),
              decoration: const BoxDecoration(
                color: AppColors.surfaceCard,
                border: Border(bottom: BorderSide(color: _cB1)),
              ),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: _cBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _cB1),
                    ),
                    child: const Center(
                      child: FaIcon(FontAwesomeIcons.arrowRight,
                          size: 15, color: _cDark)),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('فاوچەرەکان',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // Was 18 — every other in-page bar title in the app
                    // (tasks_page, levels_page, discount_codes_page) is 16;
                    // aligned here too. Weight was already SemiBold.
                    style: TextStyle(fontFamily: kAppFont, fontSize: 16,
                      fontWeight: FontWeight.w600, color: _cDark,
                      height: 1.16,
                      decoration: TextDecoration.none)),
                ),
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF06B6D4).withOpacity(0.25)),
                  ),
                  child: const Center(
                    child: FaIcon(FontAwesomeIcons.ticket,
                        size: 14, color: Color(0xFF06B6D4))),
                ),
              ]),
            ),
          ),

          // ── Scrollable body ──────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
              child: FadeTransition(
                opacity: CurvedAnimation(parent: _anim, curve: Curves.easeOut),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [

                  // ── Code input section ───────────────────────────────────────
                  const Text('کۆدی فاوچەر',
                    style: TextStyle(fontFamily: kAppFont, fontSize: 12.5,
                      fontWeight: FontWeight.w600, color: _cDark,
                      decoration: TextDecoration.none)),
                  const SizedBox(height: 8),

                  // Input + paste row
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _cB1, width: 1.5),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          child: TextField(
                            controller: _codeCtrl,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: kAppFont,
                              // "Regular for ... form fields" — was Bold
                              fontWeight: FontWeight.w400,
                              letterSpacing: 1.5,
                              fontSize: 13,
                              color: _cDark,
                              decoration: TextDecoration.none,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'کۆدەکەت لێرە بنووسە',
                              hintStyle: TextStyle(
                                fontFamily: kAppFont,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0,
                                fontSize: 13,
                                color: _cMt,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding:
                                  EdgeInsets.symmetric(vertical: 12),
                            ),
                            onChanged: (v) {
                              if (v != v.toUpperCase()) {
                                _codeCtrl.value = _codeCtrl.value.copyWith(
                                  text: v.toUpperCase(),
                                  selection: TextSelection.collapsed(
                                      offset: v.length),
                                );
                              }
                            },
                            onSubmitted: (_) => _onClaim(),
                          ),
                        ),
                      ),
                      // Paste button
                      GestureDetector(
                        onTap: _pasteCode,
                        child: Container(
                          width: 44, height: 48,
                          decoration: BoxDecoration(
                            border: Border(left: BorderSide(color: _cB1)),
                          ),
                          child: const Center(
                            child: FaIcon(FontAwesomeIcons.paste,
                                size: 14, color: _cMt)),
                        ),
                      ),
                    ]),
                  ),

                  // Message area — success and failure both render through
                  // the app's shared inline banner. It sits above the claim
                  // button in the layout, so it never covers the button or the
                  // code field, and the sheet grows instead of jumping.
                  if (_msg.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ProxoInlineError(
                      message: _msg,
                      tone: _msgOk
                          ? ProxoErrorTone.success
                          : ProxoErrorTone.danger,
                      textAlign: TextAlign.start,
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Claim button
                  GestureDetector(
                    onTap: _claiming ? null : _onClaim,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _claiming
                            ? _cDark.withOpacity(0.7)
                            : _cDark,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: _claiming ? [] : [
                          BoxShadow(
                            color: _cDark.withOpacity(0.25),
                            blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_claiming)
                            const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          else
                            const FaIcon(FontAwesomeIcons.ticket,
                                size: 14, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(_claiming ? 'چاوەڕوانبە...' : 'چالاککردن',
                            style: const TextStyle(
                              fontFamily: kAppFont,
                              fontSize: 13.5,
                              // button role: SemiBold, not Bold
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              decoration: TextDecoration.none)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── My vouchers section ─────────────────────────────────────
                  _sectionHeader(
                    icon: FontAwesomeIcons.gifts,
                    iconBg: const Color(0xFFDB277710),
                    iconFg: const Color(0xFFDB2777),
                    label: 'فاوچەرەکانت',
                  ),
                  const SizedBox(height: 10),

                  if (_loadingVouchers)
                    ..._buildSkeletonCards(3)
                  else if (_assigned.isEmpty)
                    _emptyVouchers()
                  else
                    ..._assigned.map(_buildVoucherCard),

                  // ── History section ─────────────────────────────────────────
                  if (!_loadingVouchers && _history.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    _sectionHeader(
                      icon: FontAwesomeIcons.clockRotateLeft,
                      iconBg: const Color(0xFF16A34A10),
                      iconFg: const Color(0xFF16A34A),
                      label: 'مێژووی فاوچەرەکان',
                    ),
                    const SizedBox(height: 10),
                    ..._history.map(_buildHistoryRow),
                  ],
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── UI helpers ──────────────────────────────────────────────────────────────

  void _onClaim() {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      _setMsg('تکایە کۆدی فاوچەرەکەت بنووسە', false);
      return;
    }
    _claimCode(code);
  }

  Future<void> _pasteCode() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = (data?.text ?? '').trim().toUpperCase();
      if (text.isNotEmpty) {
        _codeCtrl.text = text;
        _codeCtrl.selection =
            TextSelection.collapsed(offset: text.length);
      }
    } catch (_) {}
  }

  Widget _sectionHeader({
    required FaIconData icon,
    required Color iconBg,
    required Color iconFg,
    required String label,
  }) {
    return Row(children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
        child: Center(child: FaIcon(icon, size: 13, color: iconFg)),
      ),
      const SizedBox(width: 8),
      Text(label,
        style: const TextStyle(
          fontFamily: kAppFont,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: _cDark,
          decoration: TextDecoration.none)),
    ]);
  }

  Widget _buildVoucherCard(Map<String, dynamic> v) {
    final amt    = (v['amount_iqd'] as num?)?.toDouble() ?? 0;
    final meta   = _reasonMeta(v);
    final left   = _daysLeft(v['expires_at']);
    final leftTxt = left == null ? 'بێ کۆتایی' : '$left ڕۆژی تر ماوە';
    final Color accentColor = meta['color'] as Color;
    final FaIconData accentIcon = meta['icon'] as FaIconData;

    String sentTxt = '';
    if (v['created_at'] != null) {
      final d = DateTime.tryParse(v['created_at'].toString());
      if (d != null) {
        sentTxt = 'نێردراوە: '
            '${d.day.toString().padLeft(2,'0')}/'
            '${d.month.toString().padLeft(2,'0')}/'
            '${d.year}';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cB1, width: 1.5),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Top row: icon + label + amount
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: FaIcon(accentIcon, size: 15, color: accentColor)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(meta['label'] as String,
                style: const TextStyle(
                  fontFamily: kAppFont, fontSize: 13,
                  // card-title role: SemiBold, not Bold
                  fontWeight: FontWeight.w600, color: _cDark,
                  decoration: TextDecoration.none)),
              if (sentTxt.isNotEmpty)
                Text(sentTxt,
                  style: const TextStyle(
                    fontFamily: kAppFont, fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: _cMt, decoration: TextDecoration.none)),
            ],
          )),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_fmtIqd(amt.round()),
              style: const TextStyle(
                fontFamily: kAppFont, fontSize: 14,
                // value role: SemiBold, not Bold (matches metricLarge's
                // default — big numbers still don't default to Bold)
                fontWeight: FontWeight.w600, color: _cDark,
                decoration: TextDecoration.none)),
            const Text('IQD',
              style: TextStyle(fontFamily: kAppFont, fontSize: 11.5,
                fontWeight: FontWeight.w400,
                color: _cMt, decoration: TextDecoration.none)),
          ]),
        ]),

        const SizedBox(height: 10),

        // Code display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _cBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _cB1),
          ),
          child: Row(children: [
            const FaIcon(FontAwesomeIcons.ticket, size: 11, color: _cMt),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                (v['code'] ?? '—').toString(),
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontFamily: kAppFont,
                  // "Regular for ... values" — was Bold
                  fontWeight: FontWeight.w400,
                  letterSpacing: 1.5,
                  fontSize: 13,
                  color: _cDark,
                  decoration: TextDecoration.none),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 8),

        // Expiry
        Row(children: [
          const FaIcon(FontAwesomeIcons.clock, size: 9, color: _cMt),
          const SizedBox(width: 5),
          Flexible(
            child: Text(leftTxt,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: kAppFont, fontSize: 11.5,
                fontWeight: FontWeight.w400,
                color: _cMt, decoration: TextDecoration.none)),
          ),
        ]),

        const SizedBox(height: 10),

        // Activate button
        GestureDetector(
          onTap: _claiming ? null : () {
            _codeCtrl.text = (v['code'] ?? '').toString().toUpperCase();
            _onClaim();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const FaIcon(FontAwesomeIcons.check, size: 12, color: Colors.white),
                const SizedBox(width: 6),
                const Text('چالاککردن',
                  style: TextStyle(fontFamily: kAppFont, fontSize: 13,
                    // button role: SemiBold, not Bold; was 12.5, just under
                    // the button-role floor
                    fontWeight: FontWeight.w600, color: Colors.white,
                    decoration: TextDecoration.none)),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildHistoryRow(Map<String, dynamic> v) {
    final amt  = (v['amount_iqd'] as num?)?.toDouble() ?? 0;
    String when = '—';
    if (v['used_at'] != null) {
      final d = DateTime.tryParse(v['used_at'].toString());
      if (d != null) {
        when = '${d.day.toString().padLeft(2,'0')}/'
               '${d.month.toString().padLeft(2,'0')}/'
               '${d.year}  '
               '${d.hour.toString().padLeft(2,'0')}:'
               '${d.minute.toString().padLeft(2,'0')}';
      }
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cB1),
      ),
      child: Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFF16A34A).withOpacity(0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Center(
            child: FaIcon(FontAwesomeIcons.check,
                size: 12, color: Color(0xFF16A34A))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text((v['code'] ?? '—').toString(),
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                fontFamily: kAppFont,
                // "Regular for ... values" — was Bold; size aligned to 13
                // to match the other two code displays on this screen
                fontWeight: FontWeight.w400,
                letterSpacing: 1,
                fontSize: 13,
                color: _cDark,
                decoration: TextDecoration.none)),
            Text(when,
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontFamily: kAppFont, fontSize: 11.5,
                fontWeight: FontWeight.w400,
                color: _cMt, decoration: TextDecoration.none)),
          ],
        )),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('+${_fmtIqd(amt.round())}',
            style: const TextStyle(fontFamily: kAppFont, fontSize: 12.5,
              // value role: SemiBold, not Bold
              fontWeight: FontWeight.w600, color: Color(0xFF16A34A),
              decoration: TextDecoration.none)),
          const Text('IQD',
            style: TextStyle(fontFamily: kAppFont, fontSize: 11.5,
              fontWeight: FontWeight.w400,
              color: _cMt, decoration: TextDecoration.none)),
        ]),
      ]),
    );
  }

  Widget _emptyVouchers() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16, offset: const Offset(0, 3))]),
          child: const Center(
            child: FaIcon(FontAwesomeIcons.gift, size: 26, color: _cMt))),
        const SizedBox(height: 14),
        const Text('هیچ فاوچەرێکی چالاکت بەردەست نییە!',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: kAppFont, fontSize: 13,
            fontWeight: FontWeight.w400, height: 1.30,
            color: _cDark,
            decoration: TextDecoration.none)),
      ]),
    );
  }

  List<Widget> _buildSkeletonCards(int count) {
    return List.generate(count, (_) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 140,
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cB1),
      ),
    ));
  }
}
