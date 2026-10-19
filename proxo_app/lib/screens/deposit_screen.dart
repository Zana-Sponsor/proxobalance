import 'dart:math' as math;
import 'package:flutter_svg/flutter_svg.dart';
import 'auth/auth_models.dart';
import 'package:proxo_app/l10n/proxo_strings.dart';
import '../widgets/proxo_app_bar.dart';
import '../widgets/proxo_symbol.dart';
import 'package:proxo_app/theme/app_locale.dart';
// ═══════════════════════════════════════════════════════════════════════
// DEPOSIT SCREEN — full-screen balance top-up.
//
// Replaces the three-step modal `_DepositSheet` (part of proxo_sidebar.dart)
// with a single scrolling page: payment method -> amount -> payment details
// -> receipt -> submit. FastPay keeps its automatic checkout flow.
//
// Manual top-ups use pa_submit_topup. It prices the selected rail on the
// server and atomically records an idempotent pending request. Approval is a
// separate authorized RPC; an uploaded receipt never credits a wallet.
// ═══════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../services/topup_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart' show supabase;
import '../theme/app_theme.dart';
import '../widgets/fastpay_checkout_sheet.dart';
import '../widgets/proxo_toast.dart';
import 'package:proxo_app/widgets/proxo_text.dart';

// ── Palette ────────────────────────────────────────────────────────────
const Color _cInk = Color(0xFF0F172A);
const Color _cSlate = Color(0xFF64748B);
const Color _cMuted = Color(0xFF94A3B8);
const Color _cLine = Color(0xFFE2E8F0);
const Color _cSoft = Color(0xFFF8FAFC);

