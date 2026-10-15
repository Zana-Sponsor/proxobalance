import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/widgets/proxo_banner.dart';
import 'package:proxo_app/widgets/proxo_text.dart';
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

  Future<void> cleanup(WidgetTester t) async {
    // The fixture disconnects automatically when its last channel leaves.
    // removeAllChannels also disconnects, racing that close and cancelling the
    // single-subscription stream before its done event can finish sink.close.
    final channels = [...backend.client.getChannels()];
    var completed = false;
    final done = Future.wait(channels.map(backend.client.removeChannel))
        .then((_) => completed = true);
    await flush(t);
    expect(completed, isTrue, reason: 'fixture leave acknowledgements');
    expect(backend.client.getChannels(), isEmpty);
    await done;
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
    await cleanup(t);
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
    await cleanup(t);
    expect(t.takeException(),isNull);
  }, timeout: const Timeout(Duration(seconds:45)));
  if (!old) testWidgets('admin banner removal clears persistent cache and legacy links still navigate', (t) async {
    backend.banner = {'title':'Admin banner fixture','subtitle':'Fictional CMS text',
      'btn_text':'Open','bg_color':'#1457BC','link':'/tools'};
    String? target;
    await t.pumpWidget(MaterialApp(home: Scaffold(body: ProxoBanner(onNavigate:(v)=>target=v))));
    await flush(t);
    expect(find.text('Admin banner fixture'), findsOneWidget);
    await t.tap(find.text('Admin banner fixture'));
    expect(target, '/tools');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().any((k) => (prefs.get(k)?.toString() ?? '').contains('Admin banner fixture')), isTrue);
    backend.banner = null; backend.emitBannerChange(); await flush(t);
    expect(find.text('Admin banner fixture'), findsNothing);
    expect(prefs.getKeys().any((k) => (prefs.get(k)?.toString() ?? '').contains('Admin banner fixture')), isFalse);
    await t.pumpWidget(const SizedBox()); await flush(t); await cleanup(t);
    expect(t.takeException(), isNull);
  });
  if (!old) testWidgets('light admin backgrounds use readable ink without a synthetic CTA', (t) async {
    backend.banner = {'title':'Light admin banner','subtitle':'Admin controls this text',
      'bg_color':'#FFFFFF','locale':'all'};
    await t.pumpWidget(MaterialApp(home: Scaffold(body: ProxoBanner(onStart: () {}))));
    await flush(t);
    final title = t.widget<ProxoText>(find.byWidgetPredicate((w) => w is ProxoText && w.data == 'Light admin banner'));
    expect(title.style!.color!.computeLuminance(), lessThan(.1));
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    backend.banner = {'title':'Dark admin banner','bg_color':'#102040','locale':'all'};
    backend.emitBannerChange(); await flush(t);
    final updated = t.widget<ProxoText>(find.byWidgetPredicate((w) => w is ProxoText && w.data == 'Dark admin banner'));
    expect(updated.style!.color, Colors.white);
    await t.pumpWidget(const SizedBox()); await flush(t); await cleanup(t);
    backend.banner = null;
    expect(t.takeException(),isNull);
  });

}
