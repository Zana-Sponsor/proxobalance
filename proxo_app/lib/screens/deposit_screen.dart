import 'dart:async';
import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:solar_iconkit/solar_iconkit.dart';

import '../main.dart' show supabase, kIqdRate;
import '../theme/proxo_ui.dart';
import '../widgets/fastpay_checkout_sheet.dart';
import '../widgets/proxo_toast.dart';
import '../widgets/proxo_text.dart';

const int _kMinIqd = 5000;
const List<int> _kQuickAmounts = [5000, 10000, 25000, 50000];

@immutable
class _Wallet {
  final String key;
  final String name;
  final String number;
  final String logoAsset;
  const _Wallet(this.key, this.name, this.number, this.logoAsset);
  // Retain the canonical credit calculation used by existing requests.
  bool get hasFee => false;
  double get feeRate => 0;
  String get feePercentLabel => '0';
  int creditedIqd(int value) => value;
}

// Only configured payment rails are offered. The old ZainCash, SuperApp,
// Asiacell and Korek entries contained literal XXXXXXX recipient numbers.
const _wallets = [
  _Wallet('fib', 'FIB', '7510074008', 'assets/logos/fib_official.svg'),
  _Wallet(
      'fastpay', 'FastPay', '7510074008', 'assets/logos/fastpay_official.png'),
  _Wallet('kcard', 'Qi Card', '2879264048', 'assets/logos/qi_official.svg'),
];

/// Normalize both Kurdish/Persian and Arabic-Indic digits before validation.
String normalizeDepositDigits(String text) => text.replaceAllMapped(
      RegExp('[٠-٩۰-۹]'),
      (m) {
        final code = m[0]!.codeUnitAt(0);
        return '${code - (code >= 0x06f0 ? 0x06f0 : 0x0660)}';
      },
    );

class DepositScreen extends StatefulWidget {
  /// Isolated widget fixtures may provide synthetic account numbers. Production
  /// callers omit this parameter and use the configured recipient accounts.
  @visibleForTesting
  final Map<String, String> recipientNumberOverrides;
  const DepositScreen({super.key, this.recipientNumberOverrides = const {}});
  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  _Wallet? _wallet;
  final _form = GlobalKey<FormState>();
  final _amtCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  Uint8List? _receipt;
  String _receiptB64 = '';
  bool _submitting = false;
  bool _checkoutOpen = false;
  bool _picking = false;
  String? _error;

  List<_Wallet> get _availableWallets => _wallets
      .map((wallet) => _Wallet(
            wallet.key,
            wallet.name,
            widget.recipientNumberOverrides[wallet.key] ?? wallet.number,
            wallet.logoAsset,
          ))
      .toList();

