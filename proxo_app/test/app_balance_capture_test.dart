// Review evidence from production widgets, not synthetic mockups or goldens.
// All records are fictional. The transport rejects every write; capture never
// submits a payment, publishes a page or signs out a real account.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:proxo_app/models/proxo_card.dart';
import 'package:proxo_app/screens/deposit_screen.dart';
import 'package:proxo_app/screens/ad_detail_screen.dart';
import 'package:proxo_app/screens/home_screen.dart';
import 'package:proxo_app/screens/proxolink_create_page_screen.dart';
import 'package:proxo_app/screens/tools_screen.dart';
import 'package:proxo_app/screens/transaction_detail_screen.dart';
import 'package:proxo_app/services/best_metrics_service.dart';
import 'package:proxo_app/services/proxolink_service.dart';
import 'package:proxo_app/theme/app_locale.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/widgets/bottom_nav.dart';
import 'package:proxo_app/widgets/proxo_sidebar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integration_test/support/actual_screen_fixtures.dart';
import 'ad_receipt_data_test.dart' show receiptFixture;

const _output = 'build/app-balance-evidence';
const _permissions = MethodChannel('flutter.baseflow.com/permissions/methods');

class BalanceCaptureBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

class _EmptyToolsRepository extends ActualToolsRepository {
  @override
  Future<List<ProxoCard>> cards() async => [];
  @override
  Future<List<ProxoTemplate>> templates() async =>
      throw const ProxoLinkFailure('network_error');
}

Finder _key(String name) => find.byKey(ValueKey(name));
Finder _depositScroll() => find
    .descendant(of: _key('deposit-scroll'), matching: find.byType(Scrollable))
    .first;

Future<void> _reveal(WidgetTester t, Finder target, Finder scroll) async {
  await t.scrollUntilVisible(target, 220, scrollable: scroll);
  await t.ensureVisible(target);
  await t.pumpAndSettle();
}

Future<void> _bottom(WidgetTester t, Finder finder) async {
  final position = t.state<ScrollableState>(finder).position;
  for (var pass = 0; pass < 5; pass++) {
    position.jumpTo(position.maxScrollExtent);
    await t.pumpAndSettle();
  }
}

Future<void> _capture(WidgetTester t, GlobalKey boundaryKey, String name,
    ({double width, double height, double scale}) config,
    {bool settle = true}) async {
  final images = find.byType(Image).evaluate().toList();
  final errors = <Object>[];
  await t.runAsync(() async {
    await Future.wait(images.map((element) => precacheImage(
          (element.widget as Image).image,
          element,
          onError: (error, stack) => errors.add(error),
        ))).timeout(const Duration(seconds: 20));
  });
  expect(errors, isEmpty, reason: 'All mounted image assets must decode');
  if (settle) {
    await t.pumpAndSettle();
  } else {
    await t.pump(const Duration(milliseconds: 300));
  }
  expect(t.takeException(), isNull);
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final measurements = <Map<String, Object?>>[];
  final seen = <RenderObject>{};
  void visit(Element element) {
    final widget = element.widget;
    final render = element.findRenderObject();
    if (render is RenderBox &&
        render.hasSize &&
        render.attached &&
        (widget.key != null ||
            render is RenderParagraph ||
            widget is SvgPicture ||
            widget is Image ||
            widget is IconButton)) {
      if (seen.add(render)) {
        final rect = MatrixUtils.transformRect(
            render.getTransformTo(boundary), Offset.zero & render.size);
        final record = <String, Object?>{
          'widget': widget.runtimeType.toString(),
          'key': widget.key?.toString(),
          'bounds_dp': [rect.left, rect.top, rect.width, rect.height],
          'intersects_viewport': rect.overlaps(Offset.zero & boundary.size),
        };
        if (widget is IconButton) {
          record['tooltip'] = widget.tooltip;
          record['enabled'] = widget.onPressed != null;
        }
        if (render is RenderParagraph) {
          record.addAll({
            'text': render.text.toPlainText(),
            'font_family': render.text.style?.fontFamily,
            'font_size': render.text.style?.fontSize,
            'text_scale': render.textScaler.scale(1),
            'exceeded_max_lines': render.didExceedMaxLines,
          });
        }
        measurements.add(record);
      }
    }
    element.visitChildren(visit);
  }

  (boundaryKey.currentContext! as Element).visitChildren(visit);
  await t.runAsync(() async {
    final output = Directory(_output)..createSync(recursive: true);
    final shot = await boundary.toImage(pixelRatio: 2);
    final bytes = await shot.toByteData(format: ui.ImageByteFormat.png);
    File('${output.path}/$name.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
    shot.dispose();
    File('${output.path}/$name.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
      'fixture': 'Fictional records; actual production widgets; no writes',
      'runtime': 'Flutter widget test on Linux; not a device performance test',
      'viewport_dp': [config.width, config.height],
      'capture_pixel_ratio': 2,
      'device_pixel_ratio': 2,
      'text_scale': config.scale,
      'safe_area_dp': {'top': 24, 'bottom': 16},
      'mounted_images_decoded': images.length,
      'layout_exceptions': 0,
      'nodes': measurements,
    }));
  });
}

