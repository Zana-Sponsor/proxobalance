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
import '../config/backend_config.dart';
import '../services/fastpay_pending_checkout.dart';
import '../theme/app_theme.dart' show kAppFont;
import 'payments/payment_option.dart';
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

enum FastPayPhase { confirm, dispatching, waiting, paid, cancelled, expired, paused }

/// دۆخی گەیتوەی، وەک لە `pa_transactions.gateway_status` تۆمار کراوە.
enum FastPayGatewayStatus { created, paid, declined, expired, failed, unknown }

FastPayGatewayStatus _gatewayStatusFrom(Object? raw) {
  switch (raw is String ? raw.toUpperCase() : '') {
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

  static void _checkOwner(String owner) {
    if (supabase.auth.currentUser?.id != owner) {
      throw const FastPayException('هەژمارەکە گۆڕاوە؛ دووبارە بچۆ ژوورەوە');
    }
  }

  static bool walletCredited(Map<String, dynamic> row, {required int amountIqd}) =>
      row['status'] == 'approved' &&
      row['gateway_status'] == 'PAID' &&
      row['wallet_credited'] == true && row['gateway_amount'] == amountIqd;

  static bool isCheckoutUrl(String value) {
    final uri = Uri.tryParse(value);
    return value.length <= 4096 && uri != null && uri.scheme == 'https' &&
        uri.userInfo.isEmpty && !uri.hasPort &&
        const {'qr.fast-pay.iq', 'staging-qr.fast-pay.iq'}.contains(uri.host);
  }

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
    String? expectedUserId,
    BackendConfig? backendConfig,
  }) async {
    (backendConfig ?? BackendConfig.current).requireProductionTransport();
    final session = supabase.auth.currentSession;
    if (session == null) {
      throw const FastPayException('تکایە دووبارە بچۆ ژوورەوە');
    }
    final owner = expectedUserId ?? session.user.id;
    _checkOwner(owner);
    if (!RegExp(r'^[A-Za-z0-9_-]{8,32}$').hasMatch(orderId) ||
        RegExp(r'^AP[0-9a-f]{28}$', caseSensitive: false).hasMatch(orderId) ||
        billAmountIqd < kFastPayMinIqd) {
      throw const FastPayException('زانیاریی پارەدان دروست نییە');
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

    _checkOwner(owner);

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

    if (res.statusCode < 200 || res.statusCode >= 300 || body['success'] != true) {
      final msg = body['message'];
      throw FastPayException(
          msg is String && msg.isNotEmpty ? msg : 'دروستکردنی QR سەرنەکەوت');
    }

    if (body['orderId'] != orderId) {
      throw const FastPayException('ناسنامەی پارەدان پشتڕاست نەکرایەوە');
    }
    final qrUrl = body['qrUrl'], qrText = body['qrText'];
    if ((qrUrl != null && (qrUrl is! String || !isCheckoutUrl(qrUrl))) ||
        (qrText != null && (qrText is! String || qrText.isEmpty || qrText.length > 8192)) ||
        (qrUrl == null && qrText == null)) {
      throw const FastPayException('لینکی پارەدان پشتڕاست نەکرایەوە');
    }

    return FastPayOrder(
      orderId: orderId,
      transactionId: body['transactionId'] as String?,
      qrUrl: qrUrl as String?,
      qrText: qrText as String?,
    );
  }

  /// دۆخی ئێستای داواکارییەک لە دەیتابەیسەوە.
  ///
  /// پۆلیسی RLSـی `Own transactions` ڕێگە دەدات بەکارهێنەر تەنها
  /// ڕیزەکانی خۆی ببینێت، بۆیە ئەمە بێ مەترسییە لە ئەپەوە.
  static Future<Map<String, dynamic>?> fetchRow(String orderId,
      {required String expectedUserId, BackendConfig? backendConfig}) async {
    (backendConfig ?? BackendConfig.current).requireProductionTransport();
    _checkOwner(expectedUserId);
    final session = supabase.auth.currentSession;
    if (session == null) throw const FastPayException('تکایە دووبارە بچۆ ژوورەوە');
    // Ask the existing authenticated worker to reconcile first. Its response
    // never supplies payment proof: the committed ledger below is authoritative.
    try {
      await http.post(
        Uri.parse(kFastPayOrderCreateUrl.replaceFirst('/order-create', '/order-status')),
        headers: {'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}'},
        body: jsonEncode({'orderId': orderId}),
      ).timeout(const Duration(seconds: 15));
    } catch (_) { /* A lost status response may follow a committed credit. */ }
    _checkOwner(expectedUserId);
    final row = await supabase
        .from('pa_transactions')
        .select('gateway_status, status, wallet_credited, expires_at, public_transaction_id,qr_url,qr_text,gateway_amount')
        .eq('user_id', expectedUserId)
        .eq('fastpay_order_id', orderId)
        .maybeSingle()
        .timeout(const Duration(seconds: 15));
    _checkOwner(expectedUserId);
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
  StreamSubscription<dynamic>? _authSubscription;
  late final String _owner;
  int _generation = 0;
  Future<void>? _polling;
  static const _pendingStore = FastPayPendingCheckoutStore();
  late int _amountIqd;
  String? _note;
  bool _restoring = true;
  bool _hasPending = false;
  bool _gatewayTerminal = false;

  bool get _ownerValid =>
      widget.userId == _owner && supabase.auth.currentUser?.id == _owner;
  bool _current(String order, int generation) => mounted && _ownerValid &&
      _orderId == order && _generation == generation;

  /// دەبێتە هۆی ئەوەی داواکاری دووەم نەنێردرێت لەکاتی چاوەڕوانیدا.
  bool _dispatching = false;

  @override
  void initState() {
    super.initState();
    _owner = widget.userId;
    _amountIqd = widget.amountIqd;
    _note = widget.note;
    WidgetsBinding.instance.addObserver(this);
    _orderId = FastPayService.newOrderId();
    _deadline = DateTime.now().add(kFastPayFallbackWindow);
    _startTicker();
    _authSubscription = supabase.auth.onAuthStateChange.listen((_) {
      if (!mounted || _ownerValid) return;
      _generation++;
      _ticker?.cancel();
      _poller?.cancel();
      setState(() {});
    });
    unawaited(_restorePending());
  }

  Future<void> _restorePending() async {
    try {
      final pending = await _pendingStore.read(_owner);
      if (!mounted || !_ownerValid) return;
      if (pending != null) {
        _orderId = pending.orderId;
        _amountIqd = pending.amountIqd;
        _note = pending.note;
        _hasPending = true;
        _error = 'داواکاریی پێشووت گەڕێندرایەوە؛ هەمان پارەدان پشتڕاست دەکرێتەوە.';
      }
      setState(() => _restoring = false);
    } catch (_) {
      if (!mounted || !_ownerValid) return;
      setState(() {
        _restoring = false;
        _error = 'نەتوانرا پارەدانی پێشوو بخوێندرێتەوە؛ پەڕەکە دابخە و دووبارە بیکەرەوە.';
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _poller?.cancel();
    _authSubscription?.cancel();
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
      if (!mounted || !_ownerValid) return;
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
    if (_dispatching || _restoring || !_ownerValid) return;
    final generation = _generation;
    var orderId = _orderId;
    setState(() {
      _dispatching = true;
      _error = null;
      _phase = FastPayPhase.dispatching;
    });

    try {
      BackendConfig.current.requireProductionTransport();
      final pending = await _pendingStore.claim(_owner,
          FastPayPendingCheckout(orderId: orderId, amountIqd: _amountIqd, note: _note));
      if (!_current(orderId, generation)) return;
      final recovering = _hasPending || pending.orderId != orderId;
      setState(() {
        orderId = pending.orderId;
        _orderId = orderId;
        _amountIqd = pending.amountIqd;
        _note = pending.note;
        _hasPending = true;
      });
      FastPayOrder? recovered;
      if (recovering) {
        final row = await FastPayService.fetchRow(orderId, expectedUserId: _owner);
        if (!_current(orderId, generation)) return;
        if (row != null) {
          if (FastPayService.walletCredited(row, amountIqd: _amountIqd)) {
            _settle(FastPayPhase.paid);
            return;
          }
          final status = _gatewayStatusFrom(row['gateway_status']);
          if (status == FastPayGatewayStatus.expired || status == FastPayGatewayStatus.declined) {
            // Legacy background expiry is based on elapsed time, not proof
            // that the provider can no longer settle the original payment.
            _gatewayTerminal = status == FastPayGatewayStatus.declined;
            _settle(status == FastPayGatewayStatus.expired ? FastPayPhase.expired : FastPayPhase.cancelled);
            return;
          }
          final url = row['qr_url'], token = row['qr_text'];
          if (row['gateway_amount'] != _amountIqd) {
            throw const FastPayException('بڕی پارەدان پشتڕاست نەکرایەوە');
          }
          final validToken = token is String && token.isNotEmpty && token.length <= 8192;
          final validUrl = url is String && FastPayService.isCheckoutUrl(url);
          if ((validToken || validUrl) && (token == null || validToken) && (url == null || validUrl)) {
            recovered = FastPayOrder(orderId: orderId, qrText: token as String?, qrUrl: url as String?);
          } else {
            // The existing attempt is uncertain. Keep its identity and check it;
            // never create another provider order just because its QR is absent.
            setState(() => _phase = FastPayPhase.waiting);
            _startPolling();
            return;
          }
        }
      }
      if (recovered == null) {
        final mayDispatch = await _pendingStore.markDispatched(_owner, orderId);
        if (!_current(orderId, generation)) return;
        if (!mayDispatch) {
          // Legacy QR creation precedes its database insert. A missing row after
          // dispatch is therefore not proof that no gateway order exists.
          setState(() {
            _phase = FastPayPhase.waiting;
            _error = 'ئەنجامی پارەدانی پێشوو هێشتا دیار نییە؛ هەمان مامەڵە پشکنین دەکرێت.';
          });
          _startPolling();
          return;
        }
      }
      final order = recovered ?? await FastPayService.createOrder(
        orderId: _orderId,
        billAmountIqd: _amountIqd,
        note: _note,
        expectedUserId: _owner,
      );
      if (!_current(orderId, generation)) return;
      setState(() {
        _order = order;
        _phase = FastPayPhase.waiting;
        _deadline = DateTime.now().add(kFastPayFallbackWindow);
        _remaining = kFastPayFallbackWindow;
      });
      _startTicker();
      _startPolling();
      await _openFastPay(order);
    } on FastPayException catch (e) {
      if (!_current(orderId, generation)) return;
      setState(() {
        _error = e.message;
        _phase = FastPayPhase.confirm;
      });
    } catch (_) {
      if (!_current(orderId, generation)) return;
      setState(() {
        _error = 'هەڵەیەکی چاوەڕوان نەکراو ڕوویدا';
        _phase = FastPayPhase.confirm;
      });
    } finally {
      if (_current(orderId, generation)) setState(() => _dispatching = false);
    }
  }

  /// ئەپی فاستپەی دەکاتەوە. ئەگەر دانەمەزرابێت، پەڕەی پارەدان لە
  /// وێبڤیوێکی ناوەکیدا دەکرێتەوە — نەک لە وێبگەڕی دەرەکی.
  Future<void> _openFastPay(FastPayOrder order) async {
    final generation = _generation;
    if (!_current(order.orderId, generation) || _phase != FastPayPhase.waiting) return;
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
      if (!_current(order.orderId, generation)) return;
      setState(() => _error = 'لینکی پارەدان بەردەست نییە');
      return;
    }
    if (!_current(order.orderId, generation) || _phase != FastPayPhase.waiting) return;
    await _FastPayWebViewSheet.open(context, url: url, owner: _owner);
  }

  // ── چاودێری دۆخ ─────────────────────────────────────────────────────────

  void _startPolling() {
    _poller?.cancel();
    _poller = Timer.periodic(kFastPayPollInterval, (_) => _checkOnce());
    _checkOnce();
  }

  Future<void> _checkOnce() {
    if (!mounted || !_ownerValid || _phase != FastPayPhase.waiting) return Future.value();
    if (_polling != null) return _polling!;
    final request = _readAndApply(_orderId, _generation);
    _polling = request;
    return request.whenComplete(() {
      if (identical(_polling, request)) _polling = null;
    });
  }

  Future<void> _readAndApply(String orderId, int generation) async {

    Map<String, dynamic>? row;
    try {
      row = await FastPayService.fetchRow(orderId, expectedUserId: _owner);
    } catch (_) {
      return; // تێپەڕاندنی هەڵەی تۆڕ — لە خولی داهاتوودا دووبارە هەوڵ دەدەین
    }
    if (!_current(orderId, generation) || _phase != FastPayPhase.waiting || row == null) return;

    // کاتی ڕاستەقینەی بەسەرچوون لە باکئێندەوە دەگیرێت.
    final exp = row['expires_at'];
    if (exp is String) {
      final parsed = DateTime.tryParse(exp);
      if (parsed != null) _deadline = parsed.toLocal();
    }
    final pub = row['public_transaction_id'];
    if (pub is String && pub.isNotEmpty) _publicTxId = pub;
    if (_order == null && row['gateway_amount'] == _amountIqd &&
        _gatewayStatusFrom(row['gateway_status']) == FastPayGatewayStatus.created) {
      final url = row['qr_url'], token = row['qr_text'];
      final validToken = token is String && token.isNotEmpty && token.length <= 8192;
      final validUrl = url is String && FastPayService.isCheckoutUrl(url);
      if ((validToken || validUrl) && (token == null || validToken) && (url == null || validUrl)) {
        _order = FastPayOrder(orderId: orderId, qrText: token as String?, qrUrl: url as String?);
      }
    }

    switch (_gatewayStatusFrom(row['gateway_status'])) {
      case FastPayGatewayStatus.paid:
        if (FastPayService.walletCredited(row, amountIqd: _amountIqd)) _settle(FastPayPhase.paid);
        break;
      case FastPayGatewayStatus.declined:
        _gatewayTerminal = true;
        _settle(FastPayPhase.cancelled);
        break;
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
    final orderId = _orderId, generation = _generation;
    _ticker?.cancel();
    _poller?.cancel();
    await _checkOnce();
    if (!_current(orderId, generation) || _phase != FastPayPhase.waiting) return;
    // An authoritative expiry can arrive after the local fallback deadline.
    if (_deadline.isAfter(DateTime.now())) {
      _startTicker();
      _startPolling();
      return;
    }
    _settle(FastPayPhase.expired);
  }

  void _settle(FastPayPhase phase) {
    _generation++;
    _ticker?.cancel();
    _poller?.cancel();
    if (phase == FastPayPhase.paid) {
      unawaited(_pendingStore.clear(_owner, _orderId).catchError((_) {
        // Retaining a completed identity is safe; reopening reads the ledger.
      }));
    }
    if (mounted) setState(() {
      _dispatching = false;
      _phase = phase;
    });
  }

  /// Closing a checkout is not a provider decline. Keep its identity for recovery.
  void _cancel() => _settle(FastPayPhase.paused);

  Future<void> _retry() async {
    if (!_ownerValid) return;
    if (_gatewayTerminal) {
      final previous = _orderId, generation = _generation;
      try { await _pendingStore.clear(_owner, previous); }
      catch (_) { return; }
      if (!_current(previous, generation)) return;
      _hasPending = false;
    }
    _generation++;
    _polling = null;
    _poller?.cancel();
    setState(() {
      if (!_hasPending) _orderId = FastPayService.newOrderId();
      _order = null;
      _publicTxId = null;
      _error = null;
      _phase = FastPayPhase.confirm;
      _dispatching = false;
      _gatewayTerminal = false;
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
    final s = _amountIqd.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return '$s د.ع';
  }

  // ── بنیاتنان ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_ownerValid) return const SizedBox.shrink();
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
        const ProviderLogo(provider: 'fastpay', width: 84, height: 28),
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
          message: _gatewayTerminal ? 'کاتی دیاریکراوی ئەم مامەڵەیە بەسەرچوو، تکایە داواکاریی نوێ تۆمار بکە.' :
              'کاتی چاوەڕوانی تەواو بوو؛ هەمان پارەدان دووبارە پشتڕاست بکەرەوە.',
          reference: _reference,
          onCopy: _copyRef,
          actionLabel: _gatewayTerminal ? 'داواکاریی نوێ' : 'پشتڕاستکردنەوەی پارەدان',
          onAction: _retry,
        );
      case FastPayPhase.paused:
        return _StatusView(
          bg: _kWarnBg, line: _kWarnLine, fg: _kWarnFg,
          icon: Icons.pause_circle_outline,
          title: 'چاوەڕوانی پارەدان وەستێنرا',
          message: 'ئەمە پارەدان هەڵناوەشێنێتەوە؛ هەمان مامەڵە دەتوانرێت پشتڕاست بکرێتەوە.',
          reference: _reference, onCopy: _copyRef,
          actionLabel: 'بەردەوامبوون لە پارەدان', onAction: _retry,
        );
    }
  }

  Widget _confirmView() {
    final waiting = _phase == FastPayPhase.waiting;
    final busy = _phase == FastPayPhase.dispatching || _restoring;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const ProxoText('پارەدان لە ڕێگەی فاستپەی', translate: true,
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
                child: _ReferenceValue(reference: _reference, onCopy: _copyRef),
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
                  child: const ProviderLogo(
                      provider: 'fastpay', width: 56, height: 18),
                ),
              ),
              const Divider(height: 1, color: _kLine),
              _SummaryRow(
                label: 'کاتی ماوە بۆ مامەڵەکە',
                child: ProxoText(
                  _countdown,
                  key: const ValueKey('fastpay-countdown'),
                  textDirection: TextDirection.ltr,
                  maxLines: 1,
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
                child: ProxoText('چاوەڕوانی پشتڕاستکردنەوەی پارەدان…', translate: true,
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
            : ProxoText(label, translate: true,
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
        child: ProxoText(label, translate: true,
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
      child: LayoutBuilder(builder: (context, constraints) {
        final labelWidget = ProxoText(label, translate: true,
            style: const TextStyle(
              fontFamily: kAppFont,
              fontSize: 13,
              color: _kSlate,
            ));
        final value = Align(alignment: Alignment.centerLeft, child: child);
        // A large unbounded label must not take all the value's width. Stack
        // on compact screens and at accessibility sizes without shrinking text.
        final stack = constraints.maxWidth < 280 ||
            MediaQuery.textScalerOf(context).scale(13) > 13 * 1.3;
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [labelWidget, const SizedBox(height: 8), value],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            labelWidget,
            const SizedBox(width: 12),
            Expanded(child: value),
          ],
        );
      }),
    );
  }
}

class _ReferenceValue extends StatelessWidget {
  const _ReferenceValue({required this.reference, required this.onCopy});

  final String reference;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SingleChildScrollView(
              key: const ValueKey('fastpay-reference-scroll'),
              scrollDirection: Axis.horizontal,
              child: ProxoText(reference,
                  key: const ValueKey('fastpay-reference'),
                  textDirection: TextDirection.ltr,
                  maxLines: 1,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kInk,
                  )),
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          key: const ValueKey('fastpay-copy-reference'),
          onTap: onCopy,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: const Center(
              child: ProxoText('کۆپیکردن', translate: true,
                  style: TextStyle(
                    fontFamily: kAppFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _kAccent,
                  )),
            ),
          ),
        ),
      ],
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
              ProxoText(title, translate: true,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: kAppFont,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  )),
              const SizedBox(height: 6),
              ProxoText(message, translate: true,
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
          child: _SummaryRow(
            label: 'ژمارەی مامەڵە',
            child: _ReferenceValue(reference: reference, onCopy: onCopy),
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
  const _FastPayWebViewSheet({required this.url, required this.owner});

  final String url;
  final String owner;

  static Future<void> open(BuildContext context, {required String url, required String owner}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FastPayWebViewSheet(url: url, owner: owner),
    );
  }

  @override
  State<_FastPayWebViewSheet> createState() => _FastPayWebViewSheetState();
}

class _FastPayWebViewSheetState extends State<_FastPayWebViewSheet> {
  late final WebViewController _controller;
  StreamSubscription<dynamic>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(onNavigationRequest: (request) =>
          supabase.auth.currentUser?.id == widget.owner && FastPayService.isCheckoutUrl(request.url)
              ? NavigationDecision.navigate : NavigationDecision.prevent))
      ..loadRequest(Uri.parse(widget.url));
    _authSubscription = supabase.auth.onAuthStateChange.listen((_) {
      if (mounted && supabase.auth.currentUser?.id != widget.owner) setState(() {});
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (supabase.auth.currentUser?.id != widget.owner) return const SizedBox.shrink();
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
                  const ProviderLogo(
                      provider: 'fastpay', width: 64, height: 22),
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
