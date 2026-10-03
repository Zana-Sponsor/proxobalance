// ═══════════════════════════════════════════════════════════════════════════
// FastPayCheckoutSheet — پارەدانی خۆکار لە ڕێگەی فاستپەی
// ═══════════════════════════════════════════════════════════════════════════
//
// ڕێڕەوەکە:
//   ١. پیشاندانی کورتەی مامەڵە + ژمێرەری کات  (دۆخی confirm)
//   ٢. «بەردەوامبە» → داواکاری بۆ وێبهوکی n8n  (fastpay/order-create)
//   ٣. کردنەوەی ئەپی فاستپەی بە دیپ لینک، یان وێبڤیوی ناوەکی وەک فۆڵباک
//   ٤. چاودێری `pa_transactions` تا دۆخەکە دەگۆڕێت
//   ٥. کارتی ئەنجام: سەرکەوتوو / ڕەتکرایەوە / بەسەرچوو
//
// ⚠ سەرچاوەی ڕاستی دۆخی پارەدان **هەمیشە** دەیتابەیسە، نەک ئەپەکە.
// ئەم ویجێتە هەرگیز باڵانس نانووسێت و هەرگیز مامەڵەیەک بە «دراو»
// دانانێت لەسەر بنەمای ئەوەی بەکارهێنەر گەڕایەوە بۆ ئەپەکە — تەنها
// ئەوە پیشان دەدات کە باکئێندەکە پشتڕاستی کردووەتەوە.
//
// ⚠ ژمێرەری کات لە `expires_at`ـی ڕیزەکەوە دەگیرێت هەرکاتێک بەردەست
// بێت، بۆیە ئەپ و باکئێند هەرگیز لە کاتدا لێک جیا نابنەوە.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../main.dart' show supabase;
import '../theme/app_theme.dart' show kAppFont;
import 'proxo_toast.dart';
import 'package:proxo_app/widgets/proxo_text.dart';

// ── ڕێکخستنی باکئێند ──────────────────────────────────────────────────────

/// وێبهوکی دروستکردنی داواکاری لە n8n.
const String kFastPayOrderCreateUrl =
    'https://email.proxopages.com/webhook/fastpay/order-create';

/// پاشگری سکیمی گەڕانەوە. دەبێت وەک خۆی لە `AndroidManifest.xml` و
/// `Info.plist` تۆمار کرابێت: `appfpclientProxo`.
const String kFastPayClientSuffix = 'Proxo';

/// کەمترین بڕ بە دینار — هەمان سنووری `deposit_screen.dart`.
const int kFastPayMinIqd = 5000;

/// درێژی پەنجەرەی پارەدان کاتێک باکئێندەکە `expires_at` ناگەڕێنێتەوە.
const Duration kFastPayFallbackWindow = Duration(minutes: 5);

/// ماوەی نێوان دوو پشکنینی دۆخ.
const Duration kFastPayPollInterval = Duration(seconds: 3);

const String kFastPayLogoAsset = 'assets/logos/fastpay.jpg';

// ── تۆکنەکانی دیزاین ──────────────────────────────────────────────────────

const Color _kInk = Color(0xFF0F172A);
const Color _kSlate = Color(0xFF64748B);
const Color _kLine = Color(0xFFE2E8F0);
const Color _kSoft = Color(0xFFF8FAFC);
const Color _kAccent = Color(0xFF0265FF);

const Color _kDangerBg = Color(0xFFFEF2F2);
const Color _kDangerLine = Color(0xFFFECACA);
const Color _kDangerFg = Color(0xFFDC2626);

const Color _kWarnBg = Color(0xFFFFFBEB);
const Color _kWarnLine = Color(0xFFFDE68A);
const Color _kWarnFg = Color(0xFFD97706);

const Color _kOkBg = Color(0xFFECFDF5);
const Color _kOkLine = Color(0xFFA7F3D0);
const Color _kOkFg = Color(0xFF059669);

const double _kRadius = 16;
const double _kBtnHeight = 52;

const List<BoxShadow> _kSoftElevation = [
  BoxShadow(color: Color(0x05000000), blurRadius: 8, offset: Offset(0, 2)),
];

// ── دۆخەکان ───────────────────────────────────────────────────────────────

enum FastPayPhase { confirm, dispatching, waiting, paid, cancelled, expired }

