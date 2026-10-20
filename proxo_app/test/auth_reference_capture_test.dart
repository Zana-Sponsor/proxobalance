import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:proxo_app/main.dart' as app;
import 'package:proxo_app/screens/auth_screen.dart';
import 'package:proxo_app/theme/app_locale.dart';
import 'package:proxo_app/theme/proxo_ui.dart';
import 'package:proxo_app/widgets/auth/auth_design.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/visual_capture.dart';

void main() {
  ProxoVisualBinding();
  setUpAll(() async {
    await loadVisualFonts();
    SharedPreferences.setMockInitialValues({});
    // The reference screen is the real AuthScreen. A transport that always
    // rejects requests prevents any accidental contact with live auth APIs.
    app.supabase = SupabaseClient(
      'https://fixture.invalid',
      'fixture-only-key',
      httpClient: MockClient((request) async {
        throw StateError('Auth reference must not request ${request.url.path}');
      }),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
  });
  tearDownAll(() => app.supabase.dispose());

  for (final size in [const Size(320, 740), const Size(430, 932)]) {
    testWidgets('capture authentication reference at ${size.width}', (t) async {
      setVisualViewport(t, size);
      ProxoLocale.current.value = ProxoLocale.kurdishSorani;
      await t.pumpWidget(visualCapture(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildProxoTheme(),
        home: const AuthScreen(),
      )));
      await t.pumpAndSettle();
      expect(find.text(AuthStrings.signInTitle), findsWidgets);
      expect(t.takeException(), isNull);
      final dimensions = '${size.width.toInt()}x${size.height.toInt()}';
      await captureVisual(t, 'auth-login-reference-$dimensions');
      await t.ensureVisible(find.text(AuthStrings.noAccountAction));
      await t.tap(find.text(AuthStrings.noAccountAction));
      await t.pumpAndSettle();
      expect(find.text(AuthStrings.signUpTitle), findsOneWidget);
      expect(t.takeException(), isNull);
      await captureVisual(t, 'auth-signup-reference-$dimensions');
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    });
  }
}
