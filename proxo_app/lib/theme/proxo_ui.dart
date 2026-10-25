import 'package:flutter/material.dart';

import '../widgets/auth/auth_design.dart';
import 'app_theme.dart';

/// Shared mobile values, anchored to the existing authentication screens.
abstract final class ProxoUi {
  static const double gap4 = 4;
  static const double gap8 = 8;
  static const double gap12 = 12;
  static const double gap16 = 16;
  static const double gap24 = 24;
  static const double gap32 = 32;
  static const double pagePadding = 16;
  static const double cardPadding = 16;
  static const double radius = 16;
  static const double controlRadius = AuthTokens.buttonRadius;
  static const double controlHeight = AuthTokens.buttonHeight;
  static const double iconSize = 20;
  static const double touchTarget = 48;

  static const Color background = AuthTokens.pageBackground;
  static const Color surface = Colors.white;
  static const Color primary = AuthTokens.primary;
  static const Color ink = AuthTokens.ink;
  static const Color muted = AuthTokens.inkMuted;
  static const Color border = AuthTokens.line;
  static const Color soft = AuthTokens.fieldFillOff;

  static const TextStyle title = AuthTokens.title;
  static const TextStyle sectionTitle = AuthTokens.title;
  static const TextStyle cardTitle = AuthTokens.fieldLabel;
  static const TextStyle body = AuthTokens.fieldText;
  static const TextStyle secondary = AuthTokens.subtitle;
  static const TextStyle label = AuthTokens.fieldLabel;
  static const TextStyle status = TextStyle(
    fontFamily: kAppFont,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: muted,
  );
  static const TextStyle amount = TextStyle(
    fontFamily: kAppFont,
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static BoxDecoration cardDecoration = BoxDecoration(
    color: surface,
    border: Border.all(color: border),
    borderRadius: BorderRadius.circular(radius),
  );
}

/// Controls inherit the same sizes, colors, and readable text across screens.
ThemeData buildProxoTheme() => ThemeData(
      useMaterial3: true,
      fontFamily: kAppFont,
      scaffoldBackgroundColor: ProxoUi.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ProxoUi.primary,
        primary: ProxoUi.primary,
        surface: ProxoUi.surface,
        error: AuthTokens.danger,
      ),
      textTheme: const TextTheme(
        headlineSmall: ProxoUi.title,
        titleLarge: ProxoUi.title,
        titleMedium: ProxoUi.sectionTitle,
        titleSmall: ProxoUi.cardTitle,
        bodyLarge: ProxoUi.body,
        bodyMedium: ProxoUi.body,
        bodySmall: ProxoUi.secondary,
        labelLarge: ProxoUi.label,
        labelMedium: ProxoUi.status,
      ),
      iconTheme:
          const IconThemeData(size: ProxoUi.iconSize, color: ProxoUi.ink),
      dividerTheme: const DividerThemeData(color: ProxoUi.border, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ProxoUi.surface,
        labelStyle: ProxoUi.label,
        hintStyle: ProxoUi.secondary,
        contentPadding: AuthTokens.fieldContentPadding,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ProxoUi.controlRadius),
          borderSide: const BorderSide(color: ProxoUi.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ProxoUi.controlRadius),
          borderSide: const BorderSide(color: ProxoUi.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ProxoUi.controlRadius),
          borderSide: const BorderSide(color: ProxoUi.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, ProxoUi.controlHeight),
          textStyle: AuthTokens.buttonText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ProxoUi.controlRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, ProxoUi.controlHeight),
          textStyle: ProxoUi.label,
          side: const BorderSide(color: ProxoUi.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ProxoUi.controlRadius),
          ),
        ),
      ),
    );
