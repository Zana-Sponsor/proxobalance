import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/screens/home_screen.dart';
import 'package:proxo_app/screens/home_statistics_screen.dart';
import 'package:proxo_app/theme/app_theme.dart' show AppBackground;
import 'package:proxo_app/theme/proxo_ui.dart';
import 'package:proxo_app/widgets/bottom_nav.dart';
import 'package:proxo_app/widgets/top_bar.dart';

import 'home_sections_test.dart' show examples;
import 'support/visual_capture.dart';

void main() {
  ProxoVisualBinding();
  setUpAll(loadVisualFonts);
  for (final size in [const Size(320, 740), const Size(430, 932)]) {
    final dimensions = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('Statistics screen states $dimensions', (t) async {
      setVisualViewport(t, size);
      final pending = Completer<List<Map<String, dynamic>>>();
      var calls = 0;
      await t.pumpWidget(visualCapture(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildProxoTheme(),
        home: HomeStatisticsScreen(loadAds: () {
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
        }),
      )));
      await t.pump();
      await captureVisual(t, 'statistics-loading-$dimensions');
      pending.completeError(StateError('fixture-offline'));
      await t.pumpAndSettle();
      await captureVisual(t, 'statistics-error-$dimensions');
      await t.tap(find.text('دووبارە'));
      await t.pumpAndSettle();
      expect(find.text('2.00%'), findsOneWidget);
      await captureVisual(t, 'statistics-results-$dimensions');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    });

    testWidgets('Home screen production composition $dimensions', (t) async {
      setVisualViewport(t, size);
      var statistics = 0;
      var creates = 0;
      var pages = 0;
      var help = 0;
      await t.pumpWidget(visualCapture(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildProxoTheme(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: ProxoUi.background,
            appBar: ProxoTopBar(
              notificationCount: 3,
              onMenuTap: () {},
              onNotificationTap: () {},
            ),
            body: AppBackground(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: HomeContent(
                  userName: 'ئارام',
                  onCreateTap: () => creates++,
                  onToolsTap: () => pages++,
                  onFaqTap: () => help++,
                  onStatisticsTap: () => statistics++,
                  loadResults: ({bool forceRefresh = true}) async => examples(),
                ),
              ),
            ),
            bottomNavigationBar: ProxoBottomNav(
              currentIndex: 0,
              onTap: (_) {},
            ),
          ),
        ),
      )));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await captureVisual(t, 'home-overview-$dimensions');
      for (final key in [
        'home-view-statistics',
        'home-create-ad',
        'home-contact-tools',
        'home-faq'
      ]) {
        await t.ensureVisible(find.byKey(ValueKey(key)));
        await t.tap(find.byKey(ValueKey(key)));
        await t.pumpAndSettle();
      }
      expect((statistics, creates, pages, help), (1, 1, 1, 1));
      final toggle = find.byKey(const ValueKey('result-toggle-beauty'));
      await t.ensureVisible(toggle);
      await t.tap(toggle);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.drag(
          find.byType(SingleChildScrollView).first, const Offset(0, -350));
      await t.pumpAndSettle();
      await captureVisual(t, 'home-results-expanded-$dimensions');
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    });
  }
}
