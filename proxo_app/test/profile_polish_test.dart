import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:proxo_app/screens/profile_screen.dart';
import 'package:proxo_app/config/backend_config.dart';
import 'package:proxo_app/theme/app_locale.dart';
import 'package:proxo_app/theme/proxo_surface.dart';
import 'package:proxo_app/widgets/proxo_symbol.dart';
import 'package:proxo_app/widgets/proxo_text.dart';

import '../integration_test/support/actual_screen_fixtures.dart';

// Actual production widgets and account lifecycle, with every outbound call
// replaced by the rejecting transport or an explicit local email fixture.
void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;
  final backend = ActualScreenBackend(allowLogout: true);
  final navigator = GlobalKey<NavigatorState>();
  late String initialSession;

  setUpAll(() async {
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family'] as String);
      for (final file in font['fonts'] as List) {
        loader.addFont(rootBundle.load(file['asset'] as String));
      }
      await loader.load();
    }
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
        appName: 'Proxo',
        packageName: 'fixture.proxo',
        version: '1.0.11',
        buildNumber: '11',
        buildSignature: '');
    await backend.initialize();
    initialSession = jsonEncode(backend.client.auth.currentSession!.toJson());
  });
  tearDownAll(backend.dispose);
  setUp(() async {
    backend.readResponses.clear();
    backend.nonGetAttempts.clear();
    backend.logoutRequests = 0;
    ProxoLocale.current.value = ProxoLocale.kurdishSorani;
    await backend.client.auth.recoverSession(initialSession);
  });

  Finder key(String name) => find.byKey(ValueKey(name));
  Widget host(Widget home, {double scale = 1, double inset = 0}) => MaterialApp(
        navigatorKey: navigator,
        builder: (context, child) => ProxoLocaleScope(
            child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              viewInsets: EdgeInsets.only(bottom: inset)),
          child: child!,
        )),
        routes: {
          for (final route in ['/coupons', '/notifications', '/transactions'])
            route: (_) => Scaffold(body: Text(route))
        },
        home: home,
      );
  Future<void> settle(WidgetTester t) async {
    await t.pump();
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  }

  Future<void> tap(WidgetTester t, String name) async {
    await t.ensureVisible(key(name));
    await settle(t);
    await t.tap(key(name));
    await settle(t);
  }

  Future<void> close(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await settle(t);
  }

  Future<void> ownerChange() async {
    const owner = '00000000-0000-4000-8000-000000000098';
    String part(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    final token = '${part({'alg': 'HS256', 'typ': 'JWT'})}.${part({
          'sub': owner,
          'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 86400
        })}.fictional-signature';
    await backend.client.auth.recoverSession(jsonEncode(Session(
            accessToken: token,
            tokenType: 'bearer',
            user: const User(
                id: owner,
                appMetadata: {},
                userMetadata: {},
                aud: 'authenticated',
                createdAt: '2026-10-15T00:00:00Z'))
        .toJson()));
  }

  EditProfileScreen editor(
          {http.Client? emailClient,
          Future<XFile?> Function()? picker,
          String email = 'before@gmail.com'}) =>
      EditProfileScreen(
        initialFullName: 'ناوی درێژ — Long Profile Name',
        initialEmail: email,
        initialPhone: '+9647500000000',
        emailClient: emailClient,
        pickAvatar: picker,
      );
  void viewport(WidgetTester t, double width, {double height = 852}) {
    t.view.physicalSize = Size(width, height);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  for (final width in [320.0, 393.0, 430.0, 768.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'Profile full content and actions fit width $width at $scale text',
          (t) async {
        viewport(t, width);
        backend.readResponses['profiles'] = {
          'full_name': 'ناوی کوردی زۆر درێژ — Long Mixed Profile Name',
          'email': 'averylongprofileaddress.for.fixture@gmail.com',
          'phone': '+9647500000000',
        };
        backend.readResponses['pa_wallets'] = {'balance': 12345678.90};
        await t.pumpWidget(host(const ProfileScreen(), scale: scale));
        await settle(t);
        final identity = t.getRect(key('profile-identity'));
        expect(identity.width, lessThanOrEqualTo(ProxoSurface.maxWidth));
        expect(identity.left, greaterThanOrEqualTo(20));
        expect(identity.right, lessThanOrEqualTo(width - 20));
        expect(find.text('ناوی کوردی زۆر درێژ — Long Mixed Profile Name'),
            findsOneWidget);
        expect(
            t
                .widget<ProxoText>(find.byWidgetPredicate((w) =>
                    w is ProxoText &&
                    w.data == 'ناوی کوردی زۆر درێژ — Long Mixed Profile Name'))
                .style
                ?.fontFamily,
            ProxoSurface.fontFamily);
        expect(find.byType(ProxoSymbol), findsWidgets);
        final reads = Map<String, int>.from(backend.reads);
        await tap(t, 'profile-balance-toggle');
        expect(t.widget<ProxoText>(key('profile-balance-amount')).data,
            contains('••••••'));
        expect(backend.reads, reads,
            reason: 'Privacy toggle must not refetch/rebuild the account');
        expect(t.getSize(key('profile-balance-toggle')).height,
            greaterThanOrEqualTo(48));
        for (final name in [
          'profile-ads',
          'profile-tools',
          'profile-coupons',
          'profile-notifications',
          'profile-transactions',
          'profile-support',
          'profile-about',
          'profile-faq',
          'profile-language',
          'profile-whatsapp',
          'profile-sign-out'
        ]) {
          await t.ensureVisible(key(name));
          await settle(t);
          expect(key(name).hitTestable(), findsOneWidget, reason: name);
          if (name != 'profile-language')
            expect(t.getSize(key(name)).height, greaterThanOrEqualTo(48));
        }
        await t.ensureVisible(find.text('Proxo 1.0.11'));
        expect(find.text('Proxo 1.0.11'), findsOneWidget);
        expect(backend.nonGetAttempts, isEmpty);
        await close(t);
      });
    }
  }

  for (final locale in [
    ProxoLocale.kurdishSorani,
    ProxoLocale.arabic,
    ProxoLocale.kurdishBadini
  ]) {
    testWidgets(
        'Profile missing information and secondary surfaces fit ${locale.languageCode} at 320/200%',
        (t) async {
      viewport(t, 320);
      ProxoLocale.current.value = locale;
      backend.readResponses['profiles'] = {
        'full_name': '',
        'email': '7500000000@phone.proxopages.com',
        'phone': '',
        'avatar_url': 'not-a-url'
      };
      await t.pumpWidget(host(const ProfileScreen(), scale: 2));
      await settle(t);
      expect(find.textContaining('@phone.proxopages.com'), findsNothing);
      for (final name in ['profile-support', 'profile-about', 'profile-faq']) {
        await tap(t, name);
        expect(navigator.currentState!.canPop(), isTrue);
        if (name == 'profile-faq') {
          await t.tap(find.byType(ExpansionTile).first);
          await settle(t);
        }
        navigator.currentState!.pop();
        await settle(t);
      }
      await tap(t, 'profile-sign-out');
      expect(find.byType(AlertDialog), findsOneWidget);
      await tap(t, 'profile-dialog-cancel');
      expect(backend.logoutRequests, 0);
      expect(backend.nonGetAttempts, isEmpty);
      await close(t);
    });
  }

  testWidgets(
      'Profile route and confirmation callbacks reject repeated taps and changed owners',
      (t) async {
    viewport(t, 393);
    await t.pumpWidget(host(const ProfileScreen()));
    await settle(t);
    final edit = t.widget<IconButton>(key('profile-edit')).onPressed!;
    edit();
    edit();
    await settle(t);
    expect(find.byType(EditProfileScreen), findsOneWidget);
    navigator.currentState!.pop();
    await settle(t);
    expect(navigator.currentState!.canPop(), isFalse);
    await t.ensureVisible(key('profile-sign-out'));
    final logout = t.widget<InkWell>(key('profile-sign-out')).onTap!;
    logout();
    logout();
    await settle(t);
    expect(find.byType(AlertDialog), findsOneWidget);
    await ownerChange();
    await tap(t, 'profile-dialog-confirm');
    expect(backend.logoutRequests, 0);
    expect(backend.client.auth.currentSession, isNotNull);
    await close(t);
  });

  testWidgets('Repeated modal dismissal preserves the Profile route underneath',
      (t) async {
    viewport(t, 393);
    await t.pumpWidget(host(const Scaffold(body: Text('Base route'))));
    navigator.currentState!
        .push(MaterialPageRoute<void>(builder: (_) => const ProfileScreen()));
    await settle(t);
    await tap(t, 'profile-about');
    final dismissAbout =
        t.widget<IconButton>(key('profile-back').last).onPressed!;
    dismissAbout();
    dismissAbout();
    await settle(t);
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(navigator.currentState!.canPop(), isTrue);
    await tap(t, 'profile-sign-out');
    final cancel =
        t.widget<TextButton>(key('profile-dialog-cancel')).onPressed!;
    cancel();
    cancel();
    await settle(t);
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(navigator.currentState!.canPop(), isTrue);
    expect(backend.logoutRequests, 0);
    await close(t);
  });

  testWidgets(
      'Edit form, deletion cancel and keyboard remain reachable at 320/200%',
      (t) async {
    viewport(t, 320);
    await t.pumpWidget(host(editor(), scale: 2, inset: 300));
    await settle(t);
    expect(t.getSize(key('profile-avatar')), const Size(96, 96));
    final avatarBounds = t.getRect(key('profile-avatar'));
    final badgeBounds = t.getRect(key('profile-avatar-camera-badge'));
    expect(badgeBounds.size, const Size(32, 32));
    expect(
        (badgeBounds.center - avatarBounds.center).distance +
            badgeBounds.width / 2,
        lessThanOrEqualTo(avatarBounds.width / 2),
        reason:
            'The full camera circle must remain inside its circular ink clip');
    final fields = t.widgetList<TextField>(find.byType(TextField));
    expect(fields.where((field) => field.readOnly).length, 2);
    await tap(t, 'profile-save');
    expect(backend.nonGetAttempts, isEmpty);
    // The intentional no-change notice temporarily covers the lower form.
    // Wait for its real dismissal before testing the next physical tap.
    await t.pump(const Duration(seconds: 5));
    await settle(t);
    await tap(t, 'profile-delete');
    await tap(t, 'profile-dialog-cancel');
    expect(backend.nonGetAttempts, isEmpty);
    await close(t);
  });

  testWidgets(
      'Pending avatar selection is single-flight and cannot alter a new owner',
      (t) async {
    final gate = Completer<XFile?>();
    var picks = 0;
    await t.pumpWidget(host(editor(picker: () {
      picks++;
      return gate.future;
    })));
    await settle(t);
    final pick = t.widget<InkWell>(key('profile-avatar')).onTap!;
    pick();
    pick();
    await t.pump();
    expect(picks, 1);
    await ownerChange();
    gate.complete(XFile.fromData(Uint8List.fromList([1, 2, 3])));
    await settle(t);
    expect(find.byType(SnackBar), findsNothing);
    expect(backend.nonGetAttempts, isEmpty);
    await close(t);
  });

  testWidgets('Delete confirmation cannot delete a changed owner', (t) async {
    await t.pumpWidget(host(editor()));
    await settle(t);
    await tap(t, 'profile-delete');
    await ownerChange();
    await tap(t, 'profile-dialog-confirm');
    expect(backend.nonGetAttempts, isEmpty);
    expect(backend.client.auth.currentSession, isNotNull);
    await close(t);
  });

  testWidgets(
      'Custom email API and centered OTP use one request, normalized digits and recoverable errors',
      (t) async {
    viewport(t, 320);
    final requests = <Map<String, dynamic>>[];
    final transports = <http.Request>[];
    final gate = Completer<void>();
    addTearDown(() {
      if (!gate.isCompleted) gate.complete();
    });
    final emailClient = MockClient((request) async {
      transports.add(request);
      final payload = jsonDecode(request.body) as Map<String, dynamic>;
      requests.add(payload);
      if (payload['action'] == 'request_email_change') {
        await gate.future;
        return http.Response(
            '{"success":true,"request_id":"fixture-change"}', 200);
      }
      return http.Response('{"success":false,"error":"invalid_code"}', 400);
    });
    addTearDown(emailClient.close);
    await t.pumpWidget(host(editor(emailClient: emailClient), scale: 2));
    await settle(t);
    await t.enterText(key('profile-email'), ' After@Gmail.com ');
    await t.ensureVisible(key('profile-save'));
    await settle(t);
    final save = t.widget<FilledButton>(key('profile-save')).onPressed!;
    save();
    save();
    await t.pump();
    expect(requests.length, 1);
    expect(transports.single.url.toString(),
        'https://email.proxopages.com/webhook/send_otp');
    expect(transports.single.method, 'POST');
    expect(
        transports.single.headers.entries
            .singleWhere((entry) => entry.key.toLowerCase() == 'authorization')
            .value,
        startsWith('Bearer '));
    expect(requests.single,
        {'action': 'request_email_change', 'new_email': 'after@gmail.com'});
    gate.complete();
    await settle(t);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(t.widget<TextField>(key('profile-otp')).textAlign, TextAlign.center);
    await t.enterText(key('profile-otp'), '١٢٣٤٥٦');
    await tap(t, 'profile-otp-confirm');
    expect(requests.length, 2);
    expect(requests.last, {
      'action': 'verify_email_change',
      'request_id': 'fixture-change',
      'code': '123456'
    });
    expect(t.widget<TextField>(key('profile-otp')).controller!.text, isEmpty);
    expect(key('profile-otp-confirm'), findsOneWidget);
    await tap(t, 'profile-otp-cancel');
    expect(find.byType(AlertDialog), findsNothing);
    expect(t.widget<FilledButton>(key('profile-save')).onPressed, isNotNull);
    expect(backend.nonGetAttempts, isEmpty);
    await close(t);
  });

  testWidgets(
      'Late custom email response after owner change cannot show an OTP or pop a route',
      (t) async {
    final gate = Completer<http.Response>();
    var requests = 0;
    final emailClient = MockClient((request) {
      requests++;
      return gate.future;
    });
    addTearDown(emailClient.close);
    await t.pumpWidget(host(editor(emailClient: emailClient)));
    await settle(t);
    await t.enterText(key('profile-email'), 'after@gmail.com');
    await t.ensureVisible(key('profile-save'));
    t.widget<FilledButton>(key('profile-save')).onPressed!();
    await t.pump();
    expect(requests, 1);
    await ownerChange();
    gate.complete(
        http.Response('{"success":true,"request_id":"fixture-change"}', 200));
    await settle(t);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(backend.nonGetAttempts, isEmpty);
    await close(t);
  });
  testWidgets(
      'Staging profile email change cannot call the production email transport',
      (t) async {
    final staging = BackendConfig.fromValues(
        mode: 'staging',
        supabaseUrl: 'https://abcdefghijklmnopqrst.supabase.co',
        supabaseAnonKey: 'sb_publishable_fixture_only',
        publicBase: 'https://proxolink-staging.vercel.app');
    var requests = 0;
    final emailClient = MockClient((request) async {
      requests++;
      return http.Response(
          '{"success":true,"request_id":"must-not-send"}', 200);
    });
    addTearDown(emailClient.close);
    await t.pumpWidget(host(EditProfileScreen(
        initialFullName: 'Staging fixture',
        initialEmail: 'before@gmail.com',
        initialPhone: '',
        emailClient: emailClient,
        backendConfig: staging)));
    await settle(t);
    await t.enterText(key('profile-email'), 'after@gmail.com');
    await tap(t, 'profile-save');
    expect(requests, 0);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(backend.nonGetAttempts, isEmpty);
    await close(t);
  });
}
