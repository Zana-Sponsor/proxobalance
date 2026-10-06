import 'package:flutter/material.dart';

const proxoTemplateKeys = ['pill', 'pill-mint', 'pill-dark', 'pill-white'];
const proxoTemplateVersion = 2;
const proxoPageTypes = {
  'contact': 'پەیوەندی',
  'food': 'داواکردنی خواردن',
  'download': 'دابەزاندنی ئەپ',
};

class PlatformBtn {
  final String id, label, group, placeholder;
  final List<String> hosts;
  final bool isNumeric;
  final Color color;
  const PlatformBtn(this.id, this.label, this.group, this.placeholder,
      this.hosts, this.color, {this.isNumeric = false});
}

const kPlatformBtns = [
  PlatformBtn('wa', 'واتسئاپ', 'contact', '0750… / +964750…',
      ['wa.me', 'api.whatsapp.com', 'www.whatsapp.com'], Color(0xFF25D366), isNumeric: true),
  PlatformBtn('tg', 'تیلیگرام', 'contact', '@username / https://t.me/…',
      ['t.me', 'telegram.me', 'telegram.org'], Color(0xFF0073B5)),
  PlatformBtn('vb', 'ڤایبەر', 'contact', '0750… / +964750…',
      ['viber.com'], Color(0xFF6F5BED), isNumeric: true),
  PlatformBtn('ph', 'کۆڕەک', 'contact', '0750… / +964750…',
      [], Color(0xFF0060AB), isNumeric: true),
  PlatformBtn('as', 'ئاسیاسێڵ', 'contact', '0770… / +964770…',
      [], Color(0xFFC61932), isNumeric: true),
  // Keep existing customer Instagram links usable during the migration.
  PlatformBtn('ig', 'ئینستاگرام', 'contact', '@username / https://instagram.com/…',
      ['instagram.com'], Color(0xFFA72868)),
  PlatformBtn('talabat', 'تەڵەبات', 'food', 'https://www.talabat.com/…',
      ['talabat.com'], Color(0xFFFF5A00)),
  PlatformBtn('lezzoo', 'لەزوو', 'food', 'https://lezzoo.com/…',
      ['lezzoo.com', 'lezzoodevs.com'], Color(0xFFE63946)),
  PlatformBtn('wade', 'وادێ', 'food', 'https://wadedelivery.com/…',
      ['wadedelivery.com', 'trytiptop.com'], Color(0xFF00C6E8)),
  PlatformBtn('toters', 'توتەرز', 'food', 'https://www.totersapp.com/…',
      ['totersapp.com', 'toters.com'], Color(0xFF10B899)),
  PlatformBtn('app_store', 'App Store', 'download', 'https://apps.apple.com/…/id…',
      ['apps.apple.com'], Color(0xFF111111)),
  PlatformBtn('google_play', 'Google Play', 'download', 'https://play.google.com/store/apps/details?id=…',
      ['play.google.com'], Color(0xFF111111)),
];

const platformAliases = {
  'whatsapp': 'wa', 'telegram': 'tg', 'viber': 'vb', 'instagram': 'ig',
  'phone': 'ph', 'korek': 'ph', 'asya': 'as', 'asiacell': 'as',
};
String normalizedProxoDigits(String value) => value.replaceAllMapped(
    RegExp('[٠-٩۰-۹]'), (m) => '${m[0]!.codeUnitAt(0) - (m[0]!.codeUnitAt(0) <= 1641 ? 1632 : 1776)}');

/// Matches the server validation; arbitrary URI schemes never leave WebView.
Uri? proxoDestination(String id, String raw) {
  final providers = kPlatformBtns.where((p) => p.id == id);
  if (providers.isEmpty) return null;
  final p = providers.first;
  var value = normalizedProxoDigits(raw).trim();
  if (value.isEmpty || value.length > 2048) return null;
  if (['wa', 'vb', 'ph', 'as'].contains(id) && !value.contains('://')) {
    var n = value.replaceFirst(RegExp(r'^tel:', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\s()-]'), '');
    if (RegExp(r'^07\d{9}$').hasMatch(n)) n = '+964${n.substring(1)}';
    if (!RegExp(r'^\+?[1-9]\d{6,14}$').hasMatch(n)) return null;
    if (id == 'wa') return Uri.https('wa.me', '/${n.replaceFirst('+', '')}');
    if (id == 'vb') return Uri.parse('viber://chat').replace(queryParameters: {'number': '+${n.replaceFirst('+', '')}'});
    return Uri.parse('tel:$n');
  }
  if (['tg', 'ig'].contains(id) && !value.contains('://')) {
    value = value.replaceFirst(RegExp(r'^@'), '');
    if (!RegExp(r'^[a-zA-Z0-9._]{1,40}$').hasMatch(value)) return null;
    return Uri.https(id == 'tg' ? 't.me' : 'www.instagram.com', '/$value');
  }
  final u = Uri.tryParse(value);
  if (u == null || u.userInfo.isNotEmpty || u.hasFragment && u.scheme == 'viber') return null;
  if (id == 'vb' && u.scheme == 'viber') {
    final n = u.queryParameters['number'] ?? '';
    if (u.host != 'chat' || u.path.isNotEmpty || u.hasPort ||
        u.queryParametersAll.length != 1 || u.queryParametersAll['number']?.length != 1 ||
        !RegExp(r'^\+?[1-9]\d{6,14}$').hasMatch(n)) return null;
    return u;
  }
  if (u.scheme != 'https' || (u.hasPort && u.port != 443) ||
      !p.hosts.any((h) => u.host == h || u.host.endsWith('.$h'))) return null;
  if (id == 'app_store' && !RegExp(r'/id\d+').hasMatch(u.path)) return null;
  if (id == 'google_play' && (!RegExp(r'^/store/apps/details/?$').hasMatch(u.path) ||
      (u.queryParameters['id'] ?? '').isEmpty)) return null;
  return u;
}

bool allowedProxoExternal(Uri uri) {
  if (uri.scheme == 'https' && uri.userInfo.isEmpty && (!uri.hasPort || uri.port == 443) &&
      ['www.tiktok.com', 'tiktok.com', 'vm.tiktok.com', 'vt.tiktok.com'].contains(uri.host)) return true;
  return kPlatformBtns.any((p) => proxoDestination(p.id, uri.toString()) != null);
}
