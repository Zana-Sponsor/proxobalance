import 'package:flutter/material.dart';

import '../widgets/auth/auth_design.dart';
import 'app_theme.dart';

/// Shared content hierarchy for app surfaces, using Auth's real regular face.
/// Dimensions are logical pixels; text always follows the user's text scaler.
abstract final class ProxoSurface {
  static const double gutter = 20;
  static const double maxWidth = 600;
  static const double padding = 16;
  static const double sectionGap = 24;
  static const double radius = 16;
  static const double controlRadius = 12;
  static const double actionHeight = 48;
  static const String fontFamily = AuthTokens.fontFamily;
  static const Color ink = AuthTokens.ink;
  static const Color muted = AuthTokens.inkMuted;
  static const Color line = AuthTokens.line;
  static const Color accent = AppColors.accent;
  static const Color accentSoft = AuthTokens.accentSoft;

  static const TextStyle title = TextStyle(
      fontFamily: fontFamily,
      fontSize: 18,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: ink);
  static const TextStyle section = TextStyle(
      fontFamily: fontFamily,
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: ink);
  static const TextStyle body = TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: ink);
  static const TextStyle secondary = TextStyle(
      fontFamily: fontFamily,
      fontSize: 13,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: muted);
  static const TextStyle amount = TextStyle(
      fontFamily: fontFamily,
      fontSize: 22,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: ink);

  static ButtonStyle actionStyle() => FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(actionHeight),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: accent,
        foregroundColor: Colors.white,
        textStyle: body,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(controlRadius)),
      );
}
