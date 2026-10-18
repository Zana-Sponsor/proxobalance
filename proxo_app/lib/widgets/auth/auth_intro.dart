import 'package:flutter/material.dart';

import '../proxo_text.dart';
import 'auth_design.dart';
import 'auth_header.dart';
import 'auth_icon.dart';

/// One quiet, centered introduction shared by every Auth step.
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
      Center(
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AuthTokens.accentSoft,
            borderRadius: BorderRadius.circular(22),
          ),
          alignment: Alignment.center,
          child: AuthIcon(icon, size: 30),
        ),
      ),
      const SizedBox(height: 20),
      AuthTitle(title, textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: ProxoText(
            subtitle,
            textAlign: TextAlign.center,
            style: AuthTokens.subtitle,
          ),
        ),
      ),
      const SizedBox(height: 28),
    ],
  );
}
