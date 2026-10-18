import 'support/memory_auth_storage.dart';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:proxo_app/screens/auth/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final requests = <http.Request>[];
  late SupabaseClient client;
  late AuthService service;
  var autoConfirm = false;
  var rejectOtp = false;
  var rejectResend = false;
  final user = <String, dynamic>{
    'id': '11111111-1111-4111-8111-111111111111',
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': 'person@example.com',
    'app_metadata': {},
    'user_metadata': {},
    'created_at': '2026-10-18T12:00:00Z',
  };
  Map<String, dynamic> session() {
    String part(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    return {
      'access_token': '${part({'alg': 'HS256'})}.${part({
            'sub': user['id'],
            'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600
          })}.fixture',
      'refresh_token': 'fixture-refresh',
      'token_type': 'bearer',
      'expires_in': 3600,
      'user': user,
    };
  }

  setUp(() {
    requests.clear();
    autoConfirm = false;
    rejectOtp = false;
    rejectResend = false;
    final transport = MockClient((request) async {
      expect(request.url.host, 'email-signup-fixture.invalid');
      requests.add(request);
      Object body;
      var status = 200;
      switch (request.url.path) {
        case '/auth/v1/signup':
          body = autoConfirm ? session() : user;
        case '/auth/v1/verify':
          body = rejectOtp
              ? {
                  'code': 'otp_expired',
                  'msg': 'Token has expired or is invalid'
                }
              : session();
          status = rejectOtp ? 403 : 200;
        case '/auth/v1/resend':
          body = rejectResend
              ? {
                  'code': 'over_email_send_rate_limit',
                  'msg': 'Too many requests'
                }
              : {};
          status = rejectResend ? 429 : 200;
        case '/auth/v1/logout':
          body = {};
        default:
          throw StateError('Unexpected fixture request: ${request.url.path}');
      }
      return http.Response(jsonEncode(body), status,
          headers: {'content-type': 'application/json'});
    });
    client = SupabaseClient(
        'https://email-signup-fixture.invalid', 'fixture-key',
        httpClient: transport,
        authOptions: AuthClientOptions(
            autoRefreshToken: false, pkceAsyncStorage: MemoryAuthStorage()));
    service = AuthService(
        supabase: client,
        emailOtpUrl: 'https://unused.invalid',
        whatsappOtpUrl: 'https://unused.invalid',
        httpClient: transport);
  });
  tearDown(() async {
    service.close();
    await client.dispose();
  });

  test(
      'signup sends normalized email and profile name without a session or WhatsApp call',
      () async {
    await service.beginEmailSignup(
        email: ' Person@Example.com ',
        password: 'Example#2026',
        name: ' Person Name ');
    expect(requests, hasLength(1));
    final body = jsonDecode(requests.single.body) as Map;
    expect(body['email'], 'person@example.com');
    expect(body['password'], 'Example#2026');
    expect(
        body['data'], {'full_name': 'Person Name', 'signup_channel': 'email'});
    expect(client.auth.currentSession, isNull);
  });
  test('invalid signup OTP cannot create a session', () async {
    rejectOtp = true;
    await expectLater(
        service.verifyEmailSignup(email: 'person@example.com', code: '000000'),
        throwsA(isA<AuthException>()));
    expect(client.auth.currentSession, isNull);
  });
  test(
      'valid signup OTP is bound to email and signup purpose and creates a session',
      () async {
    final response = await service.verifyEmailSignup(
        email: ' Person@Example.com ', code: ' 123456 ');
    final body = jsonDecode(requests.single.body) as Map;
    expect(body['email'], 'person@example.com');
    expect(body['token'], '123456');
    expect(body['type'], 'signup');
    expect(response.session, isNotNull);
    expect(client.auth.currentUser!.id, user['id']);
  });
  test('resend targets signup confirmation and reports rate limiting',
      () async {
    expect(await service.resendEmailSignup(' Person@Example.com '), isTrue);
    final body = jsonDecode(requests.single.body) as Map;
    expect(body['email'], 'person@example.com');
    expect(body['type'], 'signup');
    rejectResend = true;
    expect(await service.resendEmailSignup('person@example.com'), isFalse);
    expect(service.lastOtpError, isNotNull);
    expect(client.auth.currentSession, isNull);
  });
  test('auto-confirm configuration cannot bypass the separate OTP flow',
      () async {
    autoConfirm = true;
    await expectLater(
        service.beginEmailSignup(
            email: 'person@example.com',
            password: 'Example#2026',
            name: 'Person Name'),
        throwsA(isA<AuthException>().having(
            (e) => e.message, 'message', 'email_confirmation_required')));
    expect(client.auth.currentSession, isNull);
    expect(requests.last.url.path, '/auth/v1/logout');
    expect(requests.last.url.queryParameters['scope'], 'local');
  });
}
