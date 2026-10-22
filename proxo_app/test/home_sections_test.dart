import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/screens/ad_create_screen.dart';
import 'package:proxo_app/screens/best_metrics_screen.dart';
import 'package:proxo_app/services/best_metrics_service.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/theme/proxo_surface.dart';
import 'package:proxo_app/widgets/ad_form_components.dart';
import 'package:proxo_app/widgets/best_metrics_home_section.dart';
import 'package:proxo_app/widgets/best_metric_card.dart';
import 'package:proxo_app/widgets/home_best_result_card.dart';
import 'package:proxo_app/widgets/best_results_design.dart';
import 'package:proxo_app/widgets/home_quick_actions.dart';
import 'package:proxo_app/widgets/proxo_text.dart';
import 'package:proxo_app/widgets/proxo_symbol.dart';

import 'ad_creation_flow_test.dart' show TestAdRepository;
import 'text_direction_test.dart' show expectLtrToken, paragraphOf;

const captureKey = ValueKey('home-sections-capture');

class HomePaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

BestMetricAd featured(String id, {String category = 'cosmetics_beauty'}) =>
    BestMetricAd(
      id: id,
      goal: 'messages',
      category: category,
      videoLink: 'https://www.tiktok.com/@proxo/video/123456789',
      thumbnailUrl: null,
      clicks: 1246,
      impressions: 84320,
      spendUsd: 12.5,
      dailyBudgetUsd: 10,
      days: 3,
      serviceBudgetUsd: 30,
      sortOrder: 1,
      createdAt: DateTime.utc(2026, 9, 29),
      weekStart: DateTime(2026, 9, 28),
    );

List<BestMetricAd> examples() => [
      featured('beauty'),
      featured('fashion', category: 'fashion_apparel'),
      featured('electronics', category: 'electronics'),
    ];

