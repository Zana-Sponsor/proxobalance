import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Screenshots are rendered by Flutter from the actual production widgets.
/// Supply fixture repositories at the screen boundary; do not contact live APIs.
const visualCaptureKey = ValueKey<String>('proxo-visual-capture');
const visualCaptureDirectory = String.fromEnvironment('PROXO_CAPTURE_DIR');

class ProxoVisualBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get disableShadows => false;
}

Future<void> loadVisualFonts() async {
  for (final family in ['Rabar', 'ProxoReceipt']) {
    await (FontLoader(family)
          ..addFont(rootBundle.load('assets/fonts/Rabar_021.ttf')))
        .load();
  }
  await (FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
      .load();
}

/// Wrap an entire screen/MaterialApp, or place around a scroll view's content
/// to capture the complete section instead of just its visible viewport.
Widget visualCapture(Widget child) => RepaintBoundary(
      key: visualCaptureKey,
      child: child,
    );

void setVisualViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// [name] should state the screen, state, and logical viewport dimensions.
/// This is opt-in to avoid overwriting repository images during ordinary tests.
Future<void> captureVisual(WidgetTester tester, String name) async {
  if (visualCaptureDirectory.isEmpty) return;
  assert(RegExp(r'^[a-z0-9_-]+$').hasMatch(name));
  // Asset decoding can finish after pumpAndSettle on the first screen.
  // Warm the real shared wordmark before taking the frame.
  await tester.runAsync(() => precacheImage(
        const AssetImage('assets/images/proxo_logo.png'),
        tester.element(find.byKey(visualCaptureKey)),
      ));
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(visualCaptureKey),
  );
  await tester.runAsync(() async {
    final directory = Directory(visualCaptureDirectory);
    await directory.create(recursive: true);
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('${directory.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
