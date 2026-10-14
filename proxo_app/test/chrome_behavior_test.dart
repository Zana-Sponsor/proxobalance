import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/main.dart' as app;
import 'package:proxo_app/screens/profile_screen.dart';
import 'package:proxo_app/screens/faq_screen.dart';
import 'package:proxo_app/theme/app_locale.dart';
import 'package:proxo_app/widgets/proxo_sidebar.dart';
import '../integration_test/support/actual_screen_fixtures.dart';

void main() {
  final backend = ActualScreenBackend();
  setUpAll(() async { SharedPreferences.setMockInitialValues({}); await backend.initialize(); });
  tearDownAll(backend.dispose);
  Widget host(Widget child) => MaterialApp(navigatorKey: app.navigatorKey,
    builder: (_, child) => ProxoLocaleScope(child: child!), home: child);

  testWidgets('sidebar identity does not wait for notification response or unused loyalty reads', (t) async {
    backend.unreadGate = Completer<void>();
    await t.pumpWidget(host(const Scaffold(body: ProxoSidebar())));
    await t.pumpAndSettle();
    expect(find.text('بارکردن…'), findsNothing);
    expect(find.textContaining('Proxo'), findsOneWidget);
    expect(backend.reads['pa_levels']??0, 0);
    expect(backend.reads['pa_user_points']??0, 0);
    backend.unreadGate!.complete(); backend.unreadGate = null;
    await t.pumpAndSettle();
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('sidebar selected semantics follow actual tab and FAQ survives drawer removal', (t) async {
    final semantics = t.ensureSemantics();
    try {
      bool open = true;
      await t.pumpWidget(host(StatefulBuilder(builder: (_, setState) => Scaffold(
        body: open ? ProxoSidebar(currentIndex: 4, onClose: () => setState(() => open=false)) : const Text('underlying route'),
      ))));
      await t.pumpAndSettle();
      final selected = find.byWidgetPredicate((w) => w is Semantics && w.properties.selected == true);
      expect(selected, findsOneWidget);
      expect(find.descendant(of:selected, matching:find.text('پڕۆفایل و ڕێکخستنەکان')),findsOneWidget);
      await t.ensureVisible(find.text('یارمەتی و پشتگیری')); await t.pumpAndSettle();
      await t.tap(find.text('یارمەتی و پشتگیری'));
      // _go intentionally waits 250ms for the drawer to close. An idle fake
      // clock does not advance that timer merely because no frame is pending.
      await t.pump(const Duration(milliseconds: 300));
      await t.pumpAndSettle();
      expect(find.byType(FaqScreen), findsOneWidget);
      app.navigatorKey.currentState!.pop(); await t.pumpAndSettle();
      expect(find.text('underlying route'),findsOneWidget);
      expect(t.takeException(),isNull);
    } finally { semantics.dispose(); }
    await t.pumpWidget(const SizedBox()); await t.pumpAndSettle();
  });

  testWidgets('profile edit action retains production edit route', (t) async {
    await t.pumpWidget(host(ProfileScreen(onBottomNavTap: (_) {})));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('دەستکاری پڕۆفایل')); await t.pumpAndSettle();
    expect(find.byType(EditProfileScreen),findsOneWidget);
    expect(t.takeException(),isNull);
    await t.pumpWidget(const SizedBox()); await t.pumpAndSettle();
  });
}
