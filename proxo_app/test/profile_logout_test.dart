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
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await backend.initialize();
  });
  tearDownAll(backend.dispose);

  testWidgets('profile logout clears the protected stack without an AuthGate route', (t) async {
    await t.pumpWidget(MaterialApp(navigatorKey: app.navigatorKey,
      builder: (_, child) => ProxoLocaleScope(child: child!),
      home: const ProfileScreen()));
    await t.pumpAndSettle();
    final logout = find.text('دەرچوون');
    await t.ensureVisible(logout); await t.tap(logout); await t.pumpAndSettle();
    await t.tap(find.text('دەرچوون').last); await t.pumpAndSettle();
    expect(backend.logoutRequests, 1);
    expect(backend.client.auth.currentSession, isNull);
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.byType(ProfileScreen), findsNothing);
    expect(app.navigatorKey.currentState!.canPop(), false);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox()); await t.pumpAndSettle();
  });
}
