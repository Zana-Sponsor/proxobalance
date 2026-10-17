import 'package:proxo_app/theme/app_locale.dart';
import 'package:flutter/material.dart';

import '../../widgets/auth/auth_design.dart';
import '../../widgets/auth/auth_header.dart';
import '../../widgets/auth/auth_intro.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, required this.content});

  final Widget content;

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const AuthHeader.login(),
        const SizedBox(height: AuthTokens.gapHeaderToTitle),
        AuthIntro(
          icon: 'login',
          title: AuthStrings.signInTitle,
          subtitle: AuthStrings.signInSubtitle,
        ),
        content,
        const SizedBox(height: AuthTokens.gapSectionBottom),
      ],
    );
  }
}
