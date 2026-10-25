import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_iconkit/solar_iconkit.dart';
import 'package:proxo_app/theme/proxo_ui.dart';
import 'package:proxo_app/widgets/bottom_nav.dart';
import 'package:proxo_app/widgets/proxo_empty_state.dart';

void main() {
  for (final width in [320.0, 430.0]) {
    testWidgets(
        'empty state wraps Kurdish text and keeps action reachable at $width',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 568);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var creations = 0;
      await tester.pumpWidget(MaterialApp(
        theme: buildProxoTheme(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 568),
              textScaler: const TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: ProxoEmptyState(
                  icon: const SolarIcon(SolarIcons.documentText),
                  title: 'هێشتا هیچ پەڕەیەکت دروست نەکردووە',
                  description:
                      'یەکەم پەڕەکەت دروست بکە و زانیارییەکانی کارەکەت لەگەڵ کڕیارەکان هاوبەش بکە.',
                  actionLabel: 'دروستکردنی پەڕە',
                  onAction: () => creations++,
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final button = find.byType(FilledButton);
      await tester.ensureVisible(button);
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      expect(tester.getRect(button).left, greaterThanOrEqualTo(0));
      expect(tester.getRect(button).right, lessThanOrEqualTo(width));
      await tester.tap(button);
      expect(creations, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('bottom navigation uses SVG and delivers every destination',
      (tester) async {
    final destinations = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: ProxoBottomNav(
          currentIndex: 0,
          onTap: destinations.add,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(SolarIcon), findsNWidgets(5));
    for (final label in ['سەرەکی', 'ڕیکلامەکان', 'ئامرازەکان', 'پڕۆفایل']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byWidgetPredicate(
        (widget) => widget is SolarIcon && widget.name == SolarIcons.add));
    await tester.pumpAndSettle();
    expect(destinations, [0, 1, 3, 4, 2]);
    expect(tester.takeException(), isNull);
  });
}
