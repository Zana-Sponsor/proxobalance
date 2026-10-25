import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/screens/ad_screen.dart';
import 'package:proxo_app/screens/home_screen.dart';
import 'package:proxo_app/screens/best_metrics_screen.dart';
import 'package:proxo_app/screens/proxolink_create_page_screen.dart';
import 'package:proxo_app/services/app_update_service.dart';
import 'package:proxo_app/theme/app_locale.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/widgets/app_update_host.dart';
import 'package:proxo_app/widgets/proxo_sidebar.dart';
import 'package:proxo_app/widgets/proxo_png_icon.dart';
import '../integration_test/support/actual_screen_fixtures.dart';
import 'app_update_service_test.dart' show policy;
import 'home_sections_test.dart' show examples;
import 'polish_capture_test.dart'
    show PolishBinding, measuredLayout, settleLocalImages;
import 'proxolink_tools_create_test.dart' show ToolsRepository;

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
  });
  tearDownAll(backend.dispose);
  for (final config in [
    (393.0, 1.0),
    (320.0, 1.0),
    (280.0, 1.0),
    (280.0, 2.0)
  ]) {
    for (final screen in [
      'menu',
      'update-optional',
      'update-required',
      'best-results-expanded',
      'page-error',
      'ads-empty'
    ]) {
      testWidgets('app-wide $screen $config', (t) async {
        final (width, scale) = config;
        t.view.devicePixelRatio = 2;
        t.view.physicalSize = Size(width * 2, 852 * 2);
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        ProxoLocale.current.value = ProxoLocale.kurdishSorani;
        backend.emptyAds = screen == 'ads-empty';
        addTearDown(() => backend.emptyAds = false);
        final key = GlobalKey();
        final prefs = await SharedPreferences.getInstance();
        final required = screen == 'update-required';
        final updates = AppUpdateService(
            preferences: prefs,
            fetch: (_, __) async => policy(required: required));
        final child = switch (screen) {
          'menu' => const Scaffold(body: SafeArea(child: ProxoSidebar())),
          'best-results-expanded' => BestMetricsScreen(
              initialAds: examples(),
              initialAdId: examples().first.id,
              loadResults: ({bool forceRefresh = true}) async => examples()),
          'page-error' =>
            ProxoLinkCreatePageScreen(repository: ToolsRepository([])),
          'ads-empty' => const AdScreen(),
          _ => HomeScreen(onCreateTap: () {}),
        };
        await t.pumpWidget(MaterialApp(
            theme: buildAppTheme(),
            builder: (context, navigator) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: RepaintBoundary(
                        key: key,
                        child: screen.startsWith('update-')
                            ? AppUpdateHost(
                                key: ValueKey(screen),
                                client: backend.client,
                                service: updates,
                                platform: 'android',
                                installedBuild: 10,
                                launch: (_) async => false,
                                child: navigator!)
                            : navigator!))),
            home: child));
        await t.pumpAndSettle();
        await settleLocalImages(t);
        if (screen == 'page-error') {
          final submit = find.byKey(const ValueKey('create-page-submit'));
          await t.ensureVisible(submit);
          await t.pumpAndSettle();
          await t.tap(submit);
          await t.pump();
        }
        if (screen == 'best-results-expanded') {
          final details =
              find.byKey(ValueKey('result-details-${examples().first.id}'));
          await t.ensureVisible(details);
          await t.tap(details);
          await t.pumpAndSettle();
          expect(find.byKey(ValueKey('result-expanded-${examples().first.id}')),
              findsOneWidget);
        }
        if (screen == 'menu') expect(find.byType(ProxoPngIcon), findsWidgets);
        expect(t.takeException(), isNull);
        Future<void> capture(String suffix) async {
          await settleLocalImages(t);
          final layout = measuredLayout(key);
          await t.runAsync(() async {
            final directory = Directory(
                '../docs/app-wide-release-2026-10-26/screenshots/app-states')
              ..createSync(recursive: true);
            final name = '$screen-${width.toInt()}-s$scale$suffix';
            final image = await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            await File('${directory.path}/$name.png')
                .writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
            await File('${directory.path}/$name.json')
                .writeAsString(jsonEncode({
              'screen': screen,
              'width': width,
              'text_scale': scale,
              'source':
                  'actual Flutter widgets with isolated fictional backend/release fixtures',
              'layout': layout,
              'errors': <String>[],
            }));
          });
        }

        await capture('');
        if (screen == 'menu' || screen == 'best-results-expanded') {
          final scrolls = t
              .stateList<ScrollableState>(find.byType(Scrollable))
              .where((s) => s.axisDirection == AxisDirection.down)
              .toList();
          if (scrolls.isNotEmpty &&
              scrolls.first.position.maxScrollExtent > 0) {
            scrolls.first.position
                .jumpTo(scrolls.first.position.maxScrollExtent);
            await t.pump();
            await capture('-bottom');
          }
        }
        if (screen == 'page-error') {
          await t.tap(find.byKey(const ValueKey('notice-dismiss')));
          await t.pump();
          expect(find.byKey(const ValueKey('notice-dismiss')), findsNothing);
        }
        await t.pumpWidget(const SizedBox.shrink());
        expect(t.takeException(), isNull);
      });
    }
  }
}
