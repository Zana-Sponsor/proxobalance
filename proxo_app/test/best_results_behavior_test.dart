import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/services/best_metrics_service.dart';
import 'package:proxo_app/services/featured_image_cache.dart';
import 'package:proxo_app/screens/best_metrics_screen.dart';
import 'package:proxo_app/widgets/best_metrics_home_section.dart';
import 'package:proxo_app/widgets/best_metric_card.dart';
import 'package:proxo_app/widgets/proxo_app_bar.dart';

import 'home_sections_test.dart' show featured, examples;

void main() {
  test(
    'one immutable snapshot serves concurrent callers, TTL and refresh',
    () async {
      var now = DateTime.utc(2026, 10, 18, 10);
      var calls = 0;
      final gate = Completer<List<BestMetricAd>>();
      final repository = BestMetricsRepository(
        now: () => now,
        loadPage: (_, __, ___) {
          calls++;
          return calls == 1 ? gate.future : Future.value(examples());
        },
      );
      final home = repository.fetch(), detail = repository.fetch();
      expect(identical(home, detail), true);
      gate.complete(examples());
      final rows = await home;
      expect(() => rows.clear(), throwsUnsupportedError);
      expect(identical(await repository.fetch(), rows), true);
      expect(calls, 1);
      now = now.add(const Duration(minutes: 11));
      await repository.fetch();
      expect(calls, 2);
      await repository.fetch(forceRefresh: true);
      expect(calls, 3);
    },
  );

  test(
    'all selected adverts are paginated, and a failure can be retried',
    () async {
      final offsets = <int>[];
      var fail = true;
      final repository = BestMetricsRepository(
        loadPage: (week, offset, limit) async {
          offsets.add(offset);
          if (fail) {
            fail = false;
            throw StateError('offline');
          }
          return List.generate(
            offset == 200 ? 1 : limit,
            (i) => featured('${offset + i}'),
          );
        },
      );
      await expectLater(repository.fetch(), throwsStateError);
      final rows = await repository.fetch();
      expect(rows.length, 201);
      expect(rows.last.id, '200');
      expect(offsets, [0, 0, 100, 200]);
    },
  );

  test(
    'week rollover and invalidation reject stale in-flight cache writes',
    () async {
      var now = DateTime.utc(2026, 10, 18, 20, 59); // Sunday 23:59 Baghdad.
      final pending = <Completer<List<BestMetricAd>>>[];
      final weeks = <String>[];
      final repository = BestMetricsRepository(
        now: () => now,
        loadPage: (week, _, __) {
          weeks.add(week);
          final gate = Completer<List<BestMetricAd>>();
          pending.add(gate);
          return gate.future;
        },
      );
      final old = repository.fetch();
      now = now.add(const Duration(minutes: 2));
      final fresh = repository.fetch();
      pending[1].complete([featured('new-week')]);
      await fresh;
      pending[0].complete([featured('old-week')]);
      await old;
      expect((await repository.fetch()).single.id, 'new-week');
      expect(weeks, ['2026-10-12', '2026-10-19']);
      final invalidated = repository.fetch(forceRefresh: true);
      repository.invalidate();
      final replacement = repository.fetch();
      pending[3].complete([featured('replacement')]);
      await replacement;
      pending[2].complete([featured('invalidated')]);
      await invalidated;
      expect((await repository.fetch()).single.id, 'replacement');
    },
  );

  testWidgets(
    'Home and detail thumbnail providers reuse one decoded cache key',
    (t) async {
      const url = 'https://fixtures.invalid/thumbnail.jpg';
      final one = await FeaturedImageCache.provider(url)
          .obtainKey(ImageConfiguration.empty);
      final two = await FeaturedImageCache.provider(url)
          .obtainKey(ImageConfiguration.empty);
      expect(one, two);
      expect(
        await FeaturedImageCache.provider('$url?updated=1')
            .obtainKey(ImageConfiguration.empty),
        isNot(one),
      );
      expect(FeaturedImageCache.validUrl('javascript:alert(1)'), false);
    },
  );

  Widget host(Widget child, {bool reduced = false}) => MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    ),
  );
  Future<void> advance(WidgetTester t) async {
    await t.pump(const Duration(seconds: 5));
    await t.pump();
    await t.pump(const Duration(milliseconds: 800));
    await t.pumpAndSettle();
  }

  for (final reduced in [false, true]) {
    testWidgets(
      'single row auto-slide honors touch, direction and reduced motion $reduced',
      (t) async {
        await t.pumpWidget(
          host(
            BestMetricsHomeSection(
              loadPreview: ({bool forceRefresh = false}) async => examples(),
            ),
            reduced: reduced,
          ),
        );
        await t.pumpAndSettle();
        final carousel = find.byKey(const ValueKey('home-results-carousel'));
        final controller = t.widget<PageView>(carousel).controller!;
        expect(find.byType(PageView), findsOneWidget);
        await advance(t);
        expect(controller.page, closeTo(reduced ? 0 : 1, .01));
        final gesture = await t.startGesture(t.getCenter(carousel));
        final stopped = controller.page!;
        await t.pump(const Duration(seconds: 6));
        expect(controller.page, stopped);
        // First movement crosses touch slop; the following move drags the page.
        await gesture.moveBy(const Offset(24, 0));
        await t.pump(const Duration(milliseconds: 16));
        await gesture.moveBy(const Offset(420, 0));
        await t.pump(const Duration(milliseconds: 16));
        await gesture.up();
        await t.pumpAndSettle();
        final manual = controller.page!.round();
        expect(manual, greaterThan(stopped));
        await advance(t);
        expect(
          controller.page,
          closeTo(reduced ? manual.toDouble() : manual + 1.0, .01),
        );
        if (!reduced) {
          for (var i = 0; i < 3; i++) {
            final before = controller.page!;
            await advance(t);
            expect(controller.page, closeTo(before + 1, .01));
          }
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
          final background = controller.page;
          await t.pump(const Duration(seconds: 8));
          expect(controller.page, background);
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          await advance(t);
          expect(controller.page, closeTo(background! + 1, .01));
        }
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 8));
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'detail opens the selected rank and can scroll to earlier results',
    (t) async {
      final rows = List.generate(8, (i) => featured('ad-$i'));
      await t.pumpWidget(
        MaterialApp(
          home: BestMetricsScreen(
            initialAds: rows,
            initialAdId: 'ad-6',
            loadResults: ({bool forceRefresh = false}) async => rows,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(ProxoAppBar), findsOneWidget);
      expect(
        find.byKey(const ValueKey('result-ad-6')).hitTestable(),
        findsOneWidget,
      );
      expect(
        t
            .widget<BestMetricCard>(find.byKey(const ValueKey('result-ad-6')))
            .rank,
        7,
      );
      final scroll = find.byType(CustomScrollView);
      await t.drag(scroll, const Offset(0, 600));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('result-ad-5')), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('empty results refresh in place and recover to cards', (t) async {
    var calls = 0;
    await t.pumpWidget(
      MaterialApp(
        home: BestMetricsScreen(
          loadResults: ({bool forceRefresh = false}) async {
            calls++;
            return calls == 1 ? [] : examples();
          },
        ),
      ),
    );
    await t.pumpAndSettle();
    final retry = find.byKey(const ValueKey('home-results-retry'));
    expect(retry.hitTestable(), findsOneWidget);
    await t.tap(retry);
    await t.pumpAndSettle();
    expect(find.byType(BestMetricCard), findsWidgets);
    expect(calls, 2);
    expect(t.takeException(), isNull);
  });
}
