import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/models/proxo_card.dart';
import 'package:proxo_app/models/proxolink_page_type.dart';
import 'package:proxo_app/screens/ad_create_screen.dart';
import 'package:proxo_app/screens/ad_confirmation_screen.dart';
import 'package:proxo_app/screens/proxolink_create_page_screen.dart';
import 'package:proxo_app/services/ad_submission.dart';
import 'package:proxo_app/widgets/ad_form_components.dart';
import 'package:proxo_app/widgets/ad_brand_logo.dart';
import 'package:proxo_app/widgets/bottom_nav.dart';
import 'package:proxo_app/widgets/receipt/receipt_kit.dart';

import 'ad_creation_flow_test.dart' show AdPaintBinding, tapVisible, capturePng;
import 'ad_submission_test.dart' show validDraft;
import 'meta_ad_form_test.dart' show metaHost;
import 'tiktok_dm_form_test.dart' show TikTokFormRepository, accountsFixture;
import 'proxolink_tools_create_test.dart' show ToolsRepository, field;
import 'proxolink_page_management_test.dart' show page;

const evidence = '../docs/evidence/tiktok-strict-v3-2026-10-25';

class AvatarClient extends Fake implements HttpClient {
  AvatarClient(this.bytes);
  final List<int> bytes;
  int requests = 0;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    expect(url.host, 'fixture.invalid');
    requests++;
    return AvatarRequest(bytes);
  }
}

class AvatarRequest extends Fake implements HttpClientRequest {
  AvatarRequest(this.bytes);
  final List<int> bytes;
  @override
  final HttpHeaders headers = AvatarHeaders();
  @override
  Future<HttpClientResponse> close() async => AvatarResponse(bytes);
}

class AvatarHeaders extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class AvatarResponse extends Fake implements HttpClientResponse {
  AvatarResponse(this.bytes);
  final List<int> bytes;
  @override
  int get statusCode => HttpStatus.ok;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.value(bytes).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
}

class DelayedStrictRepository extends StrictRepository {
  bool delay = false;
  final requests = <Completer<AdQuote>>[];
  @override
  Future<AdQuote> quote(AdDraft draft) {
    if (!delay) return super.quote(draft);
    lastQuoteDraft = draft;
    final request = Completer<AdQuote>();
    requests.add(request);
    return request.future;
  }
}

class StrictRepository extends TikTokFormRepository {
  StrictRepository() {
    assets = [
      {
        ...page(1, name: 'پەڕەی پەیوەندی Proxo').toJson(),
        'platforms': {'wa': '9647501234567', 'ig': 'proxo_fixture'},
      },
      page(2, name: 'خواردنگەی Proxo', type: 'order').toJson(),
      page(3, name: 'ئەپی Proxo', type: 'download').toJson(),
    ];
  }
}

Future<void> shot(WidgetTester tester, String name) async {
  expect(tester.takeException(), isNull, reason: name);
  await capturePng(tester, '$evidence/$name.png');
}

