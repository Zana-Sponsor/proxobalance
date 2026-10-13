import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/widgets/proxo_banner.dart';
import '../integration_test/support/actual_screen_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const old = bool.fromEnvironment('PROXO_REPRODUCE_OLD_BANNER');
  final backend = ActualScreenBackend();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await backend.initialize();
  });
  tearDownAll(() => backend.dispose());

  Future<void> flush(WidgetTester t) async {
    // Bounded event processing, not a navigation/performance measurement.
    for (var i=0;i<20;i++) { await t.pump(const Duration(milliseconds: 10)); }
  }

  testWidgets('banner does not subscribe after pending load is disposed', (t) async {
    final gate=Completer<void>();backend.bannerGate=gate;
    await t.pumpWidget(MaterialApp(home:ProxoBanner(onStart:() {})));
    await flush(t);
    expect(backend.reads['pa_banners'],1);
    await t.pumpWidget(const SizedBox.shrink());
    gate.complete();await flush(t);
    expect(backend.bannerJoins,old?1:0);
    expect(backend.client.getChannels().length,old?1:0);
    print('BANNER_DISPOSE old=$old joins=${backend.bannerJoins} channels=${backend.client.getChannels().length}');
    final cleanup=backend.client.removeAllChannels();await flush(t);
    // The SDK's socket-close timeout runs on the test's fake clock. Drain it
    // only after all lifecycle assertions; never extend a product deadline.
    await t.pump(const Duration(seconds:7));await cleanup;
    backend.bannerGate=null;
    expect(t.takeException(),isNull);
  }, timeout: const Timeout(Duration(seconds:45)));

  testWidgets('banner realtime reload retains one subscription', (t) async {
    final joinsBefore=backend.bannerJoins;
    await t.pumpWidget(MaterialApp(home:ProxoBanner(onStart:() {})));
    await flush(t);
    expect(backend.bannerJoins-joinsBefore,1);
    final readsBefore=backend.reads['pa_banners']!;
    backend.emitBannerChange();await flush(t);
    expect(backend.reads['pa_banners'],readsBefore+1);
    expect(backend.bannerJoins-joinsBefore,old?2:1);
    print('BANNER_RELOAD old=$old joins=${backend.bannerJoins-joinsBefore} reads=${backend.reads['pa_banners']!-readsBefore}');
    await t.pumpWidget(const SizedBox.shrink());await flush(t);
    final cleanup=backend.client.removeAllChannels();await flush(t);
    // The SDK's socket-close timeout runs on the test's fake clock. Drain it
    // only after all lifecycle assertions; never extend a product deadline.
    await t.pump(const Duration(seconds:7));await cleanup;
    expect(t.takeException(),isNull);
  }, timeout: const Timeout(Duration(seconds:45)));
}
