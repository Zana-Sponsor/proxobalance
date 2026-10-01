import 'package:flutter/material.dart';
import '../../theme/app_locale.dart';
import 'auth_design.dart';
import 'auth_logo.dart';
import 'auth_widgets.dart';

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
    if (showLanguage) {
      return const Directionality(
        // Brand stays on the physical left and the language control on the
        // physical right, matching the supplied header reference in both RTL
        // languages. Text inside the selector restores RTL independently.
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
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
              child: Text('کوردی'),
            ),
            PopupMenuItem<Locale>(
              value: ProxoLocale.arabic,
              child: Text('العربية'),
            ),
          ],
          child: Container(
            height: 40,
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AuthTokens.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.language_rounded,
                    size: 18, color: AuthTokens.inkMuted),
                const SizedBox(width: 6),
                Text(
                  locale.languageCode == 'ar' ? 'العربية' : 'کوردی',
                  style: AuthTokens.helper.copyWith(
                    color: AuthTokens.ink,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
