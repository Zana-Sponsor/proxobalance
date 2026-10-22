import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/screens/ad_create_screen.dart';
import 'package:proxo_app/screens/ad_screen.dart';
import 'package:proxo_app/screens/tools_screen.dart';
import 'package:proxo_app/services/proxolink_service.dart';
import 'package:proxo_app/theme/app_locale.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/theme/proxo_surface.dart';
import 'package:proxo_app/widgets/proxo_empty_state.dart';
import 'package:proxo_app/widgets/proxolink_page_card.dart';

import '../integration_test/support/actual_screen_fixtures.dart';
import 'proxolink_tools_create_test.dart' show ToolsRepository, size;
import 'support/session_fixture.dart';

class _Routes extends NavigatorObserver {
  int creates = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route.settings.name == 'create_ad') creates++;
  }
}

Widget _host(Widget child, {double scale = 1, NavigatorObserver? observer}) =>
    MaterialApp(
      theme: buildAppTheme(),
      navigatorObservers: [if (observer != null) observer],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          padding: const EdgeInsets.only(top: 24, bottom: 16),
        ),
        child: child!,
      ),
      home: child,
    );

void _checkPanel(
    WidgetTester tester, Finder panel, double width, double scale) {
  expect(panel, findsOneWidget);
  final box = tester.getRect(panel);
  expect(box.width, lessThanOrEqualTo(ProxoSurface.maxWidth));
  expect(box.left, greaterThanOrEqualTo(ProxoSurface.gutter));
  expect(box.right, lessThanOrEqualTo(width - ProxoSurface.gutter));
  final paragraphs =
      find.descendant(of: panel, matching: find.byType(RichText));
  expect(paragraphs, findsWidgets);
  for (final element in paragraphs.evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    // Measure actual laid-out text, so a parent accessibility clamp cannot
    // silently make a purported 2x test pass at 1x.
    expect(paragraph.textScaler.scale(14), closeTo(14 * scale, .001));
    expect(paragraph.didExceedMaxLines, false);
    expect(paragraph.text.style?.fontFamily, ProxoSurface.fontFamily);
    expect(paragraph.text.style?.fontWeight, FontWeight.w400);
    final left = paragraph.localToGlobal(Offset.zero).dx;
    expect(left, greaterThanOrEqualTo(box.left));
    expect(left + paragraph.size.width, lessThanOrEqualTo(box.right + .01));
  }
  expect(tester.takeException(), isNull);
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final backend = ActualScreenBackend();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in manifest) {
      final loader = FontLoader(font['family'] as String);
      for (final asset in font['fonts'] as List) {
        loader.addFont(rootBundle.load(asset['asset'] as String));
      }
      await loader.load();
    }
    await backend.initialize();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    backend.emptyAds = true;
    backend.adsUnavailable = false;
    backend.readGates.clear();
    backend.readResponses.clear();
    backend.reads.clear();
    ProxoLocale.current.value = ProxoLocale.kurdishSorani;
  });
  tearDownAll(() async {
    await backend.dispose();
    ProxoLocale.current.value = ProxoLocale.kurdishSorani;
  });

  for (final width in [320.0, 393.0, 430.0, 768.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final ads in [false, true]) {
        testWidgets(
            '${ads ? 'Ads' : 'Pages'} empty $width / $scale respects '
            'real font scaling, gutters, 48dp action and scrolling', (t) async {
          size(t, width, height: 700);
          await t.pumpWidget(_host(
            ads
                ? const AdScreen()
                : ToolsScreen(repository: ToolsRepository([])),
            scale: scale,
          ));
          await t.pumpAndSettle();
          final panel = find
              .byKey(ValueKey(ads ? 'ads-empty-state' : 'tools-empty-state'));
          _checkPanel(t, panel, width, scale);
          final action = find
              .byKey(ValueKey(ads ? 'ads-create-empty' : 'tools-create-page'));
          await t.ensureVisible(action);
          await t.pumpAndSettle();
          expect(t.getSize(action).height, greaterThanOrEqualTo(48));
          expect(action.hitTestable(), findsOneWidget);
          expect(find.byType(ProxoEmptyState), findsOneWidget);
          expect(t.takeException(), isNull);
          await _unmount(t);
        });
      }
    }
  }

  for (final language in ['ckb', 'ar', 'kmr']) {
    testWidgets('short Ads viewport, $language, 2x retains reachable create',
        (t) async {
      size(t, 320, height: 420);
      ProxoLocale.current.value = Locale(language);
      await t.pumpWidget(_host(const AdScreen(), scale: 2));
      await t.pumpAndSettle();
      _checkPanel(t, find.byKey(const ValueKey('ads-empty-state')), 320, 2);
      final action = find.byKey(const ValueKey('ads-create-empty'));
      await t.ensureVisible(action);
      await t.pumpAndSettle();
      expect(action.hitTestable(), findsOneWidget);
      expect(t.takeException(), isNull);
      await _unmount(t);
    });
  }

  testWidgets(
      'Ads loading is not empty; failure is distinct; retry is coalesced and recovers',
      (t) async {
    size(t, 320, height: 900);
    backend.adsUnavailable = true;
    final first = Completer<void>();
    backend.readGates['pa_ads'] = first;
    await t.pumpWidget(_host(const AdScreen(), scale: 2));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('sk')), findsOneWidget);
    expect(find.byType(ProxoEmptyState), findsNothing);
    first.complete();
    await t.pumpAndSettle();
    _checkPanel(t, find.byKey(const ValueKey('ads-error-state')), 320, 2);
    expect(find.byKey(const ValueKey('ads-create-empty')), findsNothing);
    backend.adsUnavailable = false;
    final retryGate = Completer<void>();
    backend.readGates['pa_ads'] = retryGate;
    final before = backend.reads['pa_ads']!;
    final retry = find.byKey(const ValueKey('ads-retry'));
    await t.ensureVisible(retry);
    final callback = t.widget<FilledButton>(retry).onPressed!;
    callback();
    callback();
    await t.pump(const Duration(milliseconds: 100));
    expect(backend.reads['pa_ads'], before + 1);
    expect(t.widget<FilledButton>(retry).onPressed, isNull);
    expect(find.byKey(const ValueKey('ads-error-state')), findsOneWidget);
    retryGate.complete();
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('ads-error-state')), findsNothing);
    expect(find.byKey(const ValueKey('ads-empty-state')), findsOneWidget);
    expect(t.takeException(), isNull);
    await _unmount(t);
  });

  testWidgets(
      'filtered Ads emptiness clears the filter instead of claiming no account ads',
      (t) async {
    size(t, 320, height: 900);
    await t.pumpWidget(
        _host(const AdScreen(initialFilter: AdFilter.pending), scale: 2));
    await t.pumpAndSettle();
    _checkPanel(
        t, find.byKey(const ValueKey('ads-filter-empty-state')), 320, 2);
    expect(find.byKey(const ValueKey('ads-empty-state')), findsNothing);
    expect(find.byKey(const ValueKey('ads-create-empty')), findsNothing);
    backend.emptyAds = false;
    final clear = find.byKey(const ValueKey('ads-clear-filter'));
    await t.ensureVisible(clear);
    await t.tap(clear);
    await t.pumpAndSettle();
    expect(find.byType(ProxoEmptyState), findsNothing);
    expect(find.text('Fictional screen fixture'), findsOneWidget);
    expect(backend.reads['pa_ads'], 2);
    expect(t.takeException(), isNull);
    await _unmount(t);
  });

  testWidgets(
      'Ads create opens the existing workflow once and reloads after returning',
      (t) async {
    size(t, 393, height: 900);
    final routes = _Routes();
    await t.pumpWidget(_host(const AdScreen(), observer: routes));
    await t.pumpAndSettle();
    final create = t
        .widget<FilledButton>(find.byKey(const ValueKey('ads-create-empty')))
        .onPressed!;
    create();
    create();
    await t.pumpAndSettle();
    expect(routes.creates, 1);
    expect(find.byType(AdCreateScreen), findsOneWidget);
    final reads = backend.reads['pa_ads']!;
    Navigator.of(t.element(find.byType(AdCreateScreen))).pop();
    await t.pumpAndSettle();
    expect(find.byType(AdCreateScreen), findsNothing);
    expect(backend.reads['pa_ads'], reads + 1);
    expect(find.byKey(const ValueKey('ads-empty-state')), findsOneWidget);
    expect(t.takeException(), isNull);
    await _unmount(t);
  });

  testWidgets('stale Ads empty action cannot navigate after account changes',
      (t) async {
    size(t, 393);
    final routes = _Routes();
    await t.pumpWidget(_host(const AdScreen(), observer: routes));
    await t.pumpAndSettle();
    final create = t
        .widget<FilledButton>(find.byKey(const ValueKey('ads-create-empty')))
        .onPressed!;
    await restoreFixture(backend.client, userB);
    create();
    await t.pumpAndSettle();
    expect(routes.creates, 0);
    expect(find.byType(AdCreateScreen), findsNothing);
    await _unmount(t);
    await restoreFixture(backend.client, screenFixtureOwner);
  });

  testWidgets(
      'Pages loading and retrieval error remain distinct and retry reaches true empty',
      (t) async {
    size(t, 320, height: 900);
    final repo = ToolsRepository([])..defer = true;
    await t.pumpWidget(_host(ToolsScreen(repository: repo), scale: 2));
    await t.pump();
    expect(find.byType(ProxoLinkPageSkeleton), findsWidgets);
    expect(find.byType(ProxoEmptyState), findsNothing);
    repo.reads.single.completeError(const ProxoLinkFailure('network_error'));
    await t.pumpAndSettle();
    _checkPanel(t, find.byKey(const ValueKey('tools-error-state')), 320, 2);
    expect(find.byKey(const ValueKey('tools-create-page')), findsNothing);
    final retry = t
        .widget<FilledButton>(find.byKey(const ValueKey('tools-retry-pages')))
        .onPressed!;
    retry();
    retry();
    await t.pump(const Duration(milliseconds: 100));
    expect(repo.listReads, 2);
    repo.reads.last.complete([]);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('tools-error-state')), findsNothing);
    expect(find.byKey(const ValueKey('tools-empty-state')), findsOneWidget);
    expect(t.takeException(), isNull);
    await _unmount(t);
  });
}
