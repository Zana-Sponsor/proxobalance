import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/services/ad_submission.dart';
import 'ad_repository_test.dart' show signedClient, mockTransport, jsonResponse;
import 'tiktok_dm_draft_test.dart' show directDraft;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  AdPendingSubmission request() => AdPendingSubmission.create(
      directDraft(),
      const AdQuote(
          grossUsd: 30,
          costUsd: 30,
          rate: 1500,
          days: 3,
          tiktokContract: {'quote_id': 'frozen-quote'}));

  test('lost Direct Message acceptance recovers before gates or another debit',
      () async {
    var committed = false;
    var accepted = 0;
    final transport = mockTransport((req) async {
      if (req.url.path.endsWith('/pa_ad_submission_status')) {
        return jsonResponse(committed
            ? {'ok': true, 'ad_id': 'automatic-ad'}
            : {'ok': false, 'code': 'NOT_FOUND'});
      }
      if (req.url.path.endsWith('/pa_ad_capabilities')) {
        expect(committed, isFalse);
        return jsonResponse(
            {'tiktok_dm_enabled': true, 'server_time': '2026-10-23T10:00:00Z'});
      }
      expect(req.url.path, '/api/tiktok-dm');
      expect(req.url.queryParameters['op'], 'submit');
      final body = jsonDecode(req.body);
      expect(body['quote_id'], 'frozen-quote');
      expect(body['expected_cost_usd'], 30);
      expect(body['expected_price_iqd'], 45000);
      expect(body['ad']['message_destination'], 'direct_message');
      expect((body['ad'] as Map).containsKey('video_code'), isFalse);
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
    expect(await repo.submit(frozen, progress), 'automatic-ad');
    expect(accepted, 1);
    expect(await repo.pending(), isNull);
  });

  test(
      'missing trusted time stops Direct Message before payment or provider POST',
      () async {
    final paths = <String>[];
    final transport = mockTransport((req) async {
      paths.add(req.url.path);
      return jsonResponse(req.url.path.endsWith('/pa_ad_submission_status')
          ? {'ok': false, 'code': 'NOT_FOUND'}
          : {'tiktok_dm_enabled': true});
    });
    final client = await signedClient(transport);
    addTearDown(client.dispose);
    final repo = SupabaseAdCreationRepository(client);
    final progress = ValueNotifier(const AdPaymentProgress());
    addTearDown(progress.dispose);
    await expectLater(
        repo.submit(request(), progress),
        throwsA(isA<AdSubmissionFailure>()
            .having((e) => e.code, 'code', 'SERVER_TIME_UNAVAILABLE')));
    expect(paths, [
      '/rest/v1/rpc/pa_ad_submission_status',
      '/rest/v1/rpc/pa_ad_capabilities'
    ]);
    expect(await repo.pending(), isNull);
  });
}
