// Capture the real production form, not a reconstruction of TikTok's UI.
// Run explicitly with `flutter test tool/capture_ad_link_example.dart`.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/screens/ad_create_screen.dart';
import 'package:proxo_app/theme/app_theme.dart';
import '../integration_test/support/actual_screen_fixtures.dart';

class ExamplePaintBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

void main() {
  ExamplePaintBinding();
  testWidgets('capture actual ad video-link field', (tester) async {
    final fonts = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
    for (final font in fonts) {
      final loader = FontLoader(font['family'] as String);
      for (final file in font['fonts'] as List) {
        loader.addFont(rootBundle.load(file['asset'] as String));
      }
      await loader.load();
    }
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const sample = 'https://www.tiktok.com/@scout2015/video/6718335390845095173';
    final capture = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: RepaintBoundary(
        key: capture,
        child: AdCreateScreen(repository: ActualAdRepository()),
      ),
    ));
    await tester.pumpAndSettle();
    final link = find.byKey(const ValueKey('ad-link'));
    final controller = tester.widget<TextField>(link).controller!;
    controller.text = sample;
    controller.selection = const TextSelection.collapsed(offset: 0);
    await tester.pumpAndSettle();
    expect(controller.text, sample);
    final field = tester.getRect(link);
    expect(field.top, greaterThan(0));
    expect(field.bottom, lessThan(852));
    expect(tester.takeException(), isNull);
    // Native render-layer crop of the real label and URL field. Keep the
    // unrelated empty fields and the next row outside this focused capture.
    // No retouching, synthesized UI, or external/cost-bearing request.
    final bounds = Rect.fromLTRB(
        (field.left - 12).floorToDouble(), (field.top - 42).floorToDouble(),
        (field.right + 12).ceilToDouble(), (field.bottom + 8).ceilToDouble());
    final render = capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await (render.layer! as OffsetLayer).toImage(bounds, pixelRatio: 3);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      final output = Directory('build/example-source')..createSync(recursive: true);
      File('${output.path}/ad_video_link_example.png').writeAsBytesSync(bytes);
      File('${output.path}/capture.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
        'source': 'Actual AdCreateScreen and production theme rendered by Flutter',
        'fixture': 'Isolated read-only ActualAdRepository; no advertisement submitted',
        'image_kind': 'Screenshot of the real Proxo form, not a TikTok app screenshot',
        'viewport_dp': [393, 852],
        'capture_bounds_dp': [bounds.left, bounds.top, bounds.width, bounds.height],
        'pixels': [image.width, image.height],
        'dpr': 3,
        'sample_url': sample,
        'sample_url_source': 'https://developers.tiktok.com/docs/en/embed-videos',
        'layout_exceptions': [],
      }));
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
