import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/screens/ad_screen.dart';
import 'package:proxo_app/theme/app_locale.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/widgets/proxo_refresh.dart';

import '../integration_test/support/actual_screen_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final backend = ActualScreenBackend();
  final records = <Map<String, dynamic>>[];
  Completer<Object>? delayedMeta;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await backend.initialize();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProxoLocale.current.value = ProxoLocale.kurdishSorani;
    backend.metaEnabled = true;
    backend.adQueries.clear();
    delayedMeta = null;
    records.clear();
    for (var i = 0; i < 45; i++) {
      for (final platform in ['META', 'TIKTOK']) {
        records.add({
          'id': '$platform-$i', 'user_id': screenFixtureOwner,
          'platform': platform, 'title': '$platform title $i',
          'status': 'pending',
          'created_at': DateTime.utc(2026, 10, 23)
              .subtract(Duration(minutes: i))
              .toIso8601String(),
          // A known URL suppresses legacy thumbnail mutation, including during
          // pagination. Image loading has its existing local error placeholder.
          'thumbnail_url': 'https://screen-fixtures.invalid/thumb.png',
        });
      }
    }
    backend.adsResponder = (uri) async {
      final q = uri.queryParameters;
      expectSync(q['user_id'], 'eq.$screenFixtureOwner');
      final platform = q['or']?.contains('platform.eq.META') == true
          ? 'META'
          : q['or']?.contains('platform.eq.TIKTOK') == true
              ? 'TIKTOK'
              : null;
      final matches = records
          .where((row) =>
              (platform == null || row['platform'] == platform) &&
              (q['status'] == null || q['status'] == 'eq.${row['status']}'))
          .toList();
      final offset = int.tryParse(q['offset'] ?? '') ?? 0;
      final limit = int.tryParse(q['limit'] ?? '') ?? 20;
      final result = matches
          .skip(offset)
          .take(limit)
          .map(Map<String, dynamic>.from)
          .toList();
      final gate = delayedMeta;
      if (platform == 'META' && gate != null) return gate.future;
      return result;
    };
  });
  tearDownAll(backend.dispose);

  Future<void> mount(WidgetTester tester,
      {ProxoRefreshController? refresh}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        // Network thumbnails deliberately remain local placeholders in this
        // transport fixture; suppress their infinite shimmer for settle checks.
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!),
        home: AdScreen(refreshController: refresh)));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'actual list rejects late Meta pages and scopes TikTok pagination',
      (tester) async {
    final refresh = ProxoRefreshController();
    await mount(tester, refresh: refresh);
    expect(find.text('مێتا'), findsOneWidget);
    final gate = Completer<Object>();
    delayedMeta = gate;
    await tester.tap(find.text('مێتا'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(backend.adQueries.last.queryParameters['or'], '(platform.eq.META)');
    expect(find.text('TIKTOK title 0'), findsNothing);
    await tester.tap(find.text('تیک تۆک'));
    await tester.pumpAndSettle();
    expect(find.text('TIKTOK title 0'), findsOneWidget);
    delayedMeta = null;
    gate.complete([records.first]);
    await tester.pumpAndSettle();
    expect(find.text('META title 0'), findsNothing);
    expect(find.text('TIKTOK title 0'), findsOneWidget);
    final scroll = tester.state<ScrollableState>(find
        .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable))
        .first);
    scroll.position.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(
        backend.adQueries.any((uri) =>
            uri.queryParameters['offset'] == '20' &&
            uri.queryParameters['or'] ==
                '(platform.eq.TIKTOK,and(platform.is.null,service_type.eq.tiktok))'),
        isTrue);
    final request = refresh.refresh();
    await tester.pumpAndSettle();
    await request;
    expect(backend.adQueries.last.queryParameters['limit'], '40');
    expect(backend.adQueries.last.queryParameters['or'],
        '(platform.eq.TIKTOK,and(platform.is.null,service_type.eq.tiktok))');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    refresh.dispose();
  });

  testWidgets(
      'realtime stays scoped and revocation preserves authorized history',
      (tester) async {
    await mount(tester);
    await tester.tap(find.text('مێتا'));
    await tester.pumpAndSettle();
    final reads = backend.adQueries.length;
    backend.emitAdChange({...records[1], 'spend': 5});
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(backend.adQueries.length, reads);
    final newest = {
      ...records.first,
      'id': 'new-meta',
      'title': 'New Meta history'
    };
    records.insert(0, newest);
    backend.emitAdChange(newest, event: 'INSERT');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.text('New Meta history'), findsOneWidget);
    expect(find.text('TIKTOK title 0'), findsNothing);
    backend.metaEnabled = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('مێتا'), findsNothing);
    expect(find.text('تیک تۆک'), findsNothing);
    expect(backend.adQueries.last.queryParameters['or'], isNull);
    expect(find.text('New Meta history'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
