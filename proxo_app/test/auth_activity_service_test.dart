import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:proxo_app/services/auth_activity_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const ownerA = '11111111-1111-4111-8111-111111111111';
const ownerB = '22222222-2222-4222-8222-222222222222';
const sessionA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const sessionB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

Session fixtureSession(String owner, String id) {
  String part(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final token = '${part({'alg': 'HS256'})}.'
      '${part({'sub': owner, 'session_id': id, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})}.fixture';
  return Session(accessToken: token, refreshToken: 'fixture-refresh',
      tokenType: 'bearer', user: User(id: owner, appMetadata: const {},
        userMetadata: const {}, aud: 'authenticated', createdAt: '2026-10-16T00:00:00Z'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late AuthActivityService service;
  final requests = <http.Request>[];
  var failRpc = false;
  var failLogout = false;
  var collections = 0;
  Future<Map<String, String>> Function()? collector;

  setUp(() {
    requests.clear(); failRpc = false; failLogout = false; collections = 0;
    collector = null;
    client = SupabaseClient('https://auth-log-fixture.invalid', 'fixture-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/rest/v1/rpc/pa_record_app_session') {
          return http.Response(jsonEncode(failRpc
              ? {'code': '42501', 'message': 'fixture denial'} : sessionA), failRpc ? 403 : 200,
            headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/auth/v1/logout') {
          return http.Response(failLogout ? '{"message":"fixture outage"}' : '{}',
              failLogout ? 500 : 204, headers: {'content-type': 'application/json'});
        }
        throw StateError('No real network: ${request.url.path}');
      }));
    service = AuthActivityService(client, collectDevice: () async {
      collections++;
      if (collector != null) return collector!();
      return {'device_name': 'Fixture Android', 'device_model': 'Fixture Model',
        'os': 'Android', 'os_version': '13', 'platform': 'android'};
    });
  });
  tearDown(() async { await service.dispose(); await client.dispose(); });

  Future<void> restore(String owner, String id) =>
      client.auth.recoverSession(jsonEncode(fixtureSession(owner, id).toJson()));
  Iterable<http.Request> metadataCalls() =>
      requests.where((r) => r.url.path.endsWith('pa_record_app_session'));

  test('concurrent requests share one metadata write and never send credentials in its body', () async {
    await restore(ownerA, sessionA);
    final pending = Completer<Map<String, String>>();
    collector = () => pending.future;
    final calls = [service.recordCurrentSession(), service.recordCurrentSession()];
    pending.complete({'device_model': 'Fixture Model', 'os': 'Android'});
    await Future.wait(calls);
    expect(metadataCalls().length, 1); expect(collections, 1);
    final body = jsonDecode(metadataCalls().single.body) as Map;
    expect(body['p_session_id'], sessionA);
    expect(body['p_device']['device_model'], 'Fixture Model');
    expect(body.keys.toSet(), {'p_session_id', 'p_device'});
    expect(metadataCalls().single.body, isNot(contains('fixture-refresh')));
  });

  test('restored session and repeated Auth events do not create duplicate writes', () async {
    await restore(ownerA, sessionA);
    service.start(); service.start();
    await service.recordCurrentSession();
    await restore(ownerA, sessionA);
    await service.recordCurrentSession();
    expect(metadataCalls().length, 1);
  });

  test('failed writes and device failures remain retryable', () async {
    await restore(ownerA, sessionA);
    collector = () => throw StateError('fixture plugin unavailable');
    await service.recordCurrentSession();
    expect(metadataCalls(), isEmpty);
    collector = null; failRpc = true;
    await service.recordCurrentSession();
    failRpc = false;
    await service.recordCurrentSession();
    expect(metadataCalls().length, 2);
  });

  test('account change during collection cannot write the old session under the new owner', () async {
    await restore(ownerA, sessionA);
    final pending = Completer<Map<String, String>>();
    collector = () => pending.future;
    final old = service.recordCurrentSession();
    await Future<void>.delayed(Duration.zero);
    await restore(ownerB, sessionB);
    pending.complete({'device_model': 'Fixture Model'});
    await old;
    expect(metadataCalls(), isEmpty);
    await service.recordCurrentSession();
    expect((jsonDecode(metadataCalls().single.body) as Map)['p_session_id'], sessionB);
  });

  test('logout enriches the active session before Auth clears it and sends no post-logout write', () async {
    await restore(ownerA, sessionA);
    service.start();
    await service.signOut();
    await service.recordCurrentSession();
    expect(requests.map((r) => r.url.path).toList(),
      ['/rest/v1/rpc/pa_record_app_session', '/auth/v1/logout']);
    expect(client.auth.currentSession, isNull);
  });

  test('logout failure is not logged by an unauthenticated client write', () async {
    await restore(ownerA, sessionA);
    failLogout = true;
    try { await service.signOut(); } catch (_) {}
    expect(requests.where((r) => r.url.path.contains('pa_activity_log')), isEmpty);
    expect(requests.where((r) => r.url.path.contains('close_session')), isEmpty);
  });

  test('disposed service and sessions without a real session ID do not write', () async {
    await restore(ownerA, 'not-a-session-id');
    await service.recordCurrentSession();
    expect(requests, isEmpty);
    await restore(ownerA, sessionA);
    await service.dispose();
    await service.recordCurrentSession();
    expect(requests, isEmpty);
  });
}
