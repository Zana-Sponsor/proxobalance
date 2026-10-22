import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/backend_config.dart';
import 'auth_models.dart';

typedef PhoneLoginExchange = ({String? refreshToken, String? error});
typedef PhoneSignupExchange = ({String? tokenHash, String? error});

/// Central boundary for authentication network and Supabase calls.
///
/// The three Auth screens never call HTTP, Edge Functions, or RPCs directly;
/// [AuthShell] coordinates UI state and delegates the backend work here.
final class AuthService {
  AuthService({
    required SupabaseClient supabase,
    required String emailOtpUrl,
    required String whatsappOtpUrl,
    http.Client? httpClient,
    BackendConfig? backendConfig,
  })  : _supabase = supabase,
        _emailOtpUrl = emailOtpUrl,
        _whatsappOtpUrl = whatsappOtpUrl,
        _http = httpClient ?? http.Client(),
        _backend = backendConfig ?? BackendConfig.current;

  final SupabaseClient _supabase;
  final String _emailOtpUrl;
  final String _whatsappOtpUrl;
  final http.Client _http;
  final BackendConfig _backend;

  String? lastOtpError;
  int? lastOtpStatus;
  ({String email, String password, String userId})? _createdEmailSignup;
  ({
    String email,
    String userId,
    String code,
    String password,
    bool confirmed
  })? _verifiedEmailSignup;

  /// Supabase stores the identity; the configured application API sends OTPs.
  /// Keep a pending identity in memory so retrying a failed send does not try
  /// to register the same email again. No pending credentials are persisted.
  Future<String> beginEmailSignup({
    required String email,
    required String password,
    required String name,
  }) async {
    // Block before signup can create an identity or trigger Auth email.
    _backend.requireProductionTransport();
    final normalizedEmail = email.trim().toLowerCase();
    var pending = _createdEmailSignup;
    if (pending == null ||
        pending.email != normalizedEmail ||
        pending.password != password) {
      final response = await _supabase.auth.signUp(
        email: normalizedEmail,
        password: password,
        data: {'full_name': name.trim(), 'signup_channel': 'email'},
      );
      final userId = response.user?.id;
      if (userId == null || userId.isEmpty) {
        throw const AuthException('signup_failed');
      }
      pending = (email: normalizedEmail, password: password, userId: userId);
      _createdEmailSignup = pending;
      _verifiedEmailSignup = null;
    }
    // The existing custom-mail setup may auto-confirm the Auth identity.
    // Discard its provisional session before showing our separate OTP screen.
    if (_supabase.auth.currentSession != null) {
      await _supabase.auth.signOut(scope: SignOutScope.local);
    }
    final sent = await requestEmailOtp(
      email: normalizedEmail,
      userId: pending.userId,
      name: name.trim(),
      purpose: 'signup',
    );
    if (!sent) throw const AuthException('otp_send_failed');
    _verifiedEmailSignup = null;
    return pending.userId;
  }

