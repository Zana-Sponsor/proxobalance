import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/screens/ad_create_screen.dart';
import 'package:proxo_app/services/tiktok_dm_accounts.dart';
import 'package:proxo_app/widgets/ad_form_components.dart';
import 'package:proxo_app/widgets/tiktok_dm_account_picker.dart';
import 'package:proxo_app/widgets/receipt/receipt_kit.dart';
import 'ad_creation_flow_test.dart'
    show AdPaintBinding, TestAdRepository, tapVisible, capturePng;
import 'meta_ad_form_test.dart' show metaHost;
import 'tiktok_dm_accounts_test.dart' show FakeTikTokDmRepository;

class TikTokFormRepository extends TestAdRepository {
  bool enabled = true, seen = false;
  int seenWrites = 0;
  @override
  Future<DateTime?> serverTime() async => DateTime.utc(2030, 1, 15, 9, 30);
  @override
  Future<bool> tiktokDmAvailable() async => enabled;
  @override
  Future<bool> tiktokDmSeen() async => seen;
  @override
  Future<void> markTikTokDmSeen() async {
    seenWrites++;
    seen = true;
  }
}

FakeTikTokDmRepository accountsFixture() => FakeTikTokDmRepository()
  ..connected = const [
    TikTokDmAccount(
        id: 'fixture-account',
        username: 'fixture_shop',
        displayName: 'هەژماری تاقیکردنەوە',
        dmReady: true)
  ]
  ..loadVideos = ((accountId) async => TikTokDmVideoPage([
        TikTokDmVideo(
            accountId: accountId,
            itemId: 'fixture-public',
            caption: 'ڤیدیۆی تاقیکردنەوە',
            permalink: 'https://www.tiktok.com/@fixture_shop/video/123',
            isPublic: true,
            eligible: true),
        TikTokDmVideo(
            accountId: accountId,
            itemId: 'fixture-private',
            caption: 'Private fixture',
            isPublic: false,
            eligible: true),
      ]));

Future<void> enterDirect(WidgetTester tester) async {
  await tapVisible(tester, find.byKey(const ValueKey('goal-contact')));
  await tapVisible(
      tester, find.byKey(const ValueKey('contact-destination-direct_message')));
}

Finder assetSelector() => find.byKey(const ValueKey('contact-page-disclosure'));

