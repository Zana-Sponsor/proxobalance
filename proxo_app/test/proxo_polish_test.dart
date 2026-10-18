import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:proxo_app/screens/authenticated_gate.dart';
import 'package:proxo_app/screens/account_setup_screen.dart';
import 'package:proxo_app/screens/splash_screen.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/theme/app_locale.dart';
import 'package:proxo_app/widgets/proxo_refresh.dart';
import 'package:proxo_app/widgets/auth/auth_swap.dart';
import 'support/session_fixture.dart';

void main() {
  testWidgets(
      'returning session opens home without profile provisioning or network',
      (t) async {
    late SupabaseClient client;
    final requests = <String>[];
    await t.runAsync(() async {
      client = SupabaseClient('https://fixture.invalid', 'fixture',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((r) async {
        requests.add(r.url.path);
        return http.Response(jsonEncode(sessionFor(userA).user.toJson()), 200,
            headers: {'content-type': 'application/json'});
      }));
      await restoreFixture(client);
    });
    requests.clear();
    await t.pumpWidget(MaterialApp(
        home: AuthenticatedGate(
            client: client, child: const Text('RETURNING_HOME'))));
    await t.pump();
    expect(find.text('RETURNING_HOME'), findsOneWidget);
    expect(find.byType(AccountSetupView), findsNothing);
    expect(requests, isEmpty);
    await t.pumpWidget(const SizedBox());
    await t.runAsync(client.dispose);
  });

  testWidgets('channel transition never paints two forms at once', (t) async {
    Widget host(String name) => MaterialApp(
        home: AuthSwap(
            child: SizedBox(
                key: ValueKey(name),
                height: name == 'email' ? 300 : 150,
                child: Text(name))));
    await t.pumpWidget(host('email'));
    await t.pumpWidget(host('phone'));
    await t.pump(const Duration(milliseconds: 64));
    expect(find.text('email'), findsOneWidget);
    expect(find.text('phone'), findsNothing);
    await t.pump(const Duration(milliseconds: 80));
    await t.pump();
    expect(find.text('email'), findsNothing);
    expect(find.text('phone'), findsOneWidget);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'refresh label appears with spinner, coalesces and preserves scroll state',
      (t) async {
    ProxoLocale.current.value = ProxoLocale.kurdishSorani;
    final controller = ProxoRefreshController();
    final completed = Completer<void>();
    final scroll = ScrollController();
    var calls = 0;
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ProxoRefresh(
      controller: controller,
      onRefresh: () {
        calls++;
        return completed.future;
      },
      child:
          ListView(controller: scroll, children: const [Text('kept content')]),
    ))));
    final retained = t.state(find.byType(Scrollable));
    final first = controller.refresh();
    await controller.refresh();
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('نوێدەکرێتەوە'), findsOneWidget);
    expect(calls, 1);
    expect(t.state(find.byType(Scrollable)), same(retained));
    completed.complete();
    await t.pump(const Duration(milliseconds: 600));
    await t.pumpAndSettle();
    await first;
    expect(find.text('نوێدەکرێتەوە'), findsNothing);
    expect(controller.isRefreshing, isFalse);
    expect(t.state(find.byType(Scrollable)), same(retained));
    await t.pumpWidget(const SizedBox());
    controller.dispose();
    scroll.dispose();
  });

  testWidgets(
      'reduced-motion splash finishes and transitions without ticker leaks',
      (t) async {
    await t.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => MediaQuery(
            data: const MediaQueryData(disableAnimations: true), child: child!),
        home: const SplashScreen(nextScreen: Scaffold(body: Text('READY')))));
    await t.pump(const Duration(milliseconds: 351));
    await t.pumpAndSettle();
    expect(find.text('READY'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
