import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:proxo_app/widgets/proxo_text.dart';

class ProxoLogo extends StatelessWidget {
  final double size;
  final double fontSize;
  final double borderRadius;

  const ProxoLogo({
    super.key,
    this.size = 72,
    this.fontSize = 32,
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.accent, AppColors.ink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: ProxoText(
          'P',
          style: TextStyle(
            fontFamily: kAppFont,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: AppColors.white,
          ),
        ),
      ),
    );
  }
}
