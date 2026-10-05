import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

enum PlStyle { dark, light, classic, pill, card, neon, zoom, banner }

extension PlStyleInfo on PlStyle {
  String get nameEn {
    switch (this) {
      case PlStyle.dark:
        return 'dark';
      case PlStyle.light:
        return 'light';
      case PlStyle.classic:
        return 'classic';
      case PlStyle.pill:
        return 'pill';
      case PlStyle.card:
        return 'card';
      case PlStyle.neon:
        return 'neon';
      case PlStyle.zoom:
        return 'zoom';
      case PlStyle.banner:
        return 'banner';
    }
  }

  String get displayEn {
    switch (this) {
      case PlStyle.dark:
        return 'Dark';
      case PlStyle.light:
        return 'Light';
      case PlStyle.classic:
        return 'Classic';
      case PlStyle.pill:
        return 'Pill';
      case PlStyle.card:
        return 'Card';
      case PlStyle.neon:
        return 'Neon';
      case PlStyle.zoom:
        return 'Zoom';
      case PlStyle.banner:
        return 'Banner';
    }
  }

  String get nameKu {
    switch (this) {
      case PlStyle.dark:
        return 'تاریک';
      case PlStyle.light:
        return 'ڕووناک';
      case PlStyle.classic:
        return 'کلاسیک';
      case PlStyle.pill:
        return 'پیل گرادیەنت';
      case PlStyle.card:
        return 'کارد ئاکسنت';
      case PlStyle.neon:
        return 'نیۆن ئاوتلاین';
      case PlStyle.zoom:
        return 'زووم — نزیک';
      case PlStyle.banner:
        return 'بانەر — گرادیێنت';
    }
  }

  IconData get icon {
    switch (this) {
      case PlStyle.dark:
        return Icons.dark_mode_rounded;
      case PlStyle.light:
        return Icons.light_mode_rounded;
      case PlStyle.classic:
        return Icons.layers_rounded;
      case PlStyle.pill:
        return Icons.healing_rounded;
      case PlStyle.card:
        return Icons.credit_card_rounded;
      case PlStyle.neon:
        return Icons.bolt_rounded;
      case PlStyle.zoom:
        return Icons.zoom_in_rounded;
      case PlStyle.banner:
        return Icons.view_stream_rounded;
    }
  }

  bool get requiresLogo =>
      this == PlStyle.dark ||
      this == PlStyle.light ||
      this == PlStyle.zoom ||
      this == PlStyle.banner;
}

enum CardLang { ku, ar }

extension CardLangInfo on CardLang {
  String get code => this == CardLang.ar ? 'ar' : 'ku';
  String get label => this == CardLang.ar ? 'عربی' : 'کوردی';
}

class CardTheme {
  final String key;
  final Color swatch;
  final String gradFrom;
  final String gradTo;
  const CardTheme(this.key, this.swatch, this.gradFrom, this.gradTo);
}

const List<CardTheme> kCardThemes = [
  CardTheme('purple', Color(0xFFC855E0), '#5b1fa8', '#c855e0'),
  CardTheme('blue', Color(0xFF2563EB), '#1e3a8a', '#2563eb'),
  CardTheme('green', Color(0xFF16A34A), '#14532d', '#16a34a'),
  CardTheme('red', Color(0xFFDC2626), '#7f1d1d', '#dc2626'),
  CardTheme('yellow', Color(0xFFD97706), '#78350f', '#d97706'),
  CardTheme('cyan', Color(0xFF0891B2), '#164e63', '#0891b2'),
  CardTheme('pink', Color(0xFFBE185D), '#831843', '#be185d'),
  CardTheme('dark', Color(0xFF1C2333), '#0d1021', '#1c2333'),
];

final List<Color> kThemeColors = kCardThemes.map((t) => t.swatch).toList();

CardTheme themeByKey(String? key) {
  if (key == null || key.isEmpty) return kCardThemes[0];
  for (final t in kCardThemes) {
    if (t.key == key) return t;
  }
  if (key.startsWith('#')) {
    final lower = key.toLowerCase();
    for (final t in kCardThemes) {
      if (t.gradTo.toLowerCase() == lower ||
          t.gradFrom.toLowerCase() == lower) {
        return t;
      }
    }
  }
  return kCardThemes[0];
}

CardTheme themeBySwatch(Color c) => kCardThemes.firstWhere(
  (t) => t.swatch.toARGB32() == c.toARGB32(),
  orElse: () => kCardThemes[0],
);

class PlatformBtn {
  final String id, label, type, placeholder;
  final Widget iconWidget;
  final Color iconColor, bgColor;
  final bool isNumeric;
  const PlatformBtn({
    required this.id,
    required this.label,
    required this.iconWidget,
    required this.iconColor,
    required this.bgColor,
    required this.type,
    required this.placeholder,
    required this.isNumeric,
  });
}

