import 'package:proxo_app/screens/auth/auth_shell.dart';
import 'package:proxo_app/widgets/auth/auth_design.dart';
import 'package:proxo_app/screens/deposit_screen.dart';
import 'package:proxo_app/screens/home_screen.dart';
// Credential-free Android checks of actual production widgets. Fixtures reject
// writes. This suite neither replaces authenticated E2E nor measures performance.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/screens/ad_create_screen.dart';
import 'package:proxo_app/screens/tools_screen.dart';
import 'package:proxo_app/screens/profile_screen.dart';
import 'package:proxo_app/widgets/proxo_sidebar.dart';
import 'package:proxo_app/widgets/top_bar.dart';
import 'package:proxo_app/screens/transaction_detail_screen.dart';
import 'package:proxo_app/theme/app_locale.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/widgets/bottom_nav.dart';
import 'package:proxo_app/widgets/home_quick_actions.dart';
import 'package:proxo_app/widgets/receipt/receipt_kit.dart';
import 'support/actual_screen_fixtures.dart';

const config = String.fromEnvironment('UI_CONFIG', defaultValue: 'phone');
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native icon states, targets, receipts and keyboard', (t) async {
    SharedPreferences.setMockInitialValues({});
    final backend = ActualScreenBackend();
    await backend.initialize();
    addTearDown(backend.dispose);
    final observations = <String, Object?>{
      'fixture_only': true,
      'mode': 'Android emulator debug; not a performance benchmark',
      'physical_size': [t.view.physicalSize.width, t.view.physicalSize.height],
      'dpr': t.view.devicePixelRatio,
      'config': config,
    };
    binding.reportData = {'observations': observations};
    Future<void> mount(Widget child, {double scale = 1}) async {
      await t.pumpWidget(MaterialApp(
        key: UniqueKey(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(fontFamily: kAppFont, useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
          scaffoldBackgroundColor: Colors.white),
        builder: (context, child) => ProxoLocaleScope(child: MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        )),
        home: child,
      ));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    }
    Future<void> prepareImages(String name) async {
      for (final element in find.byType(Image).evaluate().toList()) {
        await precacheImage((element.widget as Image).image, element);
      }
      await t.pumpAndSettle();
      // Image decoding can finish before the Android raster frame is presented.
      // Check the actual mounted image and its layout before capturing evidence.
      for (final element in find.byType(Image).evaluate().toList()) {
        final raw = find.descendant(of: find.byWidget(element.widget), matching: find.byType(RawImage));
        expect(raw, findsOneWidget);
        final rendered = t.widget<RawImage>(raw);
        final box = t.getSize(raw);
        observations['$name-image'] = {'decoded': rendered.image != null,
          'width_dp': box.width, 'height_dp': box.height};
        expect(rendered.image, isNotNull, reason: '$name mounted image must finish decoding');
        expect(box.width, greaterThan(0), reason: '$name image cannot collapse horizontally');
        expect(box.height, greaterThan(0), reason: '$name image cannot collapse vertically');
      }
      await t.pump(const Duration(milliseconds: 100));
      expect(t.takeException(), isNull);
    }
    Widget chrome() => Builder(builder: (context) => Scaffold(
      appBar: ProxoTopBar(
        // Match HomeScreen's real status-bar inset contract.
        topPadding: MediaQuery.paddingOf(context).top,
        onMenuTap: () {}, onNotificationTap: () {}, onSearchTap: () {},
      ),
      bottomNavigationBar: ProxoBottomNav(currentIndex: 4, onTap: (_) {}),
    ));
    // A converted FlutterImageView can still display the preceding captured
    // frame to Android. Capture the ordinary surface before any conversion.
    for (final scale in [1.0, 2.0]) {
      await mount(chrome(), scale: scale);
      await prepareImages('chrome-native-scale-$scale');
      await Future<void>.delayed(const Duration(milliseconds: 250));
      print('PROXO_UI_NATIVE_SCREENSHOT:$config-chrome-native-scale-$scale');
      await Future<void>.delayed(const Duration(milliseconds: 750));
    }
    await mount(const Scaffold());
    await binding.convertFlutterSurfaceToImage();
    await t.pump();
    Future<void> shot(String name) async {
      await prepareImages(name);
      await binding.takeScreenshot('$config-$name');
    }
    final taps = <String>[];
    Widget actions(bool enabled) => Scaffold(body: SingleChildScrollView(
      child: Padding(padding: const EdgeInsets.all(16), child: HomeQuickActions(
        onCreateTap: enabled ? () => taps.add('ad') : null,
        onAddBalanceTap: enabled ? () => taps.add('balance') : null,
        onCreatePageTap: enabled ? () => taps.add('page') : null,
      )),
    ));
    final semantics = t.ensureSemantics();
    try {
      for (final scale in [1.0, 2.0]) {
        await mount(actions(true), scale: scale);
        expect(find.descendant(of: find.byType(HomeQuickActions),
          matching: find.byType(Image)), findsNothing);
        for (final name in ['home-create-ad', 'home-add-balance', 'home-create-page']) {
          final card = find.byKey(ValueKey(name));
          await t.ensureVisible(card);
          await t.pumpAndSettle();
          final size = t.getSize(card);
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
          final semantic = t.getSemantics(card);
          expect(semantic.getSemanticsData().label, isNotEmpty);
          await t.tap(card);
        }
        await shot('actions-scale-$scale');
      }
      expect(taps, ['ad', 'balance', 'page', 'ad', 'balance', 'page']);
      observations['quick_action_callbacks'] = taps.toList();
      await mount(actions(false));
      await t.tap(find.byKey(const ValueKey('home-create-ad')));
      expect(taps.length, 6);
      await shot('actions-disabled');
      observations['disabled_action_did_not_fire'] = true;
      for (final index in [0, 1, 3, 4]) {
        await mount(Scaffold(bottomNavigationBar: ProxoBottomNav(
          currentIndex: index, onTap: (_) {},
        )));
        await shot('navigation-$index');
      }
      for (final scale in [1.0, 2.0]) {
        await mount(const AuthShell(), scale: scale);
        await shot('auth-scale-$scale');
        await t.tap(find.text(AuthStrings.channelPhone).first);
        await t.pumpAndSettle();
        final phone = find.byWidgetPredicate((w) => w is TextField && w.keyboardType == TextInputType.phone);
        await t.ensureVisible(phone); await t.pumpAndSettle();
        await t.tap(phone); await t.enterText(phone, '٠٧٥٠١٢٣٤٥٦٧');
        await t.pumpAndSettle();
        expect(t.widget<TextField>(phone).controller!.text, '7501234567');
        expect(find.text('+964'), findsOneWidget);
        await shot('auth-phone-scale-$scale');
        observations['phone_normalized_scale_$scale'] = true;
        // Leaving the actual auth screen must release its focused field.
        await mount(const DepositScreen(), scale: scale);
        await shot('deposit-scale-$scale');
        await t.drag(find.byType(Scrollable).first, const Offset(0, -1000));
        await t.pumpAndSettle(); await shot('deposit-bottom-scale-$scale');
        await mount(HomeScreen(onCreateTap: () {}, onCreatePageTap: () {}, onAddBalanceTap: () {}), scale: scale);
        await shot('home-scale-$scale');
      }
      for (final scale in [1.0, 2.0]) {
        await mount(ProfileScreen(onBottomNavTap: (_) {}), scale: scale);
        await shot('profile-scale-$scale');
        await t.drag(find.byType(Scrollable).first, const Offset(0, -650));
        await t.pumpAndSettle();
        await shot('profile-bottom-scale-$scale');
        await mount(Scaffold(body: Align(alignment: Alignment.centerRight,
          child: ProxoSidebar(onClose: () {}, onNavigate: (_) {}))), scale: scale);
        await shot('sidebar-scale-$scale');
        await t.drag(find.byType(Scrollable).first, const Offset(0, -650));
        await t.pumpAndSettle();
        await shot('sidebar-bottom-scale-$scale');
        await mount(chrome(), scale: scale);
        await shot('chrome-scale-$scale');
      }
      for (final scale in [1.0, 2.0]) {
        await mount(TransactionDetailScreen(data: TxReceiptData(
          kind: TxReceiptKind.topUp, status: 'approved', txId: 'TX4UFQVLZ4J6',
          uid: screenFixtureOwner, date: DateTime.utc(2026, 10, 14, 1, 58),
          usd: 10, amountIqd: 18000, balanceBefore: null, balanceAfter: null,
          method: 'fastpay', gateway: 'fastpay', type: 'deposit',
          adName: null, voucherCode: null,
        )), scale: scale);
        await shot('receipt-scale-$scale');
        // Native safe-area/large text can put this lazy ListView child beyond
        // the cache extent. Scroll it into the tree before asking for its box.
        await t.scrollUntilVisible(find.byType(ReceiptPdfButton), 400,
          scrollable: find.byType(Scrollable).first);
        await t.pumpAndSettle();
        expect(t.getSize(find.byType(ReceiptPdfButton)).height, greaterThanOrEqualTo(48));
        await shot('receipt-bottom-scale-$scale');
      }
      await mount(ToolsScreen(repository: ActualToolsRepository()));
      await shot('tools');
      await mount(AdCreateScreen(repository: ActualAdRepository()));
      await shot('create');
      final title = find.byKey(const ValueKey('ad-title'));
      await t.ensureVisible(title);
      await t.pumpAndSettle();
      await t.tap(title);
      Future<void> waitInsets(bool visible) async {
        var stableSamples = 0;
        double? previousInset;
        for (var i = 0; i < 100; i++) {
          await t.pump(const Duration(milliseconds: 100));
          final inset = t.view.viewInsets.bottom;
          if ((inset > 0) == visible && inset == previousInset) {
            stableSamples++;
            if (stableSamples >= 5) return;
          } else {
            stableSamples = 0;
          }
          previousInset = inset;
        }
        fail('Native keyboard visibility did not become $visible');
      }
      await waitInsets(true);
      observations['keyboard_inset_physical_px'] = t.view.viewInsets.bottom;
      await shot('create-keyboard');
      // The host runner sees this marker and sends an actual ADB BACK key event.
      // A framework handlePopRoute call would not test Android keyboard behavior.
      print('PROXO_UI_NATIVE_BACK_READY');
      await waitInsets(false);
      expect(find.byType(AdCreateScreen), findsOneWidget);
      observations['android_back_dismissed_keyboard_kept_form'] = true;
      await t.ensureVisible(title);
      await t.pumpAndSettle();
      await t.tap(title);
      await waitInsets(true);
      final goal = find.byKey(const ValueKey('goal-views'));
      await t.ensureVisible(goal);
      await t.pumpAndSettle();
      expect(goal.hitTestable(), findsOneWidget);
      await t.tap(goal);
      await waitInsets(false);
      observations['choice_dismissed_keyboard'] = true;
      await shot('create-keyboard-dismissed');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
      observations['completed'] = true;
    } finally {
      // Flutter verifies handles before addTearDown callbacks run.
      semantics.dispose();
    }
  }, timeout: const Timeout(Duration(minutes: 7)));
}
