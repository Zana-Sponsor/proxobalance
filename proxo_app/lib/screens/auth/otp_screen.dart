import 'package:flutter/material.dart';
import '../../widgets/auth/auth_design.dart';
import '../../widgets/auth/auth_header.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AuthHeader.inner(onBack: onBack),
        const SizedBox(height: 24),
        ProxoText(
          AuthStrings.otpTitle,
          style: AuthTokens.title.copyWith(color: AuthTokens.accent),
        ),
        const SizedBox(height: AuthTokens.gapTitleToSubtitle),
        ProxoText(AuthStrings.otpSubtitle, style: AuthTokens.subtitle),
        const SizedBox(height: 6),
        Directionality(
          textDirection: TextDirection.ltr,
          child: ProxoText(
            destination,
            textAlign: TextAlign.start,
            style: AuthTokens.fieldText.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 28),
        otpBoxes,
        const SizedBox(height: 18),
        SizedBox(height: 24, child: Center(child: resend)),
        const SizedBox(height: 24),
        verifyButton,
        const SizedBox(height: AuthTokens.gapSectionBottom),
      ],
    );
  }
}
