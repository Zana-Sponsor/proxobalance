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

  testWidgets(
    'signup validates identity before security and Back preserves fields',
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
      expect(fields, findsNWidgets(2));
      await t.enterText(fields.at(0), 'Fixture User');
      await t.enterText(fields.at(1), '123');
      await t.pump();
      final next = find.byKey(const ValueKey('signup-next'));
      await t.ensureVisible(next);
      await t.tap(next);
      await settle(t);
      expect(
        find.byWidgetPredicate(
          (w) => w is AuthTitle && w.text == AuthStrings.signUpTitle,
        ),
        findsOneWidget,
      );
      await t.enterText(fields.at(1), '7500000001');
      await t.pump();
      await t.ensureVisible(next);
      await t.tap(next);
      await settle(t);
      expect(
        find.byWidgetPredicate(
          (w) => w is AuthTitle && w.text == AuthStrings.signupSecurityTitle,
        ),
        findsOneWidget,
      );
      expect(fields, findsNWidgets(2));
      await t.binding.handlePopRoute();
      await settle(t);
      expect(
        t.widget<TextField>(fields.at(0)).controller!.text,
        'Fixture User',
      );
      expect(t.widget<TextField>(fields.at(1)).controller!.text, '7500000001');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'channel pill interpolates and rapid switches retain one active form',
    (t) async {
      await t.pumpWidget(host(const AuthShell()));
      await settle(t);
      await t.tap(find.text(AuthStrings.channelPhone).first);
      await settle(t);
      final pill = find
          .descendant(
            of: find.byKey(const ValueKey('auth-channel-indicator')),
            matching: find.byType(DecoratedBox),
          )
          .first;
      final start = t.getCenter(pill).dx;
      await t.tap(find.text(AuthStrings.channelEmail).first);
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      final middle = t.getCenter(pill).dx;
      await t.pump(const Duration(milliseconds: 200));
      final end = t.getCenter(pill).dx;
      expect(middle, isNot(start));
      expect(middle, isNot(end));
      expect(
        middle,
        inInclusiveRange(start < end ? start : end, start > end ? start : end),
      );
      await t.tap(find.text(AuthStrings.channelPhone).first);
      await t.pump(const Duration(milliseconds: 40));
      await t.tap(find.text(AuthStrings.channelEmail).first);
      await settle(t);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );

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
