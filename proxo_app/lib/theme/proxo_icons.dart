import 'package:flutter/material.dart';

/// Small semantic icon registry shared by campaign list states.
///
/// Keeping these aliases in one place prevents screens from silently choosing
/// different glyphs for the same action. All glyphs use outline/rounded shapes
/// so they stay visually light beside the app's Solar-linear artwork.
abstract final class ProxoIcons {
  static const IconData blocked = Icons.block_rounded;
  static const IconData calendar = Icons.calendar_month_outlined;
  static const IconData clock = Icons.schedule_rounded;
  static const IconData edit = Icons.edit_outlined;
  static const IconData offline = Icons.cloud_off_outlined;
  static const IconData add = Icons.add_rounded;
  static const IconData success = Icons.check_circle_outline_rounded;
  static const IconData alert = Icons.warning_amber_rounded;
}
