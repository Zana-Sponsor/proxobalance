import 'package:flutter/material.dart';

import '../../widgets/auth/auth_design.dart';
import '../../widgets/auth/auth_header.dart';
import '../../widgets/auth/auth_intro.dart';

class RecoveryScreen extends StatelessWidget {
  const RecoveryScreen({
    super.key,
    required this.onBack,
    required this.content,
    this.newPassword = false,
  });
  final VoidCallback onBack;
  final Widget content;
  final bool newPassword;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AuthHeader.inner(onBack: onBack),
      const SizedBox(height: AuthTokens.gapHeaderToTitle),
      AuthIntro(
        icon: newPassword ? 'security_outline' : 'recovery_outline',
        title: newPassword
            ? AuthStrings.newPasswordTitle
            : AuthStrings.recoveryTitle,
        subtitle: newPassword
            ? AuthStrings.signupSecuritySubtitle
            : AuthStrings.resetPasswordSubtitle,
      ),
      content,
      const SizedBox(height: 24),
    ],
  );
}
