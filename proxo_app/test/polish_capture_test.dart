import 'package:proxo_app/screens/auth/new_password_screen.dart';
import 'package:proxo_app/screens/best_metrics_screen.dart';
import 'package:proxo_app/widgets/best_metrics_home_section.dart';

import 'home_sections_test.dart' show examples;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:proxo_app/screens/notifications_screen.dart';
import 'package:proxo_app/widgets/proxo_sidebar.dart';
import 'package:proxo_app/widgets/levels_page.dart';
import 'package:proxo_app/widgets/tasks_page.dart';

// Actual production widgets; fictional read-only backend; no OTP/payment sends.
import 'dart:convert';
import 'dart:async';
import 'package:proxo_app/screens/splash_screen.dart';
import 'package:proxo_app/widgets/proxo_refresh.dart';
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
  @override
  bool get disableShadows => false;
}

// Geometry comes from actual laid-out RenderObjects, not inferred screenshots.
List<Map<String, Object?>> measuredLayout(GlobalKey key) {
  final root = key.currentContext! as Element;
  final origin = (root.findRenderObject() as RenderBox).localToGlobal(
    Offset.zero,
  );
  final seen = <RenderObject>{};
  final rows = <Map<String, Object?>>[];
  void visit(Element e) {
    final w = e.widget;
    final r = e.findRenderObject();
    if (r is RenderBox &&
        r.hasSize &&
        (r is RenderParagraph ||
            w is Container ||
            w is Material ||
            w is InkWell ||
            w is TextField ||
            w is Image ||
            w is SvgPicture)) {
      if (seen.add(r)) {
        final at = r.localToGlobal(Offset.zero) - origin;
        final row = <String, Object?>{
          'widget': w.runtimeType.toString(),
          'key': w.key?.toString(),
          'bounds_dp': [at.dx, at.dy, r.size.width, r.size.height],
        };
        if (r is RenderParagraph) {
          row.addAll({
            'text': r.text.toPlainText(),
            'font_family': r.text.style?.fontFamily,
            'font_size': r.text.style?.fontSize,
            'font_weight': r.text.style?.fontWeight?.index,
            'line_height': r.text.style?.height,
            'text_scale': r.textScaler.scale(1),
            'exceeded_max_lines': r.didExceedMaxLines,
          });
        }
        if (w is Container && w.decoration is BoxDecoration) {
          final d = w.decoration as BoxDecoration;
          row.addAll({
            'radius': d.borderRadius?.toString(),
            'padding': w.padding?.toString(),
            'color': d.color?.toARGB32(),
          });
        }
        if (w is Image) row['image'] = w.image.toString();
        if (w is SvgPicture) row['svg'] = w.bytesLoader.toString();
        if (w is Material) row['shape'] = w.shape?.toString();
        rows.add(row);
      }
    }
    e.visitChildren(visit);
  }

  visit(root);
  return rows;
}

// Decode bundled PNGs before capturing. pumpAndSettle alone does not wait
// for the engine image codec outside the widget test's fake clock.
Future<void> settleLocalImages(WidgetTester tester) async {
  final elements = find
      .byType(Image)
      .evaluate()
      .where(
        (e) => ((e.widget as Image).image is AssetImage ||
            (e.widget as Image).image is ResizeImage),
      )
      .toList();
  await tester.runAsync(() async {
    await Future.wait(elements.map((e) => precacheImage(
          (e.widget as Image).image,
          e,
        )));
  });
  await tester.pump();
  for (final element in elements) {
    final raw = find.descendant(
        of: find.byWidget(element.widget), matching: find.byType(RawImage));
    expect(raw, findsOneWidget);
    expect(tester.widget<RawImage>(raw).image, isNotNull,
        reason: 'Bundled icon must be decoded in the actual captured widget');
  }
}