void main() {
  BalanceCaptureBinding();
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_permissions, (_) async => 1);
    await backend.initialize();
    backend.readResponses['pa_featured_ads_public'] = [
      {
        'id': 'fixture-beauty',
        'goal': 'messages',
        'category': 'cosmetics_beauty',
        'video_link': null,
        'thumbnail_url': null,
        'clicks': 1246,
        'impressions': 84320,
        'spend': 12.5,
        'daily_budget': 10,
        'days': 3,
        'service_budget_usd': 30,
        'featured_sort': 1,
        'created_at': '2026-10-19T09:00:00Z',
        'featured_week_start': '2026-10-19',
        'is_featured': true,
      },
    ];
  });
  tearDownAll(() async {
    await backend.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_permissions, null);
  });

  for (final config in [
    (width: 393.0, height: 852.0, scale: 1.0),
    (width: 320.0, height: 740.0, scale: 2.0),
  ]) {
    for (final screen in [
      'transaction-receipt',
      'ad-receipt',
      'home',
      'deposit',
      'deposit-fib',
      'deposit-fastpay',
      'deposit-kcard',
      'tools',
      'menu',
    ]) {
      testWidgets('actual balanced $screen ${config.width} ${config.scale}',
          (t) async {
        t.view.devicePixelRatio = 2;
        t.view.physicalSize = Size(config.width * 2, config.height * 2);
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        ProxoLocale.current.value = const Locale('ckb');
        BestMetricsService.invalidateCache();
        final boundaryKey = GlobalKey();
        final name = '$screen-${config.width.toInt()}-s${config.scale.toInt()}';
        var logoutAttempts = 0;
        final adReceipt = receiptFixture()
          ..['title'] = 'Fictional campaign'
          ..['thumbnail_url'] = null;
        final Widget surface = switch (screen) {
          'ad-receipt' => AdDetailScreen(
              adId: adReceipt['id'] as String, initialAd: adReceipt,
              loadAd: (_) async => adReceipt),
          'home' => Scaffold(
              body: HomeScreen(
                  onMenuTap: () {},
                  onCreateTap: () {},
                  onAddBalanceTap: () {},
                  onCreatePageTap: () {}),
              bottomNavigationBar:
                  ProxoBottomNav(currentIndex: 0, onTap: (_) {})),
          'tools' => ToolsScreen(repository: _EmptyToolsRepository()),
          'menu' => Scaffold(
              body: Align(
                  alignment: Alignment.centerRight,
                  child: ProxoSidebar(
                      onClose: () {},
                      onNavigate: (_) {},
                      signOut: () async {
                        logoutAttempts++;
                        throw StateError('isolated_capture_logout_failure');
                      }))),
          'transaction-receipt' => TransactionDetailScreen(
              data: TxReceiptData(
                  kind: TxReceiptKind.topUp,
                  status: 'approved',
                  txId: 'FICTIONAL-RECEIPT',
                  uid: screenFixtureOwner,
                  date: DateTime.utc(2026, 10, 19, 9),
                  usd: 10,
                  amountIqd: 18000,
                  balanceBefore: null,
                  balanceAfter: null,
                  method: 'fib',
                  gateway: 'fib',
                  type: 'deposit',
                  adName: null,
                  voucherCode: null)),
          _ => DepositScreen(
              pickReceipt: (_) async =>
                  XFile('$_output/transaction-receipt-393-s1.png')),
        };
        await t.pumpWidget(MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: buildAppTheme(),
          builder: (context, child) => ProxoLocaleScope(
              child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(config.scale),
                    padding: const EdgeInsets.only(top: 24, bottom: 16),
                    disableAnimations: true,
                  ),
                  child: RepaintBoundary(key: boundaryKey, child: child!))),
          home: surface,
        ));
        await t.pumpAndSettle();
        await t.pump(const Duration(milliseconds: 600));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        if (screen.startsWith('deposit-')) {
          final method = screen.substring('deposit-'.length);
          await _reveal(t, _key('deposit-method-$method'), _depositScroll());
          await t.tap(_key('deposit-method-$method'));
          await t.pumpAndSettle();
          await _reveal(t, _key('deposit-amount'), _depositScroll());
          await t.enterText(_key('deposit-amount'), '25000');
          FocusManager.instance.primaryFocus?.unfocus();
          await t.pumpAndSettle();
          await _capture(t, boundaryKey, '$name-amount', config);
          if (method != 'fastpay') {
            await _reveal(t, _key('deposit-recipient'), _depositScroll());
            await _capture(t, boundaryKey, '$name-details', config);
            await _reveal(t, _key('deposit-instructions'), _depositScroll());
            await t.tap(_key('deposit-instructions'));
            await t.pumpAndSettle();
            await _capture(t, boundaryKey, '$name-instructions', config);
            await _reveal(t, _key('deposit-instructions'), _depositScroll());
            await t.tap(_key('deposit-instructions'));
            await t.pumpAndSettle();
            await _bottom(t, _depositScroll());
            await _capture(t, boundaryKey, '$name-receipt', config);
            expect(t.getSize(_key('deposit-submit')).height,
                greaterThanOrEqualTo(48));
            if (method == 'fib') {
              // Start FileImage decoding in the real async zone before the
              // picker mounts it; a decoder first opened inside FakeAsync can
              // otherwise leave a pending cache entry across capture waits.
              await t.runAsync(() => precacheImage(
                  FileImage(File('$_output/transaction-receipt-393-s1.png')),
                  t.element(find.byType(DepositScreen))));
              await _reveal(t, _key('deposit-pick-receipt'), _depositScroll());
              await t.tap(_key('deposit-pick-receipt'));
              await t.pump(const Duration(milliseconds: 400));
              await _capture(t, boundaryKey, '$name-receipt-picker', config,
                  settle: false);
              await t.tap(_key('deposit-gallery'));
              await t.pump();
              await t.pump(const Duration(milliseconds: 400));
              // The route transition and real file IO complete in different
              // clocks. Pump frames between bounded real-IO opportunities.
              for (var attempt = 0;
                  attempt < 30 &&
                      _key('deposit-change-receipt').evaluate().isEmpty;
                  attempt++) {
                await t.runAsync(() async {
                  await Future<void>.delayed(const Duration(milliseconds: 50));
                });
                await t.pump(const Duration(milliseconds: 100));
              }
              expect(_key('deposit-change-receipt'), findsOneWidget);
              await t.pumpAndSettle();
              await _bottom(t, _depositScroll());
              await _capture(t, boundaryKey, '$name-receipt-attached', config);
            }
          } else {
            await _bottom(t, _depositScroll());
            await _capture(t, boundaryKey, '$name-checkout-entry', config);
          }
        } else {
          await _capture(t, boundaryKey, name, config);
          if (screen == 'home') {
            final scroll = find.byType(Scrollable).first;
            await _reveal(t, _key('result-details-fixture-beauty'), scroll);
            await t.tap(_key('result-details-fixture-beauty'));
            await t.pumpAndSettle();
            expect(_key('result-expanded-fixture-beauty'), findsWidgets);
            await _capture(t, boundaryKey, '$name-expanded', config);
            await _bottom(t, scroll);
            await _capture(t, boundaryKey, '$name-expanded-bottom', config);
          } else if (screen == 'tools') {
            expect(find.byType(ProxoLinkCreatePageScreen), findsNothing,
                reason: 'Empty tools must not open the creation route');
            final scroll = find.byType(Scrollable).first;
            await _reveal(t, _key('tools-create-page'), scroll);
            if (config.scale > 1) {
              await _capture(t, boundaryKey, '$name-action', config);
            }
            await t.tap(_key('tools-create-page'));
            await t.pumpAndSettle();
            expect(_key('create-page-load-error'), findsOneWidget);
            await _capture(t, boundaryKey, '$name-create-unavailable', config);
          } else if (screen == 'menu') {
            final scroll = find
                .descendant(
                    of: _key('sidebar-scroll'),
                    matching: find.byType(Scrollable))
                .first;
            await _bottom(t, scroll);
            await _capture(t, boundaryKey, '$name-bottom', config);
            await _reveal(t, _key('sidebar-logout'), scroll);
            await t.tap(_key('sidebar-logout'));
            await t.pumpAndSettle();
            await _bottom(t, scroll);
            expect(logoutAttempts, 1);
            expect(backend.client.auth.currentSession, isNotNull);
            expect(_key('sidebar-logout-error'), findsOneWidget);
            await _capture(t, boundaryKey, '$name-logout-error', config);
          } else if (screen == 'deposit') {
            for (final method in ['zaincash', 'asiacell', 'korek']) {
              await _reveal(
                  t, _key('deposit-method-$method'), _depositScroll());
              expect(t.widget<InkWell>(_key('deposit-method-$method')).onTap,
                  isNull,
                  reason: 'Unconfigured method must remain disabled');
            }
            await _capture(
                t, boundaryKey, '$name-unconfigured-methods', config);
          } else if (screen == 'transaction-receipt' || screen == 'ad-receipt') {
            final scroll = find.byType(Scrollable).first;
            final position = t.state<ScrollableState>(scroll).position;
            if (position.maxScrollExtent > config.height) {
              position.jumpTo(position.maxScrollExtent / 2);
              await t.pumpAndSettle();
              await _capture(t, boundaryKey, '$name-middle', config);
            }
            await _bottom(t, scroll);
            await _capture(t, boundaryKey, '$name-bottom', config);
          }
        }
        expect(backend.logoutRequests, 0);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
      }, timeout: const Timeout(Duration(seconds: 90)));
    }
  }
}
