import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:proxo_app/screens/profile_screen.dart';
import 'package:proxo_app/screens/auth_screen.dart';
import 'package:proxo_app/main.dart' as app;
import 'package:proxo_app/screens/faq_screen.dart';
import 'package:proxo_app/theme/proxo_ui.dart';
import 'package:proxo_app/widgets/notification_bell.dart';
import 'package:proxo_app/widgets/proxo_sidebar.dart';
import 'package:proxo_app/widgets/top_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support/visual_capture.dart';

const _name = 'ئارام محەمەد ئەحمەد ناوێکی درێژ بۆ تاقیکردنەوەی پرۆفایل';
const _uid = '11111111-1111-4111-8111-111111111111';

Future<SupabaseClient> _fixtureClient({bool missing = false,
  Completer<http.Response>? logoutResponse, VoidCallback? onLogout}) async {
  final transport = MockClient((request) async {
    if (request.url.path.endsWith('/logout')) {
      onLogout?.call();
      if (logoutResponse != null) return logoutResponse.future;
    }
    Object result = [];
    if (request.url.path.endsWith('/profiles')) {
      result = {
        'full_name': missing ? '' : _name,
        'email': missing ? '' : 'demo@example.invalid',
        'phone': '',
        'avatar_url': null
      };
    } else if (request.url.path.endsWith('/pa_wallets')) {
      result = {'balance': 125};
    } else if (request.url.path.endsWith('/pa_notifications')) {
      result = [
        {'id': 'fixture-notification'}
      ];
    }
    return http.Response(jsonEncode(result), 200,
        request: request, headers: {'content-type': 'application/json'});
  });
  final client = SupabaseClient('https://fixture.invalid', 'fixture-only',
      httpClient: transport,
      authOptions: const AuthClientOptions(autoRefreshToken: false));
  String tokenPart(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final token = '${tokenPart({'alg': 'HS256'})}.${tokenPart({
        'sub': _uid,
        'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600
      })}.fixture';
  await client.auth.recoverSession(jsonEncode(Session(
          accessToken: token,
          tokenType: 'bearer',
          user: User(
              id: _uid,
              appMetadata: const {},
              userMetadata: {'full_name': missing ? '' : _name},
              email: missing ? null : 'demo@example.invalid',
              aud: 'authenticated',
              createdAt: '2026-01-01T00:00:00Z'))
      .toJson()));
  return client;
}

Widget _app(Widget child, {double textScale = 1}) => visualCapture(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildProxoTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: Directionality(textDirection: TextDirection.rtl, child: child!),
      ),
      home: child,
    ));

