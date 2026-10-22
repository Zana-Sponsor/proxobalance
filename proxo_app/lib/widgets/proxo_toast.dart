import '../l10n/proxo_strings.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'proxo_error_ui.dart';
import 'proxo_notice.dart';

// Screen-facing compatibility API for the shared two-second notice.

enum ProxoToastType { error, success, warning, info, noInternet }

void showProxoToast(
  BuildContext context,
  String message, {
  bool isError = true,
  ProxoToastType? type,
  Duration duration = proxoNoticeDuration,
  String? actionLabel,
  VoidCallback? onAction,
  TextDirection textDirection = TextDirection.rtl,
  String fontFamily = kAppFont,
}) {
  final toastType =
      type ?? (isError ? ProxoToastType.error : ProxoToastType.success);
  showProxoErrorSnack(
    context,
    ProxoStrings.text(message),
    tone: proxoToneForToast(toastType),
    duration: duration,
    actionLabel: actionLabel == null ? null : ProxoStrings.text(actionLabel),
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
    duration: proxoNoticeDuration,
  );
}

/// Maps this screen-facing type onto the shared visual tone. Kept public so a
/// screen that already has a `ProxoToastType` in hand can reuse it when it
/// needs an inline banner or a sheet instead of a toast.
ProxoErrorTone proxoToneForToast(ProxoToastType type) {
  switch (type) {
    case ProxoToastType.error:
      return ProxoErrorTone.danger;
    case ProxoToastType.success:
      return ProxoErrorTone.success;
    case ProxoToastType.warning:
      return ProxoErrorTone.warning;
    case ProxoToastType.info:
      return ProxoErrorTone.info;
    case ProxoToastType.noInternet:
      return ProxoErrorTone.offline;
  }
}
