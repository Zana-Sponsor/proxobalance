// auth/auth_shell.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' show max;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_locale.dart';
import '../../services/trusted_device_service.dart';
import '../../widgets/auth/auth_design.dart';
import '../../widgets/auth/auth_otp_field.dart';
import '../../widgets/auth/auth_widgets.dart';
import '../../widgets/auth/auth_header.dart';
import '../../main.dart' show n8nWebhookUrl, n8nOtpLoginWebhook, wevlixOtpSendUrl, supabase, MainShell;
import 'auth_models.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'otp_screen.dart';
import 'auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────────────────────────────────────

enum _Tab        { login, register }

/// کەناڵی چوونەژوورەوە. ⚠ تەنها لە `_buildSignInView`دا بەکاردێت —
/// شاشەی تۆمارکردن هەرگیز ئەم سویچەی نییە.
enum _Step       { form, otp, forgotEmail, forgotOtp, forgotNewPass }

// ─────────────────────────────────────────────────────────────────────────────
// Rate Limiter
// ─────────────────────────────────────────────────────────────────────────────

/// ⚠ ئەم لیمیتەرە تەنها لە یادەوەریدایە و بە دەستپێکردنەوەی ئەپەکە
/// دەسڕێتەوە. سەرچاوەی ڕاستی قفڵەکە داتابەیسە — `pa_login_attempt`
/// خۆی `failed_login_attempts` و `locked_until` هەڵدەگرێت. ئەمە تەنها
/// بۆ ئەوەیە کە داواکاری بێهوودە نەنێردرێت.
///
/// ⚠ **دوو ماوەی جیاواز** هەن، و ئەوە بە ئەنقەستە:
///
///   • وشەی نهێنی — ٢٤ کاتژمێر. دەبێت دەقاودەق هی سێرڤەرەکە بێت،
///     چونکە `pa_login_attempt` قفڵێکی ڕاستەقینە لە داتابەیس دادەنێت.
///     ئەگەر لێرە کورتتر بێت، بەکارهێنەر پێی دەوترێت چاوەڕێی ١٠ خولەک
///     بکات و پاشان دەبینێت هێشتا قفڵکراوە بۆ ٢٣ کاتژمێری تر.
///
///   • کۆدی OTP — ١٥ خولەک. هەڵەی OTP **هیچ** قفڵێک لە داتابەیس
///     دانانێت (`pa_login_attempt` تەنها بۆ وشەی نهێنییە). بۆیە پێشتر
///     کە هەردووکیان یەک ماوەیان بەکاردەهێنا، ٥ کۆدی هەڵە پەیامی
///     «٢٤ کاتژمێر»ی دەردەخست بۆ قفڵێک کە **بوونی نەبوو** — لە
///     ڕاستیدا بەکارهێنەر دەیتوانی دەستبەجێ دووبارە هەوڵ بدات، یان
///     تەنها ئەپەکە دابخات و بیکاتەوە.
class _RateLimiter {
  static final Map<String, _RateEntry> _store = {};
  static const int _maxAttempts = 5;

  /// = `now() + interval '24 hours'` لە `pa_login_attempt`دا.
  static const Duration _lockForPassword = Duration(hours: 24);

  /// تەنها لە یادەوەری — هیچ هاوتایەکی لە داتابەیس نییە.
  static const Duration _lockForOtp = Duration(minutes: 15);

  static _RateEntry _entry(String key) =>
      _store.putIfAbsent(key, () => _RateEntry());

  static String? check(String email) {
    final e = _entry(email);
    if (e.lockedUntil != null) {
      final remaining = e.lockedUntil!.difference(DateTime.now());
      if (remaining.inSeconds > 0) {
        return ProxoLocale.isArabic
            ? 'الحساب مقفل مؤقتاً. انتظر ${_wait(remaining)}.'
            : 'هەژمارەکەت قفڵ کراوە. ${_wait(remaining)} چاوەڕێ بکە.';
      } else {
        e.reset();
      }
    }
    return null;
  }

  /// ماوەی ماوە بە شێوەیەکی خوێندنەوەیی — کاتژمێر کاتێک ماوەکە درێژە،
  /// خولەک کاتێک کۆتایی دێت.
  static String _wait(Duration d) {
    final h = d.inHours;
    if (h >= 1) return ProxoLocale.isArabic ? '$h ساعة' : '$h کاتژمێر';
    final m = (d.inSeconds / 60).ceil();
    return ProxoLocale.isArabic ? '$m دقيقة' : '$m خولەک';
  }

  /// [lockFor] دیاری دەکات کە ئەم شکستە سەر بە کام کەناڵەوەیە.
  /// بنەڕەت = وشەی نهێنی، چونکە ئەوە ئەو کەناڵەیە کە قفڵی
  /// داتابەیسی هەیە و نابێت بە هەڵە کورت بکرێتەوە.
  static bool recordFail(String email, {Duration? lockFor}) {
    final e = _entry(email);
    if (e.lockedUntil != null && e.lockedUntil!.isAfter(DateTime.now())) return true;
    e.attempts++;
    if (e.attempts >= _maxAttempts) {
      e.lockedUntil = DateTime.now().add(lockFor ?? _lockForPassword);
      return true;
    }
    return false;
  }

  static int remaining(String email) => max(0, _maxAttempts - _entry(email).attempts);
  static void reset(String email)    => _entry(email).reset();
}

class _RateEntry {
  int       attempts    = 0;
  DateTime? lockedUntil;
  void reset() { attempts = 0; lockedUntil = null; }
}

// ─────────────────────────────────────────────────────────────────────────────
// AuthShell
// ─────────────────────────────────────────────────────────────────────────────

class AuthShell extends StatefulWidget {
  const AuthShell({super.key});

  @override
  State<AuthShell> createState() => _AuthShellState();
}

class _AuthShellState extends State<AuthShell> {

  _Tab  _tab     = _Tab.login;
  _Step _step    = _Step.form;
  bool  _loading  = false;
  final ValueNotifier<bool> _loginPasswordVisible = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _signupPasswordVisible = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _signupConfirmationVisible = ValueNotifier<bool>(false);

  // ── کارتی ئیرۆری سپی سەر شاشە (٤ چرکە) ──
  String? _bannerError;
  Timer?  _bannerTimer;

  final _loginEmailCtrl = TextEditingController();
  final _loginPassCtrl  = TextEditingController();
  final _loginEmailFocus = FocusNode();
  final _loginPassFocus  = FocusNode();
  String? _loginEmailErr;
  String? _loginPassErr;

  final _regNameCtrl  = TextEditingController();
  final _regPhoneCtrl = TextEditingController();
  final _regNameFocus  = FocusNode();
  final _regPhoneFocus = FocusNode();
  final _regPassCtrl  = TextEditingController();
  final _regPass2Ctrl = TextEditingController();
  String? _regNameErr;
  String? _regPhoneErr;
  String? _regPassErr;
  String? _regPass2Err;

  static const int _kOtpLength = 6;

  // ── کەناڵی چوونەژوورەوە (تەنها شاشەی چوونەژوورەوە) ──────────────────────
  AuthChannel _loginChannel = AuthChannel.email;
  AuthChannel _activeOtpChannel = AuthChannel.email;
  AuthOtpPurpose _activeOtpPurpose = AuthOtpPurpose.login;
  final _loginPhoneCtrl  = TextEditingController();
  /// ژمارەی ئەو داواکارییەی OTPـەکەی بۆ نێردراوە — E.164.
  String _pendingPhone = '';
  final _loginPhoneFocus = FocusNode();
  String? _loginPhoneErr;
  bool    _phoneOtpSending = false;

  final _otpCtrl  = TextEditingController();
  final _otpFocus = FocusNode();
  bool _loginLockedOut = false;

  String? _trustedEmail;
  bool _trustedSelected = false;

  final OtpShakeController _otpShaker   = OtpShakeController();
  final OtpShakeController _fpOtpShaker = OtpShakeController();

  String _pendingEmail   = '';
  String _pendingUserId  = '';
  String _pendingPass    = '';
  String _pendingName    = '';
  Timer? _resendTimer;
  final ValueNotifier<int> _resendSeconds = ValueNotifier<int>(60);
  int    _otpAttempts    = 0;
  bool   _otpHasError    = false;

  final _fpEmailCtrl       = TextEditingController();
  final _fpEmailFocus      = FocusNode();
  final _fpNewPassCtrl     = TextEditingController();
  final _fpConfirmPassCtrl = TextEditingController();
  final ValueNotifier<bool> _resetPasswordVisible = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _resetConfirmationVisible = ValueNotifier<bool>(false);
  String? _fpEmailErr;
  String? _fpNewPassErr;
  String? _fpConfirmPassErr;
  String _fpUserId        = '';
  String _fpVerifiedOtpId = '';
  int    _fpOtpAttempts   = 0;

  final _fpOtpCtrl  = TextEditingController();
  final _fpOtpFocus = FocusNode();
  bool   _fpOtpHasError = false;

  StreamSubscription<AuthState>? _authSub;
  late final AuthService _authService;