const double _kPageMargin = 20;
const double _kCardRadius = 18;
const double _kInputRadius = 14;
const double _kBtnHeight = 52;
const double _kBtnRadius = ProxoControls.radius;

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
/// (from the old `_kDepMethods`). ZainCash, Asiacell and Korek have no
/// configured recipient. Their placeholder values are never selectable,
/// copied or submitted.
const List<_Wallet> _kWallets = [
  _Wallet(
    key: 'fib',
    name: 'FIB',
    number: '7510074008',
    logoAsset: 'assets/logos/providers/fib.svg',
  ),
  _Wallet(
    key: 'fastpay',
    name: 'FastPay',
    number: '7510074008',
    logoAsset: 'assets/logos/providers/fastpay.png',
  ),
  _Wallet(
    key: 'kcard',
    name: 'Qi Card',
    number: '2879264048',
    logoAsset: 'assets/logos/providers/qi.svg',
  ),
  _Wallet(
    key: 'zaincash',
    name: 'ZainCash',
    number: '0750XXXXXXX',
    logoAsset: 'assets/logos/providers/zaincash.svg',
    numberIsPlaceholder: true,
  ),
  _Wallet(
    key: 'asiacell',
    name: 'Asiacell',
    number: '0770XXXXXXX',
    logoAsset: 'assets/logos/providers/asiacell.svg',
    numberIsPlaceholder: true,
    feeRate: 0.18,
  ),
  _Wallet(
    key: 'korek',
    name: 'Korek Telecom',
    number: '0750XXXXXXX',
    logoAsset: 'assets/logos/providers/korek.svg',
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
        ProxoStrings.format(
            'تێبینی: {fee}% کەمتر زیاد دەکرێت بەهۆی تێچووی باڵانسەوە.',
            {'fee': w.feePercentLabel}),
    ];

// ── Screen ─────────────────────────────────────────────────────────────

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key, this.pickReceipt});

  /// Optional platform adapter; production uses the system image picker.
  final Future<XFile?> Function(ImageSource source)? pickReceipt;

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
  bool _pickingReceipt = false;
  bool _loadingReceipt = false;
  bool _checkoutOpen = false;
  bool _instructionsOpen = false;

  bool get _busy => _submitting || _pickingReceipt || _checkoutOpen;

  int get _iqd =>
      int.tryParse(_amtCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

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
    if (w == null || w.numberIsPlaceholder) return;
    try {
      await Clipboard.setData(ClipboardData(text: w.number));
      if (!mounted) return;
      showProxoToast(context, 'ژمارەکە کۆپی کرا', type: ProxoToastType.success);
    } catch (_) {
      if (mounted) {
        showProxoToast(context, 'کۆپی نەکرا؛ دووبارە هەوڵ بدەرەوە.',
            type: ProxoToastType.error);
      }
    }
  }

  Future<void> _chooseSource() async {
    if (_busy) return;
    setState(() => _pickingReceipt = true);
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) => SafeArea(
            child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              key: const ValueKey('deposit-camera'),
              contentPadding: EdgeInsets.zero,
              leading: const ProxoSymbol(ProxoSymbolName.camera, color: _cInk),
              title: const ProxoText('کامێرا', translate: true),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              key: const ValueKey('deposit-gallery'),
              contentPadding: EdgeInsets.zero,
              leading: const ProxoSymbol(ProxoSymbolName.gallery, color: _cInk),
              title: const ProxoText('گەلەری', translate: true),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ]),
        )),
      );
      if (source == null || !mounted) return;
      setState(() => _loadingReceipt = true);
      final image = await (widget.pickReceipt?.call(source) ??
          ImagePicker()
              .pickImage(source: source, imageQuality: 60, maxWidth: 900));
      if (image == null || !mounted) return;
      final file = File(image.path);
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _receipt = file;
        _receiptB64 = base64Encode(bytes);
      });
    } catch (_) {
      if (mounted) {
        showProxoToast(context, 'وێنەکە هەڵنەبژێردرا؛ دووبارە هەوڵ بدەرەوە.',
            type: ProxoToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _pickingReceipt = false;
          _loadingReceipt = false;
        });
      }
    }
  }

  void _clearReceipt() {
    if (_busy) return;
    setState(() {
      _receipt = null;
      _receiptB64 = '';
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    final name = _nameCtrl.text.trim();
    final note = _noteCtrl.text.trim();

    if (_wallet == null) {
      showProxoToast(context, 'ڕێگای پارەدان هەڵبژێرە',
          type: ProxoToastType.error);
      return;
    }
    if (_wallet!.numberIsPlaceholder) {
      showProxoToast(context, 'ژمارە دانەنراوە', type: ProxoToastType.error);
      return;
    }
    if (name.isEmpty) {
      showProxoToast(context, 'ناوی هەژمار بنووسە', type: ProxoToastType.error);
      return;
    }
    if (_iqd < _kMinIqd) {
      showProxoToast(
          context,
          ProxoStrings.format(
              'کەمترین بڕ {amount} دینارە', {'amount': _fmt(_kMinIqd)}),
          type: ProxoToastType.error);
      return;
    }
    if (_receiptB64.isEmpty) {
      showProxoToast(context, 'تکایە وێنەی وەسڵ دابنێ',
          type: ProxoToastType.error);
      return;
    }

    // Capture the exact submitted details before yielding. The notification
    // must describe this request even if the route is closed while awaiting it.
    final wallet = _wallet!;
    final grossIqd = _iqd;
    final receipt = _receiptB64;
    final client = supabase;
    final owner = client.auth.currentUser?.id;
    final route = ModalRoute.of(context);
    bool sameOwner() =>
        identical(supabase, client) &&
        owner != null &&
        client.auth.currentUser?.id == owner;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    try {
      if (owner == null) throw Exception('no session');

      // The server derives the authenticated owner, rail fee and USD credit.
      // A receipt is evidence for review; submitting it does not add balance.
      final row = await TopupService(client).submit(
        method: wallet.key,
        grossIqd: grossIqd,
        sender: name,
        note: note,
        receipt: receipt,
      );
      if (!sameOwner()) return;
      final creditedIqd = row['credited_iqd'] as num;

      final txId = row['public_transaction_id'] as String?;

      // 3. Telegram, via the Edge Function. unawaited: the row is committed
      //    and the user has been told so — a Telegram outage must not read
      //    as a failed deposit request.
      if (txId != null) {
        unawaited(() async {
          try {
            if (!sameOwner()) return;
            await client.functions.invoke(
              'notify-deposit-request',
              body: {
                'transaction_id': txId,
                // Gross handed over vs. net credited — the admin channel
                // needs both to reconcile a telecom transfer against the
                // receipt image.
                'amount_iqd': grossIqd,
                'credited_iqd': creditedIqd,
                'fee_percent': grossIqd == 0
                    ? 0
                    : ((row['fee_iqd'] as num) * 100 / grossIqd).round(),
                'sender_name': name,
              },
            );
          } catch (e) {
            debugPrint('DepositScreen: notify-deposit-request failed: $e');
          }
        }());
      }

      if (!mounted || !sameOwner() || route?.isCurrent != true) return;
      showProxoToast(
        context,
        'داواکارییەکەت نێردرا — لە ماوەی ١ کاتژمێردا پەسەند دەکرێت',
        type: ProxoToastType.success,
      );
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted && sameOwner() && route?.isCurrent == true) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      // Money-adjacent: the user needs to know it did not go through, not
      // what Postgrest called the failure.
      debugPrint('DepositScreen: submit failed: ${e.runtimeType}');
      if (mounted &&
          (owner == null || sameOwner()) &&
          route?.isCurrent == true) {
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

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    final isFastPay = _wallet?.key == 'fastpay';
    return Directionality(
      textDirection: ProxoLocale.directionOf(ProxoLocale.current.value),
      child: Scaffold(
        backgroundColor: AppColors.page,
        appBar: const ProxoAppBar(title: 'زیادکردنی باڵانس'),
        body: SafeArea(
            top: false,
            child: ListView(
              key: const ValueKey('deposit-scroll'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                  math.max(_kPageMargin,
                      (MediaQuery.sizeOf(context).width - 600) / 2),
                  24,
                  math.max(_kPageMargin,
                      (MediaQuery.sizeOf(context).width - 600) / 2),
                  32),
              children: [
                const _SectionTitle('ڕێگای پارەدان'),
                const SizedBox(height: 12),
                _walletGrid(),
                const SizedBox(height: 24),
                _card(key: const ValueKey('deposit-amount-card'), children: [
                  const _SectionTitle('بڕی پارە'),
                  const SizedBox(height: 12),
                  _amountField(),
                  const SizedBox(height: 8),
                  ProxoText(
                      ProxoStrings.format('کەمترین بڕ {amount} دینارە',
                          {'amount': _fmt(_kMinIqd)}),
                      style: _bodyStyle),
                  const SizedBox(height: 12),
                  _quickChips(),
                  if (_wallet != null && _iqd > 0) ...[
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(height: 1, color: _cLine)),
                    _amountSummary(),
                  ],
                ]),
                if (!isFastPay && _wallet != null) ...[
                  const SizedBox(height: 24),
                  _paymentDetails(),
                  const SizedBox(height: 24),
                  _card(key: const ValueKey('deposit-receipt-card'), children: [
                    const _SectionTitle('دانانی وەسڵی پارەدان'),
                    const SizedBox(height: 12),
                    _receiptBox(),
                  ]),
                ],
                const SizedBox(height: 24),
                _submitButton(),
              ],
            )),
      ),
    );
  }

  static const _bodyStyle = TextStyle(
      fontFamily: kAppFont, fontSize: 13, height: 1.5, color: _cSlate);

  Widget _card({required List<Widget> children, Key? key}) => Container(
        key: key,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_kCardRadius),
            border: Border.all(color: _cLine)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _walletGrid() => LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 300 &&
                MediaQuery.textScalerOf(context).scale(14) <= 20
            ? 2
            : 1;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(spacing: 10, runSpacing: 10, children: [
          for (final wallet in _kWallets)
            SizedBox(
                width: width,
                child: _WalletCard(
                    wallet: wallet,
                    selected: _wallet?.key == wallet.key,
                    compact: columns == 1,
                    onTap: _busy || wallet.numberIsPlaceholder
                        ? null
                        : () {
                            FocusScope.of(context).unfocus();
                            setState(() {
                              _wallet = wallet;
                              _instructionsOpen = false;
                            });
                          })),
        ]);
      });

  Widget _amountField() => ProxoDirectionalInput(
        controller: _amtCtrl,
        keyboardType: TextInputType.number,
        forceLtr: true,
        builder: (context, inputDirection) => TextField(
          key: const ValueKey('deposit-amount'),
          controller: _amtCtrl,
          enabled: !_busy,
          keyboardType: TextInputType.number,
          textDirection: inputDirection,
          textAlign: TextAlign.start,
          inputFormatters: [
            TextInputFormatter.withFunction((oldValue, newValue) {
              final text = IraqPhone.latinDigits(newValue.text)
                  .replaceAll(RegExp(r'[^0-9]'), '');
              return TextEditingValue(
                  text: text,
                  selection: TextSelection.collapsed(offset: text.length));
            })
          ],
          onChanged: (_) => setState(() => _quickSelected = null),
          style: const TextStyle(
              fontFamily: kAppFont,
              fontSize: 20,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: _cInk),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: const TextStyle(color: _cMuted),
            filled: true,
            fillColor: _cSoft,
            suffix: const Padding(
                padding: EdgeInsetsDirectional.only(start: 10),
                child: ProxoText('IQD',
                    style: TextStyle(
                        fontFamily: kAppFont,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _cSlate))),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_kInputRadius),
                borderSide: const BorderSide(color: _cLine)),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_kInputRadius)),
          ),
        ),
      );

  Widget _quickChips() => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final amount in _kQuickAmounts)
          SizedBox(
            child: ChoiceChip(
              key: ValueKey('deposit-quick-$amount'),
              selected: _quickSelected == amount,
              showCheckmark: false,
              selectedColor: AppColors.accentSoft,
              backgroundColor: Colors.white,
              side: BorderSide(
                  color: _quickSelected == amount ? AppColors.accent : _cLine),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              materialTapTargetSize: MaterialTapTargetSize.padded,
              visualDensity: VisualDensity.standard,
              labelPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              label: ProxoText(_fmt(amount),
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                      fontFamily: kAppFont,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _quickSelected == amount
                          ? AppColors.accent
                          : _cSlate)),
              onSelected: _busy
                  ? null
                  : (_) => setState(() {
                        _quickSelected = amount;
                        _amtCtrl.text = amount.toString();
                      }),
            ),
          ),
      ]);

  Widget _amountSummary() {
    final wallet = _wallet!;
    final credited = wallet.creditedIqd(_iqd);
    return Column(key: const ValueKey('deposit-fee-summary'), children: [
      _SummaryRow(label: 'بڕی پارە', amount: '${_fmt(_iqd)} IQD'),
      const SizedBox(height: 8),
      _SummaryRow(
          label: 'تێچووی خزمەتگوزاری', amount: '${_fmt(_iqd - credited)} IQD'),
      const SizedBox(height: 10),
      _SummaryRow(
          label: 'زیاد دەکرێت بۆ باڵانس',
          amount: '${_fmt(credited)} IQD',
          strong: true),
    ]);
  }

  Widget _paymentDetails() =>
      _card(key: const ValueKey('deposit-payment-details'), children: [
        const _SectionTitle('وردەکاری پارەدان'),
        const SizedBox(height: 16),
        ProxoText(
            ProxoStrings.format(
                'ژمارەی وەرگر — {provider}', {'provider': _wallet!.name}),
            style: _bodyStyle),
        const SizedBox(height: 8),
        Container(
            padding: const EdgeInsetsDirectional.only(
                start: 12, end: 4, top: 4, bottom: 4),
            decoration: BoxDecoration(
                color: _cSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _cLine)),
            child: Row(children: [
              Expanded(
                  child: ProxoText(_wallet!.number,
                      key: const ValueKey('deposit-recipient'),
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                          fontFamily: kAppFont,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                          color: _cInk))),
              const SizedBox(width: 8),
              IconButton(
                  key: const ValueKey('deposit-copy'),
                  tooltip: ProxoStrings.text('کۆپیکردن'),
                  onPressed: _copyNumber,
                  constraints:
                      const BoxConstraints.tightFor(width: 48, height: 48),
                  style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  icon: const ProxoSymbol(ProxoSymbolName.copy,
                      size: 20, color: AppColors.accent)),
            ])),
        const SizedBox(height: 8),
        TextButton(
            key: const ValueKey('deposit-instructions'),
            onPressed: () =>
                setState(() => _instructionsOpen = !_instructionsOpen),
            style: TextButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 8)),
            child: Row(children: [
              const ProxoSymbol(ProxoSymbolName.info,
                  size: 20, color: AppColors.accent),
              const SizedBox(width: 8),
              const Expanded(
                  child: ProxoText('ڕێنمایی پارەدان',
                      translate: true,
                      style: TextStyle(
                          fontFamily: kAppFont,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent))),
              AnimatedRotation(
                  turns: _instructionsOpen ? .25 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const ProxoSymbol(ProxoSymbolName.forward,
                      size: 18, color: AppColors.accent)),
            ])),
        AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: _instructionsOpen
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final step in _stepsFor(_wallet!))
                            Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: ProxoText(step,
                                    translate: true, style: _bodyStyle)),
                        ]))
                : const SizedBox(width: double.infinity)),
        const SizedBox(height: 8),
        _fieldLabel('ناوی هەژمار'),
        const SizedBox(height: 8),
        _textField(_nameCtrl, 'ناوی خاوەنی هەژمار', 'deposit-sender'),
        const SizedBox(height: 16),
        _fieldLabel('تێبینی (ئارەزوومەندانە)'),
        const SizedBox(height: 8),
        _textField(_noteCtrl, 'هەر زانیاریەکی زیادە', 'deposit-note',
            maxLines: 3),
      ]);

  Widget _fieldLabel(String text) => ProxoText(text,
      translate: true,
      style: const TextStyle(
          fontFamily: kAppFont,
          fontSize: 14,
          height: 1.5,
          color: _cInk,
          fontWeight: FontWeight.w600));

  Widget _textField(TextEditingController controller, String hint, String key,
          {int maxLines = 1}) =>
      ProxoDirectionalInput(
          controller: controller,
          builder: (context, inputDirection) => TextField(
                key: ValueKey(key),
                controller: controller,
                enabled: !_busy,
                textDirection: inputDirection,
                minLines: 1,
                maxLines: maxLines,
                textInputAction: maxLines == 1
                    ? TextInputAction.next
                    : TextInputAction.newline,
                style: const TextStyle(
                    fontFamily: kAppFont,
                    fontSize: 14,
                    height: 1.5,
                    color: _cInk),
                decoration: InputDecoration(
                    hint: proxoFieldText(hint),
                    hintStyle: const TextStyle(fontSize: 13, color: _cSlate),
                    filled: true,
                    fillColor: _cSoft,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _cLine)),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14))),
              ));

  Widget _receiptBox() {
    if (_receipt != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(_receipt!,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.square(
                      dimension: 56,
                      child: ProxoSymbol(ProxoSymbolName.gallery,
                          color: _cSlate)))),
          const SizedBox(width: 12),
          const Expanded(
              child: ProxoText('وەسڵەکە دانرا',
                  translate: true,
                  style: TextStyle(
                      fontFamily: kAppFont,
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: _cInk))),
          const ProxoSymbol(ProxoSymbolName.check,
              color: AppColors.positive, size: 22),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          TextButton(
              key: const ValueKey('deposit-change-receipt'),
              onPressed: _busy ? null : _chooseSource,
              style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
              child: const ProxoText('گۆڕین', translate: true)),
          TextButton(
              key: const ValueKey('deposit-clear-receipt'),
              onPressed: _busy ? null : _clearReceipt,
              style: TextButton.styleFrom(
                  minimumSize: const Size(64, 48),
                  foregroundColor: AppColors.negative),
              child: const ProxoText('سڕینەوە', translate: true)),
        ]),
      ]);
    }
    return Material(
        color: _cSoft,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: _cLine)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const ValueKey('deposit-pick-receipt'),
          onTap: _busy ? null : _chooseSource,
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                SizedBox.square(
                    dimension: 40,
                    child: _loadingReceipt
                        ? const Padding(
                            padding: EdgeInsets.all(9),
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const ProxoSymbol(ProxoSymbolName.upload,
                            color: AppColors.accent, size: 24)),
                const SizedBox(width: 12),
                const Expanded(
                    child: ProxoText(
                        'کلیک بکە بۆ هەڵبژاردنی وێنە لە کامێرا یان گەلەری',
                        translate: true,
                        style: _bodyStyle)),
              ])),
        ));
  }

  Future<void> _openFastPay() async {
    if (_busy || _wallet?.key != 'fastpay') return;
    final amount = _iqd;
    if (amount < _kMinIqd) {
      showProxoToast(
          context,
          ProxoStrings.format(
              'کەمترین بڕ {amount} دینارە', {'amount': _fmt(_kMinIqd)}),
          type: ProxoToastType.error);
      return;
    }
    final client = supabase;
    final user = client.auth.currentUser;
    final route = ModalRoute.of(context);
    if (user == null) {
      showProxoToast(context, 'تکایە سەرەتا بچۆ ژوورەوە',
          type: ProxoToastType.error);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _checkoutOpen = true);
    try {
      final paid = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) =>
              FastPayCheckoutSheet(amountIqd: amount, userId: user.id));
      if (paid == true &&
          mounted &&
          identical(supabase, client) &&
          client.auth.currentUser?.id == user.id &&
          route?.isCurrent == true) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) setState(() => _checkoutOpen = false);
    }
  }

  Widget _submitButton() {
    final available = _wallet != null && !_wallet!.numberIsPlaceholder;
    final fastPay = _wallet?.key == 'fastpay';
    return FilledButton(
      key: const ValueKey('deposit-submit'),
      onPressed: !available || _busy
          ? null
          : fastPay
              ? _openFastPay
              : _submit,
      style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _cLine,
          disabledForegroundColor: _cSlate,
          minimumSize: const Size(double.infinity, _kBtnHeight),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_kBtnRadius))),
      child: _submitting
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: _cSlate))
          : ProxoText(fastPay ? 'بەردەوامبە بۆ پارەدان' : 'ناردنی داواکاری',
              translate: true,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: kAppFont,
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w700)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => ProxoText(text,
      translate: true,
      style: const TextStyle(
          fontFamily: kAppFont,
          fontSize: 18,
          height: 1.4,
          fontWeight: FontWeight.w700,
          color: _cInk));
}