void main() {
  ProxoVisualBinding();
  setUpAll(() async {
    await loadVisualFonts();
    app.supabase = SupabaseClient('https://fixture.invalid', 'fixture-only',
      httpClient: MockClient((request) async => http.Response('{}', 200,
        request: request, headers: {'content-type': 'application/json'})),
      authOptions: const AuthClientOptions(autoRefreshToken: false));
  });
  tearDownAll(() => app.supabase.dispose());

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    final label = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('app bar $label targets, badge and callbacks', (tester) async {
      setVisualViewport(tester, size);
      var menu = 0;
      var notifications = 0;
      await tester.pumpWidget(_app(Scaffold(
          appBar: ProxoTopBar(
              notificationCount: 101,
              onMenuTap: () => menu++,
              onNotificationTap: () => notifications++))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(NotificationBell)), const Size(48, 48));
      expect(find.text('99+'), findsOneWidget);
      await tester.tap(find.byTooltip('مێنیو'));
      await tester.tap(find.byTooltip('ئاگادارییەکان'));
      expect(menu, 1);
      expect(notifications, 1);
      await captureVisual(tester, 'app-bar-badge-$label');
    });

    testWidgets('profile $label long text, scroll and quick action',
        (tester) async {
      setVisualViewport(tester, size);
      final client = (await tester.runAsync(_fixtureClient))!;
      addTearDown(client.dispose);
      int? selected;
      await tester.pumpWidget(_app(ProfileScreen(
          client: client,
          listenToRealtime: false,
          onBottomNavTap: (value) => selected = value)));
      await tester.pumpAndSettle();
      expect(find.text(_name), findsOneWidget);
      expect(tester.takeException(), isNull);
      await captureVisual(tester, 'profile-top-$label');
      await tester.ensureVisible(find.text('ڕیکلامەکانم'));
      await tester.tap(find.text('ڕیکلامەکانم'));
      expect(selected, 1);
      await tester.drag(find.byType(ListView).first, const Offset(0, -700));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('دەرچوون'));
      expect(tester.takeException(), isNull);
      await captureVisual(tester, 'profile-bottom-$label');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('menu $label scrolls and routes Home once', (tester) async {
      setVisualViewport(tester, size);
      final client = (await tester.runAsync(_fixtureClient))!;
      addTearDown(client.dispose);
      final navigations = <String>[];
      var closed = 0;
      await tester.pumpWidget(_app(Scaffold(
          body: Align(
              alignment: Alignment.centerRight,
              child: ProxoSidebar(
                  client: client,
                  selectedRoute: 'ads',
                  onClose: () => closed++,
                  onNavigate: navigations.add)))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await captureVisual(tester, 'menu-top-$label');
      await tester.ensureVisible(find.text('چوونەدەرەوە'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await captureVisual(tester, 'menu-bottom-$label');
      await tester.ensureVisible(find.text('سەرەکی'));
      await tester.tap(find.text('سەرەکی'));
      await tester.tap(find.text('سەرەکی'));
      expect(navigations, ['home']);
      expect(closed, 1);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('edit profile keyboard and invalid email stay accessible', (tester) async {
    setVisualViewport(tester, const Size(320, 568));
    final client = (await tester.runAsync(() => _fixtureClient()))!;
    addTearDown(client.dispose);
    await tester.pumpWidget(_app(EditProfileScreen(client: client,
      initialFullName: _name, initialEmail: 'demo@gmail.com', initialPhone: '')));
    await tester.pumpAndSettle();
    await captureVisual(tester, 'profile-edit-top-320x568');
    final email = find.byWidgetPredicate((widget) => widget is TextFormField &&
      widget.controller != null);
    await tester.ensureVisible(email);
    await tester.enterText(email, 'invalid');
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    addTearDown(tester.view.resetViewInsets);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('ناونیشانی ئیمەیڵەکە دروست نییە.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(email);
    await captureVisual(tester, 'profile-edit-validation-keyboard-320x568');
    tester.view.resetViewInsets();
    tester.testTextInput.hide();
    await tester.ensureVisible(find.text('ناوچەی مەترسیدار'));
    await tester.pumpAndSettle();
    await captureVisual(tester, 'profile-edit-bottom-320x568');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('profile missing data and 150 percent text remain scrollable',
      (tester) async {
    setVisualViewport(tester, const Size(320, 568));
    final client =
        (await tester.runAsync(() => _fixtureClient(missing: true)))!;
    addTearDown(client.dispose);
    await tester.pumpWidget(_app(
        ProfileScreen(
            client: client, listenToRealtime: false, onBottomNavTap: (_) {}),
        textScale: 1.5));
    await tester.pumpAndSettle();
    expect(find.text('بەکارهێنەر'), findsOneWidget);
    expect(find.text('زانیاری پەیوەندی زیاد نەکراوە'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await captureVisual(tester, 'profile-missing-large-text-320x568');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('menu logout rejects repeated requests and clears navigation after server failure', (tester) async {
    setVisualViewport(tester, const Size(320, 568));
    final response = Completer<http.Response>();
    var requests = 0;
    final client = (await tester.runAsync(() => _fixtureClient(
      logoutResponse: response, onLogout: () => requests++)))!;
    addTearDown(client.dispose);
    await tester.pumpWidget(_app(Scaffold(body: ProxoSidebar(client: client, onClose: () {}))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('چوونەدەرەوە'));
    await tester.tap(find.text('چوونەدەرەوە'));
    await tester.tap(find.text('چوونەدەرەوە'));
    await tester.pump();
    expect(requests, 1);
    response.complete(http.Response('{"message":"temporarily unavailable"}', 503,
      headers: {'content-type': 'application/json'}));
    await tester.pumpAndSettle();
    expect(client.auth.currentSession, isNull);
    expect(find.byType(ProxoSidebar), findsNothing);
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(Navigator.of(tester.element(find.byType(AuthScreen))).canPop(), isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('drawer opens, dismisses from scrim, and closes from its control', (tester) async {
    setVisualViewport(tester, const Size(320, 568));
    final client = (await tester.runAsync(() => _fixtureClient()))!;
    addTearDown(client.dispose);
    final scaffold = GlobalKey<ScaffoldState>();
    await tester.pumpWidget(_app(Directionality(textDirection: TextDirection.ltr,
      child: Scaffold(key: scaffold,
        endDrawer: ProxoSidebar(client: client, onClose: () => scaffold.currentState!.closeEndDrawer()),
        body: Center(child: FilledButton(onPressed: () => scaffold.currentState!.openEndDrawer(),
          child: const Text('open-menu')))))));
    await tester.tap(find.text('open-menu'));
    await tester.pumpAndSettle();
    expect(scaffold.currentState!.isEndDrawerOpen, isTrue);
    await captureVisual(tester, 'menu-open-drawer-320x568');
    await tester.tapAt(const Offset(12, 100));
    await tester.pumpAndSettle();
    expect(scaffold.currentState!.isEndDrawerOpen, isFalse);
    await tester.tap(find.text('open-menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('داخستن'));
    await tester.pumpAndSettle();
    expect(scaffold.currentState!.isEndDrawerOpen, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('menu Help opens its destination and repeated taps do not stack',
      (tester) async {
    setVisualViewport(tester, const Size(320, 568));
    final client = (await tester.runAsync(_fixtureClient))!;
    addTearDown(client.dispose);
    await tester.pumpWidget(
        _app(Scaffold(body: ProxoSidebar(client: client, onClose: () {}))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('یارمەتی و پشتگیری'));
    await tester.tap(find.text('یارمەتی و پشتگیری'));
    await tester.tap(find.text('یارمەتی و پشتگیری'));
    await tester.pumpAndSettle();
    expect(find.byType(FaqScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