  // ── فۆنت و ستایلە یەکگرتووەکان ──────────────────────────────────────────────
  // ⚠ ئەم دووانە پێشتر کۆپییەکی دەستیی `AuthTokens.title` و
  // `AuthTokens.subtitle` بوون — هەمان ڕۆڵ، ژمارەی جیاواز (21.0 بەرامبەر
  // 21، و 12.8/1.35 بەرامبەر 13/1.40). واتە سەرناوی «چوونەژوورەوە» و
  // سەرناوی OTP دوو سەرچاوەی جیاوازیان هەبوو و دەیانتوانی لێک دووربکەونەوە
  // بەبێ ئەوەی کەس تێبینی بکات. ئێستا ئەلیاسن.
  static const TextStyle _kTitle = AuthTokens.title;
  static const TextStyle _kSub   = AuthTokens.subtitle;

  @override
  void initState() {
    super.initState();
    _authService = AuthService(
      supabase: supabase,
      emailOtpUrl: n8nOtpLoginWebhook,
      whatsappOtpUrl: wevlixOtpSendUrl,
    );
    _authSub = supabase.auth.onAuthStateChange.listen((_) {});
    for (final FocusNode f in <FocusNode>[
      _loginEmailFocus,
      _fpEmailFocus,
    ]) {
      f.addListener(_normalizeBlurredEmails);
    }
    _loadTrustedDevice();
  }

  Future<void> _loadTrustedDevice() async {
    final String? email = await TrustedDeviceService.recognisedEmail(supabase);
    if (!mounted || email == null) return;
    setState(() => _trustedEmail = email);
  }

  void _useTrustedAccount() {
    final String? email = _trustedEmail;
    if (email == null) return;
    setState(() {
      _trustedSelected = true;
      _loginEmailCtrl.text = email;
      _loginEmailErr = null;
      _loginPassErr = null;
    });
    _refreshLockState();
    _loginPassFocus.requestFocus();
  }

  Future<void> _forgetTrustedAccount() async {
    await TrustedDeviceService.forget(supabase);
    if (!mounted) return;
    setState(() {
      _trustedEmail = null;
      _trustedSelected = false;
      _loginEmailCtrl.clear();
    });
  }

  void _normalizeBlurredEmails() {
    _normalizeIfBlurred(_loginEmailFocus, _loginEmailCtrl);
    if (!_loginEmailFocus.hasFocus) _refreshLockState();
    _normalizeIfBlurred(_fpEmailFocus, _fpEmailCtrl);
  }

  Future<void> _refreshLockState() async {
    final String email = AuthValidators.normalizeEmail(_loginEmailCtrl.text);
    if (AuthValidators.email(email) != null) {
      if (_loginLockedOut && mounted) setState(() => _loginLockedOut = false);
      return;
    }
    final bool locked = await _checkLockedOut(email);
    if (mounted && locked != _loginLockedOut) {
      setState(() => _loginLockedOut = locked);
    }
  }

  void _normalizeIfBlurred(FocusNode node, TextEditingController ctrl) {
    if (node.hasFocus) return;
    final String norm = AuthValidators.normalizeEmail(ctrl.text);
    if (norm == ctrl.text) return;
    ctrl.value = TextEditingValue(
      text: norm,
      selection: TextSelection.collapsed(offset: norm.length),
    );
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _authSub?.cancel();
    _resendTimer?.cancel();
    _authService.close();
    AuthFlowGuard.inOtpFlow = false;
    _loginEmailCtrl.dispose(); _loginPassCtrl.dispose();
    for (final FocusNode f in <FocusNode>[
      _loginEmailFocus,
      _fpEmailFocus,
    ]) {
      f.removeListener(_normalizeBlurredEmails);
    }
    _loginEmailFocus.dispose(); _loginPassFocus.dispose();
    _regNameCtrl.dispose();    _regPhoneCtrl.dispose();
    _regNameFocus.dispose();   _regPhoneFocus.dispose();
    _regPassCtrl.dispose();    _regPass2Ctrl.dispose();
    _loginPhoneCtrl.dispose(); _loginPhoneFocus.dispose();
    _otpCtrl.dispose();   _otpFocus.dispose();
    _fpEmailCtrl.dispose();    _fpEmailFocus.dispose();
    _fpNewPassCtrl.dispose();
    _fpConfirmPassCtrl.dispose();
    _fpOtpCtrl.dispose(); _fpOtpFocus.dispose();
    _loginPasswordVisible.dispose();
    _signupPasswordVisible.dispose();
    _signupConfirmationVisible.dispose();
    _resetPasswordVisible.dispose();
    _resetConfirmationVisible.dispose();
    _resendSeconds.dispose();
    _otpShaker.dispose(); _fpOtpShaker.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────

  bool _isGmail(String email) =>
      RegExp(r'^[\w.+-]+@gmail\.com$', caseSensitive: false).hasMatch(email);

  bool _confirmMismatch(String original, String confirm) {
    if (confirm.isEmpty) return false;
    if (confirm.length <= original.length) return !original.startsWith(confirm);
    return confirm != original;
  }

  Future<bool> _checkLockedOut(String email) async {
    if (email.isEmpty) return false;
    try {
      final res = await supabase
          .rpc('pa_login_lock_status', params: {'p_email': email});
      if (res is List && res.isNotEmpty && res.first is Map) {
        return (res.first as Map)['locked'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _contactSupportOnWhatsApp() async {
    final Uri uri = Uri.https(
      'wa.me',
      '/' + kSupportWhatsAppNumber,
      <String, String>{'text': kSupportWhatsAppMessage},
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  // ── پیشاندانی کارتی سپی بۆ ئیرۆر بە مانەوەی ٤ چرکە ─────────────────────────
  void _showErrorCard(String msg) {
    if (!mounted) return;
    _bannerTimer?.cancel();
    setState(() => _bannerError = msg);
    _bannerTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _bannerError = null);
    });
  }

  void _showNetworkError() {
    _showErrorCard(AuthStrings.errNetwork);
  }

  String _t(String ku, String ar) => ProxoLocale.isArabic ? ar : ku;

  // ── Network ───────────────────────────────────────────────

  /// ژمارە بە فۆرمی E.164 — `+964` + ژمارەکە بەبێ سفری پێشەوە.
  String get _phoneE164 => IraqPhone.normalize(_loginPhoneCtrl.text);

  String get _regPhoneE164 => IraqPhone.normalize(_regPhoneCtrl.text);

  /// ژمارەی عێراقیی مۆبایل: ٧ + ٩ ژمارە = ١٠ ژمارە دوای کۆدی وڵات.
  bool get _phoneValid {
    return IraqPhone.isValid(_loginPhoneCtrl.text);
  }

  bool get _regPhoneValid => IraqPhone.isValid(_regPhoneCtrl.text);

  void _keepPhoneControllerLocal(TextEditingController controller) {
    String local = IraqPhone.editableDigits(controller.text);
    if (local.length > 10) local = local.substring(0, 10);
    if (controller.text == local) return;
    controller.value = TextEditingValue(
      text: local,
      selection: TextSelection.collapsed(offset: local.length),
    );
  }

  /// ناردنی کۆدی واتساپ بە ڕێی وۆرکفلۆی Wevlixـی n8n.
  ///
  /// کۆنتراتەکە لە خودی وۆرکفلۆکەوە هاتووە:
  ///   POST `wevlix/otp/send`  { phone, purpose, clientMessageId, locale }
  ///   → { success, messageId, phone, status, expiresAt, reused }
  ///
  /// `reused` واتە کۆدێکی چالاکی پێشوو دووبارە نێردراوەتەوە
  /// (`get_or_generate_otp_whatsapp` کۆدێکی نوێ دروست ناکات تا ئەوەی
  /// پێشوو بەسەر نەچووە) — بۆیە بەکارهێنەر ڕەنگە هەمان کۆدی پێشووی
  /// بۆ بێت، و ئەوە هەڵە نییە.
  Future<void> _sendPhoneOtp() async {
    if (_phoneOtpSending) return;
    FocusScope.of(context).unfocus();
    if (!_phoneValid) {
      setState(() => _loginPhoneErr = AuthStrings.phoneInvalid);
      return;
    }
    setState(() {
      _loginPhoneErr = null;
      _phoneOtpSending = true;
    });

    // ── پێش‌پشکنین: ئایا ئەم ژمارەیە هەژمارێکی هەیە؟ ──────────────────────
    // ⚠ ئەمە **کۆنترۆڵێکی ئاسایش نییە** — لەسەر کلاینت کار دەکات و
    // دەکرێت تێپەڕێنرێت. مەبەستەکەی تەنها تێچووە: بەبێی، ناردنی کۆد بۆ
    // ژمارەیەکی نەتۆمارکراو پارەی Wevlix دەخوات بۆ پەیامێک کە هەرگیز
    // بەکارناهێنرێت.
    //
    // کۆنترۆڵی ڕاستەقینە `404 user_not_found`ی فەنکشنی ئێجە.
    //
    // ⚠ `pa_phone_exists` بەکاردێت نەک `select` لەسەر `profiles`:
    // RLS چالاکە و هەر حەوت پۆلیسییەکەی تەنها بۆ `authenticated`ن،
    // بۆیە بەکارهێنەرێکی `anon` بۆ **هەموو** ژمارەیەک سفر ڕیز
    // وەردەگرێت — واتە هەموو چوونەژوورەوەیەک ڕەت دەکرایەوە.
    try {
      final bool? exists = await _authService.phoneExists(_phoneE164);
      if (exists == false) {
        if (!mounted) return;
        setState(() {
          _phoneOtpSending = false;
          _loginPhoneErr = AuthStrings.phoneNotRegistered;
        });
        return;
      }
    } catch (_) {
      // پشکنینەکە شکستی هێنا (نێتوۆرک/RPC). ⚠ لێرەدا **ناوەستێین**:
      // ئەمە قازانجی تێچووە، نەک دەروازە. بەردەوامبوون واتە لە
      // خراپترین حاڵەتدا کۆدێکی زیادە دەنێردرێت، بەڵام بەکارهێنەرێکی
      // ڕاستەقینە بەهۆی هەڵەیەکی کاتییەوە لە چوونەژوورەوە نابڕدرێت.
    }

    final bool ok = await _authService.requestWhatsappOtp(
      phone: _phoneE164,
      purpose: AuthOtpPurpose.login,
      locale: ProxoLocale.current.value.languageCode,
    );

    if (!mounted) return;
    if (ok) {
      _pendingPhone = _phoneE164;
      _activeOtpChannel = AuthChannel.phone;
      _activeOtpPurpose = AuthOtpPurpose.login;
      _otpCtrl.clear();
      AuthFlowGuard.inOtpFlow = true;
      _startResendTimer();
      setState(() {
        _phoneOtpSending = false;
        _otpAttempts = 0;
        _otpHasError = false;
        _step = _Step.otp;
      });
    } else {
      setState(() {
        _phoneOtpSending = false;
        _loginPhoneErr = AuthStrings.otpSendFailed;
      });
    }
  }

  /// ئەنجامی پشتڕاستکردنەوەی ژمارە.
  ///
  /// `refreshToken` تەنها کاتێک پڕە کە کۆدەکە ڕاست بووە **و** هەژمارێکی
  /// بەم ژمارەیەوە بەستراو هەبووە.
  ///
  /// ⚠ `error` کۆدی ماشێنە، نەک دەقی بەکارهێنەر: `invalid_code`،
  /// `user_not_found`، `banned`، `no_email_on_account`،
  /// `session_failed`، `network`.
  ///
  /// ئەم ڕێڕەوە **جێگرەوەی** بانگکردنی وێبهووکی `wevlix/otp/verify`ە لە
  /// لای کلاینتەوە: پشتڕاستکردنەوە و دروستکردنی سێشن دەبێت یەک بانگ بن،
  /// چونکە `verify_otp_whatsapp` کۆدەکە بە `is_used = true` هەڵدەگرێت و
  /// جارێکی دووەم هەرگیز سەرکەوتوو نابێت.
  Future<({String? refreshToken, String? error})> _exchangePhoneOtp({
    required String phone,
    required String code,
  }) => _authService.exchangePhoneOtp(phone: phone, code: code);

  Future<({String? tokenHash, String? error})> _completePhoneSignup({
    required String phone,
    required String code,
    required String fullName,
    required String password,
  }) => _authService.completePhoneSignup(
        phone: phone,
        code: code,
        fullName: fullName,
        password: password,
      );

  /// تۆکێنی refresh دەگۆڕێت بە سێشنێکی چالاک.
  ///
  /// `setSession` تۆکێنەکە دەگۆڕێتەوە بۆ جووتێکی نوێی access/refresh و
  /// خۆی لە کلاینتەکەدا دایدەنێت، بۆیە هیچ کارێکی تری دەستی پێویست نییە.
  Future<void> _applyPhoneSession(String refreshToken) async {
    final AuthResponse r = await supabase.auth.setSession(refreshToken);
    final User? u = r.user;
    if (u == null) throw const AuthException('no session');

    unawaited(_logAuthActivity(userId: u.id, action: 'login'));
    unawaited(_recordLoginHistory(u.id));
    unawaited(TrustedDeviceService.remember(supabase));
    await _saveDeviceToken(u.id);
  }

  /// کۆدە ماشێنییەکانی فەنکشنی ئێج → پەیامی کوردی.
  String _mapPhoneAuthError(String? code) {
    switch (code) {
      case 'banned':
        return AuthStrings.phoneBanned;
      case 'user_not_found':
        return AuthStrings.phoneNotRegistered;
      case 'ambiguous_phone':
        return AuthStrings.phoneAmbiguous;
      case 'no_email_on_account':
        return AuthStrings.phoneNoEmail;
      case 'already_registered':
        return AuthStrings.phoneAlreadyRegistered;
      case 'weak_password':
        return AuthStrings.errWeakPassword;
      case 'network':
        return AuthStrings.errNetwork;
      case 'provision_failed':
      case 'session_failed':
      case 'verify_failed':
      case 'lookup_failed':
      case 'server_error':
        return AuthStrings.errServer;
      default:
        return AuthStrings.errServer;
    }
  }

  Future<bool> _sendLoginOtp(String email) =>
      _authService.sendLoginEmailOtp(email);

  Future<bool> _verifyLoginOtp({
    required String email,
    required String code,
  }) => _authService.verifyLoginEmailOtp(email: email, code: code);

  void _notifyN8n(String action, Map<String, dynamic> data) {
    http.post(Uri.parse(n8nWebhookUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'action': action, ...data}),
    ).timeout(const Duration(seconds: 8)).catchError((_) => http.Response('', 0));
  }

  void _startResendTimer() {
    _resendSeconds.value = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_resendSeconds.value == 0) { t.cancel(); return; }
      _resendSeconds.value--;
    });
  }

