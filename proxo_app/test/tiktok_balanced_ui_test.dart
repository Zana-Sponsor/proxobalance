import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/screens/ad_create_screen.dart';
import 'package:proxo_app/services/ad_submission.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/theme/proxo_surface.dart';
import 'package:proxo_app/widgets/ad_payment_card.dart';
import 'package:proxo_app/widgets/ad_form_components.dart';
import 'package:proxo_app/widgets/bottom_nav.dart';
import 'package:proxo_app/widgets/proxo_text.dart';
import 'package:proxo_app/widgets/receipt/receipt_kit.dart';
import 'package:proxo_app/widgets/tiktok_ad_price_card.dart';

import 'ad_creation_flow_test.dart' show AdPaintBinding, capturePng, tapVisible;
import 'meta_ad_form_test.dart' show metaHost;
import 'proxolink_page_management_test.dart' show page;
import 'tiktok_dm_form_test.dart' show accountsFixture;
import 'tiktok_strict_v3_form_test.dart' show StrictRepository, reveal, view;

const evidence = '../docs/app-wide-release-2026-10-26/screenshots/create-ad';
final measurements = <String, Object?>{};
Finder key(String value) => find.byKey(ValueKey(value));
Finder section(String title) => key('ad-section-$title');
Finder heading(String title) => find
    .descendant(
      of: section(title),
      matching: find.byWidgetPredicate(
        (w) => w is ProxoText && w.data == title,
      ),
    )
    .first;

Future<void> shot(WidgetTester tester, String name) async {
  expect(tester.takeException(), isNull, reason: name);
  await capturePng(tester, '$evidence/$name.png');
}

// Verify the restored card palette in actual rendered pixels, including
// the confirmed payment editor. Geometry and state assertions are independent.
Future<void> paintedColor(
  WidgetTester tester,
  String capture,
  String role,
  Offset logicalPoint,
  int expectedArgb,
) async {
  final actualArgb = await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(
      await File('$evidence/$capture.png').readAsBytes(),
    );
    final frame = await codec.getNextFrame();
    final bytes = (await frame.image.toByteData())!;
    final x = (logicalPoint.dx * 2).floor();
    final y = (logicalPoint.dy * 2).floor();
    final offset = (y * frame.image.width + x) * 4;
    final argb = (bytes.getUint8(offset + 3) << 24) |
        (bytes.getUint8(offset) << 16) |
        (bytes.getUint8(offset + 1) << 8) |
        bytes.getUint8(offset + 2);
    (measurements.putIfAbsent('painted_colors', () => <Object?>[]) as List).add(
      {
        'capture': capture,
        'role': role,
        'x_px': x,
        'y_px': y,
        'argb': argb.toRadixString(16).toUpperCase(),
      },
    );
    frame.image.dispose();
    codec.dispose();
    return argb;
  });
  expect(actualArgb, expectedArgb, reason: '$role rendered pixel in $capture');
}

Map<String, double> rect(Rect value) => {
      'left': value.left,
      'top': value.top,
      'width': value.width,
      'height': value.height,
      'bottom': value.bottom,
    };

void assertTextFits(WidgetTester tester) {
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    final bounds = paragraph.localToGlobal(Offset.zero) & paragraph.size;
    if (!bounds.overlaps(Offset.zero & tester.view.physicalSize)) continue;
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: paragraph.text.toPlainText(),
    );
  }
  expect(tester.takeException(), isNull);
}

