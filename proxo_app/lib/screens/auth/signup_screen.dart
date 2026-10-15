import 'package:proxo_app/theme/app_locale.dart';
import 'package:flutter/material.dart';
import '../../widgets/auth/auth_design.dart';
import '../../widgets/auth/auth_header.dart';
import 'package:proxo_app/widgets/proxo_text.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({
    super.key,
    required this.onBack,
    required this.content,
  });

  final VoidCallback onBack;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AuthHeader.inner(onBack: onBack),
        const SizedBox(height: 32),
        AuthTitle(AuthStrings.signUpTitle),
        const SizedBox(height: AuthTokens.gapTitleToSubtitle),
        ProxoText(AuthStrings.signUpSubtitle, style: AuthTokens.subtitle),
        const SizedBox(height: AuthTokens.gapSubtitleToForm),
        content,
        const SizedBox(height: AuthTokens.gapSectionBottom),
      ],
    );
  }
}
