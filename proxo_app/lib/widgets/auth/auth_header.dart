import 'package:proxo_app/l10n/proxo_strings.dart';
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(width: 48, child: AuthBackButton(onTap: onBack!)),
        const AuthLogo(),
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
          tooltip: ProxoStrings.text('زمان'),
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

/// Keep whole words intact at narrow widths while retaining the user's text
/// scaling. Only headings whose longest word cannot fit are reduced.
class AuthTitle extends StatelessWidget {
  const AuthTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
    var style = AuthTokens.title;
    final scaler = MediaQuery.textScalerOf(context);
    for (var pass = 0; pass < 4; pass++) {
      var widest = 0.0;
      for (final word in text.split(RegExp(r'\s+'))) {
        final painter = TextPainter(text: TextSpan(text: word, style: style),
          textDirection: TextDirection.rtl, textScaler: scaler)..layout();
        if (painter.width > widest) widest = painter.width;
        painter.dispose();
      }
      if (widest <= constraints.maxWidth || widest == 0) break;
      style = style.copyWith(fontSize: style.fontSize! * constraints.maxWidth / widest);
    }
    return Semantics(header: true, child: ProxoText(text,
      textAlign: TextAlign.start, style: style));
  });
}
