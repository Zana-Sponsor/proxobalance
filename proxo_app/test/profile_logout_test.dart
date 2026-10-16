import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/main.dart' as app;
import 'package:proxo_app/screens/auth_screen.dart';
import 'package:proxo_app/screens/profile_screen.dart';
import 'package:proxo_app/theme/app_locale.dart';
import '../integration_test/support/actual_screen_fixtures.dart';

void main() {
  final backend = ActualScreenBackend(allowLogout: true);
  late String initialSession;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await backend.initialize();
    initialSession = jsonEncode(backend.client.auth.currentSession!.toJson());
  });
  tearDownAll(backend.dispose);
  setUp(() async {
    backend.logoutRequests = 0;
    await backend.client.auth.recoverSession(initialSession);
  });

  for (final remoteFails in [false, true]) {
    testWidgets('profile logout clears the protected stack without AuthGate (remote fails: $remoteFails)', (t) async {
      backend.logoutFails = remoteFails;
      await t.pumpWidget(MaterialApp(navigatorKey: app.navigatorKey,
        builder: (_, child) => ProxoLocaleScope(child: child!),
        home: const ProfileScreen()));
      await t.pumpAndSettle();
      final logout = find.text('دەرچوون');
      await t.ensureVisible(logout);
      await t.pumpAndSettle();
      expect(logout.hitTestable(), findsOneWidget);
      await t.tap(logout.hitTestable());
      await t.pumpAndSettle();
      await t.tap(find.text('دەرچوون').hitTestable().last);
      // SharedPreferences/SDK storage completes outside the widget fake clock.
      // Wait for the observable navigation, then keep every logout assertion.
      for (var i = 0; i < 40 && find.byType(AuthScreen).evaluate().isEmpty; i++) {
        await t.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(backend.logoutRequests, 1);
      expect(backend.client.auth.currentSession, isNull);
      expect(find.byType(AuthScreen), findsOneWidget);
      await t.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsNothing);
      expect(app.navigatorKey.currentState!.canPop(), false);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox()); await t.pumpAndSettle();
    });
  }
}
