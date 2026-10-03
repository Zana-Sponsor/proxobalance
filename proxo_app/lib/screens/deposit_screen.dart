// ═══════════════════════════════════════════════════════════════════════
// DEPOSIT SCREEN — full-screen balance top-up.
//
// Replaces the three-step modal `_DepositSheet` (part of proxo_sidebar.dart)
// with a single scrolling page: wallet grid -> instructions -> amount ->
// receipt -> submit.
//
// Backend contract is unchanged from the sheet, deliberately:
//   1. Firebase RTDB  requests/<uid>  +  allRequests/<key>   (admin panel)
//   2. Supabase       pa_transactions insert
//   3. Telegram       now via the `notify-deposit-request` Edge Function
//                     instead of a bot token compiled into this client.
//
// Two things the sheet got wrong that are fixed here:
//   • It generated `deposit_number` client-side. That column is text and is
//     filled by the `auto_deposit_number` BEFORE INSERT trigger, so the
//     hand-rolled 6-digit int was overwritten every time. It is no longer
//     sent.
//   • The receipt only ever reached Telegram. pa_transactions has a
//     `receipt_b64` column, so it is now persisted on the row as well —
//     which is also what lets the Edge Function re-read it under RLS
//     instead of trusting an image handed to it by the caller.
// ═══════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart' show supabase, kIqdRate;
import '../theme/app_theme.dart';
import '../widgets/fastpay_checkout_sheet.dart';
import '../widgets/proxo_toast.dart';
import 'package:proxo_app/widgets/proxo_text.dart';

// ── Palette ────────────────────────────────────────────────────────────
const Color _cInk = Color(0xFF0F172A);
const Color _cInk2 = Color(0xFF334155);
const Color _cSlate = Color(0xFF64748B);
const Color _cMuted = Color(0xFF94A3B8);
const Color _cLine = Color(0xFFE2E8F0);
const Color _cHair = Color(0xFFF2F3F5);
const Color _cStroke = Color(0xFFF1F5F9);
const Color _cSoft = Color(0xFFF8FAFC);
const Color _cDash = Color(0xFFE2E8EE);

const double _kPageMargin = 16;
const double _kCardRadius = 16;
const double _kInputRadius = 14;
const double _kBtnHeight = 52;
const double _kBtnRadius = 26;

/// Minimum accepted top-up, matching the old sheet's validation.
const int _kMinIqd = 5000;

/// One-tap amounts. Note the sheet shipped 18000/45000/90000/180000, which
/// were round USD tiers at kIqdRate rather than round IQD figures — change
/// this list, not the widgets, if the tiers matter commercially.
const List<int> _kQuickAmounts = [5000, 10000, 25000, 50000];

// ── Wallets ────────────────────────────────────────────────────────────

@immutable
class _Wallet {
  final String key;
  final String name;

  /// Recipient account / phone. Placeholders are deliberate and obvious —
  /// see the note on [_kWallets].
  final String number;
  final IconData icon;
  final Color iconBg;
  final String? logoAsset;
  final bool numberIsPlaceholder;

  /// Share of the transfer swallowed before it reaches the app balance.
  /// Telecom balance transfers (Asiacell / Korek) cost 18%; bank and wallet
  /// rails cost nothing. 0.0 means "credited 1:1".
  final double feeRate;

  const _Wallet({
    required this.key,
    required this.name,
    required this.number,
    required this.icon,
    required this.iconBg,
    this.logoAsset,
    this.numberIsPlaceholder = false,
    this.feeRate = 0,
  });

  bool get hasFee => feeRate > 0;

  /// What actually lands in the user's balance, in IQD.
  int creditedIqd(int enteredIqd) => (enteredIqd * (1 - feeRate)).round();

  /// 18% -> "18"
  String get feePercentLabel => (feeRate * 100).round().toString();
}

