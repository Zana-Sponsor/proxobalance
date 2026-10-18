import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:proxo_app/main.dart' as app;
import 'package:proxo_app/screens/auth/auth_service.dart';
import 'package:proxo_app/screens/auth/auth_shell.dart';
import 'package:proxo_app/screens/whatsapp_marketing_screen.dart';
import 'package:proxo_app/theme/app_locale.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/widgets/auth/auth_design.dart';
import 'package:proxo_app/widgets/auth/auth_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SupabaseClient client;
  final requests = <http.Request>[];
  var optedIn = true;
  var saveFails = false;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family'] as String);
      for (final file in font['fonts'] as List) {
        loader.addFont(rootBundle.load(file['asset'] as String));
      }
      await loader.load();
    }
    final instance = await Supabase.initialize(
      url: 'https://marketing-fixture.invalid',
      anonKey: 'fixture-only',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        localStorage: EmptyLocalStorage(),
        detectSessionInUri: false,
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        Object body;
        var status = 200;
        switch (request.url.path) {
          case '/functions/v1/phone-otp-session':
            body = {'ok': true, 'token_hash': 'fixture-hash'};
          case '/rest/v1/whatsapp_marketing_preferences':
            body = [
              {'opted_in': optedIn},
            ];
          case '/rest/v1/rpc/pa_set_whatsapp_marketing':
            if (saveFails) {
              status = 500;
              body = {'message': 'fixture failure'};
            } else {
              optedIn = (jsonDecode(request.body) as Map)['p_opted_in'] == true;
              body = {'ok': true};
            }
          default:
            throw StateError('No real network: ${request.url.path}');
        }
        return http.Response(
          jsonEncode(body),
          status,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    client = instance.client;
    app.supabase = client;
    String part(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    const owner = '11111111-1111-4111-8111-111111111111';
    final token = '${part({'alg': 'HS256'})}.${part({
          'sub': owner,
          'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 86400
        })}.fixture';
    await client.auth.recoverSession(
      jsonEncode(
        Session(
          accessToken: token,
          tokenType: 'bearer',
          user: const User(
            id: owner,
            appMetadata: {},
            userMetadata: {},
            aud: 'authenticated',
            createdAt: '2026-10-15T00:00:00Z',
          ),
        ).toJson(),
      ),
    );
    // Match PostgREST's actual response/request contract before mounting UI.
    expect(
      await client
          .from('whatsapp_marketing_preferences')
          .select('opted_in')
          .maybeSingle(),
      {'opted_in': true},
    );
  });
  tearDownAll(() async {
    await Supabase.instance.dispose();
    ProxoLocale.current.value = ProxoLocale.kurdishSorani;
  });
  setUp(() {
    requests.clear();
    saveFails = false;
    optedIn = true;
  });

  Widget host(Widget child, {double scale = 1}) => MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(fontFamily: kAppFont, useMaterial3: true),
        builder: (context, child) => ProxoLocaleScope(
          child: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
        home: child,
      );
  Future<void> settle(WidgetTester t) async {
    await t.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await t.pump(const Duration(milliseconds: 500));
    await t.pumpAndSettle();
  }

  Future<void> screenshot(WidgetTester t, GlobalKey key, String name) async {
    await t.runAsync(() async {
      final directory = Directory('build/polish-evidence/marketing')
        ..createSync(recursive: true);
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('${directory.path}/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  test(
    'Auth service forwards true/false, version and displayed locale',
    () async {
      final service = AuthService(
        supabase: client,
        emailOtpUrl: 'https://fixture.invalid/email',
        whatsappOtpUrl: 'https://fixture.invalid/otp',
      );
      addTearDown(service.close);
      for (final choice in [false, true]) {
        final result = await service.completePhoneSignup(
          phone: '07500000001',
          code: '012345',
          fullName: 'Fixture User',
          password: 'Example#9',
          whatsappMarketing: choice,
          locale: 'ar',
        );
        expect(result.tokenHash, 'fixture-hash');
        final body = jsonDecode(requests.last.body) as Map;
        expect(body['phone'], '+9647500000001');
        expect(body['whatsapp_marketing_opt_in'], choice);
        expect(body['whatsapp_consent_version'], 'whatsapp-marketing-v1');
        expect(body['whatsapp_consent_locale'], 'ar');
      }
    },
  );
  testWidgets(
    'email signup does not ask for phone marketing consent',
    (t) async {
      await t.pumpWidget(host(const AuthShell()));
      await settle(t);
      final link = find.byWidgetPredicate(
        (w) => w is AuthTextLink && w.label == AuthStrings.noAccountAction,
      );
      await t.ensureVisible(link);
      await t.tap(link);
      await settle(t);
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(4));
      await t.enterText(fields.at(0), 'Fixture User');
      await t.enterText(fields.at(1), 'fixture@example.com');
      await t.enterText(fields.at(2), 'Example#9');
      await t.enterText(fields.at(3), 'Example#9');
      await t.pump();
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.byType(AuthWhatsappConsent), findsNothing);
      final button = find.byKey(const ValueKey('signup-submit'));
      expect(t.widget<AuthPrimaryButton>(button).enabled, true);
      expect(requests, isEmpty,
          reason: 'Entering email details sends no WhatsApp request');
      await t.pumpWidget(const SizedBox());
      await t.pump();
    },
  );
  for (final width in [393.0, 280.0]) {
    for (final locale in ['ckb', 'ar', 'kmr']) {
      testWidgets(
        'profile marketing opt-out $locale $width wraps and persists',
        (t) async {
          t.view.physicalSize = Size(width, 852);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          ProxoLocale.current.value = Locale(locale);
          final key = GlobalKey();
          await t.pumpWidget(
            host(
              RepaintBoundary(key: key, child: const WhatsappMarketingScreen()),
              scale: width == 280 ? 2 : 1,
            ),
          );
          await settle(t);
          expect(
            t.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
            true,
          );
          expect(t.takeException(), isNull);
          await screenshot(t, key, 'preference-$locale-${width.toInt()}');
          await t.tap(find.byType(CheckboxListTile));
          await t.pump();
          await t.ensureVisible(find.byType(AuthPrimaryButton));
          await t.tap(find.byType(AuthPrimaryButton));
          await settle(t);
          expect(optedIn, false);
          final save = requests.singleWhere(
            (r) => r.url.path.endsWith('pa_set_whatsapp_marketing'),
          );
          final body = jsonDecode(save.body) as Map;
          expect(body['p_opted_in'], false);
          expect(body['p_locale'], locale);
          expect(
            body.containsKey('p_user_id'),
            false,
            reason: 'Server resolves the owner',
          );
          expect(
            t.widget<AuthPrimaryButton>(find.byType(AuthPrimaryButton)).enabled,
            false,
          );
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
          await t.pump();
        },
      );
    }
  }
  testWidgets('failed opt-out stays unsaved and can be retried', (t) async {
    saveFails = true;
    await t.pumpWidget(host(const WhatsappMarketingScreen()));
    await settle(t);
    await t.tap(find.byType(CheckboxListTile));
    await t.pump();
    await t.tap(find.byType(AuthPrimaryButton));
    await settle(t);
    expect(optedIn, true);
    expect(find.byType(AuthAlert), findsOneWidget);
    expect(
      t.widget<AuthPrimaryButton>(find.byType(AuthPrimaryButton)).enabled,
      true,
    );
    saveFails = false;
    await t.tap(find.byType(AuthPrimaryButton));
    await settle(t);
    expect(optedIn, false);
    await t.pumpWidget(const SizedBox());
    await t.pump();
  });
}
