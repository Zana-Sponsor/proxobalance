import 'package:proxo_app/theme/app_locale.dart';
import 'package:flutter/material.dart';

import '../../widgets/auth/auth_design.dart';
import '../../widgets/auth/auth_header.dart';
import '../../widgets/auth/auth_intro.dart';

import 'package:proxo_app/widgets/proxo_text.dart';

class OtpScreen extends StatelessWidget {
  const OtpScreen({
    super.key,
    required this.onBack,
    required this.destination,
    required this.otpBoxes,
    required this.resend,
    required this.verifyButton,
  });

  final VoidCallback onBack;
  final String destination;
  final Widget otpBoxes;
  final Widget resend;
  final Widget verifyButton;

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AuthHeader.inner(onBack: onBack),
        const SizedBox(height: AuthTokens.gapHeaderToTitle),
        AuthIntro(
          icon: 'verified_user',
          title: AuthStrings.otpTitle,
          subtitle: AuthStrings.otpSubtitle,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AuthTokens.fieldFill,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: ProxoText(
              destination,
              textAlign: TextAlign.center,
              style: AuthTokens.fieldText.copyWith(fontWeight: FontWeight.w400),
            ),
          ),
        ),
        const SizedBox(height: 28),
        otpBoxes,
        const SizedBox(height: 28),
        verifyButton,
        const SizedBox(height: 18),
        Center(child: resend),
        const SizedBox(height: AuthTokens.gapSectionBottom),
      ],
    );
  }
}
