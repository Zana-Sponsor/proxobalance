import 'package:flutter/material.dart';

/// Wraps a scrollable [child] and replaces the default Material overscroll
/// glow with a softer, theme-colored glow when the user scrolls past the
/// top or bottom edge.
///
/// Usage:
/// ```dart
/// WaveOverscroll(
///   child: ListView(...),
/// )
/// ```
class WaveOverscroll extends StatelessWidget {
  final Widget child;
  final Color? color;

  const WaveOverscroll({
    super.key,
    required this.child,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final glowColor = color ?? Theme.of(context).colorScheme.primary;
    return ScrollConfiguration(
      behavior: _WaveScrollBehavior(glowColor),
      child: child,
    );
  }
}

class _WaveScrollBehavior extends ScrollBehavior {
  final Color glowColor;

  const _WaveScrollBehavior(this.glowColor);

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return GlowingOverscrollIndicator(
      axisDirection: details.direction,
      color: glowColor.withOpacity(0.25),
      child: child,
    );
  }
}
