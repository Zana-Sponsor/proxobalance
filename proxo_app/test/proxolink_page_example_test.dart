import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxo_app/l10n/proxo_strings.dart';
import 'package:proxo_app/models/proxolink_design.dart';
import 'package:proxo_app/models/proxolink_page_type.dart';
import 'package:proxo_app/screens/proxolink_create_page_screen.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/widgets/proxolink_design_selector.dart';

import '../integration_test/support/actual_screen_fixtures.dart';

class PageExamplePaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

String _assetName(ImageProvider provider) {
  while (provider is ResizeImage) {
    provider = provider.imageProvider;
  }
  return (provider as AssetImage).assetName;
}

Future<void> _tapVisible(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

List<double> _bounds(Rect rect) =>
    [rect.left, rect.top, rect.width, rect.height];

Future<Map<String, Object>> _footerPixels(
    WidgetTester tester, ui.Image image) async {
  final luminance = <int>[255, 0];
  var samples = 0, opaque = 0;
  await tester.runAsync(() async {
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    // The footer occupies the lower fifth of the bundled full-page captures.
    // Check real decoded paint, not just the presence of an Image widget.
    for (var y = (image.height * .8).floor(); y < image.height; y += 2) {
      for (var x = 0; x < image.width; x += 2) {
        final offset = (y * image.width + x) * 4;
        final light =
            (bytes[offset] + bytes[offset + 1] + bytes[offset + 2]) ~/ 3;
        if (light < luminance[0]) luminance[0] = light;
        if (light > luminance[1]) luminance[1] = light;
        if (bytes[offset + 3] == 255) opaque++;
        samples++;
      }
    }
  });
  expect(samples, greaterThan(0));
  expect(opaque / samples, greaterThan(.99));
  expect(luminance[1] - luminance[0], greaterThan(50),
      reason: 'The footer band must contain visible paint, not a blank image.');
  return {
    'decoded_size_px': [image.width, image.height],
    'footer_band_y_fraction': [.8, 1],
    'footer_band_luminance_range': luminance,
    'footer_band_opaque_fraction': opaque / samples,
    'pixel_check_scope': 'Nonblank paint only; footer contents verified by '
        'the separate production renderer footer audit.',
  };
}

Future<Map<String, Object>> _capture(
    WidgetTester tester, GlobalKey boundary, String name,
    {required String asset,
    required Rect dialogBounds,
    required Rect imageBounds,
    required Rect viewportBounds,
    required double scrollOffset,
    required Map<String, Object> decodedImage}) async {
  late Map<String, Object> result;
  await tester.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final screenshot = await render.toImage(pixelRatio: 2);
    try {
      final png =
          (await screenshot.toByteData(format: ui.ImageByteFormat.png))!;
      final bytes =
          png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
      final source = await rootBundle.load(asset);
      final sourceBytes =
          source.buffer.asUint8List(source.offsetInBytes, source.lengthInBytes);
      final file = File('build/page-example-evidence/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      result = {
        'file': '$name.png',
        'sha256': sha256.convert(bytes).toString(),
        'size_px': [screenshot.width, screenshot.height],
        'capture_pixel_ratio': 2,
        'viewport_dp': [393, 852],
        'text_scale': 1,
        'asset': asset,
        'asset_sha256': sha256.convert(sourceBytes).toString(),
        'dialog_bounds_dp': _bounds(dialogBounds),
        'image_bounds_dp': _bounds(imageBounds),
        'scroll_viewport_bounds_dp': _bounds(viewportBounds),
        'scroll_offset_dp': scrollOffset,
        ...decodedImage,
      };
    } finally {
      screenshot.dispose();
    }
  });
  return result;
}

