import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:proxo_app/services/ad_submission.dart';
import 'package:proxo_app/services/proxolink_pending_request.dart';

import 'ad_repository_test.dart' show signedClient, mockTransport, jsonResponse;
import 'ad_submission_test.dart' show validDraft;

class DelayedRemovalStore extends SharedPreferencesStorePlatform {
  final values = <String, Object>{};
  final writes = <String>[];
  Completer<void>? removal;
  @override
  Future<Map<String, Object>> getAll() async => Map.of(values);
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    writes.add(key);
    values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    await removal?.future;
    values.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    values.clear();
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('late page cleanup cannot erase the next pending request',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = DelayedRemovalStore();
    SharedPreferencesStorePlatform.instance = store;
    addTearDown(() {
      if (store.removal?.isCompleted == false) store.removal!.complete();
      SharedPreferences.setMockInitialValues({});
    });
    const pending = ProxoLinkPendingRequestStore();
    await pending.write('fixture-owner', 'first-page-request');
    store.removal = Completer<void>();
    final cleanup = pending
        .clear('fixture-owner')
        .timeout(const Duration(seconds: 3), onTimeout: () {});
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await cleanup;
    var nextWritten = false;
    final next = pending
        .write('fixture-owner', 'second-page-request')
        .then((_) => nextWritten = true);
    await tester.pump();
    expect(nextWritten, false);
    expect(store.writes, hasLength(1));
    store.removal!.complete();
    await tester.pump();
    await next;
    expect(await pending.read('fixture-owner'), 'second-page-request');
    expect(store.values.values.single, 'second-page-request');
    expect(tester.takeException(), isNull);
  });

  testWidgets('late ad cleanup stays ahead of the next unresolved ad identity',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = DelayedRemovalStore();
    SharedPreferencesStorePlatform.instance = store;
    final secondReply = Completer<http.Response>();
    final submissions = <String>[];
    final submissionPaths = <String>[];
    final client = (await tester
        .runAsync(() => signedClient(mockTransport((request) async {
              if (request.url.path.endsWith('/generate-ad-thumbnail')) {
                return jsonResponse({'ok': true});
              }
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              if (request.url.path.endsWith('/pa_ad_submission_status')) {
                return jsonResponse({'ok': false, 'code': 'NOT_FOUND'});
              }
              submissionPaths.add(request.url.path);
              submissions.add(body['p_submission_id'] as String);
              if (submissions.length == 2) return secondReply.future;
              return jsonResponse({'ok': true, 'ad_id': 'first-ad'});
            }))))!;
    final firstProgress = ValueNotifier(const AdPaymentProgress());
    final secondProgress = ValueNotifier(const AdPaymentProgress());
    addTearDown(() async {
      if (store.removal?.isCompleted == false) store.removal!.complete();
      if (!secondReply.isCompleted)
        secondReply.complete(jsonResponse({'ok': true, 'ad_id': 'second-ad'}));
      await tester.runAsync(client.dispose);
      firstProgress.dispose();
      secondProgress.dispose();
      SharedPreferences.setMockInitialValues({});
    });
    final repository = SupabaseAdCreationRepository(client);
    final first = AdPendingSubmission.create(
        validDraft(), const AdQuote(grossUsd: 10, costUsd: 10, rate: 1800));
    final second = AdPendingSubmission.create(
        validDraft(), const AdQuote(grossUsd: 10, costUsd: 10, rate: 1800));
    store.removal = Completer<void>();
    String? confirmed;
    final firstResult = repository
        .submit(first, firstProgress)
        .then((value) => confirmed = value);
    await tester.pump();
    expect(submissions, [first.id]);
    await tester.pump(const Duration(seconds: 3));
    await firstResult;
    expect(confirmed, 'first-ad');
    final secondResult = repository.submit(second, secondProgress);
    await tester.pump();
    expect(submissions, [first.id]);
    expect(store.writes, hasLength(1));
    store.removal!.complete();
    await tester.pump();
    expect(submissions, [first.id, second.id]);
    final persisted = jsonDecode(store.values.values.single as String) as Map;
    expect(persisted['id'], second.id);
    expect((await repository.pending())?.id, second.id);
    secondReply.complete(jsonResponse({'ok': true, 'ad_id': 'second-ad'}));
    await tester.pump();
    expect(await secondResult, 'second-ad');
    expect(submissionPaths, everyElement(endsWith('/pa_submit_ad')));
    expect(store.values, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