/// FIB / FastPay / Qi Card carry the real numbers already in production
/// (from the old `_kDepMethods`). ZainCash and SuperApp are new to this
/// screen and have no account on file yet, so they ship with visibly fake
/// numbers and are flagged in the UI rather than silently accepting money
/// to a wrong destination.
const List<_Wallet> _kWallets = [
  _Wallet(
    key: 'fib',
    name: 'FIB',
    number: '7510074008',
    icon: Icons.account_balance_rounded,
    iconBg: Color(0xFFE3F4F0),
    logoAsset: 'assets/logos/fib.jpg',
  ),
  _Wallet(
    key: 'fastpay',
    name: 'FastPay',
    number: '7510074008',
    icon: Icons.flash_on_rounded,
    iconBg: Color(0xFFFCE4EC),
    logoAsset: 'assets/logos/fastpay.jpg',
  ),
  _Wallet(
    key: 'kcard',
    name: 'Qi Card',
    number: '2879264048',
    icon: Icons.credit_card_rounded,
    iconBg: Color(0xFFFFF8DC),
    logoAsset: 'assets/logos/qicard.jpg',
  ),
  _Wallet(
    key: 'zaincash',
    name: 'ZainCash',
    number: '0750XXXXXXX',
    icon: Icons.account_balance_wallet_rounded,
    iconBg: Color(0xFFF3E8FF),
    numberIsPlaceholder: true,
  ),
  _Wallet(
    key: 'superapp',
    name: 'SuperApp',
    number: '0750XXXXXXX',
    icon: Icons.apps_rounded,
    iconBg: Color(0xFFE0F2FE),
    numberIsPlaceholder: true,
  ),
  _Wallet(
    key: 'asiacell',
    name: 'Asiacell',
    number: '0770XXXXXXX',
    icon: Icons.sim_card_rounded,
    iconBg: Color(0xFFFEE2E2),
    numberIsPlaceholder: true,
    feeRate: 0.18,
  ),
  _Wallet(
    key: 'korek',
    name: 'Korek Telecom',
    number: '0750XXXXXXX',
    icon: Icons.signal_cellular_alt_rounded,
    iconBg: Color(0xFFFEF3C7),
    numberIsPlaceholder: true,
    feeRate: 0.18,
  ),
];

const List<String> _kBaseSteps = [
  'بڕی پارەی دیاریکراو بنێرە بۆ ئەم ژمارەیەی سەرەوە.',
  'دڵنیابەرەوە لە ناوی وەرگر پێش تەواوکردنی گواستنەوە.',
  'سکرینشۆتی وەسڵی تەواوبوونی مامەڵەکە بگرە.',
  'وەسڵەکە لە بەشی خوارەوە دابنێ و داواکاری بنێرە.',
];

/// The fee note is appended only for rails that actually charge one, so the
/// bank wallets don't carry a warning that doesn't apply to them.
List<String> _stepsFor(_Wallet w) => [
      ..._kBaseSteps,
      if (w.hasFee)
        'تێبینی: بەهۆی تێچووی باڵانسەوە، لە هەر بڕە پارەیەک '
            '${w.feePercentLabel}% کەمتر زیاد دەکرێت بۆ باڵانسی ئەپەکەت.',
    ];