void main() {
  AdPaintBinding();
  setUpAll(() async {
    await (FontLoader('Rabar')
          ..addFont(rootBundle.load('assets/fonts/Rabar_021.ttf')))
        .load();
    await (FontLoader(ReceiptTokens.fontFamily)
          ..addFont(rootBundle.load(ReceiptTokens.fontAsset)))
        .load();
    await (FontLoader('RabarAuthRegular')
          ..addFont(rootBundle.load('assets/fonts/Rabar_022.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    Directory('docs/meta_ads_evidence').createSync(recursive: true);
  });
  setUp(() => clearTikTokDmCache('owner-one'));

  testWidgets(
      'four ad types keep Direct Message inside contact and preserve legacy media',
      (tester) async {
    final repository = TikTokFormRepository();
    await tester.pumpWidget(metaHost(AdCreateScreen(
        repository: repository, tiktokRepository: accountsFixture())));
    await tester.pumpAndSettle();
    final sections =
        tester.widgetList<AdFormSection>(find.byType(AdFormSection)).toList();
    expect(sections[0].title, 'جۆری ڕیکلام');
    expect(find.text('ناوی ڕیکلام'), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const ValueKey('ad-title'))).dy,
        greaterThan(tester.getBottomLeft(find.byKey(const ValueKey('goal-app_download'))).dy));
    final goals = find.byWidgetPredicate((w) =>
        w is AdChoice &&
        w.key is ValueKey &&
        (w.key as ValueKey).value.toString().startsWith('goal-'));
    expect(goals, findsNWidgets(4));
    expect(find.byKey(const ValueKey('goal-direct_message')), findsNothing);
    expect(find.byKey(const ValueKey('contact-destination-direct_message')),
        findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('ad-title')));
    await tester.enterText(
        find.byKey(const ValueKey('ad-title')), 'Preserved title');
    await tester.ensureVisible(find.byKey(const ValueKey('ad-code')));
    await tester.enterText(find.byKey(const ValueKey('ad-code')), 'CODE-123');
    await tester.ensureVisible(find.byKey(const ValueKey('ad-link')));
    await tester.enterText(find.byKey(const ValueKey('ad-link')),
        'https://www.tiktok.com/@example/video/456');
    await tapVisible(tester, find.byKey(const ValueKey('goal-contact')));
    expect(assetSelector(), findsOneWidget);
    expect(find.text('نوێ'), findsOneWidget);
    await tapVisible(tester,
        find.byKey(const ValueKey('contact-destination-direct_message')));
    expect(find.byKey(const ValueKey('ad-code')), findsNothing);
    expect(find.byKey(const ValueKey('ad-link')), findsNothing);
    expect(assetSelector(), findsNothing);
    expect(find.byType(TikTokDmAccountPicker), findsOneWidget);
    expect(find.text('پێشبینی بەردەست نییە'), findsOneWidget);
    expect(find.text('پێشبینی کرتەکان'), findsNothing);
    expect(find.text('نوێ'), findsNothing);
    expect(repository.seenWrites, 1);
    await tapVisible(tester, find.byKey(const ValueKey('goal-views')));
    expect(find.byType(TikTokDmAccountPicker), findsNothing);
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('ad-code')))
            .controller!
            .text,
        'CODE-123');
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('ad-link')))
            .controller!
            .text,
        'https://www.tiktok.com/@example/video/456');
    await tapVisible(tester, find.byKey(const ValueKey('goal-contact')));
    await tapVisible(tester,
        find.byKey(const ValueKey('contact-destination-external_contact')));
    expect(assetSelector(), findsOneWidget);
    expect(find.byType(TikTokDmAccountPicker), findsNothing);
    expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('ad-title')))
            .controller!
            .text,
        'Preserved title');
    expect(tester.takeException(), isNull);
  });

  testWidgets('fresh account and public video selection bind the current quote',
      (tester) async {
    final repository = TikTokFormRepository();
    await tester.pumpWidget(metaHost(AdCreateScreen(
        repository: repository, tiktokRepository: accountsFixture())));
    await tester.pumpAndSettle();
    await enterDirect(tester);
    expect(find.byKey(const ValueKey('tiktok-video-fixture-private')),
        findsNothing);
    await tapVisible(
        tester, find.byKey(const ValueKey('tiktok-video-fixture-public')));
    final draft = repository.lastQuoteDraft!;
    expect(draft.isTikTokDirect, isTrue);
    expect(draft.tiktokAccountId, 'fixture-account');
    expect(draft.tiktokItemId, 'fixture-public');
    expect(draft.tiktokUsername, 'fixture_shop');
    expect(draft.paymentMethod, 'app_balance');
    await tapVisible(tester, find.byKey(const ValueKey('goal-views')));
    expect(repository.lastQuoteDraft!.isTikTokDirect, isFalse);
    expect(repository.lastQuoteDraft!.tiktokAccountId, isNull);
    expect(repository.lastQuoteDraft!.tiktokItemId, isNull);
  });

  testWidgets(
      'disabled server capability never opens a selectable account flow',
      (tester) async {
    await tester.pumpWidget(metaHost(AdCreateScreen(
        repository: TikTokFormRepository()..enabled = false,
        tiktokRepository: accountsFixture())));
    await tester.pumpAndSettle();
    await enterDirect(tester);
    expect(find.byType(TikTokDmAccountPicker), findsNothing);
    expect(find.text('نامەی ڕاستەوخۆ ئێستا بەردەست نییە'), findsWidgets);
  });

  for (final width in [280.0, 393.0, 768.0]) {
    testWidgets('Direct Message form fits $width at 200 percent text',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 852);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(metaHost(
          AdCreateScreen(
              repository: TikTokFormRepository(),
              tiktokRepository: accountsFixture()),
          scale: 2));
      await tester.pumpAndSettle();
      await enterDirect(tester);
      expect(tester.takeException(), isNull);
      final messages = find.byKey(const ValueKey('goal-contact'));
      final views = find.byKey(const ValueKey('goal-views'));
      expect(tester.getSize(messages), tester.getSize(views));
      await Scrollable.ensureVisible(tester.element(messages), alignment: .1);
      await tester.pumpAndSettle();
      await capturePng(tester,
          'docs/meta_ads_evidence/tiktok_direct_form_${width.toInt()}_2x.png');
      final account =
          find.byKey(const ValueKey('tiktok-account-fixture-account'));
      await Scrollable.ensureVisible(tester.element(account), alignment: .1);
      await tester.pumpAndSettle();
      expect(tester.getSize(account),
          tester.getSize(find.byKey(const ValueKey('tiktok-add-account'))));
      expect(tester.takeException(), isNull);
      await capturePng(tester,
          'docs/meta_ads_evidence/tiktok_direct_accounts_${width.toInt()}_2x.png');
      await tapVisible(
          tester, find.byKey(const ValueKey('tiktok-video-fixture-public')));
      await tester.ensureVisible(find.byKey(const ValueKey('review-ad')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