  Future<AuthResponse> verifyEmailSignup({
    required String email,
    required String code,
    required String userId,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedCode = code.trim();
    var verified = _verifiedEmailSignup;
    if (verified == null ||
        verified.email != normalizedEmail ||
        verified.userId != userId ||
        verified.code != normalizedCode ||
        verified.password != password) {
      final dynamic proof = await _supabase.rpc(
        'pa_verify_login_otp',
        params: {'p_email': normalizedEmail, 'p_code': normalizedCode},
      );
      if (proof is! Map || proof['valid'] != true) {
        throw const AuthException('Invalid or expired code',
            code: 'otp_expired');
      }
      verified = (
        email: normalizedEmail,
        userId: userId,
        code: normalizedCode,
        password: password,
        confirmed: false,
      );
      _verifiedEmailSignup = verified;
    }
    // This existing server function consumes fresh OTP proof bound to both
    // the user ID and email. Never swallow its failure or sign in before it.
    if (!verified.confirmed) {
      await _supabase.rpc(
        'proxo_confirm_email',
        params: {'p_user_id': userId},
      );
      // Retrying a failed sign-in must not replay the consumed OTP. A failed
      // confirmation response never sets this flag; resend supplies new proof
      // if the server consumed the old proof but its response was lost.
      _verifiedEmailSignup = (
        email: normalizedEmail,
        userId: userId,
        code: normalizedCode,
        password: password,
        confirmed: true,
      );
    }
    final response = await _supabase.auth.signInWithPassword(
      email: normalizedEmail,
      password: password,
    );
    if (response.session == null || response.user?.id != userId) {
      await _supabase.auth.signOut(scope: SignOutScope.local);
      throw const AuthException('signup_session_failed');
    }
    _createdEmailSignup = null;
    _verifiedEmailSignup = null;
    return response;
  }

  Future<bool> resendEmailSignup({
    required String email,
    required String userId,
    required String name,
  }) async {
    final sent = await requestEmailOtp(
      email: email.trim().toLowerCase(),
      userId: userId,
      name: name.trim(),
      purpose: 'signup',
    );
    if (sent) _verifiedEmailSignup = null;
    return sent;
  }

  Future<bool> requestEmailOtp({
    required String email,
    required String userId,
    required String name,
    required String purpose,
  }) async {
    _resetLastRequest();
    try {
      _backend.requireProductionTransport();
      final http.Response response = await _http
          .post(
            Uri.parse(_emailOtpUrl),
            headers: const <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(<String, String>{
              'action': 'request_otp',
              'purpose': purpose,
              'email': email,
              'name': name,
              'user_id': userId,
            }),
          )
          .timeout(const Duration(seconds: 15));
      lastOtpStatus = response.statusCode;
      if (_isSuccess(response.statusCode)) {
        final dynamic body = _asMap(response.body);
        if (body is! Map || (body['success'] != false && body['ok'] != false)) {
          return true;
        }
        lastOtpError = 'otp_send_rejected';
        return false;
      }
      lastOtpError = 'HTTP ${response.statusCode}';
      return false;
    } catch (error) {
      lastOtpError = error.toString();
      return false;
    }
  }

  Future<bool> sendLoginEmailOtp(String email) async {
    _resetLastRequest();
    try {
      _backend.requireProductionTransport();
      final http.Response response = await _http
          .post(
            Uri.parse(_emailOtpUrl),
            headers: const <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(<String, String>{'email': email}),
          )
          .timeout(const Duration(seconds: 15));
      lastOtpStatus = response.statusCode;
      return _isSuccess(response.statusCode);
    } catch (error) {
      lastOtpError = error.toString();
      return false;
    }
  }

  Future<bool> verifyLoginEmailOtp({
    required String email,
    required String code,
  }) async {
    try {
      final dynamic response = await _supabase.rpc(
        'pa_verify_login_otp',
        params: <String, String>{
          'p_email': email.trim().toLowerCase(),
          'p_code': code.trim(),
        },
      );
      return response is Map && response['valid'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool?> phoneExists(String phone) async {
    try {
      final dynamic result = await _supabase.rpc(
        'pa_phone_exists',
        params: <String, String>{'p_phone': IraqPhone.normalize(phone)},
      );
      return result == true;
    } catch (_) {
      return null;
    }
  }

  Future<bool> requestWhatsappOtp({
    required String phone,
    required AuthOtpPurpose purpose,
    required String locale,
  }) async {
    try {
      _backend.requireProductionTransport();
      final http.Response response = await _http
          .post(
            Uri.parse(_whatsappOtpUrl),
            headers: const <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(<String, String>{
              'phone': IraqPhone.normalize(phone),
              'purpose': switch (purpose) {
                AuthOtpPurpose.login => 'login',
                AuthOtpPurpose.signup => 'signup',
                AuthOtpPurpose.passwordReset => 'reset_password',
              },
              'clientMessageId':
                  'proxo-${DateTime.now().millisecondsSinceEpoch}',
              'locale': locale,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (!_isSuccess(response.statusCode)) return false;
      final dynamic body = jsonDecode(response.body);
      return body is Map && body['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<PhoneLoginExchange> exchangePhoneOtp({
    required String phone,
    required String code,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'whatsapp-session-exchange',
        body: <String, String>{
          'phone': IraqPhone.normalize(phone),
          'code': code.trim(),
        },
      );
      final dynamic data = _asMap(response.data);
      if (data is Map && data['ok'] == true) {
        final String refreshToken = (data['refresh_token'] ?? '').toString();
        if (refreshToken.isNotEmpty) {
          return (refreshToken: refreshToken, error: null);
        }
        return (refreshToken: null, error: 'session_failed');
      }
      return (refreshToken: null, error: _errorCode(data));
    } on FunctionException catch (error) {
      return (
        refreshToken: null,
        error: _errorCode(_asMap(error.details)),
      );
    } catch (_) {
      return (refreshToken: null, error: 'network');
    }
  }

  Future<PhoneSignupExchange> completePhoneSignup({
    required String phone,
    required String code,
    required String fullName,
    required String password,
    bool whatsappMarketing = false,
    String locale = 'ckb',
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'phone-otp-session',
        body: <String, dynamic>{
          'phone': IraqPhone.normalize(phone),
          'code': code.trim(),
          'full_name': fullName.trim(),
          'password': password,
          'whatsapp_marketing_opt_in': whatsappMarketing,
          'whatsapp_consent_version': 'whatsapp-marketing-v1',
          'whatsapp_consent_locale': locale,
        },
      );
      final dynamic data = _asMap(response.data);
      if (data is Map && data['ok'] == true) {
        final String tokenHash = (data['token_hash'] ?? '').toString();
        if (tokenHash.isNotEmpty) {
          return (tokenHash: tokenHash, error: null);
        }
      }
      return (tokenHash: null, error: _errorCode(data));
    } on FunctionException catch (error) {
      return (tokenHash: null, error: _errorCode(_asMap(error.details)));
    } catch (_) {
      return (tokenHash: null, error: 'network');
    }
  }

  void close() {
    _createdEmailSignup = null;
    _verifiedEmailSignup = null;
    _http.close();
  }

  void _resetLastRequest() {
    lastOtpError = null;
    lastOtpStatus = null;
  }

  static bool _isSuccess(int statusCode) =>
      statusCode >= 200 && statusCode < 300;

  static dynamic _asMap(dynamic raw) {
    if (raw is Map) return raw;
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final dynamic parsed = jsonDecode(raw);
        if (parsed is Map) return parsed;
      } catch (_) {}
    }
    return null;
  }

  static String _errorCode(dynamic data) {
    if (data is Map) {
      final dynamic error = data['error'];
      if (error != null && error.toString().isNotEmpty) {
        return error.toString();
      }
    }
    return 'server_error';
  }
}
