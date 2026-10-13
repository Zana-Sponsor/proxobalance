import 'package:flutter/material.dart';

/// The single Auth wordmark implementation. Its painted size is deliberately
/// fixed so keyboard, screen height, transitions and text scaling cannot shrink
/// it on Sign Up or OTP.
class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key});

  static const double width = 132;
  static const double height = 38;
  static const String asset = 'assets/images/proxo_logo.png';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Proxo',
      image: true,
      child: const SizedBox(
        width: width,
        height: height,
        child: Image(
          image: AssetImage(asset),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}
