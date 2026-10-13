import 'dart:async';

// Register every predetermined phase before awaiting any capture/PNG encoding.
// Each phase takes its first read once; no retry, replacement or later selection.
// Future.wait also drains outstanding captures before the screen can unmount.
Future<void> scheduleNativePhases({
  required List<int> phases,
  required int Function() elapsedMilliseconds,
  required Future<void> Function(int phase) capture,
}) async {
  final pending = phases.map((phase) async {
    final remaining = phase - elapsedMilliseconds();
    if (remaining < 0) throw StateError('actual_screen_phase_missed');
    await Future<void>.delayed(Duration(milliseconds: remaining));
    await capture(phase);
  }).toList();
  await Future.wait(pending, eagerError: false);
}
