import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:proxo_app/config/backend_config.dart';
import 'package:proxo_app/screens/auth/auth_models.dart';
import 'package:proxo_app/screens/auth/auth_service.dart';
import 'package:proxo_app/services/ad_submission.dart';
import 'package:proxo_app/services/notification_service.dart';
import 'package:proxo_app/widgets/fastpay_checkout_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final config = BackendConfig.fromValues(
    mode: 'staging',
    supabaseUrl: 'https://abcdefghijklmnopqrst.supabase.co',
    supabaseAnonKey: 'sb_publishable_fictionalAcceptanceKey',
    publicBase: 'https://proxolink-staging-proxo.vercel.app',
  );
  final requests = <http.Request>[];
  late SupabaseClient client;
  late AuthService service;

  setUp(() {
    requests.clear();
    final transport = MockClient((request) async {
      requests.add(request);
      throw StateError('Unexpected staging external transport');
    });
    client = SupabaseClient(config.supabaseUrl, config.supabaseAnonKey,
        httpClient: transport,
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    service = AuthService(
      supabase: client,
      emailOtpUrl: 'https://email.proxopages.com/webhook/send_otp',
      whatsappOtpUrl: 'https://email.proxopages.com/webhook/wevlix/otp/send',
      httpClient: transport,
      backendConfig: config,
    );
  });
  tearDown(() async {
    service.close();
    await client.dispose();
  });

  test('staging email login, signup resend and recovery send no HTTP',
      () async {
    expect(await service.sendLoginEmailOtp('fixture@example.invalid'), isFalse);
    for (final purpose in ['signup', 'reset_password']) {
      expect(
          await service.requestEmailOtp(
            email: 'fixture@example.invalid',
            userId: '11111111-1111-4111-8111-111111111111',
            name: 'Fixture',
            purpose: purpose,
          ),
          isFalse);
    }
    expect(service.lastOtpStatus, isNull);
    expect(requests, isEmpty);
  });

  test('staging signup fails before creating identity or sending Auth mail',
      () async {
    await expectLater(
        service.beginEmailSignup(
          email: 'fixture@example.invalid',
          password: 'Synthetic#2026',
          name: 'Fixture',
        ),
        throwsStateError);
    expect(requests, isEmpty);
  });

  test('every staging WhatsApp OTP purpose fails before HTTP', () async {
    for (final purpose in AuthOtpPurpose.values) {
      expect(
          await service.requestWhatsappOtp(
            phone: '+9647500000000',
            purpose: purpose,
            locale: 'ckb',
          ),
          isFalse);
    }
    expect(requests, isEmpty);
  });

  test('staging wallet checkout fails before Auth or order-create request',
      () async {
    await expectLater(
        FastPayService.createOrder(
          orderId: 'PX-STAGING-FIXTURE',
          billAmountIqd: 5000,
          backendConfig: config,
        ),
        throwsStateError);
    expect(requests, isEmpty);
  });

  test('staging FastPay ad checkout fails before submission or payment state',
      () {
    final repository =
        SupabaseAdCreationRepository(client, backendConfig: config);
    final progress = ValueNotifier(const AdPaymentProgress());
    addTearDown(progress.dispose);
    final pending = AdPendingSubmission.create(
      const AdDraft(paymentMethod: 'fastpay'),
      const AdQuote(grossUsd: 10, costUsd: 10, rate: 1800),
    );
    expect(() => repository.submit(pending, progress), throwsStateError);
    expect(requests, isEmpty);
    expect(progress.value.waitingForPayment, isFalse);
  });

  test('staging foreground/background push helpers avoid Firebase and tokens',
      () async {
    expect(BackendConfig.current.isStaging, isTrue);
    expect(Firebase.apps, isEmpty);
    await firebaseMessagingBackgroundHandler(const RemoteMessage());
    final notifications = NotificationService.instance;
    await notifications.init(navigatorKey: GlobalKey<NavigatorState>());
    await notifications.saveTokenAfterLogin();
    await notifications.removeToken();
    expect(await notifications.getToken(), isNull);
    await notifications.subscribeToTopic('staging-fixture');
    await notifications.unsubscribeFromTopic('staging-fixture');
    expect(Firebase.apps, isEmpty);
    expect(requests, isEmpty);
  },
      skip: !BackendConfig.current.isStaging
          ? 'Run this case with the complete guarded staging build defines.'
          : false);
}
