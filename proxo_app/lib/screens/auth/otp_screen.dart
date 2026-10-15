import 'package:proxo_app/theme/app_locale.dart';
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
    ProxoLocale.watch(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AuthHeader.inner(onBack: onBack),
        const SizedBox(height: AuthTokens.gapHeaderToTitle),
        AuthTitle(AuthStrings.otpTitle),
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
        const SizedBox(height: AuthTokens.gapHeaderToPin),
        otpBoxes,
        const SizedBox(height: AuthTokens.gapBetweenFields),
        Center(child: resend),
        const SizedBox(height: AuthTokens.gapBetweenFields),
        verifyButton,
        const SizedBox(height: AuthTokens.gapSectionBottom),
      ],
    );
  }
}
