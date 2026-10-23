import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../integration_test/support/actual_screen_fixtures.dart';

void main() {
  test('exact ad help reads return the real disabled SQL response', () async {
    final backend = ActualScreenBackend();
    final client = SupabaseClient(
        'https://screen-fixtures.invalid', 'fictional-publishable-key',
        httpClient: backend.transport,
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    addTearDown(client.dispose);
    for (final platform in ['META', 'TIKTOK']) {
      expect(await client.rpc('pa_ad_help', params: {'p_platform': platform}),
          isNull);
    }
    expect(backend.nonGetAttempts, isEmpty);
  });

  test('help fixture rejects different hosts, methods, paths and body shapes',
      () async {
    final backend = ActualScreenBackend();
    addTearDown(backend.transport.close);
    const url = 'https://screen-fixtures.invalid/rest/v1/rpc/pa_ad_help';
    const body = '{"p_platform":"TIKTOK"}';
    final cases = [
      ('https://other.invalid/rest/v1/rpc/pa_ad_help', body),
      (url.replaceFirst('https:', 'http:'), body),
      (url.replaceFirst('screen-fixtures', 'user@screen-fixtures'), body),
      (url.replaceFirst('.invalid/', '.invalid:8443/'), body),
      ('$url?x=1', body),
      ('$url#fragment', body),
      ('$url/extra', body),
      (url, '{}'),
      (url, 'null'),
      (url, '{"p_platform":"OTHER"}'),
      (url, '{"p_platform":"TIKTOK","active":true}'),
      (url, '{"p_platform":"TIKTOK","p_platform":"META"}'),
      (url, '{"p_platform":true}'),
      (url, 'not-json'),
    ];
    for (final (uri, payload) in cases) {
      await expectLater(backend.transport.post(Uri.parse(uri), body: payload),
          throwsA(isA<StateError>()));
    }
    await expectLater(backend.transport.put(Uri.parse(url), body: body),
        throwsA(isA<StateError>()));
    expect(backend.nonGetAttempts, hasLength(cases.length + 1));
    expect(
        backend.nonGetAttempts
            .every((attempt) => attempt['expected_blocked_operation'] == null),
        isTrue);
  });

  test('actual unread count HEAD is classified but remains blocked', () async {
    final backend = ActualScreenBackend();
    final client = SupabaseClient(
        'https://screen-fixtures.invalid', 'fictional-publishable-key',
        httpClient: backend.transport,
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    addTearDown(client.dispose);
    await expectLater(
      client
          .from('pa_notifications')
          .count(CountOption.exact)
          .eq('user_id', screenFixtureOwner)
          .eq('is_read', false),
      throwsA(isA<StateError>()),
    );
    expect(backend.nonGetAttempts.single['method'], 'HEAD');
    expect(backend.nonGetAttempts.single['expected_blocked_operation'],
        'unread_notification_count');
  });

  test('other HEAD hosts, paths, owners and query shapes stay unexpected',
      () async {
    final backend = ActualScreenBackend();
    addTearDown(backend.transport.close);
    const query = 'user_id=eq.$screenFixtureOwner&is_read=eq.false';
    final cases = [
      'https://other.invalid/rest/v1/pa_notifications?$query',
      'https://screen-fixtures.invalid/rest/v1/pa_wallets?$query',
      'https://screen-fixtures.invalid/rest/v1/pa_notifications?user_id=eq.another-owner&is_read=eq.false',
      'https://screen-fixtures.invalid/rest/v1/pa_notifications?user_id=eq.$screenFixtureOwner',
      'https://screen-fixtures.invalid/rest/v1/pa_notifications?$query&limit=1',
      'https://screen-fixtures.invalid/rest/v1/pa_notifications?$query&is_read=eq.true',
    ];
    for (final uri in cases) {
      await expectLater(
          backend.transport.head(Uri.parse(uri)), throwsA(isA<StateError>()));
    }
    expect(backend.nonGetAttempts, hasLength(cases.length));
    expect(
        backend.nonGetAttempts
            .every((attempt) => attempt['expected_blocked_operation'] == null),
        isTrue);
  });

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
