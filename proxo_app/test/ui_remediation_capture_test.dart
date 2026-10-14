// Same harness is run against the immutable baseline and candidate sources.
// Captures are review evidence, never automatically approved golden files.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/screens/home_screen.dart';
import 'package:proxo_app/screens/ad_detail_screen.dart';
import 'package:proxo_app/screens/proxolink_create_page_screen.dart';
import 'package:proxo_app/screens/proxolink_page_details_screen.dart';
import 'package:proxo_app/screens/proxolink_page_editor_screen.dart';

import 'proxolink_tools_create_test.dart' show ToolsRepository;
import 'proxolink_page_management_test.dart' show page;

import 'package:proxo_app/screens/tools_screen.dart';
import 'package:proxo_app/screens/ad_create_screen.dart';
import 'package:proxo_app/screens/ad_confirmation_screen.dart';
import 'package:proxo_app/screens/transaction_detail_screen.dart';
import 'package:proxo_app/services/ad_submission.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/theme/app_locale.dart';
import 'package:proxo_app/widgets/home_quick_actions.dart';
import 'package:proxo_app/widgets/bottom_nav.dart';
import 'package:proxo_app/widgets/receipt/receipt_kit.dart';
import 'package:proxo_app/widgets/receipt/tx_history_layout.dart';

import 'ad_creation_flow_test.dart' show TestAdRepository;
import 'ad_submission_test.dart' show validDraft;
import 'ad_receipt_data_test.dart' show receiptFixture;
import '../integration_test/support/actual_screen_fixtures.dart';

class EvidenceBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

const output = 'build/ui-remediation';
const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
void main() {
  EvidenceBinding();
  final backend = ActualScreenBackend();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await (FontLoader(
      'Rabar',
    )..addFont(rootBundle.load('assets/fonts/Rabar_021.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissions, (_) async => 1);
    await backend.initialize();
  });
  tearDownAll(() async {
    await backend.dispose();
  });
  for (final config in [
    (280.0, 1.0, 1.0),
    (393.0, 1.0, 3.0),
    (393.0, 2.0, 1.0),
    (768.0, 1.0, 2.0),
  ]) {
    for (final screen in [
      'home',
      'actions',
      'history',
      'receipt',
      'ad-receipt',
      'create',
      'confirmation',
      'confirmation-error',
      'confirmation-unknown',
      'tools',
      'page-contact',
      'page-order',
      'page-download',
      'page-details',
      'page-edit',
      'navigation',
    ]) {
      testWidgets('render $screen $config', (t) async {
        print('EVIDENCE start $screen $config');
        final (width, scale, dpr) = config;
        t.view.devicePixelRatio = dpr;
        t.view.physicalSize = Size(width * dpr, 852 * dpr);
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final key = GlobalKey();
        final request = AdPendingSubmission.create(
          validDraft(),
          const AdQuote(grossUsd: 10, costUsd: 10, rate: 1800),
        );
        // Adapt only the callback API introduced by this change. The baseline
        // has no add-balance argument; all available actions remain enabled.
        final callbacks = <Symbol, dynamic>{
          #onCreateTap: () {},
          #onToolsTap: () {},
          #onCreatePageTap: () {},
          #onFaqTap: () {},
          if (!const bool.fromEnvironment('BASELINE_CAPTURE'))
            #onAddBalanceTap: () {},
        };
        final child = switch (screen) {
          'home' => Function.apply(HomeScreen.new, [], callbacks) as Widget,
          'actions' => Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Function.apply(
                  HomeQuickActions.new,
                  [],
                  callbacks,
                ) as Widget,
              ),
            ),
          ),
          'history' => TxHistoryLayout(
            title: 'مێژووی مامەڵەکان',
            backLabel: 'گەڕانەوە',
            refreshLabel: 'نوێکردنەوە',
            onBack: () {},
            onRefresh: () {},
            refreshing: false,
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TxHistoryCard(
                  date: '14/10/2026',
                  time: '01:58 AM',
                  amount: '+18,000 د.ع',
                  amountColor: ReceiptTokens.positive,
                  onTap: () {},
                ),
              ],
            ),
          ),
          'receipt' => TransactionDetailScreen(
            data: TxReceiptData(
              kind: TxReceiptKind.topUp,
              status: 'approved',
              txId: 'TX4UFQVLZ4J6',
              uid: '83062db4-47d0-4ce1-a3b4-33a766783553',
              date: DateTime.utc(2026, 10, 13, 22, 58),
              usd: 10,
              amountIqd: 18000,
              balanceBefore: null,
              balanceAfter: null,
              method: 'fastpay',
              gateway: 'fastpay',
              type: 'deposit',
              adName: null,
              voucherCode: null,
            ),
          ),
          'ad-receipt' => AdDetailScreen(
            adId: receiptFixture()['id'] as String,
            initialAd: receiptFixture(),
            loadAd: (_) async => receiptFixture(),
          ),
          'create' => AdCreateScreen(
            repository: TestAdRepository(),
            proxoCard: validDraft().toJson(),
          ),
          'confirmation' => AdConfirmationScreen(
            request: request,
            repository: TestAdRepository(),
            countdown: const Duration(hours: 1),
          ),
          'confirmation-error' ||
          'confirmation-unknown' => AdConfirmationScreen(
            request: request,
            repository: TestAdRepository()
              ..failure = AdSubmissionFailure(
                'NETWORK',
                uncertain: screen.endsWith('unknown'),
              ),
            countdown: const Duration(milliseconds: 100),
          ),
          'page-contact' || 'page-order' || 'page-download' =>
            ProxoLinkCreatePageScreen(repository: ToolsRepository([])),
          'page-details' => ProxoLinkPageDetailsScreen(
            initialPage: page(1),
            repository: ToolsRepository([page(1)]),
          ),
          'page-edit' => ProxoLinkPageEditorScreen(
            existing: page(1),
            repository: ToolsRepository([page(1)]),
          ),
          'tools' => ToolsScreen(repository: ActualToolsRepository()),
          _ => Scaffold(
            bottomNavigationBar: ProxoBottomNav(currentIndex: 0, onTap: (_) {}),
          ),
        };
        await t.pumpWidget(
          MaterialApp(
            // Match the production MaterialApp's Sorani framework mapping,
            // locale scope, seed and white fallback canvas.
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => ProxoLocaleScope(child: child!),
            theme: ThemeData(
              fontFamily: kAppFont,
              colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
              useMaterial3: true,
              scaffoldBackgroundColor: Colors.white,
              textTheme: const TextTheme().apply(
                fontFamily: kAppFont,
                decoration: TextDecoration.none,
              ),
            ),
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: RepaintBoundary(key: key, child: child),
              ),
            ),
          ),
        );
        await t.pump();
        await t.pump(const Duration(milliseconds: 500));
        await t.pump(const Duration(milliseconds: 500));
        if (['page-contact', 'page-order', 'page-download'].contains(screen)) {
          final choice = find.byKey(
            ValueKey('create-type-${screen.substring(5)}'),
          );
          await t.ensureVisible(choice);
          await t.tap(choice);
          await t.pumpAndSettle();
          final scroll = t.state<ScrollableState>(
            find.byType(Scrollable).first,
          );
          scroll.position.jumpTo(0);
          await t.pump();
        }
        final name = '$screen-${width.toInt()}-s$scale-d$dpr';
        print('EVIDENCE painted $name');
        await snapshot(t, key, name, config);
        print('EVIDENCE screenshot $name');
        if (screen == 'receipt' || screen == 'ad-receipt') {
          final surface = find.byType(ReceiptSurface);
          final boundaryFinder = find
              .ancestor(of: surface, matching: find.byType(RepaintBoundary))
              .first;
          final boundaryKey =
              t.widget<RepaintBoundary>(boundaryFinder).key! as GlobalKey;
          const channel = MethodChannel('net.nfet.printing');
          t.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
            call,
          ) async {
            if (call.method == 'sharePdf') {
              final args = call.arguments as Map;
              File('$output/$name.pdf')
                  .writeAsBytesSync(args['doc'] as List<int>);
              return 1;
            }
            return null;
          });
          late Future<bool> future;
          await t.runAsync(() async {
            future = exportReceiptPdf(
              boundaryKey: boundaryKey,
              title: 'Proxo',
              fileStem: name,
            );
          });
          var done = false;
          future.then((_) => done = true);
          for (var frame = 0; frame < 500 && !done; frame++) {
            await t.pump();
            await t.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
          }
          print('EVIDENCE PDF $name done=$done');
          expect(done, true);
          await t.runAsync(() async {
            expect(await future, true);
          });
          t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          );
        }
        final scrolls = find.byType(Scrollable);
        if (scrolls.evaluate().isNotEmpty) {
          final state = t.state<ScrollableState>(scrolls.first);
          if (state.position.maxScrollExtent > 0) {
            // A lazy ListView first estimates unseen child heights. Refine
            // the end position after layout instead of capturing a transient
            // overscroll frame beyond the last (now measured) child.
            for (var pass = 0; pass < 4; pass++) {
              state.position.jumpTo(state.position.maxScrollExtent);
              await t.pump(const Duration(milliseconds: 100));
            }
            expect(
              state.position.pixels,
              lessThanOrEqualTo(state.position.maxScrollExtent + 0.01),
            );
            if (screen == 'receipt' || screen == 'ad-receipt') {
              expect(
                t
                    .getRect(find.byType(ReceiptPdfButton))
                    .overlaps(t.getRect(scrolls.first)),
                isTrue,
              );
            }
            await snapshot(t, key, '$name-bottom', config);
          }
        }
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pump();
      }, timeout: const Timeout(Duration(seconds: 60)));
    }
  }
}

