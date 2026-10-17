import 'package:proxo_app/theme/app_locale.dart';
import 'package:flutter/material.dart';

import '../../widgets/auth/auth_design.dart';
import '../../widgets/auth/auth_header.dart';
import '../../widgets/auth/auth_intro.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key, required this.onBack, required this.content});

  final VoidCallback onBack;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AuthHeader.inner(onBack: onBack),
        const SizedBox(height: AuthTokens.gapHeaderToTitle),
        AuthIntro(
          icon: 'person_add',
          title: AuthStrings.signUpTitle,
          subtitle: AuthStrings.signUpSubtitle,
        ),
        content,
        const SizedBox(height: AuthTokens.gapSectionBottom),
      ],
    );
  }
}