  bool get _busy => _submitting || _checkoutOpen;
  int get _iqd => int.tryParse(normalizeDepositDigits(_amtCtrl.text)) ?? 0;
  static String _fmt(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

  @override
  void dispose() {
    _amtCtrl.dispose();
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _fail(String text) {
    if (!mounted) return;
    setState(() => _error = text);
    showProxoToast(context, text, type: ProxoToastType.error);
  }

  Future<void> _copyNumber() async {
    final wallet = _wallet;
    if (wallet == null || _busy) return;
    try {
      await Clipboard.setData(ClipboardData(text: wallet.number));
      if (mounted) {
        showProxoToast(context, 'ژمارەکە کۆپی کرا',
            type: ProxoToastType.success);
      }
    } catch (_) {
      _fail('کۆپی نەکرا، دووبارە هەوڵ بدەرەوە.');
    }
  }

  Future<void> _chooseSource() async {
    if (_busy || _picking) return;
    setState(() => _picking = true);
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        showDragHandle: true,
        backgroundColor: Colors.white,
        builder: (ctx) => Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const SolarIcon(SolarIcons.camera,
                  style: SolarIconStyle.linear, size: 24),
              title: const ProxoText('کامێرا', style: ProxoUi.body),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const SolarIcon(SolarIcons.gallery,
                  style: SolarIconStyle.linear, size: 24),
              title: const ProxoText('گەلەری', style: ProxoUi.body),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 16),
          ])),
        ),
      );
      if (source == null || !mounted) return;
      final selected = await ImagePicker().pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1200,
      );
      if (selected == null) return;
      final bytes = await selected.readAsBytes();
      if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
        _fail('وێنەیەکی دروست هەڵبژێرە کە قەبارەکەی کەمتر لە 5 MB بێت.');
        return;
      }
      if (!mounted) return;
      setState(() {
        _receipt = bytes;
        _receiptB64 = base64Encode(bytes);
        _error = null;
      });
    } catch (_) {
      _fail('نەتوانرا وێنەکە بکرێتەوە. ڕێگەپێدانی کامێرا و وێنەکان بپشکنە.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _continue() async {
    if (_busy || _picking) return;
    if (!_form.currentState!.validate()) return;
    if (_wallet == null) {
      _fail('ڕێگای پارەدان هەڵبژێرە');
      return;
    }
    setState(() => _error = null);
    if (_wallet!.key == 'fastpay') {
      await _openFastPay();
    } else {
      await _submit();
    }
  }

  Future<void> _submit() async {
    if (_submitting || _checkoutOpen) return;
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
      _fail('تکایە وێنەی وەسڵ دابنێ');
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    final enteredIqd = _iqd;
    final receiptB64 = _receiptB64;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('no session');

      final wallet = _wallet!;
      // Preserve the existing IQD-to-USD amount contract for configured rails.
      final creditedIqd = wallet.creditedIqd(enteredIqd);
      final amountUsd = creditedIqd / kIqdRate;

      // Commit the canonical request first. deposit_number / tx_id / public_transaction_id are all
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
                'نێردراو: ${_fmt(enteredIqd)} IQD | باج ${wallet.feePercentLabel}% | '
                    'وەرگیراو: ${_fmt(creditedIqd)} IQD',
              if (note.isNotEmpty) note,
            ].join(' | '),
            'status': 'pending',
            'type': 'deposit',
            'receipt_b64': receiptB64,
          })
          .select('public_transaction_id')
          .single();

      final txId = row['public_transaction_id']?.toString();

      if (txId != null && txId.isNotEmpty) {
        unawaited(() async {
          // Mirror only committed requests for the existing admin panel.
          try {
            final db = FirebaseDatabase.instance;
            final ref = db.ref('requests/${user.id}/$txId');
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
            await db.ref('allRequests/$txId').set({...payload, 'reqId': txId});
          } catch (e) {
            // The committed Supabase row is the record of truth; RTDB is a mirror.
            debugPrint('DepositScreen: rtdb mirror failed: $e');
          }
        }());
      }

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
                'amount_iqd': enteredIqd,
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
        'داواکارییەکەت نێردرا و چاوەڕوانی پشکنینە',
        type: ProxoToastType.success,
      );
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      // Money-adjacent: the user needs to know it did not go through, not
      // what Postgrest called the failure.
      debugPrint('DepositScreen: submit failed: $e');
      if (mounted) {
        setState(() => _error =
            'داواکارییەکە نەنێردرا. پەیوەندییەکەت بپشکنە و دووبارە هەوڵ بدەرەوە.');
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

  Future<void> _openFastPay() async {
    if (_busy) return;
    if (_iqd < _kMinIqd) {
      _fail('کەمترین بڕ ${_fmt(_kMinIqd)} دینارە');
      return;
    }
    final user = supabase.auth.currentUser;
    if (user == null) {
      _fail('تکایە سەرەتا بچۆ ژوورەوە');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _checkoutOpen = true);
    try {
      final paid = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => FastPayCheckoutSheet(amountIqd: _iqd, userId: user.id),
      );
      if (paid == true && mounted) Navigator.of(context).pop(true);
    } catch (_) {
      _fail('پارەدان نەکرایەوە. دووبارە هەوڵ بدەرەوە.');
    } finally {
      if (mounted) setState(() => _checkoutOpen = false);
    }
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: ProxoUi.secondary,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ProxoUi.controlRadius),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ProxoUi.controlRadius),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ProxoUi.controlRadius),
            borderSide: const BorderSide(color: Color(0xFF046CFA), width: 1.5)),
        errorMaxLines: 3,
      );

  @override
  Widget build(BuildContext context) {
    final fastpay = _wallet?.key == 'fastpay';
    final manual = _wallet != null && !fastpay;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: !_submitting,
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            toolbarHeight: 56,
            title: const ProxoText('زیادکردنی باڵانس', style: ProxoUi.title),
            leading: IconButton(
              tooltip: 'گەڕانەوە',
              onPressed:
                  _submitting ? null : () => Navigator.of(context).maybePop(),
              icon: const SolarIcon(SolarIcons.altArrowRight,
                  style: SolarIconStyle.linear, size: 24),
            ),
            bottom: const PreferredSize(
                preferredSize: Size.fromHeight(1),
                child: Divider(height: 1, color: Color(0xFFF1F5F9))),
          ),
          body: SafeArea(
              top: false,
              child: Center(
                  child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Form(
                    key: _form,
                    child: ListView(
                      key: const ValueKey('deposit-scroll'),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      children: [
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const ProxoText(
                                  'بڕی پارە و ڕێگای پارەدان هەڵبژێرە بۆ زیادکردنی باڵانس.',
                                  style: ProxoUi.secondary),
                              const SizedBox(height: 24),
                              const _SectionTitle('١', 'بڕی پارە'),
                              const SizedBox(height: 12),
                              TextFormField(
                                key: const ValueKey('deposit-amount'),
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                enabled: !_busy,
                                controller: _amtCtrl,
                                textDirection: TextDirection.ltr,
                                textAlign: TextAlign.left,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                inputFormatters: [
                                  TextInputFormatter.withFunction(
                                      (oldValue, value) {
                                    final normalized =
                                        normalizeDepositDigits(value.text);
                                    if (!RegExp(r'^\d*$')
                                        .hasMatch(normalized)) {
                                      return oldValue;
                                    }
                                    return value.copyWith(text: normalized);
                                  }),
                                  LengthLimitingTextInputFormatter(12),
                                ],
                                style: ProxoUi.amount,
                                onChanged: (_) => setState(() {}),
                                validator: (_) => _iqd < _kMinIqd
                                    ? 'کەمترین بڕ ${_fmt(_kMinIqd)} دینارە'
                                    : null,
                                decoration: _inputDecoration('0').copyWith(
                                  suffixIcon: const Center(
                                      widthFactor: 1,
                                      child: ProxoText('IQD',
                                          textDirection: TextDirection.ltr,
                                          style: ProxoUi.label)),
                                  suffixIconConstraints: const BoxConstraints(
                                      minWidth: 56, minHeight: 48),
                                  helperText:
                                      'کەمترین بڕ ${_fmt(_kMinIqd)} دینارە',
                                  helperStyle: ProxoUi.secondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              LayoutBuilder(builder: (context, constraints) {
                                final columns =
                                    constraints.maxWidth >= 340 ? 4 : 2;
                                final width =
                                    (constraints.maxWidth - 8 * (columns - 1)) /
                                        columns;
                                return Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _kQuickAmounts
                                        .map((amount) => SizedBox(
                                              width: width,
                                              child: ChoiceChip(
                                                label: SizedBox(
                                                    width: double.infinity,
                                                    child: ProxoText(
                                                        _fmt(amount),
                                                        textAlign:
                                                            TextAlign.center,
                                                        textDirection:
                                                            TextDirection.ltr,
                                                        style: ProxoUi.label)),
                                                selected: _iqd == amount,
                                                showCheckmark: false,
                                                selectedColor:
                                                    const Color(0xFFEAF2FF),
                                                side: BorderSide(
                                                    color: _iqd == amount
                                                        ? const Color(
                                                            0xFF046CFA)
                                                        : const Color(
                                                            0xFFE2E8F0)),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12)),
                                                materialTapTargetSize:
                                                    MaterialTapTargetSize
                                                        .padded,
                                                onSelected: _busy
                                                    ? null
                                                    : (_) => setState(() =>
                                                        _amtCtrl.text =
                                                            '$amount'),
                                              ),
                                            ))
                                        .toList());
                              }),
                              const SizedBox(height: 24),
                              const _SectionTitle('٢', 'ڕێگای پارەدان'),
                              const SizedBox(height: 12),
                              ..._availableWallets.map((wallet) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _WalletCard(
                                        wallet: wallet,
                                        selected: _wallet?.key == wallet.key,
                                        onTap: _busy
                                            ? null
                                            : () => setState(() {
                                                  _wallet = wallet;
                                                  _error = null;
                                                })),
                                  )),
                              if (_wallet != null) ...[
                                const SizedBox(height: 16),
                                if (fastpay)
                                  _panel(children: [
                                    const ProxoText('پارەدانی ئۆنلاین',
                                        style: ProxoUi.sectionTitle),
                                    const SizedBox(height: 8),
                                    const ProxoText(
                                        'لە هەنگاوی داهاتوودا پارەدان بە FastPay تەواو بکە. پێویست بە ناردنی وەسڵ نییە.',
                                        style: ProxoUi.secondary),
                                  ])
                                else
                                  _paymentDetails(),
                              ],
                              if (manual) ...[
                                const SizedBox(height: 24),
                                const _SectionTitle(
                                    '٣', 'زانیاری پارەدان و وەسڵ'),
                                const SizedBox(height: 12),
                                const ProxoText('ناوی خاوەنی هەژمار',
                                    style: ProxoUi.label),
                                const SizedBox(height: 8),
                                ProxoDirectionalInput(
                                    controller: _nameCtrl,
                                    builder: (_, direction) => TextFormField(
                                          key: const ValueKey('deposit-name'),
                                          autovalidateMode: AutovalidateMode
                                              .onUserInteraction,
                                          enabled: !_busy,
                                          controller: _nameCtrl,
                                          textDirection: direction,
                                          textInputAction: TextInputAction.next,
                                          style: ProxoUi.body,
                                          maxLength: 120,
                                          decoration: _inputDecoration(
                                                  'ناوی خاوەنی هەژمار')
                                              .copyWith(counterText: ''),
                                          validator: (v) =>
                                              (v ?? '').trim().isEmpty
                                                  ? 'ناوی هەژمار بنووسە'
                                                  : null,
                                        )),
                                const SizedBox(height: 16),
                                const ProxoText('تێبینی (ئارەزوومەندانە)',
                                    style: ProxoUi.label),
                                const SizedBox(height: 8),
                                ProxoDirectionalInput(
                                    controller: _noteCtrl,
                                    builder: (_, direction) => TextFormField(
                                          key: const ValueKey('deposit-note'),
                                          enabled: !_busy,
                                          controller: _noteCtrl,
                                          textDirection: direction,
                                          style: ProxoUi.body,
                                          minLines: 2,
                                          maxLines: 4,
                                          maxLength: 500,
                                          decoration: _inputDecoration(
                                              'زانیارییەکی زیادە'),
                                        )),
                                const SizedBox(height: 16),
                                _receiptUpload(),
                              ],
                              if (_error != null) ...[
                                const SizedBox(height: 16),
                                Semantics(
                                    liveRegion: true,
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                          color: const Color(0xFFFEF2F2),
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      child: ProxoText(_error!,
                                          style: ProxoUi.body.copyWith(
                                              color: const Color(0xFFDC2626))),
                                    )),
                              ],
                              const SizedBox(height: 24),
                              FilledButton(
                                key: const ValueKey('deposit-submit'),
                                onPressed: _busy || _picking ? null : _continue,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  backgroundColor: const Color(0xFF046CFA),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: _busy
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : ProxoText(
                                        fastpay
                                            ? 'بەردەوامبە بۆ پارەدان'
                                            : 'ناردنی داواکاری',
                                        textAlign: TextAlign.center,
                                        style: ProxoUi.label
                                            .copyWith(color: Colors.white)),
                              ),
                            ])
                      ],
                    )),
              ))),
        ),
      ),
    );
  }

  Widget _panel({required List<Widget> children}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );

  Widget _paymentDetails() => KeyedSubtree(
      key: const ValueKey('deposit-payment-details'),
      child: _panel(children: [
        ProxoText('زانیاری پارەدان • ${_wallet!.name}',
            style: ProxoUi.sectionTitle),
        const SizedBox(height: 12),
        const ProxoText('ژمارەی وەرگر', style: ProxoUi.secondary),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
              child: SelectableText(_wallet!.number,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  style: ProxoUi.amount)),
          const SizedBox(width: 8),
          IconButton.filledTonal(
              onPressed: _busy ? null : _copyNumber,
              tooltip: 'کۆپیکردنی ژمارە',
              icon: const SolarIcon(SolarIcons.copy,
                  style: SolarIconStyle.linear, size: 20)),
        ]),
        const SizedBox(height: 12),
        const ProxoText('١. بڕەکە بنێرە بۆ ژمارەی سەرەوە؛ ناوی وەرگر پشکنە.',
            style: ProxoUi.secondary),
        const SizedBox(height: 8),
        const ProxoText('٢. وێنەی وەسڵی گواستنەوە دابنێ و داواکاری بنێرە.',
            style: ProxoUi.secondary),
        const SizedBox(height: 8),
        const ProxoText(
            'باڵانس دوای پشکنین و پەسەندکردنی داواکاری زیاد دەکرێت.',
            style: ProxoUi.secondary),
      ]));

  Widget _receiptUpload() => _panel(children: [
        Row(children: [
          const SolarIcon(SolarIcons.gallery,
              style: SolarIconStyle.linear, size: 24, color: Color(0xFF046CFA)),
          const SizedBox(width: 12),
          Expanded(
              child: ProxoText(
                  _receipt == null ? 'وەسڵی پارەدان' : 'وەسڵەکە دانرا',
                  style: ProxoUi.cardTitle)),
        ]),
        const SizedBox(height: 12),
        if (_receipt != null) ...[
          ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(_receipt!,
                  height: 128,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const ProxoText(
                      'وێنەکە بار نەبوو؛ وێنەیەکی تر هەڵبژێرە.',
                      style: ProxoUi.secondary))),
          const SizedBox(height: 12),
        ] else ...[
          const ProxoText('وێنەی وەسڵ لە کامێرا یان گەلەری هەڵبژێرە.',
              style: ProxoUi.secondary),
          const SizedBox(height: 12),
        ],
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton(
              onPressed: _busy || _picking ? null : _chooseSource,
              child: ProxoText(
                  _picking
                      ? 'بارکردن…'
                      : _receipt == null
                          ? 'هەڵبژاردنی وێنە'
                          : 'گۆڕینی وێنە',
                  style: ProxoUi.label)),
          if (_receipt != null)
            TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _receipt = null;
                          _receiptB64 = '';
                        }),
                child: ProxoText('سڕینەوە',
                    style: ProxoUi.label
                        .copyWith(color: const Color(0xFFDC2626)))),
        ]),
      ]);
}