/// دۆخی گەیتوەی، وەک لە `pa_transactions.gateway_status` تۆمار کراوە.
enum FastPayGatewayStatus { created, paid, declined, expired, failed, unknown }

FastPayGatewayStatus _gatewayStatusFrom(String? raw) {
  switch ((raw ?? '').toUpperCase()) {
    case 'CREATED':
      return FastPayGatewayStatus.created;
    case 'PAID':
      return FastPayGatewayStatus.paid;
    case 'DECLINED':
      return FastPayGatewayStatus.declined;
    case 'EXPIRED':
      return FastPayGatewayStatus.expired;
    case 'FAILED':
    case 'FRAUD_SUSPECT':
      return FastPayGatewayStatus.failed;
    default:
      return FastPayGatewayStatus.unknown;
  }
}

// ── مۆدێلەکان ─────────────────────────────────────────────────────────────

@immutable
class FastPayOrder {
  final String orderId;
  final String? transactionId;
  final String? qrUrl;
  final String? qrText;

  const FastPayOrder({
    required this.orderId,
    this.transactionId,
    this.qrUrl,
    this.qrText,
  });

  /// دیپ لینکی ئەپی فاستپەی. ئەگەر `qrText` نەبێت ناتوانرێت دروست بکرێت.
  String? get deepLink {
    final token = qrText;
    if (token == null || token.isEmpty) return null;
    return 'appFpp://fast-pay.cash/qrpay'
        '?qrdata=${Uri.encodeQueryComponent(token)}'
        '&clientUri=appfpclient$kFastPayClientSuffix'
        '&transactionId=${Uri.encodeQueryComponent(orderId)}';
  }
}

class FastPayException implements Exception {
  final String message;
  const FastPayException(this.message);
  @override
  String toString() => message;
}

// ── خزمەتگوزاری ───────────────────────────────────────────────────────────

class FastPayService {
  const FastPayService._();

  /// ناسنامەیەکی نوێی داواکاری. هەمان شێوازی ئەوانەی لە بەرهەمهێناندان:
  /// `PX` + کاتی یەکەیی + چوار ژمارەی هەڕەمەکی (١٩ پیت — لەنێو ٨ و ٣٢).
  static String newOrderId() {
    final ms = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(10000).toString().padLeft(4, '0');
    return 'PX$ms$rand';
  }

  /// داواکارییەک لە باکئێندەوە دروست دەکات و QRـەکەی دەگەڕێنێتەوە.
  static Future<FastPayOrder> createOrder({
    required String orderId,
    required int billAmountIqd,
    String? note,
  }) async {
    final session = supabase.auth.currentSession;
    if (session == null) {
      throw const FastPayException('تکایە دووبارە بچۆ ژوورەوە');
    }
    late final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse(kFastPayOrderCreateUrl),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
              'Authorization': 'Bearer ${session.accessToken}',
            },
            body: jsonEncode({
              'purpose': 'wallet_deposit',
              'orderId': orderId,
              'billAmount': billAmountIqd,
              'currency': 'IQD',
              if (note != null && note.isNotEmpty) 'note': note,
            }),
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const FastPayException('کاتی پەیوەندی بە سێرڤەرەوە تەواو بوو');
    } catch (_) {
      throw const FastPayException('پەیوەندی بە ئینتەرنێتەوە نییە');
    }

    // بۆدییەکی بەتاڵ = وەرکفلۆکە بەبێ وەڵام کۆتایی هاتووە. ئەمە
    // `Unexpected end of JSON input`ـە کە جاران دەردەکەوت.
    if (res.body.trim().isEmpty) {
      throw const FastPayException('سێرڤەر وەڵامی نەدایەوە، دووبارە هەوڵبدەرەوە');
    }

    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FastPayException('وەڵامی سێرڤەر تێنەگەیشتن');
      }
      body = decoded;
    } on FastPayException {
      rethrow;
    } catch (_) {
      throw const FastPayException('وەڵامی سێرڤەر تێنەگەیشتن');
    }

    if (body['success'] != true) {
      final msg = body['message'];
      throw FastPayException(
          msg is String && msg.isNotEmpty ? msg : 'دروستکردنی QR سەرنەکەوت');
    }

    return FastPayOrder(
      orderId: (body['orderId'] as String?) ?? orderId,
      transactionId: body['transactionId'] as String?,
      qrUrl: body['qrUrl'] as String?,
      qrText: body['qrText'] as String?,
    );
  }

  /// دۆخی ئێستای داواکارییەک لە دەیتابەیسەوە.
  ///
  /// پۆلیسی RLSـی `Own transactions` ڕێگە دەدات بەکارهێنەر تەنها
  /// ڕیزەکانی خۆی ببینێت، بۆیە ئەمە بێ مەترسییە لە ئەپەوە.
  static Future<Map<String, dynamic>?> fetchRow(String orderId) async {
    final row = await supabase
        .from('pa_transactions')
        .select('gateway_status, status, expires_at, public_transaction_id')
        .eq('fastpay_order_id', orderId)
        .maybeSingle();
    return row;
  }
}

