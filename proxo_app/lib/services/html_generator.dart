// ═══════════════════════════════════════════════════════════════════════
// HTML GENERATOR — ProxoLink card domain models + final HTML builder
// ═══════════════════════════════════════════════════════════════════════
//
// This file is the single source of truth for turning form data (name,
// bio, tiktok, selected platforms + contact values, style, theme, card
// language) into the final standalone HTML page — the exact same HTML
// used for:
//   • the file that gets saved to Supabase (`html_content`)
//   • the file that gets sent to Telegram via the Cloudflare Worker
//
// It mirrors proxo-tools.js's `buildPLCardHTML()` as closely as possible
// (same theme gradients, same platform labels/url-schemes for Kurdish +
// Arabic card language, same button layouts per style) so a card created
// in the Flutter app renders identically to one created on the website.
//
// It also FIXES a real bug found in the original card_templates.dart:
// every one of the 8 style templates shipped with a hardcoded demo
// click-handler script (4 platforms only, pointing at a placeholder
// phone number / the @proxo_iq demo accounts) instead of the user's
// actual entered data. That dead script has been replaced with a
// {{HANDLERS}} placeholder in card_templates.dart, filled in here by
// _buildHandlersScript() using the real, active platforms + values.
// ═══════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../templates/card_templates.dart';
import 'package:proxo_app/widgets/proxo_text.dart';

// ─────────────────────────────────────────────────────────────
// STYLES
// ─────────────────────────────────────────────────────────────

enum PlStyle { dark, light, classic, pill, card, neon, zoom, banner }

extension PlStyleInfo on PlStyle {
  String get nameEn {
    switch (this) {
      case PlStyle.dark:    return 'dark';
      case PlStyle.light:   return 'light';
      case PlStyle.classic: return 'classic';
      case PlStyle.pill:    return 'pill';
      case PlStyle.card:    return 'card';
      case PlStyle.neon:    return 'neon';
      case PlStyle.zoom:    return 'zoom';
      case PlStyle.banner:  return 'banner';
    }
  }
  String get displayEn {
    switch (this) {
      case PlStyle.dark:    return 'Dark';
      case PlStyle.light:   return 'Light';
      case PlStyle.classic: return 'Classic';
      case PlStyle.pill:    return 'Pill';
      case PlStyle.card:    return 'Card';
      case PlStyle.neon:    return 'Neon';
      case PlStyle.zoom:    return 'Zoom';
      case PlStyle.banner:  return 'Banner';
    }
  }
  String get nameKu {
    switch (this) {
      case PlStyle.dark:    return 'تاریک';
      case PlStyle.light:   return 'ڕووناک';
      case PlStyle.classic: return 'کلاسیک';
      case PlStyle.pill:    return 'پیل گرادیەنت';
      case PlStyle.card:    return 'کارد ئاکسنت';
      case PlStyle.neon:    return 'نیۆن ئاوتلاین';
      case PlStyle.zoom:    return 'زووم — نزیک';
      case PlStyle.banner:  return 'بانەر — گرادیێنت';
    }
  }
  IconData get icon {
    switch (this) {
      case PlStyle.dark:    return Icons.dark_mode_rounded;
      case PlStyle.light:   return Icons.light_mode_rounded;
      case PlStyle.classic: return Icons.layers_rounded;
      case PlStyle.pill:    return Icons.healing_rounded;
      case PlStyle.card:    return Icons.credit_card_rounded;
      case PlStyle.neon:    return Icons.bolt_rounded;
      case PlStyle.zoom:    return Icons.zoom_in_rounded;
      case PlStyle.banner:  return Icons.view_stream_rounded;
    }
  }

  /// Styles that require a profile image on proxo-tools.js (source of
  /// truth: `plValidateForm()` in proxo-tools.js). Preserved here so the
  /// Flutter form applies the same rule.
  bool get requiresLogo =>
      this == PlStyle.dark || this == PlStyle.light ||
      this == PlStyle.zoom || this == PlStyle.banner;
}

// ─────────────────────────────────────────────────────────────
// CARD LANGUAGE — text on the *generated card* only.
// (The Flutter app's own form UI stays Kurdish, same as the
// website's own admin form UI stays Kurdish regardless of this.)
// ─────────────────────────────────────────────────────────────

enum CardLang { ku, ar }

