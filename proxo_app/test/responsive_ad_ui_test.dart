import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/l10n/ad_detail_strings.dart';
import 'package:proxo_app/screens/ad_confirmation_screen.dart';
import 'package:proxo_app/screens/ad_create_screen.dart';
import 'package:proxo_app/services/ad_submission.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/widgets/ad_form_components.dart';
import 'package:proxo_app/widgets/receipt/receipt_kit.dart';
import 'ad_creation_flow_test.dart'
    show TestAdRepository, AdPaintBinding, capture, capturePng;
import 'ad_submission_test.dart' show validDraft;
import 'ad_receipt_data_test.dart' show receiptFixture;
import 'receipt_layout_test.dart' show receiptHost;
import 'tx_history_layout_test.dart' show historyHost, firstCardKey;

Widget responsiveHost(
  Widget child,
  double scale,
  EdgeInsets padding, {
  double keyboard = 0,
}) => MaterialApp(
  theme: buildAppTheme(),
  builder:
      (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          padding: padding,
          viewPadding: padding,
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: child!,
      ),
  home: RepaintBoundary(key: capture, child: child),
);

void expectVisibleTextFits(WidgetTester tester) {
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  for (final element in find.byType(RichText).evaluate()) {
    final paragraph = element.renderObject;
    if (paragraph is! RenderParagraph || !paragraph.attached) continue;
    final rect = paragraph.localToGlobal(Offset.zero) & paragraph.size;
    if (!rect.overlaps(Offset.zero & size)) continue;
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: 'Clipped text: ${paragraph.text.toPlainText()}',
    );
    final fullHeight = TextPainter(
      text: paragraph.text,
      textDirection: paragraph.textDirection,
      textScaler: paragraph.textScaler,
    )..layout(maxWidth: paragraph.size.width);
    expect(
      fullHeight.height,
      lessThanOrEqualTo(paragraph.size.height + 1),
      reason: 'Text height clipped: ${paragraph.text.toPlainText()}',
    );
    fullHeight.dispose();
  }
}

