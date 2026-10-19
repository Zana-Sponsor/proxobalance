// Production deposit UI, isolated payment transport, fictional fixture receipt.
// The transport rejects every unexpected endpoint; no real transfer is sent.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:proxo_app/main.dart' as app;
import 'package:proxo_app/screens/deposit_screen.dart';
import 'package:proxo_app/theme/app_locale.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/widgets/fastpay_checkout_sheet.dart';
import 'package:proxo_app/widgets/proxo_error_stack.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/session_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  late File receipt;
  final requests = <Map<String, dynamic>>[];
  final notices = <Map<String, dynamic>>[];
  Completer<void>? responseGate;
  var failRequest = false;
  var initialized = false;

  setUpAll(() async {
    final manifest =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in manifest) {
      final loader = FontLoader(font['family'] as String);
      for (final entry in font['fonts'] as List) {
        loader.addFont(rootBundle.load(entry['asset'] as String));
      }
      await loader.load();
    }
    final directory =
        Directory.systemTemp.createTempSync('proxo-deposit-fixture-');
    receipt = File('${directory.path}/receipt.png')
      ..writeAsBytesSync(base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l9sAAAAASUVORK5CYII='));
  });
  tearDownAll(() async {
    receipt.parent.deleteSync(recursive: true);
    await client.dispose();
  });
  setUp(() async {
    requests.clear();
    notices.clear();
    responseGate = null;
    failRequest = false;
    SharedPreferences.setMockInitialValues({});
    ProxoLocale.current.value = const Locale('ckb');
    if (!initialized) {
      client = SupabaseClient('https://deposit-fixture.invalid', 'fixture-only',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
        if (request.method != 'POST' ||
            request.url.host != 'deposit-fixture.invalid') {
          throw StateError('deposit_fixture_network_boundary');
        }
        if (request.url.path == '/rest/v1/rpc/pa_submit_topup') {
          final data = jsonDecode(request.body) as Map<String, dynamic>;
          requests.add(data);
          await responseGate?.future;
          if (failRequest) throw StateError('fixture payment unavailable');
          return http.Response(
              jsonEncode({
                'ok': true,
                'credited_iqd': data['p_gross_iqd'],
                'fee_iqd': 0,
                'public_transaction_id': 'FICTIONAL-TOPUP'
              }),
              200,
              request: request,
              headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/functions/v1/notify-deposit-request') {
          notices.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response('{}', 200,
              request: request, headers: {'content-type': 'application/json'});
        }
        throw StateError('deposit_fixture_network_boundary');
      }));
      app.supabase = client;
      initialized = true;
    }
    await restoreFixture(client);
  });
  tearDown(() async {
    if (responseGate != null && !responseGate!.isCompleted) {
      responseGate!.complete();
    }
  });

  Finder key(String name) => find.byKey(ValueKey(name));
  Finder getScroll() => find
      .descendant(of: key('deposit-scroll'), matching: find.byType(Scrollable))
      .first;
  Future<void> settle(WidgetTester t) async {
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  }

  Future<void> mount(WidgetTester t,
      {double width = 393,
      double scale = 1,
      Future<XFile?> Function(ImageSource)? picker}) async {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = Size(width, 852);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        builder: (_, child) => ProxoLocaleScope(
            child: MediaQuery(
                data: MediaQueryData(
                    size: Size(width, 852),
                    textScaler: TextScaler.linear(scale)),
                child: child!)),
        home: DepositScreen(pickReceipt: picker)));
    await settle(t);
  }

  Future<void> top(WidgetTester t) async {
    t.state<ScrollableState>(getScroll()).position.jumpTo(0);
    await settle(t);
  }

  Future<void> reveal(WidgetTester t, String name) async {
    await t.scrollUntilVisible(key(name), 220, scrollable: getScroll());
    await t.ensureVisible(key(name));
    await settle(t);
  }

  Future<void> select(WidgetTester t, String method) async {
    await top(t);
    await reveal(t, 'deposit-method-$method');
    await t.tap(key('deposit-method-$method'));
    await settle(t);
  }

  Future<void> amount(WidgetTester t, String value) async {
    await reveal(t, 'deposit-amount');
    await t.enterText(key('deposit-amount'), value);
    await t.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(t);
  }

  Future<void> attach(WidgetTester t) async {
    await reveal(t, 'deposit-pick-receipt');
    await t.tap(key('deposit-pick-receipt'));
    await settle(t);
    await t.tap(key('deposit-gallery'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    for (var i = 0; i < 20; i++) {
      await t.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 20)));
      await t.pump(const Duration(milliseconds: 50));
      if (key('deposit-change-receipt').evaluate().isNotEmpty ||
          (key('deposit-pick-receipt').evaluate().isNotEmpty &&
              t.widget<InkWell>(key('deposit-pick-receipt')).onTap != null)) {
        break;
      }
    }
    await settle(t);
  }

  Future<void> validForm(WidgetTester t) async {
    await select(t, 'fib');
    await amount(t, '٢٥٠٠٠');
    await reveal(t, 'deposit-sender');
    await t.enterText(key('deposit-sender'), 'Fictional Sender');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(t);
    await attach(t);
    await reveal(t, 'deposit-submit');
  }

  // TopupService deliberately keeps one persistence queue across screens.
  // Start payment work in the real event loop so its completed Futures never
  // retain a previous widget test's disposed FakeAsync zone.
  Future<void> submit(WidgetTester t,
      {bool twice = false, bool gated = false}) async {
    await t.runAsync(() async {
      if (gated) responseGate = Completer<void>();
      final action = t.widget<FilledButton>(key('deposit-submit')).onPressed!;
      action();
      if (twice) action();
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await t.pump();
  }

  Future<void> completeRequest(WidgetTester t) async {
    await t.runAsync(() async {
      responseGate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await t.pump();
  }

  Future<void> unmount(WidgetTester t) async {
    ProxoErrorStack.clear();
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 4));
  }

  for (final width in [320.0, 393.0, 430.0, 768.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('deposit content fits $width dp at text scale $scale',
          (t) async {
        await mount(t, width: width, scale: scale);
        await select(t, 'fib');
        await amount(t, '25000');
        await reveal(t, 'deposit-instructions');
        await t.tap(key('deposit-instructions'));
        await settle(t);
        final scroll = t.state<ScrollableState>(getScroll()).position;
        for (var offset = 0.0;
            offset < scroll.maxScrollExtent + 600;
            offset += 500) {
          scroll.jumpTo(offset.clamp(0, scroll.maxScrollExtent));
          await t.pump();
          expect(t.takeException(), isNull);
          for (final element in find.byType(RichText).evaluate()) {
            final render = element.findRenderObject();
            if (render is! RenderParagraph || !render.hasSize) continue;
            final left = render.localToGlobal(Offset.zero).dx;
            expect(left, greaterThanOrEqualTo(-.1));
            expect(left + render.size.width, lessThanOrEqualTo(width + .1));
            expect(render.didExceedMaxLines, isFalse);
          }
        }
        await reveal(t, 'deposit-submit');
        expect(
            t.getSize(key('deposit-submit')).height, greaterThanOrEqualTo(48));
        expect(requests, isEmpty);
        expect(notices, isEmpty);
        await unmount(t);
      });
    }
  }

  testWidgets(
      'unconfigured wallets stay disabled and account numbers remain exact',
      (t) async {
    await mount(t);
    await reveal(t, 'deposit-submit');
    expect(t.widget<FilledButton>(key('deposit-submit')).onPressed, isNull);
    for (final method in ['zaincash', 'asiacell', 'korek']) {
      await top(t);
      await reveal(t, 'deposit-method-$method');
      expect(t.widget<InkWell>(key('deposit-method-$method')).onTap, isNull);
    }
    await select(t, 'fib');
    await reveal(t, 'deposit-recipient');
    expect(find.text('7510074008'), findsOneWidget);
    await select(t, 'kcard');
    await reveal(t, 'deposit-recipient');
    expect(find.text('2879264048'), findsOneWidget);
    expect(requests, isEmpty);
    await unmount(t);
  });

  testWidgets(
      'localized amounts and chips show zero-fee credit without changing the amount',
      (t) async {
    await mount(t);
    await select(t, 'fib');
    await amount(t, '٢٥٬٠٠٠');
    expect(
        t.widget<TextField>(key('deposit-amount')).controller!.text, '25000');
    await reveal(t, 'deposit-fee-summary');
    expect(find.text('25,000 IQD'), findsNWidgets(2));
    expect(find.text('0 IQD'), findsOneWidget);
    await top(t);
    await reveal(t, 'deposit-quick-50000');
    await t.tap(key('deposit-quick-50000'));
    await settle(t);
    expect(
        t.widget<TextField>(key('deposit-amount')).controller!.text, '50000');
    await select(t, 'kcard');
    await reveal(t, 'deposit-amount');
    expect(
        t.widget<TextField>(key('deposit-amount')).controller!.text, '50000');
    expect(requests, isEmpty);
    await unmount(t);
  });

  testWidgets('copy uses the selected recipient and has a 48 dp target',
      (t) async {
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await mount(t);
    await select(t, 'kcard');
    await reveal(t, 'deposit-copy');
    expect(t.getSize(key('deposit-copy')), const Size(48, 48));
    await t.tap(key('deposit-copy'));
    await settle(t);
    expect(copied, '2879264048');
    expect(requests, isEmpty);
    await unmount(t);
  });

  testWidgets('missing receipt and sender block submission', (t) async {
    await mount(t);
    await select(t, 'fib');
    await amount(t, '5000');
    await reveal(t, 'deposit-submit');
    await t.tap(key('deposit-submit'));
    await settle(t);
    expect(requests, isEmpty);
    await top(t);
    await reveal(t, 'deposit-sender');
    await t.enterText(key('deposit-sender'), 'Fictional Sender');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(t);
    await reveal(t, 'deposit-submit');
    await t.tap(key('deposit-submit'));
    await settle(t);
    expect(requests, isEmpty);
    await unmount(t);
  });

  testWidgets(
      'picker failure is recoverable and completion after disposal is safe',
      (t) async {
    var selections = 0;
    final gate = Completer<XFile?>();
    await mount(t, picker: (_) {
      selections++;
      return selections == 1
          ? Future<XFile?>.error(StateError('fixture picker failure'))
          : gate.future;
    });
    await select(t, 'fib');
    await attach(t);
    expect(t.widget<InkWell>(key('deposit-pick-receipt')).onTap, isNotNull);
    await t.tap(key('deposit-pick-receipt'));
    await settle(t);
    await t.tap(key('deposit-gallery'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await unmount(t);
    gate.complete(XFile(receipt.path));
    await t.pump();
    expect(t.takeException(), isNull);
    expect(requests, isEmpty);
  });

  testWidgets('submission snapshots details, locks edits and joins double taps',
      (t) async {
    await mount(t, picker: (_) async => XFile(receipt.path));
    await validForm(t);
    await submit(t, twice: true, gated: true);
    expect(requests, hasLength(1));
    expect(requests.single['p_gross_iqd'], 25000);
    expect(requests.single['p_sender'], 'Fictional Sender');
    expect(t.widget<FilledButton>(key('deposit-submit')).onPressed, isNull);
    t.state<ScrollableState>(getScroll()).position.jumpTo(0);
    await t.pump();
    await t.scrollUntilVisible(key('deposit-amount'), 220,
        scrollable: getScroll());
    await t.ensureVisible(key('deposit-amount'));
    await t.pump();
    expect(t.widget<TextField>(key('deposit-amount')).enabled, isFalse);
    // Close the route before the server resolves: no disposed controller reads.
    await unmount(t);
    await completeRequest(t);
    expect(notices, hasLength(1));
    expect(notices.single['amount_iqd'], 25000);
    expect(t.takeException(), isNull);
  });

  testWidgets('failed submission keeps the form and reuses the retry key',
      (t) async {
    await mount(t, picker: (_) async => XFile(receipt.path));
    await validForm(t);
    failRequest = true;
    await submit(t);
    await settle(t);
    expect(requests, hasLength(1));
    expect(t.widget<FilledButton>(key('deposit-submit')).onPressed, isNotNull);
    failRequest = false;
    await submit(t, gated: true);
    expect(requests, hasLength(2));
    expect(requests.last['p_key'], requests.first['p_key']);
    expect(requests.last['p_receipt'], requests.first['p_receipt']);
    await unmount(t);
    await completeRequest(t);
    expect(t.takeException(), isNull);
  });

  testWidgets(
      'changing account during a pending top-up cannot notify or close the new route',
      (t) async {
    await mount(t, picker: (_) async => XFile(receipt.path));
    await validForm(t);
    await submit(t, gated: true);
    expect(requests, hasLength(1));
    await restoreFixture(client, userB);
    await completeRequest(t);
    await t.pump(const Duration(seconds: 2));
    expect(notices, isEmpty);
    expect(find.byType(DepositScreen), findsOneWidget);
    expect(
        find.text('داواکارییەکەت نێردرا — لە ماوەی ١ کاتژمێردا پەسەند دەکرێت'),
        findsNothing);
    expect(
        find.text(
            'داواکارییەکە نەنێردرا — ئینتەرنێتەکەت بپشکنەوە و دووبارە هەوڵ بدەرەوە'),
        findsNothing);
    await unmount(t);
  });

  testWidgets('the success delay cannot pop a route opened after submission',
      (t) async {
    await mount(t, picker: (_) async => XFile(receipt.path));
    await validForm(t);
    await submit(t);
    expect(notices, hasLength(1));
    final navigator = t.state<NavigatorState>(find.byType(Navigator));
    unawaited(navigator.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(
            body: Center(child: Text('Fictional subsequent route'))))));
    await t.pump(const Duration(milliseconds: 400));
    // Submission began in runAsync, so allow the production 900ms delay on
    // that same real clock before checking the route remains unchanged.
    await t.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 1000)));
    await t.pump();
    expect(find.text('Fictional subsequent route'), findsOneWidget);
    expect(navigator.canPop(), isTrue);
    expect(t.takeException(), isNull);
    await unmount(t);
  });

  testWidgets('FastPay keeps one checkout route and no manual submission',
      (t) async {
    await mount(t);
    await select(t, 'fastpay');
    await amount(t, '10000');
    await reveal(t, 'deposit-submit');
    expect(find.byKey(const ValueKey('deposit-payment-details')), findsNothing);
    final open = t.widget<FilledButton>(key('deposit-submit')).onPressed!;
    open();
    open();
    await settle(t);
    expect(find.byType(FastPayCheckoutSheet), findsOneWidget);
    expect(requests, isEmpty);
    expect(notices, isEmpty);
    await unmount(t);
  });
}
