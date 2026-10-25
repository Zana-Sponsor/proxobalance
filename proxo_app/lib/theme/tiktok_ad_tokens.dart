import 'package:flutter/material.dart';

import 'proxo_surface.dart';

/// Visual tokens for the open TikTok creation form. Auth's bundled regular
/// face is retained; receipt, Meta, and navigation defaults stay independent.
abstract final class TikTokAdTokens {
  static const fontFamily = ProxoSurface.fontFamily;
  static const ink = ProxoSurface.ink;
  static const muted = ProxoSurface.muted;
  static const blue = Color(0xFF2F70C7);
  static const blueSoft = Color(0xFFEDF4FC);
  static const line = Color(0xFFCBD5E1);
  static const fieldLine = Color(0xFFE2E8F0);
  static const fieldFill = Color(0xFFFCFDFF);
  static const gutter = 20.0;
  static const headingGap = 16.0;
  static const sectionGap = 32.0;
  static const controlGap = 12.0;
  static const helperGap = 8.0;
  static const controlHeight = 50.0;
  static const inputHeight = 56.0;
  static const controlRadius = BorderRadius.all(Radius.circular(12));
  static const priceRadius = BorderRadius.all(Radius.circular(10));
  static const priceNavGap = 2.0;
  static const priceCollapsedHeight = 72.0;
  static const transition = Duration(milliseconds: 180);
  static const priceTransition = Duration(milliseconds: 200);
  static const controlShadow = [
    BoxShadow(color: Color(0x080F172A), blurRadius: 5, offset: Offset(0, 2)),
  ];
  static const selectedShadow = [
    BoxShadow(color: Color(0x102F70C7), blurRadius: 6, offset: Offset(0, 2)),
  ];
  static const priceShadow = [
    BoxShadow(color: Color(0x100F172A), blurRadius: 12, offset: Offset(0, -3)),
  ];

  static const appBar = TextStyle(
      fontFamily: fontFamily,
      fontSize: 18,
      fontWeight: FontWeight.w500,
      height: 1.5,
      color: ink);
  static const heading = TextStyle(
      fontFamily: fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.5,
      color: ink);
  static const label = TextStyle(
      fontFamily: fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w500,
      height: 1.5,
      color: ink);
  static const field = TextStyle(
      fontFamily: fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: ink);
  static const choice = TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.5,
      color: ink);
  static const helper = TextStyle(
      fontFamily: fontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: muted);
  static const priceLabel = TextStyle(
      fontFamily: fontFamily,
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: ink);
  static const priceAmount = TextStyle(
      fontFamily: fontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.5,
      color: ink);
  static const totalLabel = TextStyle(
      fontFamily: fontFamily,
      fontSize: 15,
      fontWeight: FontWeight.w500,
      height: 1.5,
      color: ink);
  static const totalAmount = TextStyle(
      fontFamily: fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.5,
      color: blue);

  static ThemeData theme(ThemeData base) => base.copyWith(
        colorScheme: base.colorScheme.copyWith(primary: blue),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          constraints: const BoxConstraints(minHeight: inputHeight),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          hintStyle: helper,
          border: const OutlineInputBorder(borderRadius: controlRadius),
          enabledBorder: const OutlineInputBorder(
              borderRadius: controlRadius,
              borderSide: BorderSide(color: fieldLine)),
          focusedBorder: const OutlineInputBorder(
              borderRadius: controlRadius, borderSide: BorderSide(color: blue)),
        ),
        sliderTheme: base.sliderTheme.copyWith(
            activeTrackColor: blue,
            thumbColor: blue,
            inactiveTrackColor: blueSoft,
            overlayColor: const Color(0x142F70C7)),
        filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
          backgroundColor: blue,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: choice,
          shape: const RoundedRectangleBorder(borderRadius: controlRadius),
        )),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
          foregroundColor: blue,
          minimumSize: const Size(0, controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: choice,
          side: const BorderSide(color: line),
          shape: const RoundedRectangleBorder(borderRadius: controlRadius),
        )),
        textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
          foregroundColor: blue,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          textStyle: helper,
        )),
      );
}