extension CardLangInfo on CardLang {
  String get code => this == CardLang.ar ? 'ar' : 'ku';
  String get label => this == CardLang.ar ? 'عربی' : 'کوردی';
}

// ─────────────────────────────────────────────────────────────
// THEME — named themes, matching proxo-tools.js's `themeMap` inside
// buildPLCardHTML() exactly (same from/to gradient hex per theme), so
// a card looks identical whether it was made on the website or here.
// `swatch` is only used for the Flutter theme-picker dot color.
// ─────────────────────────────────────────────────────────────

class CardTheme {
  final String key;
  final Color swatch;
  final String gradFrom;
  final String gradTo;
  const CardTheme(this.key, this.swatch, this.gradFrom, this.gradTo);
}

const List<CardTheme> kCardThemes = [
  CardTheme('purple', Color(0xFFC855E0), '#5b1fa8', '#c855e0'),
  CardTheme('blue',   Color(0xFF2563EB), '#1e3a8a', '#2563eb'),
  CardTheme('green',  Color(0xFF16A34A), '#14532d', '#16a34a'),
  CardTheme('red',    Color(0xFFDC2626), '#7f1d1d', '#dc2626'),
  CardTheme('yellow', Color(0xFFD97706), '#78350f', '#d97706'),
  CardTheme('cyan',   Color(0xFF0891B2), '#164e63', '#0891b2'),
  CardTheme('pink',   Color(0xFFBE185D), '#831843', '#be185d'),
  CardTheme('dark',   Color(0xFF1C2333), '#0d1021', '#1c2333'),
];

/// Swatch colors only, in theme order — used by the Flutter theme picker.
final List<Color> kThemeColors = kCardThemes.map((t) => t.swatch).toList();

/// Resolves a stored `color_theme` value to a [CardTheme]. Handles the
/// normal case (a theme key like `'purple'`) as well as legacy rows from
/// an earlier version of the Flutter app that stored a raw hex string
/// instead (falls back to the closest-matching theme by hex, then to
/// `purple` if nothing matches — same default proxo-tools.js uses).
CardTheme themeByKey(String? key) {
  if (key == null || key.isEmpty) return kCardThemes[0];
  for (final t in kCardThemes) {
    if (t.key == key) return t;
  }
  if (key.startsWith('#')) {
    final lower = key.toLowerCase();
    for (final t in kCardThemes) {
      if (t.gradTo.toLowerCase() == lower || t.gradFrom.toLowerCase() == lower) {
        return t;
      }
    }
  }
  return kCardThemes[0];
}

CardTheme themeBySwatch(Color c) => kCardThemes.firstWhere(
    (t) => t.swatch.value == c.value, orElse: () => kCardThemes[0]);

// ─────────────────────────────────────────────────────────────
// PLATFORMS
// ─────────────────────────────────────────────────────────────

class PlatformBtn {
  final String id, label, type, placeholder;
  final Widget iconWidget;
  final Color iconColor, bgColor;
  final bool isNumeric;
  const PlatformBtn({
    required this.id, required this.label, required this.iconWidget,
    required this.iconColor, required this.bgColor, required this.type,
    required this.placeholder, required this.isNumeric,
  });
}