final List<PlatformBtn> kPlatformBtns = [
  const PlatformBtn(
    id: 'wa',
    label: 'واتسئاپ',
    iconWidget: const FaIcon(
      FontAwesomeIcons.whatsapp,
      size: 20,
      color: Colors.white,
    ),
    iconColor: const Color(0xFF25D366),
    bgColor: const Color(0xFFE8FDF2),
    type: 'whatsapp',
    placeholder: '9647XXXXXXXXX',
    isNumeric: true,
  ),
  const PlatformBtn(
    id: 'vb',
    label: 'ڤایبەر',
    iconWidget: const FaIcon(
      FontAwesomeIcons.viber,
      size: 20,
      color: Colors.white,
    ),
    iconColor: const Color(0xFF7360F2),
    bgColor: const Color(0xFFF3F0FE),
    type: 'viber',
    placeholder: '9647XXXXXXXXX',
    isNumeric: true,
  ),
  const PlatformBtn(
    id: 'ig',
    label: 'ئینستاگرام',
    iconWidget: const FaIcon(
      FontAwesomeIcons.instagram,
      size: 20,
      color: Colors.white,
    ),
    iconColor: const Color(0xFFE1306C),
    bgColor: const Color(0xFFFCE8F0),
    type: 'instagram',
    placeholder: 'username',
    isNumeric: false,
  ),
  const PlatformBtn(
    id: 'ph',
    label: 'کۆرەک',
    iconWidget: const FaIcon(
      FontAwesomeIcons.phone,
      size: 17,
      color: Colors.white,
    ),
    iconColor: const Color(0xFF2563EB),
    bgColor: const Color(0xFFEBF2FF),
    type: 'phone',
    placeholder: '9647XXXXXXXXX',
    isNumeric: true,
  ),
  const PlatformBtn(
    id: 'as',
    label: 'ئاسیا سێڵ',
    iconWidget: const FaIcon(
      FontAwesomeIcons.mobileScreenButton,
      size: 20,
      color: Colors.white,
    ),
    iconColor: const Color(0xFFEF4444),
    bgColor: const Color(0xFFFEECEC),
    type: 'asya',
    placeholder: '9647XXXXXXXXX',
    isNumeric: true,
  ),
];

const List<String> kBioChips = [
  'لەڕێگەی دووگمەکانەوە پەیوەندیمان پێوە بکەن.',
  'ئۆفەری ناوازەمان داناوە بۆ کڕیارەکانمان، هەرئێستا پەیوەندیمان پێوە بکە.',
  'زانیاری زیاترت دەوێت؟ کلیک لەم دووگمانەی خوارەوە بکە، کارمەندەکانمان ئامادەن بۆ یارمەتیدانت.',
  'پەیوەندیمان پێوە بکەن بۆ زانیاری زیاتر، تیمەکەمان بە خێرایی وەڵامتان دەداتەوە.',
  'تەنها یەک کلیک دوورین. پەیوەندیمان پێوە بکە و وەڵامت دەدەینەوە.',
  'بۆ هەر پرسیارێک، ئێمە لێرەین. لەم دووگمانەی خوارەوە کلیک بکە.',
  'کڕیارەکانمان بۆمان گرنگن. پەیوەندیمان پێوە بکە و یارمەتیت دەدەین.',
  'ئەگەر دەتەوێت زیاتر بزانیت، پەیوەندیمان پێوە بکە، خێرا وەڵامت دەدەینەوە.',
  'خزمەتگوزاریمان بۆ ئێوە ئامادەیە، تەنها پەیوەندیمان پێوە بکەن.',
  'هەرئێستا ئامادەین بۆ گوێگرتن و یارمەتیدان. پەیوەندیمان پێوە بکە.',
];

const Map<String, Map<String, String>> kPlatformCardLabels = {
  'wa': {'ku': 'واتسئاپ', 'ar': 'واتساب'},
  'vb': {'ku': 'ڤایبەر', 'ar': 'فايبر'},
  'ig': {'ku': 'ئینستاگرام', 'ar': 'إنستغرام'},
  'ph': {'ku': 'کۆرەک', 'ar': 'كورك'},
  'as': {'ku': 'ئاسیا سێڵ', 'ar': 'آسيا سيل'},
};

const Map<String, String> kPlatformUrlScheme = {
  'wa': 'whatsapp://send?phone=',
  'vb': 'viber://chat?number=',
  'ig': 'https://instagram.com/',
  'ph': 'tel:',
  'as': 'tel:',
};

String platformCardLabel(String id, CardLang lang) =>
    kPlatformCardLabels[id]?[lang.code] ?? id;