void main() {
  PolishBinding();
  final backend = ActualScreenBackend();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family'] as String);
      for (final file in font['fonts'] as List) {
        loader.addFont(rootBundle.load(file['asset'] as String));
      }
      await loader.load();
    }
    await backend.initialize();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/permissions/methods'),
      (_) async => 1,
    );
  });
  tearDownAll(() async {
    await backend.dispose();
    ProxoLocale.current.value = ProxoLocale.kurdishSorani;
  });
  for (final config in [
    (393.0, 1.0, 3.0),
    (320.0, 1.0, 2.0),
    (280.0, 1.0, 2.0),
    (280.0, 2.0, 2.0)
  ]) {
    for (final language in ['ckb', 'ar', 'kmr']) {
      for (final section in [
        'login',
        'login-phone',
        'login-phone-filled',
        'signup',
        'signup-filled',
        'forgot',
        'new-password',
        'otp',
        'otp-filled',
        'splash',
        'refresh',
        'results-banner',
        'results',
        'results-empty',
        'deposit',
        'ads',
        'create',
        'profile',
        'home',
        'navigation',
        'levels',
        'tasks',
        'vouchers',
        'discounts',
        'notifications',
      ]) {
        testWidgets('$section $language $config', (t) async {
          final (width, scale, dpr) = config;
          t.view.devicePixelRatio = dpr;
          t.view.physicalSize = Size(width * dpr, 852 * dpr);
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          ProxoLocale.current.value = Locale(language);
          backend.includeNotifications = section == 'notifications';
          final key = GlobalKey();
          final code = TextEditingController();
          final refresh = ProxoRefreshController();
          Future<void>? refreshing;
          final focus = FocusNode();
          final password = TextEditingController(),
              confirmation = TextEditingController();
          final passwordVisible = ValueNotifier(false),
              confirmationVisible = ValueNotifier(false);
          final child = switch (section) {
            'login' ||
            'login-phone' ||
            'login-phone-filled' ||
            'signup' ||
            'signup-filled' ||
            'forgot' =>
              const AuthShell(),
            'new-password' => Scaffold(
                body: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: NewPasswordScreen(
                      onBack: () {},
                      password: password,
                      confirmation: confirmation,
                      passwordVisible: passwordVisible,
                      confirmationVisible: confirmationVisible,
                      onSave: () async {},
                    ),
                  ),
                ),
              ),
            'results-banner' => Scaffold(
                body: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: BestMetricsHomeSection(
                      autoPlay: false,
                      loadPreview: ({bool forceRefresh = false}) async =>
                          examples(),
                    ),
                  ),
                ),
              ),
            'results' => BestMetricsScreen(
                initialAds: examples(),
                initialAdId: 'beauty',
                loadResults: ({bool forceRefresh = false}) async => examples(),
              ),
            'results-empty' => BestMetricsScreen(
                loadResults: ({bool forceRefresh = false}) async => [],
              ),
            'splash' => const Scaffold(body: SplashArtwork()),
            'otp' || 'otp-filled' => Scaffold(
                body: SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: OtpScreen(
                      onBack: () {},
                      destination: '+96475***0000',
                      otpBoxes: AuthOtpBoxes(
                        length: 6,
                        codeController: code,
                        firstBoxFocus: focus,
                        onCompleted: (_) {},
                      ),
                      resend: AuthTextLink(
                        label: AuthStrings.resendAction,
                        onTap: () {},
                      ),
                      verifyButton: AuthPrimaryButton(
                        label: AuthStrings.verifyButton,
                        onPressed: null,
                      ),
                    ),
                  ),
                ),
              ),
            'notifications' => const NotificationsScreen(),
            'levels' => const LevelsPage(),
            'tasks' => const TasksPage(),
            'vouchers' => const VoucherPage(),
            'discounts' => const DiscountCodesPage(),
            'deposit' => const DepositScreen(),
            'ads' => const AdScreen(),
            'create' => AdCreateScreen(repository: TestAdRepository()),
            'profile' => const ProfileScreen(),
            'home' || 'refresh' => HomeScreen(
                refreshController: refresh,
                onCreateTap: () {},
                onAddBalanceTap: () {},
                onToolsTap: () {},
                onCreatePageTap: () {},
                onFaqTap: () {},
              ),
            _ => Scaffold(
                bottomNavigationBar: ProxoBottomNav(
                  currentIndex: 0,
                  onTap: (_) {},
                ),
              ),
          };
          await t.pumpWidget(
            MaterialApp(
              locale: const Locale('ar'),
              supportedLocales: const [Locale('ar')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: buildAppTheme(),
              builder: (context, child) => ProxoLocaleScope(
                child: MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
              ),
              home: RepaintBoundary(key: key, child: child),
            ),
          );
          Future<void> settle() async {
            await t.runAsync(() async {
              await Future<void>.delayed(const Duration(milliseconds: 60));
            });
            for (var i = 0; i < 12; i++) {
              await t.pump(const Duration(milliseconds: 100));
            }
          }

          await settle();
          if (section == 'login-phone' || section == 'login-phone-filled') {
            await t.tap(find.text(AuthStrings.channelPhone).first);
            await settle();
          }
          if (section == 'login-phone-filled') {
            await t.enterText(find.byType(TextField).first, '7501234567');
            FocusManager.instance.primaryFocus?.unfocus();
            await settle();
          }
          if (section == 'signup' || section == 'signup-filled') {
            final link = find.byWidgetPredicate(
              (w) =>
                  w is AuthTextLink && w.label == AuthStrings.noAccountAction,
            );
            await t.ensureVisible(link);
            await t.tap(link);
            await settle();
          }
          if (section == 'signup-filled') {
            await t.enterText(find.byType(TextField).at(0), 'هێمن ئەحمەد');
            await t.enterText(find.byType(TextField).at(1), '7501234567');
            await t.enterText(find.byType(TextField).at(2), 'Example#2026');
            await t.enterText(find.byType(TextField).at(3), 'Example#2026');
            FocusManager.instance.primaryFocus?.unfocus();
            await settle();
            // Let the input's scheduled ensureVisible finish before framing
            // the filled-form evidence at the top of the same screen.
            t
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position
                .jumpTo(0);
            await t.pump();
          }
          if (section == 'forgot') {
            await t.tap(find.text(AuthStrings.channelEmail).first);
            await settle();
            final link = find.byWidgetPredicate(
              (w) =>
                  w is AuthTextLink &&
                  w.label == AuthStrings.forgotPasswordLink,
            );
            await t.ensureVisible(link);
            await t.tap(link);
            await settle();
          }
          if (section == 'otp-filled') {
            await t.enterText(find.byType(TextField).first, '123456');
            await t.pump();
          }
          if (section == 'otp' || section == 'otp-filled') {
            focus.unfocus();
            await t.pump();
          }
          if (!before &&
              ['signup', 'signup-filled', 'forgot'].contains(section)) {
            expect(
              t
                  .state<ScrollableState>(find.byType(Scrollable).first)
                  .position
                  .pixels,
              0,
              reason:
                  'A new Auth step must start at its heading, not inherit the previous form scroll',
            );
          }
          if (section == 'refresh') {
            refreshing = refresh.refresh();
            await t.pump();
            for (var frame = 0; frame < 20; frame++) {
              await t.pump(const Duration(milliseconds: 16));
            }
            expect(find.byKey(const ValueKey('refresh-status-label')),
                findsOneWidget);
          }
          await settleLocalImages(t);
          if (section == 'ads' && scale == 2) {
            final title = find.text('Fictional screen fixture');
            expect(title, findsOneWidget);
            final paragraph = t.renderObject<RenderParagraph>(title);
            expect(paragraph.textScaler.scale(14), 28,
                reason:
                    'Ads list must honor the same accessibility scale as the app');
          }
          final exceptions = <String>[];
          Object? error;
          while ((error = t.takeException()) != null) {
            exceptions.add(error.toString());
          }
          final name = '$section-$language-${width.toInt()}-s$scale-d$dpr';
          await t.runAsync(() async {
            final directory = Directory('build/polish-evidence')
              ..createSync(recursive: true);
            final boundary = key.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: dpr);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File('${directory.path}/$name.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
            await File('${directory.path}/$name.json').writeAsString(
              jsonEncode({
                'source': before ? 'before' : 'after',
                'section': section,
                'locale': language,
                'width': width,
                'height': 852,
                'textScale': scale,
                'dpr': dpr,
                'layout': measuredLayout(key),
                'exceptions': exceptions,
                'fixture':
                    'fictional GET-only; OTP/new-password production components; Results fixture metrics and missing-thumbnail fallback; no authentication or payment sends',
              }),
            );
          });
          if ([
            'deposit',
            'create',
            'profile',
            'home',
            'login',
            'login-phone',
            'signup',
            'signup-filled',
            'forgot',
            'new-password',
            'results-banner',
            'results',
          ].contains(section)) {
            final scroll = find.byType(Scrollable);
            if (scroll.evaluate().isNotEmpty) {
              final state = t.state<ScrollableState>(scroll.first);
              if (state.position.maxScrollExtent > 0) {
                state.position.jumpTo(state.position.maxScrollExtent);
                await settle();
                while ((error = t.takeException()) != null) {
                  exceptions.add(error.toString());
                }
                await t.runAsync(() async {
                  final boundary = key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
                  final shot = await boundary.toImage(pixelRatio: dpr);
                  final png = await shot.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  await File('build/polish-evidence/$name-bottom.png')
                      .writeAsBytes(png!.buffer.asUint8List());
                  shot.dispose();
                  await File('build/polish-evidence/$name-bottom.json')
                      .writeAsString(
                    jsonEncode({
                      'source': before ? 'before' : 'after',
                      'section': section,
                      'locale': language,
                      'width': width,
                      'height': 852,
                      'textScale': scale,
                      'dpr': dpr,
                      'position': 'bottom',
                      'layout': measuredLayout(key),
                      'exceptions': exceptions,
                    }),
                  );
                });
              }
            }
          }
          try {
            if (refreshing != null) {
              await settle();
              await t.pump(const Duration(seconds: 1));
              await refreshing;
            }
            await t.pumpWidget(const SizedBox());
            await t.pump();
          } catch (error) {
            exceptions.add(error.toString());
          }
          while ((error = t.takeException()) != null) {
            exceptions.add(error.toString());
          }
          await t.runAsync(() async {
            await File('build/polish-evidence/$name-lifecycle.json')
                .writeAsString(
              jsonEncode({
                'section': section,
                'locale': language,
                'width': width,
                'textScale': scale,
                'exceptions': exceptions,
              }),
            );
          });
          refresh.dispose();
          code.dispose();
          focus.dispose();
          password.dispose();
          confirmation.dispose();
          passwordVisible.dispose();
          confirmationVisible.dispose();
          if (!before) expect(exceptions, isEmpty, reason: name);
        });
      }
    }
  }
}
