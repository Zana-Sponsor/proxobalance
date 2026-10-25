import 'package:flutter/material.dart';

import 'proxo_design_tokens.dart';
import 'ad_form_colors.dart';

/// Approved TikTok geometry and price bar, backed by the shared app palette.
abstract final class TikTokAdTokens {
  static const fontFamily = ProxoDesign.font;
  static const ink = ProxoDesign.ink;
  static const muted = ProxoDesign.muted;
  static const blue = ProxoDesign.blue;
  static const blueSoft = ProxoDesign.blueSoft;
  static const line = ProxoDesign.line;
  static const fieldLine = ProxoDesign.line;
  static const fieldFill = ProxoDesign.surface;
  // Sampled from the supplied JPEG's app screen; see the palette evidence.
  static const secondaryBlue = ProxoDesign.secondaryBlue;
  static const selectedLine = ProxoDesign.blueInk;
  static const pageFill = ProxoDesign.softSurface;
  static const pageLine = Color(0xFFCCD9E6);
  static const newBadge = Color(0xFFFE6F61);
  static const colors = AdFormColors(
    primary: blue,
    ink: ink,
    muted: muted,
    line: line,
    surface: pageFill,
    selectedFill: blueSoft,
    selectedLine: selectedLine,
  );
  static const gutter = 20.0;
  static const headingGap = 16.0;
  static const sectionGap = 32.0;
  static const controlGap = 12.0;
  static const helperGap = 8.0;
  static const controlHeight = 50.0;
  static const inputHeight = 56.0;
  static const controlRadius = BorderRadius.all(Radius.circular(12));
  // Latest approved long rectangle: 10dp corners, directly above navigation.
  static const priceRadius = BorderRadius.all(Radius.circular(10));
  static const priceNavGap = 0.0;
  static const priceCollapsedHeight = 64.0;
  static const transition = Duration(milliseconds: 180);
  static const priceTransition = Duration(milliseconds: 200);
  static const controlShadow = [
    BoxShadow(color: Color(0x08000000), blurRadius: 5, offset: Offset(0, 2)),
  ];
  static const selectedShadow = [
    BoxShadow(color: Color(0x100278FE), blurRadius: 6, offset: Offset(0, 2)),
  ];
  static const priceShadow = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, -2)),
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
      fontWeight: FontWeight.w600,
      height: 1.5,
      color: ink);
  static const totalAmount = TextStyle(
      fontFamily: fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.5,
      color: blue);

  static ThemeData theme(ThemeData base) => base.copyWith(
        extensions: [
          ...base.extensions.values.where((e) => e is! AdFormColors),
          colors
        ],
        colorScheme: base.colorScheme.copyWith(
          primary: blue,
          onPrimary: Colors.white,
          primaryContainer: blueSoft,
          onPrimaryContainer: secondaryBlue,
          secondary: secondaryBlue,
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: ink,
          onSurfaceVariant: muted,
          outline: line,
          outlineVariant: line,
        ),
        textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
        iconTheme: base.iconTheme.copyWith(color: ink),
        dividerColor: line,
        disabledColor: muted,
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: blue,
          selectionColor: Color(0x330278FE),
          selectionHandleColor: blue,
        ),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          fillColor: fieldFill,
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
            overlayColor: const Color(0x140278FE)),
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
