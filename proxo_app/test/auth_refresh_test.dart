import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/screens/auth/auth_shell.dart';
import 'package:proxo_app/screens/account_setup_screen.dart';
import 'package:proxo_app/services/account_setup_service.dart';
import 'package:proxo_app/theme/app_locale.dart';
import 'package:proxo_app/widgets/auth/auth_design.dart';
import 'package:proxo_app/widgets/auth/auth_header.dart';
import 'package:proxo_app/widgets/auth/auth_widgets.dart';

import '../integration_test/support/actual_screen_fixtures.dart';
import 'polish_capture_test.dart' show measuredLayout;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final backend = ActualScreenBackend();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    final fonts =
        jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family'] as String);
      for (final item in font['fonts'] as List) {
        loader.addFont(rootBundle.load(item['asset'] as String));
      }
      await loader.load();
    }
    await backend.initialize();
  });
  tearDownAll(() async {
    await backend.dispose();
    ProxoLocale.current.value = ProxoLocale.kurdishSorani;
  });

  Widget host(Widget child, {double scale = 1, bool reduced = false}) =>
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(useMaterial3: true),
        builder: (context, child) => ProxoLocaleScope(
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reduced,
            ),
            child: child!,
          ),
        ),
        home: child,
      );
  Future<void> settle(WidgetTester t) async {
    await t.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    });
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 60));
    }
  }

  for (final reduced in [false, true]) {
    testWidgets(
      'Auth back restores login quickly, with reduced motion $reduced',
      (t) async {
        ProxoLocale.current.value = ProxoLocale.kurdishSorani;
        await t.pumpWidget(host(const AuthShell(), reduced: reduced));
        await settle(t);
        final signup = find.byWidgetPredicate(
          (w) => w is AuthTextLink && w.label == AuthStrings.noAccountAction,
        );
        await t.ensureVisible(signup);
        await t.tap(signup);
        await t.pump();
        await t.pump(const Duration(milliseconds: 90));
        expect(t.takeException(), isNull);
        await t.pump(const Duration(milliseconds: 130));
        expect(
          find.byWidgetPredicate(
            (w) => w is AuthTitle && w.text == AuthStrings.signUpTitle,
          ),
          findsOneWidget,
        );
        await t.binding.handlePopRoute();
        await t.pump();
        await t.pump(const Duration(milliseconds: 220));
        expect(
          find.byWidgetPredicate(
            (w) => w is AuthTitle && w.text == AuthStrings.signInTitle,
          ),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (w) => w is AuthTitle && w.text == AuthStrings.signUpTitle,
          ),
          findsNothing,
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );
  }

  for (final width in [393.0, 280.0]) {
    for (final locale in ['ckb', 'ar', 'kmr']) {
      for (final failed in [false, true]) {
        testWidgets('setup $locale ${width.toInt()} failed=$failed', (t) async {
          final scale = width == 280 ? 2.0 : 1.0;
          t.view.devicePixelRatio = 2;
          t.view.physicalSize = Size(width * 2, 852 * 2);
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          ProxoLocale.current.value = Locale(locale);
          final key = GlobalKey();
          var retries = 0;
          await t.pumpWidget(
            host(
              RepaintBoundary(
                key: key,
                child: AccountSetupView(
                  phase: AccountSetupPhase.profile,
                  failed: failed,
                  onRetry: () async {
                    retries++;
                  },
                ),
              ),
              scale: scale,
            ),
          );
          await t.pump(const Duration(milliseconds: 100));
          expect(t.takeException(), isNull);
          final layout = measuredLayout(key);
          final texts = layout.where((e) => e['text'] != null).toList();
          expect(texts, isNotEmpty);
          expect(
            texts.every(
              (e) =>
                  e['font_family'] == AuthTokens.fontFamily &&
                  e['font_weight'] == FontWeight.w400.index,
            ),
            isTrue,
          );
          await t.runAsync(() async {
            final out = Directory('build/auth-refresh')
              ..createSync(recursive: true);
            final image =
                await (key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 2);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            image.dispose();
            final name =
                'setup-$locale-${width.toInt()}-${failed ? 'error' : 'loading'}';
            await File('${out.path}/$name.png')
                .writeAsBytes(data!.buffer.asUint8List());
            await File('${out.path}/$name.json').writeAsString(
              jsonEncode({
                'width': width,
                'text_scale': scale,
                'layout': layout,
              }),
            );
          });
          if (failed) {
            final retry = find.byType(AuthPrimaryButton);
            await t.ensureVisible(retry);
            await t.tap(retry);
            await t.pump(const Duration(milliseconds: 400));
            expect(retries, 1);
          }
          await t.pumpWidget(const SizedBox());
          expect(t.takeException(), isNull);
        });
      }
    }
  }
}
