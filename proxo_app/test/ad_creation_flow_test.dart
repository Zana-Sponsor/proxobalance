import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/screens/ad_create_screen.dart';
import 'package:proxo_app/screens/ad_confirmation_screen.dart';
import 'package:proxo_app/services/ad_submission.dart';
import 'package:proxo_app/services/ad_forecast.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/widgets/ad_form_components.dart';
import 'package:proxo_app/widgets/ad_validation_notifications.dart';
import 'package:proxo_app/widgets/proxo_text.dart';
import 'ad_submission_test.dart' show validDraft;

class AdPaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

class TestAdRepository extends AdCreationRepository {
  int submissions = 0;
  int pendingFailures = 0;
  bool couponExpired = false;
  AdDraft? lastQuoteDraft;
  double balance = 1000;
  AdPendingSubmission? saved;
  AdSubmissionFailure? failure;
  Completer<String>? completion;
  List<Map<String, dynamic>> assets = [
    {'id': 'contact-1', 'name': 'پەڕەی ABC-123'}
  ];
  @override
  Future<List<Map<String, dynamic>>> loadAssets() async => assets;
  @override
  Future<AdPendingSubmission?> pending() async {
    if (pendingFailures-- > 0) {
      throw const AdSubmissionFailure('STORAGE_UNAVAILABLE');
    }
    return saved;
  }

  @override
  Future<AdQuote> quote(AdDraft d) async {
    lastQuoteDraft = d;
    if (d.promoCode == 'BAD' || (d.promoCode == 'VALID' && couponExpired)) {
      throw const AdSubmissionFailure('INVALID_PROMO');
    }
    final gross = d.dailyBudget * d.days * 1.0;
    return AdQuote(
        grossUsd: gross,
        costUsd: gross - (d.promoCode == 'VALID' ? 2000 / 1800 : 0),
        promoUsd: d.promoCode == 'VALID' ? 2000 / 1800 : 0,
        promoFixedIqd: d.promoCode == 'VALID' ? 2000 : 0,
        rate: 1800,
        balanceUsd: balance,
        days: d.days,
        historicalViewRate: 0.72);
  }

  @override
  Future<String> submit(
      AdPendingSubmission r, ValueNotifier<AdPaymentProgress> progress) async {
    submissions++;
    saved = r;
    if (failure != null) {
      if (!failure!.uncertain) saved = null;
      throw failure!;
    }
    final result = completion == null ? 'created-ad' : await completion!.future;
    saved = null;
    return result;
  }
}

