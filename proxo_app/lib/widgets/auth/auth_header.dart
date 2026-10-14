import '../proxo_symbol.dart';
import 'package:flutter/material.dart';
import '../../theme/app_locale.dart';
import 'auth_design.dart';
import 'auth_logo.dart';
import 'auth_widgets.dart';
import 'package:proxo_app/widgets/proxo_text.dart';

class AuthHeader extends StatelessWidget {
  const AuthHeader.login({super.key})
      : onBack = null,
        showLanguage = true;

  const AuthHeader.inner({super.key, required this.onBack})
      : showLanguage = false;

  final VoidCallback? onBack;
  final bool showLanguage;

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    if (showLanguage) {
      return const Directionality(
        // Brand stays on the physical left and the language control on the
        // physical right, matching the supplied header reference in both RTL
        // languages. Text inside the selector restores RTL independently.
        textDirection: TextDirection.ltr,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween, spacing: 12, runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            AuthLogo(),
            Directionality(
              textDirection: TextDirection.rtl,
              child: AuthLanguageSelector(),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AuthBackButton(onTap: onBack!),
        const SizedBox(height: 14),
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: AuthLogo(),
        ),
      ],
    );
  }
}

class AuthLanguageSelector extends StatelessWidget {
  const AuthLanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    return ValueListenableBuilder<Locale>(
      valueListenable: ProxoLocale.current,
      builder: (context, locale, _) {
        return PopupMenuButton<Locale>(
          tooltip: locale.languageCode == 'ar' ? 'اللغة' : 'زمان',
          onSelected: ProxoLocale.set,
          position: PopupMenuPosition.under,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          itemBuilder: (context) => const <PopupMenuEntry<Locale>>[
            PopupMenuItem<Locale>(
              value: ProxoLocale.kurdishSorani,
              child: ProxoText('کوردی سۆرانی', translate: true),
            ),
            PopupMenuItem<Locale>(
              value: ProxoLocale.kurdishBadini,
              child: ProxoText('کوردی بادینی', translate: true),
            ),
            PopupMenuItem<Locale>(
              value: ProxoLocale.arabic,
              child: ProxoText('العربية', translate: true),
            ),
          ],
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AuthTokens.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const ProxoSymbol(ProxoSymbolName.language,
                    size: 22, color: AuthTokens.inkMuted),
                const SizedBox(width: 6),
                Flexible(child: ProxoText(
                  locale.languageCode == 'ar' ? 'العربية' :
                    locale.languageCode == 'kmr' ? 'کوردی بادینی' : 'کوردی سۆرانی',
                  style: AuthTokens.helper.copyWith(
                    color: AuthTokens.ink,
                    fontWeight: FontWeight.w500,
                  ),
                )),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Quiet, consistent identity for each authentication step.
class AuthHeroSymbol extends StatelessWidget {
  const AuthHeroSymbol(this.symbol, {super.key});
  final ProxoSymbolName symbol;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Align(alignment: AlignmentDirectional.centerStart,
      child: Container(width: 56, height: 56,
        decoration: BoxDecoration(color: const Color(0xFFEDF4FF),
          borderRadius: BorderRadius.circular(18)),
        alignment: Alignment.center,
        child: ProxoSymbol(symbol, size: 28, color: AuthTokens.accent))),
  );
}