Widget host(Widget child, {double scale = 1, bool reduced = false}) =>
    MaterialApp(
      theme: buildAppTheme(),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale), disableAnimations: reduced),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              backgroundColor: Colors.white,
              body: SingleChildScrollView(
                child: RepaintBoundary(
                  key: captureKey,
                  child: ColoredBox(
                    color: Colors.white,
                    child: Padding(
                        padding: const EdgeInsets.all(20), child: child),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

Widget sections({GlobalKey<BestMetricsHomeSectionState>? resultsKey}) => Column(
      children: [
        HomeQuickActions(
            onCreateTap: () {}, onToolsTap: () {}, onFaqTap: () {}),
        const SizedBox(height: 24),
        BestMetricsHomeSection(
          autoPlay: false,
          key: resultsKey,
          loadPreview: ({bool forceRefresh = true}) async => examples(),
        ),
      ],
    );

void auditText(
  WidgetTester tester,
  Finder parent, {
  String font = ResultsUi.font,
}) {
  for (final text in tester.widgetList<ProxoText>(
    find.descendant(of: parent, matching: find.byType(ProxoText)),
  )) {
    expect(text.style!.fontWeight, FontWeight.w400);
    expect(text.style!.fontFamily, font);
    final paragraph = paragraphOf(tester, find.byWidget(text));
    expect(paragraph.didExceedMaxLines, false);
    final rendered = paragraph.text.toPlainText(includeSemanticsLabels: false);
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: rendered.length),
    );
    expect(boxes, isNotEmpty);
    final card = find.ancestor(
      of: find.byWidget(text),
      matching: find.byWidgetPredicate((widget) {
        if (widget is! Container || widget.decoration is! BoxDecoration) {
          return false;
        }
        return (widget.decoration! as BoxDecoration).borderRadius ==
                ResultsUi.radius ||
            (widget.decoration! as BoxDecoration).borderRadius == AdUi.radius;
      }),
    );
    final paintSpace = tester.getRect(
      card.evaluate().isEmpty ? parent : card.first,
    );
    for (final box in boxes) {
      // Native Rabar shaping can extend past its line box at both the left
      // edge and descent. Verify the actual padded card's paint bounds,
      // rather than changing inherited typography to fit selection boxes.
      expect(
        paragraph.localToGlobal(Offset(box.left, 0)).dx,
        greaterThanOrEqualTo(paintSpace.left - 0.5),
        reason: text.data,
      );
      expect(
        paragraph.localToGlobal(Offset(box.right, 0)).dx,
        lessThanOrEqualTo(paintSpace.right + 0.5),
        reason: text.data,
      );
      expect(
        paragraph.localToGlobal(Offset(0, box.bottom)).dy,
        lessThanOrEqualTo(paintSpace.bottom + 0.5),
        reason: text.data,
      );
    }
  }
}

Future<void> screenshot(WidgetTester tester, String path) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(captureKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(path).parent.create(recursive: true);
    await File(path).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  HomePaintBinding();
  setUpAll(() async {
    await (FontLoader(
      'Rabar',
    )..addFont(rootBundle.load('assets/fonts/Rabar_021.ttf')))
        .load();
    await (FontLoader(
      'RabarAuthRegular',
    )..addFont(rootBundle.load('assets/fonts/Rabar_022.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  for (final size in [
    const Size(240, 700),
    const Size(280, 700),
    const Size(320, 700),
    const Size(393, 852),
    const Size(430, 932),
    const Size(768, 1024),
    const Size(852, 393),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 1.5, 3.0]) {
      testWidgets('Home sections fit $size at system text scale $scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(host(sections(), scale: scale));
        await tester.pumpAndSettle();
        auditText(tester, find.byType(HomeQuickActions),
            font: ProxoSurface.fontFamily);
        auditText(tester, find.byType(BestMetricsHomeSection));
        final carousel = find.byKey(const ValueKey('home-results-carousel'));
        final card = find.byKey(const ValueKey('weekly-beauty'));
        expect(
          tester.getSize(card).height,
          lessThanOrEqualTo(tester.getSize(carousel).height + 0.1),
        );
        expect(
          tester.getSize(find.byKey(const ValueKey('home-create-ad'))).width,
          lessThanOrEqualTo(600),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('all existing quick actions call only their own callback', (
    tester,
  ) async {
    var creates = 0, balances = 0, pages = 0;
    await tester.pumpWidget(
      host(
        HomeQuickActions(
          onCreateTap: () => creates++,
          onAddBalanceTap: () => balances++,
          onCreatePageTap: () => pages++,
        ),
      ),
    );
    for (final key in [
      'home-create-ad',
      'home-add-balance',
      'home-create-page',
    ]) {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
    }
    expect((creates, balances, pages), (1, 1, 1));
    expect(find.byKey(const ValueKey('home-contact-tools')), findsNothing);
    expect(find.byKey(const ValueKey('home-faq')), findsNothing);
  });

  testWidgets('Create quick action opens the existing Create Ad screen', (
    tester,
  ) async {
    final repo = TestAdRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: HomeQuickActions(
              onCreateTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AdCreateScreen(repository: repo),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('home-create-ad')));
    await tester.pumpAndSettle();
    expect(find.byType(AdCreateScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('ad-title')), findsOneWidget);
    expect(repo.submissions, 0);
  });

  testWidgets('result card has a quiet border and consistent content inset', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(HomeBestResultCard(ad: featured('beauty'), rank: 1)),
    );
    await tester.pumpAndSettle();
    final card = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(HomeBestResultCard),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = card.decoration as BoxDecoration;
    expect(decoration.color, Colors.white);
    expect(decoration.borderRadius, ResultsUi.radius);
    expect(decoration.border, isNotNull);
    expect(
      find.descendant(
        of: find.byType(HomeBestResultCard),
        matching: find.byWidgetPredicate(
          (w) => w is Padding && w.padding == const EdgeInsets.all(16),
        ),
      ),
      findsWidgets,
    );
  });

  testWidgets('metrics retain database values, normal type and LTR currency', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(HomeBestResultCard(ad: featured('beauty'), rank: 1)),
    );
    await tester.pumpAndSettle();
    for (final token in ['84,320', '1,246', '\$12.50', '#1']) {
      final text = find.byWidgetPredicate(
        (widget) => widget is ProxoText && widget.data == token,
      );
      expect(text, findsOneWidget);
      final paragraph = paragraphOf(tester, text);
      expect(paragraph.textDirection, TextDirection.ltr);
      expectLtrToken(paragraph, token);
    }
    final label = find.byWidgetPredicate(
      (widget) => widget is ProxoText && widget.data == 'تێچوو',
    );
    expect(paragraphOf(tester, label).textDirection, TextDirection.rtl);
  });

  testWidgets(
    'loading, empty, failure and retry keep their existing behavior',
    (tester) async {
      final initial = Completer<List<BestMetricAd>>();
      var calls = 0;
      await tester.pumpWidget(
        host(
          BestMetricsHomeSection(
            autoPlay: false,
            loadPreview: ({bool forceRefresh = true}) {
              calls++;
              return calls == 1 ? initial.future : Future.value(examples());
            },
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      initial.completeError(StateError('network unavailable'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-results-retry')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('home-results-retry')));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.byType(HomeBestResultCard), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        host(
          BestMetricsHomeSection(
            autoPlay: false,
            loadPreview: ({bool forceRefresh = true}) async => [],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('هێشتا ئەنجامی ئەم هەفتەیە هەڵنەبژێردراوە'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('home-results-view-all')),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('carousel swipes, cached refresh and view-all keep ranking', (
    tester,
  ) async {
    final flags = <bool>[];
    final key = GlobalKey<BestMetricsHomeSectionState>();
    await tester.pumpWidget(
      host(
        BestMetricsHomeSection(
          autoPlay: false,
          key: key,
          loadPreview: ({bool forceRefresh = true}) async {
            flags.add(forceRefresh);
            return examples();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final carousel = find.byKey(const ValueKey('home-results-carousel'));
    await tester.ensureVisible(carousel);
    await tester.drag(carousel, const Offset(500, 0));
    await tester.pumpAndSettle();
    final page = tester.widget<PageView>(carousel).controller!.page!;
    expect(page, greaterThan(0.5));
    await key.currentState!.refresh(forceRefresh: false);
    await tester.pumpAndSettle();
    expect(flags, [
      false,
      false,
    ]); // Mount and pull-to-refresh both honor the cache TTL.
    await tester.ensureVisible(
      find.byKey(const ValueKey('home-results-view-all')),
    );
    await tester.tap(find.byKey(const ValueKey('home-results-view-all')));
    await tester.pumpAndSettle();
    final screen = tester.widget<BestMetricsScreen>(
      find.byType(BestMetricsScreen),
    );
    expect(screen.initialAds.map((ad) => ad.id), [
      'beauty',
      'fashion',
      'electronics',
    ]);
    expect(screen.initialAdId, isNull);
  });

  testWidgets('selected result opens the existing details route', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        BestMetricsHomeSection(
          autoPlay: false,
          loadPreview: ({bool forceRefresh = true}) async => examples(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('weekly-beauty')));
    await tester.tap(find.byKey(const ValueKey('result-open-beauty')));
    await tester.pumpAndSettle();
    final screen = tester.widget<BestMetricsScreen>(
      find.byType(BestMetricsScreen),
    );
    expect(screen.initialAdId, 'beauty');
  });

  testWidgets(
    'carousel recomputes height after rotation and text-size changes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 852);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final child = sections();
      await tester.pumpWidget(host(child));
      await tester.pumpAndSettle();
      final carousel = find.byKey(const ValueKey('home-results-carousel'));
      final normalHeight = tester.getSize(carousel).height;
      await tester.pumpWidget(host(child, scale: 3));
      await tester.pumpAndSettle();
      expect(tester.getSize(carousel).height, greaterThan(normalHeight));
      tester.view.physicalSize = const Size(852, 393);
      await tester.pumpAndSettle();
      auditText(tester, find.byType(BestMetricsHomeSection));
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 393.0, 430.0, 768.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('balanced Home geometry is summary-only $width/$scale',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 1400);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(host(sections(), scale: scale));
        await tester.pumpAndSettle();
        final actions = [
          'home-create-ad',
          'home-add-balance',
          'home-create-page'
        ].map((key) => tester.getRect(find.byKey(ValueKey(key)))).toList();
        for (final rect in actions) {
          expect(rect.width, closeTo(actions.first.width, .1));
          expect(rect.height, closeTo(actions.first.height, .1));
          expect(rect.height, greaterThanOrEqualTo(48));
        }
        if (scale == 1) {
          expect(actions.every((r) => (r.top - actions.first.top).abs() < .1),
              true);
          expect(actions.first.height, lessThanOrEqualTo(142));
          final glyphs = [
            'home-create-ad',
            'home-add-balance',
            'home-create-page'
          ].map((key) => tester.getCenter(find.descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(ProxoSymbol))));
          expect(
              glyphs.every((point) => (point.dy - glyphs.first.dy).abs() < .1),
              true);
        }
        final section =
            tester.getRect(find.byKey(const ValueKey('home-results-banner')));
        final card = find.byKey(const ValueKey('weekly-beauty'));
        final collapsed = tester.getRect(card);
        expect(collapsed.left, closeTo(section.left, .1));
        expect(collapsed.right, closeTo(section.right, .1));
        expect(section.width, lessThanOrEqualTo(600));
        expect(
            section.left,
            closeTo(actions.map((r) => r.left).reduce((a, b) => a < b ? a : b),
                .1));
        expect(
            section.right,
            closeTo(actions.map((r) => r.right).reduce((a, b) => a > b ? a : b),
                .1));
        expect(
            section.top -
                actions.map((r) => r.bottom).reduce((a, b) => a > b ? a : b),
            closeTo(24, .1));
        if (scale == 1) expect(collapsed.height, lessThanOrEqualTo(290));
        expect(
            find.byKey(const ValueKey('result-expanded-beauty')), findsNothing);
        expect(
            find.byKey(const ValueKey('result-details-beauty')), findsNothing);
        expect(find.text('وردەکاری زیاتر'), findsNothing);
        expect(find.text('وردەکاری کەمتر'), findsNothing);
        expect(find.text('کۆی بودجە'), findsNothing);
        expect(find.text('ئامانج'), findsNothing);
        final carousel = find.byKey(const ValueKey('home-results-carousel'));
        expect(tester.getSize(carousel).height,
            closeTo(tester.getSize(card).height, .1));
        auditText(tester, find.byType(BestMetricsHomeSection));
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final width in [320.0, 393.0]) {
    testWidgets('reduced motion details resize safely at $width',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 1400);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(host(
          BestMetricCard(ad: featured('beauty'), rank: 1),
          scale: width == 320 ? 2 : 1,
          reduced: true));
      await tester.pumpAndSettle();
      final toggle = find.byKey(const ValueKey('result-details-beauty'));
      final card = find.byType(BestMetricCard);
      final originalHeight = tester.getSize(card).height;
      for (var i = 0; i < 3; i++) {
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('result-expanded-beauty')),
            findsOneWidget);
        expect(tester.getSize(card).height, greaterThan(originalHeight));
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(tester.getSize(card).height, closeTo(originalHeight, .1));
        expect(tester.takeException(), isNull);
      }
    });
  }

  for (final width in [280.0, 320.0, 430.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'dedicated results keep objective and budget side by side $width/$scale',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 1400);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: BestMetricsScreen(
            initialAds: [featured('beauty')],
            loadResults: ({bool forceRefresh = false}) async =>
                [featured('beauty')],
          ),
        ));
        await tester.pumpAndSettle();
        final card = find.byKey(const ValueKey('result-beauty'));
        final originalHeight = tester.getSize(card).height;
        final toggle = find.byKey(const ValueKey('result-details-beauty'));
        expect(tester.getSize(toggle).height, greaterThanOrEqualTo(48));
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        final objective = tester
            .getRect(find.byKey(const ValueKey('result-objective-beauty')));
        final budget =
            tester.getRect(find.byKey(const ValueKey('result-budget-beauty')));
        expect(objective.top, closeTo(budget.top, .1));
        expect(objective.height, closeTo(budget.height, .1));
        expect(objective.width, closeTo(budget.width, .1));
        expect(objective.left - budget.right, closeTo(8, .1));
        expect(
          tester
              .getRect(
                  find.byKey(const ValueKey('result-objective-value-beauty')))
              .top,
          closeTo(
              tester
                  .getRect(
                      find.byKey(const ValueKey('result-budget-value-beauty')))
                  .top,
              .1),
        );
        expect(find.text('کۆی بودجە'), findsOneWidget);
        expect(find.text('نامە و فرۆش'), findsOneWidget);
        expect(find.text(r'$30'), findsOneWidget);
        auditText(tester, card);
        expect(tester.getSize(card).height, greaterThan(originalHeight));
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(
            find.byKey(const ValueKey('result-expanded-beauty')), findsNothing);
        expect(tester.getSize(card).height, closeTo(originalHeight, .1));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('late loading completion after leaving Home is harmless', (
    tester,
  ) async {
    final pending = Completer<List<BestMetricAd>>();
    await tester.pumpWidget(
      host(
        BestMetricsHomeSection(
          autoPlay: false,
          loadPreview: ({bool forceRefresh = true}) => pending.future,
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox());
    pending.complete(examples());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final entry in [
    (393.0, 1.0, 'phone'),
    (768.0, 1.0, 'tablet'),
    (393.0, 3.0, 'large_text'),
  ]) {
    testWidgets('render actual Home sections ${entry.$3}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(entry.$1, 1200);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(host(sections(), scale: entry.$2));
      await tester.pumpAndSettle();
      await screenshot(
          tester, 'build/home-balance-evidence/sections-${entry.$3}.png');
      expect(tester.takeException(), isNull);
    });
  }
}
