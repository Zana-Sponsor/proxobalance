import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../integration_test/support/actual_screen_fixtures.dart';

void main() {
  test('expected Android lookup is classified but remains blocked', () async {
    final backend = ActualScreenBackend();
    addTearDown(backend.transport.close);
    final hash = List.filled(64, 'a').join();
    await expectLater(
      backend.transport.post(
        Uri.parse(
            'https://screen-fixtures.invalid/rest/v1/rpc/pa_trusted_device_lookup'),
        body: jsonEncode({'p_device_id': hash}),
      ),
      throwsA(isA<StateError>()),
    );
    expect(backend.nonGetAttempts.single['expected_blocked_operation'],
        'trusted_device_lookup');
    expect(jsonEncode(backend.nonGetAttempts), isNot(contains(hash)));
  });

  test('only the exact fictional thumbnail repair is expected and blocked',
      () async {
    final backend = ActualScreenBackend();
    addTearDown(backend.transport.close);
    final uri = Uri.parse(
        'https://screen-fixtures.invalid/functions/v1/generate-ad-thumbnail');
    for (final id in ['00000000-0000-4000-8000-000000000001', 'another-ad']) {
      await expectLater(
          backend.transport.post(uri, body: jsonEncode({'ad_id': id})),
          throwsA(isA<StateError>()));
    }
    expect(backend.nonGetAttempts.first['expected_blocked_operation'],
        'fictional_thumbnail_repair');
    expect(backend.nonGetAttempts.last['expected_blocked_operation'], isNull);
  });

  test('lookup classification cannot admit different hosts or request shapes',
      () async {
    final backend = ActualScreenBackend();
    addTearDown(backend.transport.close);
    final hash = List.filled(64, 'a').join();
    final cases = [
      ('screen-fixtures.invalid', {'p_device_id': 'invalid'}),
      ('screen-fixtures.invalid', {'p_device_id': hash, 'unexpected': true}),
      ('other.invalid', {'p_device_id': hash}),
    ];
    for (final entry in cases) {
      await expectLater(
        backend.transport.post(
          Uri.parse('https://${entry.$1}/rest/v1/rpc/pa_trusted_device_lookup'),
          body: jsonEncode(entry.$2),
        ),
        throwsA(isA<StateError>()),
      );
    }
    expect(backend.nonGetAttempts, hasLength(3));
    expect(
        backend.nonGetAttempts
            .every((attempt) => attempt['expected_blocked_operation'] == null),
        isTrue);
  });

  test(
      'registration, payments and page mutations remain unexpected and blocked',
      () async {
    final backend = ActualScreenBackend();
    addTearDown(backend.transport.close);
    for (final path in [
      '/rest/v1/rpc/pa_trusted_device_register',
      '/rest/v1/rpc/pa_submit_topup',
      '/rest/v1/proxolink_cards',
      '/auth/v1/logout',
    ]) {
      await expectLater(
        backend.transport.post(
            Uri.parse('https://screen-fixtures.invalid$path'),
            body: '{}'),
        throwsA(isA<StateError>()),
      );
    }
    expect(backend.nonGetAttempts, hasLength(4));
    expect(
        backend.nonGetAttempts
            .every((attempt) => attempt['expected_blocked_operation'] == null),
        isTrue);
  });
}
