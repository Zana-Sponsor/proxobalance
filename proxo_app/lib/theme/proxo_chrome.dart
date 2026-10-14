import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Shared navigation/profile dimensions. Text keeps the user's text scaler.
abstract final class ProxoChrome {
  static const iconSize = 24.0;
  static const actionSize = 48.0;
  static const labelSize = 14.0;
  static const radius = 16.0;
  static const surface = Color(0xFFF4F7FC);
  static const selected = Color(0xFFEAF2FF);
  static const border = Color(0xFFE5EBF4);
  static const label = TextStyle(fontFamily: kAppFont, fontSize: labelSize,
      height: 1.5, color: AppColors.ink);
}