void main() {
  PageExamplePaintBinding();
  final captures = <Map<String, Object>>[];
  final validatedCases = <Map<String, Object>>[];
  late String sourceCommit;
  setUpAll(() async {
    final git = await Process.run('git', ['rev-parse', 'HEAD']);
    expect(git.exitCode, 0);
    sourceCommit = (git.stdout as String).trim();
    await (FontLoader(kAppFont)
          ..addFont(rootBundle.load('assets/fonts/Rabar_021.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDownAll(() async {
    final file = File('build/page-example-evidence/manifest.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert({
      'source_commit': sourceCommit,
      'evidence_type': 'Actual production Flutter Create Page screen and '
          'FormHelpActions dialog; real bundled production-renderer PNGs.',
      'test': 'test/proxolink_page_example_test.dart',
      'fixture': 'integration_test/support/actual_screen_fixtures.dart: '
          'ActualToolsRepository; fictional form content; writes and '
          'network previews rejected.',
      'native_device': false,
      'customer_data': false,
      'fonts': ['Rabar_021.ttf', 'MaterialIcons-Regular.otf'],
      'expected_screenshots': 24,
      'complete_capture_set': captures.length == 24,
      'validated_interaction_cases': validatedCases,
      'captures': captures,
    }));
  });

  for (final configuration in [(393.0, 1.0), (320.0, 1.6)]) {
    testWidgets(
        'actual Create Page example follows all 12 type/style selections, '
        'retains input, and exposes the complete image at $configuration',
        (tester) async {
      tester.view.physicalSize = Size(configuration.$1, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      // This repository throws on preview, upload, save and other external
      // actions. Examples must work entirely from the bundled PNG captures.
      final repository = ActualToolsRepository();
      final boundary = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(configuration.$2)),
          child: RepaintBoundary(key: boundary, child: child!),
        ),
        home: ProxoLinkCreatePageScreen(repository: repository),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsAtLeastNWidgets(2),
          reason:
              'Complete fictional providers must make the authoring form ready.');
      final name = find.byType(TextFormField).at(0);
      final bio = find.byType(TextFormField).at(1);
      const retainedName = 'پەڕەی من Proxo';
      const retainedBio = 'دەقەکەم بە گۆڕینی ستایل و بینینی نمونە نامڕدرێت.';
      await tester.ensureVisible(name);
      await tester.enterText(name, retainedName);
      await tester.ensureVisible(bio);
      await tester.enterText(bio, retainedBio);
      tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      final examplesSeen = <String>{};
      for (final type in ProxoPageType.values) {
        await _tapVisible(
            tester, find.byKey(ValueKey('create-type-${type.key}')));
        for (final style in ProxoLinkDesign.labels.keys) {
          await _tapVisible(
              tester, find.byKey(ValueKey('proxolink-design-$style')));
          expect(
              tester
                  .widget<ProxoLinkDesignSelector>(
                      find.byType(ProxoLinkDesignSelector))
                  .selectedKey,
              style);
          await _tapVisible(
              tester, find.byKey(const ValueKey('help-example-page_creation')));

          final dialog = find.byType(Dialog);
          expect(dialog, findsOneWidget);
          final imageFinder =
              find.descendant(of: dialog, matching: find.byType(Image));
          expect(imageFinder, findsOneWidget);
          final image = tester.widget<Image>(imageFinder);
          final expectedAsset =
              'assets/proxolink_thumbnails/${type.key}-$style.png';
          expect(_assetName(image.image), expectedAsset);
          expect(image.fit, BoxFit.contain);
          // Real decoding is required: a matching asset name with a blank or
          // unresolved Image is insufficient evidence that the example works.
          await tester.runAsync(
              () => precacheImage(image.image, tester.element(imageFinder)));
          await tester.pumpAndSettle();
          final pixels = tester.widget<RawImage>(find.descendant(
              of: imageFinder, matching: find.byType(RawImage)));
          expect(pixels.image, isNotNull);
          expect(pixels.image!.width / pixels.image!.height,
              closeTo(393 / 1040, .001));
          final decodedImage = await _footerPixels(tester, pixels.image!);

          final scrollView = find.descendant(
              of: dialog, matching: find.byType(SingleChildScrollView));
          final scrollable =
              find.descendant(of: dialog, matching: find.byType(Scrollable));
          final position = tester.state<ScrollableState>(scrollable).position;
          expect(position.maxScrollExtent, greaterThan(0),
              reason: 'The full page capture must remain scrollable.');
          if (configuration.$1 == 393) {
            captures.add(await _capture(
                tester, boundary, '${type.key}-$style-top',
                asset: expectedAsset,
                dialogBounds: tester.getRect(dialog),
                imageBounds: tester.getRect(imageFinder),
                viewportBounds: tester.getRect(scrollView),
                scrollOffset: position.pixels,
                decodedImage: decodedImage));
          }
          await tester.drag(scrollView, const Offset(0, -1600));
          await tester.pumpAndSettle();
          expect(position.extentAfter, closeTo(0, .01));
          final viewport = tester.getRect(scrollView);
          final imageRect = tester.getRect(imageFinder);
          // The footer is in the bottom of the real full-page capture. The
          // renderer footer-content checks are separate; this checks that the
          // app's help dialog does not crop that bottom away from the user.
          expect(imageRect.bottom, lessThanOrEqualTo(viewport.bottom));
          expect(imageRect.bottom, greaterThan(viewport.top));
          expect(imageRect.left, greaterThanOrEqualTo(viewport.left));
          expect(imageRect.right, lessThanOrEqualTo(viewport.right));
          if (configuration.$1 == 393) {
            captures.add(await _capture(
                tester, boundary, '${type.key}-$style-bottom',
                asset: expectedAsset,
                dialogBounds: tester.getRect(dialog),
                imageBounds: imageRect,
                viewportBounds: viewport,
                scrollOffset: position.pixels,
                decodedImage: decodedImage));
          }

          await tester.drag(scrollView, const Offset(0, 1600));
          await tester.pumpAndSettle();
          await _tapVisible(
              tester,
              find.descendant(
                  of: dialog,
                  matching: find.byTooltip(ProxoStrings.text('داخستن'))));
          expect(find.byType(Dialog), findsNothing);
          expect(tester.widget<TextFormField>(name).controller!.text,
              retainedName);
          expect(
              tester.widget<TextFormField>(bio).controller!.text, retainedBio);
          expect(tester.takeException(), isNull);
          examplesSeen.add('${type.key}-$style');
          validatedCases.add({
            'page_type': type.key,
            'style': style,
            'width_dp': configuration.$1,
            'text_scale': configuration.$2,
            'selected_asset_verified': true,
            'image_bottom_reachable': true,
            'form_input_retained': true,
            'close_button_used': true,
          });
        }
      }
      expect(examplesSeen, hasLength(12));
      expect(repository.reads, 0,
          reason: 'Example browsing must not reload or create customer pages.');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