void view(WidgetTester tester, {double width = 393, double height = 852}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> reveal(
  WidgetTester tester,
  String key, {
  double alignment = .2,
}) async {
  await Scrollable.ensureVisible(
    tester.element(find.byKey(ValueKey(key))),
    alignment: alignment,
  );
  await tester.pumpAndSettle();
}

Future<void> type(WidgetTester tester, String value) async {
  await tapVisible(tester, find.byKey(ValueKey('goal-$value')));
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

  testWidgets(
    'strict hierarchy, four types, filtered accordion and stable authoritative total',
    (tester) async {
      view(tester);
      final repo = StrictRepository();
      await tester.pumpWidget(
        metaHost(
          AdCreateScreen(repository: repo, tiktokRepository: accountsFixture()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ئامانجی ڕیکلام'), findsNothing);
      expect(find.text('جۆری پۆل'), findsNothing);
      expect(find.text('جۆری ئامێر'), findsNothing);
      expect(find.text('بینینی وردەکاری'), findsNothing);
      expect(find.byType(ProxoBottomNav), findsOneWidget);
      final title = tester
          .widget<TextField>(find.byKey(const ValueKey('ad-title')))
          .controller!;
      expect(title.text, matches(RegExp(r'^New Ad \d{2}-\d{2}-\d{4}$')));
      final sections = tester.widgetList<AdFormSection>(
        find.byType(AdFormSection),
      );
      expect(sections.every((s) => s.style == AdSectionStyle.open), isTrue);
      await shot(tester, '01-main');
      await shot(tester, '02-four-ad-types');
      await shot(tester, '07-primary-inactive');
      title.text = 'ناوی دەستکاریکراوی Proxo';
      await type(tester, 'contact');
      await reveal(tester, 'goal-contact', alignment: .05);
      await shot(tester, '03-contact-active');
      expect(title.text, 'ناوی دەستکاریکراوی Proxo');
      await reveal(tester, 'contact-destination-external_contact');
      await shot(tester, '10-contact-destinations');
      await shot(tester, '12-all-platforms-active');
      await shot(tester, '13-tiktok-message-inactive');
      await reveal(tester, 'contact-page-disclosure');
      await shot(tester, '15-page-collapsed');
      await tapVisible(
        tester,
        find.byKey(const ValueKey('contact-page-disclosure')),
      );
      expect(
        find.byKey(ValueKey('contact-page-${page(1).id}')),
        findsOneWidget,
      );
      expect(find.byKey(ValueKey('contact-page-${page(2).id}')), findsNothing);
      expect(find.byKey(ValueKey('contact-page-${page(3).id}')), findsNothing);
      await reveal(tester, 'contact-page-disclosure', alignment: .05);
      await tester.runAsync(() => precacheImage(
          const AssetImage('assets/images/proxo_logo.png'),
          tester.element(find.byKey(const ValueKey('contact-page-disclosure')))));
      await tester.pumpAndSettle();
      await shot(tester, '16-page-expanded');
      await shot(tester, '18-contact-only-pages');
      final avatar =
          AvatarClient(File('assets/images/proxo_logo.png').readAsBytesSync());
      debugNetworkImageHttpClientProvider = () => avatar;
      try {
        const avatarUrl = 'https://fixture.invalid/contact/avatar.png';
        repo.assets.first['avatar_url'] = avatarUrl;
        await tester.runAsync(() => precacheImage(
            const NetworkImage(avatarUrl),
            tester.element(
                find.byKey(const ValueKey('contact-page-disclosure')))));
        await tapVisible(
            tester, find.byKey(const ValueKey('contact-page-disclosure')));
        await tapVisible(
            tester, find.byKey(const ValueKey('contact-page-disclosure')));
        await reveal(tester, 'contact-page-disclosure', alignment: .05);
        final rowImage = find.descendant(
            of: find.byKey(ValueKey('contact-page-${page(1).id}')),
            matching: find.byType(RawImage));
        expect(tester.widget<RawImage>(rowImage).image, isNotNull);
        expect(avatar.requests, 1);
        await shot(tester, '17-page-image-name-status');
      } finally {
        debugNetworkImageHttpClientProvider = null;
      }
      await tapVisible(
        tester,
        find.byKey(ValueKey('contact-page-${page(1).id}')),
      );
      await tapVisible(
        tester,
        find.byKey(const ValueKey('contact-page-disclosure')),
      );
      expect(repo.lastQuoteDraft!.assetId, page(1).id);
      await tapVisible(
        tester,
        find.byKey(const ValueKey('contact-page-disclosure')),
      );
      expect(repo.lastQuoteDraft!.assetId, page(1).id);
      await tapVisible(
        tester,
        find.byKey(const ValueKey('contact-page-disclosure')),
      );
      await reveal(tester, 'contact-destination-external_contact');
      final brands = tester
          .widgetList<AdBrandLogo>(
            find.descendant(
              of: find.byKey(
                const ValueKey('contact-destination-external_contact'),
              ),
              matching: find.byType(AdBrandLogo),
            ),
          )
          .map((logo) => logo.brand);
      expect(brands, containsAll(['whatsapp', 'instagram']));
      await shot(tester, '12-all-platforms-active');
      await tapVisible(
        tester,
        find.byKey(const ValueKey('contact-destination-direct_message')),
      );
      await reveal(tester, 'contact-destination-direct_message');
      await shot(tester, '11-all-platforms-inactive');
      await shot(tester, '14-tiktok-message-active');
      expect(
        find.byKey(const ValueKey('contact-page-disclosure')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('ad-code')), findsNothing);
      await type(tester, 'views');
      await reveal(tester, 'goal-views', alignment: .05);
      await shot(tester, '04-views-active');
      await reveal(tester, 'ad-code', alignment: .1);
      await shot(tester, '21-views-content');
      expect(
        find.byKey(const ValueKey('contact-page-disclosure')),
        findsNothing,
      );
      await type(tester, 'restaurant');
      await reveal(tester, 'goal-restaurant', alignment: .05);
      await shot(tester, '05-restaurant-active');
      await tapVisible(
        tester,
        find.byKey(const ValueKey('contact-page-disclosure')),
      );
      await reveal(tester, 'contact-page-disclosure', alignment: .05);
      expect(
        find.byKey(ValueKey('contact-page-${page(2).id}')),
        findsOneWidget,
      );
      expect(find.byKey(ValueKey('contact-page-${page(1).id}')), findsNothing);
      expect(find.byKey(ValueKey('contact-page-${page(3).id}')), findsNothing);
      await shot(tester, '19-restaurant-only-pages');
      await type(tester, 'app_download');
      await reveal(tester, 'goal-app_download', alignment: .05);
      await shot(tester, '06-app-download-active');
      await tapVisible(
        tester,
        find.byKey(const ValueKey('contact-page-disclosure')),
      );
      await reveal(tester, 'contact-page-disclosure', alignment: .05);
      expect(
        find.byKey(ValueKey('contact-page-${page(3).id}')),
        findsOneWidget,
      );
      expect(find.byKey(ValueKey('contact-page-${page(1).id}')), findsNothing);
      expect(find.byKey(ValueKey('contact-page-${page(2).id}')), findsNothing);
      await shot(tester, '20-app-download-only-pages');
      await tapVisible(tester, find.byKey(const ValueKey('age-18-24')));
      await reveal(tester, 'age-18-24');
      await shot(tester, '08-age-active');
      await tapVisible(tester, find.byKey(const ValueKey('gender-female')));
      await reveal(tester, 'gender-female');
      await shot(tester, '09-gender-active');
      final nav = tester.getRect(find.byType(ProxoBottomNav));
      final collapsed = tester.getRect(
        find.byKey(const ValueKey('sticky-ad-price')),
      );
      expect(collapsed.bottom, lessThanOrEqualTo(nav.top));
      await shot(tester, '22-total-collapsed');
      await tester.tap(find.byKey(const ValueKey('sticky-price-disclosure')));
      await tester.pumpAndSettle();
      final expanded = tester.getRect(
        find.byKey(const ValueKey('sticky-ad-price')),
      );
      expect(tester.getRect(find.byType(ProxoBottomNav)), nav);
      expect(expanded.bottom, collapsed.bottom);
      expect(expanded.top, lessThan(collapsed.top));
      await shot(tester, '23-total-expanded');
      await tester.tap(find.byKey(const ValueKey('sticky-price-disclosure')));
      await tester.pumpAndSettle();
      repo.quoteCompletion = Completer<AdQuote>();
      tester
          .widget<Slider>(find.byKey(const ValueKey('duration-slider')))
          .onChanged!(3);
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.byKey(const ValueKey('sticky-price-loading')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('sticky-price-total')), findsNothing);
      await shot(tester, '24-total-loading');
      repo.quoteCompletion!.complete(
        const AdQuote(grossUsd: 30, costUsd: 30, rate: 1800, balanceUsd: 1000),
      );
      repo.quoteCompletion = null;
      await tester.pumpAndSettle();
      await reveal(tester, 'review-ad', alignment: .4);
      await shot(tester, '25-scrolled-sticky-total');
      await shot(tester, '26-separate-sponsor');
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('sticky-ad-price')),
          matching: find.byKey(const ValueKey('review-ad')),
        ),
        findsNothing,
      );
      expect(tester.getRect(find.byType(ProxoBottomNav)), nav);
    },
  );

  testWidgets(
    'out-of-order authoritative quotes cannot replace the newest total',
    (tester) async {
      view(tester);
      final repo = DelayedStrictRepository();
      await tester.pumpWidget(metaHost(AdCreateScreen(repository: repo)));
      await tester.pumpAndSettle();
      repo.delay = true;
      tester
          .widget<Slider>(find.byKey(const ValueKey('duration-slider')))
          .onChanged!(2);
      await tester.pump(const Duration(milliseconds: 200));
      tester
          .widget<Slider>(find.byKey(const ValueKey('duration-slider')))
          .onChanged!(3);
      await tester.pump(const Duration(milliseconds: 200));
      expect(repo.requests.length, 2);
      expect(find.byKey(const ValueKey('sticky-price-total')), findsNothing);
      repo.requests[1].complete(
        const AdQuote(grossUsd: 30, costUsd: 30, rate: 1800, balanceUsd: 1000),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sticky-price-disclosure')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AdPriceDetails>(find.byType(AdPriceDetails))
            .quote
            .totalIqd,
        54000,
      );
      repo.requests[0].complete(
        const AdQuote(grossUsd: 20, costUsd: 20, rate: 1800, balanceUsd: 1000),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AdPriceDetails>(find.byType(AdPriceDetails))
            .quote
            .totalIqd,
        54000,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'expanded price preserves visible total at 300 percent text with keyboard',
    (tester) async {
      view(tester, width: 280, height: 700);
      for (final keyboard in [0.0, 240.0]) {
        await tester.pumpWidget(
          metaHost(
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(viewInsets: EdgeInsets.only(bottom: keyboard)),
                child: AdCreateScreen(
                  key: ValueKey(keyboard),
                  repository: StrictRepository(),
                ),
              ),
            ),
            scale: 3,
          ),
        );
        await tester.pumpAndSettle();
        final toggle = find.byKey(const ValueKey('sticky-price-disclosure'));
        final total = find.byKey(const ValueKey('sticky-price-total'));
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        final panel = tester.getRect(
          find.byKey(const ValueKey('sticky-ad-price')),
        );
        final totalRect = tester.getRect(total);
        final toggleRect = tester.getRect(toggle);
        expect(totalRect.top, greaterThanOrEqualTo(panel.top));
        expect(totalRect.bottom, lessThanOrEqualTo(panel.bottom));
        expect(toggleRect.top, greaterThanOrEqualTo(panel.top));
        expect(toggleRect.bottom, lessThanOrEqualTo(panel.bottom));
        expect(
          panel.bottom,
          lessThanOrEqualTo(tester.getRect(find.byType(ProxoBottomNav)).top),
        );
        expect(tester.takeException(), isNull, reason: 'keyboard=$keyboard');
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        await reveal(tester, 'review-ad', alignment: 0);
        final body =
            tester.getRect(find.byKey(const ValueKey('ad-form-scroll')));
        final price =
            tester.getRect(find.byKey(const ValueKey('sticky-ad-price')));
        final exposed = Offset(12, body.top + (price.top - body.top) / 2);
        expect(exposed.dy, greaterThan(body.top));
        expect(exposed.dy, lessThan(price.top));
        await tester.dragFrom(exposed, const Offset(0, -40));
        await tester.pumpAndSettle();
        final sponsor = find.byKey(const ValueKey('review-ad'));
        for (var attempt = 0; attempt < 8; attempt++) {
          final current = tester.getRect(sponsor);
          if (current.center.dy > body.top && current.center.dy < price.top && sponsor.hitTestable().evaluate().isNotEmpty) break;
          final delta = (exposed.dy - current.center.dy).clamp(-120.0, 120.0);
          await tester.dragFrom(exposed, Offset(0, delta));
          await tester.pumpAndSettle();
        }
        expect(tester.getCenter(sponsor).dy, greaterThan(body.top));
        final priceTop =
            tester.getRect(find.byKey(const ValueKey('sticky-ad-price'))).top;
        expect(tester.getCenter(sponsor).dy, lessThan(priceTop));
        expect(sponsor.hitTestable(), findsOneWidget);
        await tester.tap(sponsor);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(AdConfirmationScreen), findsNothing);
        expect(tester.takeException(), isNull,
            reason: 'reachable sponsor keyboard=$keyboard');
      }
    },
  );

  testWidgets(
    'direct page creation returns to the same form on back and success',
    (tester) async {
      view(tester);
      final repo = StrictRepository()..assets = [];
      final pages = ToolsRepository([]);
      Future<Map<String, dynamic>?> create(BuildContext context) async {
        final result = await Navigator.of(context).push<ProxoCard>(
          MaterialPageRoute(
            builder: (_) => ProxoLinkCreatePageScreen(
              repository: pages,
              initialType: ProxoPageType.contact,
              lockType: true,
            ),
          ),
        );
        if (result != null) repo.assets = [result.toJson()];
        return result?.toJson();
      }

      await tester.pumpWidget(
        metaHost(AdCreateScreen(repository: repo, createContactPage: create)),
      );
      await tester.pumpAndSettle();
      await type(tester, 'contact');
      final title = tester
          .widget<TextField>(find.byKey(const ValueKey('ad-title')))
          .controller!;
      title.text = 'Draft kept on return';
      await tapVisible(
        tester,
        find.byKey(const ValueKey('contact-page-disclosure')),
      );
      await reveal(tester, 'contact-page-disclosure', alignment: .05);
      expect(find.byKey(const ValueKey('no-contact-page')), findsOneWidget);
      await shot(tester, '27-no-page');
      await tapVisible(
        tester,
        find.byKey(const ValueKey('create-contact-page')),
      );
      expect(find.byType(ProxoLinkCreatePageScreen), findsOneWidget);
      await shot(tester, '28-direct-create-page');
      tester.widget<ReceiptAppBar>(find.byType(ReceiptAppBar).last).onBack!();
      await tester.pumpAndSettle();
      expect(find.byType(AdCreateScreen), findsOneWidget);
      expect(title.text, 'Draft kept on return');
      await shot(tester, '29-back-to-preserved-ad');
      await tapVisible(
        tester,
        find.byKey(const ValueKey('create-contact-page')),
      );
      await tester.ensureVisible(field('ناوی پەڕە'));
      await tester.enterText(field('ناوی پەڕە'), 'پەڕەی نوێی Proxo');
      await tester.ensureVisible(field('telegram'));
      await tester.enterText(field('telegram'), 'proxo_fixture');
      await tapVisible(
        tester,
        find.byKey(const ValueKey('create-page-submit')),
      );
      await tester.pumpAndSettle();
      expect(pages.saves, 1);
      expect(find.byType(ProxoLinkCreatePageScreen), findsNothing);
      expect(title.text, 'Draft kept on return');
      await reveal(tester, 'contact-page-disclosure', alignment: .05);
      expect(find.text('پەڕەی نوێی Proxo'), findsWidgets);
      await shot(tester, '30-new-page-visible');
    },
  );

  testWidgets(
    'definite failed submission never auto-resends on clean route reopen',
    (tester) async {
      view(tester);
      final repo = StrictRepository()
        ..failure = const AdSubmissionFailure('INVALID_VIDEO_LINK');
      var opens = 0;
      await tester.pumpWidget(
        metaHost(
          Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AdCreateScreen(
                        repository: repo,
                        proxoCard: opens++ == 0 ? validDraft().toJson() : null,
                      ),
                    ),
                  );
                },
                child: const Text('Open create ad'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open create ad'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const ValueKey('review-ad')));
      await tester.pump(const Duration(seconds: 11));
      await tester.pumpAndSettle();
      expect(repo.submissions, 1);
      expect(find.byType(AdConfirmationScreen), findsOneWidget);
      await shot(tester, '31-definitive-failure');
      await tester.tap(find.byKey(const ValueKey('cancel-submission')));
      await tester.pumpAndSettle();
      tester.widget<ReceiptAppBar>(find.byType(ReceiptAppBar).last).onBack!();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open create ad'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('resume-pending-ad')), findsNothing);
      expect(repo.saved, isNull);
      expect(repo.submissions, 1);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('ad-title')))
            .controller!
            .text,
        matches(RegExp(r'^New Ad \d{2}-\d{2}-\d{4}$')),
      );
      await shot(tester, '32-fresh-after-failure');
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      expect(repo.submissions, 1);
    },
  );

  testWidgets(
    'small screen keeps four types, navigation and validation usable',
    (tester) async {
      view(tester, width: 280, height: 700);
      final repo = StrictRepository();
      await tester.pumpWidget(
        metaHost(AdCreateScreen(repository: repo), scale: 2),
      );
      await tester.pumpAndSettle();
      await shot(tester, '33-small-screen-280-2x');
      for (final value in ['contact', 'restaurant', 'app_download', 'views']) {
        await type(tester, value);
        expect(tester.takeException(), isNull);
      }
      await tapVisible(tester, find.byKey(const ValueKey('review-ad')));
      expect(repo.submissions, 0);
      expect(find.byType(AdConfirmationScreen), findsNothing);
      await shot(tester, '34-validation-error');
    },
  );
}
