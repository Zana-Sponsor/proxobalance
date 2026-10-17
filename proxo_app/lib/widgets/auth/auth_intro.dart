import 'package:flutter/material.dart';

import '../proxo_text.dart';
import 'auth_design.dart';
import 'auth_header.dart';
import 'auth_icon.dart';

class AuthIntro extends StatelessWidget {
  const AuthIntro({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final String icon, title, subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AuthTokens.accentSoft,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: AuthIcon(icon, size: 27),
        ),
      ),
      const SizedBox(height: 16),
      AuthTitle(title),
      const SizedBox(height: AuthTokens.gapTitleToSubtitle),
      ProxoText(
        subtitle,
        textAlign: TextAlign.start,
        style: AuthTokens.subtitle,
      ),
      const SizedBox(height: AuthTokens.gapSubtitleToForm),
    ],
  );
}
