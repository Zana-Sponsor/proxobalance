import 'package:flutter/material.dart';

import 'proxo_design_tokens.dart';

/// Shared content hierarchy for app surfaces, using Auth's real regular face.
/// Dimensions are logical pixels; text always follows the user's text scaler.
abstract final class ProxoSurface {
  static const double gutter = 20;
  static const double maxWidth = 600;
  static const double padding = 16;
  static const double sectionGap = ProxoDesign.sectionGap;
  static const double radius = 16;
  static const double controlRadius = 12;
  static const double actionHeight = ProxoDesign.controlHeight;
  static const String fontFamily = ProxoDesign.font;
  static const Color ink = ProxoDesign.ink;
  static const Color muted = ProxoDesign.muted;
  static const Color line = ProxoDesign.line;
  static const Color accent = ProxoDesign.blue;
  static const Color accentSoft = ProxoDesign.blueSoft;

  static const TextStyle title = TextStyle(
      fontFamily: fontFamily,
      fontSize: 18,
      height: 1.5,
      fontWeight: FontWeight.w500,
      color: ink);
  static const TextStyle section = TextStyle(
      fontFamily: fontFamily,
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w500,
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
