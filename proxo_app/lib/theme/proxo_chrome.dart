import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'proxo_design_tokens.dart';

/// Shared navigation/profile dimensions. Text keeps the user's text scaler.
abstract final class ProxoChrome {
  static const iconSize = 24.0;
  static const toolbarIconSize = 22.0;
  static const toolbarHeight = 56.0;
  static const actionSize = 48.0;
  static const labelSize = 14.0;
  static const radius = 16.0;
  static const surface = ProxoDesign.softSurface;
  static const selected = ProxoDesign.blueSoft;
  static const border = ProxoDesign.line;
  static const label = TextStyle(
      fontFamily: ProxoDesign.font,
      fontSize: labelSize,
      height: 1.5,
      color: AppColors.ink);
}
