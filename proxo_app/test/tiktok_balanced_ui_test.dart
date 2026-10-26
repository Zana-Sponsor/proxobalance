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
import 'package:proxo_app/theme/tiktok_ad_tokens.dart';
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
        matching:
            find.byWidgetPredicate((w) => w is ProxoText && w.data == title))
    .first;

Future<void> shot(WidgetTester tester, String name) async {
  expect(tester.takeException(), isNull, reason: name);
  await capturePng(tester, '$evidence/$name.png');
}

// Verify actual rendered pixels against sampled reference colors, including
// modal theme capture. Geometry and state assertions remain independent.
Future<void> paintedColor(WidgetTester tester, String capture, String role,
    Offset logicalPoint, int expectedArgb) async {
  final actualArgb = await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(
        await File('$evidence/$capture.png').readAsBytes());
    final frame = await codec.getNextFrame();
    final bytes = (await frame.image.toByteData())!;
    final x = (logicalPoint.dx * 2).floor();
    final y = (logicalPoint.dy * 2).floor();
    final offset = (y * frame.image.width + x) * 4;
    final argb = (bytes.getUint8(offset + 3) << 24) |
        (bytes.getUint8(offset) << 16) |
        (bytes.getUint8(offset + 1) << 8) |
        bytes.getUint8(offset + 2);
    (measurements.putIfAbsent('painted_colors', () => <Object?>[]) as List)
        .add({
      'capture': capture,
      'role': role,
      'x_px': x,
      'y_px': y,
      'argb': argb.toRadixString(16).toUpperCase()
    });
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
    expect(paragraph.didExceedMaxLines, isFalse,
        reason: paragraph.text.toPlainText());
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
  tearDownAll(() => File('$evidence/measurements.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(measurements)));

  testWidgets('393px measured section rhythm and new full-screen evidence',
      (tester) async {
    view(tester);
    final repo = StrictRepository();
    await tester.pumpWidget(metaHost(
        AdCreateScreen(repository: repo, tiktokRepository: accountsFixture())));
    await tester.pumpAndSettle();
    await shot(tester, '01-top-create-ad');
    final plusRect = tester.getRect(key('bottom-nav-2'));
    await paintedColor(tester, '01-top-create-ad', 'navigation create button',
        plusRect.center + const Offset(18, -12), 0xFF0278FE);

    final gaps = <String, double>{};
    void gap(String name, Finder before, Finder after, double expected) {
      final measured =
          tester.getRect(after).top - tester.getRect(before).bottom;
      gaps[name] = measured;
      expect(measured, closeTo(expected, .01), reason: name);
    }

    gap('ad type → name', section('جۆری ڕیکلام'), key('ad-field-title'), 32);
    gap('name → code', key('ad-field-title'), key('ad-field-code'), 32);
    for (final entry in [
      ('title', 'ناوی ڕیکلام'),
      ('code', 'کۆدی ڤیدیۆ'),
      ('link', 'بەستەری ڤیدیۆ')
    ]) {
      gap('${entry.$1} label → input', key('ad-label-${entry.$2}'),
          key('ad-${entry.$1}'), 16);
    }
    gap('code → helper', key('ad-field-code'), key('ad-code-help'), 8);
    gap('helper → link', key('ad-code-help'), key('ad-field-link'), 32);
    gap('link → helper', key('ad-field-link'), key('ad-link-help'), 8);
    gap('helper → optional note', key('ad-link-help'),
        key('ad-note-disclosure'), 32);
    gap('media → audience', key('ad-media'), key('ad-label-شوێن'), 32);
    gap('location heading → controls', key('ad-label-شوێن'),
        key('ad-choices-location'), 16);
    gap('location → age', key('ad-choices-location'), key('ad-label-تەمەن'),
        32);
    gap('age heading → controls', key('ad-label-تەمەن'), key('ad-choices-age'),
        16);
    gap('age → gender', key('ad-choices-age'), key('ad-label-ڕەگەز'), 32);
    gap('gender heading → controls', key('ad-label-ڕەگەز'),
        key('ad-choices-gender'), 16);
    gap('audience → budget', key('ad-audience'),
        section('بودجە و ماوەی ڕیکلام'), 32);
    gap('budget → schedule', section('بودجە و ماوەی ڕیکلام'),
        section('بەروار و کاتی دەستپێک'), 32);
    gap('schedule → coupon', section('بەروار و کاتی دەستپێک'),
        section('کۆدی داشکاندن'), 32);
    gap('coupon → forecast', section('کۆدی داشکاندن'),
        section('پێشبینی ئەنجام'), 32);
    gap('forecast → payment', section('پێشبینی ئەنجام'),
        section('شێوازەکانی پارەدان'), 32);
    gap('payment heading → card', heading('شێوازەکانی پارەدان'),
        key('selected-payment-card'), 16);
    gap('payment → Sponsor', key('selected-payment-card'), key('review-ad'),
        32);
    gap('ad type heading → controls', heading('جۆری ڕیکلام'),
        key('ad-choices-goal'), 16);

    for (final id in [
      'goal-contact',
      'goal-views',
      'goal-restaurant',
      'goal-app_download',
      'age-all',
      'age-18-24',
      'age-55+',
      'gender-female',
      'location-all'
    ]) {
      expect(tester.getSize(key(id)).height, 50, reason: id);
    }
    final titleField = tester.getRect(key('ad-title'));
    expect(titleField.left, 20);
    expect(titleField.width, 353);
    expect(titleField.height, inInclusiveRange(52, 56));
    expect(
        tester.widget<TextField>(key('ad-title')).style, TikTokAdTokens.field);
    final titleStyle =
        tester.widget<ReceiptAppBar>(find.byType(ReceiptAppBar)).titleStyle!;
    final sectionStyle =
        tester.widget<ProxoText>(heading('جۆری ڕیکلام')).style!;
    expect(titleStyle, TikTokAdTokens.appBar);
    expect(sectionStyle, TikTokAdTokens.heading);
    expect(find.text('جۆری پۆل'), findsNothing);
    expect(find.text('جۆری ئامێر'), findsNothing);
    expect(find.text('بینینی وردەکاری'), findsNothing);
    expect(find.byType(TikTokAdPriceCard), findsOneWidget);
    expect(
        find.descendant(of: key('sticky-ad-price'), matching: key('review-ad')),
        findsNothing);

    final collapsed = tester.getRect(key('sticky-ad-price'));
    final nav = tester.getRect(find.byType(ProxoBottomNav));
    // The restored design uses a flush price bar with 20dp content gutters.
    expect(collapsed.left, 0);
    expect(collapsed.width, 393);
    expect(collapsed.height, 64);
    expect(nav.top - collapsed.bottom, 0);
    final surface = tester.widget<Container>(key('sticky-ad-price'));
    expect(
        (surface.decoration! as BoxDecoration).borderRadius, BorderRadius.zero);
    expect(tester.getRect(key('sticky-price-total')).left, 20);
    expect(tester.getRect(key('sticky-price-label')).right, 373);
    measurements['393px'] = {
      'screen': {'width': 393, 'height': 852, 'text_scale': 1},
      'gaps_dp': gaps,
      'input': rect(titleField),
      'objective_button': rect(tester.getRect(key('goal-contact'))),
      'price_collapsed': rect(collapsed),
      'bottom_navigation': rect(nav),
      'price_navigation_gap_dp': nav.top - collapsed.bottom,
      'typography': {
        'family': sectionStyle.fontFamily,
        'app_bar_sp': titleStyle.fontSize,
        'app_bar_weight': titleStyle.fontWeight!.value,
        'heading_sp': sectionStyle.fontSize,
        'heading_weight': sectionStyle.fontWeight!.value,
        'input_label_sp': TikTokAdTokens.label.fontSize,
        'input_label_weight': 500,
        'field_sp': TikTokAdTokens.field.fontSize,
        'field_weight': 400,
        'choice_sp': TikTokAdTokens.choice.fontSize,
        'choice_weight': 500,
        'helper_sp': TikTokAdTokens.helper.fontSize,
        'helper_weight': 400,
        'price_row_label_sp': 13,
        'price_row_amount_sp': 14,
        'price_total_label_sp': 15,
        'price_total_amount_sp': 16,
      },
      'button_radius_dp': 12,
      'input_radius_dp': 12,
      'input_horizontal_padding_dp': 16,
      'price_radius_dp':
          ((surface.decoration! as BoxDecoration).borderRadius! as BorderRadius)
              .topLeft
              .x,
    };

    await tapVisible(tester, key('goal-views'));
    await reveal(tester, 'ad-section-جۆری ڕیکلام', alignment: 0);
    await shot(tester, '02-ad-types');
    final primaryRect = tester.getRect(key('goal-views'));
    await paintedColor(tester, '02-ad-types', 'primary fill',
        Offset(primaryRect.center.dx, primaryRect.top + 6), 0xFF0278FE);
    await reveal(tester, 'ad-field-title', alignment: .1);
    await shot(tester, '03-ad-name');
    await reveal(tester, 'ad-media', alignment: .05);
    await shot(tester, '04-media');

    await tapVisible(tester, key('goal-contact'));
    gap('name → destination', key('ad-field-title'),
        section('شوێنی پەیوەندیکردن'), 32);
    gap('destination → page', section('شوێنی پەیوەندیکردن'),
        section('پەڕەی پەیوەندی'), 32);
    gap('page heading → disclosure', heading('پەڕەی پەیوەندی'),
        key('contact-page-disclosure'), 16);
    gap('page → media', section('پەڕەی پەیوەندی'), key('ad-media'), 32);
    await reveal(tester, 'ad-section-شوێنی پەیوەندیکردن', alignment: .05);
    await shot(tester, '05-contact-destination');
    final destinationRect =
        tester.getRect(key('contact-destination-external_contact'));
    await paintedColor(tester, '05-contact-destination', 'secondary fill',
        Offset(destinationRect.center.dx, destinationRect.top + 8), 0xFFEEF7FF);
    final pageRect = tester.getRect(key('contact-page-disclosure'));
    await paintedColor(tester, '05-contact-destination', 'contact page fill',
        Offset(pageRect.center.dx, pageRect.top + 8), 0xFFF6F9FE);
    final badgeRect = tester.getRect(key('tiktok-new-badge'));
    await paintedColor(tester, '05-contact-destination', 'new badge',
        badgeRect.topLeft + const Offset(12, 3), 0xFFFE6F61);
    await reveal(tester, 'ad-section-پەڕەی پەیوەندی', alignment: .05);
    await shot(tester, '06-contact-page-collapsed');
    await tapVisible(tester, key('contact-page-disclosure'));
    await tester.runAsync(() => precacheImage(
        const AssetImage('assets/images/proxo_logo.png'),
        tester.element(key('contact-page-disclosure'))));
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
    await reveal(tester, 'ad-section-شێوازەکانی پارەدان', alignment: .05);
    await shot(tester, '12-payment');
    await tapVisible(tester, key('change-payment'));
    await tester.runAsync(() => precacheImage(
        const AssetImage('assets/logos/providers/fastpay.png'),
        tester.element(key('payment-method-sheet'))));
    await tester.pumpAndSettle();
    await shot(tester, '34-payment-sheet-wallet');
    final walletRect = tester.getRect(key('payment-app_balance'));
    await paintedColor(tester, '34-payment-sheet-wallet', 'modal selected fill',
        Offset(walletRect.center.dx, walletRect.top + 8), 0xFFEEF7FF);
    final confirmRect = tester.getRect(key('confirm-payment'));
    await paintedColor(tester, '34-payment-sheet-wallet', 'modal confirm fill',
        Offset(confirmRect.center.dx, confirmRect.top + 8), 0xFF0278FE);
    await tapVisible(tester, key('payment-fastpay'));
    await tester.pumpAndSettle();
    await shot(tester, '35-payment-sheet-fastpay');
    final fastPayRect = tester.getRect(key('payment-fastpay'));
    await paintedColor(
        tester,
        '35-payment-sheet-fastpay',
        'modal FastPay selected fill',
        Offset(fastPayRect.center.dx, fastPayRect.top + 8),
        0xFFEEF7FF);
    // Closing without confirming must retain the original payment method.
    Navigator.of(tester.element(key('payment-method-sheet'))).pop();
    await tester.pumpAndSettle();
    await reveal(tester, 'review-ad', alignment: .4);
    expect(tester.getRect(key('review-ad')).bottom, lessThan(collapsed.top));
    await shot(tester, '13-separate-sponsor');
    await shot(tester, '14-price-collapsed');
    final headerBefore = tester.getRect(key('sticky-price-header'));
    await tester.tap(key('sticky-price-disclosure'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getRect(find.byType(ProxoBottomNav)), nav);
    expect(tester.getRect(key('sticky-ad-price')).bottom, collapsed.bottom);
    await tester.pumpAndSettle();
    final expanded = tester.getRect(key('sticky-ad-price'));
    expect(expanded.top, lessThan(collapsed.top));
    expect(tester.getRect(key('sticky-price-header')), headerBefore);
    expect(tester.getRect(key('price-value-unit')).left,
        closeTo(tester.getRect(key('sticky-price-total')).left, .01));
    expect(tester.getRect(key('price-value-fee')).left,
        closeTo(tester.getRect(key('price-value-unit')).left, .01));
    await shot(tester, '15-price-expanded');
    measurements['393px_expanded_price'] = rect(expanded);

    repo.quoteCompletion = Completer<AdQuote>();
    tester.widget<Slider>(key('duration-slider')).onChanged!(3);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getRect(key('sticky-ad-price')), expanded);
    expect(tester.getRect(key('sticky-price-header')), headerBefore);
    expect(key('sticky-price-total'), findsNothing);
    expect(
        tester
            .widget<TikTokAdPriceCard>(find.byType(TikTokAdPriceCard))
            .expanded,
        isTrue);
    expect(tester.widget<AdPriceDetails>(find.byType(AdPriceDetails)).loading,
        isTrue);
    await tester.pump(const Duration(milliseconds: 300));
    await shot(tester, '23-price-expanded-loading');
    expect(tester.getRect(key('sticky-price-loading')).left, 20);
    // Loading must not disable the full-row expand/collapse interaction.
    await tester.tap(key('sticky-price-label'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(key('sticky-price-details'), findsNothing);
    expect(tester.getRect(find.byType(ProxoBottomNav)), nav);
    await tester.tap(key('sticky-price-label'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.getRect(key('sticky-ad-price')), expanded);
    repo.quoteCompletion!.complete(
        const AdQuote(grossUsd: 30, costUsd: 30, rate: 1800, balanceUsd: 1000));
    repo.quoteCompletion = null;
    await tester.pumpAndSettle();
    await tester.tap(key('sticky-price-disclosure'));
    await tester.pumpAndSettle();
    final nextCollapsed = tester.getRect(key('sticky-ad-price'));
    repo.quoteCompletion = Completer<AdQuote>();
    tester.widget<Slider>(key('duration-slider')).onChanged!(2);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getRect(key('sticky-ad-price')), nextCollapsed);
    expect(key('sticky-price-total'), findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
    await shot(tester, '16-price-loading');
    repo.quoteCompletion!.complete(
        const AdQuote(grossUsd: 20, costUsd: 20, rate: 1800, balanceUsd: 1000));
    repo.quoteCompletion = null;
    await tester.pumpAndSettle();
    await tester.drag(key('ad-form-scroll'), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(tester.getRect(key('sticky-ad-price')), nextCollapsed);
    expect(tester.getRect(find.byType(ProxoBottomNav)), nav);
    await shot(tester, '17-scroll-behind-price');
    await shot(tester, '18-price-and-bottom-navigation');

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
              : '25-app-resources');
    }
    await tapVisible(tester, key('goal-contact'));
    await tapVisible(tester, key('contact-destination-direct_message'));
    expect(key('ad-code'), findsNothing);
    expect(
        tester
            .widgetList<AdFormSection>(find.byType(AdFormSection))
            .every((s) => s.style == AdSectionStyle.open),
        isTrue);
    await reveal(tester, 'ad-section-شوێنی پەیوەندیکردن', alignment: .05);
    await shot(tester, '26-direct-message-open-sections');
    await tester.tap(key('sticky-price-disclosure'));
    await tester.pumpAndSettle();
    expect(find.byType(AdPriceDetails), findsNothing,
        reason:
            'A missing authoritative DM quote must not expose cached amounts');
    expect(tester.widget<ProxoText>(key('sticky-price-total')).data, '—');
    expect(repo.submissions, 0);
    await tester.tap(key('sticky-price-disclosure'));
    await tester.pumpAndSettle();
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
      'discount and quote-error recovery keep one anchored price surface',
      (tester) async {
    view(tester);
    final repo = StrictRepository();
    await tester.pumpWidget(metaHost(AdCreateScreen(repository: repo)));
    await tester.pumpAndSettle();
    final title = tester.widget<TextField>(key('ad-title')).controller!;
    title.text = 'Customer edited title';
    await tester.pumpAndSettle();
    final nav = tester.getRect(find.byType(ProxoBottomNav));
    final header = tester.getRect(key('sticky-price-header'));
    await tester.tap(key('sticky-price-label'));
    await tester.pumpAndSettle();
    expect(key('sticky-price-details'), findsOneWidget);
    await tester.ensureVisible(key('ad-coupon'));
    await tester.enterText(key('ad-coupon'), 'VALID');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('بەکارهێنانی کۆد'));
    await reveal(tester, 'review-ad', alignment: .1);
    expect(key('coupon-discount'), findsOneWidget);
    expect(find.text('−2,000 د.ع'), findsOneWidget);
    expect(tester.getRect(key('price-value-discount')).left,
        tester.getRect(key('price-value-unit')).left);
    expect(tester.getRect(key('sticky-price-header')), header);
    await shot(tester, '29-price-with-discount');

    repo.quoteCompletion = Completer<AdQuote>();
    tester.widget<Slider>(key('duration-slider')).onChanged!(2);
    await tester.pump(const Duration(milliseconds: 400));
    repo.quoteCompletion!
        .completeError(const AdSubmissionFailure('SERVER_REJECTED'));
    repo.quoteCompletion = null;
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TikTokAdPriceCard>(find.byType(TikTokAdPriceCard))
            .expanded,
        isTrue);
    expect(tester.widget<ProxoText>(key('sticky-price-total')).data, '—');
    expect(key('coupon-discount'), findsNothing);
    expect(tester.getRect(key('sticky-price-header')), header);
    await shot(tester, '30-price-error');
    await tester.tap(find.descendant(
        of: key('sticky-ad-price'), matching: find.byType(TextButton)));
    await tester.pumpAndSettle();
    expect(
        tester.widget<TikTokAdPriceCard>(find.byType(TikTokAdPriceCard)).error,
        isNull);
    expect(
        tester
            .widget<AdPriceDetails>(find.byType(AdPriceDetails))
            .quote
            .totalIqd,
        34000);
    expect(tester.getRect(find.byType(ProxoBottomNav)), nav);
    expect(title.text, 'Customer edited title');
    expect(repo.submissions, 0);
    await shot(tester, '31-price-recovered');
  });

  for (final scenario in [
    (320.0, 800.0, 1.0, '19-layout-320'),
    (280.0, 700.0, 1.0, '20-layout-280'),
    (393.0, 852.0, 2.0, '21-large-text-393'),
    (320.0, 800.0, 2.0, '27-large-text-320'),
    (280.0, 700.0, 2.0, '28-large-text-280'),
    (768.0, 1024.0, 1.0, '33-tablet-768'),
  ]) {
    testWidgets(
        '${scenario.$1}px / ${scenario.$3}x responsive layout and anchored price',
        (tester) async {
      view(tester, width: scenario.$1, height: scenario.$2);
      await tester.pumpWidget(metaHost(
          AdCreateScreen(repository: StrictRepository()),
          scale: scenario.$3));
      await tester.pumpAndSettle();
      final card = tester.getRect(key('sticky-ad-price'));
      final nav = tester.getRect(find.byType(ProxoBottomNav));
      expect(card.left, 0);
      expect(card.width, scenario.$1);
      expect(nav.top - card.bottom, 0);
      if (scenario.$3 == 1) expect(card.height, 64);
      if (scenario.$1 == 768) {
        expect(tester.getRect(key('sticky-price-total')).left, 84);
        expect(tester.getRect(key('sticky-price-label')).right, 684);
      }
      assertTextFits(tester);
      await shot(tester, scenario.$4);
      await reveal(tester, 'ad-section-شێوازەکانی پارەدان', alignment: .05);
      await tester.tap(key('sticky-price-disclosure'));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(ProxoBottomNav)), nav);
      expect(tester.getRect(key('sticky-ad-price')).bottom, card.bottom);
      assertTextFits(tester);
      await reveal(tester, 'review-ad', alignment: 0);
      expect(tester.getRect(key('review-ad')).bottom,
          lessThan(tester.getRect(key('sticky-ad-price')).top));
      expect(key('review-ad').hitTestable(), findsOneWidget);
      await shot(tester, '${scenario.$4}-expanded');
      for (final id in ['price-label-unit', 'price-label-fee']) {
        final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: key(id), matching: find.byType(RichText)));
        expect(paragraph.getMinIntrinsicWidth(double.infinity),
            lessThanOrEqualTo(paragraph.size.width + 1));
      }
      if (scenario.$1 == 280 && scenario.$3 == 2) {
        final before = tester.getRect(key('sticky-price-header'));
        await tester.drag(key('sticky-price-details'), const Offset(0, -200));
        await tester.pumpAndSettle();
        expect(tester.getRect(key('sticky-price-header')), before);
        final details = tester.getRect(key('sticky-price-details'));
        expect(tester.getRect(key('price-value-fee')).bottom,
            lessThanOrEqualTo(details.bottom));
        await shot(tester, '32-narrow-price-details-scrolled');
      }
      measurements[scenario.$4] = {
        'width': scenario.$1,
        'height': scenario.$2,
        'text_scale': scenario.$3,
        'price_collapsed': rect(card),
        'price_expanded': rect(tester.getRect(key('sticky-ad-price'))),
        'navigation_gap_dp': nav.top - card.bottom,
        'sponsor_visible_above_price': true,
      };
    });
  }
}
