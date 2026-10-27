import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/proxo_surface.dart';
import '../theme/proxo_chrome.dart';
import 'proxo_notice.dart';

/// Compatibility entry point for one temporary notification. New messages
/// replace the old one; duplicates neither stack nor extend its deadline.
class ProxoErrorStack {
  ProxoErrorStack._();
  static OverlayEntry? _entry;
  static String? _message;
  static ModalRoute<dynamic>? _route;
  static int _generation = 0;

  static void show(
    BuildContext context,
    String message, {
    // Temporary notices use a short readable lifetime; actions stay available.
    Duration duration = proxoNoticeDuration,
    TextStyle? textStyle,
    String? actionLabel,
    VoidCallback? onAction,
    TextDirection direction = TextDirection.rtl,
    ProxoNoticeTone tone = ProxoNoticeTone.error,
  }) {
    if (!context.mounted || message.trim().isEmpty) return;
    // Retained tabs share one route. Query their current visibility without
    // subscribing the calling screen to notifier rebuilds.
    if (!TickerMode.getValuesNotifier(context).value.enabled) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final route = ModalRoute.of(context);
    // An async request from a covered screen must not announce its result on
    // the screen the user has since opened.
    if (route != null && !route.isCurrent) return;
    final text = message.trim();
    if (_entry != null && _message == text && _route == route) return;
    clear();
    final generation = ++_generation;
    _message = text;
    _route = route;
    void dismiss() {
      if (_generation == generation) clear();
    }

    _entry = OverlayEntry(
        builder: (context) => Positioned(
              top: MediaQuery.paddingOf(context).top +
                  ProxoChrome.toolbarHeight +
                  8,
              left: ProxoSurface.gutter,
              right: ProxoSurface.gutter,
              child: Center(
                  child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: ProxoTimedNotice(
                  key: ValueKey(generation),
                  duration: onAction != null && actionLabel != null
                      ? null
                      : proxoNoticeReadingTime(text),
                  onExpired: dismiss,
                  onDisposed: () => _detach(generation),
                  child: ProxoNoticeCard(
                    onDismiss: dismiss,
                    message: text,
                    tone: tone,
                    direction: direction,
                    textStyle: textStyle,
                    actionLabel: actionLabel,
                    onAction: onAction == null
                        ? null
                        : () {
                            dismiss();
                            onAction();
                          },
                  ),
                ),
              )),
            ));
    overlay.insert(_entry!);
    // A closing screen must not leave feedback over its destination.
    route?.popped.then((_) => dismiss());
  }

  static void _detach(int generation) {
    if (_generation != generation) return;
    ++_generation;
    _message = null;
    _route = null;
    final entry = _entry;
    _entry = null;
    // The enclosing Navigator/Overlay may be removed without popping its
    // route. Release the entry after the current widget teardown completes.
    scheduleMicrotask(() {
      entry?.remove();
      entry?.dispose();
    });
  }

  static void clear() {
    ++_generation;
    _message = null;
    _route = null;
    final entry = _entry;
    _entry = null;
    entry?.remove();
    entry?.dispose();
  }
}

/// Clear screen-scoped feedback when the visible route changes. This keeps
/// navigation independent of both request state and notification timers.
class ProxoNoticeObserver extends NavigatorObserver {
  static final instance = ProxoNoticeObserver();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    ProxoErrorStack.clear();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    ProxoErrorStack.clear();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (ProxoErrorStack._route == route) ProxoErrorStack.clear();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (ProxoErrorStack._route == oldRoute) ProxoErrorStack.clear();
  }
}
