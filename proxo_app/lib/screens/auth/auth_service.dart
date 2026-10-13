import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

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
  })  : _supabase = supabase,
        _emailOtpUrl = emailOtpUrl,
        _whatsappOtpUrl = whatsappOtpUrl,
        _http = httpClient ?? http.Client();

  final SupabaseClient _supabase;
  final String _emailOtpUrl;
  final String _whatsappOtpUrl;
  final http.Client _http;

  String? lastOtpError;
  int? lastOtpStatus;

  Future<bool> requestEmailOtp({
    required String email,
    required String userId,
    required String name,
    required String purpose,
  }) async {
    _resetLastRequest();
    try {
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
      if (_isSuccess(response.statusCode)) return true;
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
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'phone-otp-session',
        body: <String, String>{
          'phone': IraqPhone.normalize(phone),
          'code': code.trim(),
          'full_name': fullName.trim(),
          'password': password,
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

  void close() => _http.close();

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