const capture = ValueKey('ad-preview-capture');
Widget host(Widget child, {double scale = 1}) => MaterialApp(
    theme: buildAppTheme(),
    home: Builder(
        builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: RepaintBoundary(key: capture, child: child))));
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> capturePng(WidgetTester tester, String path) async {
  await tester.pump();
  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(capture));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    await File(path).writeAsBytes(bytes.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  AdPaintBinding();
  setUpAll(() async {
    await (FontLoader('Rabar')
          ..addFont(rootBundle.load('assets/fonts/Rabar_021.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  for (final width in [280.0, 393.0, 430.0, 768.0]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('create form fits $width at text scale $scale',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 852);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repo = TestAdRepository();
        await tester
            .pumpWidget(host(AdCreateScreen(repository: repo), scale: scale));
        await tester.pumpAndSettle();
        await tapVisible(tester, find.byKey(const ValueKey('goal-messages')));
        await tester.ensureVisible(find.byKey(const ValueKey('review-ad')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(adForecastDisclaimer), findsOneWidget);
        expect(find.text('پێشبینی کرتەکان'), findsOneWidget);
        for (final text
            in tester.widgetList<ProxoText>(find.byType(ProxoText))) {
          expect(text.data?.toUpperCase() ?? '', isNot(contains('CPM')));
          if (text.style != null) {
            expect(text.style!.fontWeight, FontWeight.w400);
          }
        }
      });
    }
  }
  testWidgets(
      'invalid form shows deduplicated validation stack and cannot confirm',
      (tester) async {
    final repo = TestAdRepository();
    await tester.pumpWidget(host(AdCreateScreen(repository: repo)));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('review-ad')));
    expect(find.byType(AdConfirmationScreen), findsNothing);
    expect(repo.submissions, 0);
    expect(find.byType(AdValidationNotifications), findsOneWidget);
    await capturePng(tester, 'docs/ad_validation_preview.png');
    await tapVisible(tester, find.byKey(const ValueKey('review-ad')));
    expect(tester.takeException(), isNull);
  });
  testWidgets('targeting natural widths, RTL order and supported values',
      (tester) async {
    await tester
        .pumpWidget(host(AdCreateScreen(repository: TestAdRepository())));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('location-all')));
    await tester.pump();
    final all = find.byKey(const ValueKey('location-all')),
        ku = find.byKey(const ValueKey('location-kurdistan')),
        iq = find.byKey(const ValueKey('location-iraq'));
    expect(tester.getCenter(all).dx, greaterThan(tester.getCenter(ku).dx));
    expect(tester.getCenter(ku).dx, greaterThan(tester.getCenter(iq).dx));
    expect(tester.getSize(all).height, tester.getSize(ku).height);
    expect(tester.getSize(all).width, isNot(tester.getSize(ku).width));
    await tapVisible(tester, ku);
    expect(tester.widget<AdChoice>(ku).selected, isTrue);
    await tapVisible(tester, find.byKey(const ValueKey('gender-female')));
    await tapVisible(tester, find.byKey(const ValueKey('device-iphone')));
    await tapVisible(tester, find.byKey(const ValueKey('age-18-24')));
    expect(
        tester.widget<AdChoice>(find.byKey(const ValueKey('age-all'))).selected,
        isFalse);
  });
  testWidgets(
      'both sliders update budget, forecasts and prices without compounding',
      (tester) async {
    await tester.pumpWidget(host(AdCreateScreen(
        repository: TestAdRepository(), proxoCard: validDraft().toJson())));
    await tester.pumpAndSettle();
    final duration = find.byKey(const ValueKey('duration-slider'));
    for (final days in [2.0, 3.0, 5.0, 1.0, 7.0, 2.0]) {
      tester.widget<Slider>(duration).onChanged!(days);
      await tester.pumpAndSettle();
      final totalRow = find.ancestor(
          of: find.text('کۆی بودجە'), matching: find.byType(AdValueRow));
      expect(
          find.descendant(
              of: totalRow, matching: find.text(adIqd(10 * days * 1800))),
          findsOneWidget);
      expect(
          tester
              .widget<AdPriceDetails>(find.byType(AdPriceDetails))
              .quote
              .grossUsd,
          10 * days);
    }
    tester
        .widget<Slider>(find.byKey(const ValueKey('daily-budget-slider')))
        .onChanged!(2);
    await tester.pumpAndSettle();
    final budgetRow = find.ancestor(
        of: find.text('کۆی بودجە'), matching: find.byType(AdValueRow));
    expect(
        find.descendant(of: budgetRow, matching: find.text('180,000 د.ع')),
        findsOneWidget);
    expect(
        tester
            .widget<Slider>(find.byKey(const ValueKey('daily-budget-slider')))
            .label,
        '90,000 د.ع');
    expect(find.text('پێشبینی کرتەکان'), findsNothing);
    await tapVisible(tester, find.byKey(const ValueKey('goal-messages')));
    expect(find.text('پێشبینی کرتەکان'), findsOneWidget);
  });
  testWidgets(
      'valid coupon highlights label and value; invalid coupon has no discount',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester
        .pumpWidget(host(AdCreateScreen(repository: TestAdRepository())));
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey('ad-coupon'));
    await tester.ensureVisible(input);
    await tester.enterText(input, 'VALID');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('بەکارهێنانی کۆد'));
    final row = find.byKey(const ValueKey('coupon-discount'));
    expect(row, findsOneWidget);
    final texts = find.descendant(of: row, matching: find.byType(ProxoText));
    for (final t in tester.widgetList<ProxoText>(texts)) {
      expect(t.style!.color, AdUi.green);
    }
    expect(find.text('−2,000 د.ع'), findsOneWidget);
    await Scrollable.ensureVisible(tester.element(find.byType(AdPriceDetails)),
        alignment: 0.05);
    await tester.pumpAndSettle();
    await capturePng(tester, 'docs/create_ad_coupon_preview.png');
    await tester.ensureVisible(input);
    await tester.enterText(input, 'BAD');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('بەکارهێنانی کۆد'));
    expect(find.byKey(const ValueKey('coupon-discount')), findsNothing);
  });
  testWidgets('contact creation returns to preserved form and selects new page',
      (tester) async {
    final repo = TestAdRepository();
    await tester.pumpWidget(host(AdCreateScreen(
        repository: repo,
        createContactPage: (_) async {
          final card = {'id': 'new-contact', 'name': 'پەڕەی نوێ'};
          repo.assets = [...repo.assets, card];
          return card;
        })));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('ad-title')), 'پاراستنی ناو');
    await tapVisible(tester, find.byKey(const ValueKey('goal-messages')));
    await tapVisible(tester, find.text('دروستکردنی پەڕەی نوێ'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('ad-title')))
            .controller!
            .text,
        'پاراستنی ناو');
    expect(find.text('پەڕەی نوێ'), findsWidgets);
    await tapVisible(tester, find.byKey(const ValueKey('goal-views')));
    expect(find.text('پەڕەی پەیوەندی'), findsNothing);
  });
  testWidgets('expired applied coupon is removed on the next pricing update',
      (tester) async {
    final repo = TestAdRepository();
    await tester.pumpWidget(host(AdCreateScreen(repository: repo)));
    await tester.pumpAndSettle();
    final input = find.byKey(const ValueKey('ad-coupon'));
    await tester.ensureVisible(input);
    await tester.enterText(input, 'VALID');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('بەکارهێنانی کۆد'));
    expect(find.byKey(const ValueKey('coupon-discount')), findsOneWidget);
    repo.couponExpired = true;
    tester
        .widget<Slider>(find.byKey(const ValueKey('duration-slider')))
        .onChanged!(2);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('coupon-discount')), findsNothing);
    expect(repo.lastQuoteDraft!.promoCode, isNull);
  });
  testWidgets('insufficient balance prevents confirmation', (tester) async {
    final repo = TestAdRepository()..balance = 0;
    await tester.pumpWidget(host(
        AdCreateScreen(repository: repo, proxoCard: validDraft().toJson())));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('review-ad')));
    expect(find.byType(AdConfirmationScreen), findsNothing);
    expect(repo.submissions, 0);
    expect(find.text('باڵانسی پێویستت بەردەست نییە'), findsWidgets);
  });
  testWidgets('unreadable pending submission blocks a fresh checkout',
      (tester) async {
    final repo = TestAdRepository()..pendingFailures = 2;
    await tester.pumpWidget(host(
        AdCreateScreen(repository: repo, proxoCard: validDraft().toJson())));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('review-ad')));
    expect(find.byType(AdConfirmationScreen), findsNothing);
    expect(repo.submissions, 0);
    await tapVisible(tester, find.text('دووبارە پشکنینەوە'));
    await tapVisible(tester, find.byKey(const ValueKey('review-ad')));
    expect(find.byType(AdConfirmationScreen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cancel-submission')));
    await tester.pumpAndSettle();
  });
  testWidgets(
      'future scheduling uses date/time controls and survives confirmation',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = TestAdRepository();
    await tester.pumpWidget(host(
        AdCreateScreen(repository: repo, proxoCard: validDraft().toJson())));
    await tester.pumpAndSettle();
    final nowChoice = find.byKey(const ValueKey('schedule-now'));
    final laterChoice = find.byKey(const ValueKey('schedule-later'));
    final dateButton = find.byKey(const ValueKey('ad-date'));
    final timeButton = find.byKey(const ValueKey('ad-time'));
    expect(find.text('ئێستا'), findsOneWidget);
    expect(find.text('دیاریکردنی کات'), findsOneWidget);
    expect(tester.widget<AdChoice>(nowChoice).selected, isTrue);
    expect(tester.widget<AdChoice>(laterChoice).selected, isFalse);
    expect(dateButton, findsNothing);
    expect(timeButton, findsNothing);
    await tapVisible(tester, find.byKey(const ValueKey('schedule-later')));
    expect(tester.widget<AdChoice>(nowChoice).selected, isFalse);
    expect(tester.widget<AdChoice>(laterChoice).selected, isTrue);
    await tapVisible(tester, find.byKey(const ValueKey('ad-date')));
    await tester.pumpAndSettle();
    final now = adScheduleNow(),
        tomorrow =
            DateUtils.dateOnly(adScheduleNow()).add(const Duration(days: 1));
    // Move the actual calendar to the current month (prefilled ads may be in a later year).
    final calendar =
        tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
    calendar.onDateChanged(tomorrow);
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('ad-time')));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    String pickerText(Finder button) => tester.widget<ProxoText>(
        find.descendant(of: button, matching: find.byType(ProxoText))).data!;
    final dateText = pickerText(dateButton), timeText = pickerText(timeButton);
    await Scrollable.ensureVisible(
        tester.element(find.text('بەروار و کاتی دەستپێک')), alignment: 0.15);
    await tester.pumpAndSettle();
    await capturePng(tester, 'docs/create_ad_schedule_preview.png');
    await tapVisible(tester, nowChoice);
    expect(tester.widget<AdChoice>(nowChoice).selected, isTrue);
    expect(tester.widget<AdChoice>(laterChoice).selected, isFalse);
    expect(dateButton, findsNothing);
    expect(timeButton, findsNothing);
    await tapVisible(tester, laterChoice);
    expect(pickerText(dateButton), dateText);
    expect(pickerText(timeButton), timeText);
    await tapVisible(tester, find.byKey(const ValueKey('review-ad')));
    expect(find.byType(AdConfirmationScreen), findsOneWidget);
    final draft = tester
        .widget<AdConfirmationScreen>(find.byType(AdConfirmationScreen))
        .request
        .draft;
    expect(draft.immediate, isFalse);
    expect(DateUtils.dateOnly(draft.schedule!), tomorrow);
    expect(draft.schedule!.isAfter(now), isTrue);
    expect(repo.lastQuoteDraft!.schedule, draft.schedule);
    await tester.tap(find.byKey(const ValueKey('cancel-submission')));
    await tester.pumpAndSettle();
  });
  testWidgets('incomplete future scheduling cannot reach confirmation',
      (tester) async {
    final repo = TestAdRepository();
    final draft = validDraft().toJson()
      ..remove('start_date')
      ..remove('start_time');
    await tester.pumpWidget(host(AdCreateScreen(
        repository: repo, proxoCard: draft)));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('schedule-later')));
    await tapVisible(tester, find.byKey(const ValueKey('review-ad')));
    expect(find.byType(AdConfirmationScreen), findsNothing);
    expect(repo.submissions, 0);
    expect(find.byType(AdValidationNotifications), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('cancel countdown returns to entered form without submitting',
      (tester) async {
    final repo = TestAdRepository();
    await tester.pumpWidget(host(
        AdCreateScreen(repository: repo, proxoCard: validDraft().toJson())));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('review-ad')));
    expect(find.byType(AdConfirmationScreen), findsOneWidget);
    expect(repo.submissions, 0);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('cancel-submission')));
    await tester.pumpAndSettle();
    expect(repo.submissions, 0);
    expect(repo.saved, isNull);
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('ad-title')))
            .controller!
            .text,
        validDraft().title);
  });
  testWidgets(
      'successful confirmation returns refresh and invokes creation once',
      (tester) async {
    final repo = TestAdRepository();
    var created = 0;
    String? result;
    await tester.pumpWidget(host(Builder(
        builder: (context) => Scaffold(
            body: FilledButton(
                onPressed: () async {
                  result = await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                          builder: (_) => AdCreateScreen(
                              repository: repo,
                              proxoCard: validDraft().toJson(),
                              onAdCreated: () => created++)));
                },
                child: const ProxoText('Open ad form'))))));
    await tester.tap(find.text('Open ad form'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('review-ad')));
    expect(repo.submissions, 0);
    await tester.pump(const Duration(seconds: 11));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(repo.submissions, 1);
    expect(created, 1);
    expect(result, 'refresh');
    expect(find.byType(AdCreateScreen), findsNothing);
    expect(repo.saved, isNull);
  });
  testWidgets(
      'countdown submits once and disables cancellation while processing',
      (tester) async {
    final repo = TestAdRepository()..completion = Completer<String>();
    final r = AdPendingSubmission.create(
        validDraft(), const AdQuote(grossUsd: 10, costUsd: 10, rate: 1800));
    await tester.pumpWidget(host(AdConfirmationScreen(
        request: r, repository: repo, countdown: const Duration(seconds: 3))));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(repo.submissions, 0);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(repo.submissions, 1);
    expect(
        tester
            .widget<OutlinedButton>(
                find.byKey(const ValueKey('cancel-submission')))
            .onPressed,
        isNull);
    await tester.pump(const Duration(seconds: 2));
    expect(repo.submissions, 1);
    repo.completion!.complete('created');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('ad-success')), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });
  testWidgets('uncertain failures retry same key and cannot cancel',
      (tester) async {
    final repo = TestAdRepository()
      ..failure = const AdSubmissionFailure('NETWORK', uncertain: true);
    final r = AdPendingSubmission.create(
        validDraft(), const AdQuote(grossUsd: 10, costUsd: 10, rate: 1800));
    await tester.pumpWidget(host(AdConfirmationScreen(
        request: r, repository: repo, countdown: const Duration(seconds: 1))));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(repo.saved!.id, r.id);
    expect(
        tester
            .widget<OutlinedButton>(
                find.byKey(const ValueKey('cancel-submission')))
            .onPressed,
        isNull);
    await tester.tap(find.byKey(const ValueKey('retry-submission')));
    await tester.pump();
    expect(repo.submissions, 2);
    expect(repo.saved!.id, r.id);
  });
  testWidgets('editing after a paid FastPay failure switches to account credit',
      (tester) async {
    final repo = TestAdRepository()
      ..failure =
          const AdSubmissionFailure('PRICE_CHANGED', paymentCredited: true);
    final draft = AdDraft.fromJson(
        {...validDraft().toJson(), 'payment_method': 'fastpay'});
    await tester.pumpWidget(
        host(AdCreateScreen(repository: repo, proxoCard: draft.toJson())));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('review-ad')));
    await tester.pump(const Duration(seconds: 11));
    await tester.pump();
    expect(repo.submissions, 1);
    expect(find.textContaining('پارەدانی FastPay لە باڵانسی'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('cancel-submission')));
    await tester.pumpAndSettle();
    expect(find.byType(AdConfirmationScreen), findsNothing);
    expect(repo.lastQuoteDraft!.paymentMethod, 'app_balance');
    expect(repo.saved, isNull);
  });
  testWidgets('countdown pauses while the app is backgrounded', (tester) async {
    final repo = TestAdRepository()..completion = Completer<String>();
    final request = AdPendingSubmission.create(
        validDraft(), const AdQuote(grossUsd: 10, costUsd: 10, rate: 1800));
    await tester.pumpWidget(host(AdConfirmationScreen(
        request: request,
        repository: repo,
        countdown: const Duration(seconds: 3))));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 10));
    expect(repo.submissions, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2016));
    expect(repo.submissions, 1);
    repo.completion!.complete('created');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  });
  for (final width in [280.0, 393.0, 768.0]) {
    testWidgets('confirmation fits $width with long mixed values',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 852);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final draft = AdDraft.fromJson({
        ...validDraft(goal: 'messages', asset: 'contact-1').toJson(),
        'asset_name': 'پەڕەی پەیوەندی ABC-123',
        'video_code': 'CODE-${'ABC-123-' * 20}'
      });
      await tester.pumpWidget(host(
          AdConfirmationScreen(
              request: AdPendingSubmission.create(
                  draft, const AdQuote(grossUsd: 10, costUsd: 10, rate: 1800)),
              repository: TestAdRepository()),
          scale: 1.5));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.text(draft.assetName!), findsOneWidget);
      final cancel = find.byKey(const ValueKey('cancel-submission'));
      expect(tester.getRect(cancel).bottom, lessThanOrEqualTo(852));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets(
      'three validation pages each hold five seconds and dismiss in order',
      (tester) async {
    final controller = AdValidationController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(
        Scaffold(body: AdValidationNotifications(controller: controller))));
    controller.show({
      'a': 'هەڵەی یەکەم',
      'b': 'هەڵەی دووەم',
      'c': 'هەڵەی سێیەم',
      'd': 'هەڵەی چوارەم'
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('هەڵەی یەکەم'), findsOneWidget);
    expect(find.text('هەڵەی چوارەم'), findsNothing);
    controller.show({'a': 'هەڵەی یەکەم'});
    await tester.pump();
    expect(find.text('هەڵەی یەکەم'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 4600));
    expect(find.text('هەڵەی یەکەم'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('هەڵەی یەکەم'), findsNothing);
    expect(find.text('هەڵەی چوارەم'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.byType(ProxoText), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('render Create Ad preview', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host(AdCreateScreen(
        repository: TestAdRepository(), proxoCard: validDraft().toJson())));
    await tester.pumpAndSettle();
    await capturePng(tester, 'docs/create_ad_preview.png');
    await tester.ensureVisible(find.byType(AdPriceDetails));
    await tester.pumpAndSettle();
    await capturePng(tester, 'docs/create_ad_pricing_preview.png');
  });
  testWidgets('render confirmation preview', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host(AdConfirmationScreen(
        request: AdPendingSubmission.create(
            validDraft(), const AdQuote(grossUsd: 10, costUsd: 10, rate: 1800)),
        repository: TestAdRepository())));
    await tester.pump(const Duration(milliseconds: 300));
    await capturePng(tester, 'docs/ad_confirmation_preview.png');
  });
  testWidgets('render budget preview in Iraqi dinars', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      host(
        AdCreateScreen(
          repository: TestAdRepository(),
          proxoCard: {...validDraft().toJson(), 'days': 2},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final slider = find.byKey(const ValueKey('daily-budget-slider'));
    await Scrollable.ensureVisible(tester.element(slider), alignment: 0.15);
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(slider).label, '18,000 د.ع');
    expect(find.text('36,000 د.ع'), findsWidgets);
    expect(tester.takeException(), isNull);
    await capturePng(tester, 'docs/create_ad_budget_preview.png');
  });
  testWidgets('render complete Create Ad design', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      host(
        AdCreateScreen(
          repository: TestAdRepository(),
          proxoCard: {...validDraft().toJson(), 'days': 2},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scroll = find.byKey(const ValueKey('ad-form-scroll'));
    final content =
        find.descendant(of: scroll, matching: find.byType(Center)).first;
    final height =
        tester.getSize(content).height + tester.getTopLeft(scroll).dy + 48;
    tester.view.physicalSize = Size(393, height.ceilToDouble());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capturePng(tester, 'docs/create_ad_full_preview.png');
  });
}
