import 'support/memory_auth_storage.dart';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:proxo_app/screens/auth/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const userId = '11111111-1111-4111-8111-111111111111';
  const password = 'Example#2026';
  const apiUrl = 'https://email-api-fixture.invalid/webhook/send_otp';
  final requests = <http.Request>[];
  late SupabaseClient client;
  late AuthService service;
  var autoConfirm = false;
  var rejectOtp = false;
  var rejectConfirmation = false;
  var loseConfirmationResponse = false;
  var failSignIn = false;
  var proofUsed = false;
  var confirmationConsumed = false;
  final registeredEmails = <String>{};
  var deliveryStatus = 200;
  var deliverySuccess = true;
  final user = <String, dynamic>{
    'id': userId,
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
            'sub': userId,
            'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600
          })}.fixture',
      'refresh_token': 'fixture-refresh',
      'token_type': 'bearer',
      'expires_in': 3600,
      'user': user,
    };
  }

  List<String> paths() => requests.map((r) => r.url.path).toList();
  Map<String, dynamic> bodyOf(http.Request request) =>
      jsonDecode(request.body) as Map<String, dynamic>;
  Map<String, String> otpBody({String name = 'Person Name'}) => {
        'action': 'request_otp',
        'purpose': 'signup',
        'email': 'person@example.com',
        'name': name,
        'user_id': userId,
      };
  Future<String> begin() => service.beginEmailSignup(
      email: ' Person@Example.com ', password: password, name: ' Person Name ');
  Future<AuthResponse> verify() => service.verifyEmailSignup(
      email: ' Person@Example.com ',
      code: ' 123456 ',
      userId: userId,
      password: password);

  setUp(() {
    requests.clear();
    autoConfirm = false;
    rejectOtp = false;
    rejectConfirmation = false;
    loseConfirmationResponse = false;
    failSignIn = false;
    proofUsed = false;
    confirmationConsumed = false;
    registeredEmails.clear();
    deliveryStatus = 200;
    deliverySuccess = true;
    final transport = MockClient((request) async {
      requests.add(request);
      expect(request.method, 'POST');
      Object? body;
      var status = 200;
      if (request.url.host == 'email-api-fixture.invalid') {
        expect(request.url.toString(), apiUrl);
        expect(request.headers['content-type'], 'application/json');
        expect(bodyOf(request)['action'], 'request_otp');
        expect(bodyOf(request)['purpose'], 'signup');
        // An auto-confirmed identity must not remain signed in while the
        // separate custom email verification flow is still pending.
        expect(client.auth.currentSession, isNull);
        status = deliveryStatus;
        if (deliveryStatus >= 200 && deliveryStatus < 300 && deliverySuccess) {
          proofUsed = false;
          confirmationConsumed = false;
        }
        body = {
          'success': deliverySuccess,
          if (!deliverySuccess) 'error': 'delivery_rejected',
        };
      } else {
        expect(request.url.host, 'email-signup-fixture.invalid');
        switch (request.url.path) {
          case '/auth/v1/signup':
            if (!registeredEmails.add(bodyOf(request)['email'] as String)) {
              status = 422;
              body = {
                'code': 'user_already_exists',
                'msg': 'User already registered',
              };
            } else {
              body = autoConfirm ? session() : user;
            }
          case '/auth/v1/logout':
            body = {};
          case '/rest/v1/rpc/pa_verify_login_otp':
            final valid = !rejectOtp && !proofUsed;
            if (valid) proofUsed = true;
            body = {'valid': valid, if (valid) 'otp_id': 'otp-proof'};
          case '/rest/v1/rpc/proxo_confirm_email':
            final rejected = rejectConfirmation || confirmationConsumed;
            status = rejected ? 403 : 200;
            body =
                rejected ? {'code': '42501', 'message': 'otp_required'} : null;
            if (!rejected) {
              confirmationConsumed = true;
              if (loseConfirmationResponse) {
                throw http.ClientException('confirmation response lost');
              }
            }
          case '/auth/v1/token':
            expect(request.url.queryParameters['grant_type'], 'password');
            if (failSignIn) throw http.ClientException('sign-in unavailable');
            body = session();
          default:
            throw StateError('Unexpected fixture route: ${request.url.path}');
        }
      }
      return http.Response(jsonEncode(body), status,
          headers: {
            'content-type': 'application/json',
            'x-supabase-api-version': '2024-01-01',
          },
          request: request);
    });
    client = SupabaseClient(
        'https://email-signup-fixture.invalid', 'fixture-key',
        httpClient: transport,
        authOptions: AuthClientOptions(
            autoRefreshToken: false, pkceAsyncStorage: MemoryAuthStorage()));
    service = AuthService(
        supabase: client,
        emailOtpUrl: apiUrl,
        whatsappOtpUrl: 'https://unused-whatsapp.invalid',
        httpClient: transport);
  });
  tearDown(() async {
    service.close();
    await client.dispose();
  });

  test(
      'signup creates identity then sends the existing custom email API payload',
      () async {
    expect(await begin(), userId);
    expect(paths(), ['/auth/v1/signup', '/webhook/send_otp']);
    final signup = bodyOf(requests.first);
    expect(signup['email'], 'person@example.com');
    expect(signup['password'], password);
    expect(signup['data'],
        {'full_name': 'Person Name', 'signup_channel': 'email'});
    expect(bodyOf(requests.last), otpBody());
    expect(client.auth.currentSession, isNull);
  });

  test('auto-confirmed identity signs out before custom OTP delivery',
      () async {
    autoConfirm = true;
    expect(await begin(), userId);
    expect(
        paths(), ['/auth/v1/signup', '/auth/v1/logout', '/webhook/send_otp']);
    expect(requests[1].url.queryParameters['scope'], 'local');
    expect(bodyOf(requests.last), otpBody());
    expect(client.auth.currentSession, isNull);
  });

  for (final failure in [429, 200]) {
    test('custom delivery rejection at HTTP $failure cannot finish signup',
        () async {
      deliveryStatus = failure;
      deliverySuccess = false;
      await expectLater(begin(), throwsA(isA<AuthException>()));
      expect(paths(), ['/auth/v1/signup', '/webhook/send_otp']);
      expect(service.lastOtpStatus, failure);
      expect(service.lastOtpError, isNotNull);
      expect(client.auth.currentSession, isNull);
    });
  }

  test('retry after delivery failure reuses the created identity', () async {
    autoConfirm = true;
    deliverySuccess = false;
    await expectLater(begin(), throwsA(isA<AuthException>()));
    deliverySuccess = true;
    expect(await begin(), userId);
    expect(paths(), [
      '/auth/v1/signup',
      '/auth/v1/logout',
      '/webhook/send_otp',
      '/webhook/send_otp',
    ]);
    expect(bodyOf(requests[2]), otpBody());
    expect(bodyOf(requests[3]), otpBody());
    expect(client.auth.currentSession, isNull);
  });

  test(
      'changed password surfaces duplicate signup instead of using the old password',
      () async {
    deliverySuccess = false;
    await expectLater(begin(), throwsA(isA<AuthException>()));
    deliverySuccess = true;
    await expectLater(
        service.beginEmailSignup(
            email: 'person@example.com',
            password: 'Different#2026',
            name: 'Person Name'),
        throwsA(isA<AuthException>()
            .having((e) => e.code, 'code', 'user_already_exists')));
    expect(paths(), [
      '/auth/v1/signup',
      '/webhook/send_otp',
      '/auth/v1/signup',
    ]);
    expect(bodyOf(requests[2])['password'], 'Different#2026');
    expect(client.auth.currentSession, isNull);
  });

  test(
      'delivery retry with an edited name does not rewrite created identity metadata',
      () async {
    deliverySuccess = false;
    await expectLater(begin(), throwsA(isA<AuthException>()));
    deliverySuccess = true;
    expect(
        await service.beginEmailSignup(
            email: 'person@example.com',
            password: password,
            name: 'Edited Name'),
        userId);
    expect(
        paths(), ['/auth/v1/signup', '/webhook/send_otp', '/webhook/send_otp']);
    expect(bodyOf(requests.first)['data']['full_name'], 'Person Name');
    expect(bodyOf(requests.last), otpBody(name: 'Edited Name'));
  });

  test('invalid custom OTP never confirms the email or opens a session',
      () async {
    rejectOtp = true;
    await expectLater(verify(), throwsA(isA<AuthException>()));
    expect(paths(), ['/rest/v1/rpc/pa_verify_login_otp']);
    expect(bodyOf(requests.single),
        {'p_email': 'person@example.com', 'p_code': '123456'});
    expect(client.auth.currentSession, isNull);
  });

  test('confirmation failure cannot fall through to password sign-in',
      () async {
    rejectConfirmation = true;
    await expectLater(verify(),
        throwsA(anyOf(isA<AuthException>(), isA<PostgrestException>())));
    expect(paths(), [
      '/rest/v1/rpc/pa_verify_login_otp',
      '/rest/v1/rpc/proxo_confirm_email',
    ]);
    expect(bodyOf(requests.last), {'p_user_id': userId});
    expect(client.auth.currentSession, isNull);
  });

  test(
      'custom verification and confirmation precede the final password session',
      () async {
    final response = await verify();
    expect(paths(), [
      '/rest/v1/rpc/pa_verify_login_otp',
      '/rest/v1/rpc/proxo_confirm_email',
      '/auth/v1/token',
    ]);
    expect(bodyOf(requests[0]),
        {'p_email': 'person@example.com', 'p_code': '123456'});
    expect(bodyOf(requests[1]), {'p_user_id': userId});
    expect(bodyOf(requests[2])['email'], 'person@example.com');
    expect(bodyOf(requests[2])['password'], password);
    expect(response.user?.id, userId);
    expect(response.session, isNotNull);
    expect(client.auth.currentUser?.id, userId);
  });

  test(
      'retry after rejected confirmation reuses proof but retries confirmation',
      () async {
    rejectConfirmation = true;
    await expectLater(verify(), throwsA(isA<PostgrestException>()));
    rejectConfirmation = false;
    final response = await verify();
    expect(paths(), [
      '/rest/v1/rpc/pa_verify_login_otp',
      '/rest/v1/rpc/proxo_confirm_email',
      '/rest/v1/rpc/proxo_confirm_email',
      '/auth/v1/token',
    ]);
    expect(response.session, isNotNull);
  });

  test(
      'lost confirmation response needs fresh OTP when proof was already consumed',
      () async {
    loseConfirmationResponse = true;
    await expectLater(verify(), throwsA(isA<http.ClientException>()));
    expect(client.auth.currentSession, isNull);
    loseConfirmationResponse = false;
    await expectLater(verify(), throwsA(isA<PostgrestException>()));
    expect(paths(), [
      '/rest/v1/rpc/pa_verify_login_otp',
      '/rest/v1/rpc/proxo_confirm_email',
      '/rest/v1/rpc/proxo_confirm_email',
    ]);
    expect(client.auth.currentSession, isNull);

    expect(
        await service.resendEmailSignup(
            email: 'person@example.com', userId: userId, name: 'Person Name'),
        isTrue);
    final response = await service.verifyEmailSignup(
        email: 'person@example.com',
        code: '654321',
        userId: userId,
        password: password);
    expect(paths().skip(3), [
      '/webhook/send_otp',
      '/rest/v1/rpc/pa_verify_login_otp',
      '/rest/v1/rpc/proxo_confirm_email',
      '/auth/v1/token',
    ]);
    expect(bodyOf(requests[4])['p_code'], '654321');
    expect(response.session, isNotNull);
  });

  test(
      'retry after a sign-in network failure does not replay consumed OTP proof',
      () async {
    failSignIn = true;
    await expectLater(verify(), throwsA(isA<AuthException>()));
    expect(client.auth.currentSession, isNull);
    failSignIn = false;
    final response = await verify();
    expect(paths(), [
      '/rest/v1/rpc/pa_verify_login_otp',
      '/rest/v1/rpc/proxo_confirm_email',
      '/auth/v1/token',
      '/auth/v1/token',
    ]);
    expect(response.session, isNotNull);
  });

  test('successful resend clears the cached confirmation stage', () async {
    failSignIn = true;
    await expectLater(verify(), throwsA(isA<AuthException>()));
    expect(
        await service.resendEmailSignup(
            email: 'person@example.com', userId: userId, name: 'Person Name'),
        isTrue);
    failSignIn = false;
    final response = await verify();
    expect(paths(), [
      '/rest/v1/rpc/pa_verify_login_otp',
      '/rest/v1/rpc/proxo_confirm_email',
      '/auth/v1/token',
      '/webhook/send_otp',
      '/rest/v1/rpc/pa_verify_login_otp',
      '/rest/v1/rpc/proxo_confirm_email',
      '/auth/v1/token',
    ]);
    expect(response.session, isNotNull);
  });

  for (final changed in ['email', 'userId', 'code', 'password']) {
    test(
        'cached signup verification cannot be reused with a different $changed',
        () async {
      failSignIn = true;
      await expectLater(verify(), throwsA(isA<AuthException>()));
      requests.clear();
      rejectOtp = true;
      await expectLater(
          service.verifyEmailSignup(
              email: changed == 'email'
                  ? 'other@example.com'
                  : 'person@example.com',
              userId: changed == 'userId'
                  ? '22222222-2222-4222-8222-222222222222'
                  : userId,
              code: changed == 'code' ? '654321' : '123456',
              password: changed == 'password' ? 'Different#2026' : password),
          throwsA(isA<AuthException>()));
      expect(paths(), ['/rest/v1/rpc/pa_verify_login_otp']);
      expect(client.auth.currentSession, isNull);
    });
  }

  test('resend only calls the configured custom email API with signup context',
      () async {
    expect(
        await service.resendEmailSignup(
            email: ' Person@Example.com ',
            userId: userId,
            name: ' Person Name '),
        isTrue);
    expect(paths(), ['/webhook/send_otp']);
    expect(bodyOf(requests.single), otpBody());
    expect(client.auth.currentSession, isNull);
  });

  for (final failure in [429, 200]) {
    test('custom resend rejects HTTP $failure delivery failure', () async {
      deliveryStatus = failure;
      deliverySuccess = false;
      expect(
          await service.resendEmailSignup(
              email: 'person@example.com', userId: userId, name: 'Person Name'),
          isFalse);
      expect(paths(), ['/webhook/send_otp']);
      expect(service.lastOtpStatus, failure);
      expect(service.lastOtpError, isNotNull);
      expect(client.auth.currentSession, isNull);
    });
  }
}
