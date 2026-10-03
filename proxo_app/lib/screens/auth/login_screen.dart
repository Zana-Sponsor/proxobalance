import 'package:flutter/material.dart';
import '../../widgets/auth/auth_design.dart';
import '../../widgets/auth/auth_header.dart';
import 'package:proxo_app/widgets/proxo_text.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    required this.content,
  });

  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const AuthHeader.login(),
        const SizedBox(height: 28),
        ProxoText(AuthStrings.signInTitle,
            textAlign: TextAlign.start, style: AuthTokens.title),
        const SizedBox(height: AuthTokens.gapTitleToSubtitle),
        ProxoText(AuthStrings.signInSubtitle,
            textAlign: TextAlign.start, style: AuthTokens.subtitle),
        const SizedBox(height: AuthTokens.gapSubtitleToForm),
        content,
        const SizedBox(height: AuthTokens.gapSectionBottom),
      ],
    );
  }
}