Future<void> snapshot(
  WidgetTester t,
  GlobalKey key,
  String name,
  (double, double, double) config,
) async {
  final boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final nodes = <Map<String, Object?>>[];
  void visit(Element e) {
    final ro = e.findRenderObject();
    if (ro is RenderBox && ro.hasSize && ro.attached) {
      final origin = ro.localToGlobal(Offset.zero, ancestor: boundary);
      final record = <String, Object?>{
        'widget': e.widget.runtimeType.toString(),
        'key': e.widget.key?.toString(),
        'bounds_dp': [origin.dx, origin.dy, ro.size.width, ro.size.height],
      };
      if (ro is RenderParagraph) {
        record['text'] = ro.text.toPlainText();
        record['font_size'] = ro.text.style?.fontSize;
        record['font_family'] = ro.text.style?.fontFamily;
        record['exceeded_max_lines'] = ro.didExceedMaxLines;
      }
      nodes.add(record);
    }
    e.visitChildren(visit);
  }

  (key.currentContext! as Element).visitChildren(visit);
  await t.runAsync(() async {
    Directory(output).createSync(recursive: true);
    final shot = await boundary.toImage(pixelRatio: config.$3);
    final bytes = await shot.toByteData(format: ui.ImageByteFormat.png);
    File('$output/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    shot.dispose();
    File('$output/$name.json').writeAsStringSync(
      jsonEncode({
        'fixture': 'fictional deterministic records; actual production widgets',
        'runtime': 'Flutter widget test, Linux, not Android profile',
        'viewport_dp': [config.$1, 852],
        'dpr': config.$3,
        'text_scale': config.$2,
        'nodes': nodes,
      }),
    );
  });
}
