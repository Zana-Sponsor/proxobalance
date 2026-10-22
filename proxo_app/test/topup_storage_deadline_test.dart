import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:proxo_app/services/topup_service.dart';

import 'ad_repository_test.dart' show signedClient, mockTransport, jsonResponse;

class DelayedTopupStore extends SharedPreferencesStorePlatform {
  final values = <String, Object>{};
  Completer<void>? initialWrite, completedWrite;

  @override
  Future<Map<String, Object>> getAll() async => Map.of(values);

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key.contains('proxo.topup.retry.v2.')) {
      final records = jsonDecode(value as String) as Map;
      final completed =
          records.values.any((row) => (row as Map)['complete'] == true);
      await (completed ? completedWrite?.future : initialWrite?.future);
    }
    values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
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

  // All stages share a FakeAsync zone because the production storage queue is
  // intentionally serialized across TopupService instances and screen routes.
  testWidgets(
      'storage deadlines unlock callers and preserve the original retry key',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = DelayedTopupStore();
    SharedPreferencesStorePlatform.instance = store;
    final paths = <String>[];
    final requests = <Map<String, dynamic>>[];
    final resultsByKey = <String, Map<String, dynamic>>{};
    final client = (await tester
        .runAsync(() => signedClient(mockTransport((request) async {
              paths.add(request.url.path);
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              requests.add(body);
              final key = body['p_key'] as String;
              return jsonResponse(resultsByKey.putIfAbsent(
                  key,
                  () => {
                        'ok': true,
                        'public_transaction_id':
                            'CONFIRMED-${resultsByKey.length + 1}',
                        'credited_iqd': body['p_gross_iqd'],
                        'fee_iqd': 0,
                      }));
            }))))!;
    addTearDown(() async {
      if (store.initialWrite?.isCompleted == false)
        store.initialWrite!.complete();
      if (store.completedWrite?.isCompleted == false)
        store.completedWrite!.complete();
      await tester.runAsync(client.dispose);
      SharedPreferences.setMockInitialValues({});
    });
    final service = TopupService(client);
    Future<Map<String, dynamic>> submit() => service.submit(
        method: 'fib',
        grossIqd: 25000,
        sender: 'Fixture Sender',
        note: '',
        receipt: 'fixture receipt');

    // Before any RPC, a stalled durable key write fails closed and releases its
    // caller. Completing that old write later does not start a payment request.
    store.initialWrite = Completer<void>();
    final blocked = expectLater(
        submit(),
        throwsA(isA<TopupFailure>()
            .having((error) => error.code, 'reason', 'STORAGE_UNAVAILABLE')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    await blocked;
    expect(requests, isEmpty);
    store.initialWrite!.complete();
    await tester.pump();
    expect(requests, isEmpty);
    final persisted = jsonDecode(store.values.values.single as String) as Map;
    final originalKey = (persisted.values.single as Map)['key'];

    // Confirmed server success is returned after a bounded bookkeeping wait.
    // That write stays in the queue, so a later retry cannot overtake it.
    store.completedWrite = Completer<void>();
    Map<String, dynamic>? confirmed;
    submit().then((value) => confirmed = value);
    await tester.pump();
    expect(requests, hasLength(1));
    expect(requests.single['p_key'], originalKey);
    await tester.pump(const Duration(seconds: 3));
    expect(confirmed?['public_transaction_id'], 'CONFIRMED-1');
    final blockedRetry = expectLater(
        submit(),
        throwsA(isA<TopupFailure>()
            .having((error) => error.code, 'reason', 'STORAGE_UNAVAILABLE')));
    // Start the queued operation before advancing its deadline in FakeAsync.
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    await blockedRetry;
    expect(requests, hasLength(1));
    store.completedWrite!.complete();
    await tester.pump();
    // The deferred local retry-key task may finish, but its timed-out caller
    // must never proceed to a second RPC in the background.
    expect(requests, hasLength(1));
    final retry = submit();
    await tester.pump();
    final recovered = await retry;
    expect(recovered['public_transaction_id'], 'CONFIRMED-1');
    expect(requests.map((body) => body['p_key']).toSet(), {originalKey});
    expect(resultsByKey, hasLength(1));
    expect(paths, everyElement(endsWith('/pa_submit_topup')));
    expect(tester.takeException(), isNull);
  });
}
