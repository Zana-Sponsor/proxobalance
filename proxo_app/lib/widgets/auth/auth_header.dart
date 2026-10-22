import 'package:proxo_app/l10n/proxo_strings.dart';
import 'package:flutter/material.dart';

import '../../theme/app_locale.dart';
import 'auth_design.dart';
import 'auth_logo.dart';
import 'auth_widgets.dart';
import 'auth_icon.dart';

import 'package:proxo_app/widgets/proxo_text.dart';

class AuthHeader extends StatelessWidget {
  const AuthHeader.login({super.key}) : onBack = null;

  const AuthHeader.inner({super.key, required this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    return Container(
      key: const ValueKey('auth-app-bar'),
      height: AuthTokens.toolbarHeight,
      child: Row(
        children: [
          SizedBox(
            width: AuthTokens.controlHeight,
            child: onBack == null ? null : AuthBackButton(onTap: onBack!),
          ),
          const Expanded(child: Center(child: AuthLogo())),
          const AuthLanguageSelector(compact: true),
        ],
      ),
    );
  }
}

class AuthLanguageSelector extends StatelessWidget {
  const AuthLanguageSelector(
      {super.key, this.compact = false, this.childBuilder});

  final bool compact;

  /// Reuse the same supported languages in a full settings row.
  final Widget Function(BuildContext context, Locale locale)? childBuilder;

  @override
  Widget build(BuildContext context) {
    ProxoLocale.watch(context);
    return ValueListenableBuilder<Locale>(
      valueListenable: ProxoLocale.current,
      builder: (context, locale, _) {
        return PopupMenuButton<Locale>(
          tooltip: '${ProxoStrings.text('زمان')} · ${_languageName(locale)}',
          initialValue: locale,
          onSelected: ProxoLocale.set,
          position: PopupMenuPosition.under,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          itemBuilder: (context) => const <PopupMenuEntry<Locale>>[
            PopupMenuItem<Locale>(
              value: ProxoLocale.kurdishSorani,
              child: ProxoText(
                'کوردی سۆرانی',
                translate: true,
                style: AuthTokens.fieldText,
              ),
            ),
            PopupMenuItem<Locale>(
              value: ProxoLocale.kurdishBadini,
              child: ProxoText(
                'کوردی بادینی',
                translate: true,
                style: AuthTokens.fieldText,
              ),
            ),
            PopupMenuItem<Locale>(
              value: ProxoLocale.arabic,
              child: ProxoText(
                'العربية',
                translate: true,
                style: AuthTokens.fieldText,
              ),
            ),
          ],
          child: childBuilder?.call(context, locale) ??
              Container(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const AuthIcon(
                      'language_outline',
                      size: 20,
                      color: AuthTokens.ink,
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 7),
                      Flexible(
                        child: ProxoText(
                          _languageName(locale),
                          style: AuthTokens.helper.copyWith(
                            color: AuthTokens.ink,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
        );
      },
    );
  }

  String _languageName(Locale locale) => switch (locale.languageCode) {
        'ar' => 'العربية',
        'kmr' => 'کوردی بادینی',
        _ => 'کوردی سۆرانی',
      };
}

/// Keep whole words intact at narrow widths while retaining the user's text
/// scaling. Only headings whose longest word cannot fit are reduced.
class AuthTitle extends StatelessWidget {
  const AuthTitle(this.text, {super.key, this.textAlign = TextAlign.start});
  final String text;
  final TextAlign textAlign;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          var style = AuthTokens.title;
          final scaler = MediaQuery.textScalerOf(context);
          for (var pass = 0; pass < 4; pass++) {
            var widest = 0.0;
            for (final word in text.split(RegExp(r'\s+'))) {
              final painter = TextPainter(
                text: TextSpan(text: word, style: style),
                textDirection: TextDirection.rtl,
                textScaler: scaler,
              )..layout();
              if (painter.width > widest) widest = painter.width;
              painter.dispose();
            }
            if (widest <= constraints.maxWidth || widest == 0) break;
            style = style.copyWith(
              fontSize: style.fontSize! * constraints.maxWidth / widest,
            );
          }
          return Semantics(
            header: true,
            child: ProxoText(text, textAlign: textAlign, style: style),
          );
        },
      );
}
