import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Public release metadata only. Build numbers are monotonic per platform;
/// version strings are display labels, never lexicographically compared.
class AppUpdatePolicy {
  const AppUpdatePolicy(
      {required this.latestBuild,
      required this.minimumBuild,
      required this.version,
      required this.url,
      required this.message,
      required this.revision,
      required this.requiredEnabled});
  final int latestBuild, minimumBuild, revision;
  final String version, message;
  final Uri url;
  final bool requiredEnabled;

  bool isRequired(int installedBuild) =>
      requiredEnabled && installedBuild < minimumBuild;
  bool isAvailable(int installedBuild) => installedBuild < latestBuild;

  static AppUpdatePolicy? parse(Object? raw) {
    if (raw is! Map ||
        raw['enabled'] != true ||
        raw['release_verified'] != true) return null;
    final latest = raw['latest_build'];
    final minimum = raw['minimum_build'];
    final revision = raw['revision'];
    final version = raw['latest_version'];
    final message = raw['message'] ?? '';
    if (message is! String || message.length > 600) return null;
    final url = Uri.tryParse(raw['update_url']?.toString() ?? '');
    final published = DateTime.tryParse(raw['published_at']?.toString() ?? '');
    if (latest is! int ||
        minimum is! int ||
        revision is! int ||
        latest < 1 ||
        minimum < 0 ||
        minimum > latest ||
        revision < 1 ||
        version is! String ||
        version.trim().isEmpty ||
        version.length > 40 ||
        published == null ||
        published.isAfter(DateTime.now().toUtc()) ||
        url == null ||
        url.scheme != 'https' ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        (url.hasPort && url.port != 443) ||
        !allowedUpdateDestination(url)) return null;
    return AppUpdatePolicy(
        latestBuild: latest,
        minimumBuild: minimum,
        revision: revision,
        version: version,
        url: url,
        message: message.trim(),
        requiredEnabled: raw['required_enabled'] == true);
  }

  /// Distribution destinations must be reviewed before adding another host.
  /// No arbitrary server-provided deep links, credentials, or executable schemes.
  static bool allowedUpdateDestination(Uri url) =>
      (url.host == 'play.google.com' &&
          url.path == '/store/apps/details' &&
          url.queryParameters['id'] == 'com.proxo.proxoapp') ||
      (const {'proxobalance.app', 'www.proxobalance.app'}.contains(url.host) &&
          url.path.startsWith('/downloads/'));
}

typedef FetchUpdatePolicy = Future<Object?> Function(
    String platform, String channel);

class AppUpdateService {
  AppUpdateService(
      {required this.fetch,
      required this.preferences,
      DateTime Function()? now})
      : now = now ?? DateTime.now;
  final FetchUpdatePolicy fetch;
  final SharedPreferences preferences;
  final DateTime Function() now;
  static const cacheLifetime = Duration(hours: 24);
  static const laterInterval = Duration(hours: 24);

  String _cacheKey(String platform, String channel) =>
      'release-policy-v1:$platform:$channel';
  String _laterKey(
          AppUpdatePolicy policy, String platform, String channel, int build) =>
      'release-later-v1:$platform:$channel:$build:${policy.latestBuild}:${policy.revision}';

  Future<AppUpdatePolicy?> load(String platform, String channel) async {
    final key = _cacheKey(platform, channel);
    try {
      final raw =
          await fetch(platform, channel).timeout(const Duration(seconds: 5));
      final policy = AppUpdatePolicy.parse(raw);
      if (policy == null) {
        // A disabled/withdrawn policy authoritatively clears an old gate.
        await preferences.remove(key);
        return null;
      }
      await preferences.setString(
          key, jsonEncode({'policy': raw, 'at': now().millisecondsSinceEpoch}));
      return policy;
    } catch (_) {
      try {
        final cached = jsonDecode(preferences.getString(key) ?? 'null');
        if (cached is! Map || cached['at'] is! int) return null;
        final age = now().difference(
            DateTime.fromMillisecondsSinceEpoch(cached['at'] as int));
        if (age.isNegative || age > cacheLifetime) return null;
        return AppUpdatePolicy.parse(cached['policy']);
      } catch (_) {
        return null;
      }
    }
  }

  bool shouldOffer(
      AppUpdatePolicy policy, String platform, String channel, int build) {
    if (!policy.isAvailable(build)) return false;
    if (policy.isRequired(build)) return true;
    final deferredAt =
        preferences.getInt(_laterKey(policy, platform, channel, build));
    if (deferredAt == null) return true;
    return now().millisecondsSinceEpoch - deferredAt >=
        laterInterval.inMilliseconds;
  }

  Future<void> defer(
          AppUpdatePolicy policy, String platform, String channel, int build) =>
      preferences.setInt(_laterKey(policy, platform, channel, build),
          now().millisecondsSinceEpoch);
}