// ── ویجێت ─────────────────────────────────────────────────────────────────

class FastPayCheckoutSheet extends StatefulWidget {
  const FastPayCheckoutSheet({
    super.key,
    required this.amountIqd,
    required this.userId,
    this.note,
  });

  final int amountIqd;
  final String userId;
  final String? note;

  @override
  State<FastPayCheckoutSheet> createState() => _FastPayCheckoutSheetState();
}

class _FastPayCheckoutSheetState extends State<FastPayCheckoutSheet>
    with WidgetsBindingObserver {
  FastPayPhase _phase = FastPayPhase.confirm;
  late String _orderId;
  FastPayOrder? _order;

  /// ژمارەی مامەڵەی گشتی (`TX…`) کاتێک باکئێند دەیگەڕێنێتەوە، ئەگەرنا
  /// ناسنامەی داواکارییەکە.
  String? _publicTxId;

  String? _error;

  late DateTime _deadline;
  Duration _remaining = kFastPayFallbackWindow;
  Timer? _ticker;
  Timer? _poller;

  /// دەبێتە هۆی ئەوەی داواکاری دووەم نەنێردرێت لەکاتی چاوەڕوانیدا.
  bool _dispatching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _orderId = FastPayService.newOrderId();
    _deadline = DateTime.now().add(kFastPayFallbackWindow);
    _startTicker();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _poller?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _phase == FastPayPhase.waiting) {
      unawaited(_checkOnce());
    }
  }

  // ── کات ─────────────────────────────────────────────────────────────────

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final left = _deadline.difference(DateTime.now());
      setState(() => _remaining = left.isNegative ? Duration.zero : left);

      if (left.isNegative && _phase == FastPayPhase.waiting) {
        // کات تەواو بوو. یەک پشکنینی کۆتایی دەکەین پێش ئەوەی بە
        // «بەسەرچوو» دایبنێین — لەوانەیە پارەدانێکی دواکەوتوو گەیشتبێت.
        _finalCheckThenExpire();
      } else if (left.isNegative && _phase == FastPayPhase.confirm) {
        _ticker?.cancel();
        setState(() => _phase = FastPayPhase.expired);
      }
    });
  }

  String get _countdown {
    final m = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── ڕێڕەوی سەرەکی ───────────────────────────────────────────────────────

  Future<void> _continue() async {
    if (_dispatching) return;
    setState(() {
      _dispatching = true;
      _error = null;
      _phase = FastPayPhase.dispatching;
    });

    try {
      final order = await FastPayService.createOrder(
        orderId: _orderId,
        billAmountIqd: widget.amountIqd,
        note: widget.note,
      );
      if (!mounted) return;
      setState(() {
        _order = order;
        _phase = FastPayPhase.waiting;
      });

      _startPolling();
      await _openFastPay(order);
    } on FastPayException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _phase = FastPayPhase.confirm;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'هەڵەیەکی چاوەڕوان نەکراو ڕوویدا';
        _phase = FastPayPhase.confirm;
      });
    } finally {
      if (mounted) setState(() => _dispatching = false);
    }
  }

  /// ئەپی فاستپەی دەکاتەوە. ئەگەر دانەمەزرابێت، پەڕەی پارەدان لە
  /// وێبڤیوێکی ناوەکیدا دەکرێتەوە — نەک لە وێبگەڕی دەرەکی.
  Future<void> _openFastPay(FastPayOrder order) async {
    final link = order.deepLink;
    if (link != null) {
      try {
        final ok = await launchUrl(
          Uri.parse(link),
          mode: LaunchMode.externalApplication,
        );
        if (ok) return;
      } catch (_) {
        // ئەپەکە دانەمەزراوە — دەکەوینە سەر فۆڵباک.
      }
    }

    final url = order.qrUrl;
    if (url == null || url.isEmpty) {
      if (!mounted) return;
      setState(() => _error = 'لینکی پارەدان بەردەست نییە');
      return;
    }
    if (!mounted) return;
    await _FastPayWebViewSheet.open(context, url: url);
  }

  // ── چاودێری دۆخ ─────────────────────────────────────────────────────────

  void _startPolling() {
    _poller?.cancel();
    _poller = Timer.periodic(kFastPayPollInterval, (_) => _checkOnce());
    _checkOnce();
  }

  Future<void> _checkOnce() async {
    if (!mounted || _phase != FastPayPhase.waiting) return;

    Map<String, dynamic>? row;
    try {
      row = await FastPayService.fetchRow(_orderId);
    } catch (_) {
      return; // تێپەڕاندنی هەڵەی تۆڕ — لە خولی داهاتوودا دووبارە هەوڵ دەدەین
    }
    if (!mounted || row == null) return;

    // کاتی ڕاستەقینەی بەسەرچوون لە باکئێندەوە دەگیرێت.
    final exp = row['expires_at'];
    if (exp is String) {
      final parsed = DateTime.tryParse(exp);
      if (parsed != null) _deadline = parsed.toLocal();
    }
    final pub = row['public_transaction_id'];
    if (pub is String && pub.isNotEmpty) _publicTxId = pub;

    switch (_gatewayStatusFrom(row['gateway_status'] as String?)) {
      case FastPayGatewayStatus.paid:
        _settle(FastPayPhase.paid);
        break;
      case FastPayGatewayStatus.declined:
      case FastPayGatewayStatus.failed:
        _settle(FastPayPhase.cancelled);
        break;
      case FastPayGatewayStatus.expired:
        _settle(FastPayPhase.expired);
        break;
      case FastPayGatewayStatus.created:
      case FastPayGatewayStatus.unknown:
        setState(() {});
        break;
    }
  }

  Future<void> _finalCheckThenExpire() async {
    _poller?.cancel();
    try {
      final row = await FastPayService.fetchRow(_orderId);
      if (mounted &&
          row != null &&
          _gatewayStatusFrom(row['gateway_status'] as String?) ==
              FastPayGatewayStatus.paid) {
        _settle(FastPayPhase.paid);
        return;
      }
    } catch (_) {
      // بێدەنگ — بە بەسەرچوو دایدەنێین
    }
    if (mounted) _settle(FastPayPhase.expired);
  }

  void _settle(FastPayPhase phase) {
    _ticker?.cancel();
    _poller?.cancel();
    if (mounted) setState(() => _phase = phase);
  }

  /// «پاشگەزبوونەوە» — تەنها ڕووکارەکە دەگۆڕێت. باکئێندەکە خۆی لە
  /// خولی پۆڵینگدا داواکارییەکە بە `DECLINED` تۆمار دەکات.
  void _cancel() => _settle(FastPayPhase.cancelled);

  void _retry() {
    _poller?.cancel();
    setState(() {
      _orderId = FastPayService.newOrderId();
      _order = null;
      _publicTxId = null;
      _error = null;
      _phase = FastPayPhase.confirm;
      _deadline = DateTime.now().add(kFastPayFallbackWindow);
      _remaining = kFastPayFallbackWindow;
    });
    _startTicker();
  }

  void _copyRef() {
    Clipboard.setData(ClipboardData(text: _reference));
    showProxoToast(context, 'ژمارەی مامەڵە کۆپی کرا',
        type: ProxoToastType.success);
  }

  String get _reference => _publicTxId ?? _orderId;

  String get _amountLabel {
    final s = widget.amountIqd.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return '$s د.ع';
  }

  // ── بنیاتنان ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_kRadius),
            border: Border.all(color: _kLine),
            boxShadow: _kSoftElevation,
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(),
                  const SizedBox(height: 16),
                  _body(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Image.asset(kFastPayLogoAsset, height: 28),
        const Spacer(),
        InkResponse(
          onTap: () => Navigator.of(context)
              .pop(_phase == FastPayPhase.paid),
          radius: 22,
          child: Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
                color: _kSoft, shape: BoxShape.circle),
            child: const Icon(Icons.close, size: 18, color: _kSlate),
          ),
        ),
      ],
    );
  }

  Widget _body() {
    switch (_phase) {
      case FastPayPhase.confirm:
      case FastPayPhase.dispatching:
      case FastPayPhase.waiting:
        return _confirmView();
      case FastPayPhase.paid:
        return _StatusView(
          bg: _kOkBg,
          line: _kOkLine,
          fg: _kOkFg,
          icon: Icons.check_circle_rounded,
          title: 'سەرکەوتوو بوو',
          message: 'پارەدان بە سەرکەوتوویی ئەنجامدرا و باڵانسەکەت نوێکرایەوە.',
          reference: _reference,
          onCopy: _copyRef,
          actionLabel: 'گەڕانەوە بۆ باڵانس',
          onAction: () => Navigator.of(context).pop(true),
        );
      case FastPayPhase.cancelled:
        return _StatusView(
          bg: _kDangerBg,
          line: _kDangerLine,
          fg: _kDangerFg,
          icon: Icons.cancel_rounded,
          title: 'ڕەتکرایەوە',
          message: 'مامەڵەکە ڕەتکرایەوە.',
          reference: _reference,
          onCopy: _copyRef,
          actionLabel: 'دووبارە هەوڵبدەرەوە',
          onAction: _retry,
        );
      case FastPayPhase.expired:
        return _StatusView(
          bg: _kWarnBg,
          line: _kWarnLine,
          fg: _kWarnFg,
          icon: Icons.schedule_rounded,
          title: 'بەسەرچوو',
          message: 'کاتی دیاریکراوی ئەم مامەڵەیە بەسەرچوو، '
              'تکایە داواکاریی نوێ تۆمار بکە.',
          reference: _reference,
          onCopy: _copyRef,
          actionLabel: 'داواکاریی نوێ',
          onAction: _retry,
        );
    }
  }

  Widget _confirmView() {
    final waiting = _phase == FastPayPhase.waiting;
    final busy = _phase == FastPayPhase.dispatching;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const ProxoText('پارەدان لە ڕێگەی فاستپەی',
            style: TextStyle(
              fontFamily: kAppFont,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _kInk,
            )),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: _kSoft,
            borderRadius: BorderRadius.circular(_kRadius),
            border: Border.all(color: _kLine),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            children: [
              _SummaryRow(
                label: 'ژمارەی مامەڵە',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: ProxoText(
                        _reference,
                        textDirection: TextDirection.ltr,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _kInk,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _copyRef,
                      child: const ProxoText('کۆپیکردن',
                          style: TextStyle(
                            fontFamily: kAppFont,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _kAccent,
                          )),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: _kLine),
              _SummaryRow(
                label: 'بڕی پارە',
                child: ProxoText(_amountLabel,
                    style: const TextStyle(
                      fontFamily: kAppFont,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _kInk,
                    )),
              ),
              const Divider(height: 1, color: _kLine),
              _SummaryRow(
                label: 'شێوازی پارەدان',
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kLine),
                  ),
                  child: Image.asset(kFastPayLogoAsset, height: 18),
                ),
              ),
              const Divider(height: 1, color: _kLine),
              _SummaryRow(
                label: 'کاتی ماوە بۆ مامەڵەکە',
                child: ProxoText(
                  _countdown,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _remaining.inSeconds <= 60 ? _kWarnFg : _kSlate,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kDangerBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kDangerLine),
            ),
            child: ProxoText(_error!,
                style: const TextStyle(
                  fontFamily: kAppFont,
                  fontSize: 13,
                  color: _kDangerFg,
                )),
          ),
        ],
        if (waiting) ...[
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: _kAccent),
              ),
              SizedBox(width: 10),
              Flexible(
                child: ProxoText('چاوەڕوانی پشتڕاستکردنەوەی پارەدان…',
                    style: TextStyle(
                      fontFamily: kAppFont,
                      fontSize: 13,
                      color: _kSlate,
                    )),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        _primaryButton(
          label: waiting ? 'کردنەوەی فاستپەی دووبارە' : 'بەردەوامبە',
          busy: busy,
          onTap: busy
              ? null
              : waiting
                  ? () {
                      final o = _order;
                      if (o != null) _openFastPay(o);
                    }
                  : _continue,
        ),
        const SizedBox(height: 10),
        _outlinedButton(label: 'پاشگەزبوونەوە', onTap: busy ? null : _cancel),
      ],
    );
  }

  Widget _primaryButton({
    required String label,
    required bool busy,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: _kBtnHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: onTap == null ? _kAccent.withOpacity(.5) : _kAccent,
          borderRadius: BorderRadius.circular(_kRadius),
        ),
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Colors.white),
              )
            : ProxoText(label,
                style: const TextStyle(
                  fontFamily: kAppFont,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                )),
      ),
    );
  }

  Widget _outlinedButton({required String label, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: _kBtnHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_kRadius),
          border: Border.all(color: _kLine),
        ),
        child: ProxoText(label,
            style: const TextStyle(
              fontFamily: kAppFont,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _kSlate,
            )),
      ),
    );
  }
}

