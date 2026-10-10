import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import '../integration_test/support/native_phase_schedule.dart';

void main() {
  testWidgets('slow first PNG cannot delay the predetermined second request', (tester) async {
    var elapsed = 0, finished = false;
    final requested = <int>[];
    final completed = <int>[];
    final run = scheduleNativePhases(
      phases: [100, 300],
      elapsedMilliseconds: () => elapsed,
      capture: (phase) async {
        requested.add(elapsed);
        await Future<void>.delayed(const Duration(milliseconds: 350));
        completed.add(phase);
      },
    ).then((_) => finished = true);
    elapsed = 100;
    await tester.pump(const Duration(milliseconds: 100));
    expect(requested, [100]);
    elapsed = 300;
    await tester.pump(const Duration(milliseconds: 200));
    expect(requested, [100, 300]);
    expect(completed, isEmpty);
    elapsed = 450;
    await tester.pump(const Duration(milliseconds: 150));
    expect(completed, [100]);
    expect(finished, isFalse);
    elapsed = 650;
    await tester.pump(const Duration(milliseconds: 200));
    await run;
    expect(completed, [100, 300]);
    expect(finished, isTrue);
  });

  testWidgets('a failing phase drains later fixed captures before unmount', (tester) async {
    var elapsed = 0, finished = false;
    final requested = <int>[];
    final run = scheduleNativePhases(
      phases: [100, 300],
      elapsedMilliseconds: () => elapsed,
      capture: (phase) async {
        requested.add(phase);
        if (phase == 100) throw StateError('actual_screen_surface');
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
    );
    final check = expectLater(run, throwsStateError).then((_) => finished = true);
    elapsed = 100;
    await tester.pump(const Duration(milliseconds: 100));
    expect(finished, isFalse);
    elapsed = 300;
    await tester.pump(const Duration(milliseconds: 200));
    expect(requested, [100, 300]);
    expect(finished, isFalse);
    elapsed = 350;
    await tester.pump(const Duration(milliseconds: 50));
    await check;
    expect(finished, isTrue);
  });

  test('already missed phases remain failures', () async {
    await expectLater(scheduleNativePhases(
      phases: [100, 300], elapsedMilliseconds: () => 301,
      capture: (_) async => fail('a missed phase must not capture a later frame'),
    ), throwsStateError);
  });
}
