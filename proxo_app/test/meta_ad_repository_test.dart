import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/services/ad_submission.dart';
import 'ad_repository_test.dart' show signedClient, mockTransport, jsonResponse;
import 'meta_ad_draft_test.dart' show metaDraft;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  AdPendingSubmission request() => AdPendingSubmission.create(
      metaDraft(),
      const AdQuote(
          grossUsd: 15,
          costUsd: 15,
          rate: 1500,
          metaContract: {'quote_id': 'frozen-quote'},
          days: 3));

  test(
      'lost Meta accept response recovers before gate, schedule or new payment',
      () async {
    var committed = false;
    var accepted = 0;
    final transport = mockTransport((req) async {
      if (req.url.path.endsWith('/pa_ad_submission_status')) {
        return jsonResponse(committed
            ? {'ok': true, 'ad_id': 'meta-ad'}
            : {'ok': false, 'code': 'NOT_FOUND'});
      }
      if (req.url.path.endsWith('/pa_ad_capabilities')) {
        expect(committed, isFalse);
        return jsonResponse(
            {'meta_enabled': true, 'server_time': '2026-10-23T10:00:00Z'});
      }
      expect(req.url.path, '/api/meta-ads');
      expect(req.url.queryParameters['op'], 'submit');
      final body = jsonDecode(req.body);
      expect(body['quote_id'], 'frozen-quote');
      expect(body['expected_total_minor'], 1500);
      expect(body['expected_total_iqd'], 22500);
      accepted++;
      committed = true;
      throw http.ClientException('Lost after atomic commit');
    });
    final client = await signedClient(transport);
    addTearDown(client.dispose);
    final repo = SupabaseAdCreationRepository(client);
    final progress = ValueNotifier(const AdPaymentProgress());
    addTearDown(progress.dispose);
    await expectLater(
        http.runWithClient(
            () => repo.submit(request(), progress), () => transport),
        throwsA(isA<AdSubmissionFailure>()
            .having((e) => e.uncertain, 'uncertain', true)));
    final frozen = (await repo.pending())!;
    expect(await repo.submit(frozen, progress), 'meta-ad');
    expect(accepted, 1);
    expect(await repo.pending(), isNull);
  });

  test(
      'explicit Meta gate rejection clears pending without client wallet writes',
      () async {
    final paths = <String>[];
    final transport = mockTransport((req) async {
      paths.add(req.url.path);
      if (req.url.path.endsWith('/pa_ad_submission_status')) {
        return jsonResponse({'ok': false, 'code': 'NOT_FOUND'});
      }
      if (req.url.path.endsWith('/pa_ad_capabilities')) {
        return jsonResponse({'server_time': '2026-10-23T10:00:00Z'});
      }
      return jsonResponse({'ok': false, 'code': 'META_DISABLED'});
    });
    final client = await signedClient(transport);
    addTearDown(client.dispose);
    final repo = SupabaseAdCreationRepository(client);
    final progress = ValueNotifier(const AdPaymentProgress());
    addTearDown(progress.dispose);
    await expectLater(
        http.runWithClient(
            () => repo.submit(request(), progress), () => transport),
        throwsA(isA<AdSubmissionFailure>()
            .having((e) => e.code, 'code', 'META_DISABLED')));
    expect(await repo.pending(), isNull);
    expect(paths, [
      '/rest/v1/rpc/pa_ad_submission_status',
      '/rest/v1/rpc/pa_ad_capabilities',
      '/api/meta-ads'
    ]);
  });
}
