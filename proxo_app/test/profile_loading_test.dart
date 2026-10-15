import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:proxo_app/main.dart' as app;
import 'package:proxo_app/screens/profile_screen.dart';
import 'package:proxo_app/theme/app_locale.dart';
import 'package:proxo_app/widgets/proxo_refresh.dart';

import '../integration_test/support/actual_screen_fixtures.dart';

void main() {
  final backend = ActualScreenBackend();
  const before = bool.fromEnvironment('PROXO_PROFILE_BEFORE');

  setUpAll(() async {
    final fonts = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family'] as String);
      for (final file in font['fonts'] as List) {
        loader.addFont(rootBundle.load(file['asset'] as String));
      }
      await loader.load();
    }
    SharedPreferences.setMockInitialValues({});
    await backend.initialize();
  });
  tearDownAll(backend.dispose);
  tearDown(() {
    for (final gate in backend.readGates.values) {
      if (!gate.isCompleted) gate.complete();
    }
    backend.readGates.clear();
    backend.readResponses.clear();
  });

  Widget host() => MaterialApp(
    navigatorKey: app.navigatorKey,
    builder: (_, child) => ProxoLocaleScope(child: child!),
    home: const ProfileScreen(),
  );
  Map<String, Object> row(String name) => {
    'full_name': name, 'email': 'fixture@example.invalid',
    'phone': '+9647500000000',
  };
  Future<void> settle(WidgetTester t) async {
    await t.pump();
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  }
  Future<void> Function() refresh(WidgetTester t) =>
      t.widget<ProxoRefresh>(find.byType(ProxoRefresh)).onRefresh;
  double? balance(WidgetTester t) => t.widget<ValueListenableBuilder<double?>>(
    find.byWidgetPredicate((w) => w is ValueListenableBuilder<double?>),
  ).valueListenable.value;

  testWidgets('Profile coalesces overlapping reads and later refresh stays fresh', (t) async {
    final gate = Completer<void>();
    backend.readGates.addAll({'profiles': gate, 'pa_wallets': gate});
    final profileReads = backend.reads['profiles'] ?? 0;
    final walletReads = backend.reads['pa_wallets'] ?? 0;
    await t.pumpWidget(host()); await t.pump();
    final retained = t.state(find.byType(ProfileScreen));
    final first = refresh(t)(), second = refresh(t)();
    await t.pump();
    final expected = before ? 3 : 1;
    expect(backend.reads['profiles']! - profileReads, expected);
    expect(backend.reads['pa_wallets']! - walletReads, expected);
    debugPrint('PROFILE_READS initial+two-overlaps: profiles=$expected wallets=$expected');
    gate.complete(); backend.readGates.clear();
    await t.pump(); await first; await second; await settle(t);
    backend.readResponses['profiles'] = row('Fresh manual refresh');
    await refresh(t)(); await settle(t);
    expect(backend.reads['profiles']! - profileReads, expected + 1);
    expect(backend.reads['pa_wallets']! - walletReads, expected + 1);
    expect(find.text('Fresh manual refresh'), findsOneWidget);
    expect(t.state(find.byType(ProfileScreen)), same(retained));
    await t.pumpWidget(const SizedBox()); await settle(t);
  });

  testWidgets('returning from a saved edit supersedes a pending older read', (t) async {
    await t.pumpWidget(host()); await settle(t);
    final gate = Completer<void>();
    backend.readGates.addAll({'profiles': gate, 'pa_wallets': gate});
    backend.readResponses['profiles'] = row('Old pending profile');
    backend.readResponses['pa_wallets'] = {'balance': 10};
    final older = refresh(t)(); await t.pump();
    final reads = backend.reads['profiles']!;

    await t.tap(find.byTooltip('دەستکاری پڕۆفایل')); await settle(t);
    expect(find.byType(EditProfileScreen), findsOneWidget);
    // Return the actual edit route's success result. No profile mutation or
    // email delivery is performed by this read-only navigation fixture.
    backend.readGates.clear();
    backend.readResponses['profiles'] = row('Saved profile');
    backend.readResponses['pa_wallets'] = {'balance': 20};
    app.navigatorKey.currentState!.pop(true); await settle(t);
    expect(backend.reads['profiles']! - reads, 1);
    expect(find.text('Saved profile'), findsOneWidget);
    expect(balance(t), 20 * app.kIqdRate);
    gate.complete(); await t.pump(); await older; await settle(t);
    expect(find.text('Old pending profile'), findsNothing);
    expect(find.text('Saved profile'), findsOneWidget);
    expect(balance(t), 20 * app.kIqdRate);
    await t.pumpWidget(const SizedBox()); await settle(t);
  });

  testWidgets('live profile and wallet updates survive a late read response', (t) async {
    await t.pumpWidget(host()); await settle(t);
    final gate = Completer<void>();
    backend.readGates.addAll({'profiles': gate, 'pa_wallets': gate});
    backend.readResponses['profiles'] = row('Old read');
    backend.readResponses['pa_wallets'] = {'balance': 10};
    final older = refresh(t)(); await t.pump();
    backend.emitProfileChange({'id': screenFixtureOwner, ...row('Live profile')});
    backend.emitProfileChange({'user_id': screenFixtureOwner, 'balance': 30}, wallet: true);
    await settle(t);
    expect(find.text('Live profile'), findsOneWidget);
    expect(balance(t), 30 * app.kIqdRate);
    gate.complete(); backend.readGates.clear();
    await t.pump(); await older; await settle(t);
    expect(find.text('Old read'), findsNothing);
    expect(find.text('Live profile'), findsOneWidget);
    expect(balance(t), 30 * app.kIqdRate);
    await t.pumpWidget(const SizedBox()); await settle(t);
  });

  testWidgets('pending reads cannot apply after the authenticated owner changes', (t) async {
    final session = jsonEncode(backend.client.auth.currentSession!.toJson());
    final gate = Completer<void>();
    backend.readGates.addAll({'profiles': gate, 'pa_wallets': gate});
    backend.readResponses['profiles'] = row('Former owner');
    await t.pumpWidget(host()); await t.pump();
    try {
      const other = '00000000-0000-4000-8000-000000000098';
      String part(Object value) => base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
      final token = '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({'sub': other, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 86400})}.fictional-signature';
      await backend.client.auth.recoverSession(jsonEncode(Session(
        accessToken: token, tokenType: 'bearer',
        user: const User(id: other, appMetadata: {}, userMetadata: {},
          aud: 'authenticated', createdAt: '2026-10-15T00:00:00Z'),
      ).toJson()));
      expect(backend.client.auth.currentUser!.id, other);
      gate.complete(); backend.readGates.clear(); await settle(t);
      expect(find.text('Former owner'), findsNothing);
      expect(balance(t), isNull);
    } finally {
      if (!gate.isCompleted) gate.complete();
      await t.pumpWidget(const SizedBox()); await settle(t);
      await backend.client.auth.recoverSession(session);
    }
  });

  testWidgets('closing Profile while its reads are pending is safe', (t) async {
    final gate = Completer<void>();
    backend.readGates.addAll({'profiles': gate, 'pa_wallets': gate});
    await t.pumpWidget(host()); await t.pump();
    final running = refresh(t)(); await t.pump();
    await t.pumpWidget(const SizedBox());
    gate.complete(); backend.readGates.clear();
    await t.pump(); await running; await settle(t);
  });
}
