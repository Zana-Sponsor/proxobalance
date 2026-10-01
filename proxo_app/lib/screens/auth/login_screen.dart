import 'package:flutter/material.dart';
import '../../widgets/auth/auth_design.dart';
import '../../widgets/auth/auth_header.dart';

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
        Text(AuthStrings.signInTitle,
            textAlign: TextAlign.start, style: AuthTokens.title),
        const SizedBox(height: AuthTokens.gapTitleToSubtitle),
        Text(AuthStrings.signInSubtitle,
            textAlign: TextAlign.start, style: AuthTokens.subtitle),
        const SizedBox(height: AuthTokens.gapSubtitleToForm),
        content,
        const SizedBox(height: AuthTokens.gapSectionBottom),
      ],
    );
  }
}
