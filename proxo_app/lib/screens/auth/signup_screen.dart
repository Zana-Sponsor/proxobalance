import 'package:proxo_app/theme/app_locale.dart';
import 'package:flutter/material.dart';

import '../../widgets/proxo_text.dart';
import '../../widgets/auth/auth_design.dart';
import '../../widgets/auth/auth_header.dart';
import '../../widgets/auth/auth_intro.dart';
import '../../widgets/auth/auth_icon.dart';

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
        const SizedBox(height: AuthTokens.gapHeaderToTitle),
        AuthSignupProgress(stage: stage),
        const SizedBox(height: 24),
        AuthIntro(
          icon: stage == 0 ? 'account_outline' : 'security_outline',
          title: stage == 0
              ? AuthStrings.signUpTitle
              : AuthStrings.signupSecurityTitle,
          subtitle: stage == 0
              ? AuthStrings.signupDetailsSubtitle
              : AuthStrings.signupSecuritySubtitle,
        ),
        content,
        const SizedBox(height: AuthTokens.gapSectionBottom),
      ],
    );
  }
}

/// Read-only progress: advancing still runs the form's existing validation.
class AuthSignupProgress extends StatelessWidget {
  const AuthSignupProgress({super.key, required this.stage})
      : assert(stage == 0 || stage == 1);

  final int stage;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final steps = [
            _step(
                0, AuthStrings.signupDetailsStep, AuthStrings.signupFirstStep),
            _step(1, AuthStrings.signupSecurityStep,
                AuthStrings.signupSecondStep),
          ];
          // Keep the labels and 24dp markers intact with accessibility text.
          if (constraints.maxWidth < 270 ||
              MediaQuery.textScalerOf(context).scale(14) > 18) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [steps[0], const SizedBox(height: 8), steps[1]],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: steps[0]),
                const SizedBox(width: 12),
                Expanded(child: steps[1]),
              ],
            ),
          );
        },
      );

  Widget _step(int index, String label, String announcement) {
    final active = stage == index;
    final complete = stage > index;
    final highlighted = active || complete;
    return Semantics(
      label: '$announcement. $label',
      selected: active,
      excludeSemantics: true,
      child: Container(
        key: ValueKey('signup-progress-$index'),
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: active ? AuthTokens.accentSoft : AuthTokens.pageBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: highlighted ? AuthTokens.accentLine : AuthTokens.line,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: highlighted ? AuthTokens.accent : AuthTokens.fieldFill,
                shape: BoxShape.circle,
              ),
              child: complete
                  ? const AuthIcon(
                      'check_outline',
                      size: 16,
                      color: Colors.white,
                    )
                  : ProxoText(
                      index == 0 ? '١' : '٢',
                      textScaler: TextScaler.noScaling,
                      style: AuthTokens.helper.copyWith(
                        fontSize: 12,
                        height: 1,
                        color: active ? Colors.white : AuthTokens.inkMuted,
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ProxoText(
                label,
                style: AuthTokens.fieldLabel.copyWith(
                  color:
                      highlighted ? AuthTokens.accentInk : AuthTokens.inkMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
