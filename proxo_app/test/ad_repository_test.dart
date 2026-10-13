import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:proxo_app/services/ad_submission.dart';
import 'ad_submission_test.dart' show validDraft;

const userId = '11111111-1111-4111-8111-111111111111';
const storageKey = 'proxo.pending-ad.v1.$userId';
http.Response jsonResponse(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json'});
MockClient mockTransport(
        Future<http.Response> Function(http.Request) handler) =>
    MockClient((req) async {
      final response = await handler(req);
      return http.Response.bytes(response.bodyBytes, response.statusCode,
          headers: response.headers, request: req);
    });

Future<SupabaseClient> signedClient(MockClient transport) async {
  String part(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final token = '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({
        'sub': userId,
        'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600
      })}.test-signature';
  final client = SupabaseClient('https://test.invalid', 'test-only-anon-key',
      httpClient: transport,
      authOptions: const AuthClientOptions(autoRefreshToken: false));
  await client.auth.recoverSession(jsonEncode(Session(
          accessToken: token,
          tokenType: 'bearer',
          user: const User(
              id: userId,
              appMetadata: {},
              userMetadata: {},
              aud: 'authenticated',
              createdAt: '2026-01-01T00:00:00Z'))
      .toJson()));
  return client;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  AdPendingSubmission request() => AdPendingSubmission.create(
      validDraft(), const AdQuote(grossUsd: 10, costUsd: 10, rate: 1800));
  ValueNotifier<AdPaymentProgress> progress() =>
      ValueNotifier(const AdPaymentProgress());

  test(
      'interrupted response retains frozen request and recovers without another charge',
      () async {
    var submissions = 0;
    var committed = false;
    final r = request();
    final transport = mockTransport((req) async {
      if (req.url.path.endsWith('/generate-ad-thumbnail')) {
        return jsonResponse({'ok': true});
      }
      if (req.url.path.endsWith('/pa_ad_submission_status')) {
        expect(jsonDecode(req.body)['p_submission_id'], r.id);
        return jsonResponse(committed
            ? {'ok': true, 'ad_id': 'saved-ad'}
            : {'ok': false, 'code': 'NOT_FOUND'});
      }
      expect(req.url.path, endsWith('/pa_submit_ad'));
      expect(req.method, 'POST');
      final stored =
          (await SharedPreferences.getInstance()).getString(storageKey)!;
      expect(AdPendingSubmission.fromJson(jsonDecode(stored)).id, r.id);
      final body = jsonDecode(req.body);
      expect(body['p_expected_price_iqd'], 18000);
      expect(body['p_ad']['video_code'], validDraft().code);
      submissions++;
      committed = true;
      throw http.ClientException('Response lost after server commit');
    });
    final client = await signedClient(transport);
    addTearDown(client.dispose);
    final repo = SupabaseAdCreationRepository(client);
    final p = progress();
    addTearDown(p.dispose);
    await expectLater(
        repo.submit(r, p),
        throwsA(isA<AdSubmissionFailure>()
            .having((e) => e.uncertain, 'uncertain', true)));
    final restored = (await SupabaseAdCreationRepository(client).pending())!;
    expect(restored.toJson(), r.toJson());
    expect(await repo.submit(restored, p), 'saved-ad');
    expect(submissions, 1);
    expect(await repo.pending(), isNull);
  });

  test(
      'definite insufficient-funds failure clears pending request without client wallet writes',
      () async {
    final paths = <String>[];
    final client = await signedClient(mockTransport((req) async {
      paths.add(req.url.path);
      return jsonResponse(req.url.path.endsWith('/pa_ad_submission_status')
          ? {'ok': false, 'code': 'NOT_FOUND'}
          : {'ok': false, 'code': 'INSUFFICIENT_FUNDS'});
    }));
    addTearDown(client.dispose);
    final repo = SupabaseAdCreationRepository(client);
    final p = progress();
    addTearDown(p.dispose);
    await expectLater(
        repo.submit(request(), p),
        throwsA(isA<AdSubmissionFailure>()
            .having((e) => e.code, 'code', 'INSUFFICIENT_FUNDS')));
    expect(await repo.pending(), isNull);
    expect(paths,
        ['/rest/v1/rpc/pa_ad_submission_status', '/rest/v1/rpc/pa_submit_ad']);
  });

  test(
      'simultaneous repeated calls share one operation; competing request is blocked',
      () async {
    final gate = Completer<http.Response>();
    final started = Completer<void>();
    var submissions = 0;
    final client = await signedClient(mockTransport((req) async {
      if (req.url.path.endsWith('/pa_ad_submission_status')) {
        return jsonResponse({'ok': false, 'code': 'NOT_FOUND'});
      }
      if (req.url.path.endsWith('/pa_submit_ad')) {
        submissions++;
        started.complete();
        return gate.future;
      }
      return jsonResponse({'ok': true}); // Thumbnail generation is independent.
    }));
    addTearDown(client.dispose);
    final repo = SupabaseAdCreationRepository(client),
        other = SupabaseAdCreationRepository(client);
    final p = progress();
    addTearDown(p.dispose);
    final r = request(), first = repo.submit(request(), p);
    await started.future;
    final saved = (await repo.pending())!;
    final repeated = other.submit(saved, p);
    await expectLater(
        repo.submit(r, p),
        throwsA(isA<AdSubmissionFailure>()
            .having((e) => e.code, 'code', 'IDEMPOTENCY_CONFLICT')));
    gate.complete(jsonResponse({'ok': true, 'ad_id': 'once'}));
    expect(await first, 'once');
    expect(await repeated, 'once');
    expect(submissions, 1);
  });

  test('a different persisted operation cannot be overwritten', () async {
    final r = request();
    SharedPreferences.setMockInitialValues(
        {storageKey: jsonEncode(r.toJson())});
    var requests = 0;
    final client = await signedClient(mockTransport((_) async {
      requests++;
      return jsonResponse({});
    }));
    addTearDown(client.dispose);
    final repo = SupabaseAdCreationRepository(client);
    final p = progress();
    addTearDown(p.dispose);
    await expectLater(
        repo.submit(request(), p), throwsA(isA<AdSubmissionFailure>()));
    expect((await repo.pending())!.id, r.id);
    expect(requests, 0);
  });
  test('unavailable status lookup retains an earlier request', () async {
    final r = request();
    SharedPreferences.setMockInitialValues(
        {storageKey: jsonEncode(r.toJson())});
    final client = await signedClient(mockTransport((req) async {
      expect(req.url.path, endsWith('/pa_ad_submission_status'));
      return jsonResponse({'ok': false, 'code': 'NOT_AUTHENTICATED'});
    }));
    addTearDown(client.dispose);
    final repo = SupabaseAdCreationRepository(client);
    final p = progress();
    addTearDown(p.dispose);
    await expectLater(
        repo.submit(r, p),
        throwsA(isA<AdSubmissionFailure>()
            .having((e) => e.uncertain, 'uncertain', true)));
    expect((await repo.pending())!.id, r.id);
  });

  test('expired future schedule revalidates before any submission call',
      () async {
    var submits = 0;
    final client = await signedClient(mockTransport((req) async {
      if (req.url.path.endsWith('/pa_submit_ad')) submits++;
      return jsonResponse({'ok': false, 'code': 'NOT_FOUND'});
    }));
    addTearDown(client.dispose);
    final repo = SupabaseAdCreationRepository(client);
    final p = progress();
    addTearDown(p.dispose);
    final r = AdPendingSubmission.create(
        AdDraft.fromJson({
          ...validDraft().toJson(),
          'start_date': '2000-01-01',
          'start_immediately': false
        }),
        request().quote);
    await expectLater(
        repo.submit(r, p),
        throwsA(isA<AdSubmissionFailure>()
            .having((e) => e.code, 'code', 'INVALID_SCHEDULE')));
    expect(submits, 0);
    expect(await repo.pending(), isNull);
  });
  test('paid FastPay credit is retained when final ad registration fails',
      () async {
    const paymentId = '22222222-2222-4222-8222-222222222222';
    final client = await signedClient(mockTransport((req) async {
      if (req.url.path.endsWith('/pa_ad_submission_status')) {
        return jsonResponse({'ok': false, 'code': 'NOT_FOUND'});
      }
      if (req.url.path.endsWith('/pa_transactions')) {
        return jsonResponse([
          {
            'id': paymentId,
            'status': 'approved',
            'gateway_status': 'PAID',
            'wallet_credited': true,
            'amount': 10
          }
        ]);
      }
      expect(req.url.path, endsWith('/pa_submit_ad'));
      expect(jsonDecode(req.body)['p_ad']['payment_transaction_id'], paymentId);
      return jsonResponse({'ok': false, 'code': 'PRICE_CHANGED'});
    }));
    addTearDown(client.dispose);
    final repo = SupabaseAdCreationRepository(client);
    final p = progress();
    addTearDown(p.dispose);
    final r = AdPendingSubmission.create(
        AdDraft.fromJson(
            {...validDraft().toJson(), 'payment_method': 'fastpay'}),
        request().quote);
    await expectLater(
        repo.submit(r, p),
        throwsA(isA<AdSubmissionFailure>()
            .having((e) => e.paymentCredited, 'paid funds stay in wallet', true)
            .having((e) => e.uncertain, 'definite result', false)));
    expect(await repo.pending(), isNull);
  });
}
