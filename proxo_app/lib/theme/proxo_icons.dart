import 'package:flutter/material.dart';

/// Small semantic icon registry shared by campaign list states.
///
/// Keeping these aliases in one place prevents screens from silently choosing
/// different glyphs for the same action. All glyphs use outline/rounded shapes
/// so they stay visually light beside the app's Solar-linear artwork.
abstract final class ProxoIcons {
  // Material outline glyphs already bundled by Flutter (Apache-2.0).
  static const IconData createAd = Icons.campaign_outlined;
  static const IconData wallet = Icons.account_balance_wallet_outlined;
  static const IconData createPage = Icons.add_link_outlined;
  static const IconData pages = Icons.link_outlined;
  static const IconData help = Icons.help_outline_rounded;
  static const IconData blocked = Icons.block_rounded;
  static const IconData calendar = Icons.calendar_month_outlined;
  static const IconData clock = Icons.schedule_rounded;
  static const IconData edit = Icons.edit_outlined;
  static const IconData offline = Icons.cloud_off_outlined;
  static const IconData add = Icons.add_rounded;
  static const IconData success = Icons.check_circle_outline_rounded;
  static const IconData alert = Icons.warning_amber_rounded;
}
