import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/screens/home_screen.dart';
import 'package:proxo_app/screens/home_statistics_screen.dart';
import 'package:proxo_app/services/best_metrics_service.dart';
import 'package:proxo_app/theme/proxo_ui.dart';
import 'package:proxo_app/widgets/ad_thumbnail.dart';
import 'package:proxo_app/widgets/ads_collection_state.dart';
import 'package:proxo_app/widgets/best_metrics_home_section.dart';
import 'package:proxo_app/widgets/home_best_result_card.dart';

import 'support/visual_capture.dart';

BestMetricAd _result(String id, {String? thumbnail}) => BestMetricAd(
      id: id,
      goal: 'messages',
      category: 'cosmetics_beauty',
      videoLink: null,
      thumbnailUrl: thumbnail,
      clicks: 1246,
      impressions: 84320,
      spendUsd: 12.5,
      dailyBudgetUsd: 10,
      days: 3,
      serviceBudgetUsd: 30,
      sortOrder: 1,
      createdAt: DateTime(2026, 10, 18),
      weekStart: DateTime(2026, 10, 19),
    );

Widget _host(Widget content, {double textScale = 1}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildProxoTheme(),
      home: Builder(
          builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Scaffold(
                        body: SingleChildScrollView(
                      child: visualCapture(ColoredBox(
                          color: Colors.white,
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: content))),
                    ))),
              )),
    );

