import 'package:flutter/foundation.dart';

/// Product selections are immediate local state, never proof of asset access.
@immutable
class MetaAdSelection {
  final Set<String> placements, destinations, unavailable;
  const MetaAdSelection({
    this.placements = const {'facebook', 'instagram'},
    this.destinations = const {'WHATSAPP', 'MESSENGER', 'INSTAGRAM_DIRECT'},
    this.unavailable = const {},
  });

  bool available(String destination) =>
      !unavailable.contains(destination) &&
      switch (destination) {
        'WHATSAPP' => true,
        'MESSENGER' => placements.contains('facebook'),
        'INSTAGRAM_DIRECT' => placements.contains('instagram'),
        _ => false,
      };

  MetaAdSelection togglePlacement(String placement) {
    if (!const {'facebook', 'instagram'}.contains(placement)) return this;
    final next = {...placements};
    if (!next.add(placement)) next.remove(placement);
    if (next.isEmpty) return this;
    final selected = {...destinations};
    if (!next.contains('facebook')) selected.remove('MESSENGER');
    if (!next.contains('instagram')) selected.remove('INSTAGRAM_DIRECT');
    return MetaAdSelection(
        placements: Set.unmodifiable(next),
        destinations: Set.unmodifiable(selected),
        unavailable: unavailable);
  }

  MetaAdSelection toggleDestination(String destination) {
    final next = {...destinations};
    if (next.contains(destination)) {
      // An invalid selected destination may always be removed.
      if (available(destination) && next.where(available).length == 1) {
        return this;
      }
      next.remove(destination);
    } else {
      if (!available(destination)) return this;
      next.add(destination);
    }
    return MetaAdSelection(
        placements: placements,
        destinations: Set.unmodifiable(next),
        unavailable: unavailable);
  }

  static List<String> canonical(Iterable<String> values) =>
      values.toList()..sort();
}

bool validMetaUrl(String value, {bool page = false}) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      value.trim().length > 2048 ||
      value.trim().contains(RegExp(r'\s'))) {
    return false;
  }
  final host = uri.host.toLowerCase();
  final facebook = const {
    'facebook.com',
    'www.facebook.com',
    'm.facebook.com',
    'web.facebook.com',
    'fb.watch'
  }.contains(host);
  final instagram = const {'instagram.com', 'www.instagram.com'}.contains(host);
  if (page) {
    return facebook &&
        host != 'fb.watch' &&
        uri.path.isNotEmpty &&
        uri.path != '/' &&
        !RegExp(r'/(posts|videos|reel|share)/').hasMatch(uri.path);
  }
  return (facebook && uri.path.isNotEmpty && uri.path != '/') ||
      (instagram && RegExp(r'^/(p|reel|tv)/[^/]+').hasMatch(uri.path));
}

const metaObjectiveLabels = {
  'messages': 'نامە',
  'views': 'بینین',
  'engagement': 'کارلێک',
};
const metaObjectiveCodes = {
  'messages': 'MESSAGES',
  'views': 'VIDEO_VIEWS',
  'engagement': 'VIDEO_ENGAGEMENT',
};