  bool _isNetworkError() {
    final s = _authService.lastOtpError ?? '';
    if (s.contains('timeout') || s.contains('TimeoutException')) return true;
    if (s.contains('SocketException') || s.contains('connection refused')) return true;
    if (s.contains('NetworkException') || s.contains('network')) return true;
    final code = _authService.lastOtpStatus;
    return code == 408 || code == 503 || code == 504;
  }

  // ── Actions: Login ────────────────────────────────────────

  Future<void> _doLogin() async {
    if (_loading) return;
    final email = AuthValidators.normalizeEmail(_loginEmailCtrl.text);
    final pass  = _loginPassCtrl.text;
    setState(() { _loginEmailErr = null; _loginPassErr = null; });
    if (email.isEmpty) { setState(() => _loginEmailErr = AuthStrings.errEmptyField); return; }
    if (!_isGmail(email)) { setState(() => _loginEmailErr = AuthStrings.errInvalidEmail); return; }
    if (pass.isEmpty)  { setState(() => _loginPassErr = AuthStrings.errEmptyField); return; }
    final lockMsg = _RateLimiter.check(email);
    if (lockMsg != null) { _showErrorCard(lockMsg); return; }
    setState(() => _loading = true);
    AuthFlowGuard.inOtpFlow = true;
    try {
      final Map<String, dynamic> attempt =
          Map<String, dynamic>.from(await supabase.rpc(
        'pa_login_attempt',
        params: {'p_email': email, 'p_password': pass},
      ) as Map);

      final String status = (attempt['status'] as String?) ?? 'invalid';

      if (status == 'locked') {
        _RateLimiter.reset(email);
        AuthFlowGuard.inOtpFlow = false;
        if (mounted) setState(() => _loginLockedOut = true);
        return;
      }
      if (status != 'ok') {
        AuthFlowGuard.inOtpFlow = false;
        final int? left = attempt['remaining'] as int?;
        _RateLimiter.recordFail(email);
        setState(() => _loginPassErr = left != null
            ? _t('وشەی تێپەڕ هەڵەیە — $left هەوڵی تر ماوە',
                'كلمة المرور غير صحيحة — تبقت $left محاولات')
            : AuthStrings.errWrongPassword);
        return;
      }

      if (mounted && _loginLockedOut) setState(() => _loginLockedOut = false);
      final String uid = attempt['user_id'] as String;
      String name = ((attempt['full_name'] as String?) ?? '').trim();
      if (name.isEmpty) name = email.split('@').first;

      try { await supabase.auth.signOut(); } catch (_) {}

      _pendingEmail = email; _pendingUserId = uid;
      _pendingPass  = pass;  _pendingName   = name;
      _activeOtpChannel = AuthChannel.email;
      _activeOtpPurpose = AuthOtpPurpose.login;
      _otpAttempts  = 0;
      _RateLimiter.reset(email);

      final ok = await _sendLoginOtp(email);
      if (!ok) {
        AuthFlowGuard.inOtpFlow = false;
        if (_isNetworkError()) {
          _showNetworkError();
        } else {
          _showErrorCard(AuthStrings.otpSendFailed);
        }
        return;
      }

      _startResendTimer();
      _otpCtrl.clear();
      setState(() { _otpHasError = false; _step = _Step.otp; });
    } on AuthException catch (e) {
      AuthFlowGuard.inOtpFlow = false;
      final locked = _RateLimiter.recordFail(email);
      if (locked) {
        _showErrorCard(_t('هەژمارەکەت بۆ ماوەی ٢٤ کاتژمێر قفڵ کراوە',
            'تم قفل حسابك لمدة 24 ساعة'));
      } else {
        setState(() => _loginPassErr =
            _t('${_mapAuthError(e.message)} — ${_RateLimiter.remaining(email)} هەوڵی تر ماوە',
                '${_mapAuthError(e.message)} — تبقت ${_RateLimiter.remaining(email)} محاولات'));
      }
    } catch (e) {
      AuthFlowGuard.inOtpFlow = false;
      _showNetworkError();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Actions: Register ─────────────────────────────────────

  Future<void> _doRegister() async {
    if (_loading) return;
    final String name = _regNameCtrl.text.trim();
    final String phone = _regPhoneE164;
    final String pass = _regPassCtrl.text;
    final pass2 = _regPass2Ctrl.text;

    setState(() {
      _regNameErr = null;
      _regPhoneErr = null;
      _regPassErr = null;
      _regPass2Err = null;
    });
    final String? nameError = AuthValidators.fullName(name);
    if (nameError != null) {
      setState(() => _regNameErr = nameError);
      return;
    }
    if (!_regPhoneValid) {
      setState(() => _regPhoneErr = AuthStrings.phoneInvalid);
      return;
    }
    final String? passwordError = AuthValidators.newPassword(pass);
    if (passwordError != null) {
      setState(() => _regPassErr = passwordError);
      return;
    }
    final String? confirmationError =
        AuthValidators.confirmPassword(pass2, pass);
    if (confirmationError != null) {
      setState(() => _regPass2Err = confirmationError);
      return;
    }

    setState(() => _loading = true);
    AuthFlowGuard.inOtpFlow = true;
    try {
      final bool? exists = await _authService.phoneExists(phone);
      if (exists == true) {
        setState(() => _regPhoneErr = AuthStrings.phoneAlreadyRegistered);
        AuthFlowGuard.inOtpFlow = false;
        return;
      }

      final bool ok = await _authService.requestWhatsappOtp(
        phone: phone,
        purpose: AuthOtpPurpose.signup,
        locale: ProxoLocale.current.value.languageCode,
      );
      if (!ok) {
        _showErrorCard(AuthStrings.otpSendFailed);
        AuthFlowGuard.inOtpFlow = false;
        return;
      }

      _pendingPhone = phone;
      _pendingEmail = '';
      _pendingUserId = '';
      _pendingPass = pass;
      _pendingName = name;
      _activeOtpChannel = AuthChannel.phone;
      _activeOtpPurpose = AuthOtpPurpose.signup;
      _otpAttempts = 0;
      _startResendTimer();
      _otpCtrl.clear();
      setState(() { _otpHasError = false; _step = _Step.otp; });
    } catch (_) {
      AuthFlowGuard.inOtpFlow = false;
      _showNetworkError();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Actions: OTP ──────────────────────────────────────────

  String get _otpCode => _otpCtrl.text.trim();

  Future<void> _doVerifyOtp() async {
    if (_loading) return;
    if (_otpCode.length < 6) { 
      _showErrorCard(AuthStrings.errEmptyField);
      return; 
    }
    // ── کام کەناڵ؟ ───────────────────────────────────────────────────────
    // هەمان ڕووکاری OTP بۆ هەردوو کەناڵەکە بەکاردێت؛ تەنها ئەو
    // فەنکشنەی پشتڕاستکردنەوە و ئەو کلیلەی سنووردارکردنی نرخ
    // جیاوازن (ئیمەیڵ بەرامبەر ژمارە).
    final bool byPhone = _activeOtpChannel == AuthChannel.phone;
    final bool isPhoneSignup =
        byPhone && _activeOtpPurpose == AuthOtpPurpose.signup;
    final String rateKey = byPhone ? _pendingPhone : _pendingEmail;

    setState(() => _loading = true);
    try {
      // ڕێڕەوی ژمارە کۆدی هەڵەی خۆی دەگەڕێنێتەوە (بانکراو، شکستی
      // دروستکردن، …)، بۆیە جیا هەڵدەگیرێت لە ئەنجامی سادەی ئیمەیڵ.
      String? phoneRefreshToken;
      String? signupTokenHash;
      String? phoneError;
      bool valid;

      if (isPhoneSignup) {
        final result = await _completePhoneSignup(
          phone: _pendingPhone,
          code: _otpCode,
          fullName: _pendingName,
          password: _pendingPass,
        );
        signupTokenHash = result.tokenHash;
        phoneError = result.error;
        valid = result.tokenHash != null;
        if (!valid && phoneError != 'invalid_code') {
          _showErrorCard(_mapPhoneAuthError(phoneError));
          if (phoneError == 'already_registered') {
            AuthFlowGuard.inOtpFlow = false;
            setState(() {
              _tab = _Tab.login;
              _step = _Step.form;
            });
          }
          return;
        }
      } else if (byPhone) {
        final r = await _exchangePhoneOtp(
            phone: _pendingPhone, code: _otpCode);
        phoneRefreshToken = r.refreshToken;
        phoneError = r.error;
        valid = r.refreshToken != null;

        // ⚠ بانکراو و شکستی سێرڤەر **هەڵەی کۆد نین**. ئەگەر وەک هەڵەی
        // کۆد مامەڵەیان لەگەڵ بکرێت، ژمێرەری هەوڵەکان بەفیڕۆ دەڕوات و
        // بەکارهێنەرێکی بانکراو پەیامی «کۆدەکە هەڵەیە» دەبینێت.
        if (!valid && phoneError != 'invalid_code') {
          _showErrorCard(_mapPhoneAuthError(phoneError));
          AuthFlowGuard.inOtpFlow = false;
          setState(() => _step = _Step.form);
          return;
        }
      } else {
        valid = await _verifyLoginOtp(email: _pendingEmail, code: _otpCode);
      }

      if (!valid) {
        _otpAttempts++;
        if (_otpAttempts >= _RateLimiter._maxAttempts) {
          // OTP، نەک وشەی نهێنی — بۆیە ماوەیەکی کورتتر و پەیامێکی
          // جیاواز. هیچ قفڵێکی داتابەیس لێرەوە دانانرێت.
          _RateLimiter.recordFail(rateKey,
              lockFor: _RateLimiter._lockForOtp);
          _showErrorCard(_t('زۆر کۆدی هەڵەت نووسی — ١٥ خولەک چاوەڕێ بکە',
              'محاولات كثيرة غير صحيحة — انتظر 15 دقيقة'));
          AuthFlowGuard.inOtpFlow = false;
          setState(() { _step = _Step.form; _otpAttempts = 0; _otpHasError = false; });
        } else {
          _showErrorCard(_t('کۆدەکە هەڵەیە — ${_RateLimiter._maxAttempts - _otpAttempts} هەوڵی تر ماوە',
              'الرمز غير صحيح — تبقت ${_RateLimiter._maxAttempts - _otpAttempts} محاولات'));
          setState(() { _otpHasError = true; });
          _otpShaker.shakeAndReset();
        }
        return;
      }

      _RateLimiter.reset(rateKey);

      if (isPhoneSignup) {
        try {
          final AuthResponse response = await supabase.auth.verifyOTP(
            tokenHash: signupTokenHash!,
            type: OtpType.magiclink,
          );
          final User? user = response.user;
          if (user == null) throw const AuthException('session_failed');
          unawaited(_logAuthActivity(userId: user.id, action: 'register'));
          unawaited(_recordLoginHistory(user.id));
          unawaited(TrustedDeviceService.remember(supabase));
          await _saveDeviceToken(user.id);
          AuthFlowGuard.inOtpFlow = false;
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainShell()),
            (route) => false,
          );
        } on AuthException catch (e) {
          AuthFlowGuard.inOtpFlow = false;
          _showErrorCard(_mapAuthError(e.message));
        } catch (_) {
          AuthFlowGuard.inOtpFlow = false;
          _showErrorCard(AuthStrings.errServer);
        }
        return;
      }

      // ── ڕێڕەوی ژمارە: سێشن دروست بکە و بچۆ ژوورەوە ────────────────────
      // فەنکشنی ئێج کۆدەکەی پشتڕاست کردەوە، بەکارهێنەرەکەی دۆزییەوە
      // (یان دروستی کرد)، و کلیلێکی یەک‌جاریی گەڕاندەوە. ئێستا تەنها
      // دەگۆڕدرێت بە سێشن.
      if (byPhone) {
        try {
          await _applyPhoneSession(phoneRefreshToken!);
          AuthFlowGuard.inOtpFlow = false;
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainShell()),
            (r) => false,
          );
        } on AuthException catch (e) {
          AuthFlowGuard.inOtpFlow = false;
          _showErrorCard(_mapAuthError(e.message));
          setState(() => _step = _Step.form);
        } catch (e) {
          AuthFlowGuard.inOtpFlow = false;
          // ⚠ `setSession` شکستی هێنا دوای ئەوەی سێرڤەر تۆکێنەکەی دا.
          // ئەمە شکستی سێشنە، نەک ئینتەرنێت و نەک کۆدی هەڵە.
          debugPrint('setSession failed: $e');
          _showErrorCard(_mapPhoneAuthError('session_failed'));
          setState(() => _step = _Step.form);
        }
        return;
      }

      Future<void> signInAndNavigate() async {
        try {
          final r = await supabase.auth.signInWithPassword(
            email: _pendingEmail, password: _pendingPass);
          if (r.user != null && mounted) {
            // تەنها دوای دروستبوونی سێشنی خاوەن هەژمار، تۆماری
            // سڕینەوەی هەمان بەکارهێنەر لادەبرێت.
            try { await supabase.rpc('pa_restore_deleted_account'); } catch (_) {}
            unawaited(_logAuthActivity(
              userId: r.user!.id,
              action: _tab == _Tab.login ? 'login' : 'register',
            ));
            unawaited(_recordLoginHistory(r.user!.id));
            unawaited(TrustedDeviceService.remember(supabase));
            await _saveDeviceToken(r.user!.id);
            AuthFlowGuard.inOtpFlow = false;
            if (!mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MainShell()), (r) => false);
          } else if (mounted) {
            _showErrorCard(AuthStrings.errServer);
          }
        } on AuthException catch (e) {
          _showErrorCard(_mapAuthError(e.message));
        }
      }

      if (_tab == _Tab.login) {
        await signInAndNavigate();
      } else {
        _notifyN8n('email_verified', {'email': _pendingEmail, 'user_id': _pendingUserId});
        try { await supabase.rpc('proxo_confirm_email', params: {'p_user_id': _pendingUserId}); } catch (_) {}
        await signInAndNavigate();
      }
    } catch (e) {
      _showNetworkError();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logAuthActivity({
    required String userId,
    required String action,
  }) async {
    try {
      await supabase.from('pa_activity_log').insert({
        'user_id': userId,
        'action': action,
        'description': action == 'login'
            ? 'چوونەژوورەوە بۆ هەژمار'
            : 'تۆمارکردنی هەژماری نوێ',
      });
    } catch (_) {}
  }

  Future<void> _recordLoginHistory(String userId) async {
    try {
      final device = await _getDeviceModel();
      final geo    = await _getIpLocation();
      await supabase.from('pa_login_history').insert({
        'user_id':     userId,
        'device_info': device,
        'location':    geo['location'],
        'ip_address':  geo['ip'],
        'success':     true,
      });
    } catch (_) {}
  }

  Future<String> _getDeviceModel() async {
    try {
      final info = DeviceInfoPlugin();
      if (Theme.of(context).platform == TargetPlatform.iOS) {
        final ios = await info.iosInfo;
        final name = ios.name.isNotEmpty ? ios.name : 'ئایفۆن';
        return '$name (iOS ${ios.systemVersion})';
      } else {
        final android = await info.androidInfo;
        final brand = android.brand.isNotEmpty
            ? '${android.brand[0].toUpperCase()}${android.brand.substring(1)}'
            : '';
        final model = android.model;
        final combined = '$brand $model'.trim();
        return combined.isEmpty ? 'ئامێری ئەندرۆید' : combined;
      }
    } catch (_) {
      return 'ئامێری نەزانراو';
    }
  }

  Future<Map<String, String>> _getIpLocation() async {
    try {
      final res = await http
          .get(Uri.parse('https://ipapi.co/json/'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['error'] != true) {
          final city    = data['city']?.toString() ?? '';
          final country = data['country_name']?.toString() ?? '';
          final loc = [city, country].where((e) => e.isNotEmpty).join('، ');
          return {
            'location': loc.isEmpty ? 'نەزانراو' : loc,
            'ip': data['ip']?.toString() ?? '',
          };
        }
      }
    } catch (_) {}
    return {'location': 'نەزانراو', 'ip': ''};
  }

  Future<void> _saveDeviceToken(String userId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      final platform = Theme.of(context).platform == TargetPlatform.iOS ? 'ios' : 'android';
      await supabase.from('pa_device_tokens').upsert(
        {
          'user_id':    userId,
          'token':      token,
          'platform':   platform,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id, token',
      );
    } catch (_) {}
  }

  void _cancelOtpAndGoBack() {
    AuthFlowGuard.inOtpFlow = false;
    setState(() { _step = _Step.form; _otpAttempts = 0; _otpHasError = false; });
    _otpCtrl.clear();
  }

  Future<void> _resendOtp() async {
    if (_resendSeconds.value > 0) return;
    setState(() => _loading = true);
    try {
      final bool ok;
      if (_activeOtpChannel == AuthChannel.phone) {
        ok = await _authService.requestWhatsappOtp(
          phone: _pendingPhone,
          purpose: _activeOtpPurpose,
          locale: ProxoLocale.current.value.languageCode,
        );
      } else if (_activeOtpPurpose == AuthOtpPurpose.login) {
        ok = await _sendLoginOtp(_pendingEmail);
      } else {
        ok = await _authService.requestEmailOtp(
          email: _pendingEmail,
          userId: _pendingUserId,
          name: _pendingName.isNotEmpty
              ? _pendingName
              : _pendingEmail.split('@').first,
          purpose: _activeOtpPurpose == AuthOtpPurpose.passwordReset
              ? 'reset_password'
              : 'signup',
        );
      }
      if (ok) {
        _startResendTimer(); _otpAttempts = 0;
        _otpCtrl.clear();
        setState(() => _otpHasError = false);
        _otpFocus.requestFocus();
      } else {
        if (_isNetworkError()) {
          _showNetworkError();
        } else {
          _showErrorCard(AuthStrings.otpSendFailed);
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Actions: Forgot Password ──────────────────────────────

  Future<void> _doForgotSendOtp() async {
    final email = AuthValidators.normalizeEmail(_fpEmailCtrl.text);
    setState(() => _fpEmailErr = null);
    if (email.isEmpty)    { setState(() => _fpEmailErr = AuthStrings.errEmptyField); return; }
    if (!_isGmail(email)) { setState(() => _fpEmailErr = AuthStrings.errInvalidEmail); return; }
    setState(() => _loading = true);
    try {
      final prof = await supabase.from('profiles')
          .select('id, full_name').eq('email', email).maybeSingle();
      if (prof == null) { 
        _showErrorCard(_t('ئەگەر هەژمارەکە هەبێت، کۆدێک بۆی دەنێردرێت',
            'إذا كان الحساب موجوداً فسيتم إرسال رمز إليه'));
        return; 
      }
      _fpUserId = prof['id'] as String;
      final name = (prof['full_name'] as String?) ?? '';
      final ok = await _authService.requestEmailOtp(
          email: email, userId: _fpUserId, name: name, purpose: 'reset_password');
      if (!ok) {
        if (_isNetworkError()) {
          _showNetworkError();
        } else {
          _showErrorCard(AuthStrings.otpSendFailed);
        }
        return;
      }
      _fpOtpAttempts = 0;
      _fpOtpCtrl.clear();
      _activeOtpChannel = AuthChannel.email;
      _activeOtpPurpose = AuthOtpPurpose.passwordReset;
      setState(() { _fpOtpHasError = false; });
      _startResendTimer();
      setState(() => _step = _Step.forgotOtp);
    } catch (e) {
      _showNetworkError();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _fpOtpCode => _fpOtpCtrl.text.trim();

  Future<void> _doForgotVerifyOtp() async {
    if (_fpOtpCode.length < 6) { 
      _showErrorCard(AuthStrings.errEmptyField);
      return; 
    }
    setState(() => _loading = true);
    try {
      final rpc = await supabase.rpc('pa_verify_reset_otp', params: {
        'p_email': AuthValidators.normalizeEmail(_fpEmailCtrl.text),
        'p_code': _fpOtpCode.trim(),
      });
      final Map<String, dynamic>? res =
          (rpc is Map && rpc['valid'] == true)
              ? Map<String, dynamic>.from(rpc as Map)
              : null;
      if (res == null) {
        _fpOtpAttempts++;
        if (_fpOtpAttempts >= _RateLimiter._maxAttempts) {
          _showErrorCard(_t('زۆر هەوڵی هەڵەت دا — کۆدی نوێ داوا بکە',
              'محاولات كثيرة غير صحيحة — اطلب رمزاً جديداً'));
          setState(() { _step = _Step.forgotEmail; _fpOtpAttempts = 0; _fpOtpHasError = false; });
        } else {
          _showErrorCard(_t('کۆدەکە هەڵەیە — ${_RateLimiter._maxAttempts - _fpOtpAttempts} هەوڵی تر ماوە',
              'الرمز غير صحيح — تبقت ${_RateLimiter._maxAttempts - _fpOtpAttempts} محاولات'));
          setState(() { _fpOtpHasError = true; });
          _fpOtpShaker.shakeAndReset();
        }
        return;
      }
      _fpVerifiedOtpId = res['otp_id'] as String;
      _fpNewPassCtrl.clear();
      _resetPasswordVisible.value = false;
      _resetConfirmationVisible.value = false;
      setState(() => _step = _Step.forgotNewPass);
    } catch (e) {
      _showNetworkError();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _doForgotSetPassword() async {
    final newPass     = _fpNewPassCtrl.text;
    final confirmPass = _fpConfirmPassCtrl.text;
    final email       = AuthValidators.normalizeEmail(_fpEmailCtrl.text);

    setState(() { _fpNewPassErr = null; _fpConfirmPassErr = null; });
    final String? passwordError = AuthValidators.newPassword(newPass);
    if (passwordError != null) {
      setState(() => _fpNewPassErr = passwordError);
      return;
    }
    if (newPass != confirmPass) {
      setState(() => _fpConfirmPassErr = AuthStrings.errPasswordMismatch);
      return;
    }

    setState(() => _loading = true);
    try {
      final rpcRes = await supabase.rpc(
        'proxo_reset_password',
        params: {
          'p_user_id': _fpUserId,
          'p_otp_id': _fpVerifiedOtpId,
          'p_new_password': newPass,
        },
      );

      if (rpcRes != true) {
        _showErrorCard(AuthStrings.errExpiredOtp);
        return;
      }

      try { await supabase.auth.signOut(); } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 600));

      final loginRes = await supabase.auth.signInWithPassword(
        email:    email,
        password: newPass,
      );

      if (loginRes.user != null) {
        await _saveDeviceToken(loginRes.user!.id);
        unawaited(_recordLoginHistory(loginRes.user!.id));
        if (!mounted) return;
        _fpUserId = ''; _fpVerifiedOtpId = '';
        _fpEmailCtrl.clear(); _fpNewPassCtrl.clear(); _fpConfirmPassCtrl.clear();
      } else {
        setState(() {
          _step = _Step.form;
          _tab  = _Tab.login;
          _loginEmailCtrl.text = email;
          _fpUserId = ''; _fpVerifiedOtpId = '';
          _fpEmailCtrl.clear(); _fpNewPassCtrl.clear(); _fpConfirmPassCtrl.clear();
        });
      }
    } catch (e) {
      _showErrorCard(AuthStrings.errServer);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendFpOtp() async {
    if (_resendSeconds.value > 0) return;
    setState(() => _loading = true);
    try {
      final prof = await supabase.from('profiles')
          .select('full_name').eq('id', _fpUserId).maybeSingle();
      final name = (prof?['full_name'] as String?) ?? '';
      final ok = await _authService.requestEmailOtp(
        email: AuthValidators.normalizeEmail(_fpEmailCtrl.text), userId: _fpUserId,
        name: name, purpose: 'reset_password',
      );
      if (ok) {
        _startResendTimer(); _fpOtpAttempts = 0;
        _fpOtpCtrl.clear();
        setState(() => _fpOtpHasError = false);
        _fpOtpFocus.requestFocus();
      } else {
        if (_isNetworkError()) {
          _showNetworkError();
        } else {
          _showErrorCard(AuthStrings.otpSendFailed);
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mapAuthError(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('email not confirmed')) return AuthStrings.errWrongPassword;
    if (m.contains('invalid login') || m.contains('invalid credentials') ||
        m.contains('invalid email or password') || m.contains('invalid')) return AuthStrings.errWrongPassword;
    if (m.contains('email already') || m.contains('already registered')) return AuthStrings.errEmailExists;
    if (m.contains('otp')) return AuthStrings.errInvalidOtp;
    if (m.contains('expired')) return AuthStrings.errExpiredOtp;
    if (m.contains('weak password')) return AuthStrings.errWeakPassword;
    if (m.contains('network') || m.contains('connection')) return AuthStrings.errNetwork;
    return AuthStrings.errWrongPassword;
  }

  String get _viewKey => switch (_step) {
        _Step.form => _tab == _Tab.login ? 'signin' : 'signup',
        _Step.otp => 'otp',
        _Step.forgotEmail => 'fpEmail',
        _Step.forgotOtp => 'fpOtp',
        _Step.forgotNewPass => 'fpPass',
      };

  void _goToSignUp() {
    FocusScope.of(context).unfocus();
    AuthFlowGuard.inOtpFlow = false;
    setState(() {
      _tab = _Tab.register;
      _step = _Step.form;
      _regNameErr = _regPhoneErr = _regPassErr = _regPass2Err = null;
      _bannerError = null;
    });
  }

  void _goToSignIn() {
    FocusScope.of(context).unfocus();
    AuthFlowGuard.inOtpFlow = false;
    setState(() {
      _tab = _Tab.login;
      _step = _Step.form;
      _loginEmailErr = _loginPassErr = null;
      _bannerError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ProxoLocale.directionOf(ProxoLocale.current.value),
      child: PopScope<Object?>(
        // Auth history is internal state, not Navigator history. Disabling
        // route pop also prevents Android back and iOS edge-swipe from
        // bypassing the visible, state-aware Back control.
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {},
        child: Scaffold(
          backgroundColor: AuthTokens.pageBackground,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, viewport) => SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              // ⚠ بوو 20. گەتەری ئاسۆیی ئێستا 16ـە لە هەموو شاشەکاندا —
              // هەمان `AuthTokens.pagePadding`.
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: max(0.0, viewport.maxHeight - 32),
                ),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── کارتی ئیرۆری سپی مۆدێرن (پاش ٤ چرکە دەڕوات) ──
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _bannerError != null
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
                              // ── بانەری سنوورداری نرخ (١٥ خولەک) ────────
                              // ئەمە ئەو بانەرەیە کە پەیامی «زۆر کۆدی
                              // هەڵەت نووسی — ١٥ خولەک چاوەڕێ بکە» نیشان
                              // دەدات. دەقاودەق هەمان ڕووی `AuthAlert` و
                              // `AuthLockoutNotice`ە، بۆیە هەر سێ
                              // ئاگادارکردنەوەکەی ئەم شاشەیە یەک شێوەن.
                              decoration: BoxDecoration(
                                color: AuthTokens.dangerBg,
                                borderRadius: BorderRadius.circular(12.0),
                                border: Border.all(
                                    color: AuthTokens.danger, width: 1.0),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: AuthTokens.danger,
                                    size: 19.0,
                                  ),
                                  const SizedBox(width: 10.0),
                                  Expanded(
                                    child: Text(
                                      _bannerError!,
                                      style: TextStyle(
                                        fontFamily: kAppFont,
                                        fontSize: AuthTokens.textSize,
                                        fontWeight: FontWeight.w500,
                                        color: AuthTokens.danger,
                                        height: 1.25,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  AnimatedSwitcher(
                    duration: AuthTokens.viewTransition,
                    switchInCurve: AuthTokens.curve,
                    switchOutCurve: AuthTokens.curve,
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        ...previous.map((w) => Positioned.fill(child: w)),
                        if (current != null) current,
                      ],
                    ),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.04, 0),
                          end: Offset.zero,
                        ).animate(anim),
                        textDirection: Directionality.of(context),
                        child: child,
                      ),
                    ),
                    child: AbsorbPointer(
                      absorbing: _loading,
                      child: KeyedSubtree(
                        key: ValueKey<String>(_viewKey),
                        child: _buildCurrentView(),
                      ),
                    ),
                  ),
                ],
                ),
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentView() => switch (_step) {
        _Step.form =>
          _tab == _Tab.login ? _buildSignInView() : _buildSignUpView(),
        _Step.otp => _buildOtpView(),
        _Step.forgotEmail => _buildForgotEmailView(),
        _Step.forgotOtp => _buildForgotOtpView(),
        _Step.forgotNewPass => _buildForgotNewPassView(),
      };

  // ── View 1: Sign In ───────────────────────────────────────────────────────

  Widget _buildSignInView() {
    final String? lockMsg =
        _RateLimiter.check(AuthValidators.normalizeEmail(_loginEmailCtrl.text));

    return LoginScreen(
      content: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── سویچی کەناڵ ────────────────────────────────────────────────
        // ⚠ تەنها لێرەیە. `_buildSignUpView` دەستی لێ نەدراوە.
        AuthSegmentedControl(
          labels: [AuthStrings.channelPhone, AuthStrings.channelEmail],
          index: _loginChannel == AuthChannel.phone ? 0 : 1,
          enabled: !_loading && !_phoneOtpSending,
          onChanged: (i) {
            FocusScope.of(context).unfocus();
            setState(() {
              _loginChannel =
                  i == 0 ? AuthChannel.phone : AuthChannel.email;
              // هەڵەکانی کەناڵی پێشوو نامێننەوە بۆ ئەوەی بەکارهێنەر
              // هەڵەیەکی خانەیەکی شاراوە نەبینێت.
              _loginPhoneErr = null;
              _loginEmailErr = null;
              _loginPassErr = null;
            });
          },
        ),
        const SizedBox(height: 14),

        if (_loginLockedOut)
          AuthLockoutNotice(onContactSupport: _contactSupportOnWhatsApp)
        else
          AuthAlert(message: lockMsg),

        // ── فۆڕمی کەناڵ ────────────────────────────────────────────────
        // `AnimatedSwitcher` بە فەید + سلایدی سووک. ⚠ `KeyedSubtree` بە
        // کلیلی کەناڵەکە پێویستە: بەبێ ئەو، `AnimatedSwitcher` هەردوو
        // فۆڕمەکە وەک هەمان ویدجێت دەبینێت (هەردووکیان `Column`ن) و هیچ
        // گواستنەوەیەک ناکات.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          // بەرزایی دوو فۆڕمەکە جیاوازە، بۆیە `AnimatedSize`ـی ناوەوەی
          // `AnimatedSwitcher` (لەیئاوتبیلدەر) پێویستە تا ستوونەکە
          // نەبازێت لە کاتی گۆڕیندا.
          layoutBuilder: (current, previous) => Stack(
            alignment: AlignmentDirectional.topStart,
            children: [
              ...previous,
              if (current != null) current,
            ],
          ),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey<AuthChannel>(_loginChannel),
            child: _loginChannel == AuthChannel.phone
                ? _buildPhoneForm()
                : _buildEmailForm(),
          ),
        ),

        const SizedBox(height: 16),
        _promptRow(
          lead: AuthStrings.noAccountLead,
          action: AuthStrings.noAccountAction,
          onTap: _loading ? null : _goToSignUp,
        ),
        const SizedBox(height: 16),
      ],
      ),
    );
  }

  /// فۆڕمی ئیمەیڵ + وشەی نهێنی — دەقاودەق ئەوەی پێشوو، بەبێ گۆڕان.
  Widget _buildEmailForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_trustedEmail != null)
          AuthFastAccountCard(
            email: _trustedEmail!,
            selected: _trustedSelected,
            onContinue: _useTrustedAccount,
            onForget: _forgetTrustedAccount,
          ),

        if (!_trustedSelected)
          AuthTextField(
            controller: _loginEmailCtrl,
            focusNode: _loginEmailFocus,
            label: AuthStrings.emailLabel,
            hint: AuthStrings.emailHint,
            icon: Icons.mail_outline_rounded,
            error: _loginEmailErr,
            ltr: true,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            enabled: !_loading,
            onChanged: (_) {
              if (_loginEmailErr != null) setState(() => _loginEmailErr = null);
            },
            trailing: AuthClearButton(
              controller: _loginEmailCtrl,
              focusNode: _loginEmailFocus,
              onCleared: () {
                if (_loginEmailErr != null) setState(() => _loginEmailErr = null);
              },
            ),
          ),
        if (!_trustedSelected)
          EmailDomainChips(
            controller: _loginEmailCtrl,
            focusNode: _loginEmailFocus,
          ),
        if (!_trustedSelected)
          const SizedBox(height: 10),

        ValueListenableBuilder<bool>(
          valueListenable: _loginPasswordVisible,
          builder: (context, visible, _) => AuthTextField(
          controller: _loginPassCtrl,
          focusNode: _loginPassFocus,
          label: AuthStrings.passwordLabel,
          forceLtr: true,
          hint: AuthStrings.passwordHint,
          icon: Icons.lock_outline_rounded,
          error: _loginPassErr,
          obscure: !visible,
          ltr: true,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          enabled: !_loading,
          onChanged: (_) {
            if (_loginPassErr != null) setState(() => _loginPassErr = null);
          },
          onSubmitted: (_) => _doLogin(),
          trailing: _visibilityToggle(
            shown: visible,
            onTap: () => _loginPasswordVisible.value = !visible,
          ),
          ),
        ),

        const SizedBox(height: 10),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: AuthTextLink(
            label: AuthStrings.forgotPasswordLink,
            onTap: _loading
                ? null
                : () {
                    FocusScope.of(context).unfocus();
                    setState(() {
                      _step = _Step.forgotEmail;
                      _fpEmailErr = null;
                      _fpEmailCtrl.text =
                          AuthValidators.normalizeEmail(_loginEmailCtrl.text);
                    });
                  },
          ),
        ),

        const SizedBox(height: 18),
        ListenableBuilder(
          listenable: Listenable.merge([_loginEmailCtrl, _loginPassCtrl]),
          builder: (context, _) => AuthPrimaryButton(
            label: AuthStrings.signInButton,
            loading: _loading,
            enabled: AuthValidators.signInReady(
              email: _loginEmailCtrl.text,
              password: _loginPassCtrl.text,
            ),
            onPressed: _doLogin,
          ),
        ),
      ],
    );
  }

  /// فۆڕمی ژمارەی مۆبایل — خانەیەک و دوگمەیەک.
  Widget _buildPhoneForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AuthTextField(
          controller: _loginPhoneCtrl,
          focusNode: _loginPhoneFocus,
          label: AuthStrings.phoneLabel,
          hint: AuthStrings.phoneHint,
          icon: Icons.phone_iphone_rounded,
          error: _loginPhoneErr,
          ltr: true,
          forceLtr: true,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.telephoneNumber],
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          enabled: !_phoneOtpSending,
          // پێشگری کۆدی وڵات لەناو خودی خانەکەدا — یەک سنوور، یەک فۆکەس.
          prefix: Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Text(
              '🇮🇶  ${AuthStrings.phonePrefix}',
              textDirection: TextDirection.ltr,
              style: AuthTokens.fieldText.copyWith(
                fontWeight: FontWeight.w500,
                color: AuthTokens.inkMuted,
              ),
            ),
          ),
          onChanged: (_) {
            _keepPhoneControllerLocal(_loginPhoneCtrl);
            if (_loginPhoneErr != null) {
              setState(() => _loginPhoneErr = null);
            }
          },
          onSubmitted: (_) => _sendPhoneOtp(),
        ),

        const SizedBox(height: 18),
        ListenableBuilder(
          listenable: _loginPhoneCtrl,
          builder: (context, _) => AuthPrimaryButton(
            label: AuthStrings.sendOtpButton,
            loading: _phoneOtpSending,
            enabled: _phoneValid,
            onPressed: _sendPhoneOtp,
          ),
        ),
      ],
    );
  }

  // ── View 2: Sign Up ───────────────────────────────────────────────────────

  Widget _buildSignUpView() {
    return SignupScreen(
      onBack: _goToSignIn,
      content: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthTextField(
          controller: _regNameCtrl,
          focusNode: _regNameFocus,
          label: AuthStrings.fullNameLabel,
          hint: AuthStrings.fullNameHint,
          icon: Icons.person_outline_rounded,
          error: _regNameErr,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          enabled: !_loading,
          onChanged: (_) {
            if (_regNameErr != null) setState(() => _regNameErr = null);
          },
          trailing: AuthClearButton(
            controller: _regNameCtrl,
            focusNode: _regNameFocus,
            onCleared: () {
              if (_regNameErr != null) setState(() => _regNameErr = null);
            },
          ),
        ),
        const SizedBox(height: 10),

        AuthTextField(
          controller: _regPhoneCtrl,
          focusNode: _regPhoneFocus,
          label: AuthStrings.phoneLabel,
          hint: AuthStrings.phoneHint,
          icon: Icons.phone_iphone_rounded,
          error: _regPhoneErr,
          ltr: true,
          forceLtr: true,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.telephoneNumber],
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          enabled: !_loading,
          prefix: Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Text(
              '🇮🇶  ${AuthStrings.phonePrefix}',
              textDirection: TextDirection.ltr,
              style: AuthTokens.fieldText.copyWith(
                fontWeight: FontWeight.w500,
                color: AuthTokens.inkMuted,
              ),
            ),
          ),
          onChanged: (_) {
            _keepPhoneControllerLocal(_regPhoneCtrl);
            if (_regPhoneErr != null) setState(() => _regPhoneErr = null);
          },
          trailing: AuthClearButton(
            controller: _regPhoneCtrl,
            focusNode: _regPhoneFocus,
            onCleared: () {
              if (_regPhoneErr != null) setState(() => _regPhoneErr = null);
            },
          ),
        ),
        const SizedBox(height: 10),

        ValueListenableBuilder<bool>(
          valueListenable: _signupPasswordVisible,
          builder: (context, visible, _) => AuthTextField(
          controller: _regPassCtrl,
          forceLtr: true,
          label: AuthStrings.passwordLabel,
          hint: AuthStrings.passwordHint,
          icon: Icons.lock_outline_rounded,
          error: _regPassErr,
          obscure: !visible,
          ltr: true,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          enabled: !_loading,
          onChanged: (_) {
            if (_regPassErr != null) setState(() => _regPassErr = null);
          },
          trailing: _visibilityToggle(
            shown: visible,
            onTap: () => _signupPasswordVisible.value = !visible,
          ),
          ),
        ),

        const SizedBox(height: 10),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _regPassCtrl,
          builder: (context, value, _) =>
              PasswordStrengthMeter(password: value.text),
        ),

        const SizedBox(height: 10),
        ListenableBuilder(
          listenable: Listenable.merge([_regPassCtrl, _regPass2Ctrl]),
          builder: (context, _) => ValueListenableBuilder<bool>(
            valueListenable: _signupConfirmationVisible,
            builder: (context, visible, __) => AuthTextField(
            controller: _regPass2Ctrl,
            forceLtr: true,
            label: AuthStrings.confirmPasswordLabel,
            hint: AuthStrings.passwordHint,
            icon: Icons.lock_reset_rounded,
            error: _regPass2Err ??
                (_confirmMismatch(_regPassCtrl.text, _regPass2Ctrl.text)
                    ? AuthStrings.errPasswordMismatch
                    : null),
            obscure: !visible,
            ltr: true,
            textInputAction: TextInputAction.done,
            enabled: !_loading,
            onChanged: (_) {
              if (_regPass2Err != null) setState(() => _regPass2Err = null);
            },
            onSubmitted: (_) => _doRegister(),
            trailing: _visibilityToggle(
              shown: visible,
              onTap: () => _signupConfirmationVisible.value = !visible,
            ),
            ),
          ),
        ),

        const SizedBox(height: 18),
        ListenableBuilder(
          listenable: Listenable.merge(
              [_regNameCtrl, _regPhoneCtrl, _regPassCtrl, _regPass2Ctrl]),
          builder: (context, _) => AuthPrimaryButton(
            label: AuthStrings.signUpButton,
            loading: _loading,
            enabled: AuthValidators.signUpReady(
              name: _regNameCtrl.text,
              phone: _regPhoneE164,
              password: _regPassCtrl.text,
              confirmation: _regPass2Ctrl.text,
            ),
            onPressed: _doRegister,
          ),
        ),

        const SizedBox(height: 16),
        _promptRow(
          lead: AuthStrings.haveAccountLead,
          action: AuthStrings.haveAccountAction,
          onTap: _loading ? null : _goToSignIn,
        ),
        const SizedBox(height: 16),
      ],
      ),
    );
  }

  // ── View 3: OTP ───────────────────────────────────────────────────────────

  Widget _buildOtpView() => _otpScaffold(
        destination: otpDestination(
          _activeOtpChannel,
          _activeOtpChannel == AuthChannel.phone
              ? _pendingPhone
              : _pendingEmail,
        ),
        codeCtrl: _otpCtrl,
        focus: _otpFocus,
        shaker: _otpShaker,
        hasError: _otpHasError,
        seconds: _resendSeconds,
        onBack: _cancelOtpAndGoBack,
        onSubmit: _doVerifyOtp,
        onResend: _resendOtp,
      );

  Widget _buildForgotOtpView() => _otpScaffold(
        destination: otpDestination(
          AuthChannel.email,
          AuthValidators.normalizeEmail(_fpEmailCtrl.text),
        ),
        codeCtrl: _fpOtpCtrl,
        focus: _fpOtpFocus,
        shaker: _fpOtpShaker,
        hasError: _fpOtpHasError,
        seconds: _resendSeconds,
        onBack: () => setState(() => _step = _Step.forgotEmail),
        onSubmit: _doForgotVerifyOtp,
        onResend: _resendFpOtp,
      );

  Widget _otpScaffold({
    required String destination,
    required TextEditingController codeCtrl,
    required FocusNode focus,
    required OtpShakeController shaker,
    required bool hasError,
    required ValueListenable<int> seconds,
    required VoidCallback onBack,
    required Future<void> Function() onSubmit,
    required Future<void> Function() onResend,
  }) {
    return OtpScreen(
      onBack: onBack,
      destination: destination,
      otpBoxes: AuthOtpBoxes(
          length: _kOtpLength,
          codeController: codeCtrl,
          firstBoxFocus: focus,
          shaker: shaker,
          hasError: hasError,
          enabled: !_loading,
          onChanged: (_) {
            if (hasError) {
              setState(() {
                if (identical(codeCtrl, _otpCtrl)) {
                  _otpHasError = false;
                } else {
                  _fpOtpHasError = false;
                }
              });
            }
          },
          onCompleted: (_) => onSubmit(),
        ),
      resend: ValueListenableBuilder<int>(
        valueListenable: seconds,
        builder: (context, value, _) =>
            _resendRow(seconds: value, onResend: onResend),
      ),
      verifyButton: ValueListenableBuilder<TextEditingValue>(
        valueListenable: codeCtrl,
        builder: (context, value, _) => AuthPrimaryButton(
          label: AuthStrings.verifyButton,
          loading: _loading,
          enabled: value.text.trim().length == _kOtpLength,
          onPressed: onSubmit,
        ),
      ),
    );
  }

  Widget _resendRow({
    required int seconds,
    required Future<void> Function() onResend,
  }) {
    if (seconds <= 0) {
      return AuthTextLink(
        label: AuthStrings.resendAction,
        onTap: _loading ? null : () => onResend(),
        style: AuthTokens.helper.copyWith(fontWeight: FontWeight.w500),
      );
    }
    final String mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final String ss = (seconds % 60).toString().padLeft(2, '0');
    // ── بێ بازدانی لەیئاوت ───────────────────────────────────────────────
    // ⚠ ژمێرەرەکە و دوگمەی دووبارەناردنەوە دوو شتی جیاوازن بە دوو پانی
    // جیاواز، بۆیە لە چرکەی سفردا ڕیزەکە پانییەکەی دەگۆڕا و ئەوەی
    // ژێری هەڵدەبەزی. `SizedBox(height:)` بەرزاییەکە دەبەستێتەوە، و
    // `Center` هەردووکیان لە یەک خاڵدا ناوەڕاست دەکات.
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: '${AuthStrings.resendIn} '),
        TextSpan(
          text: '$mm:$ss',
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: AuthTokens.ink,
          ),
        ),
      ]),
      style: AuthTokens.helper,
    );
  }

  // ── Forgot-password views ─────────────────────────────────────────────────

  Widget _buildForgotEmailView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthHeader.inner(onBack: _goToSignIn),
        const SizedBox(height: 24),
        Text(AuthStrings.resetPasswordTitle, style: _kTitle),
        const SizedBox(height: 4),
        Text(AuthStrings.resetPasswordSubtitle, style: _kSub),
        const SizedBox(height: 16),
        AuthTextField(
          controller: _fpEmailCtrl,
          focusNode: _fpEmailFocus,
          label: AuthStrings.emailLabel,
          hint: AuthStrings.emailHint,
          icon: Icons.mail_outline_rounded,
          error: _fpEmailErr,
          ltr: true,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          enabled: !_loading,
          onChanged: (_) {
            if (_fpEmailErr != null) setState(() => _fpEmailErr = null);
          },
          onSubmitted: (_) => _doForgotSendOtp(),
          trailing: AuthClearButton(
            controller: _fpEmailCtrl,
            focusNode: _fpEmailFocus,
            onCleared: () {
              if (_fpEmailErr != null) setState(() => _fpEmailErr = null);
            },
          ),
        ),
        EmailDomainChips(
          controller: _fpEmailCtrl,
          focusNode: _fpEmailFocus,
        ),
        const SizedBox(height: 18),
        ListenableBuilder(
          listenable: _fpEmailCtrl,
          builder: (context, _) => AuthPrimaryButton(
            label: AuthStrings.resendAction,
            loading: _loading,
            enabled: AuthValidators.email(_fpEmailCtrl.text) == null,
            onPressed: _doForgotSendOtp,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildForgotNewPassView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthHeader.inner(
            onBack: () => setState(() => _step = _Step.forgotOtp)),
        const SizedBox(height: 24),
        Text(AuthStrings.resetPasswordTitle, style: _kTitle),
        const SizedBox(height: 4),
        Text(AuthStrings.resetPasswordSubtitle, style: _kSub),

        const SizedBox(height: 16),
        ValueListenableBuilder<bool>(
          valueListenable: _resetPasswordVisible,
          builder: (context, visible, _) => AuthTextField(
          controller: _fpNewPassCtrl,
          forceLtr: true,
          label: AuthStrings.passwordLabel,
          hint: AuthStrings.passwordHint,
          icon: Icons.lock_outline_rounded,
          error: _fpNewPassErr,
          obscure: !visible,
          ltr: true,
          textInputAction: TextInputAction.next,
          enabled: !_loading,
          onChanged: (_) {
            if (_fpNewPassErr != null) setState(() => _fpNewPassErr = null);
          },
          trailing: _visibilityToggle(
            shown: visible,
            onTap: () => _resetPasswordVisible.value = !visible,
          ),
          ),
        ),

        const SizedBox(height: 10),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _fpNewPassCtrl,
          builder: (context, value, _) =>
              PasswordStrengthMeter(password: value.text),
        ),

        const SizedBox(height: 10),
        ListenableBuilder(
          listenable: Listenable.merge([_fpNewPassCtrl, _fpConfirmPassCtrl]),
          builder: (context, _) => ValueListenableBuilder<bool>(
            valueListenable: _resetConfirmationVisible,
            builder: (context, visible, __) => AuthTextField(
            controller: _fpConfirmPassCtrl,
            forceLtr: true,
            label: AuthStrings.confirmPasswordLabel,
            hint: AuthStrings.passwordHint,
            icon: Icons.lock_reset_rounded,
            error: _fpConfirmPassErr ??
                (_confirmMismatch(_fpNewPassCtrl.text, _fpConfirmPassCtrl.text)
                    ? AuthStrings.errPasswordMismatch
                    : null),
            obscure: !visible,
            ltr: true,
            textInputAction: TextInputAction.done,
            enabled: !_loading,
            onChanged: (_) {
              if (_fpConfirmPassErr != null) {
                setState(() => _fpConfirmPassErr = null);
              }
            },
            onSubmitted: (_) => _doForgotSetPassword(),
            trailing: _visibilityToggle(
              shown: visible,
              onTap: () => _resetConfirmationVisible.value = !visible,
            ),
            ),
          ),
        ),

        const SizedBox(height: 18),
        AuthPrimaryButton(
          label: AuthStrings.savePasswordButton,
          loading: _loading,
          onPressed: _doForgotSetPassword,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Small shared pieces ───────────────────────────────────────────────────

  Widget _visibilityToggle({
    required bool shown,
    required VoidCallback onTap,
  }) {
    return IconButton(
      onPressed: onTap,
      splashRadius: 18,
      icon: Icon(
        shown ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        size: 19,
        color: AuthTokens.placeholder,
      ),
    );
  }

  Widget _promptRow({
    required String lead,
    required String action,
    required VoidCallback? onTap,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(lead, style: _kSub.copyWith(fontSize: AuthTokens.textSize)),
        const SizedBox(width: 4),
        AuthTextLink(
          label: action,
          onTap: onTap,
          style: const TextStyle(
            fontFamily: kAppFont,
            fontSize: AuthTokens.textSize,
            fontWeight: FontWeight.w500,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }
}
