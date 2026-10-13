import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ProxoLocale — the app's one source of truth for language and text direction.
//
// ── WHY THIS EXISTS RATHER THAN JUST `Locale('ku')` ─────────────────────────
// Setting `MaterialApp.locale` does not cover Sorani direction on its own. The
// app-level `Directionality` is installed by the Localizations widget. Flutter
// has Arabic framework localizations, but ckb is not in the stock delegate's
// supported set, so the app keeps an explicit source of truth for direction.
//
// Adding `flutter_localizations` fixes that for Arabic, but not for Kurdish:
//
//   • `ckb` (Central Kurdish / Sorani — this app's language, Arabic script,
//     RTL) is not in `GlobalWidgetsLocalizations`' supported set, so no
//     delegate matches and the direction silently falls back to LTR.
//   • `ku` is the macrolanguage code and in practice usually means Kurmanji,
//     which is written in LATIN script and is LTR. Tagging a Sorani build as
//     `Locale('ku')` is the wrong code for the content AND resolves to the
//     wrong direction.
//
// Hence an explicit table. It answers the direction question without depending
// on the framework knowing the language, and it keeps working if
// `flutter_localizations` is added later for Material's own strings.
// ─────────────────────────────────────────────────────────────────────────────

class ProxoLocale {
  ProxoLocale._();

  /// Central Kurdish (Sorani) — Arabic script, RTL. `ckb` is the correct
  /// ISO 639-3 code; see the note above on why `ku` is not.
  static const Locale kurdishSorani = Locale('ckb');
  static const Locale arabic = Locale('ar');
  static const Locale english = Locale('en');

  static const List<Locale> supported = <Locale>[
    kurdishSorani,
    arabic,
    english,
  ];

  /// The live app language. Assign to `.value` and every widget listening
  /// through [ProxoLocaleScope] rebuilds with the new direction — that is what
  /// makes the switch automatic rather than requiring a restart.
  static final ValueNotifier<Locale> current =
      ValueNotifier<Locale>(kurdishSorani);

  static const String _storageKey = 'proxo_locale';

  static Future<void> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? code = prefs.getString(_storageKey);
    current.value = switch (code) {
      'ar' => arabic,
      'en' => english,
      _ => kurdishSorani,
    };
  }

  static Future<void> set(Locale locale) async {
    final Locale next = supported.firstWhere(
      (item) => item.languageCode == locale.languageCode,
      orElse: () => kurdishSorani,
    );
    if (current.value.languageCode != next.languageCode) {
      current.value = next;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, next.languageCode);
  }

  static bool get isArabic => current.value.languageCode == 'ar';

  /// Languages written right-to-left, by ISO 639 code.
  ///
  /// `ku` is listed as RTL because this app ships Sorani and some devices
  /// still report the macrolanguage code for it. If a Kurmanji (Latin script)
  /// build is ever added, remove `ku` from this set — Kurmanji is LTR and
  /// would otherwise be mirrored incorrectly.
  ///
  /// `iw` and `ji` are the deprecated codes for Hebrew and Yiddish; some
  /// Android builds still report them.
  static const Set<String> _rtlLanguages = <String>{
    'ar', // Arabic
    'ckb', // Central Kurdish (Sorani)
    'ku', // Kurdish macrolanguage — see note above
    'fa', // Persian
    'he', 'iw', // Hebrew
    'ur', // Urdu
    'ps', // Pashto
    'sd', // Sindhi
    'ug', // Uyghur
    'yi', 'ji', // Yiddish
    'dv', // Dhivehi
  };

  static bool isRtl(Locale? locale) =>
      locale != null &&
      _rtlLanguages.contains(locale.languageCode.toLowerCase());

  static TextDirection directionOf(Locale? locale) =>
      isRtl(locale) ? TextDirection.rtl : TextDirection.ltr;

  /// Resolution for `MaterialApp.localeResolutionCallback`.
  ///
  /// The default resolver falls back to `supportedLocales.first` when nothing
  /// matches, which would hand an Arabic-script user an LTR English layout
  /// without any warning. This matches on language code alone (so `ar-IQ`,
  /// `ar-SA` and bare `ar` all land on Arabic) and falls back to Sorani, the
  /// app's primary market.
  static Locale resolve(Locale? deviceLocale, Iterable<Locale> supportedList) {
    if (deviceLocale != null) {
      for (final Locale l in supportedList) {
        if (l.languageCode.toLowerCase() ==
            deviceLocale.languageCode.toLowerCase()) {
          return l;
        }
      }
    }
    return kurdishSorani;
  }
}

/// Installs the app-wide [Directionality] from [ProxoLocale.current] and
/// rebuilds when the language changes.
///
/// Drop this in `MaterialApp.builder`. It sits BELOW the `Localizations`
/// widget, so its direction overrides the LTR default described at the top of
/// this file.
///
/// ⚠ This sets the app DEFAULT only. Any widget that wraps itself in its own
/// `Directionality` still wins locally — and this codebase does that in about
/// 140 places, roughly half of them deliberately LTR (charts, the bottom nav
/// order, latin numerals). Those are unaffected by a language switch until
/// they are migrated to read [ProxoLocale] instead of a hard-coded literal.
/// MaterialApp maps ckb to its Arabic framework locale, while this scope reads
/// [ProxoLocale.current] directly so the application's real language choice is
/// retained and direction remains explicit.
class ProxoLocaleScope extends StatelessWidget {
  final Widget child;

  const ProxoLocaleScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: ProxoLocale.current,
      builder: (context, locale, _) {
        return Directionality(
          textDirection: ProxoLocale.directionOf(locale),
          child: child,
        );
      },
    );
  }
}