void main() {
  AdPaintBinding();
  setUpAll(() async {
    await (FontLoader('Rabar')
      ..addFont(rootBundle.load('assets/fonts/Rabar_021.ttf'))).load();
    await (FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  const scenarios = [
    (Size(240, 480), 1.0, 1.0, EdgeInsets.zero),
    (Size(240, 568), 3.0, 2.0, EdgeInsets.only(top: 24, bottom: 16)),
    (Size(320, 568), 2.0, 2.0, EdgeInsets.only(top: 24, bottom: 16)),
    (Size(393, 852), 3.0, 3.0, EdgeInsets.only(top: 44, bottom: 34)),
    (Size(600, 960), 2.0, 1.5, EdgeInsets.only(top: 24, bottom: 20)),
    (Size(768, 1024), 1.0, 2.0, EdgeInsets.only(top: 24, bottom: 20)),
    (Size(1024, 600), 2.0, 2.0, EdgeInsets.only(left: 36, right: 24)),
    (Size(1280, 800), 1.0, 1.0, EdgeInsets.zero),
    (
      Size(640, 320),
      2.0,
      3.0,
      EdgeInsets.only(left: 44, right: 20, bottom: 16),
    ),
  ];
  for (final (size, scale, density, padding) in scenarios) {
    testWidgets('create fits $size, text $scale, density $density', (
      tester,
    ) async {
      tester.view.devicePixelRatio = density;
      tester.view.physicalSize = size * density;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = TestAdRepository();
      repo.assets[0]['name'] = 'پەڕەی پەیوەندی بۆ کڕیارەکانی کوردستان ABC-123';
      final draft = validDraft(goal: 'messages', asset: 'contact-1');
      await tester.pumpWidget(
        responsiveHost(
          AdCreateScreen(repository: repo, proxoCard: draft.toJson()),
          scale,
          padding,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final key in [
        'ad-title',
        'location-all',
        'daily-budget-slider',
        'ad-coupon',
        'review-ad',
      ]) {
        final finder = find.byKey(ValueKey(key));
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$key on $size');
        expectVisibleTextFits(tester);
        final rect = tester.getRect(finder);
        expect(
          rect.left,
          greaterThanOrEqualTo(padding.left),
          reason: '$key in left safe area',
        );
        expect(
          rect.right,
          lessThanOrEqualTo(size.width - padding.right),
          reason: '$key in right safe area',
        );
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('confirmation fits $size, text $scale, density $density', (
      tester,
    ) async {
      tester.view.devicePixelRatio = density;
      tester.view.physicalSize = size * density;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = TestAdRepository();
      final request = AdPendingSubmission.create(
        validDraft(),
        const AdQuote(grossUsd: 10, costUsd: 10, rate: 1800),
      );
      await tester.pumpWidget(
        responsiveHost(
          AdConfirmationScreen(request: request, repository: repo),
          scale,
          padding,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expectVisibleTextFits(tester);
      final ring = tester.getSize(find.byType(CircularProgressIndicator));
      expect(
        ring.width,
        closeTo(ring.height, 0.01),
        reason: 'The countdown stays circular',
      );
      final cancel = find.byKey(const ValueKey('cancel-submission'));
      final rect = tester.getRect(cancel);
      expect(rect.bottom, lessThanOrEqualTo(size.height - padding.bottom));
      expect(rect.left, greaterThanOrEqualTo(padding.left));
      expect(rect.right, lessThanOrEqualTo(size.width - padding.right));
      expect(rect.width, lessThanOrEqualTo(600));
      await tester.tap(cancel);
      await tester.pump();
      expect(repo.submissions, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('history and receipt fit $size at text $scale', (tester) async {
      tester.view.devicePixelRatio = density;
      tester.view.physicalSize = size * density;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        historyHost(scale: scale, padding: padding, amount: '-999,999,999 د.ع'),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expectVisibleTextFits(tester);
      final historyCard = tester.getRect(find.byKey(firstCardKey));
      expect(historyCard.left, greaterThanOrEqualTo(padding.left));
      expect(historyCard.right, lessThanOrEqualTo(size.width - padding.right));
      final data = receiptFixture();
      await tester.pumpWidget(
        receiptHost(
          strings: AdDetailStrings.of(const Locale('ckb')),
          data: data,
          scale: scale,
          padding: padding,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final receipt = tester.getRect(find.byType(ReceiptSurface));
      expect(receipt.left, greaterThanOrEqualTo(padding.left));
      expect(receipt.right, lessThanOrEqualTo(size.width - padding.right));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('long contact menu stays readable and selectable at large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = TestAdRepository();
    const name = 'پەڕەی پەیوەندی بۆ کڕیارەکانی کوردستان ABC-123';
    repo.assets[0]['name'] = name;
    await tester.pumpWidget(
      responsiveHost(
        AdCreateScreen(
          repository: repo,
          proxoCard: validDraft(goal: 'messages').toJson(),
        ),
        3,
        const EdgeInsets.only(top: 24, bottom: 16),
      ),
    );
    await tester.pumpAndSettle();
    final menu = find.byType(DropdownButtonFormField<String>).first;
    await tester.ensureVisible(menu);
    await tester.pumpAndSettle();
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expectVisibleTextFits(tester);
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<DropdownButtonFormField<String>>(menu).initialValue,
      'contact-1',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('keyboard and orientation changes preserve the editable draft', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = TestAdRepository();
    final form = AdCreateScreen(repository: repo);
    await tester.pumpWidget(responsiveHost(form, 2, EdgeInsets.zero));
    await tester.pumpAndSettle();
    final title = find.byKey(const ValueKey('ad-title'));
    await tester.ensureVisible(title);
    await tester.enterText(title, 'ڕیکلام ABC-123');
    await tester.pumpWidget(
      responsiveHost(form, 2, EdgeInsets.zero, keyboard: 300),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(title);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getRect(title).bottom, lessThanOrEqualTo(852 - 300));
    tester.view.physicalSize = const Size(640, 320);
    await tester.pumpWidget(
      responsiveHost(
        form,
        2,
        const EdgeInsets.only(left: 44, right: 20),
        keyboard: 160,
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(title);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getRect(title).left, greaterThanOrEqualTo(44));
    expect(tester.widget<TextField>(title).controller!.text, 'ڕیکلام ABC-123');
    await tester.pumpWidget(
      responsiveHost(form, 2, const EdgeInsets.only(left: 44, right: 20)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('daily-budget-slider')),
    );
    await tester.pumpAndSettle();
    expectVisibleTextFits(tester);
    expect(tester.widget<TextField>(title).controller!.text, 'ڕیکلام ABC-123');
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('retry and cancellation remain reachable in short landscape', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(640, 320);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo =
        TestAdRepository()
          ..failure = const AdSubmissionFailure('INSUFFICIENT_BALANCE');
    final request = AdPendingSubmission.create(
      validDraft(),
      const AdQuote(grossUsd: 10, costUsd: 10, rate: 1800),
    );
    await tester.pumpWidget(
      responsiveHost(
        AdConfirmationScreen(
          request: request,
          repository: repo,
          countdown: const Duration(seconds: 1),
        ),
        3,
        const EdgeInsets.only(left: 44, right: 20, bottom: 16),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expectVisibleTextFits(tester);
    final cancel = find.byKey(const ValueKey('cancel-submission'));
    final retry = find.byKey(const ValueKey('retry-submission'));
    expect(tester.getRect(cancel).bottom, lessThanOrEqualTo(304));
    await tester.ensureVisible(retry);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expectVisibleTextFits(tester);
    expect(tester.getRect(retry).center.dy, greaterThanOrEqualTo(0));
    expect(
      tester.getRect(retry).center.dy,
      lessThan(tester.getRect(cancel).top),
    );
    expect(repo.submissions, 1);
    await tester.tap(cancel);
    await tester.pump();
    expect(repo.submissions, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('render responsive tablet form preview', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(768, 1024);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(responsiveHost(
        AdCreateScreen(repository: TestAdRepository(),
            proxoCard: validDraft(goal: 'messages', asset: 'contact-1').toJson()),
        1, const EdgeInsets.only(top: 24, bottom: 20)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capturePng(tester, 'docs/create_ad_tablet_preview.png');
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('refined fields align and sliders accept drag gestures',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = TestAdRepository();
    await tester.pumpWidget(responsiveHost(AdCreateScreen(repository: repo,
        proxoCard: validDraft().toJson()), 1, EdgeInsets.zero));
    await tester.pumpAndSettle();
    final code = find.byKey(const ValueKey('ad-code'));
    final category = find.byType(DropdownButtonFormField<String>).first;
    expect(tester.getSize(category).height,
        closeTo(tester.getSize(code).height, 1));
    final budget = find.byKey(const ValueKey('daily-budget-slider'));
    await tester.ensureVisible(budget);
    await tester.pumpAndSettle();
    await tester.drag(budget, const Offset(100, 0));
    await tester.pumpAndSettle();
    expect(repo.lastQuoteDraft!.dailyBudget, greaterThan(10));
    final duration = find.byKey(const ValueKey('duration-slider'));
    await tester.ensureVisible(duration);
    await tester.pumpAndSettle();
    await tester.drag(duration, const Offset(90, 0));
    await tester.pumpAndSettle();
    expect(repo.lastQuoteDraft!.days, greaterThan(1));
    final quote = tester.widget<AdPriceDetails>(find.byType(AdPriceDetails)).quote;
    expect(quote.grossUsd,
        repo.lastQuoteDraft!.dailyBudget * repo.lastQuoteDraft!.days);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('render large-text narrow confirmation preview', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(responsiveHost(AdConfirmationScreen(
        request: AdPendingSubmission.create(validDraft(),
            const AdQuote(grossUsd: 10, costUsd: 10, rate: 1800)),
        repository: TestAdRepository()),
        3, const EdgeInsets.only(top: 24, bottom: 16)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expectVisibleTextFits(tester);
    await capturePng(tester, 'docs/ad_confirmation_large_text_preview.png');
    await tester.tap(find.byKey(const ValueKey('cancel-submission')));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