class _WalletCard extends StatelessWidget {
  const _WalletCard(
      {required this.wallet,
      required this.selected,
      required this.compact,
      required this.onTap});
  final _Wallet wallet;
  final bool selected;
  final bool compact;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final logo = SizedBox(
        height: 24,
        width: 64,
        child: wallet.logoAsset!.endsWith('.svg')
            ? SvgPicture.asset(wallet.logoAsset!,
                fit: BoxFit.contain, excludeFromSemantics: true)
            : Image.asset(wallet.logoAsset!,
                fit: BoxFit.contain,
                cacheWidth:
                    (64 * MediaQuery.devicePixelRatioOf(context)).ceil(),
                excludeFromSemantics: true));
    final label = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            compact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          ProxoText(wallet.name,
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                  fontFamily: kAppFont,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  color: _cInk)),
          if (wallet.numberIsPlaceholder) ...[
            const SizedBox(height: 4),
            const ProxoText('ژمارە دانەنراوە',
                translate: true,
                style: TextStyle(
                    fontFamily: kAppFont,
                    fontSize: 12,
                    height: 1.4,
                    color: _cSlate)),
          ],
        ]);
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      label: wallet.name,
      child: Material(
        color: selected ? AppColors.accentSoft : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
                color: selected ? AppColors.accent : _cLine,
                width: selected ? 1.5 : 1)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('deposit-method-${wallet.key}'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: compact ? 76 : 104),
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: compact
                    ? Row(children: [
                        logo,
                        const SizedBox(width: 14),
                        Expanded(child: label),
                        if (selected)
                          const Padding(
                              padding: EdgeInsetsDirectional.only(start: 8),
                              child: ProxoSymbol(ProxoSymbolName.check,
                                  size: 18, color: AppColors.accent)),
                      ])
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            logo,
                            const SizedBox(height: 8),
                            label,
                          ])),
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(
      {required this.label, required this.amount, this.strong = false});
  final String label, amount;
  final bool strong;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final labelWidget = ProxoText(label,
            translate: true,
            style: TextStyle(
                fontFamily: kAppFont,
                fontSize: 13,
                height: 1.5,
                color: strong ? _cInk : _cSlate,
                fontWeight: strong ? FontWeight.w600 : FontWeight.w400));
        final valueWidget = ProxoText(amount,
            textDirection: TextDirection.ltr,
            style: TextStyle(
                fontFamily: kAppFont,
                fontSize: 14,
                height: 1.5,
                color: strong ? AppColors.accent : _cInk,
                fontWeight: FontWeight.w600));
        if (constraints.maxWidth < 280 ||
            MediaQuery.textScalerOf(context).scale(14) > 20) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelWidget, const SizedBox(height: 4), valueWidget]);
        }
        return Row(children: [
          Expanded(child: labelWidget),
          const SizedBox(width: 12),
          valueWidget
        ]);
      });
}
