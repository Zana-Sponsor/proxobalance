import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/screens/ad_create_screen.dart';
import 'package:proxo_app/services/ad_submission.dart';
import 'package:proxo_app/widgets/ad_form_components.dart';
import 'package:proxo_app/widgets/ad_payment_card.dart';
import 'package:proxo_app/widgets/ad_schedule_picker.dart';
import 'package:proxo_app/widgets/bottom_nav.dart';
import 'package:proxo_app/widgets/payments/payment_option.dart';
import 'package:proxo_app/widgets/proxo_symbol.dart';
import 'package:proxo_app/widgets/receipt/receipt_kit.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'ad_creation_flow_test.dart'
    show AdPaintBinding, TestAdRepository, tapVisible, capturePng;

Widget metaHost(Widget child, {double scale = 1}) => RepaintBoundary(
    key: const ValueKey('ad-preview-capture'),
    child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        builder: (context, navigator) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: navigator!),
        home: child));

class MetaRepository extends TestAdRepository {
  bool allowed = true;
  bool fastPay = false;
  DateTime time = DateTime.utc(2030, 1, 15, 9, 30, 15);
  final List<Completer<AdQuote>> requests = [];
  bool delayed = false;
  @override
  Future<bool> metaAvailable() async => allowed;
  @override
  Future<bool> metaFastPayAvailable() async => fastPay;
  @override
  Future<DateTime?> serverTime() async => time;
  @override
  Future<AdQuote> quote(AdDraft d) {
    if (!delayed) {
      lastQuoteDraft = d;
      return Future.value(AdQuote(
          grossUsd: d.dailyBudget * d.days * 1.0,
          costUsd: d.dailyBudget * d.days * 1.0,
          rate: 1800,
          balanceUsd: 1000,
          days: d.days,
          metaContract: const {'fixture': true}));
    }
    lastQuoteDraft = d;
    final request = Completer<AdQuote>();
    requests.add(request);
    return request.future;
  }
}

const fixture = AdDraft(
    platform: 'META',
    title: 'ڕیکلامی تاقیکردنەوە ABC',
    link: 'https://www.facebook.com/example/posts/123',
    pageUrl: 'https://www.facebook.com/example',
    goal: 'messages',
    dailyBudget: 5,
    days: 3,
    paymentMethod: 'app_balance',
    immediate: true);

