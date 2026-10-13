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
import 'package:proxo_app/widgets/ad_form_components.dart';
import 'package:proxo_app/widgets/best_metrics_home_section.dart';
import 'package:proxo_app/widgets/home_best_result_card.dart';
import 'package:proxo_app/widgets/home_quick_actions.dart';
import 'package:proxo_app/widgets/proxo_text.dart';

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

Widget host(Widget child, {double scale = 1}) => MaterialApp(
      theme: buildAppTheme(),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
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
                        padding: const EdgeInsets.all(16), child: child),
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
        const SizedBox(height: AdUi.sectionGap),
        BestMetricsHomeSection(
          key: resultsKey,
          loadPreview: ({bool forceRefresh = true}) async => examples(),
        ),
      ],
    );

void auditText(WidgetTester tester, Finder parent) {
  for (final text in tester.widgetList<ProxoText>(
    find.descendant(of: parent, matching: find.byType(ProxoText)),
  )) {
    expect(text.style!.fontWeight, FontWeight.w400);
    expect(text.style!.fontFamily, 'Rabar');
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
            AdUi.radius;
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
        auditText(tester, find.byType(HomeQuickActions));
        auditText(tester, find.byType(BestMetricsHomeSection));
        final carousel = find.byKey(const ValueKey('home-results-carousel'));
        final card = find.byKey(const ValueKey('weekly-beauty'));
        expect(
          tester.getSize(card).height + 30,
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
    var creates = 0, tools = 0, faqs = 0;
    await tester.pumpWidget(
      host(
        HomeQuickActions(
          onCreateTap: () => creates++,
          onToolsTap: () => tools++,
          onFaqTap: () => faqs++,
        ),
      ),
    );
    for (final key in ['home-create-ad', 'home-contact-tools', 'home-faq']) {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
    }
    expect((creates, tools, faqs), (1, 1, 1));
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

  testWidgets('card corners, padding and shadows match Create Ad', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        Column(
          children: [
            const AdFormSection(title: 'Reference', child: SizedBox()),
            const SizedBox(height: 22),
            const HomeQuickActions(),
            HomeBestResultCard(ad: featured('beauty'), rank: 1),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final reference = tester
        .widget<Container>(
          find
              .descendant(
                of: find.byType(AdFormSection),
                matching: find.byType(Container),
              )
              .first,
        )
        .decoration as BoxDecoration;
    for (final parent in [
      find.byKey(const ValueKey('home-create-ad')),
      find.byType(HomeBestResultCard),
    ]) {
      final card = tester.widget<Container>(
        find.descendant(of: parent, matching: find.byType(Container)).first,
      );
      final decoration = card.decoration as BoxDecoration;
      expect(decoration.color, reference.color);
      expect(decoration.borderRadius, reference.borderRadius);
      expect(decoration.boxShadow, reference.boxShadow);
      expect(decoration.border, isNull);
      final padding = tester
          .widgetList<Padding>(
            find.descendant(of: parent, matching: find.byType(Padding)),
          )
          .firstWhere((widget) => widget.padding == AdUi.cardPadding);
      expect(padding.padding, const EdgeInsets.all(20));
    }
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
    expect(flags, [true, false]);
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
          loadPreview: ({bool forceRefresh = true}) async => examples(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('weekly-beauty')));
    await tester.tap(find.byKey(const ValueKey('weekly-beauty')));
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

  testWidgets('late loading completion after leaving Home is harmless', (
    tester,
  ) async {
    final pending = Completer<List<BestMetricAd>>();
    await tester.pumpWidget(
      host(
        BestMetricsHomeSection(
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
      await screenshot(tester, 'docs/home_sections_${entry.$3}_preview.png');
      expect(tester.takeException(), isNull);
    });
  }
}
