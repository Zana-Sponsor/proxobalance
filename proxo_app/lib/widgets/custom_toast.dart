import 'package:flutter/material.dart';
import 'proxo_error_ui.dart';
import 'proxo_notice.dart';

// Screen-facing compatibility API for the shared two-second notice.

enum CustomToastType { error, warning, success, info }

class CustomToast {
  const CustomToast._();

  static void show(
    BuildContext context,
    String message, {
    CustomToastType type = CustomToastType.error,
    Duration duration = proxoNoticeDuration,
    TextDirection textDirection = TextDirection.rtl,
  }) {
    showProxoErrorSnack(
      context,
      message,
      tone: _tone(type),
      duration: duration,
      textDirection: textDirection,
    );
  }

  static ProxoErrorTone _tone(CustomToastType type) {
    switch (type) {
      case CustomToastType.error:
        return ProxoErrorTone.danger;
      case CustomToastType.warning:
        return ProxoErrorTone.warning;
      case CustomToastType.success:
        return ProxoErrorTone.success;
      case CustomToastType.info:
        return ProxoErrorTone.info;
    }
  }
}