// ── پارچە یاریدەدەرەکان ───────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ProxoText(label,
              style: const TextStyle(
                fontFamily: kAppFont,
                fontSize: 13,
                color: _kSlate,
              )),
          const SizedBox(width: 12),
          Expanded(
            child: Align(alignment: Alignment.centerLeft, child: child),
          ),
        ],
      ),
    );
  }
}

class _StatusView extends StatelessWidget {
  const _StatusView({
    required this.bg,
    required this.line,
    required this.fg,
    required this.icon,
    required this.title,
    required this.message,
    required this.reference,
    required this.onCopy,
    required this.actionLabel,
    required this.onAction,
  });

  final Color bg;
  final Color line;
  final Color fg;
  final IconData icon;
  final String title;
  final String message;
  final String reference;
  final VoidCallback onCopy;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(_kRadius),
            border: Border.all(color: line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: fg),
              const SizedBox(height: 10),
              ProxoText(title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: kAppFont,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  )),
              const SizedBox(height: 6),
              ProxoText(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: kAppFont,
                    fontSize: 13,
                    height: 1.5,
                    color: fg,
                  )),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _kSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kLine),
          ),
          child: Row(
            children: [
              const ProxoText('ژمارەی مامەڵە',
                  style: TextStyle(
                    fontFamily: kAppFont,
                    fontSize: 12,
                    color: _kSlate,
                  )),
              const SizedBox(width: 10),
              Expanded(
                child: ProxoText(
                  reference,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kInk,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onCopy,
                child: const Icon(Icons.copy_rounded, size: 17, color: _kSlate),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: onAction,
          child: Container(
            height: _kBtnHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _kAccent,
              borderRadius: BorderRadius.circular(_kRadius),
            ),
            child: ProxoText(actionLabel,
                style: const TextStyle(
                  fontFamily: kAppFont,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                )),
          ),
        ),
      ],
    );
  }
}

