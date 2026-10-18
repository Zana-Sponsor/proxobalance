import 'package:flutter/material.dart';

import 'auth_design.dart';

/// Retiring forms never affect the new form's height, focus or semantics.
class AuthSwap extends StatelessWidget {
  const AuthSwap({
    super.key,
    required this.child,
    this.duration = AuthTokens.viewTransition,
  });
  final Widget child;
  final Duration duration;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [
            ...previous.map(
              (w) => Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: ExcludeFocus(child: ExcludeSemantics(child: w)),
                ),
              ),
            ),
            if (current != null) current,
          ],
        ),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.018),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: child,
      ),
    );
  }
}
