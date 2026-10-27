import 'package:proxo_app/services/app_update_service.dart';
import 'package:proxo_app/widgets/app_update_host.dart';
import '../test/app_update_service_test.dart' show policy;
// Production widgets in an Android profile build, with fictional backend data.
// No real account, payment, message, credential or external page is used.
import 'dart:async';
import 'dart:convert';
import 'dart:ui' show FrameTiming;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/screens/account_setup_screen.dart';
import 'package:proxo_app/screens/ad_confirmation_screen.dart';
import 'package:proxo_app/screens/ad_create_screen.dart';
import 'package:proxo_app/screens/ad_detail_screen.dart';
import 'package:proxo_app/screens/ad_screen.dart';
import 'package:proxo_app/screens/auth/auth_shell.dart';
import 'package:proxo_app/screens/auth/new_password_screen.dart';
import 'package:proxo_app/screens/auth/otp_screen.dart';
import 'package:proxo_app/screens/best_metrics_screen.dart';
import 'package:proxo_app/screens/card_webview_screen.dart';
import 'package:proxo_app/screens/deposit_screen.dart';
import 'package:proxo_app/screens/faq_screen.dart';
import 'package:proxo_app/screens/home_screen.dart';
import 'package:proxo_app/screens/notifications_screen.dart';
import 'package:proxo_app/screens/profile_screen.dart';
import 'package:proxo_app/screens/proxolink_create_page_screen.dart';
import 'package:proxo_app/screens/proxolink_page_details_screen.dart';
import 'package:proxo_app/screens/proxolink_page_editor_screen.dart';
import 'package:proxo_app/screens/splash_screen.dart';
import 'package:proxo_app/screens/tools_screen.dart';
import 'package:proxo_app/screens/transaction_detail_screen.dart';
import 'package:proxo_app/screens/tutorial_screen.dart';
import 'package:proxo_app/screens/whatsapp_marketing_screen.dart';
import 'package:proxo_app/services/account_setup_service.dart';
import 'package:proxo_app/services/ad_snapshot_cache.dart';
import 'package:proxo_app/services/ad_submission.dart';
import 'package:proxo_app/services/proxolink_service.dart';
import 'package:proxo_app/theme/app_locale.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/widgets/ad_form_components.dart';
import 'package:proxo_app/widgets/auth/auth_design.dart';
import 'package:proxo_app/widgets/auth/auth_otp_field.dart';
import 'package:proxo_app/widgets/auth/auth_widgets.dart';
import 'package:proxo_app/widgets/levels_page.dart';
import 'package:proxo_app/widgets/proxo_refresh.dart';
import 'package:proxo_app/widgets/proxo_notice.dart';
import 'package:proxo_app/widgets/proxo_sidebar.dart';
import 'package:proxo_app/widgets/proxo_drawer_navigation.dart';
import 'package:proxo_app/widgets/tasks_page.dart';
import '../test/ad_creation_flow_test.dart' show TestAdRepository;
import '../test/ad_receipt_data_test.dart' show receiptFixture;
import '../test/ad_submission_test.dart' show validDraft;
import '../test/home_sections_test.dart' show examples;
import '../test/proxolink_page_management_test.dart' show page;
import '../test/proxolink_tools_create_test.dart' show ToolsRepository;
import 'support/actual_screen_fixtures.dart';