void main() {
  AdPaintBinding();
  setUpAll(() async {
    for (final pair in [
      ('Rabar', 'assets/fonts/Rabar_021.ttf'),
      ('RabarAuthRegular', 'assets/fonts/Rabar_022.ttf'),
      (ReceiptTokens.fontFamily, ReceiptTokens.fontAsset),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(pair.$1)..addFont(rootBundle.load(pair.$2))).load();
    }
    Directory(evidence).createSync(recursive: true);
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDownAll(
    () => File('$evidence/measurements.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(measurements),
    ),
  );

  testWidgets('previous card layout keeps current ad and payment flows', (
    tester,
  ) async {
    view(tester);
    final repo = StrictRepository();
    await tester.pumpWidget(
      metaHost(
        AdCreateScreen(repository: repo, tiktokRepository: accountsFixture()),
      ),
    );
    await tester.pumpAndSettle();
    await shot(tester, '01-top-create-ad');

    final sections = tester.widgetList<AdFormSection>(
      find.byType(AdFormSection),
    );
    expect(sections.first.title, 'زانیاری ڕیکلام');
    expect(sections.every((s) => s.style == AdSectionStyle.card), isTrue);
    expect(find.byType(TikTokAdPriceCard), findsNothing);
    expect(find.byType(ProxoBottomNav), findsNothing);
    expect(key('sticky-ad-price'), findsNothing);
    final information = tester.getRect(section('زانیاری ڕیکلام'));
    final objective = tester.getRect(section('جۆری ڕیکلام'));
    expect(information.left, 20);
    expect(information.width, 353);
    expect(objective.top - information.bottom, 24);
    final titleField = tester.getRect(key('ad-title'));
    expect(titleField.left, 36);
    expect(titleField.width, 321);
    expect(titleField.height, greaterThanOrEqualTo(48));
    final surface = tester.widget<Container>(
      find
          .descendant(
            of: section('زانیاری ڕیکلام'),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = surface.decoration! as BoxDecoration;
    expect(decoration.borderRadius, AdUi.radius);
    expect(decoration.boxShadow, AdUi.cardShadow);
    expect(
      tester.widget<TextField>(key('ad-title')).style!.fontFamily,
      ProxoSurface.fontFamily,
    );
    for (final choice in tester.widgetList<AdChoice>(find.byType(AdChoice))) {
      expect(choice.style, AdChoiceStyle.standard);
    }
    for (final id in [
      'goal-contact',
      'goal-views',
      'goal-restaurant',
      'goal-app_download',
      'age-all',
      'age-18-24',
      'age-55+',
      'gender-female',
      'location-all',
    ]) {
      expect(
        tester.getSize(key(id)).height,
        greaterThanOrEqualTo(48),
        reason: id,
      );
    }
    expect(find.text('جۆری پۆل'), findsNothing);
    expect(find.text('جۆری ئامێر'), findsNothing);
    expect(find.text('بینینی وردەکاری'), findsNothing);
    measurements['393px'] = {
      'baseline': '058f2f6 PR44 card presentation',
      'screen': {'width': 393, 'height': 852, 'text_scale': 1},
      'information_card': rect(information),
      'input': rect(titleField),
      'section_gap_dp': objective.top - information.bottom,
      'sticky_price': false,
      'bottom_navigation': false,
      'retained_features': [
        'four ad types',
        'typed pages',
        'TikTok accounts',
        'confirmed payment editor',
        'authoritative pricing',
      ],
    };

    await tapVisible(tester, key('goal-views'));
    await reveal(tester, 'ad-section-جۆری ڕیکلام', alignment: .05);
    await shot(tester, '02-ad-types');
    final primaryRect = tester.getRect(key('goal-views'));
    await paintedColor(
      tester,
      '02-ad-types',
      'restored selected choice fill',
      Offset(primaryRect.center.dx, primaryRect.top + 6),
      AppColors.accentSoft.toARGB32(),
    );
    await reveal(tester, 'ad-field-title', alignment: .1);
    await shot(tester, '03-ad-name');
    await reveal(tester, 'ad-media', alignment: .05);
    await shot(tester, '04-media');
    await tapVisible(tester, key('goal-contact'));
    await reveal(tester, 'ad-section-شوێنی پەیوەندیکردن', alignment: .05);
    await shot(tester, '05-contact-destination');
    final destinationRect = tester.getRect(
      key('contact-destination-external_contact'),
    );
    await paintedColor(
      tester,
      '05-contact-destination',
      'restored destination fill',
      Offset(destinationRect.center.dx, destinationRect.top + 6),
      AppColors.accentSoft.toARGB32(),
    );
    await reveal(tester, 'ad-section-پەڕەی پەیوەندی', alignment: .05);
    await shot(tester, '06-contact-page-collapsed');
    await tapVisible(tester, key('contact-page-disclosure'));
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/images/proxo_logo.png'),
        tester.element(key('contact-page-disclosure')),
      ),
    );
    await tester.pumpAndSettle();
    await reveal(tester, 'ad-section-پەڕەی پەیوەندی', alignment: .05);
    await shot(tester, '07-contact-page-expanded');
    await tapVisible(tester, key('contact-page-${page(1).id}'));
    await tapVisible(tester, key('contact-page-disclosure'));
    await reveal(tester, 'ad-section-شوێنی پەیوەندیکردن', alignment: .05);
    await shot(tester, '22-contact-selected-platform-logos');
    for (final capture in [
      ('age-18-24', 'ad-label-تەمەن', '08-age'),
      ('gender-female', 'ad-label-ڕەگەز', '09-gender'),
    ]) {
      await tapVisible(tester, key(capture.$1));
      await reveal(tester, capture.$2, alignment: .05);
      await shot(tester, capture.$3);
    }
    await reveal(tester, 'ad-section-بودجە و ماوەی ڕیکلام', alignment: .05);
    await shot(tester, '10-budget');
    await tapVisible(tester, key('schedule-later'));
    await reveal(tester, 'ad-section-بەروار و کاتی دەستپێک', alignment: .05);
    await shot(tester, '11-schedule');
    await reveal(tester, 'ad-section-ناردنی ڕیکلام', alignment: .05);
    await shot(tester, '12-payment');
    await tapVisible(tester, key('change-payment'));
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/logos/providers/fastpay.png'),
        tester.element(key('payment-method-sheet')),
      ),
    );
    await tester.pumpAndSettle();
    await shot(tester, '34-payment-sheet-wallet');
    final walletRect = tester.getRect(key('payment-app_balance'));
    await paintedColor(
      tester,
      '34-payment-sheet-wallet',
      'modal selected fill',
      Offset(walletRect.center.dx, walletRect.top + 8),
      AppColors.accentSoft.toARGB32(),
    );
    final confirmRect = tester.getRect(key('confirm-payment'));
    await paintedColor(
      tester,
      '34-payment-sheet-wallet',
      'modal confirm fill',
      Offset(confirmRect.center.dx, confirmRect.top + 8),
      AdUi.blue.toARGB32(),
    );
    await tapVisible(tester, key('payment-fastpay'));
    await shot(tester, '35-payment-sheet-fastpay');
    final fastPayRect = tester.getRect(key('payment-fastpay'));
    await paintedColor(
      tester,
      '35-payment-sheet-fastpay',
      'modal FastPay selected fill',
      Offset(fastPayRect.center.dx, fastPayRect.top + 8),
      AppColors.accentSoft.toARGB32(),
    );
    Navigator.of(tester.element(key('payment-method-sheet'))).pop();
    await tester.pumpAndSettle();
    expect(
      tester.widget<AdPaymentCard>(find.byType(AdPaymentCard)).value,
      'app_balance',
    );
    await reveal(tester, 'review-ad', alignment: .4);
    expect(key('review-ad').hitTestable(), findsOneWidget);
    await shot(tester, '13-submission-card');

    await reveal(tester, 'ad-section-پوختەی نرخ', alignment: .05);
    expect(find.byType(AdPriceDetails), findsOneWidget);
    expect(
      tester.widget<AdPriceDetails>(find.byType(AdPriceDetails)).showTotal,
      isTrue,
    );
    await shot(tester, '14-in-scroll-price');
    final priceBefore = tester.getRect(section('پوختەی نرخ'));
    await tester.drag(key('ad-form-scroll'), const Offset(0, 160));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(section('پوختەی نرخ')).top,
      greaterThan(priceBefore.top),
    );
    await shot(tester, '17-price-scrolls-with-form');

    repo.quoteCompletion = Completer<AdQuote>();
    tester.widget<Slider>(key('duration-slider')).onChanged!(3);
    await tester.pump(const Duration(milliseconds: 400));
    expect(key('ad-price-loading'), findsOneWidget);
    expect(find.byType(AdPriceDetails), findsNothing);
    expect(key('ad-total'), findsNothing);
    // Reveal without pumpAndSettle while the unresolved indicator animates.
    await Scrollable.ensureVisible(
      tester.element(section('پوختەی نرخ')),
      alignment: .1,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await shot(tester, '16-price-loading');
    repo.quoteCompletion!.complete(
      const AdQuote(grossUsd: 30, costUsd: 30, rate: 1800, balanceUsd: 1000),
    );
    repo.quoteCompletion = null;
    await tester.pumpAndSettle();
    expect(
      tester.widget<AdPriceDetails>(find.byType(AdPriceDetails)).quote.totalIqd,
      54000,
    );
    await shot(tester, '15-authoritative-price');
    for (final entry in [('restaurant', 2), ('app_download', 3)]) {
      await tapVisible(tester, key('goal-${entry.$1}'));
      await tapVisible(tester, key('contact-page-disclosure'));
      expect(key('contact-page-${page(entry.$2).id}'), findsOneWidget);
      expect(key('contact-page-${page(1).id}'), findsNothing);
      await reveal(tester, 'ad-section-پەڕەی پەیوەندی', alignment: .05);
      await shot(
        tester,
        entry.$1 == 'restaurant'
            ? '24-restaurant-resources'
            : '25-app-resources',
      );
    }
    await tapVisible(tester, key('goal-contact'));
    await tapVisible(tester, key('contact-destination-direct_message'));
    expect(key('ad-code'), findsNothing);
    expect(
      tester
          .widgetList<AdFormSection>(find.byType(AdFormSection))
          .every((s) => s.style == AdSectionStyle.card),
      isTrue,
    );
    expect(
      find.byType(AdPriceDetails),
      findsNothing,
      reason: 'A missing authoritative DM quote must not expose cached amounts',
    );
    expect(key('ad-total'), findsNothing);
    expect(repo.submissions, 0);
    await reveal(tester, 'ad-section-شوێنی پەیوەندیکردن', alignment: .05);
    await shot(tester, '26-direct-message-card-sections');
    await tapVisible(tester, key('tiktok-account-fixture-account'));
    await reveal(tester, 'tiktok-account-fixture-account', alignment: .05);
    await shot(tester, '36-direct-account-selected');
    await tapVisible(tester, key('tiktok-video-fixture-public'));
    await reveal(tester, 'tiktok-video-fixture-public', alignment: .05);
    await shot(tester, '37-direct-video-selected');
    await tapVisible(tester, find.text('بینینی هەموو'));
    await shot(tester, '38-direct-video-sheet');
    Navigator.of(tester.element(find.byType(GridView))).pop();
    await tester.pumpAndSettle();
    assertTextFits(tester);
  });

  testWidgets(
    'discount and quote errors retain the form without stale totals',
    (tester) async {
      view(tester);
      final repo = StrictRepository();
      await tester.pumpWidget(metaHost(AdCreateScreen(repository: repo)));
      await tester.pumpAndSettle();
      final title = tester.widget<TextField>(key('ad-title')).controller!;
      title.text = 'Customer edited title';
      await tester.ensureVisible(key('ad-coupon'));
      await tester.enterText(key('ad-coupon'), 'VALID');
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('بەکارهێنانی کۆد'));
      await reveal(tester, 'ad-section-پوختەی نرخ', alignment: .05);
      expect(key('coupon-discount'), findsOneWidget);
      expect(find.text('−2,000 د.ع'), findsOneWidget);
      await shot(tester, '29-price-with-discount');
      repo.quoteCompletion = Completer<AdQuote>();
      tester.widget<Slider>(key('duration-slider')).onChanged!(2);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AdPriceDetails), findsNothing);
      repo.quoteCompletion!.completeError(
        const AdSubmissionFailure('SERVER_REJECTED'),
      );
      repo.quoteCompletion = null;
      await tester.pumpAndSettle();
      expect(find.byType(AdPriceDetails), findsNothing);
      expect(key('ad-total'), findsNothing);
      expect(key('coupon-discount'), findsNothing);
      await shot(tester, '30-price-error');
      await tapVisible(
        tester,
        find.descendant(
          of: section('پوختەی نرخ'),
          matching: find.byType(TextButton),
        ),
      );
      expect(
        tester
            .widget<AdPriceDetails>(find.byType(AdPriceDetails))
            .quote
            .totalIqd,
        34000,
      );
      expect(title.text, 'Customer edited title');
      expect(repo.submissions, 0);
      await shot(tester, '31-price-recovered');
    },
  );

  for (final scenario in [
    (320.0, 800.0, 1.0, '19-layout-320'),
    (280.0, 700.0, 1.0, '20-layout-280'),
    (393.0, 852.0, 2.0, '21-large-text-393'),
    (320.0, 800.0, 2.0, '27-large-text-320'),
    (280.0, 700.0, 2.0, '28-large-text-280'),
    (768.0, 1024.0, 1.0, '33-tablet-768'),
  ]) {
    testWidgets(
      '${scenario.$1}px / ${scenario.$3}x cards and controls remain reachable',
      (tester) async {
        view(tester, width: scenario.$1, height: scenario.$2);
        await tester.pumpWidget(
          metaHost(
            AdCreateScreen(repository: StrictRepository()),
            scale: scenario.$3,
          ),
        );
        await tester.pumpAndSettle();
        final card = tester.getRect(section('زانیاری ڕیکلام'));
        expect(card.width, scenario.$1 == 768 ? 600 : scenario.$1 - 40);
        expect(card.left, scenario.$1 == 768 ? 84 : 20);
        expect(find.byType(ProxoBottomNav), findsNothing);
        expect(find.byType(TikTokAdPriceCard), findsNothing);
        assertTextFits(tester);
        await shot(tester, scenario.$4);
        await reveal(tester, 'ad-section-پوختەی نرخ', alignment: .05);
        assertTextFits(tester);
        await shot(tester, '${scenario.$4}-price');
        await reveal(tester, 'review-ad', alignment: .5);
        expect(key('review-ad').hitTestable(), findsOneWidget);
        final body = tester.getRect(key('ad-form-scroll'));
        expect(tester.getCenter(key('review-ad')).dy, greaterThan(body.top));
        expect(tester.getCenter(key('review-ad')).dy, lessThan(body.bottom));
        assertTextFits(tester);
        await shot(tester, '${scenario.$4}-submission');
        measurements[scenario.$4] = {
          'width': scenario.$1,
          'height': scenario.$2,
          'text_scale': scenario.$3,
          'information_card': rect(card),
          'price_card': rect(tester.getRect(section('پوختەی نرخ'))),
          'submission_reachable': true,
        };
      },
    );
  }
}
