// Production widgets in an Android profile build, with fictional backend data.
// No real account, payment, message, credential or external page is used.
import 'dart:async';
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
import 'package:proxo_app/services/ad_submission.dart';
import 'package:proxo_app/services/proxolink_service.dart';
import 'package:proxo_app/theme/app_locale.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/widgets/auth/auth_design.dart';
import 'package:proxo_app/widgets/auth/auth_otp_field.dart';
import 'package:proxo_app/widgets/auth/auth_widgets.dart';
import 'package:proxo_app/widgets/levels_page.dart';
import 'package:proxo_app/widgets/proxo_refresh.dart';
import 'package:proxo_app/widgets/proxo_sidebar.dart';
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
    backend.readResponses['whatsapp_marketing_preferences'] = {
      'opted_in': false
    };
    addTearDown(backend.dispose);
    ProxoLocale.current.value = ProxoLocale.kurdishSorani;
    final observations = <String, Object?>{
      'environment':
          'Android emulator, profile AOT, software GPU; not physical-device certification',
      'fixture_only': true,
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
        final scrolls = find.byType(Scrollable);
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
      await t.pumpAndSettle();
      await t.tap(target);
      await t.pumpAndSettle(const Duration(milliseconds: 16));
    }

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
              txId: 'TX-FIXTURE',
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
                      destination: 'fi***@example.invalid',
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
    for (final entry in screens.entries) await record(entry.key, entry.value);
    await record(
        'ad-video-example', AdCreateScreen(repository: TestAdRepository()),
        action: () async {
      final button = find.byKey(const ValueKey('help-example-ad_video_link'));
      await t.ensureVisible(button);
      await t.pumpAndSettle();
      await t.tap(button);
      await t.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
    });
    await record('page-example',
        ProxoLinkCreatePageScreen(repository: ToolsRepository([])),
        action: () async {
      final button = find.byKey(const ValueKey('help-example-page_creation'));
      await t.ensureVisible(button);
      await t.pumpAndSettle();
      await t.tap(button);
      await t.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
    });
    await record('auth-login', const AuthShell());
    await record('auth-phone', const AuthShell(), action: () async {
      await tapLabel(AuthStrings.channelPhone);
      await t.enterText(find.byType(TextField).first, '7501234567');
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      expect(find.byType(IraqPhonePrefix), findsOneWidget);
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
      await first;
      backend.refreshGate = null;
      await t.pumpAndSettle(const Duration(milliseconds: 16));
      expect(refresh.isRefreshing, isFalse);
    });
    await mount(const AuthShell());
    await t.tap(find.byType(TextField).first);
    await t.pumpAndSettle();
    observations['keyboard_inset_px'] = t.view.viewInsets.bottom;
    print('PROXO_POLISH_KEYBOARD_READY');
    await Future<void>.delayed(const Duration(seconds: 4));
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pumpAndSettle();
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
    await t.pumpAndSettle();
    await mount(const SizedBox());
    refresh.dispose();
    code.dispose();
    focus.dispose();
    password.dispose();
    confirmation.dispose();
    showPassword.dispose();
    showConfirmation.dispose();
    observations['completed'] = true;
  }, timeout: const Timeout(Duration(minutes: 10)));
}