class _SectionTitle extends StatelessWidget {
  final String number;
  final String title;
  const _SectionTitle(this.number, this.title);
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(8)),
            child: ProxoText(number,
                style: ProxoUi.label.copyWith(color: const Color(0xFF046CFA)))),
        const SizedBox(width: 8),
        Expanded(child: ProxoText(title, style: ProxoUi.sectionTitle)),
      ]);
}

class _WalletCard extends StatelessWidget {
  final _Wallet wallet;
  final bool selected;
  final VoidCallback? onTap;
  const _WalletCard(
      {required this.wallet, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        label: wallet.name,
        child: Material(
          color: selected ? const Color(0xFFF1F6FF) : Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                  color: selected
                      ? const Color(0xFF046CFA)
                      : const Color(0xFFE2E8F0))),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Container(
                      width: 56,
                      height: 44,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8)),
                      child: wallet.logoAsset.endsWith('.svg')
                          ? SvgPicture.asset(wallet.logoAsset,
                              fit: BoxFit.contain, semanticsLabel: wallet.name)
                          : Image.asset(wallet.logoAsset,
                              fit: BoxFit.contain,
                              semanticLabel: wallet.name,
                              errorBuilder: (_, __, ___) => const SolarIcon(
                                  SolarIcons.wallet,
                                  style: SolarIconStyle.linear,
                                  size: 24))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        ProxoText(wallet.name, style: ProxoUi.cardTitle),
                        const SizedBox(height: 4),
                        ProxoText(
                            wallet.key == 'fastpay'
                                ? 'پارەدانی ئۆنلاین'
                                : 'گواستنەوەی دەستی',
                            style: ProxoUi.secondary),
                      ])),
                  const SizedBox(width: 8),
                  if (selected)
                    const SolarIcon(SolarIcons.checkCircle,
                        style: SolarIconStyle.linear,
                        size: 22,
                        color: Color(0xFF046CFA))
                  else
                    Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFF94A3B8), width: 1.5))),
                ]),
              )),
        ),
      );
}
