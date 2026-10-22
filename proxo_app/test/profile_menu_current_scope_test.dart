import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/screens/profile_screen.dart';
import 'package:proxo_app/theme/app_locale.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/widgets/proxo_sidebar.dart';
import 'package:proxo_app/widgets/proxo_text.dart';
import '../integration_test/support/actual_screen_fixtures.dart';

void main() {
  final backend = ActualScreenBackend();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
        appName: 'Proxo',
        packageName: 'fixture.proxo',
        version: '1.0.11',
        buildNumber: '11',
        buildSignature: '');
    await backend.initialize();
  });
  tearDownAll(backend.dispose);
  setUp(() {
    backend.readResponses.clear();
    ProxoLocale.current.value = ProxoLocale.kurdishSorani;
  });
  Finder keyed(String key) => find.byKey(ValueKey(key));
  void viewport(WidgetTester t, double width, double height) {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = Size(width, height);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  Widget host(Widget home, {double scale = 1}) => MaterialApp(
        theme: buildAppTheme(),
        builder: (context, child) => ProxoLocaleScope(
            child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    padding: const EdgeInsets.only(top: 24, bottom: 34),
                    textScaler: TextScaler.linear(scale)),
                child: child!)),
        home: home,
      );

  testWidgets(
      'menu shows actual phone instead of synthetic authentication email',
      (t) async {
    viewport(t, 320, 568);
    backend.readResponses['profiles'] = {
      'full_name': 'ناوی کوردی زۆر درێژ — Long Account Name',
      'email': '9647510074008@phone.proxopages.com',
      'phone': '+9647510074008',
    };
    await t.pumpWidget(host(
        const Scaffold(
            body: Directionality(
                textDirection: TextDirection.rtl, child: ProxoSidebar())),
        scale: 2));
    await t.pumpAndSettle();
    expect(find.textContaining('@phone.proxopages.com'), findsNothing);
    final contact = t.widget<ProxoText>(keyed('sidebar-contact'));
    expect(contact.data, '+9647510074008');
    expect(contact.textDirection, TextDirection.ltr);
    expect(contact.maxLines, 1);
    await t.ensureVisible(keyed('sidebar-logout'));
    await t.pumpAndSettle();
    expect(keyed('sidebar-logout').hitTestable(), findsOneWidget);
    expect(
        t.getRect(keyed('sidebar-logout')).bottom, lessThanOrEqualTo(568 - 34));
    expect(keyed('sidebar-close').hitTestable(), findsOneWidget,
        reason: 'Header stays reachable after scrolling the long menu');
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'menu keeps genuine long email in one LTR line with complete tooltip',
      (t) async {
    viewport(t, 320, 568);
    const email = 'averylong.account.address.for.profile@gmail.com';
    backend.readResponses['profiles'] = {'full_name': 'Zana', 'email': email};
    await t.pumpWidget(host(const Scaffold(body: ProxoSidebar())));
    await t.pumpAndSettle();
    expect(find.byTooltip(email), findsOneWidget);
    final text = t.widget<ProxoText>(keyed('sidebar-contact'));
    expect(text.data, email);
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.textDirection, TextDirection.ltr);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'native drawer closes via close, outside tap and Android Back without blocking body',
      (t) async {
    viewport(t, 320, 568);
    final shell = GlobalKey<ScaffoldState>();
    var bodyTaps = 0;
    await t.pumpWidget(host(Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(
          key: shell,
          endDrawer: Directionality(
              textDirection: TextDirection.rtl,
              child: ProxoSidebar(
                  onClose: () => shell.currentState!.closeEndDrawer())),
          body: Center(
              child: TextButton(
                  key: const ValueKey('underlying-control'),
                  onPressed: () => bodyTaps++,
                  child: const Text('Open'))),
        ))));
    await t.pumpAndSettle();
    for (final mode in ['close', 'outside', 'back']) {
      shell.currentState!.openEndDrawer();
      await t.pumpAndSettle();
      expect(shell.currentState!.isEndDrawerOpen, isTrue);
      if (mode == 'close') {
        await t.tap(keyed('sidebar-close'));
      } else if (mode == 'outside') {
        await t.tapAt(const Offset(8, 300));
      } else {
        await t.binding.handlePopRoute();
      }
      await t.pumpAndSettle();
      expect(shell.currentState!.isEndDrawerOpen, isFalse, reason: mode);
      await t.tap(keyed('underlying-control'));
      await t.pump();
      expect(t.takeException(), isNull);
    }
    expect(bodyTaps, 3);
  });

  testWidgets('menu Profile uses the retained tab callback once', (t) async {
    viewport(t, 393, 852);
    final destinations = <String>[];
    var closes = 0;
    await t.pumpWidget(host(Scaffold(
        body: ProxoSidebar(
            currentIndex: 4,
            onClose: () => closes++,
            onNavigate: destinations.add))));
    await t.pumpAndSettle();
    final action = t.widget<InkWell>(keyed('sidebar-profile')).onTap!;
    action();
    action();
    await t.pump(const Duration(milliseconds: 300));
    await t.pumpAndSettle();
    expect(destinations, ['profile']);
    expect(closes, 1);
    expect(find.byType(ProfileScreen), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'Profile compact balance, integrated language and authentic WhatsApp SVG',
      (t) async {
    viewport(t, 393, 852);
    await t.pumpWidget(host(const ProfileScreen()));
    await t.pumpAndSettle();
    expect(t.getSize(keyed('profile-balance')).height, lessThanOrEqualTo(160));
    await t.ensureVisible(keyed('profile-whatsapp'));
    await t.pumpAndSettle();
    final icon = t.widget<SvgPicture>(keyed('profile-whatsapp-brand'));
    expect(icon.width, 22);
    expect(icon.height, 22);
    expect(icon.colorFilter, isNull,
        reason: 'Official brand green must be preserved');
    expect(await rootBundle.loadString('assets/icons/whatsapp.svg'),
        contains('#25d366'));
    await t.ensureVisible(keyed('profile-language'));
    await t.pumpAndSettle();
    await t.tap(keyed('profile-language'));
    await t.pumpAndSettle();
    await t.tap(find.text('العربية'));
    await t.pumpAndSettle();
    expect(ProxoLocale.current.value, ProxoLocale.arabic);
    expect(t.takeException(), isNull);
  });
}
