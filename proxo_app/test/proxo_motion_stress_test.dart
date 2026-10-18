import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proxo_app/theme/app_theme.dart';
import 'package:proxo_app/widgets/auth/auth_swap.dart';
import 'package:proxo_app/widgets/auth/auth_widgets.dart';

void main() {
  testWidgets(
      'rapid repeated channel changes finish on the latest form without ticker leaks',
      (t) async {
    Widget host(String name) => MaterialApp(
        home: Scaffold(
            body: AuthSwap(
                child: SizedBox(
                    key: ValueKey(name),
                    height: name == 'email' ? 300 : 150,
                    child: Text(name)))));
    await t.pumpWidget(host('email'));
    for (var i = 0; i < 30; i++) {
      await t.pumpWidget(host(['email', 'phone', 'signup'][i % 3]));
      await t.pump(const Duration(milliseconds: 8));
      expect(t.takeException(), isNull);
    }
    await t.pumpWidget(host('final-form'));
    final frames = await t.pumpAndSettle(const Duration(milliseconds: 16));
    expect(frames * 16, lessThanOrEqualTo(600));
    expect(find.text('final-form'), findsOneWidget);
    expect(find.text('email'), findsNothing);
    expect(find.text('phone'), findsNothing);
    await t.pumpWidget(const SizedBox());
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'primary action coalesces rapid taps and unlocks after completion',
      (t) async {
    var calls = 0;
    final pending = Completer<void>();
    await t.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
            body: AuthPrimaryButton(
                label: 'Submit',
                onPressed: () async {
                  calls++;
                  if (calls == 1) await pending.future;
                }))));
    for (var i = 0; i < 10; i++) {
      await t.tap(find.byType(FilledButton));
    }
    expect(calls, 1);
    pending.complete();
    await t.pump();
    await t.pump(const Duration(milliseconds: 351));
    await t.tap(find.byType(FilledButton));
    expect(calls, 2);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(milliseconds: 400));
    expect(t.takeException(), isNull);
  });
  testWidgets('Auth text action has a usable touch area beyond the text glyphs',
      (t) async {
    var calls = 0;
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Center(
                child: AuthTextLink(label: 'Back', onTap: () => calls++)))));
    final target = find.byType(InkWell);
    expect(t.getSize(target).height, greaterThanOrEqualTo(44));
    await t.tapAt(t.getCenter(target) + const Offset(0, 18));
    expect(calls, 1);
  });
}
