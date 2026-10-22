import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/screens/auth_screen.dart';
import 'package:proxo_app/screens/faq_screen.dart';
import 'package:proxo_app/theme/app_locale.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/widgets/proxo_sidebar.dart';
import 'package:proxo_app/widgets/top_bar.dart';
import '../integration_test/support/actual_screen_fixtures.dart';

class _Routes extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
  }
}

void main() {
  final backend = ActualScreenBackend(allowLogout: true);
  late String session;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await backend.initialize();
    session = jsonEncode(backend.client.auth.currentSession!.toJson());
  });
  tearDownAll(backend.dispose);
  setUp(() async {
    backend.logoutRequests = 0;
    backend.logoutFails = false;
    await backend.client.auth.recoverSession(session);
  });

  Widget host(Widget child,
          {GlobalKey<NavigatorState>? navigatorKey,
          NavigatorObserver? observer}) =>
      MaterialApp(
          navigatorKey: navigatorKey,
          navigatorObservers: [if (observer != null) observer],
          theme: buildAppTheme(),
          builder: (_, child) => ProxoLocaleScope(child: child!),
          home: child);

  testWidgets('repeated bell taps cannot stack notification routes', (t) async {
    final nav = GlobalKey<NavigatorState>();
    final observer = _Routes();
    await t.pumpWidget(host(
        Scaffold(
            appBar: ProxoTopBar(
          onNotificationTap: () => nav.currentState!.push(
              MaterialPageRoute<void>(
                  builder: (_) =>
                      const Scaffold(body: Text('notification detail')))),
        )),
        navigatorKey: nav,
        observer: observer));
    await t.pumpAndSettle();
    final bell = find.byKey(const ValueKey('notification-bell-target'));
    final tap = t
        .widget<IconButton>(
            find.descendant(of: bell, matching: find.byType(IconButton)))
        .onPressed!;
    tap();
    tap();
    await t.pumpAndSettle();
    expect(observer.pushes, 2);
    expect(find.text('notification detail'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'drawer route captures its own navigator, closes once and ignores repeated taps',
      (t) async {
    final nav = GlobalKey<NavigatorState>();
    final observer = _Routes();
    var open = true;
    var closes = 0;
    await t.pumpWidget(host(
        StatefulBuilder(
            builder: (_, setState) => Scaffold(
                  body: open
                      ? ProxoSidebar(onClose: () {
                          closes++;
                          setState(() => open = false);
                        })
                      : const Text('original route'),
                )),
        navigatorKey: nav,
        observer: observer));
    await t.pumpAndSettle();
    final help = find.byKey(const ValueKey('sidebar-help'));
    await t.ensureVisible(help);
    await t.pumpAndSettle();
    // Invoke two taps before a frame can remove the drawer.
    final tap = t.widget<InkWell>(help).onTap!;
    tap();
    tap();
    await t.pump(const Duration(milliseconds: 300));
    await t.pumpAndSettle();
    expect(closes, 1);
    expect(observer.pushes, 2); // initial route + one FAQ
    expect(find.byType(FaqScreen), findsOneWidget);
    nav.currentState!.pop();
    await t.pumpAndSettle();
    expect(find.text('original route'), findsOneWidget);
    expect(nav.currentState!.canPop(), false);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'pending drawer navigation cannot reopen private UI after session clears',
      (t) async {
    final nav = GlobalKey<NavigatorState>();
    final observer = _Routes();
    await t.pumpWidget(host(const Scaffold(body: ProxoSidebar()),
        navigatorKey: nav, observer: observer));
    await t.pumpAndSettle();
    final help = find.byKey(const ValueKey('sidebar-help'));
    await t.ensureVisible(help);
    await t.pumpAndSettle();
    await t.tap(help);
    await t.runAsync(() => backend.client.auth.signOut());
    await t.pump(const Duration(milliseconds: 300));
    await t.pumpAndSettle();
    expect(observer.pushes, 1);
    expect(find.byType(FaqScreen), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('failed logout keeps the account visible and can be retried once',
      (t) async {
    final nav = GlobalKey<NavigatorState>();
    final gate = Completer<void>();
    var calls = 0;
    await t.pumpWidget(host(Scaffold(body: ProxoSidebar(signOut: () async {
      calls++;
      await gate.future;
      throw StateError('fixture failure before local logout');
    })), navigatorKey: nav));
    await t.pumpAndSettle();
    final logout = find.byKey(const ValueKey('sidebar-logout'));
    await t.ensureVisible(logout);
    await t.pumpAndSettle();
    final tap = t.widget<InkWell>(logout).onTap!;
    tap();
    tap();
    await t.pump();
    expect(calls, 1);
    expect(find.text('دەرچوون…'), findsOneWidget);
    expect(t.widget<InkWell>(find.byKey(const ValueKey('sidebar-help'))).onTap,
        isNull);
    gate.complete();
    await t.pumpAndSettle();
    expect(backend.client.auth.currentSession, isNotNull);
    expect(find.byKey(const ValueKey('sidebar-logout-error')), findsOneWidget);
    expect(find.byType(AuthScreen), findsNothing);
    expect(nav.currentState!.canPop(), false);
    await t.ensureVisible(logout);
    await t.pumpAndSettle();
    await t.tap(logout);
    await t.pumpAndSettle();
    expect(calls, 2);
    expect(t.takeException(), isNull);
  });

  testWidgets('app auth listener wins without a second logout route',
      (t) async {
    final nav = GlobalKey<NavigatorState>();
    final observer = _Routes();
    var redirected = false;
    final auth = backend.client.auth.onAuthStateChange.listen((event) {
      if (event.session != null || redirected) return;
      redirected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nav.currentState!.pushAndRemoveUntil(
            MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('app auth gate'))),
            (_) => false);
      });
    });
    addTearDown(auth.cancel);
    await t.pumpWidget(host(const Scaffold(body: ProxoSidebar()),
        navigatorKey: nav, observer: observer));
    await t.pumpAndSettle();
    final logout = find.byKey(const ValueKey('sidebar-logout'));
    await t.ensureVisible(logout);
    await t.pumpAndSettle();
    await t.tap(logout);
    for (var i = 0; i < 50 && !redirected; i++) {
      await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)));
      await t.pump(const Duration(milliseconds: 100));
    }
    await t.pumpAndSettle();
    expect(redirected, true);
    expect(observer.pushes, 2); // initial private screen + app-owned auth gate
    expect(find.text('app auth gate'), findsOneWidget);
    expect(find.byType(AuthScreen), findsNothing);
    expect(nav.currentState!.canPop(), false);
    expect(t.takeException(), isNull);
  });

  for (final remoteFails in [false, true]) {
    testWidgets(
        'logout clears private stack without global navigator, remote failure: $remoteFails',
        (t) async {
      backend.logoutFails = remoteFails;
      final nav = GlobalKey<NavigatorState>();
      await t.pumpWidget(host(const Scaffold(body: Text('protected root')),
          navigatorKey: nav));
      nav.currentState!.push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: ProxoSidebar())));
      await t.pumpAndSettle();
      final logout = find.byKey(const ValueKey('sidebar-logout'));
      await t.ensureVisible(logout);
      await t.pumpAndSettle();
      await t.tap(logout);
      for (var i = 0;
          i < 50 && find.byType(AuthScreen).evaluate().isEmpty;
          i++) {
        await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)));
        await t.pump(const Duration(milliseconds: 100));
      }
      await t.pumpAndSettle();
      expect(backend.logoutRequests, 1);
      expect(backend.client.auth.currentSession, isNull);
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.byType(ProxoSidebar), findsNothing);
      expect(find.text('protected root'), findsNothing);
      expect(nav.currentState!.canPop(), false);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('logout completion after drawer disposal is safe', (t) async {
    final gate = Completer<void>();
    var open = true;
    await t.pumpWidget(host(StatefulBuilder(
        builder: (_, setState) => Scaffold(
              body: open
                  ? ProxoSidebar(
                      signOut: () => gate.future,
                      onClose: () => setState(() => open = false))
                  : const Text('closed'),
            ))));
    await t.pumpAndSettle();
    final logout = find.byKey(const ValueKey('sidebar-logout'));
    await t.ensureVisible(logout);
    await t.pumpAndSettle();
    await t.tap(logout);
    await t.pump();
    final close = find.byKey(const ValueKey('sidebar-close'));
    await t.ensureVisible(close);
    await t.pump();
    await t.tap(close);
    await t.pump();
    gate.complete();
    await t.pumpAndSettle();
    expect(find.text('closed'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
