import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:proxo_app/services/proxolink_service.dart';

import 'ad_repository_test.dart' show signedClient, mockTransport, userId;

const pageId = '22222222-2222-4222-8222-222222222222';
Map<String, dynamic> persistedPage() => {
      'id': pageId,
      'user_id': userId,
      'name': 'پەڕەی Proxo',
      'template_key': 'pill-white',
      'template_version': 6,
      'platforms': {'wa': '07501234567'},
      'status': 'active',
      'publish_status': 'ready',
      'created_at': '2026-10-20T08:00:00Z',
      'updated_at': '2026-10-20T08:01:00Z',
      'card_number': 7,
    };
http.Response response(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('successful persisted response does not depend on a second list request',
      () async {
    final calls = <String>[];
    final transport = mockTransport((req) async {
      calls.add(req.method);
      expect(req.headers['authorization'], startsWith('Bearer '));
      if (req.method == 'GET') throw http.ClientException('List unavailable');
      return response({'ok': true, 'card': persistedPage()}, 201);
    });
    final client = await signedClient(transport);
    addTearDown(client.dispose);
    final service = ProxoLinkService(client, httpClient: transport);
    final card = await service.save({'client_request_id': pageId});
    expect(card.id, pageId);
    expect(card.updatedAt, DateTime.utc(2026, 10, 20, 8, 1));
    expect(card.available, isTrue);
    expect(calls, ['POST']);
  });

  test(
      'legacy server summary reads back persisted record and supports reopening',
      () async {
    final calls = <String>[];
    final transport = mockTransport((req) async {
      calls.add(req.method);
      return req.method == 'POST'
          ? response({
              'ok': true,
              'card': {'id': pageId}
            })
          : response({
              'ok': true,
              'cards': [persistedPage()]
            });
    });
    final client = await signedClient(transport);
    addTearDown(client.dispose);
    final service = ProxoLinkService(client, httpClient: transport);
    expect((await service.save({'client_request_id': pageId})).id, pageId);
    expect(
        (await ProxoLinkService(client, httpClient: transport).cards())
            .single
            .id,
        pageId);
    expect(calls, ['POST', 'GET', 'GET']);
  });

  test(
      'legacy write success and list failure reports saved ID, not unsaved failure',
      () async {
    final transport = mockTransport((req) async {
      if (req.method == 'GET') throw http.ClientException('offline');
      return response({
        'ok': true,
        'card': {'id': pageId}
      });
    });
    final client = await signedClient(transport);
    addTearDown(client.dispose);
    await expectLater(
        ProxoLinkService(client, httpClient: transport)
            .save({'client_request_id': pageId}),
        throwsA(isA<ProxoLinkFailure>()
            .having((e) => e.code, 'code', 'saved_refresh_failed')
            .having((e) => e.savedCardId, 'persisted page', pageId)));
  });

  test('changed interrupted request exposes original saved page for recovery',
      () async {
    final transport = mockTransport((req) async => response({
          'ok': false,
          'error': 'idempotency_conflict',
          'card': persistedPage(),
        }, 409));
    final client = await signedClient(transport);
    addTearDown(client.dispose);
    await expectLater(
        ProxoLinkService(client, httpClient: transport)
            .save({'client_request_id': pageId}),
        throwsA(isA<ProxoLinkFailure>()
            .having((e) => e.code, 'code', 'idempotency_conflict')
            .having((e) => e.savedCardId, 'persisted page', pageId)));
  });

  test('expired authentication is not reported as a generic network error',
      () async {
    final transport =
        mockTransport((req) async => http.Response('Unauthorized', 401));
    final client = await signedClient(transport);
    addTearDown(client.dispose);
    await expectLater(
        ProxoLinkService(client, httpClient: transport).cards(),
        throwsA(isA<ProxoLinkFailure>()
            .having((e) => e.code, 'code', 'unauthorized')));
  });
}