void main() {
  AdPaintBinding();
  setUpAll(() async {
    await (FontLoader('Rabar')
          ..addFont(rootBundle.load('assets/fonts/Rabar_021.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    await (FontLoader(ReceiptTokens.fontFamily)
          ..addFont(rootBundle.load(ReceiptTokens.fontAsset)))
        .load();
    await (FontLoader('RabarAuthRegular')
          ..addFont(rootBundle.load('assets/fonts/Rabar_022.ttf')))
        .load();
    Directory('docs/meta_ads_evidence').createSync(recursive: true);
  });
  testWidgets('ordinary user cannot enter a direct Meta route', (tester) async {
    await tester.pumpWidget(metaHost(
        AdCreateScreen(platform: 'META', repository: TestAdRepository())));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ad-title')), findsNothing);
    expect(find.text('ئەم خزمەتگوزارییە بەردەست نییە'), findsOneWidget);
  });
  testWidgets('gate revocation preserves pending recovery', (tester) async {
    final repo = MetaRepository()..allowed = false;
    repo.saved = AdPendingSubmission.create(
        fixture, const AdQuote(grossUsd: 15, costUsd: 15, rate: 1800));
    await tester.pumpWidget(
        metaHost(AdCreateScreen(platform: 'META', repository: repo)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('resume-pending-ad')), findsOneWidget);
    expect(find.byKey(const ValueKey('ad-title')), findsNothing);
  });
  testWidgets(
      'placements reject empty atomically and never restore destinations',
      (tester) async {
    final repo = MetaRepository();
    await tester.pumpWidget(metaHost(AdCreateScreen(
        platform: 'META', repository: repo, proxoCard: fixture.toJson())));
    await tester.pumpAndSettle();
    final fb = find.byKey(const ValueKey('placement-facebook'));
    final ig = find.byKey(const ValueKey('placement-instagram'));
    await tapVisible(tester, fb);
    expect(tester.widget<AdChoice>(fb).selected, isFalse);
    expect(
        tester
            .widget<AdChoice>(
                find.byKey(const ValueKey('destination-MESSENGER')))
            .selected,
        isFalse);
    await tapVisible(tester, ig);
    expect(tester.widget<AdChoice>(ig).selected, isTrue);
    expect(find.text('لانیکەم یەک شوێنی پیشاندان هەڵبژێرە'), findsOneWidget);
    await tapVisible(tester, fb);
    expect(
        tester
            .widget<AdChoice>(
                find.byKey(const ValueKey('destination-MESSENGER')))
            .selected,
        isFalse);
    expect(repo.lastQuoteDraft!.placements, {'facebook', 'instagram'});
  });
  for (final platform in ['META', 'TIKTOK']) {
    testWidgets(
        '$platform default wallet card edits only through confirmed sheet',
        (tester) async {
      final repo = MetaRepository()..fastPay = true;
      await tester.pumpWidget(
          metaHost(AdCreateScreen(platform: platform, repository: repo)));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('ad-title')), 'Preserved draft');
      await tester.pumpAndSettle();
      final card = find.byType(AdPaymentCard);
      expect(tester.widget<AdPaymentCard>(card).value, 'app_balance');
      expect(find.byKey(const ValueKey('payment-app_balance')), findsNothing);
      expect(find.byKey(const ValueKey('confirm-payment')), findsNothing);
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      final before =
          tester.getSize(find.byKey(const ValueKey('selected-payment-card')));
      await tester.tap(find.byKey(const ValueKey('selected-payment-card')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('payment-method-sheet')), findsNothing);
      await tapVisible(tester, find.byKey(const ValueKey('change-payment')));
      final wallet = find.byKey(const ValueKey('payment-app_balance'));
      final fastpay = find.byKey(const ValueKey('payment-fastpay'));
      expect(tester.getSize(wallet), tester.getSize(fastpay));
      expect(tester.widget<PaymentOption>(wallet).selected, isTrue);
      expect(tester.widget<PaymentOption>(fastpay).selectedOnlyCheck, isTrue);
      final ticks = find.descendant(
          of: find.byKey(const ValueKey('payment-method-sheet')),
          matching: find.byWidgetPredicate(
              (w) => w is ProxoSymbol && w.symbol == ProxoSymbolName.check));
      expect(ticks, findsOneWidget);
      final walletIcon = find.descendant(
          of: wallet,
          matching: find.byWidgetPredicate(
              (w) => w is ProxoSymbol && w.symbol == ProxoSymbolName.wallet));
      expect(tester.getCenter(walletIcon).dx,
          greaterThan(tester.getCenter(ticks).dx));

      await tapVisible(tester, fastpay);
      expect(tester.widget<PaymentOption>(wallet).selected, isFalse);
      expect(tester.widget<PaymentOption>(fastpay).selected, isTrue);
      expect(ticks, findsOneWidget);
      expect(tester.widget<AdPaymentCard>(card).value, 'app_balance');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.widget<AdPaymentCard>(card).value, 'app_balance');
      await tapVisible(tester, find.byKey(const ValueKey('change-payment')));
      await tapVisible(tester, fastpay);
      await tapVisible(tester, find.byKey(const ValueKey('confirm-payment')));
      expect(tester.widget<AdPaymentCard>(card).value, 'fastpay');
      expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('ad-title')))
              .controller!
              .text,
          'Preserved draft');
      expect(
          tester.getSize(find.byKey(const ValueKey('selected-payment-card'))),
          before);
      expect(find.byKey(const ValueKey('payment-method-sheet')), findsNothing);
      await tapVisible(tester, find.byKey(const ValueKey('change-payment')));
      expect(tester.widget<PaymentOption>(fastpay).selected, isTrue);
      await tapVisible(tester, wallet);
      await tapVisible(tester, find.byKey(const ValueKey('confirm-payment')));
      expect(tester.widget<AdPaymentCard>(card).value, 'app_balance');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('text edits prevent a late quote from overwriting current price',
      (tester) async {
    final repo = MetaRepository();
    await tester.pumpWidget(metaHost(AdCreateScreen(
        platform: 'META', repository: repo, proxoCard: fixture.toJson())));
    await tester.pumpAndSettle();
    repo.delayed = true;
    await tester.enterText(find.byKey(const ValueKey('ad-title')), 'First');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byKey(const ValueKey('ad-title')), 'Second');
    await tester.pump(const Duration(milliseconds: 200));
    expect(repo.requests.length, 2);
    repo.requests.last
        .complete(const AdQuote(grossUsd: 15, costUsd: 15, rate: 1800));
    await tester.pump();
    repo.requests.first
        .complete(const AdQuote(grossUsd: 999, costUsd: 999, rate: 1800));
    await tester.pump();
    expect(
        tester
            .widget<AdPriceDetails>(find.byType(AdPriceDetails))
            .quote
            .costUsd,
        15);
  });
  testWidgets(
      'shared time picker disables past hours and elapsed minutes, including resume',
      (tester) async {
    var now = DateTime.utc(2030, 1, 15, 12, 30, 15);
    await tester.pumpWidget(metaHost(Builder(
        builder: (context) => Scaffold(
            body: TextButton(
                onPressed: () => showAdTimePicker(
                    context: context,
                    date: DateTime.utc(2030, 1, 15),
                    now: () => now,
                    initialTime: const TimeOfDay(hour: 12, minute: 31)),
                child: const Text('Time'))))));
    await tester.tap(find.text('Time'));
    await tester.pumpAndSettle();
    final menus = tester
        .widgetList<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>))
        .toList();
    // Inspect the actual public DropdownButton entries rendered by each field.
    final dropdowns = tester
        .widgetList<DropdownButton<int>>(find.byType(DropdownButton<int>))
        .toList();
    expect(menus.length, 2);
    expect(dropdowns[0].items!.first.enabled, isFalse);
    expect(dropdowns[0].items![12].enabled, isTrue);
    expect(dropdowns[1].items![30].enabled, isFalse);
    expect(dropdowns[1].items![31].enabled, isTrue);
    now = DateTime.utc(2030, 1, 15, 12, 32);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('confirm-ad-time')))
            .onPressed,
        isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('shared date dialog refreshes disabled dates at Baghdad midnight',
      (tester) async {
    var now = DateTime.utc(2030, 1, 15, 23, 59, 58);
    await tester.pumpWidget(metaHost(Builder(
        builder: (context) => Scaffold(
            body: TextButton(
                onPressed: () =>
                    showAdDatePicker(context: context, now: () => now),
                child: const Text('Date'))))));
    await tester.tap(find.text('Date'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
            .firstDate,
        DateTime(2030, 1, 15));
    now = DateTime.utc(2030, 1, 16);
    await tester.pump(const Duration(seconds: 2));
    expect(
        tester
            .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
            .firstDate,
        DateTime(2030, 1, 16));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
      'center launcher defaults TikTok and eligible state expands only two equal actions',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final selections = <String>[];
    int taps = 0;
    await tester.pumpWidget(metaHost(Scaffold(
        bottomNavigationBar:
            ProxoBottomNav(currentIndex: 0, onTap: (_) => taps++))));
    await tester.tap(find.byKey(const ValueKey('bottom-nav-2')));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(find.text('مێتا'), findsNothing);
    await tester.pumpWidget(metaHost(Scaffold(
        bottomNavigationBar: ProxoBottomNav(
            currentIndex: 0,
            onTap: (_) => taps++,
            metaEnabled: true,
            onCreatePlatform: selections.add))));
    await tester.tap(find.byKey(const ValueKey('bottom-nav-2')));
    await tester.pumpAndSettle();
    final meta = find.byKey(const ValueKey('create-platform-META'));
    final tiktok = find.byKey(const ValueKey('create-platform-TIKTOK'));
    expect(meta, findsOneWidget);
    expect(tiktok, findsOneWidget);
    expect(tester.getSize(meta), tester.getSize(tiktok));
    await capturePng(tester, 'docs/meta_ads_evidence/launcher.png');
    await tester.tap(meta);
    await tester.pumpAndSettle();
    expect(selections, ['META']);
    expect(meta, findsNothing);
    await tester.tap(find.byKey(const ValueKey('bottom-nav-2')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(meta, findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final width in [280.0, 768.0]) {
    testWidgets(
        'eligible launcher stays within $width at 200 percent text and collapses on routes',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 852);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(metaHost(
          Scaffold(
              bottomNavigationBar: ProxoBottomNav(
                  currentIndex: 0,
                  onTap: (_) {},
                  metaEnabled: true,
                  onCreatePlatform: (_) {})),
          scale: 2));
      await tester.pumpAndSettle();
      final plus = find.byKey(const ValueKey('bottom-nav-2'));
      await Scrollable.ensureVisible(tester.element(plus), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(plus);
      await tester.pumpAndSettle();
      final meta = find.byKey(const ValueKey('create-platform-META'));
      final tiktok = find.byKey(const ValueKey('create-platform-TIKTOK'));
      expect(tester.getSize(meta), tester.getSize(tiktok));
      expect(tester.getRect(tiktok).left, greaterThanOrEqualTo(0));
      expect(tester.getRect(meta).right, lessThanOrEqualTo(width));
      expect(tester.takeException(), isNull);
      await capturePng(
          tester, 'docs/meta_ads_evidence/launcher_${width.toInt()}_2x.png');
      unawaited(tester.state<NavigatorState>(find.byType(Navigator)).push(
          MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Another route')))));
      await tester.pumpAndSettle();
      expect(meta, findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(meta, findsNothing);
    });
  }
  for (final width in [280.0, 393.0, 768.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Meta form fits $width at $scale and captures real widgets',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 852);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(metaHost(
            AdCreateScreen(
                platform: 'META',
                repository: MetaRepository(),
                proxoCard: fixture.toJson()),
            scale: scale));
        await tester.pumpAndSettle();
        await Scrollable.ensureVisible(
            tester.element(find.byKey(const ValueKey('goal-messages'))),
            alignment: 0.1);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final objectives = ['messages', 'views', 'engagement']
            .map((goal) => tester.getSize(find.byKey(ValueKey('goal-$goal'))))
            .toList();
        expect(objectives[0], objectives[1]);
        expect(objectives[1], objectives[2]);
        await capturePng(tester,
            'docs/meta_ads_evidence/meta_${width.toInt()}_${scale.toInt()}x.png');
        await tester.ensureVisible(find.byKey(const ValueKey('review-ad')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (width == 393 && scale == 1) {
          await capturePng(tester, 'docs/meta_ads_evidence/meta_payment.png');
        }
        await tapVisible(tester, find.byKey(const ValueKey('change-payment')));
        final wallet = find.byKey(const ValueKey('payment-app_balance'));
        final fastpay = find.byKey(const ValueKey('payment-fastpay'));
        expect(tester.getSize(wallet), tester.getSize(fastpay));
        expect(tester.takeException(), isNull);
        await capturePng(tester,
            'docs/meta_ads_evidence/payment_sheet_${width.toInt()}_${scale.toInt()}x.png');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
      });
    }
  }
}
