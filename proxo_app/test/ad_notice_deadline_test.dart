import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/widgets/ad_validation_notifications.dart';

void main() {
  const oldNotice = bool.fromEnvironment('PROXO_REPRODUCE_OLD_NOTICE');
  testWidgets('notice keeps its 400ms deadline after a delayed mounting frame', (t) async {
    final controller = AdValidationController();
    addTearDown(controller.dispose);
    await t.pumpWidget(MaterialApp(home: Scaffold(
      body: AdValidationNotifications(controller: controller))));
    controller.show({'first': 'First error', 'second': 'Second error'});
    // The timers run but no intermediate widget frame is produced. This
    // reproduces a busy first frame without extending the observation deadline.
    await t.pump(const Duration(milliseconds: 180));
    await t.pump(const Duration(milliseconds: 220));
    final fades = t.widgetList<FadeTransition>(find.descendant(
      of: find.byType(AdValidationNotifications), matching: find.byType(FadeTransition)))
      .map((w) => w.opacity.value).toList();
    final sizes = t.widgetList<SizeTransition>(find.descendant(
      of: find.byType(AdValidationNotifications), matching: find.byType(SizeTransition)))
      .map((w) => w.sizeFactor.value).toList();
    expect(fades.length, 2);
    expect(sizes.length, 2);
    if (const bool.fromEnvironment('PROXO_REPRODUCE_OLD_NOTICE')) {
      // Used ONLY by the before-fix source experiment in CI, never acceptance.
      expect(fades.any((v) => v < 1), isTrue);
      expect(sizes.any((v) => v < 1), isTrue);
    } else {
      expect(fades, [1.0, 1.0]);
      expect(sizes, [1.0, 1.0]);
    }
    await t.pump(const Duration(milliseconds: 4500)); // 4900ms, unchanged.
    expect(find.text('First error'), findsOneWidget);
    expect(find.text('Second error'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 600)); // 5500ms, unchanged.
    expect(find.text('First error'), findsNothing);
    expect(find.text('Second error'), oldNotice ? findsNothing : findsOneWidget);
    if (!oldNotice) {
      await t.pump(const Duration(milliseconds: 4700)); // 10200: second still readable
      expect(find.text('Second error'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 600)); // 10800: second has exited
      expect(find.text('Second error'), findsNothing);
    }
    await t.pumpWidget(const SizedBox.shrink());
    expect(t.takeException(), isNull);
  });
}
