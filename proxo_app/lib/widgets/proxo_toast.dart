import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'proxo_error_ui.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Proxo Toast — the app's lightweight message surface
// ─────────────────────────────────────────────────────────────────────────────
//
// The public API is unchanged: every existing `showProxoToast(...)` call site
// keeps working exactly as before, with its own wording and its own decision
// about when to fire.
//
// What changed is only the paint. The bespoke SnackBar body that used to live
// here has moved to `proxo_error_ui.dart`, so this surface now looks identical
// to the inline banners, sheets, dialogs and full error states everywhere else
// in the app — same tinted surface, same icon well, same typography, same
// radius, same shadow, same entrance.
// ─────────────────────────────────────────────────────────────────────────────

enum ProxoToastType { error, success, warning, info, noInternet }

void showProxoToast(
  BuildContext context,
  String message, {
  bool isError = true,
  ProxoToastType? type,
  Duration duration = const Duration(seconds: 4),
  String? actionLabel,
  VoidCallback? onAction,
  TextDirection textDirection = TextDirection.rtl,
  String fontFamily = kAppFont,
}) {
  final toastType =
      type ?? (isError ? ProxoToastType.error : ProxoToastType.success);
  showProxoErrorSnack(
    context,
    message,
    tone: proxoToneForToast(toastType),
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
    textDirection: textDirection,
    fontFamily: fontFamily,
  );
}

void showProxoNoInternetToast(BuildContext context) {
  showProxoErrorSnack(
    context,
    'پەیوەندیت بە ئینتەرنێت نییە — ئینتەرنێتەکەت بپشکنەوە',
    tone: ProxoErrorTone.offline,
    duration: const Duration(seconds: 5),
  );
}

/// Maps this screen-facing type onto the shared visual tone. Kept public so a
/// screen that already has a `ProxoToastType` in hand can reuse it when it
/// needs an inline banner or a sheet instead of a toast.
ProxoErrorTone proxoToneForToast(ProxoToastType type) {
  switch (type) {
    case ProxoToastType.error:      return ProxoErrorTone.danger;
    case ProxoToastType.success:    return ProxoErrorTone.success;
    case ProxoToastType.warning:    return ProxoErrorTone.warning;
    case ProxoToastType.info:       return ProxoErrorTone.info;
    case ProxoToastType.noInternet: return ProxoErrorTone.offline;
  }
}
