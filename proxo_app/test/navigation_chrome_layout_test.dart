import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/services/unread_notification_counter.dart';
import 'package:proxo_app/theme/app_locale.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/widgets/proxo_sidebar.dart';
import 'package:proxo_app/widgets/proxo_symbol.dart';
import 'package:proxo_app/widgets/top_bar.dart';
import '../integration_test/support/actual_screen_fixtures.dart';

void main() {
  final backend = ActualScreenBackend();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await backend.initialize();
  });
  tearDownAll(backend.dispose);

  testWidgets(
      'shared toolbar ignores legacy screen direction and follows app locale',
      (t) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(393, 852);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final originalLocale = ProxoLocale.current.value;
    addTearDown(() => ProxoLocale.current.value = originalLocale);
    ProxoLocale.current.value = ProxoLocale.kurdishSorani;
    List<Rect> bounds() => [
          t.getRect(find.byKey(const ValueKey('proxo-toolbar-logo'))),
          t.getRect(find.byTooltip('مێنیو')),
          t.getRect(find.byKey(const ValueKey('notification-bell-target'))),
        ];
    Future<void> mount(TextDirection screenDirection) async {
      await t.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => ProxoLocaleScope(child: child!),
        home: Directionality(
          textDirection: screenDirection,
          child: Scaffold(
              appBar: ProxoTopBar(onMenuTap: () {}, onNotificationTap: () {})),
        ),
      ));
      await t.pumpAndSettle();
    }

    await mount(TextDirection.rtl);
    final homeBounds = bounds();
    await mount(TextDirection.ltr);
    expect(bounds(), homeBounds,
        reason:
            'Home and Ads retain identical logo, menu, and notification geometry');
    expect(homeBounds[0].left, lessThan(homeBounds[1].left));
    expect(t.takeException(), isNull);
  });

  for (final width in [320.0, 393.0, 430.0, 768.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('toolbar and menu retain balanced targets at $width / $scale',
          (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = Size(width, 852);
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        Widget host(Widget child) => MaterialApp(
            theme: buildAppTheme(),
            builder: (context, child) => ProxoLocaleScope(
                child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                        padding: const EdgeInsets.only(top: 24, bottom: 34),
                        textScaler: TextScaler.linear(scale),
                        disableAnimations: true),
                    child: child!)),
            home: child);
        var menuTaps = 0;
        var bellTaps = 0;
        await t.pumpWidget(host(Scaffold(
            appBar: ProxoTopBar(
                topPadding: 24,
                onMenuTap: () => menuTaps++,
                onNotificationTap: () => bellTaps++),
            body: const SizedBox.expand(key: ValueKey('chrome-body')))));
        await t.pumpAndSettle();
        UnreadNotificationCounter.forClient(backend.client).count.value = 125;
        await t.pumpAndSettle();
        final toolbar = t.getRect(find.byKey(const ValueKey('proxo-toolbar')));
        final logo =
            t.getRect(find.byKey(const ValueKey('proxo-toolbar-logo')));
        final menu = t.getRect(find.byTooltip('مێنیو'));
        final bell =
            t.getRect(find.byKey(const ValueKey('notification-bell-target')));
        final badge =
            t.getRect(find.byKey(const ValueKey('notification-badge')));
        expect(toolbar.top, 24);
        expect(toolbar.height, 56);
        expect(t.getRect(find.byKey(const ValueKey('chrome-body'))).top, 80);
        expect(logo.size, const Size(77, 22));
        expect(menu.right, closeTo(toolbar.right - 12, .1));
        expect(logo.left, closeTo(toolbar.left + 12, .1));
        expect(menu.size, const Size(48, 48));
        expect(bell.size, const Size(48, 48));
        expect(menu.center.dy, logo.center.dy);
        expect(bell.center.dy, logo.center.dy);
        expect(badge.left, greaterThanOrEqualTo(bell.left));
        expect(badge.right, lessThanOrEqualTo(bell.right));
        expect(badge.top, greaterThanOrEqualTo(bell.top));
        expect(badge.bottom, lessThanOrEqualTo(bell.bottom));
        for (final symbol in [ProxoSymbolName.menu, ProxoSymbolName.bell]) {
          final icon = find
              .byWidgetPredicate((w) => w is ProxoSymbol && w.symbol == symbol);
          expect(
              t.getSize(
                  find.descendant(of: icon, matching: find.byType(SvgPicture))),
              const Size(22, 22));
        }
        await t.tap(find.byTooltip('مێنیو'));
        expect(menuTaps, 1);
        await t.tap(find.byKey(const ValueKey('notification-bell-target')));
        expect(bellTaps, 1);
        expect(t.takeException(), isNull);
        await t.pumpWidget(host(const Scaffold(
            body: Align(
                alignment: Alignment.centerRight,
                child: ProxoSidebar(currentIndex: 3)))));
        await t.pumpAndSettle();
        final panel = t.getRect(find.byKey(const ValueKey('sidebar-panel')));
        expect(panel.width, lessThanOrEqualTo(336));
        expect(panel.width, lessThanOrEqualTo(width - 24));
        final tools = find.byKey(const ValueKey('sidebar-tools'));
        final selected = find.ancestor(
            of: tools,
            matching: find.byWidgetPredicate(
                (w) => w is Semantics && w.properties.selected == true));
        expect(selected, findsOneWidget);
        for (final id in [
          'home',
          'ads',
          'tools',
          'deposit',
          'transactions',
          'discounts',
          'notifications',
          'profile',
          'help',
          'logout'
        ]) {
          final target = find.byKey(ValueKey('sidebar-$id'));
          await t.ensureVisible(target);
          await t.pumpAndSettle();
          final rect = t.getRect(target);
          expect(rect.height, greaterThanOrEqualTo(48));
          expect(rect.left, greaterThanOrEqualTo(panel.left + 16));
          expect(rect.right, lessThanOrEqualTo(panel.right - 16));
          expect(target.hitTestable(), findsOneWidget);
          expect(t.takeException(), isNull);
        }
        final logoutIcon = find.byWidgetPredicate(
            (w) => w is ProxoSymbol && w.symbol == ProxoSymbolName.logout);
        expect(
            t.getSize(find.descendant(
                of: logoutIcon, matching: find.byType(SvgPicture))),
            const Size(22, 22));
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
      });
    }
  }
}
