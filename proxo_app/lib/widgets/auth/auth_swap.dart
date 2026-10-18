import 'dart:async';
import 'package:flutter/material.dart';
import 'auth_design.dart';

/// Fade the old form away before revealing the next. Fields never overlap,
/// keep their controllers, and cannot receive taps during a transition.
class AuthSwap extends StatefulWidget {
  const AuthSwap(
      {super.key,
      required this.child,
      this.duration = AuthTokens.viewTransition});
  final Widget child;
  final Duration duration;
  @override
  State<AuthSwap> createState() => _AuthSwapState();
}

class _AuthSwapState extends State<AuthSwap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
      vsync: this,
      value: 1,
      duration: widget.duration * .6,
      reverseDuration: widget.duration * .4);
  late Widget _visible = widget.child;
  int _generation = 0;
  @override
  void didUpdateWidget(covariant AuthSwap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (Widget.canUpdate(_visible, widget.child)) {
      _visible = widget.child;
      if (_fade.status == AnimationStatus.reverse) {
        ++_generation;
        _fade.forward();
      }
    } else if (!Widget.canUpdate(oldWidget.child, widget.child)) {
      unawaited(_replace());
    }
  }

  Future<void> _replace() async {
    final generation = ++_generation;
    if (MediaQuery.disableAnimationsOf(context)) {
      _visible = widget.child;
      _fade.value = 1;
      return;
    }
    try {
      await _fade.reverse().orCancel;
      if (!mounted || generation != _generation) return;
      setState(() => _visible = widget.child);
      await _fade.forward().orCancel;
    } on TickerCanceled {/* Route disposed or superseded. */}
  }

  @override
  void dispose() {
    ++_generation;
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return _visible;
    return AnimatedSize(
      duration: widget.duration,
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedBuilder(
          animation: _fade,
          builder: (context, child) => IgnorePointer(
              ignoring: _fade.isAnimating,
              child: ExcludeSemantics(
                  excluding: _fade.status == AnimationStatus.reverse,
                  child: FadeTransition(
                      opacity: _fade,
                      child: Transform.translate(
                          offset: Offset(0, 8 * (1 - _fade.value)),
                          child: child)))),
          child: _visible),
    );
  }
}
