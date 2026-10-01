import 'package:flutter/material.dart';
import 'proxo_error_ui.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CustomToast — form-validation snack
// ─────────────────────────────────────────────────────────────────────────────
//
// Usage is unchanged:
//   CustomToast.show(context, "بەشی ئیمەیڵ پڕبکەرەوە");
//   CustomToast.show(context, "وشەی نهێنی هەڵەیە", type: CustomToastType.warning);
//
// Two things were wrong with the old implementation and both were visual:
//
//  1. It was a dark glassmorphism card — a second, competing style in a light
//     app. It now renders through the shared error visual, so a validation
//     message looks like every other message in Proxo.
//
//  2. It was an `OverlayEntry` pinned to `bottom: safeArea + 24`, which put it
//     directly underneath the floating bottom-nav pill (74 dp tall) and on top
//     of the keyboard on form screens. It now goes through `ScaffoldMessenger`
//     with floating behaviour, so Flutter lifts it above the nav bar and above
//     an open keyboard automatically.
//
// Validation *logic* still lives in each screen — this only draws the result.
// ─────────────────────────────────────────────────────────────────────────────

enum CustomToastType { error, warning, success, info }

class CustomToast {
  const CustomToast._();

  static void show(
    BuildContext context,
    String message, {
    CustomToastType type = CustomToastType.error,
    Duration duration = const Duration(seconds: 3),
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
      case CustomToastType.error:   return ProxoErrorTone.danger;
      case CustomToastType.warning: return ProxoErrorTone.warning;
      case CustomToastType.success: return ProxoErrorTone.success;
      case CustomToastType.info:    return ProxoErrorTone.info;
    }
  }
}
