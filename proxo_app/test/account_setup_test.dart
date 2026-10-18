import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:proxo_app/services/account_setup_service.dart';
import 'package:proxo_app/screens/account_setup_screen.dart';

import 'support/session_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late AccountSetupService setup;
  final paths = <String>[];
  Completer<void>? blocked;
  bool fail = false, readable = true;
  setUp(() async {
    paths.clear();
    blocked = null;
    fail = false;
    readable = true;
    client = SupabaseClient(
      'https://setup-fixture.invalid',
      'fixture',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((q) async {
        paths.add(q.url.path);
        final owner = client.auth.currentUser!.id;
        dynamic body;
        int code = 200;
        if (q.url.path == '/auth/v1/user') {
          body = sessionFor(owner).user.toJson();
        } else if (q.url.path.endsWith('pa_ensure_account_ready')) {
          if (blocked != null) await blocked!.future;
          body = fail
              ? {'code': 'fixture_failure', 'message': 'fixture'}
              : {'ready': true, 'user_id': owner};
          if (fail) code = 503;
        } else if (q.url.path.startsWith('/rest/v1/')) {
          body = readable ? {'id': owner, 'user_id': owner} : null;
        } else {
          throw StateError('Unexpected network');
        }
        return http.Response(
          jsonEncode(body),
          code,
          headers: {'content-type': 'application/json'},
          request: q,
        );
      }),
    );
    await restoreFixture(client);
    setup = AccountSetupService(client);
  });
  tearDown(() async {
    await client.dispose();
  });
  test('one authoritative provisioning request, readable records and cached session readiness', () async {
    await Future.wait([setup.ensure(), setup.ensure(), setup.ensure()]);
    expect(setup.isReady, isTrue);
    expect(paths.where((p) => p.endsWith('pa_ensure_account_ready')).length, 1);
    expect(paths.where((p) => p.endsWith('/profiles')).length, 1);
    expect(paths.where((p) => p.endsWith('/pa_wallets')).length, 1);
    final before = paths.length;
    await setup.ensure();
    expect(paths.length, before);
    expect(
      paths.any((p) => p.contains('signup') || p.contains('token')),
      isFalse,
    );
  });
  test('provisioning failure can retry without a new Auth account', () async {
    fail = true;
    await expectLater(setup.ensure(), throwsA(anything));
    expect(setup.isReady, isFalse);
    fail = false;
    await setup.ensure();
    expect(setup.isReady, isTrue);
    expect(paths.where((p) => p.endsWith('pa_ensure_account_ready')).length, 2);
  });
  test('RPC success cannot hide records denied by RLS', () async {
    readable = false;
    await expectLater(setup.ensure(), throwsA(anything));
    expect(setup.isReady, isFalse);
    readable = true;
    await setup.ensure();
    expect(setup.isReady, isTrue);
  });
  test('restart revalidates setup and resumes the existing user', () async {
    await setup.ensure();
    final restarted = AccountSetupService(client);
    expect(restarted.isReady, isFalse);
    await restarted.ensure();
    expect(restarted.isReady, isTrue);
    expect(paths.where((p) => p.endsWith('pa_ensure_account_ready')).length, 2);
  });
  test('old provisioning response cannot unlock another account', () async {
    blocked = Completer<void>();
    final old = setup.ensure();
    final rejection = expectLater(old, throwsA(isA<StateError>()));
    await Future<void>.delayed(Duration.zero);
    await restoreFixture(client, userB);
    blocked!.complete();
    await rejection;
    expect(setup.isReady, isFalse);
    blocked = null;
    await setup.ensure();
    expect(setup.isReady, isTrue);
  });
  testWidgets(
    'slow setup shows indeterminate loading and never builds home early',
    (t) async {
      blocked = Completer<void>();
      await t.pumpWidget(
        MaterialApp(
          home: AccountSetupGate(
            service: setup,
            child: const Text('PRIVATE_HOME'),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 50));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('PRIVATE_HOME'), findsNothing);
      blocked!.complete();
      await t.pumpAndSettle();
      expect(find.text('PRIVATE_HOME'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'failed setup offers retry and can recover after widget termination',
    (t) async {
      fail = true;
      await t.pumpWidget(
        MaterialApp(
          home: AccountSetupGate(
            service: setup,
            child: const Text('PRIVATE_HOME'),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text('PRIVATE_HOME'), findsNothing);
      fail = false;
      await t.ensureVisible(find.byType(FilledButton));
      await t.tap(find.byType(FilledButton));
      await t.pumpAndSettle();
      expect(find.text('PRIVATE_HOME'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      final restarted = AccountSetupService(client);
      blocked = Completer<void>();
      await t.pumpWidget(
        MaterialApp(
          home: AccountSetupGate(
            service: restarted,
            child: const Text('PRIVATE_HOME'),
          ),
        ),
      );
      await t.pump();
      expect(find.text('PRIVATE_HOME'), findsNothing);
      await t.pumpWidget(const SizedBox());
      blocked!.complete();
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    },
  );
}
