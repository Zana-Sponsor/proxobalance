import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/l10n/proxo_strings.dart';
import 'package:proxo_app/theme/app_locale.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/widgets/form_help_actions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
  });
  tearDownAll(() => ProxoLocale.current.value = ProxoLocale.kurdishSorani);
  for (final language in ['ckb', 'ar', 'kmr']) {
    for (final config in [(393.0, 1.0), (280.0, 2.0)]) {
      for (final section in ['video-link', 'contact', 'order', 'download']) {
        testWidgets('example dialog $section $language $config', (t) async {
          t.view.physicalSize = Size(config.$1 * 2, 852 * 2);
          t.view.devicePixelRatio = 2;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          ProxoLocale.current.value = language == 'ar'
              ? ProxoLocale.arabic
              : language == 'kmr'
                  ? ProxoLocale.kurdishBadini
                  : ProxoLocale.kurdishSorani;
          final boundary = GlobalKey();
          final video = section == 'video-link';
          await t.pumpWidget(RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: buildAppTheme(),
                locale: const Locale('ar'),
                supportedLocales: const [Locale('ar')],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate
                ],
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(config.$2)),
                    child: ProxoLocaleScope(child: child!)),
                home: Scaffold(
                    body: Center(
                        child: FormHelpActions(
                            helpKey: 'sample',
                            exampleAsset: video
                                ? 'assets/images/ad_video_link_example.png'
                                : 'assets/proxolink_thumbnails/$section-pill.png',
                            exampleCaption: video
                                ? 'سکرینشۆتی خانەی بەستەر لە ئەپی Proxo؛ بەستەری ڤیدیۆی خۆت دابنێ'
                                : 'نمونەی پەڕەکە؛ ناو و وێنە و بەستەرەکانی خۆت دابنێ',
                            sampleValue: video
                                ? 'https://www.tiktok.com/@scout2015/video/6718335390845095173'
                                : null,
                            loadTutorial: (_) async => null))),
              )));
          {
            await t.runAsync(() => precacheImage(
                ResizeImage.resizeIfNeeded(
                    720,
                    null,
                    AssetImage(video
                        ? 'assets/images/ad_video_link_example.png'
                        : 'assets/proxolink_thumbnails/$section-pill.png')),
                t.element(find.byType(FormHelpActions))));
            await t.pump();
          }
          await t.tap(find.byKey(const ValueKey('help-example-sample')));
          await t.pumpAndSettle();
          expect(find.byType(Dialog), findsOneWidget);
          expect(t.takeException(), isNull);
          final rect = t.getRect(find.byType(Dialog));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(config.$1));
          final render = boundary.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
          await t.runAsync(() async {
            final image = await render.toImage(pixelRatio: 2);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            final directory = Directory('build/help-evidence')
              ..createSync(recursive: true);
            final name = '$section-$language-${config.$1.toInt()}';
            File('${directory.path}/$name.png')
                .writeAsBytesSync(bytes!.buffer.asUint8List());
            File('${directory.path}/$name.json').writeAsStringSync(jsonEncode({
              'section': section,
              'locale': language,
              'width_dp': config.$1,
              'text_scale': config.$2,
              'dpr': 2,
              'dialog_bounds_dp': [
                rect.left,
                rect.top,
                rect.width,
                rect.height
              ],
              'exceptions': [],
              'fixture':
                  'Production FormHelpActions; local example assets; no network',
            }));
            image.dispose();
          });
          await t.tap(find.descendant(
              of: find.byType(Dialog),
              matching: find.byTooltip(ProxoStrings.text('داخستن'))));
          await t.pumpAndSettle();
          expect(find.byType(Dialog), findsNothing);
          expect(t.takeException(), isNull);
        });
      }
    }
  }
}