/// Order + defaults must stay in lockstep with proxo-tools.js's `PL_BTNS`
/// and `plChecked` — this drives the Supabase `platforms` jsonb shape too.
final List<PlatformBtn> kPlatformBtns = [
  PlatformBtn(id:'wa', label:'واتسئاپ',
      iconWidget: const FaIcon(FontAwesomeIcons.whatsapp, size: 20, color: Colors.white),
      iconColor: const Color(0xFF25D366), bgColor: const Color(0xFFE8FDF2),
      type:'whatsapp', placeholder:'9647XXXXXXXXX', isNumeric:true),
  PlatformBtn(id:'vb', label:'ڤایبەر',
      iconWidget: const FaIcon(FontAwesomeIcons.viber, size: 20, color: Colors.white),
      iconColor: const Color(0xFF7360F2), bgColor: const Color(0xFFF3F0FE),
      type:'viber', placeholder:'9647XXXXXXXXX', isNumeric:true),
  PlatformBtn(id:'tg', label:'تیلیگرام',
      iconWidget: const FaIcon(FontAwesomeIcons.telegram, size: 20, color: Colors.white),
      iconColor: const Color(0xFF229ED9), bgColor: const Color(0xFFE8F6FD),
      type:'telegram', placeholder:'username یان 964XXXXXXXX', isNumeric:false),
  PlatformBtn(id:'ig', label:'ئینستاگرام',
      iconWidget: const FaIcon(FontAwesomeIcons.instagram, size: 20, color: Colors.white),
      iconColor: const Color(0xFFE1306C), bgColor: const Color(0xFFFCE8F0),
      type:'instagram', placeholder:'username', isNumeric:false),
  PlatformBtn(id:'ph', label:'کۆرەک',
      iconWidget: const FaIcon(FontAwesomeIcons.phone, size: 17, color: Colors.white),
      iconColor: const Color(0xFF2563EB), bgColor: const Color(0xFFEBF2FF),
      type:'phone', placeholder:'9647XXXXXXXXX', isNumeric:true),
  PlatformBtn(id:'as', label:'ئاسیا سێڵ',
      iconWidget: const FaIcon(FontAwesomeIcons.mobileScreenButton, size: 20, color: Colors.white),
      iconColor: const Color(0xFFEF4444), bgColor: const Color(0xFFFEECEC),
      type:'asya', placeholder:'9647XXXXXXXXX', isNumeric:true),
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

/// On-card label per platform id, by card language — matches
/// proxo-tools.js's `platDefs` inside buildPLCardHTML(). This is
/// deliberately separate from `PlatformBtn.label` (which is the
/// Flutter *form's own* UI text and always stays Kurdish).
const Map<String, Map<String, String>> kPlatformCardLabels = {
  'wa': {'ku': 'واتسئاپ',    'ar': 'واتساب'},
  'vb': {'ku': 'ڤایبەر',     'ar': 'فايبر'},
  'tg': {'ku': 'تیلیگرام',   'ar': 'تيليجرام'},
  'ig': {'ku': 'ئینستاگرام', 'ar': 'إنستغرام'},
  'ph': {'ku': 'کۆرەک',      'ar': 'كورك'},
  'as': {'ku': 'ئاسیا سێڵ',  'ar': 'آسيا سيل'},
};

/// URL scheme prefix per platform id — the contact value is appended
/// directly, exactly as proxo-tools.js's `platDefs[type].url` does.
const Map<String, String> kPlatformUrlScheme = {
  'wa': 'whatsapp://send?phone=',
  'vb': 'viber://chat?number=',
  'ig': 'https://instagram.com/',
  'tg': 'https://t.me/',
  'ph': 'tel:',
  'as': 'tel:',
};

String platformCardLabel(String id, CardLang lang) =>
    kPlatformCardLabels[id]?[lang.code] ?? id;

// ─────────────────────────────────────────────────────────────
// SMALL HELPERS
// ─────────────────────────────────────────────────────────────

String _escHtml(String s) => s
    .replaceAll('&', '&amp;').replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;').replaceAll('"', '&quot;');

String _escHtmlText(String text) =>
    ProxoTextDirection.html(text, escape: _escHtml);


/// Escapes text embedded inside a single-quoted inline `<script>` string
/// literal (e.g. inside `askConfirm('...', '...', '...')`). proxo-tools.js
/// does not escape this at all, which means a contact value containing a
/// stray `'` breaks the whole generated page there. We defend against
/// that here so a bad character a user pastes in can't produce a broken
/// HTML file (a page that "opens in browser independently" is one of the
/// acceptance tests for this feature).
String _escJs(String s) => s
    .replaceAll('\\', '\\\\')
    .replaceAll("'", "\\'")
    .replaceAll('\n', ' ')
    .replaceAll('\r', ' ');

const _btnBg = <String, String>{
  'wa': 'linear-gradient(to left,#128c7e,#25d366)',
  'vb': 'linear-gradient(to left,#5c4fd6,#7360f2)',
  'tg': 'linear-gradient(to left,#229ed9,#2aabee)',
  'ig': 'linear-gradient(to left,#833ab4,#fd1d1d,#f09433)',
  'ph': 'linear-gradient(to left,#1d4ed8,#2563eb)',
  'as': 'linear-gradient(to left,#b91c1c,#dc2626)',
};
// Used by pill/card/zoom/banner (their box-shadow color, .42 alpha).
const _btnSh = <String, String>{
  'wa': 'rgba(37,211,102,.42)', 'vb': 'rgba(115,96,242,.42)',
  'tg': 'rgba(42,171,238,.42)', 'ig': 'rgba(220,39,67,.42)',
  'ph': 'rgba(37,99,235,.42)',  'as': 'rgba(220,38,38,.42)',
};
// Neon's own glow-shadow color map — same hues as _btnSh but .6 alpha,
// NOT reused from _btnSh (verified against buildPageNeon's own `btnGw`
// in proxo-tools.js, which is distinct from the `btnSh` other styles use).
const _btnGw = <String, String>{
  'wa': 'rgba(37,211,102,.6)', 'vb': 'rgba(115,96,242,.6)',
  'tg': 'rgba(42,171,238,.6)', 'ig': 'rgba(220,39,67,.6)',
  'ph': 'rgba(37,99,235,.6)',  'as': 'rgba(220,38,38,.6)',
};
// Classic's own button colors — solid, NOT the _btnBg gradients (verified
// against buildPageClassic's own `btnColors` in proxo-tools.js).
const _classicBtnColors = <String, String>{
  'wa': '#25d366', 'vb': '#7360F2', 'tg': '#29a8eb',
  'ig': 'linear-gradient(to right,#8a2387,#e94057,#f27121)',
  'ph': '#e03030', 'as': '#e03030',
};
const _btnIco = <String, String>{
  'wa': 'fa-whatsapp', 'vb': 'fa-viber', 'tg': 'fa-telegram',
  'ig': 'fa-instagram', 'ph': 'fa-phone-alt', 'as': 'fa-phone-alt',
};
const _btnIcoSz = <String, String>{
  'wa': '25', 'vb': '22', 'tg': '22', 'ig': '22', 'ph': '20', 'as': '20',
};
const _icoClass = <String, String>{
  'wa': 'fab', 'vb': 'fab', 'tg': 'fab', 'ig': 'fab', 'ph': 'fas', 'as': 'fas',
};

/// TikTok's own profile URL always uses the `www.` subdomain — matches
/// proxo-tools.js's `ttUrl` (`'https://www.tiktok.com/@' + tt`) exactly.
String _ttUrl(String tt) => 'https://www.tiktok.com/@' + tt;

/// One active platform, resolved with its actual contact value and its
/// on-card label for the current card language.
class _ActivePlatform {
  final PlatformBtn btn;
  final String contact;
  final String cardLabel;
  const _ActivePlatform(this.btn, this.contact, this.cardLabel);
}

List<_ActivePlatform> _resolveActivePlatforms(
    List<bool> checked, Map<int, String> contacts, CardLang lang) {
  final out = <_ActivePlatform>[];
  for (int i = 0; i < checked.length && i < kPlatformBtns.length; i++) {
    if (!checked[i]) continue;
    final value = (contacts[i] ?? '').trim();
    if (value.isEmpty) continue; // matches plGetPlatforms(): only filled values count
    final btn = kPlatformBtns[i];
    out.add(_ActivePlatform(btn, value, platformCardLabel(btn.id, lang)));
  }
  return out;
}

// ── DARK / LIGHT: grid layout ──────────────────────────────────────────
// Mirrors proxo-tools.js's `buildLayout()` exactly:
//  - WhatsApp is always pinned to the 2nd grid slot (RTL: visually the
//    left button) when present, regardless of the order it was toggled.
//  - Exactly 1, 3, or 5 active platforms get a special layout: the last
//    button pairs with a compact TikTok pill in a "three-bottom-row"
//    below the (now-shorter) grid, instead of the usual full grid + a
//    separate centered TikTok badge.
//  - Exactly one button gets the shimmer (`shine-active`) effect — the
//    2nd slot in the normal case, or the paired bottom-row button in the
//    1/3/5 case.
// Returns the grid's inner HTML and the *complete*, self-contained
// sibling block that goes right after `</div>` of the grid (already
// includes its own tt-wrap/three-bottom-row wrapper — nothing further
// should wrap it).
class _DarkLightLayout {
  final String gridHtml;
  final String belowGridHtml;
  const _DarkLightLayout(this.gridHtml, this.belowGridHtml);
}

String _gridBtn(_ActivePlatform p, bool shine) {
  final id = p.btn.id;
  final ico = _btnIco[id] ?? 'fa-circle';
  final cls = _icoClass[id] ?? 'fas';
  final sz  = _btnIcoSz[id] ?? '22';
  // Matches proxo-tools.js's makeBtnInner(): icon + a <span>-wrapped label
  // (not bare text) — kept even though dark/light's CSS has no `.btn span`
  // rule of its own, purely for exact DOM-structure fidelity.
  return '<a id="' + id + '" class="btn' + (shine ? ' shine-active' : '') + '">'
      + '<i class="' + cls + ' ' + ico + '" style="font-size:' + sz + 'px"></i>'
      + '<span dir="auto">' + _escHtmlText(p.cardLabel) + '</span></a>';
}

_DarkLightLayout _buildDarkLightLayout(List<_ActivePlatform> activePlats, String tt) {
  final btns = List<_ActivePlatform>.from(activePlats);
  final waIdx = btns.indexWhere((p) => p.btn.id == 'wa');
  if (waIdx == 0 && btns.length >= 2) {
    final tmp = btns[0]; btns[0] = btns[1]; btns[1] = tmp;
  } else if (waIdx > 1) {
    final wa = btns.removeAt(waIdx);
    btns.insert(1, wa);
  }

  const shineIdx = 1;
  final ttUrl = _ttUrl(tt);
  final ttEsc = _escHtml(tt);

  String ttPill() => '<a href="' + ttUrl + '" target="_blank" class="tt-pill">'
      '<span>@' + ttEsc + '</span><i class="fab fa-tiktok"></i></a>';
  String ttBadgeWrap() => '<div class="tt-wrap"><a href="' + ttUrl
      + '" target="_blank" class="tt-badge"><span>@' + ttEsc
      + '</span><i class="fab fa-tiktok"></i></a></div>';

  final count = btns.length;
  if (count == 1) {
    return _DarkLightLayout('',
        '<div class="three-bottom-row">' + ttPill() + _gridBtn(btns[0], true) + '</div>');
  } else if (count == 3) {
    final grid = _gridBtn(btns[0], false) + _gridBtn(btns[1], true);
    final below = '<div class="three-bottom-row">' + ttPill() + _gridBtn(btns[2], false) + '</div>';
    return _DarkLightLayout(grid, below);
  } else if (count == 5) {
    final grid = _gridBtn(btns[0], false) + _gridBtn(btns[1], true)
        + _gridBtn(btns[2], false) + _gridBtn(btns[3], false);
    final below = '<div class="three-bottom-row">' + ttPill() + _gridBtn(btns[4], false) + '</div>';
    return _DarkLightLayout(grid, below);
  } else {
    final grid = StringBuffer();
    for (int i = 0; i < btns.length; i++) {
      grid.write(_gridBtn(btns[i], i == shineIdx));
    }
    return _DarkLightLayout(grid.toString(), ttBadgeWrap());
  }
}

// ── PILL-SHAPED BUTTONS (pill / card / neon / zoom / banner) ──────────
// All five styles share the same `<a class="pl-btn">` structure and the
// same `_btnBg` color map — they differ only in the box-shadow formula
// (and neon uses its own `_btnGw` glow-color map instead of `_btnSh`).
// Only the FIRST active button gets `shine-active` (verified: `i===0` in
// every one of buildPagePill/Card/Neon/Zoom/Banner).
String _buildPlBtn(_ActivePlatform p, bool shine, String boxShadow) {
  final id = p.btn.id;
  final bg = _btnBg[id] ?? 'linear-gradient(to left,#555,#888)';
  final sz = _btnIcoSz[id] ?? '22';
  return '<a id="' + id + '" class="pl-btn' + (shine ? ' shine-active' : '') + '"'
      + ' style="background:' + bg + ';box-shadow:' + boxShadow + ';">'
      + '<span style="width:44px;flex-shrink:0;"></span>'
      + '<span class="pl-lbl" dir="auto">' + _escHtmlText(p.cardLabel) + '</span>'
      + '<i class="' + (_icoClass[id] ?? 'fas') + ' ' + (_btnIco[id] ?? 'fa-circle') + '"'
      + ' style="font-size:' + sz + 'px;width:44px;flex-shrink:0;text-align:center;"></i></a>';
}

/// pill / zoom / banner: `box-shadow: 0 5px 18px {sh}` with `_btnSh` (.42 alpha).
String _buildPillButtons(List<_ActivePlatform> plats) {
  final buf = StringBuffer();
  for (int i = 0; i < plats.length; i++) {
    final sh = _btnSh[plats[i].btn.id] ?? 'rgba(0,0,0,.25)';
    buf.write(_buildPlBtn(plats[i], i == 0, '0 5px 18px ' + sh));
  }
  return buf.toString();
}

/// card: same colors as pill, but `box-shadow: 0 6px 20px {sh}`.
String _buildCardButtons(List<_ActivePlatform> plats) {
  final buf = StringBuffer();
  for (int i = 0; i < plats.length; i++) {
    final sh = _btnSh[plats[i].btn.id] ?? 'rgba(0,0,0,.25)';
    buf.write(_buildPlBtn(plats[i], i == 0, '0 6px 20px ' + sh));
  }
  return buf.toString();
}

/// neon: own `_btnGw` glow-color map (.6 alpha) + a second fixed dark
/// shadow layer: `box-shadow: 0 0 28px {gw}, 0 5px 16px rgba(0,0,0,.5)`.
String _buildNeonButtons(List<_ActivePlatform> plats) {
  final buf = StringBuffer();
  for (int i = 0; i < plats.length; i++) {
    final gw = _btnGw[plats[i].btn.id] ?? 'rgba(255,255,255,.2)';
    buf.write(_buildPlBtn(plats[i], i == 0, '0 0 28px ' + gw + ',0 5px 16px rgba(0,0,0,.5)'));
  }
  return buf.toString();
}

/// classic: its own `_classicBtnColors` map (mostly solid, not gradient),
/// a different button shape (`.btn-classic`), shine on the first button.
String _buildClassicButtons(List<_ActivePlatform> plats) {
  final buf = StringBuffer();
  for (int i = 0; i < plats.length; i++) {
    final p = plats[i];
    final id = p.btn.id;
    final bg = _classicBtnColors[id] ?? '#888';
    final ico = _btnIco[id] ?? 'fa-circle';
    final cls = _icoClass[id] ?? 'fas';
    buf.write('<a id="' + id + '" class="btn-classic' + (i == 0 ? ' shine-active' : '')
        + '" style="background:' + bg + '">'
        + '<div class="ic-spacer"></div>'
        + '<span dir="auto">' + _escHtmlText(p.cardLabel) + '</span>'
        + '<div class="ic-wrap"><i class="' + cls + ' ' + ico + '"></i></div></a>');
  }
  return buf.toString();
}

// ── TikTok badges/pills, one shape per style family ────────────────────
// Each mirrors its JS counterpart's exact element order (span before
// icon — RTL flips the visual side, so getting this order right matters
// for which side the icon lands on) and the shared `www.tiktok.com` URL.

String _buildTtBadgePill(String tt) {
  if (tt.isEmpty) return '';
  return '<div class="tt-wrap"><a href="' + _ttUrl(tt)
      + '" target="_blank" class="tt-sm"><span dir="ltr">@' + _escHtml(tt)
      + '</span><i class="fab fa-tiktok" style="font-size:18px"></i></a></div>';
}

String _buildTtBadgeClassic(String tt) {
  if (tt.isEmpty) return '';
  return '<a href="' + _ttUrl(tt) + '" target="_blank" class="tt-classic">'
      '<span dir="ltr">@' + _escHtml(tt) + '</span><i class="fab fa-tiktok"></i></a>';
}

String _buildTtInline(String tt) {
  if (tt.isEmpty) return '';
  return '<div style="display:inline-flex;align-items:center;gap:5px;background:rgba(0,0,0,.28);'
      'padding:4px 12px;border-radius:20px;color:rgba(255,255,255,.92);font-size:12px;margin-top:6px;">'
      '<span dir="ltr">@' + _escHtml(tt) + '</span><i class="fab fa-tiktok"></i></div>';
}

/// Builds the real `{{HANDLERS}}` script — one `getElementById(...).onclick`
/// assignment per active platform, wired to the real contact value and the
/// correct url scheme, tapping the page's own `askConfirm(type, url, label)`
/// (already defined per-template in card_templates.dart). This is what
/// actually makes the generated buttons work; matches proxo-tools.js's
/// `handlers` builder inside buildPLCardHTML().
String _buildHandlersScript(List<_ActivePlatform> plats) {
  final buf = StringBuffer();
  for (final p in plats) {
    final scheme = kPlatformUrlScheme[p.btn.id] ?? '';
    final url = scheme + p.contact;
    buf.write("document.getElementById('" + p.btn.id + "').onclick=function(){"
        + "askConfirm('" + p.btn.type + "','" + _escJs(url) + "','" + _escJs(p.cardLabel) + "');};\n  ");
  }
  return buf.toString().trimRight();
}

// ─────────────────────────────────────────────────────────────
// MAIN GENERATOR
// ─────────────────────────────────────────────────────────────

/// Builds the final, standalone HTML for a ProxoLink card. This is used
/// for the live preview, the file saved to Supabase, and the file sent to
/// Telegram — always the exact same generation path, so what the user
/// sees while editing is exactly what gets published.
String buildCardHtml({
  required String name,
  required String bio,
  required String tt,
  required String logoB64,
  required String themeKey,
  required PlStyle style,
  required List<bool> checked,
  required Map<int, String> contacts,
  CardLang lang = CardLang.ku,
}) {
  final theme = themeByKey(themeKey);
  // Matches proxo-tools.js's `themeMap[key].grad` exactly: a left-to-right
  // gradient, not a diagonal one — verified against buildPLCardHTML's
  // themeMap in proxo-tools.js (an earlier version of this function used
  // `135deg` here, which doesn't match the website's output).
  final grad = 'linear-gradient(to right,' + theme.gradFrom + ',' + theme.gradTo + ')';

  final activePlats = _resolveActivePlatforms(checked, contacts, lang);

  final avatarHtml = logoB64.isNotEmpty
      ? '<img src="' + logoB64 + '" style="width:100%;height:100%;object-fit:cover;border-radius:50%">'
      : '<span style="font-size:26px;font-weight:800;color:#fff;line-height:1">'
        + (name.isNotEmpty ? name[0].toUpperCase() : 'P') + '</span>';

  String buttons; String ttBadge; String ttInline = '';

  switch (style) {
    case PlStyle.dark:
    case PlStyle.light:
      // WhatsApp-reordering, odd-count (1/3/5) special layout, and single-
      // button shine targeting all live in _buildDarkLightLayout — see its
      // doc comment. belowGridHtml is a complete, self-contained sibling
      // block (already includes its own tt-wrap/three-bottom-row wrapper),
      // which is exactly what {{TT_BADGE}} expects now that it sits
      // outside <div class="grid"> in card_templates.dart.
      final layout = _buildDarkLightLayout(activePlats, tt);
      buttons = layout.gridHtml;
      ttBadge = layout.belowGridHtml;
      break;
    case PlStyle.classic:
      buttons = _buildClassicButtons(activePlats);
      ttBadge = _buildTtBadgeClassic(tt);
      break;
    case PlStyle.pill:
    case PlStyle.banner: // banner's buttons are identical to pill's — same colors, same 0 5px 18px shadow
      buttons = _buildPillButtons(activePlats);
      ttBadge = _buildTtBadgePill(tt);
      break;
    case PlStyle.card:
      buttons = _buildCardButtons(activePlats);
      ttBadge = _buildTtBadgePill(tt);
      break;
    case PlStyle.neon:
      buttons = _buildNeonButtons(activePlats);
      ttBadge = _buildTtBadgePill(tt);
      break;
    case PlStyle.zoom:
      buttons = _buildPillButtons(activePlats);
      ttBadge = _buildTtBadgePill(tt);
      break;
  }

  // Banner shows TikTok inline in the header instead of as a badge below
  // the buttons — overrides the ttBadge set above for banner specifically.
  if (style == PlStyle.banner) {
    ttBadge = '';
    ttInline = _buildTtInline(tt);
  }

  final handlers = _buildHandlersScript(activePlats);

  String html = CardTemplates.forStyle(style.nameEn);
  html = html
      .replaceAll('{{NAME}}',         _escHtmlText(name))
      .replaceAll('{{BIO}}',          _escHtmlText(bio))
      .replaceAll('{{AVATAR}}',       avatarHtml)
      .replaceAll('{{GRAD}}',         grad)
      .replaceAll('{{BUTTONS}}',      buttons)
      .replaceAll('{{TT_BADGE}}',     ttBadge)
      .replaceAll('{{TT_INLINE}}',    ttInline)
      .replaceAll('{{THEME_FROM}}',   theme.gradFrom)
      .replaceAll('{{THEME_TO}}',     theme.gradTo)
      .replaceAll('{{HANDLERS}}',     handlers);
  return html;
}