// ── فۆڵباکی وێبڤیو ────────────────────────────────────────────────────────
//
// هەمان بنەمای `html_preview_sheet.dart`: پەڕەکە هەرگیز نادرێت بە
// ئەپێکی دەرەکی، بۆیە هەڵبژێرەری سیستەم دەرناکەوێت. بەڵام لێرەدا
// JavaScript پێویستە، چونکە پەڕەی پارەدانی فاستپەیە.

class _FastPayWebViewSheet extends StatefulWidget {
  const _FastPayWebViewSheet({required this.url});

  final String url;

  static Future<void> open(BuildContext context, {required String url}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FastPayWebViewSheet(url: url),
    );
  }

  @override
  State<_FastPayWebViewSheet> createState() => _FastPayWebViewSheetState();
}

class _FastPayWebViewSheetState extends State<_FastPayWebViewSheet> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: MediaQuery.of(context).size.height * .9,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(_kRadius)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                children: [
                  Image.asset(kFastPayLogoAsset, height: 22),
                  const Spacer(),
                  InkResponse(
                    onTap: () => Navigator.of(context).pop(),
                    radius: 22,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                          color: _kSoft, shape: BoxShape.circle),
                      child:
                          const Icon(Icons.close, size: 17, color: _kSlate),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _kLine),
            Expanded(child: WebViewWidget(controller: _controller)),
          ],
        ),
      ),
    );
  }
}
