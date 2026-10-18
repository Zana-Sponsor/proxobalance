import 'package:flutter/material.dart';
import '../../theme/app_locale.dart';
import '../../widgets/auth/auth_design.dart';
import '../../widgets/auth/auth_header.dart';
import '../../widgets/auth/auth_intro.dart';

/// One continuous account form; verification is a separate route in AuthShell.
class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key, required this.onBack, required this.content});
  final VoidCallback onBack;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthHeader.inner(onBack: onBack),
        const SizedBox(height: AuthTokens.gapHeaderToTitle),
        AuthIntro(
          icon: 'account_outline',
          title: AuthStrings.signUpTitle,
          subtitle: AuthStrings.signUpSubtitle,
        ),
        content,
        const SizedBox(height: AuthTokens.gapSectionBottom),
      ],
    );
  }
}
