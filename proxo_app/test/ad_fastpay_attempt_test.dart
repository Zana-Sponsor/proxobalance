import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/config/backend_config.dart';
import 'package:proxo_app/services/ad_submission.dart';
import 'ad_repository_test.dart' show signedClient, mockTransport, jsonResponse;
import 'meta_ad_draft_test.dart' show metaDraft;
import 'tiktok_dm_draft_test.dart' show directDraft;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  AdPendingSubmission request({bool meta = false}) =>
      AdPendingSubmission.create(
          AdDraft.fromJson({
            ...(meta ? metaDraft() : directDraft()).toJson(),
            'payment_method': 'fastpay',
            'start_immediately': false,
            'start_date': '2000-01-01',
          }),
          const AdQuote(
              grossUsd: 30,
              costUsd: 29.99,
              rate: 1500,
              days: 3,
              metaContract: {'quote_id': 'frozen-quote'},
              tiktokContract: {'quote_id': 'frozen-quote'}));
  Map<String, Object?> attempt(AdPendingSubmission r,
          {String status = 'funded'}) =>
      {
        'ok': true,
        'attempt_id': 'bound-attempt',
        'order_id': 'server-order',
        'environment': 'sandbox',
        'currency': 'IQD',
        'amount_iqd': r.quote.totalIqd,
        'status': status,
        'result': status == 'funded' || status == 'compensated'
            ? {'ad_id': 'atomic-ad', 'compensated': status == 'compensated'}
            : null,
      };
  final staging = BackendConfig.fromValues(
      mode: 'staging',
      supabaseUrl: 'https://abcdefghijklmnopqrst.supabase.co',
      supabaseAnonKey: 'sb_publishable_test',
      publicBase: 'https://proxolink-staging.vercel.app');

  for (final meta in [false, true]) {
    test(
        '${meta ? 'Meta' : 'TikTok'} recovers immutable payment before expired schedule without second submit',
        () async {
      final r = request(meta: meta), paths = <String>[];
      final transport = mockTransport((req) async {
        paths.add(req.url.path);
        if (req.url.path.endsWith('/pa_ad_submission_status')) {
          return jsonResponse({'ok': false, 'code': 'NOT_FOUND'});
        }
        expect(req.url.origin, staging.publicBase);
        expect(req.url.path, '/api/meta-ads');
        expect(
            req.url.queryParameters, {'op': 'prepare', 'platform': 'payments'});
        expect(jsonDecode(req.body), {
          'submission_id': r.id,
          'platform': meta ? 'META' : 'TIKTOK',
          'quote_id': 'frozen-quote',
          'expected_cost_usd': 29.99,
          'expected_amount_iqd': r.quote.totalIqd,
        });
        expect(req.headers['authorization'], startsWith('Bearer '));
        return jsonResponse(attempt(r));
      });
      final client = await signedClient(transport);
      addTearDown(client.dispose);
      final repo = SupabaseAdCreationRepository(client, backendConfig: staging);
      final progress = ValueNotifier(const AdPaymentProgress());
      addTearDown(progress.dispose);
      expect(
          await http.runWithClient(
              () => repo.submit(r, progress), () => transport),
          'atomic-ad');
      expect(paths, ['/rest/v1/rpc/pa_ad_submission_status', '/api/meta-ads']);
      expect(await repo.pending(), isNull);
    });
  }

  test('lost prepare response retries same submission and frozen quote',
      () async {
    final r = request();
    final bodies = <Object>[];
    final transport = mockTransport((req) async {
      if (req.url.path.endsWith('/pa_ad_submission_status')) {
        return jsonResponse({'ok': false, 'code': 'NOT_FOUND'});
      }
      expect(req.url.queryParameters['op'], 'prepare');
      bodies.add(jsonDecode(req.body));
      if (bodies.length == 1) throw http.ClientException('response lost');
      return jsonResponse(attempt(r));
    });
    final client = await signedClient(transport);
    addTearDown(client.dispose);
    final repo = SupabaseAdCreationRepository(client, backendConfig: staging);
    final progress = ValueNotifier(const AdPaymentProgress());
    addTearDown(progress.dispose);
    await expectLater(
        http.runWithClient(() => repo.submit(r, progress), () => transport),
        throwsA(isA<AdSubmissionFailure>()
            .having((e) => e.uncertain, 'uncertain', true)));
    final frozen = (await repo.pending())!;
    expect(
        await http.runWithClient(
            () => repo.submit(frozen, progress), () => transport),
        'atomic-ad');
    expect(bodies[0], bodies[1]);
  });

  test(
      'verification rejection during prepare preserves the existing attempt identity',
      () async {
    final r = request();
    final transport = mockTransport((req) async {
      if (req.url.path.endsWith('/pa_ad_submission_status')) {
        return jsonResponse({'ok': false, 'code': 'NOT_FOUND'});
      }
      return http.Response(
          jsonEncode({
            'ok': false,
            'code': 'FASTPAY_VERIFICATION_MISMATCH',
            'uncertain': false
          }),
          409,
          headers: {'content-type': 'application/json'});
    });
    final client = await signedClient(transport);
    addTearDown(client.dispose);
    final repo = SupabaseAdCreationRepository(client, backendConfig: staging);
    final progress = ValueNotifier(const AdPaymentProgress());
    addTearDown(progress.dispose);
    await expectLater(
        http.runWithClient(() => repo.submit(r, progress), () => transport),
        throwsA(isA<AdSubmissionFailure>()
            .having((e) => e.uncertain, 'uncertain', true)));
    expect((await repo.pending())!.toJson(), r.toJson());
  });

  for (final meta in [false, true]) {
    for (final code in [
      'AD_FASTPAY_UNAVAILABLE',
      'QUOTE_EXPIRED',
      'PRICE_CHANGED',
    ]) {
      test('${meta ? 'Meta' : 'TikTok'} $code before payment permits a fresh confirmation',
          () async {
        final r = request(meta: meta), operations = <String>[];
        final transport = mockTransport((req) async {
          if (req.url.path.endsWith('/pa_ad_submission_status')) {
            return jsonResponse({'ok': false, 'code': 'NOT_FOUND'});
          }
          operations.add(req.url.queryParameters['op']!);
          return http.Response(jsonEncode({
            'ok': false, 'code': code, 'uncertain': false,
            'attempt_created': false,
          }), 409, headers: {'content-type': 'application/json'});
        });
        final client = await signedClient(transport);
        addTearDown(client.dispose);
        final repo = SupabaseAdCreationRepository(client, backendConfig: staging);
        final progress = ValueNotifier(const AdPaymentProgress());
        addTearDown(progress.dispose);
        await expectLater(
            http.runWithClient(() => repo.submit(r, progress), () => transport),
            throwsA(isA<AdSubmissionFailure>()
                .having((e) => e.code, 'rejection', code)
                .having((e) => e.uncertain, 'definite pre-payment rejection', false)));
        expect(await repo.pending(), isNull);
        expect(operations, ['prepare']);
        expect(progress.value.qrUrl, isNull);
      });
    }
  }

  for (final response in [
    {'ok': false, 'code': 'QUOTE_EXPIRED', 'uncertain': false},
    {'ok': null, 'code': 'QUOTE_EXPIRED', 'uncertain': false, 'attempt_created': false},
    {'ok': false, 'code': 'QUOTE_EXPIRED', 'uncertain': true, 'attempt_created': false},
    {'ok': false, 'code': 'IDEMPOTENCY_CONFLICT', 'uncertain': false, 'attempt_created': false},
  ]) {
    test('ambiguous prepare rejection retains the same payment identity: $response',
        () async {
      final r = request();
      final transport = mockTransport((req) async =>
          req.url.path.endsWith('/pa_ad_submission_status')
              ? jsonResponse({'ok': false, 'code': 'NOT_FOUND'})
              : http.Response(jsonEncode(response), 409,
                  headers: {'content-type': 'application/json'}));
      final client = await signedClient(transport);
      addTearDown(client.dispose);
      final repo = SupabaseAdCreationRepository(client, backendConfig: staging);
      final progress = ValueNotifier(const AdPaymentProgress());
      addTearDown(progress.dispose);
      await expectLater(
          http.runWithClient(() => repo.submit(r, progress), () => transport),
          throwsA(isA<AdSubmissionFailure>()
              .having((e) => e.uncertain, 'retain payment recovery', true)));
      expect((await repo.pending())!.id, r.id);
    });
  }

  for (final meta in [false, true]) {
    test('${meta ? 'Meta' : 'TikTok'} can reconfirm after a proven unstarted closure',
        () async {
      final r = request(meta: meta);
      final transport = mockTransport((req) async => jsonResponse(
          req.url.path.endsWith('/pa_ad_submission_status')
              ? {'ok': false, 'code': 'NOT_FOUND'}
              : {
                  ...attempt(r, status: 'cancelled'),
                  'payment_not_started': true,
                  'uncertain': false,
                }));
      final client = await signedClient(transport);
      addTearDown(client.dispose);
      final repo = SupabaseAdCreationRepository(client, backendConfig: staging);
      final progress = ValueNotifier(const AdPaymentProgress());
      addTearDown(progress.dispose);
      await expectLater(
          http.runWithClient(() => repo.submit(r, progress), () => transport),
          throwsA(isA<AdSubmissionFailure>()
              .having((e) => e.code, 'closed before payment', 'FASTPAY_NOT_STARTED')
              .having((e) => e.uncertain, 'definitive closure', false)));
      expect(await repo.pending(), isNull);
      expect(progress.value.qrUrl, isNull);
    });
  }

  for (final extra in [
    {'payment_not_started': null},
    {'payment_not_started': 'true'},
    {'uncertain': true},
    {'uncertain': null},
    {'attempt_id': null},
    {'qr_text': 'still-payable'},
    {'result': {'ad_id': 'unproven-result'}},
  ]) {
    test('incomplete or contradictory unstarted proof keeps recovery: $extra',
        () async {
      final r = request();
      final transport = mockTransport((req) async => jsonResponse(
          req.url.path.endsWith('/pa_ad_submission_status')
              ? {'ok': false, 'code': 'NOT_FOUND'}
              : {
                  ...attempt(r, status: 'expired'),
                  'payment_not_started': true,
                  'uncertain': false,
                  ...extra,
                }));
      final client = await signedClient(transport);
      addTearDown(client.dispose);
      final repo = SupabaseAdCreationRepository(client, backendConfig: staging);
      final progress = ValueNotifier(const AdPaymentProgress());
      addTearDown(progress.dispose);
      await expectLater(
          http.runWithClient(() => repo.submit(r, progress), () => transport),
          throwsA(isA<AdSubmissionFailure>()
              .having((e) => e.uncertain, 'retain original payment', true)));
      expect((await repo.pending())!.id, r.id);
      expect(progress.value.qrUrl, isNull);
    });
  }

  for (final statusCode in [302, 409, 429, 503]) {
    test('unstarted proof in HTTP $statusCode cannot clear payment recovery',
        () async {
      final r = request();
      final transport = mockTransport((req) async =>
          req.url.path.endsWith('/pa_ad_submission_status')
              ? jsonResponse({'ok': false, 'code': 'NOT_FOUND'})
              : http.Response(jsonEncode({
                  ...attempt(r, status: 'cancelled'),
                  'payment_not_started': true,
                  'uncertain': false,
                }), statusCode));
      final client = await signedClient(transport);
      addTearDown(client.dispose);
      final repo = SupabaseAdCreationRepository(client, backendConfig: staging);
      final progress = ValueNotifier(const AdPaymentProgress());
      addTearDown(progress.dispose);
      await expectLater(
          http.runWithClient(() => repo.submit(r, progress), () => transport),
          throwsA(isA<AdSubmissionFailure>()
              .having((e) => e.uncertain, 'HTTP failure remains uncertain', true)));
      expect((await repo.pending())!.id, r.id);
    });
  }

  test('cancel clears only a matching attempt proven never dispatched', () async {
    final r = request(), started = Completer<void>(), gate = Completer<void>();
    final operations = <String>[];
    final transport = mockTransport((req) async {
      if (req.url.path.endsWith('/pa_ad_submission_status')) {
        return jsonResponse({'ok': false, 'code': 'NOT_FOUND'});
      }
      final op = req.url.queryParameters['op']!;
      operations.add(op);
      if (op == 'prepare') {
        started.complete();
        await gate.future;
        return jsonResponse(attempt(r, status: 'prepared'));
      }
      expect(op, 'cancel');
      return jsonResponse({
        ...attempt(r, status: 'cancelled'),
        'payment_not_started': true,
        'uncertain': false,
      });
    });
    final client = await signedClient(transport);
    addTearDown(client.dispose);
    final repo = SupabaseAdCreationRepository(client, backendConfig: staging);
    final progress = ValueNotifier(const AdPaymentProgress());
    addTearDown(progress.dispose);
    final pending =
        http.runWithClient(() => repo.submit(r, progress), () => transport);
    await started.future;
    repo.cancelPendingOperation(r.id);
    final checked = expectLater(
        pending,
        throwsA(isA<AdSubmissionFailure>()
            .having((e) => e.code, 'user cancelled', 'CANCELLED')
            .having((e) => e.uncertain, 'never dispatched', false)));
    gate.complete();
    await checked;
    expect(operations, ['prepare', 'cancel']);
    expect(await repo.pending(), isNull);
  });

  test('status rejection after prepare never clears an existing payment', () async {
    final r = request(), operations = <String>[];
    final transport = mockTransport((req) async {
      if (req.url.path.endsWith('/pa_ad_submission_status')) {
        return jsonResponse({'ok': false, 'code': 'NOT_FOUND'});
      }
      final op = req.url.queryParameters['op']!;
      operations.add(op);
      if (op == 'prepare') return jsonResponse(attempt(r, status: 'awaiting'));
      return http.Response(jsonEncode({
        'ok': false, 'code': 'QUOTE_EXPIRED', 'uncertain': false,
        'attempt_created': false,
      }), 409, headers: {'content-type': 'application/json'});
    });
    final client = await signedClient(transport);
    addTearDown(client.dispose);
    final repo = SupabaseAdCreationRepository(client, backendConfig: staging);
    final progress = ValueNotifier(const AdPaymentProgress());
    addTearDown(progress.dispose);
    await expectLater(
        http.runWithClient(() => repo.submit(r, progress), () => transport),
        throwsA(isA<AdSubmissionFailure>()
            .having((e) => e.uncertain, 'retain payment recovery', true)));
    expect(operations, ['prepare', 'status']);
    expect((await repo.pending())!.id, r.id);
  });

  test('malformed recovered success never removes the frozen submission',
      () async {
    final r = request();
    final client = await signedClient(mockTransport((req) async {
      expect(req.url.path, endsWith('/pa_ad_submission_status'));
      return jsonResponse({'ok': true});
    }));
    addTearDown(client.dispose);
    final repo = SupabaseAdCreationRepository(client, backendConfig: staging);
    final progress = ValueNotifier(const AdPaymentProgress());
    addTearDown(progress.dispose);
    await expectLater(
        repo.submit(r, progress),
        throwsA(isA<AdSubmissionFailure>()
            .having((e) => e.uncertain, 'uncertain', true)));
    expect((await repo.pending())!.id, r.id);
  });

  test('production app cannot accept a funded sandbox attempt', () async {
    final r = request();
    final transport = mockTransport((req) async => jsonResponse(
        req.url.path.endsWith('/pa_ad_submission_status')
            ? {'ok': false, 'code': 'NOT_FOUND'}
            : attempt(r)));
    final client = await signedClient(transport);
    addTearDown(client.dispose);
    final repo = SupabaseAdCreationRepository(client);
    final progress = ValueNotifier(const AdPaymentProgress());
    addTearDown(progress.dispose);
    await expectLater(
        http.runWithClient(() => repo.submit(r, progress), () => transport),
        throwsA(isA<AdSubmissionFailure>()
            .having((e) => e.code, 'mismatch', 'PAYMENT_ATTEMPT_MISMATCH')));
    expect((await repo.pending())!.id, r.id);
  });

  for (final change in [
    {'amount_iqd': 1},
    {'environment': 'production'},
    {'status': 'expired', 'result': null},
  ]) {
    test(
        'unresolved payment ${change.keys.first} preserves request without exposing QR',
        () async {
      final r = request();
      final transport = mockTransport((req) async => jsonResponse(
          req.url.path.endsWith('/pa_ad_submission_status')
              ? {'ok': false, 'code': 'NOT_FOUND'}
              : {
                  ...attempt(r),
                  ...change,
                  'qr_url': 'https://qr.fast-pay.iq/qr.png'
                }));
      final client = await signedClient(transport);
      addTearDown(client.dispose);
      final repo = SupabaseAdCreationRepository(client, backendConfig: staging);
      final progress = ValueNotifier(const AdPaymentProgress());
      addTearDown(progress.dispose);
      await expectLater(
          http.runWithClient(() => repo.submit(r, progress), () => transport),
          throwsA(isA<AdSubmissionFailure>()
              .having((e) => e.uncertain, 'uncertain', true)));
      expect((await repo.pending())!.id, r.id);
      expect(progress.value.qrUrl, isNull);
    });
  }

  test(
      'cancel after prepare records server intent and retains late-payment recovery',
      () async {
    final r = request(), started = Completer<void>(), gate = Completer<void>();
    final operations = <String>[];
    final transport = mockTransport((req) async {
      if (req.url.path.endsWith('/pa_ad_submission_status')) {
        return jsonResponse({'ok': false, 'code': 'NOT_FOUND'});
      }
      final op = req.url.queryParameters['op']!;
      operations.add(op);
      if (op == 'prepare') {
        started.complete();
        await gate.future;
      } else {
        expect(op, 'cancel');
        expect(jsonDecode(req.body), {'attempt_id': 'bound-attempt'});
      }
      return jsonResponse(attempt(r, status: 'awaiting'));
    });
    final client = await signedClient(transport);
    addTearDown(client.dispose);
    final repo = SupabaseAdCreationRepository(client, backendConfig: staging);
    final progress = ValueNotifier(const AdPaymentProgress());
    addTearDown(progress.dispose);
    final pending =
        http.runWithClient(() => repo.submit(r, progress), () => transport);
    await started.future;
    repo.cancelPendingOperation(r.id);
    final checked = expectLater(
        pending,
        throwsA(isA<AdSubmissionFailure>()
            .having((e) => e.code, 'cancelled', 'CANCELLED')
            .having((e) => e.uncertain, 'retain recovery', true)));
    gate.complete();
    await checked;
    expect(operations, ['prepare', 'cancel']);
    expect((await repo.pending())!.id, r.id);
  });
}