// ── Screen ─────────────────────────────────────────────────────────────

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  _Wallet? _wallet;
  final _amtCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  File? _receipt;
  String _receiptB64 = '';
  int? _quickSelected;
  bool _submitting = false;

  int get _iqd => int.tryParse(_amtCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  @override
  void dispose() {
    _amtCtrl.dispose();
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  static String _fmt(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  // ── Actions ──────────────────────────────────────────────────────────

  Future<void> _copyNumber() async {
    final w = _wallet;
    if (w == null) return;
    await Clipboard.setData(ClipboardData(text: w.number));
    if (!mounted) return;
    showProxoToast(context, 'ژمارەکە کۆپی کرا', type: ProxoToastType.success);
  }

  Future<void> _pickReceipt(ImageSource source) async {
    final xf = await ImagePicker()
        .pickImage(source: source, imageQuality: 60, maxWidth: 900);
    if (xf == null) return;
    final file = File(xf.path);
    // readAsBytes + base64 on a 900px jpeg is small, but it is still work
    // that does not belong in the tap callback's synchronous path.
    final bytes = await file.readAsBytes();
    final b64 = base64Encode(bytes);
    if (!mounted) return;
    setState(() {
      _receipt = file;
      _receiptB64 = b64;
    });
  }

  Future<void> _chooseSource() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: _cLine,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.photo_camera_rounded, color: _cInk),
            title: const ProxoText('کامێرا',
                style: TextStyle(fontFamily: kAppFont, color: _cInk)),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: _cInk),
            title: const ProxoText('گەلەری',
                style: TextStyle(fontFamily: kAppFont, color: _cInk)),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (src != null) await _pickReceipt(src);
  }

  void _clearReceipt() => setState(() {
        _receipt = null;
        _receiptB64 = '';
      });

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final note = _noteCtrl.text.trim();

    if (_wallet == null) {
      showProxoToast(context, 'ڕێگای پارەدان هەڵبژێرە',
          type: ProxoToastType.error);
      return;
    }
    if (name.isEmpty) {
      showProxoToast(context, 'ناوی هەژمار بنووسە', type: ProxoToastType.error);
      return;
    }
    if (_iqd < _kMinIqd) {
      showProxoToast(context, 'کەمترین بڕ ${_fmt(_kMinIqd)} دینارە',
          type: ProxoToastType.error);
      return;
    }
    if (_receiptB64.isEmpty) {
      showProxoToast(context, 'تکایە وێنەی وەسڵ دابنێ',
          type: ProxoToastType.error);
      return;
    }

    setState(() => _submitting = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('no session');

      final wallet = _wallet!;
      // The balance is credited with what survives the rail's fee, not with
      // what the user handed over — crediting the gross on an 18% rail would
      // silently over-pay every telecom deposit. The gross is preserved in
      // the note and in the Telegram payload so the admin can reconcile.
      final creditedIqd = wallet.creditedIqd(_iqd);
      final amountUsd = creditedIqd / kIqdRate;

      // 1. Firebase RTDB — the admin panel reads these two paths.
      try {
        final db = FirebaseDatabase.instance;
        final ref = db.ref('requests/${user.id}').push();
        final payload = {
          'type': 'deposit',
          'amount': amountUsd,
          'method': wallet.name,
          'name': name,
          'note': note,
          'status': 'pending',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'userId': user.id,
          'userEmail': user.email ?? '',
        };
        await ref.set(payload);
        await db.ref('allRequests/${ref.key}').set({...payload, 'reqId': ref.key});
      } catch (e) {
        // The Supabase row below is the record of truth; RTDB is a mirror.
        debugPrint('DepositScreen: rtdb mirror failed: $e');
      }

      // 2. Supabase. deposit_number / tx_id / public_transaction_id are all
      //    filled by BEFORE INSERT triggers, so none of them are sent.
      final row = await supabase
          .from('pa_transactions')
          .insert({
            'user_id': user.id,
            'amount': amountUsd,
            'method': wallet.key,
            'note': [
              if (name.isNotEmpty) 'ناو: $name',
              if (wallet.hasFee)
                'نێردراو: ${_fmt(_iqd)} IQD | باج ${wallet.feePercentLabel}% | '
                    'وەرگیراو: ${_fmt(creditedIqd)} IQD',
              if (note.isNotEmpty) note,
            ].join(' | '),
            'status': 'pending',
            'type': 'deposit',
            'receipt_b64': _receiptB64,
          })
          .select('public_transaction_id')
          .single();

      final txId = row['public_transaction_id'] as String?;

      // 3. Telegram, via the Edge Function. unawaited: the row is committed
      //    and the user has been told so — a Telegram outage must not read
      //    as a failed deposit request.
      if (txId != null) {
        unawaited(() async {
          try {
            await supabase.functions.invoke(
              'notify-deposit-request',
              body: {
                'transaction_id': txId,
                // Gross handed over vs. net credited — the admin channel
                // needs both to reconcile a telecom transfer against the
                // receipt image.
                'amount_iqd': _iqd,
                'credited_iqd': creditedIqd,
                'fee_percent': (wallet.feeRate * 100).round(),
                'sender_name': name,
              },
            );
          } catch (e) {
            debugPrint('DepositScreen: notify-deposit-request failed: $e');
          }
        }());
      }

      if (!mounted) return;
      showProxoToast(
        context,
        'داواکارییەکەت نێردرا — لە ماوەی ١ کاتژمێردا پەسەند دەکرێت',
        type: ProxoToastType.success,
      );
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      // Money-adjacent: the user needs to know it did not go through, not
      // what Postgrest called the failure.
      debugPrint('DepositScreen: submit failed: $e');
      if (mounted) {
        showProxoToast(
          context,
          'داواکارییەکە نەنێردرا — ئینتەرنێتەکەت بپشکنەوە و دووبارە هەوڵ بدەرەوە',
          type: ProxoToastType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isFastPay = _wallet?.key == 'fastpay';
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: const _DepositAppBar(),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                _kPageMargin, _kPageMargin, _kPageMargin, 32),
            children: [
              const _SectionLabel('ڕێگای پارەدان'),
              const SizedBox(height: 10),
              _walletGrid(),
              // فاستپەی خۆکارە: نە ڕێنمایی دەستی، نە ناو، نە تێبینی،
              // نە وەسڵ — باکئێندەکە خۆی مامەڵەکە پشتڕاست دەکاتەوە.
              if (!isFastPay && _wallet != null) ...[
                const SizedBox(height: 18),
                RepaintBoundary(
                  child: _InstructionCard(
                    wallet: _wallet!,
                    onCopy: _copyNumber,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              const _SectionLabel('بڕی پارە'),
              const SizedBox(height: 10),
              _amountField(),
              if (_wallet?.hasFee == true && _iqd > 0) ...[
                const SizedBox(height: 8),
                _feeBadge(_wallet!),
              ],
              const SizedBox(height: 10),
              _quickChips(),
              if (!isFastPay) ...[
                const SizedBox(height: 18),
                const _SectionLabel('ناوی هەژمار'),
                const SizedBox(height: 10),
                _textField(_nameCtrl, 'ناوی خاوەنی هەژمار'),
                const SizedBox(height: 18),
                const _SectionLabel('تێبینی (ئارەزوومەندانە)'),
                const SizedBox(height: 10),
                _textField(_noteCtrl, 'هەر زانیاریەکی زیادە'),
                const SizedBox(height: 18),
                _receiptBox(),
              ],
              const SizedBox(height: 24),
              _submitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _walletGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _kWallets.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 92,
      ),
      itemBuilder: (_, i) {
        final w = _kWallets[i];
        return _WalletCard(
          wallet: w,
          selected: _wallet?.key == w.key,
          onTap: () => setState(() => _wallet = w),
        );
      },
    );
  }

  Widget _amountField() {
    return Container(
      height: _kBtnHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kInputRadius),
        border: Border.all(color: _cLine),
      ),
      child: Row(children: [
        const SizedBox(width: 14),
        Expanded(
          child: ProxoDirectionalInput(
            controller: _amtCtrl,
            keyboardType: TextInputType.number,
            forceLtr: true,
            builder: (context, inputDirection) => TextField(
              controller: _amtCtrl,
              keyboardType: TextInputType.number,
              textDirection: inputDirection,
              textAlign: TextAlign.start,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() => _quickSelected = null),
              style: const TextStyle(
                fontFamily: kAppFont,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: _cInk,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hint: ProxoText('0'),
                hintStyle: TextStyle(
                  fontFamily: kAppFont,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _cMuted,
                ),
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _cSoft,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: _cLine),
          ),
          child: const ProxoText('IQD',
              style: TextStyle(
                fontFamily: kAppFont,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _cSlate,
              )),
        ),
      ]),
    );
  }

  /// Real-time "what you'll actually receive" line for the telecom rails.
  Widget _feeBadge(_Wallet w) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: ProxoText(
        'بڕی پارەی وەرگیراو: ${_fmt(w.creditedIqd(_iqd))} دینار '
        '(${w.feePercentLabel}% کەمتر بەهۆی باجی باڵانس)',
        style: const TextStyle(
          fontFamily: kAppFont,
          fontSize: 12.5,
          height: 1.6,
          fontWeight: FontWeight.w600,
          color: Color(0xFF92400E),
        ),
      ),
    );
  }

  Widget _quickChips() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _kQuickAmounts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final v = _kQuickAmounts[i];
          final active = _quickSelected == v;
          return GestureDetector(
            onTap: () => setState(() {
              _quickSelected = v;
              _amtCtrl.text = v.toString();
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: ProxoInk.toggle(active, radius: 19),
              child: ProxoText(
                _fmt(v),
                style: TextStyle(
                  fontFamily: kAppFont,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: active ? ProxoInk.onInk : ProxoInk.outlineText,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _textField(TextEditingController c, String hint) {
    return Container(
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cLine),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: ProxoDirectionalInput(
        controller: c,
        builder: (context, inputDirection) => TextField(
          textDirection: inputDirection,
          controller: c,
          style: const TextStyle(
            fontFamily: kAppFont,
            fontSize: 13.5,
            color: _cInk,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            isDense: true,
            hint: proxoFieldText(hint),
            hintStyle: const TextStyle(
              fontFamily: kAppFont,
              fontSize: 13,
              color: _cMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _receiptBox() {
    if (_receipt != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_kCardRadius),
          border: Border.all(color: _cStroke),
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(_receipt!,
                width: 58, height: 58, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: ProxoText('وەسڵەکە دانرا',
                style: TextStyle(
                  fontFamily: kAppFont,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: _cInk,
                )),
          ),
          _MiniAction(label: 'گۆڕین', onTap: _chooseSource),
          const SizedBox(width: 8),
          _MiniAction(label: 'سڕینەوە', onTap: _clearReceipt, danger: true),
        ]),
      );
    }

    return GestureDetector(
      onTap: _chooseSource,
      child: CustomPaint(
        painter: const _DashedBorderPainter(),
        child: Container(
          height: 152,
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                  color: _cSoft, shape: BoxShape.circle),
              child: const Icon(Icons.cloud_upload_rounded,
                  color: _cSlate, size: 24),
            ),
            const SizedBox(height: 12),
            const ProxoText('دانانی وەسڵی پارەدان',
                style: TextStyle(
                  fontFamily: kAppFont,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _cInk,
                )),
            const SizedBox(height: 4),
            const ProxoText('کلیک بکە بۆ هەڵبژاردنی وێنە لە کامێرا یان گەلەری',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: kAppFont, fontSize: 12, color: _cMuted)),
          ]),
        ),
      ),
    );
  }

  /// فاستپەی ڕێڕەوی خۆکاری هەیە، بۆیە دوگمەکە شیتەکەی پارەدان
  /// دەکاتەوە لە جیاتی ناردنی داواکارییەکی دەستی.
  Future<void> _openFastPay() async {
    if (_iqd < _kMinIqd) {
      showProxoToast(context, 'کەمترین بڕ ${_fmt(_kMinIqd)} دینارە',
          type: ProxoToastType.error);
      return;
    }
    final user = supabase.auth.currentUser;
    if (user == null) {
      showProxoToast(context, 'تکایە سەرەتا بچۆ ژوورەوە',
          type: ProxoToastType.error);
      return;
    }

    final paid = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FastPayCheckoutSheet(
        amountIqd: _iqd,
        userId: user.id,
      ),
    );

    if (paid == true && mounted) Navigator.of(context).pop(true);
  }

  Widget _submitButton() {
    final isFastPay = _wallet?.key == 'fastpay';

    if (isFastPay) {
      return GestureDetector(
        onTap: _openFastPay,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF0265FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const ProxoText('بەردەوامبە بۆ پارەدان',
              style: TextStyle(
                fontFamily: kAppFont,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              )),
        ),
      );
    }

    return GestureDetector(
      onTap: _submitting ? null : _submit,
      child: Container(
        height: _kBtnHeight,
        alignment: Alignment.center,
        decoration: _submitting
            ? ProxoInk.disabled(radius: _kBtnRadius)
            : ProxoInk.fill(radius: _kBtnRadius),
        child: _submitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: _cMuted),
              )
            : const ProxoText('ناردنی داواکاری',
                style: TextStyle(
                  fontFamily: kAppFont,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                )),
      ),
    );
  }
}

