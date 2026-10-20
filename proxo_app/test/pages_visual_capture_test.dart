import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/models/proxo_card.dart';
import 'package:proxo_app/screens/tools_screen.dart';
import 'package:proxo_app/services/proxolink_service.dart';
import 'package:proxo_app/theme/proxo_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages_flow_test.dart' show ControlledPages;
import 'proxo_four_flow_test.dart' show field, fill;
import 'support/visual_capture.dart';

void main() {
  ProxoVisualBinding();
  setUpAll(loadVisualFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget host(ControlledPages pages) => visualCapture(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildProxoTheme(),
        home: ToolsScreen(repository: pages),
      ));

  for (final size in [const Size(320, 740), const Size(430, 932)]) {
    final dimensions = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('Pages visual flow $dimensions', (t) async {
      setVisualViewport(t, size);
      final repo = ControlledPages()..initial = Completer<List<ProxoCard>>();
      await t.pumpWidget(host(repo));
      await t.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await captureVisual(t, 'pages-loading-$dimensions');
      repo.initial!.completeError(const ProxoLinkFailure('network_error'));
      await t.pumpAndSettle();
      expect(find.text('نەتوانرا پەڕەکان پیشان بدرێن'), findsOneWidget);
      await captureVisual(t, 'pages-retrieval-error-$dimensions');
      await t.tap(find.text('دووبارە هەوڵبدەرەوە'));
      await t.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      await captureVisual(t, 'pages-empty-$dimensions');
      await t.tap(find.text('دروستکردنی پەڕە'));
      await t.pumpAndSettle();
      await captureVisual(t, 'pages-create-top-$dimensions');

      final submit = find.text('دروستکردن');
      await t.ensureVisible(submit);
      await t.tap(submit);
      await t.pumpAndSettle();
      expect(repo.saves, 0);
      await t.ensureVisible(field('ناو'));
      await t.pumpAndSettle();
      await captureVisual(t, 'pages-create-validation-$dimensions');
      await fill(t, 'ناو', 'پەڕەی نموونەی Proxo 2026');
      await fill(t, 'ناوی تیکتۆک', '@proxo_demo');
      // Capture the populated fields and then the remaining bottom controls.
      await t.pumpAndSettle();
      await captureVisual(t, 'pages-create-fields-$dimensions');
      await t.ensureVisible(submit);
      await t.pumpAndSettle();
      await captureVisual(t, 'pages-create-bottom-$dimensions');
      await t.tap(submit);
      await t.pumpAndSettle();
      expect(repo.saves, 1);
      expect(find.text('پەڕەی نموونەی Proxo 2026'), findsOneWidget);
      await captureVisual(t, 'pages-created-$dimensions');
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(host(repo));
      await t.pumpAndSettle();
      expect(find.text('پەڕەی نموونەی Proxo 2026'), findsOneWidget);
      await captureVisual(t, 'pages-reopened-fixture-$dimensions');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pumpAndSettle();
    });
  }
}
