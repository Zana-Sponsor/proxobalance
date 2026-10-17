import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:proxo_app/services/app_telemetry_service.dart';
import 'package:proxo_app/services/observed_http_client.dart';

import 'support/session_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late AppTelemetryService telemetry;
  final batches = <Map<String, dynamic>>[];
  bool failing = false;
  setUp(() async {
    batches.clear();
    failing = false;
    client = SupabaseClient(
      'https://telemetry.invalid',
      'fixture',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('pa_record_app_telemetry')) {
          batches.add(
            Map<String, dynamic>.from(
              jsonDecode(request.body)['p_batch'] as Map,
            ),
          );
          return http.Response(
            jsonEncode(
              failing
                  ? {'message': 'unavailable', 'code': '503'}
                  : {'ok': true},
            ),
            failing ? 503 : 200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        throw StateError('Unexpected network request');
      }),
    );
    await restoreFixture(client);
    telemetry = AppTelemetryService(
      client,
      deviceCollector: () async => {'device_model': 'Fixture'},
      installationLoader: () async => '40000000-0000-4000-8000-000000000001',
    );
    AppTelemetryService.active = telemetry;
  });
  tearDown(() async {
    await telemetry.dispose();
    await client.dispose();
  });

  test(
    'failed batches keep stable event IDs and order until acknowledged',
    () async {
      failing = true;
      telemetry.event('action', 'example', outcome: 'success');
      telemetry.event('error', 'TimeoutException', outcome: 'failure');
      await telemetry.flush();
      expect(telemetry.queuedEvents, 2);
      final first = batches.single['events'];
      failing = false;
      await telemetry.flush();
      expect(batches.last['events'], first);
      expect((first as List).map((e) => e['ordinal']), [1, 2]);
      expect(telemetry.queuedEvents, 0);
    },
  );

  test(
    'queue is bounded and rejects private route data or malformed events',
    () {
      for (var i = 0; i < 110; i++) {
        telemetry.event('error', 'E$i');
      }
      expect(telemetry.queuedEvents, 100);
      telemetry.section('/profile/$userA');
      expect(telemetry.currentSection, 'home');
      telemetry.event('unknown', 'bad');
      telemetry.event('action', 'email@example.invalid');
      telemetry.event('action', 'ok', outcome: 'not_a_status');
      expect(telemetry.queuedEvents, 100);
    },
  );

  test(
    'late HTTP result from another account is never logged for current user',
    () async {
      final release = Completer<void>();
      final transport = ObservedHttpClient(
        MockClient((request) async {
          await release.future;
          return http.Response('failed', 500, request: request);
        }),
      );
      final pending = transport.get(
        Uri.parse('https://fixture.invalid/rest/v1/profiles'),
      );
      await Future<void>.delayed(Duration.zero);
      await restoreFixture(client, userB);
      release.complete();
      await pending;
      expect(telemetry.queuedEvents, 0);
      transport.close();
    },
  );

  test('telemetry transport never observes itself', () async {
    final transport = ObservedHttpClient(
      MockClient((request) async => http.Response('{}', 200, request: request)),
    );
    await transport.post(
      Uri.parse('https://fixture.invalid/rest/v1/rpc/pa_record_app_telemetry'),
    );
    expect(telemetry.queuedEvents, 0);
    transport.close();
  });

  test(
    'back, dialog and replacement retain the actual visible section',
    () async {
      final observer = AppSectionObserver();
      Route<void> route(String name) => MaterialPageRoute<void>(
        settings: RouteSettings(name: name),
        builder: (_) => const SizedBox(),
      );
      final shell = route('/'),
          create = route('/create'),
          dialog = route('/dialog/$userA'),
          replacement = route('/replacement');
      observer.didPush(shell, null);
      observer.register(shell, 'shell');
      observer.selectTab('tools');
      expect(telemetry.currentSection, 'tools');
      observer.didPush(create, shell);
      observer.register(create, 'create_ad');
      expect(telemetry.currentSection, 'create_ad');
      observer.didPush(dialog, create);
      expect(telemetry.currentSection, 'create_ad');
      observer.didReplace(oldRoute: shell, newRoute: replacement);
      observer.register(replacement, 'shell');
      expect(telemetry.currentSection, 'create_ad');
      observer.didPop(dialog, create);
      observer.didPop(create, replacement);
      expect(telemetry.currentSection, 'tools');
      await telemetry.flush();
      expect(jsonEncode(batches), isNot(contains(userA)));
    },
  );
}