// ── Chrome ─────────────────────────────────────────────────────────────

class _DepositAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _DepositAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _cHair)),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(children: [
          const Center(
            child: ProxoText('زیادکردنی باڵانس',
                style: TextStyle(
                  fontFamily: kAppFont,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _cInk,
                )),
          ),
          // RTL: `start` is the physical right edge, which is where the back
          // affordance belongs in this app.
          PositionedDirectional(
            start: 4,
            top: 0,
            bottom: 0,
            child: IconButton(
              icon: const Icon(Icons.chevron_right_rounded,
                  color: _cInk, size: 26),
              onPressed: () => Navigator.of(context).maybePop(),
              tooltip: 'گەڕانەوە',
            ),
          ),
        ]),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => ProxoText(
        text,
        style: const TextStyle(
          fontFamily: kAppFont,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _cSlate,
        ),
      );
}

// ── Wallet card ────────────────────────────────────────────────────────

class _WalletCard extends StatelessWidget {
  final _Wallet wallet;
  final bool selected;
  final VoidCallback onTap;

  const _WalletCard({
    required this.wallet,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_kCardRadius),
          border: Border.all(
            color: selected ? _cInk : _cStroke,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: const [
            BoxShadow(
                color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration:
                BoxDecoration(color: wallet.iconBg, shape: BoxShape.circle),
            clipBehavior: Clip.antiAlias,
            child: wallet.logoAsset != null
                ? Image.asset(wallet.logoAsset!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Icon(wallet.icon, color: _cInk, size: 18))
                : Icon(wallet.icon, color: _cInk, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ProxoText(wallet.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: kAppFont,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: _cInk,
                    )),
                const SizedBox(height: 2),
                ProxoText(
                  wallet.numberIsPlaceholder ? 'ژمارە دانەنراوە' : wallet.number,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: wallet.numberIsPlaceholder
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  style: const TextStyle(
                      fontFamily: kAppFont, fontSize: 11.5, color: _cMuted),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Instruction card ───────────────────────────────────────────────────

class _InstructionCard extends StatelessWidget {
  final _Wallet wallet;
  final VoidCallback onCopy;

  const _InstructionCard({required this.wallet, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kCardRadius),
        border: Border.all(color: _cStroke),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ProxoText('ژمارەی وەرگر — ${wallet.name}',
            style: const TextStyle(
              fontFamily: kAppFont,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _cSlate,
            )),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
          decoration: BoxDecoration(
            color: _cSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _cLine),
          ),
          child: Row(children: [
            // The copy button is its own tap target so copying can't be
            // mistaken for re-selecting the wallet.
            GestureDetector(
              onTap: onCopy,
              child: Container(
                width: 40,
                height: 40,
                decoration: ProxoInk.fill(radius: 10, elevated: false),
                child: const Icon(Icons.copy_rounded,
                    color: ProxoInk.onInk, size: 17),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ProxoText(
                wallet.number,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                style: const TextStyle(
                  fontFamily: kAppFont,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _cInk,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ]),
        ),
        if (wallet.numberIsPlaceholder) ...[
          const SizedBox(height: 8),
          const ProxoText(
            '⚠ ژمارەی ئەم ڕێگایە هێشتا دانەنراوە — تکایە ڕێگایەکی تر هەڵبژێرە',
            style: TextStyle(
                fontFamily: kAppFont, fontSize: 12, color: Color(0xFFB45309)),
          ),
        ],
        const SizedBox(height: 14),
        ..._stepsFor(wallet).map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 5,
                  height: 5,
                  decoration:
                      const BoxDecoration(color: _cSlate, shape: BoxShape.circle),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: ProxoText(s,
                      style: const TextStyle(
                        fontFamily: kAppFont,
                        fontSize: 12.5,
                        height: 1.75,
                        color: _cSlate,
                      )),
                ),
              ]),
            )),
      ]),
    );
  }
}

// ── Bits ───────────────────────────────────────────────────────────────

class _MiniAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _MiniAction(
      {required this.label, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _cSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cLine),
        ),
        child: ProxoText(label,
            style: TextStyle(
              fontFamily: kAppFont,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: danger ? const Color(0xFFDC2626) : _cSlate,
            )),
      ),
    );
  }
}

/// Dashed outline matching the drop area in tools_screen.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _cDash
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(_kCardRadius),
    );

    const dash = 7.0;
    const gap = 5.0;
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, (d + dash).clamp(0.0, metric.length)),
          paint,
        );
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => false;
}
