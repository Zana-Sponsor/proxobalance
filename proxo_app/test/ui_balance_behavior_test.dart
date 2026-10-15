import 'dart:convert';
import 'package:proxo_app/widgets/tasks_page.dart';
import 'package:proxo_app/widgets/levels_page.dart';
import 'package:proxo_app/screens/tutorial_screen.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/main.dart' as app;
import 'package:proxo_app/screens/ad_screen.dart';
import 'package:proxo_app/screens/ad_create_screen.dart';
import 'package:proxo_app/screens/home_screen.dart';
import 'package:proxo_app/screens/profile_screen.dart';
import 'package:proxo_app/screens/deposit_screen.dart';
import 'package:proxo_app/theme/app_locale.dart';
import 'package:proxo_app/widgets/auth/auth_logo.dart';
import 'package:proxo_app/widgets/bottom_nav.dart';
import 'package:proxo_app/widgets/proxo_symbol.dart';
import 'package:proxo_app/widgets/proxo_refresh.dart';
import '../integration_test/support/actual_screen_fixtures.dart';

void main() {
  final backend = ActualScreenBackend();
  setUpAll(() async {
    // Load the same bundled fonts as the app; Ahem's square test glyphs do
    // not represent provider-name wrapping or Kurdish line heights.
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('flutter.baseflow.com/permissions/methods'),
            (_) async => 1);
  });
  tearDownAll(backend.dispose);
  Widget host(Widget child) => MaterialApp(
      navigatorKey: app.navigatorKey,
      builder: (_, child) => ProxoLocaleScope(child: child!), home: child);
  void phone(WidgetTester t) {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(393, 852);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }
  Future<void> settle(WidgetTester t) async {
    await t.pump(const Duration(milliseconds: 600));
    await t.pumpAndSettle();
  }

  testWidgets('glyph paint stays 24dp inside a 48dp control', (t) async {
    await t.pumpWidget(host(const Scaffold(body: Center(child: SizedBox.square(
        dimension: 48, child: ProxoSymbol(ProxoSymbolName.logout))))));
    expect(t.getSize(find.byType(SvgPicture)), const Size(24, 24));
    expect(t.getSize(find.byType(ProxoSymbol)), const Size(48, 48));
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('Auth and provider marks have bounded paint at text scale $scale', (t) async {
      phone(t);
      await t.pumpWidget(host(MediaQuery(
        data: MediaQueryData(size: const Size(393, 852), textScaler: TextScaler.linear(scale)),
        child: const Scaffold(body: Column(children: [AuthLogo(), Expanded(child: DepositScreen())])),
      )));
      await settle(t);
      expect(t.getSize(find.byType(AuthLogo)), const Size(84, 24));
      final marks = find.byWidgetPredicate((w) => w is SvgPicture &&
          w.bytesLoader is SvgAssetLoader &&
          (w.bytesLoader as SvgAssetLoader).assetName.startsWith('assets/logos/providers/'));
      // The grid lazily mounts visible cards; scroll to inspect the remainder.
      for (var pass = 0; pass < 2; pass++) {
        for (final mark in marks.evaluate()) {
          expect((mark.findRenderObject()! as RenderBox).size, const Size(64, 24));
        }
        final scroll = t.state<ScrollableState>(find.byType(Scrollable).first);
        scroll.position.jumpTo(scroll.position.maxScrollExtent);
        await t.pump();
      }
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }

  testWidgets('logout uses the same 24dp paint as profile menu glyphs', (t) async {
    phone(t);
    await t.pumpWidget(host(const ProfileScreen()));
    await settle(t);
    final scroll = t.state<ScrollableState>(find.byType(Scrollable).first);
    scroll.position.jumpTo(scroll.position.maxScrollExtent);
    await t.pump();
    final logout = find.byWidgetPredicate((w) => w is ProxoSymbol && w.symbol == ProxoSymbolName.logout);
    expect(t.getSize(find.descendant(of: logout, matching: find.byType(SvgPicture))), const Size(24, 24));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  for (final physics in [const ClampingScrollPhysics(), const BouncingScrollPhysics()]) {
    testWidgets('pull and tab refresh share one request with $physics', (t) async {
      phone(t);
      final controller = ProxoRefreshController();
      final gate = Completer<void>();
      var reads = 0;
      await t.pumpWidget(host(Scaffold(body: ProxoRefresh(
        controller: controller, pullToRefresh: true,
        onRefresh: () { reads++; return gate.future; },
        child: ListView(physics: AlwaysScrollableScrollPhysics(parent: physics),
            children: const [SizedBox(height: 160, child: Text('Short list'))]),
      ))));
      final retained = t.state(find.byType(Scrollable));
      await t.drag(find.byType(ListView), const Offset(0, 300));
      for (var i = 0; i < 25; i++) { await t.pump(const Duration(milliseconds: 100)); }
      expect(reads, 1);
      await controller.refresh(); // already busy: no second fetch
      expect(reads, 1);
      gate.complete();
      await settle(t);
      expect(controller.isRefreshing, isFalse);
      expect(t.state(find.byType(Scrollable)), same(retained));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }

  testWidgets('returning a pull below its threshold before release cancels refresh', (t) async {
    var reads = 0;
    await t.pumpWidget(host(Scaffold(body: ProxoRefresh(pullToRefresh: true,
      onRefresh: () async { reads++; },
      child: ListView(physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          children: const [SizedBox(height: 2000)]),
    ))));
    final gesture = await t.startGesture(t.getCenter(find.byType(ListView)));
    await gesture.moveBy(const Offset(0, 220)); await t.pump();
    await gesture.moveBy(const Offset(0, -400)); await t.pump();
    // Bouncing physics applies friction in both directions: pointer travel
    // alone does not prove the viewport has returned below the threshold.
    final position = t.state<ScrollableState>(find.byType(Scrollable)).position;
    expect(position.pixels, greaterThanOrEqualTo(position.minScrollExtent));
    await gesture.up(); await settle(t);
    expect(reads, 0);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('finishing a refresh after closing its route is safe', (t) async {
    final handle = ProxoRefreshController(), gate = Completer<void>();
    await t.pumpWidget(host(Scaffold(body: ProxoRefresh(controller: handle,
      onRefresh: () => gate.future, child: ListView(children: const [Text('Content')])))));
    final running = handle.refresh();
    await t.pump(); await t.pump(const Duration(milliseconds: 100));
    await t.pumpWidget(const SizedBox());
    gate.complete();
    await t.pump(const Duration(seconds: 1));
    await running;
    expect(handle.isAttached, isFalse);
    expect(t.takeException(), isNull);
    handle.dispose();
  });

  for (final entry in <String, Widget>{
    'pa_challenges': const TasksPage(),
    'pa_levels': const LevelsPage(),
    'pa_tutorials': const TutorialScreen(),
  }.entries) {
    testWidgets('${entry.key} retains loaded content during pull refresh', (t) async {
      phone(t);
      await t.pumpWidget(host(entry.value)); await settle(t);
      final state = t.state(find.byType(Scrollable).first);
      final refresh = t.widget<ProxoRefresh>(find.byType(ProxoRefresh)).onRefresh;
      final gate = Completer<void>();
      backend.readGates[entry.key] = gate;
      final running = refresh(); await t.pump();
      expect(t.state(find.byType(Scrollable).first), same(state));
      expect(find.byType(ProxoRefresh), findsOneWidget);
      gate.complete(); backend.readGates.remove(entry.key);
      await t.pump(); await running; await settle(t);
      expect(t.state(find.byType(Scrollable).first), same(state));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Home joins overlapping initial and refresh reads, then fetches fresh data', (t) async {
    phone(t);
    backend.refreshGate = Completer<void>();
    final initial = backend.reads['pa_ads'] ?? 0;
    await t.pumpWidget(host(HomeScreen(onCreateTap: () {}, onAddBalanceTap: () {},
        onToolsTap: () {}, onCreatePageTap: () {}, onFaqTap: () {})));
    await t.pump();
    final refresh = t.widget<ProxoRefresh>(find.byType(ProxoRefresh)).onRefresh;
    final first = refresh(), second = refresh();
    await t.pump();
    expect(backend.reads['pa_ads']! - initial, 1);
    backend.refreshGate!.complete(); backend.refreshGate = null;
    await t.pump(); await first; await second; await settle(t);
    await refresh(); await settle(t);
    expect(backend.reads['pa_ads']! - initial, 2);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('refresh recovers an Ads error even when the returned list is empty', (t) async {
    phone(t);
    await (await SharedPreferences.getInstance()).clear();
    backend.adsUnavailable = true; backend.emptyAds = true;
    final handle = ProxoRefreshController();
    try {
      await t.pumpWidget(host(AdScreen(refreshController: handle))); await settle(t);
      expect(find.text('پەیوەندی نییە'), findsOneWidget);
      expect(handle.isAttached, isTrue);
      backend.adsUnavailable = false;
      final running = handle.refresh();
      await settle(t); await running;
      expect(find.text('پەیوەندی نییە'), findsNothing);
      expect(find.text('هەڵەیەک ڕوویدا'), findsNothing);
      expect(handle.isAttached, isTrue);
      expect(t.takeException(), isNull);
    } finally {
      backend.adsUnavailable = false; backend.emptyAds = false;
      await t.pumpWidget(const SizedBox()); handle.dispose();
    }
  });

  testWidgets('successful creation preserves Home and Ads state and prevents duplicate routes', (t) async {
    phone(t);
    await t.pumpWidget(host(const app.MainShell())); await settle(t);
    final homeState = t.state(find.byType(HomeScreen));
    final homeScroll = t.state<ScrollableState>(find.descendant(of: find.byType(HomeScreen), matching: find.byType(Scrollable)).first);
    homeScroll.position.jumpTo(homeScroll.position.maxScrollExtent);
    final offset = homeScroll.position.pixels;
    void tab(int index) => t.widget<ProxoBottomNav>(find.byType(ProxoBottomNav)).onTap(index);
    tab(1); await settle(t);
    final adsState = t.state(find.byType(AdScreen));
    final reads = backend.reads['pa_ads']!;
    tab(2); tab(2); await settle(t);
    expect(find.byType(AdCreateScreen), findsOneWidget);
    app.navigatorKey.currentState!.pop('refresh'); await settle(t);
    expect(find.byType(AdCreateScreen), findsNothing);
    expect(t.state(find.byType(AdScreen)), same(adsState));
    expect(t.state(find.byType(HomeScreen, skipOffstage: false)), same(homeState));
    expect(backend.reads['pa_ads']! - reads, 1);
    tab(0); await settle(t);
    expect(homeScroll.position.pixels, offset);
    // Also cover return from creation when Ads is an inactive, retained tab.
    tab(2); await settle(t);
    app.navigatorKey.currentState!.pop('refresh'); await settle(t);
    expect(t.state(find.byType(AdScreen)), same(adsState));
    expect(t.state(find.byType(HomeScreen, skipOffstage: false)), same(homeState));
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox()); await settle(t);
  });
}
