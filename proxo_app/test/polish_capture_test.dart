import 'package:proxo_app/widgets/proxo_sidebar.dart';
import 'package:proxo_app/widgets/levels_page.dart';
import 'package:proxo_app/widgets/tasks_page.dart';
// Actual production widgets; fictional read-only backend; no OTP/payment sends.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/screens/auth/auth_shell.dart';
import 'package:proxo_app/screens/auth/otp_screen.dart';
import 'package:proxo_app/screens/deposit_screen.dart';
import 'package:proxo_app/screens/ad_screen.dart';
import 'package:proxo_app/screens/ad_create_screen.dart';
import 'package:proxo_app/screens/profile_screen.dart';
import 'package:proxo_app/screens/home_screen.dart';
import 'package:proxo_app/theme/app_locale.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/widgets/auth/auth_widgets.dart';
import 'package:proxo_app/widgets/auth/auth_otp_field.dart';
import 'package:proxo_app/widgets/auth/auth_design.dart';
import 'package:proxo_app/widgets/bottom_nav.dart';
import '../integration_test/support/actual_screen_fixtures.dart';
import 'ad_creation_flow_test.dart' show TestAdRepository;

const before = bool.fromEnvironment('POLISH_BEFORE');
class PolishBinding extends AutomatedTestWidgetsFlutterBinding {
  @override bool get disableShadows => false;
}
void main() {
  PolishBinding();
  final backend = ActualScreenBackend();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final fonts = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family'] as String);
      for (final file in font['fonts'] as List) { loader.addFont(rootBundle.load(file['asset'] as String)); }
      await loader.load();
    }
    await backend.initialize();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('flutter.baseflow.com/permissions/methods'), (_) async => 1);
  });
  tearDownAll(() async { await backend.dispose(); ProxoLocale.current.value = ProxoLocale.kurdishSorani; });
  for (final config in [(393.0, 1.0, 3.0), (280.0, 2.0, 2.0)]) {
    for (final language in ['ckb', 'ar', 'kmr']) {
      for (final section in ['login', 'signup', 'forgot', 'otp', 'deposit', 'ads', 'create', 'profile', 'home', 'navigation', 'levels', 'tasks', 'vouchers', 'discounts']) {
        testWidgets('$section $language $config', (t) async {
          final (width, scale, dpr) = config;
          t.view.devicePixelRatio = dpr;
          t.view.physicalSize = Size(width*dpr, 852*dpr);
          addTearDown(t.view.resetPhysicalSize); addTearDown(t.view.resetDevicePixelRatio);
          ProxoLocale.current.value = Locale(language);
          final key = GlobalKey();
          final code = TextEditingController(); final focus = FocusNode();
          final child = switch(section) {
            'login' || 'signup' || 'forgot' => const AuthShell(),
            'otp' => Scaffold(body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(16),
              child: OtpScreen(onBack: () {}, destination: '+964 750 *** ** 67',
                otpBoxes: AuthOtpBoxes(length: 6, codeController: code, firstBoxFocus: focus, onCompleted: (_) {}),
                resend: AuthTextLink(label: AuthStrings.resendAction, onTap: () {}),
                verifyButton: AuthPrimaryButton(label: AuthStrings.verifyButton, onPressed: null))))),
            'levels' => const LevelsPage(),
            'tasks' => const TasksPage(),
            'vouchers' => const VoucherPage(),
            'discounts' => const DiscountCodesPage(),
            'deposit' => const DepositScreen(),
            'ads' => const AdScreen(),
            'create' => AdCreateScreen(repository: TestAdRepository()),
            'profile' => const ProfileScreen(),
            'home' => HomeScreen(onCreateTap: () {}, onToolsTap: () {}, onCreatePageTap: () {}, onFaqTap: () {}),
            _ => Scaffold(bottomNavigationBar: ProxoBottomNav(currentIndex: 0, onTap: (_) {})),
          };
          await t.pumpWidget(MaterialApp(locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
            theme: ThemeData(fontFamily: kAppFont, useMaterial3: true, scaffoldBackgroundColor: Colors.white),
            builder: (context, child) => ProxoLocaleScope(child: MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!)),
            home: RepaintBoundary(key: key, child: child)));
          Future<void> settle() async {
            await t.runAsync(() async { await Future<void>.delayed(const Duration(milliseconds: 60)); });
            for (var i=0;i<12;i++) { await t.pump(const Duration(milliseconds: 100)); }
          }
          await settle();
          if (section == 'signup') {
            final link = find.byWidgetPredicate((w) => w is AuthTextLink && w.label == AuthStrings.noAccountAction);
            await t.ensureVisible(link); await t.tap(link); await settle();
          }
          if (section == 'forgot') {
            await t.tap(find.text(AuthStrings.channelEmail).first); await settle();
            final link = find.byWidgetPredicate((w) => w is AuthTextLink && w.label == AuthStrings.forgotPasswordLink);
            await t.ensureVisible(link); await t.tap(link); await settle();
          }
          if (section == 'otp') { focus.unfocus(); await t.pump(); }
          final exceptions = <String>[];
          Object? error;
          while ((error = t.takeException()) != null) { exceptions.add(error.toString()); }
          final name = '$section-$language-${width.toInt()}-s$scale-d$dpr';
          await t.runAsync(() async {
            final directory = Directory('build/polish-evidence')..createSync(recursive:true);
            final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio:dpr);
            final bytes = await image.toByteData(format:ui.ImageByteFormat.png);
            await File('${directory.path}/$name.png').writeAsBytes(bytes!.buffer.asUint8List()); image.dispose();
            await File('${directory.path}/$name.json').writeAsString(jsonEncode({
              'source': before?'before':'after','section':section,'locale':language,
              'width':width,'height':852,'textScale':scale,'dpr':dpr,
              'exceptions':exceptions,'fixture':'fictional GET-only; OTP screen component; no authentication or payment sends',
            }));
          });
          if (['deposit','create','profile','home'].contains(section)) {
            final scroll = find.byType(Scrollable);
            if (scroll.evaluate().isNotEmpty) {
              final state = t.state<ScrollableState>(scroll.first);
              if (state.position.maxScrollExtent > 0) {
                state.position.jumpTo(state.position.maxScrollExtent);
                await settle();
                while ((error = t.takeException()) != null) { exceptions.add(error.toString()); }
                await t.runAsync(() async {
                  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
                  final shot = await boundary.toImage(pixelRatio:dpr);
                  final png = await shot.toByteData(format:ui.ImageByteFormat.png);
                  await File('build/polish-evidence/$name-bottom.png').writeAsBytes(png!.buffer.asUint8List()); shot.dispose();
                  await File('build/polish-evidence/$name-bottom.json').writeAsString(jsonEncode({
                    'source':before?'before':'after','section':section,'locale':language,
                    'width':width,'height':852,'textScale':scale,'dpr':dpr,'position':'bottom','exceptions':exceptions,
                  }));
                });
              }
            }
          }
          await t.pumpWidget(const SizedBox()); await t.pump();
          code.dispose(); focus.dispose();
          if (!before) expect(exceptions,isEmpty, reason:name);
        });
      }
    }
  }
}
