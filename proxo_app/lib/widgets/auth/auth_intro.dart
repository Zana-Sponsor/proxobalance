import 'package:flutter/material.dart';

import '../proxo_text.dart';
import 'auth_design.dart';
import 'auth_header.dart';
import 'auth_icon.dart';

/// A compact, directional title block. The icon shares the title's row instead
/// of consuming a separate hero row above the form.
class AuthIntro extends StatelessWidget {
  const AuthIntro({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final String icon, title, subtitle;

  @override
  Widget build(BuildContext context) {
    final symbol = Container(
      key: const ValueKey('auth-intro-icon'),
      width: AuthTokens.introIconSize,
      height: AuthTokens.introIconSize,
      decoration: BoxDecoration(
        color: AuthTokens.accentSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuthTokens.accentLine),
      ),
      alignment: Alignment.center,
      child: AuthIcon(icon, size: 20),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AuthTokens.gapSubtitleToForm),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // At large text sizes the heading gets the complete line width.
          // No text scaling is clamped and no title is ellipsized.
          final stacked = constraints.maxWidth < 260 ||
              MediaQuery.textScalerOf(context).scale(14) > 18;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (stacked) ...[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: symbol,
                ),
                const SizedBox(height: 12),
                AuthTitle(title),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: AuthTitle(title)),
                    const SizedBox(width: 16),
                    symbol,
                  ],
                ),
              const SizedBox(height: AuthTokens.gapTitleToSubtitle),
              ProxoText(subtitle, style: AuthTokens.subtitle),
            ],
          );
        },
      ),
    );
  }
}
