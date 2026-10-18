import 'package:proxo_app/theme/app_locale.dart';
import 'package:flutter/material.dart';

import '../../widgets/proxo_text.dart';
import '../../widgets/auth/auth_design.dart';
import '../../widgets/auth/auth_header.dart';
import '../../widgets/auth/auth_intro.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({
    super.key,
    required this.onBack,
    required this.content,
    this.stage = 0,
  });
  final VoidCallback onBack;
  final Widget content;
  final int stage;

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthHeader.inner(onBack: onBack),
        const SizedBox(height: 28),
        AuthIntro(
          icon: stage == 0 ? 'person_add' : 'shield',
          title: stage == 0
              ? AuthStrings.signUpTitle
              : AuthStrings.signupSecurityTitle,
          subtitle: stage == 0
              ? AuthStrings.signupDetailsSubtitle
              : AuthStrings.signupSecuritySubtitle,
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Row(
              children: [
                for (var i = 0; i < 2; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: i <= stage ? AuthTokens.accent : AuthTokens.line,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ProxoText(
          stage == 0
              ? AuthStrings.signupFirstStep
              : AuthStrings.signupSecondStep,
          textAlign: TextAlign.center,
          style: AuthTokens.helper.copyWith(fontSize: 12),
        ),
        const SizedBox(height: 24),
        content,
        const SizedBox(height: AuthTokens.gapSectionBottom),
      ],
    );
  }
}
