import 'package:flutter/material.dart';
import '../theme/proxo_design_tokens.dart';
import '../theme/app_locale.dart';
import 'proxo_text.dart';

/// Intrinsic height keeps Kurdish and Arabic copy readable at narrow widths
/// and large text sizes. The only action uses Home's existing ad route.
class ProxoHomeHero extends StatelessWidget {
  const ProxoHomeHero({super.key, this.onStart});
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) => Directionality(
      textDirection: ProxoLocale.directionOf(ProxoLocale.watch(context)),
      child: Container(
        key: const ValueKey('home-gradient-banner'),
        width: double.infinity,
        padding: const EdgeInsets.all(ProxoDesign.cardPadding),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.centerStart,
            end: AlignmentDirectional.centerEnd,
            colors: [ProxoDesign.blue, ProxoDesign.secondaryBlue],
          ),
          borderRadius:
              BorderRadius.all(Radius.circular(ProxoDesign.cardRadius)),
          boxShadow: ProxoDesign.shadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProxoText('ڕیکلامەکەت بە ئاسانی دروست بکە',
                translate: true,
                style: ProxoDesign.heading.copyWith(color: Colors.white)),
            const SizedBox(height: ProxoDesign.helperGap),
            ProxoText('پەڕە، ناوەڕۆک و بودجەکەت هەڵبژێرە.',
                translate: true,
                style: ProxoDesign.helper.copyWith(color: Colors.white)),
            if (onStart != null) ...[
              const SizedBox(height: ProxoDesign.headingGap),
              FilledButton(
                key: const ValueKey('home-banner-create-ad'),
                onPressed: onStart,
                style: FilledButton.styleFrom(
                  foregroundColor: ProxoDesign.blue,
                  backgroundColor: Colors.white,
                  minimumSize: const Size(0, ProxoDesign.controlHeight),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: const RoundedRectangleBorder(
                      borderRadius: ProxoDesign.border),
                  textStyle: ProxoDesign.button,
                ),
                child: const ProxoText('دروستکردنی ڕیکلام',
                    translate: true, textAlign: TextAlign.center),
              ),
            ],
          ],
        ),
      ));
}
