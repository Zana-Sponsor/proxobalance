import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/proxo_surface.dart';
import '../l10n/proxo_strings.dart';
import 'proxo_symbol.dart';
import 'proxo_text.dart';

/// The lifetime starts after the first rendered frame, not when a request ends.
const proxoNoticeDuration = Duration(milliseconds: 2000);

Duration proxoNoticeReadingTime(String message) => message.runes.length > 80
    ? const Duration(seconds: 3)
    : proxoNoticeDuration;

enum ProxoNoticeTone { error, warning, success, info }

/// A content-sized, non-modal notification shared by forms and global feedback.
class ProxoNoticeCard extends StatelessWidget {
  const ProxoNoticeCard(
      {super.key,
      required this.message,
      this.tone = ProxoNoticeTone.error,
      this.direction = TextDirection.rtl,
      this.textStyle,
      this.actionLabel,
      this.onAction,
      this.onDismiss});
  final String message;
  final ProxoNoticeTone tone;
  final TextDirection direction;
  final TextStyle? textStyle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      ProxoNoticeTone.error => const Color(0xFFB42318),
      ProxoNoticeTone.warning => const Color(0xFF9A6700),
      ProxoNoticeTone.success => const Color(0xFF15803D),
      ProxoNoticeTone.info => ProxoSurface.accent,
    };
    final symbol = switch (tone) {
      ProxoNoticeTone.error ||
      ProxoNoticeTone.warning =>
        ProxoSymbolName.warning,
      ProxoNoticeTone.success => ProxoSymbolName.check,
      ProxoNoticeTone.info => ProxoSymbolName.info,
    };
    return RepaintBoundary(
        child: Semantics(
      liveRegion: true,
      child: Directionality(
        textDirection: direction,
        child: Material(
          type: MaterialType.transparency,
          child: Stack(children: [
            Positioned.fill(
                child: IgnorePointer(
                    child: DecoratedBox(
                        decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(ProxoSurface.controlRadius),
              border: Border.all(color: ProxoSurface.line),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x140F172A),
                    blurRadius: 16,
                    offset: Offset(0, 4))
              ],
            )))),
            Padding(
              padding: const EdgeInsets.all(12),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                IgnorePointer(
                    child: ProxoSymbol(symbol, size: 20, color: color)),
                const SizedBox(width: 12),
                Expanded(
                    child: IgnorePointer(
                        child: ProxoText(message,
                            style: textStyle ?? ProxoSurface.body))),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                      child: TextButton(
                          style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              foregroundColor: ProxoSurface.accent,
                              textStyle: ProxoSurface.body),
                          onPressed: onAction,
                          child: ProxoText(actionLabel!,
                              textAlign: TextAlign.center))),
                ],
                if (onDismiss != null)
                  IconButton(
                    key: const ValueKey('notice-dismiss'),
                    tooltip: ProxoStrings.text('داخستن'),
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                    onPressed: onDismiss,
                    icon: const ProxoSymbol(ProxoSymbolName.close,
                        size: 18, color: ProxoSurface.muted),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    ));
  }
}

/// Owns only notification lifetime. It never changes request or form state.
class ProxoTimedNotice extends StatefulWidget {
  const ProxoTimedNotice(
      {super.key,
      required this.child,
      required this.onExpired,
      this.duration = proxoNoticeDuration,
      this.onDisposed});
  final Widget child;
  final VoidCallback onExpired;
  final VoidCallback? onDisposed;

  /// Null keeps an action-required notice available until dismissed.
  final Duration? duration;
  @override
  State<ProxoTimedNotice> createState() => _ProxoTimedNoticeState();
}

class _ProxoTimedNoticeState extends State<ProxoTimedNotice> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.duration == null) return;
      _timer = Timer(widget.duration!, () {
        if (mounted) widget.onExpired();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.onDisposed?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
