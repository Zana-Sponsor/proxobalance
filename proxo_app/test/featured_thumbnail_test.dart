import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/screens/ad_screen.dart';
import 'package:proxo_app/services/best_metrics_service.dart';
import 'package:proxo_app/theme/app_locale.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/widgets/best_results_design.dart';
import 'package:proxo_app/widgets/home_best_result_card.dart';
import 'package:proxo_app/widgets/proxo_thumbnail_fallback.dart';
import 'package:proxo_app/widgets/result_thumbnail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../integration_test/support/actual_screen_fixtures.dart';
import 'home_sections_test.dart' show auditText;
import 'support/featured_thumbnail_fixture.dart';

BestMetricAd thumbnailAd(String? url) => BestMetricAd.fromMap({
      'id': 'thumbnail-fixture',
      'goal': 'messages',
      'category': 'health_wellness',
      'thumbnail_url': url,
      'clicks': 1246,
      'impressions': 84320,
      'spend': 12.5,
      'daily_budget': 10,
      'days': 3,
      'service_budget_usd': 30,
      'featured_sort': 1,
      'created_at': '2026-10-19T09:00:00Z',
      'featured_week_start': '2026-10-19',
    });

Widget _host(Widget child, {double scale = 1, bool reduced = false}) =>
    MaterialApp(
      theme: buildAppTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduced,
        ),
        child: Directionality(textDirection: TextDirection.rtl, child: child!),
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(padding: const EdgeInsets.all(20), child: child),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final backend = ActualScreenBackend();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await FeaturedThumbnailFixture.initialize();
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
  setUp(() => ProxoLocale.current.value = const Locale('ckb'));
  tearDownAll(() async {
    await backend.dispose();
    await FeaturedThumbnailFixture.shutdown();
  });

  testWidgets('Advertisements and Results use the same branded fallback',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: const AdScreen()));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
          of: find.byType(AdScreen),
          matching: find.byType(ProxoThumbnailFallback)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester
        .pumpWidget(_host(HomeBestResultCard(ad: thumbnailAd(null), rank: 1)));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
          of: find.byType(ResultThumbnail),
          matching: find.byType(ProxoThumbnailFallback)),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Proxo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final config in [
    (width: 393.0, scale: 1.0),
    (width: 320.0, scale: 2.0),
  ]) {
    for (final state in ['missing', 'image', 'failed']) {
      testWidgets(
          'featured $state thumbnail and full label fit '
          '${config.width}/${config.scale} with inline details',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(config.width, 1400);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final url = state == 'missing'
            ? null
            : 'https://fixtures.invalid/featured-$state-${config.width}.jpg';
        final fixture =
            url == null ? null : await FeaturedThumbnailFixture.pending(url);
        if (fixture != null) addTearDown(fixture.dispose);
        await tester.pumpWidget(_host(
            HomeBestResultCard(
                ad: thumbnailAd(url), rank: 1, showDetails: true),
            scale: config.scale));
        await tester.pumpAndSettle();
        final card = find.byType(HomeBestResultCard);
        final thumb = find.byType(ResultThumbnail);
        final originalSize = tester.getSize(card);
        expect(tester.getSize(thumb),
            const Size(ResultsUi.thumbnailWidth, ResultsUi.thumbnailHeight));

        if (state == 'image') {
          await tester.runAsync(fixture!.succeed);
        } else if (state == 'failed') {
          fixture!.fail();
        }
        await tester.pumpAndSettle();
        expect(tester.getSize(card), originalSize,
            reason: 'Image resolution must not shift the collapsed card');
        expect(tester.getSize(thumb),
            const Size(ResultsUi.thumbnailWidth, ResultsUi.thumbnailHeight));
        if (state == 'image') {
          expect(find.byType(ProxoThumbnailFallback), findsNothing);
          final raw = tester.widget<RawImage>(
              find.descendant(of: thumb, matching: find.byType(RawImage)));
          expect(raw.image, isNotNull);
          expect(raw.image!.width, greaterThan(1));
          expect(raw.image!.height, greaterThan(1));
          expect(raw.fit, BoxFit.cover);
        } else {
          expect(find.byType(ProxoThumbnailFallback), findsOneWidget);
        }
        auditText(tester, card);
        expect(find.text('تەندروستی و خۆپارێزی'), findsOneWidget);

        final toggle =
            find.byKey(const ValueKey('result-details-thumbnail-fixture'));
        expect(tester.getSize(toggle).height, greaterThanOrEqualTo(48));
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.text('کۆی بودجە'), findsOneWidget);
        expect(find.text(r'$30'), findsOneWidget);
        expect(find.text('نامە و فرۆش'), findsOneWidget);
        expect(tester.getSize(card).height, greaterThan(originalSize.height));
        expect(tester.getSize(thumb),
            const Size(ResultsUi.thumbnailWidth, ResultsUi.thumbnailHeight));
        auditText(tester, card);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.text('کۆی بودجە'), findsNothing);
        expect(tester.getSize(card), originalSize);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('failed image is replaced when the advertised image URL changes',
      (tester) async {
    const failedUrl = 'https://fixtures.invalid/old-ad-image.jpg';
    const replacementUrl = 'https://fixtures.invalid/replacement-ad-image.jpg';
    final failed = await FeaturedThumbnailFixture.pending(failedUrl);
    addTearDown(failed.dispose);
    await tester.pumpWidget(_host(
        HomeBestResultCard(ad: thumbnailAd(failedUrl), rank: 1),
        reduced: true));
    await tester.pumpAndSettle();
    failed.fail();
    await tester.pumpAndSettle();
    expect(find.byType(ProxoThumbnailFallback), findsOneWidget);
    final replacement = await FeaturedThumbnailFixture.pending(replacementUrl);
    addTearDown(replacement.dispose);
    await tester.pumpWidget(_host(
        HomeBestResultCard(ad: thumbnailAd(replacementUrl), rank: 1),
        reduced: true));
    await tester.pumpAndSettle();
    await tester.runAsync(replacement.succeed);
    await tester.pumpAndSettle();
    expect(find.byType(ProxoThumbnailFallback), findsNothing);
    final raw = tester.widget<RawImage>(find.descendant(
        of: find.byType(ResultThumbnail), matching: find.byType(RawImage)));
    expect(raw.image, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