const native = MethodChannel('proxo/polish-fixture');
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'profile screen, control, motion and background-notification evidence',
      (t) async {
    expect(kProfileMode, isTrue,
        reason: 'Performance measurements require profile mode');
    SharedPreferences.setMockInitialValues({});
    final backend = ActualScreenBackend();
    await backend.initialize();
    backend.includeNotifications = true;
    backend.readResponses['pa_featured_ads_public'] = [
      for (final ad in examples())
        {
          'id': ad.id,
          'goal': ad.goal,
          'category': ad.category,
          'clicks': ad.clicks,
          'impressions': ad.impressions,
          'spend': ad.spendUsd,
          'daily_budget': ad.dailyBudgetUsd,
          'days': ad.days,
          'service_budget_usd': ad.serviceBudgetUsd,
          'featured_sort': ad.sortOrder,
        },
    ];
    backend.readResponses['whatsapp_marketing_preferences'] = {
      'opted_in': false
    };
    addTearDown(backend.dispose);
    ProxoLocale.current.value = ProxoLocale.kurdishSorani;
    final observations = <String, Object?>{
      'environment':
          'Android emulator, profile AOT, software GPU; not physical-device certification',
      'fixture_only': true,
      'completed': false,
      'network_latency_measured': false,
      'physical_size': [t.view.physicalSize.width, t.view.physicalSize.height],
      'dpr': t.view.devicePixelRatio,
      'screens': <String, Object?>{},
    };
    binding.reportData = {'observations': observations};
    print('PROXO_POLISH_PERMISSION_READY');
    for (var i = 0;
        i < 100 && !await ph.Permission.notification.isGranted;
        i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(await ph.Permission.notification.isGranted, isTrue);

    Future<void> settle({bool continuous = false}) async {
      if (continuous) {
        // The confirmation countdown intentionally ticks for an hour in this
        // read-only fixture. Observe it without waiting for a real submission.
        for (var frame = 0; frame < 24; frame++) {
          await t.pump(const Duration(milliseconds: 16));
        }
      } else {
        await t.pumpAndSettle(const Duration(milliseconds: 16),
            EnginePhase.sendSemanticsUpdate, const Duration(seconds: 8));
      }
    }

    Future<void> mount(Widget widget, {bool continuous = false}) async {
      await t.pumpWidget(MaterialApp(
        key: UniqueKey(),
        theme: buildAppTheme(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate
        ],
        builder: (context, child) => ProxoLocaleScope(child: child!),
        home: widget,
      ));
      await settle(continuous: continuous);
      expect(t.takeException(), isNull);
    }

    Future<void> capture(String name) async {
      await t.pump();
      final result = await native
          .invokeMapMethod<String, dynamic>('capture', {'name': '$name.png'});
      expect(result?['status'], 0, reason: 'Android PixelCopy $name');
    }

    Future<void> checkpoint() async {
      await native.invokeMethod<void>('checkpoint', {
        'json': const JsonEncoder.withIndent('  ').convert(binding.reportData),
      }).timeout(const Duration(seconds: 5));
    }

    Future<void> measureFrames(
        String name, Future<void> Function() action) async {
      // Read the engine's actual frame timings directly. watchPerformance also
      // connects to VM Service for GC counts; flutter drive may advertise its
      // host-forwarded port to the Android process, where it is unreachable.
      await Future<void>.delayed(const Duration(seconds: 2));
      final frames = <FrameTiming>[];
      void collect(List<FrameTiming> timings) => frames.addAll(timings);
      SchedulerBinding.instance.addTimingsCallback(collect);
      try {
        await action();
        await t.pump();
        // Profile-mode frame timing callbacks are batched by the engine.
        await Future<void>.delayed(const Duration(seconds: 2));
      } finally {
        SchedulerBinding.instance.removeTimingsCallback(collect);
      }
      expect(frames, isNotEmpty, reason: 'Engine frame timings for $name');
      binding.reportData!['frames_$name'] =
          FrameTimingSummarizer(frames).summary;
      await checkpoint();
    }

    Future<void> record(String name, Widget widget,
        {Future<void> Function()? action}) async {
      final row = <String, Object?>{};
      final continuous = widget is AdConfirmationScreen;
      row['continuous_animation_fixture'] = continuous;
      (observations['screens'] as Map<String, Object?>)[name] = row;
      await measureFrames(name, () async {
        final clock = Stopwatch()..start();
        await mount(widget, continuous: continuous);
        row['mount_and_settle_ms'] = clock.elapsedMilliseconds;
        if (action != null) await action();
        // Real scrolling/animation work, rather than timing a static screenshot.
        final scrolls = find.byWidgetPredicate((widget) =>
            widget is Scrollable &&
            axisDirectionToAxis(widget.axisDirection) == Axis.vertical);
        if (find.byType(Dialog).evaluate().isEmpty &&
            scrolls.evaluate().isNotEmpty) {
          final state = t.state<ScrollableState>(scrolls.first);
          if (state.position.maxScrollExtent > 0) {
            await t.drag(scrolls.first, const Offset(0, -250));
            await settle(continuous: continuous);
            await t.drag(scrolls.first, const Offset(0, 250));
            await settle(continuous: continuous);
          }
        }
      });
      final controls = <Map<String, Object?>>[];
      for (final element in find
          .byWidgetPredicate(
              (w) => w is ButtonStyleButton || w is IconButton || w is InkWell)
          .evaluate()) {
        final box = element.findRenderObject();
        if (box is! RenderBox || !box.hasSize) continue;
        final w = element.widget;
        final enabled = w is ButtonStyleButton
            ? w.onPressed != null
            : w is IconButton
                ? w.onPressed != null
                : w is InkWell && w.onTap != null;
        controls.add({
          'type': w.runtimeType.toString(),
          'key': w.key?.toString(),
          'enabled': enabled,
          'width_dp': box.size.width,
          'height_dp': box.size.height
        });
      }
      row['mounted_controls'] = controls;
      row['exception'] = t.takeException()?.toString();
      expect(row['exception'], isNull, reason: name);
      await capture(name);
      print('PROXO_POLISH_SCREEN $name');
    }

    Future<void> tapLabel(String label) async {
      final target = find.text(label).first;
      await t.ensureVisible(target);
      await settle();
      await t.tap(target);
      await settle();
    }

    Future<void> reveal(Finder target, Finder scrollable) async {
      // ListView children below the cache extent have no Element yet.
      // Scroll the intended outer list until mounted before ensuring visibility.
      await t.scrollUntilVisible(target, 220, scrollable: scrollable);
      await t.ensureVisible(target);
      await settle();
    }

    Finder depositScroll() => find
        .descendant(
            of: find.byKey(const ValueKey('deposit-scroll')),
            matching: find.byType(Scrollable))
        .first;

    final code = TextEditingController(), focus = FocusNode();
    final password = TextEditingController(),
        confirmation = TextEditingController();
    final showPassword = ValueNotifier(false),
        showConfirmation = ValueNotifier(false);
    final request = AdPendingSubmission.create(
        validDraft(), const AdQuote(grossUsd: 10, costUsd: 10, rate: 1800));
    final screens = <String, Widget>{
      'splash': const Scaffold(body: SplashArtwork()),
      'home': HomeScreen(
          onCreateTap: () {},
          onAddBalanceTap: () {},
          onToolsTap: () {},
          onCreatePageTap: () {},
          onFaqTap: () {}),
      'ads': const AdScreen(),
      'ad-create': AdCreateScreen(repository: TestAdRepository()),
      'ad-confirmation': AdConfirmationScreen(
          request: request,
          repository: TestAdRepository(),
          countdown: const Duration(hours: 1)),
      'ad-details': AdDetailScreen(
          adId: receiptFixture()['id'] as String,
          initialAd: receiptFixture(),
          loadAd: (_) async => receiptFixture()),
      'tools': ToolsScreen(repository: ActualToolsRepository()),
      'tools-empty': ToolsScreen(repository: ToolsRepository([])),
      'page-create': ProxoLinkCreatePageScreen(repository: ToolsRepository([])),
      'page-details': ProxoLinkPageDetailsScreen(
          initialPage: page(1), repository: ToolsRepository([page(1)])),
      'page-edit': ProxoLinkPageEditorScreen(
          existing: page(1), repository: ToolsRepository([page(1)])),
      'profile': const ProfileScreen(),
      'profile-edit': const EditProfileScreen(
          initialFullName: 'تاقیکردنەوە',
          initialEmail: 'fixture@example.invalid',
          initialPhone: '+9647500000000'),
      'deposit': const DepositScreen(),
      'transaction': TransactionDetailScreen(
          data: TxReceiptData(
              kind: TxReceiptKind.topUp,
              status: 'approved',
              txId: '75e3a228-4a4c-4d1e-a6c4-f705ecba349e',
              uid: 'fixture',
              date: DateTime.utc(2026, 10, 18),
              usd: 10,
              amountIqd: 18000,
              balanceBefore: null,
              balanceAfter: null,
              method: 'fastpay',
              gateway: 'fastpay',
              type: 'deposit',
              adName: null,
              voucherCode: null)),
      'notifications': const NotificationsScreen(),
      'faq': const FaqScreen(),
      'tutorial': const TutorialScreen(),
      'results': BestMetricsScreen(
          initialAds: examples(),
          loadResults: ({bool forceRefresh = false}) async => examples()),
      'levels': const LevelsPage(),
      'tasks': const TasksPage(),
      'vouchers': const VoucherPage(),
      'discounts': const DiscountCodesPage(),
      'sidebar': const Scaffold(body: ProxoSidebar()),
      'whatsapp-preferences': const WhatsappMarketingScreen(),
      'account-setup-error': AccountSetupView(
          phase: AccountSetupPhase.verifying,
          failed: true,
          onRetry: () async {}),
      'web-preview-error': CardWebViewScreen(
          title: 'پێشبینین',
          loadUrl: () async => throw const ProxoLinkFailure('network_error')),
      'new-password': Scaffold(
          body: SafeArea(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: NewPasswordScreen(
                      onBack: () {},
                      password: password,
                      confirmation: confirmation,
                      passwordVisible: showPassword,
                      confirmationVisible: showConfirmation,
                      onSave: () async {})))),
      'otp': Scaffold(
          body: SafeArea(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: OtpScreen(
                      onBack: () {},
                      destination: '+96475***0000',
                      otpBoxes: AuthOtpBoxes(
                          length: 6,
                          codeController: code,
                          firstBoxFocus: focus,
                          onCompleted: (_) {}),
                      resend: AuthTextLink(
                          label: AuthStrings.resendAction, onTap: () {}),
                      verifyButton: AuthPrimaryButton(
                          label: AuthStrings.verifyButton,
                          onPressed: () async {}))))),
    };
    for (final entry in screens.entries) {
      await record(entry.key, entry.value,
          action: entry.key != 'ad-create' ? null : () async {
        final sections = t.widgetList<AdFormSection>(find.byType(AdFormSection));
        expect(sections.first.title, 'زانیاری ڕیکلام');
        expect(sections.every((section) => section.style == AdSectionStyle.card),
            isTrue);
        expect(find.byKey(const ValueKey('sticky-ad-price')), findsNothing);
        expect(find.byKey(const ValueKey('bottom-nav-2')), findsNothing);
        final scroll = find.descendant(
            of: find.byKey(const ValueKey('ad-form-scroll')),
            matching: find.byType(Scrollable)).first;
        final information = find.byKey(const ValueKey('ad-section-زانیاری ڕیکلام'));
        final pricing = find.byKey(const ValueKey('ad-section-پوختەی نرخ'));
        final review = find.byKey(const ValueKey('review-ad'));
        await capture('ad-create-restored-top');
        await reveal(pricing, scroll);
        expect(find.descendant(of: pricing, matching: find.byType(AdPriceDetails)),
            findsOneWidget);
        await capture('ad-create-restored-pricing');
        await reveal(review, scroll);
        expect(review.hitTestable(), findsOneWidget);
        await capture('ad-create-restored-submission');
        observations['create_ad_previous_card_design'] = {
          'visual_baseline': '058f2f6',
          'card_sections': true,
          'in_scroll_pricing': true,
          'submission_reachable': true,
          'fixture_only': true,
        };
        await t.ensureVisible(information);
        await settle();
      });
    }
    for (final required in [false, true]) {
      final service = AppUpdateService(
        preferences: await SharedPreferences.getInstance(),
        fetch: (_, __) async => policy(required: required),
      );
      final name = required ? 'update-required' : 'update-optional';
      await record(
          name,
          AppUpdateHost(
            client: backend.client,
            service: service,
            installedBuild: 10,
            platform: 'android',
            launch: (_) async => false,
            child: HomeScreen(onCreateTap: () {}),
          ));
      expect(
          find.byKey(
              ValueKey(required ? 'required-update' : 'optional-update')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('update-later')),
          required ? findsNothing : findsOneWidget);
      await t.tap(find.byKey(const ValueKey('update-now')));
      await settle();
      expect(find.text('بەستەرەکە نەکرایەوە. تکایە دووبارە هەوڵ بدەرەوە.'),
          findsOneWidget);
      await capture('$name-link-recovery');
      if (!required) {
        await t.tap(find.byKey(const ValueKey('update-later')));
        await settle();
        expect(find.byKey(const ValueKey('optional-update')), findsNothing);
      }
    }
    await mount(const SizedBox.shrink());
    await AdSnapshotCache.clearStoredFor(screenFixtureOwner);
    backend.emptyAds = true;
    await record('ads-empty', const AdScreen(), action: () async {
      final empty = find.byKey(const ValueKey('ads-empty-state'));
      final create = find.byKey(const ValueKey('ads-create-empty'));
      expect(empty, findsOneWidget);
      final scroll =
          find.ancestor(of: empty, matching: find.byType(Scrollable)).first;
      await reveal(create, scroll);
      expect(t.widget<FilledButton>(create).onPressed, isNotNull);
      await capture('ads-empty-action');
    });
    await mount(const SizedBox.shrink());
    backend.emptyAds = false;
    await AdSnapshotCache.clearStoredFor(screenFixtureOwner);
    await record(
        'home-result-summary',
        HomeScreen(
            onCreateTap: () {},
            onAddBalanceTap: () {},
            onToolsTap: () {},
            onCreatePageTap: () {},
            onFaqTap: () {}), action: () async {
      final card = find.byKey(const ValueKey('result-open-beauty'));
      final scroll = find
          .descendant(
              of: find.byType(HomeScreen), matching: find.byType(Scrollable))
          .first;
      await reveal(card, scroll);
      expect(find.byKey(const ValueKey('result-details-beauty')), findsNothing);
      expect(
          find.byKey(const ValueKey('result-expanded-beauty')), findsNothing);
      await capture('home-result-summary');
    });
    await record(
        'results-expansion',
        BestMetricsScreen(
          initialAds: examples(),
          loadResults: ({bool forceRefresh = false}) async => examples(),
        ), action: () async {
      final details = find.byKey(const ValueKey('result-details-beauty'));
      final scroll = find.byType(Scrollable).first;
      await reveal(details, scroll);
      await capture('results-collapsed');
      await t.tap(details);
      await settle();
      final objective =
          t.getRect(find.byKey(const ValueKey('result-objective-beauty')));
      final budget =
          t.getRect(find.byKey(const ValueKey('result-budget-beauty')));
      expect(objective.top, closeTo(budget.top, .01));
      expect(objective.height, closeTo(budget.height, .01));
      expect(objective.left, greaterThan(budget.right));
      expect(
          t
              .getRect(
                  find.byKey(const ValueKey('result-objective-value-beauty')))
              .top,
          closeTo(
              t
                  .getRect(
                      find.byKey(const ValueKey('result-budget-value-beauty')))
                  .top,
              .01));
      await capture('results-expanded');
      for (var i = 0; i < 4; i++) {
        await reveal(details, scroll);
        await t.tap(details);
        await settle();
      }
    });
    // Exercise the actual native Drawer route with the production menu. The
    // host deliberately omits authentication/backend navigation side effects.
    final drawerKey = GlobalKey<ScaffoldState>();
    final menuDestinations = <String>[];
    await record(
        'menu-route-dismissal',
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
              builder: (context) => Scaffold(
                    key: drawerKey,
                    onEndDrawerChanged: (_) =>
                        syncProxoDrawerBackNavigation(context),
                    endDrawer: Directionality(
                      textDirection: TextDirection.rtl,
                      child: ProxoSidebar(
                        onClose: () => drawerKey.currentState!.closeEndDrawer(),
                        onNavigate: (destination) {
                          menuDestinations.add(destination);
                          drawerKey.currentState!.closeEndDrawer();
                        },
                      ),
                    ),
                    body: const SizedBox.expand(),
                  )),
        ), action: () async {
      for (var cycle = 0; cycle < 3; cycle++) {
        drawerKey.currentState!.openEndDrawer();
        await settle();
        expect(drawerKey.currentState!.isEndDrawerOpen, isTrue);
        if (cycle == 0) {
          await capture('menu-open-native');
          final backState = await native
              .invokeMapMethod<String, dynamic>('backState')
              .timeout(const Duration(seconds: 5));
          observations['menu_native_back_registration'] = backState;
          expect(backState?['framework_handles_back'], true,
              reason:
                  'Android must route Back to Flutter while the drawer is open');
          observations['menu_android_back'] = 'awaiting native key event';
          await checkpoint();
          print('PROXO_POLISH_MENU_BACK_READY');
          final backClock = Stopwatch()..start();
          while (drawerKey.currentState!.isEndDrawerOpen &&
              backClock.elapsed < const Duration(seconds: 8)) {
            await t.pump(const Duration(milliseconds: 16));
          }
          expect(drawerKey.currentState!.isEndDrawerOpen, isFalse,
              reason: 'Android Back must dismiss the drawer, not the activity');
          final closedState = await native
              .invokeMapMethod<String, dynamic>('backState')
              .timeout(const Duration(seconds: 5));
          expect(closedState?['activity_finishing'], false);
          expect(closedState?['activity_destroyed'], false);
          observations['menu_native_back_after_dismissal'] = closedState;
          observations['menu_android_back'] = 'dismissed';
          await checkpoint();
          print('PROXO_POLISH_MENU_BACK_DISMISSED');
        } else if (cycle == 1) {
          // The exposed strip is the native scrim on this narrow viewport.
          await t.tapAt(const Offset(8, 300));
        } else {
          await t.tap(find.byKey(const ValueKey('sidebar-close')));
        }
        await settle();
        expect(drawerKey.currentState!.isEndDrawerOpen, isFalse);
      }
      observations['menu_native_dismissal_cycles'] = 3;
      observations['menu_destinations_from_dismissal'] = menuDestinations;
    });

    await record('ad-validation-notice-scroll',
        AdCreateScreen(repository: TestAdRepository()), action: () async {
      final scroll = find
          .descendant(
              of: find.byKey(const ValueKey('ad-form-scroll')),
              matching: find.byType(Scrollable))
          .first;
      await reveal(find.byKey(const ValueKey('review-ad')), scroll);
      await t.tap(find.byKey(const ValueKey('review-ad')));
      await t.pump(const Duration(milliseconds: 16));
      expect(find.byType(ProxoNoticeCard), findsOneWidget);
      final noticeClock = Stopwatch()..start();
      await capture('ad-validation-notice');
      await t.drag(scroll, const Offset(0, 100));
      while (find.byType(ProxoNoticeCard).evaluate().isNotEmpty &&
          noticeClock.elapsed < const Duration(seconds: 3)) {
        await t.pump(const Duration(milliseconds: 16));
      }
      final visibleMs = noticeClock.elapsedMilliseconds;
      expect(find.byType(ProxoNoticeCard), findsNothing);
      // Exact timer boundaries are covered by FakeAsync widget checks; this
      // permits one platform scheduling/frame interval around the real timer.
      expect(visibleMs, inInclusiveRange(1800, 2600));
      observations['ad_validation_notice_observed_ms'] = visibleMs;
      observations['ad_validation_notice_scroll_recovered'] = true;
      await capture('ad-validation-dismissed');
    });

    final failedAdRepository = TestAdRepository()
      ..failure = const AdSubmissionFailure('NETWORK', uncertain: true);
    await record(
        'ad-create-error-recovery',
        AdCreateScreen(
          repository: failedAdRepository,
          proxoCard: validDraft().toJson(),
        ), action: () async {
      Finder adScroll() => find
          .descendant(
              of: find.byKey(const ValueKey('ad-form-scroll')),
              matching: find.byType(Scrollable))
          .first;
      final title = find.byKey(const ValueKey('ad-title'));
      final initialTitle = t.widget<TextField>(title).controller!.text;
      expect(initialTitle, matches(RegExp(r'^New Ad \d{2}-\d{2}-\d{4}$')));
      final review = find.byKey(const ValueKey('review-ad'));
      await reveal(review, adScroll());
      await t.tap(review);
      // A second tap in the same frame must not push another confirmation.
      await t.tap(review, warnIfMissed: false);
      final failureClock = Stopwatch()..start();
      while (failedAdRepository.submissions == 0 &&
          failureClock.elapsed < const Duration(seconds: 15)) {
        await t.pump(const Duration(milliseconds: 50));
      }
      await settle();
      expect(failedAdRepository.submissions, 1);
      expect(find.byType(AdConfirmationScreen), findsOneWidget);
      final savedId = failedAdRepository.saved!.id;
      expect(failedAdRepository.saved!.draft.title, initialTitle);
      await capture('ad-submit-error');
      final cancel = find.byKey(const ValueKey('cancel-submission'));
      await t.ensureVisible(cancel);
      await settle();
      await t.tap(cancel);
      await settle();
      expect(find.byType(AdConfirmationScreen), findsNothing);
      await reveal(title, adScroll());
      expect(t.widget<TextField>(title).enabled, isNot(false));
      expect(t.widget<TextField>(title).controller!.text, initialTitle);
      await capture('ad-error-editable');
      await t.tap(title);
      final titleController = t.widget<TextField>(title).controller!;
      titleController.selection = TextSelection(
          baseOffset: 0, extentOffset: titleController.text.length);
      await t.pump(const Duration(milliseconds: 100));
      print('PROXO_POLISH_AD_INPUT_READY');
      final editClock = Stopwatch()..start();
      while (titleController.text != 'Recovered-ad' &&
          editClock.elapsed < const Duration(seconds: 12)) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(titleController.text, 'Recovered-ad');
      var stableFrames = 0;
      var lastInset = 0.0;
      final keyboardClock = Stopwatch()..start();
      while (stableFrames < 6 &&
          keyboardClock.elapsed < const Duration(seconds: 8)) {
        await t.pump(const Duration(milliseconds: 50));
        final inset = t.view.viewInsets.bottom;
        stableFrames = inset > 0 && inset == lastInset ? stableFrames + 1 : 0;
        lastInset = inset;
      }
      expect(stableFrames, greaterThanOrEqualTo(6));
      final visibleBottom =
          (t.view.physicalSize.height - t.view.viewInsets.bottom) /
              t.view.devicePixelRatio;
      expect(t.getRect(title).bottom, lessThanOrEqualTo(visibleBottom));
      observations['ad_error_keyboard_inset_px'] = t.view.viewInsets.bottom;
      observations['ad_error_title_edit_transport'] = 'Android adb input text';
      print('PROXO_POLISH_AD_KEYBOARD_READY');
      final captureClock = Stopwatch()..start();
      while (captureClock.elapsed < const Duration(seconds: 3)) {
        await t.pump(const Duration(milliseconds: 50));
      }
      FocusManager.instance.primaryFocus?.unfocus();
      await settle();
      final resume = find.byKey(const ValueKey('resume-pending-ad'));
      await reveal(resume, adScroll());
      await t.tap(resume);
      await settle();
      expect(failedAdRepository.submissions, 2);
      expect(failedAdRepository.saved!.id, savedId);
      await t.ensureVisible(cancel);
      await settle();
      await t.tap(cancel);
      await settle();
      await reveal(title, adScroll());
      expect(titleController.text, 'Recovered-ad');
      observations['ad_error_recovery'] = {
        'submissions': failedAdRepository.submissions,
        'same_pending_id': failedAdRepository.saved!.id == savedId,
        'edited_title_retained': true,
        'navigation_recovered': true,
      };
      await capture('ad-error-retry-restored');
    });
    for (final method in ['fib', 'fastpay']) {
      await record('deposit-$method', const DepositScreen(), action: () async {
        final option = find.byKey(ValueKey('deposit-method-$method'));
        await reveal(option, depositScroll());
        await t.tap(option);
        await settle();
        final amount = find.byKey(const ValueKey('deposit-quick-10000'));
        await reveal(amount, depositScroll());
        await t.tap(amount);
        await settle();
        if (method != 'fastpay') {
          final details = find.byKey(const ValueKey('deposit-payment-details'));
          await reveal(details, depositScroll());
          final instructions =
              find.byKey(const ValueKey('deposit-instructions'));
          await reveal(instructions, depositScroll());
          await t.tap(instructions);
          await settle();
          await capture('deposit-$method-instructions');
        }
      });
    }
    await record(
        'ad-video-example', AdCreateScreen(repository: TestAdRepository()),
        action: () async {
      final button = find.byKey(const ValueKey('help-example-ad_video_link'));
      await t.ensureVisible(button);
      await settle();
      await t.tap(button);
      await settle();
      expect(find.byType(Dialog), findsOneWidget);
    });
    await record('page-example',
        ProxoLinkCreatePageScreen(repository: ToolsRepository([])),
        action: () async {
      final button = find.byKey(const ValueKey('help-example-page_creation'));
      await t.ensureVisible(button);
      await settle();
      await t.tap(button);
      await settle();
      expect(find.byType(Dialog), findsOneWidget);
    });
    await record('auth-login', const AuthShell());
    await record('auth-phone', const AuthShell(), action: () async {
      await tapLabel(AuthStrings.channelPhone);
      final input = find.byType(TextField).first;
      // Profile builds reject TestTextInput's debug-only client id -1.
      // Type through Android's actual input channel instead.
      await t.tap(input);
      await t.pump(const Duration(milliseconds: 100));
      print('PROXO_POLISH_PHONE_INPUT_READY');
      final inputClock = Stopwatch()..start();
      while (t.widget<TextField>(input).controller!.text != '7501234567' &&
          inputClock.elapsed < const Duration(seconds: 12)) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(t.widget<TextField>(input).controller!.text, '7501234567');
      observations['phone_input_transport'] = 'Android adb input text';
      FocusManager.instance.primaryFocus?.unfocus();
      await settle();
      expect(find.byType(IraqPhonePrefix), findsOneWidget);
      expect(t.widget<TextField>(input).controller!.text, '7501234567',
          reason: 'Phone input must survive unfocus');
    });
    await record('auth-signup', const AuthShell(), action: () async {
      await tapLabel(AuthStrings.noAccountAction);
      expect(find.byType(TextField), findsNWidgets(4));
    });
    await record('auth-recovery', const AuthShell(), action: () async {
      await tapLabel(AuthStrings.forgotPasswordLink);
    });
    await record('auth-channel-cycles', const AuthShell(), action: () async {
      for (var i = 0; i < 8; i++) {
        await tapLabel(
            i.isEven ? AuthStrings.channelPhone : AuthStrings.channelEmail);
        expect(t.takeException(), isNull);
      }
    });
    // Measure a production refresh with a controlled pending response.
    final refresh = ProxoRefreshController();
    await record('home-refresh', HomeScreen(refreshController: refresh),
        action: () async {
      final gate = Completer<void>();
      backend.refreshGate = gate;
      final first = refresh.refresh();
      unawaited(refresh.refresh());
      for (var i = 0; i < 25; i++)
        await t.pump(const Duration(milliseconds: 16));
      expect(find.text('نوێدەکرێتەوە'), findsOneWidget);
      await capture('home-refresh-pending');
      gate.complete();
      backend.refreshGate = null;
      // The refresh Future also awaits its closing spring; integration tests
      // must pump those frames before awaiting the Future's completion.
      final completionClock = Stopwatch()..start();
      while (refresh.isRefreshing &&
          completionClock.elapsed < const Duration(seconds: 12)) {
        await t.pump(const Duration(milliseconds: 16));
      }
      expect(refresh.isRefreshing, isFalse,
          reason: 'Refresh fetch and closing animation must finish');
      await first.timeout(const Duration(seconds: 1));
      await settle();
    });
    await mount(const AuthShell());
    final keyboardField = find.byType(TextField).first;
    await t.tap(keyboardField);
    final keyboardClock = Stopwatch()..start();
    var stableKeyboardFrames = 0;
    var previousKeyboardInset = 0.0;
    while (stableKeyboardFrames < 6 &&
        keyboardClock.elapsed < const Duration(seconds: 8)) {
      await t.pump(const Duration(milliseconds: 50));
      final inset = t.view.viewInsets.bottom;
      stableKeyboardFrames = inset > 0 && inset == previousKeyboardInset
          ? stableKeyboardFrames + 1
          : 0;
      previousKeyboardInset = inset;
    }
    expect(t.view.viewInsets.bottom, greaterThan(0),
        reason: 'Capture the real Android software keyboard');
    expect(stableKeyboardFrames, greaterThanOrEqualTo(6));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    final keyboardFieldBounds = t.getRect(keyboardField);
    final visibleBottom =
        (t.view.physicalSize.height - t.view.viewInsets.bottom) /
            t.view.devicePixelRatio;
    expect(keyboardFieldBounds.bottom, lessThanOrEqualTo(visibleBottom),
        reason: 'Focused email field must remain above the Android keyboard');
    observations['keyboard_inset_px'] = t.view.viewInsets.bottom;
    observations['keyboard_field_bottom_dp'] = keyboardFieldBounds.bottom;
    observations['keyboard_visible_bottom_dp'] = visibleBottom;
    print('PROXO_POLISH_KEYBOARD_READY');
    // Continue Flutter frames while the host captures the native IME surface.
    final captureClock = Stopwatch()..start();
    while (captureClock.elapsed < const Duration(seconds: 4)) {
      await t.pump(const Duration(milliseconds: 50));
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await settle();
    await mount(const Scaffold(
        body: Center(child: Text('Proxo notification fixture'))));
    observations['background_notification'] = await native
        .invokeMapMethod<String, dynamic>('postBackgroundFcmFixture');
    await Future<void>.delayed(const Duration(seconds: 2));
    final active =
        await native.invokeListMethod<dynamic>('activeNotifications');
    expect(active?.any((n) => (n as Map)['id'] == 4321), isTrue);
    observations['active_background_notifications'] = active;
    // The host captures the Android heads-up/shade and then resumes this activity.
    print('PROXO_POLISH_NOTIFICATION_VISIBLE');
    await native
        .invokeMethod<bool>('waitForResume')
        .timeout(const Duration(seconds: 30));
    await settle();
    await mount(const SizedBox());
    refresh.dispose();
    code.dispose();
    focus.dispose();
    password.dispose();
    confirmation.dispose();
    showPassword.dispose();
    showConfirmation.dispose();
    final unexpectedAttempts = backend.nonGetAttempts
        .where((attempt) => attempt['expected_blocked_operation'] == null)
        .toList();
    observations['blocked_non_get_requests'] = backend.nonGetAttempts;
    observations['blocked_fixture_thumbnail_repairs'] = backend.nonGetAttempts
        .where((attempt) =>
            attempt['expected_blocked_operation'] ==
            'fictional_thumbnail_repair')
        .length;
    observations['blocked_trusted_device_lookups'] = backend.nonGetAttempts
        .where((attempt) =>
            attempt['expected_blocked_operation'] == 'trusted_device_lookup')
        .length;
    observations['blocked_unread_notification_counts'] = backend.nonGetAttempts
        .where((attempt) =>
            attempt['expected_blocked_operation'] ==
            'unread_notification_count')
        .length;
    observations['unexpected_backend_requests'] = unexpectedAttempts;
    observations['fixture_network_boundary'] =
        'Every non-GET request is rejected by the local mock before network '
        'access. Only the exact fictional thumbnail repair, Android Auth '
        'trusted-device lookup and owner-filtered unread-count HEAD shapes '
        'are expected. Production RPC semantics '
        'and writes are not exercised by this fixture.';
    expect(unexpectedAttempts, isEmpty,
        reason: 'No payment, page, auth registration or other unexpected '
            'backend request may be attempted by the visual fixture');
    observations['completed'] = true;
  }, timeout: const Timeout(Duration(minutes: 10)));
}