void main() {
  ProxoVisualBinding();
  setUpAll(loadVisualFonts);

  testWidgets('details expand and collapse in the card without navigation',
      (tester) async {
    var navigations = 0;
    await tester.pumpWidget(_host(HomeBestResultCard(
        ad: _result('one'), rank: 1, onOpenDetails: () => navigations++)));
    expect(find.text('بودجەی گشتی'), findsNothing);
    final collapsedHeight =
        tester.getSize(find.byType(HomeBestResultCard)).height;
    await tester.tap(find.byKey(const ValueKey('result-toggle-one')));
    await tester.pumpAndSettle();
    expect(find.text('بودجەی گشتی'), findsOneWidget);
    expect(find.text('\$30'), findsOneWidget);
    expect(find.text('نامە و فرۆش'), findsOneWidget);
    expect(navigations, 0);
    expect(tester.getSize(find.byType(HomeBestResultCard)).height,
        greaterThan(collapsedHeight));
    await tester.tap(find.byKey(const ValueKey('result-toggle-one')));
    await tester.pumpAndSettle();
    expect(find.text('بودجەی گشتی'), findsNothing);
    expect(tester.getSize(find.byType(HomeBestResultCard)).height,
        collapsedHeight);
    await tester.tap(find.byKey(const ValueKey('result-open-one')));
    expect(navigations, 1);
  });

  testWidgets('empty and invalid thumbnails use the same branded fallback',
      (tester) async {
    await tester.pumpWidget(_host(const Row(children: [
      SizedBox(width: 60, height: 80, child: AdThumbnail()),
      SizedBox(width: 60, height: 80, child: AdThumbnail(url: 'not-a-url')),
    ])));
    await tester.pumpAndSettle();
    expect(find.byType(AdThumbnailFallback), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('filter empty offers clear-filter action rather than create',
      (tester) async {
    var actions = 0;
    await tester.pumpWidget(
        _host(AdsEmptyState(filtered: true, onAction: () => actions++)));
    expect(find.text('بینینی هەموو ڕیکلامەکان'), findsOneWidget);
    expect(find.text('دروستکردنی ڕیکلام'), findsNothing);
    await tester.tap(find.byType(FilledButton));
    expect(actions, 1);
    await tester.pumpWidget(_host(AdsErrorState(
        message: 'پەیوەندی تۆڕ پچڕاوە', onRetry: () => actions++)));
    expect(find.text('ڕیکلامەکان بار نەبوون'), findsOneWidget);
    expect(find.text('هێشتا هیچ ڕیکلامێک نییە!'), findsNothing);
    await tester.tap(find.byType(FilledButton));
    expect(actions, 2);
  });

  testWidgets(
      'statistics action opens cumulative metrics with loading and retry',
      (tester) async {
    final pending = Completer<List<Map<String, dynamic>>>();
    var calls = 0;
    Future<List<Map<String, dynamic>>> load() {
      calls++;
      return calls == 1
          ? pending.future
          : Future.value([
              {
                'spend': 10,
                'prev_spend': 2.5,
                'impressions': 900,
                'prev_impressions': 100,
                'clicks': 20,
                'conversions': 5
              },
            ]);
    }

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
        theme: buildProxoTheme(),
        home: Builder(
            builder: (context) => Scaffold(
                    body: SingleChildScrollView(
                        child: HomeContent(
                  loadResults: ({bool forceRefresh = false}) async => [],
                  onStatisticsTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => HomeStatisticsScreen(loadAds: load))),
                ))))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-view-statistics')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('ئامارەکان بار نەبوون'), findsOneWidget);
    await tester.tap(find.text('دووبارە'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('\$12.50'), findsOneWidget);
    expect(find.text('1000'), findsOneWidget);
    expect(find.text('2.00%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 430.0]) {
    final viewport = Size(width, width == 320 ? 740 : 932);
    final suffix = '${width.toInt()}x${viewport.height.toInt()}';
    testWidgets('capture Best Results states $suffix', (tester) async {
      setVisualViewport(tester, viewport);
      await tester.pumpWidget(
          _host(HomeBestResultCard(ad: _result('missing'), rank: 1)));
      await tester.pumpAndSettle();
      await captureVisual(tester, 'best-card-no-thumbnail-collapsed-$suffix');
      await tester.tap(find.byKey(const ValueKey('result-toggle-missing')));
      await tester.pumpAndSettle();
      await captureVisual(tester, 'best-card-no-thumbnail-expanded-$suffix');
      await tester.pumpWidget(_host(HomeBestResultCard(
          ad: _result('image'),
          rank: 2,
          thumbnailProvider:
              const AssetImage('assets/images/empty_ads_box.png'))));
      await tester.pumpAndSettle();
      expect(find.byType(AdThumbnailFallback), findsNothing);
      await captureVisual(tester, 'best-card-with-thumbnail-collapsed-$suffix');
      await tester.tap(find.byKey(const ValueKey('result-toggle-image')));
      await tester.pumpAndSettle();
      await captureVisual(tester, 'best-card-with-thumbnail-expanded-$suffix');
      await tester.pumpWidget(_host(HomeBestResultCard(
          ad: _result('failed'),
          rank: 3,
          thumbnailProvider:
              const AssetImage('assets/fixtures/missing-thumbnail.png'))));
      await tester.pumpAndSettle();
      expect(find.byType(AdThumbnailFallback), findsOneWidget);
      await captureVisual(tester, 'best-card-failed-thumbnail-$suffix');
      expect(tester.takeException(), isNull);
    });

    testWidgets('capture complete Best Results section $suffix', (tester) async {
      setVisualViewport(tester, viewport);
      await tester.pumpWidget(_host(BestMetricsHomeSection(
        loadPreview: ({bool forceRefresh = false}) async => [_result('section')],
      )));
      await tester.pumpAndSettle();
      await captureVisual(tester, 'best-results-section-collapsed-$suffix');
      await tester.tap(find.byKey(const ValueKey('result-toggle-section')));
      await tester.pumpAndSettle();
      await captureVisual(tester, 'best-results-section-expanded-$suffix');
      expect(tester.takeException(), isNull);
    });

    testWidgets('capture Ads empty and retrieval error $suffix',
        (tester) async {
      setVisualViewport(tester, viewport);
      await tester.pumpWidget(_host(AdsEmptyState(onAction: () {})));
      await tester.pumpAndSettle();
      await captureVisual(tester, 'advertisements-empty-$suffix');
      await tester.pumpWidget(_host(AdsErrorState(
          message: 'پەیوەندییەکەت بپشکنە و دووبارە هەوڵ بدەرەوە.',
          onRetry: () {})));
      await tester.pumpAndSettle();
      await captureVisual(tester, 'advertisements-error-$suffix');
      expect(tester.takeException(), isNull);
    });

    testWidgets('expanded long Kurdish category and large text fit $suffix',
        (tester) async {
      setVisualViewport(tester, viewport);
      await tester.pumpWidget(_host(
          HomeBestResultCard(ad: _result('long'), rank: 999),
          textScale: 2));
      await tester.tap(find.byKey(const ValueKey('result-toggle-long')));
      await tester.pumpAndSettle();
      for (final finder in [
        find.text('بودجەی گشتی'),
        find.text('نامە و فرۆش')
      ]) {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
      }
      final card = tester.getRect(find.byType(HomeBestResultCard));
      expect(card.left, greaterThanOrEqualTo(0));
      expect(card.right, lessThanOrEqualTo(width));
      expect(tester.takeException(), isNull);
    });
  }
}
