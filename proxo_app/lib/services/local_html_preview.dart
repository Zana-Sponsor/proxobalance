// ═══════════════════════════════════════════════════════════════════════
// LOCAL HTML PREVIEW — opens an already-generated ProxoLink landing page
// in the device's own browser, entirely from the phone.
//
// NO domain. NO hosting. NO upload. NO https:// URL. NO in-app WebView.
//
//   saved html_content
//     └─> <cache>/proxo_preview/proxo_preview_<id>.html   (UTF-8)
//           └─> Android FileProvider  ->  content:// URI
//                 └─> ACTION_VIEW + text/html + FLAG_GRANT_READ_URI_PERMISSION
//                       └─> whatever browser/app the user has (Android picks)
//
// The Android half lives in:
//   android/app/src/main/kotlin/com/proxo/proxoapp/MainActivity.kt
//   android/app/src/main/res/xml/proxo_file_paths.xml
//   android/app/src/main/AndroidManifest.xml   (<provider> + <queries>)
//
// The file written here is the EXACT html the card already carries — it is
// never re-generated, simplified, or rewritten (see §30 of the brief).
// ═══════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Why a preview attempt ended. Every one of these has a Kurdish message —
/// the flow never fails silently and never throws at the call site.
enum LocalPreviewStatus {
  /// Handed off to an external app successfully.
  opened,

  /// The card has no stored HTML at all (older row, failed save, …).
  missingHtml,

  /// Stored HTML exists but isn't a usable document.
  corruptHtml,

  /// Couldn't write the temp file (no space, sandbox error, …).
  writeFailed,

  /// Nothing on the device can open a local text/html document.
  noApp,

  /// Anything else — provider misconfiguration, launch refused, …
  failed,
}

@immutable
class LocalPreviewResult {
  final LocalPreviewStatus status;
  final String? path;
  const LocalPreviewResult(this.status, {this.path});

  bool get ok => status == LocalPreviewStatus.opened;

  /// Kurdish, user-facing. Deliberately never contains an exception string.
  String get messageKu {
    switch (status) {
      case LocalPreviewStatus.opened:
        return '';
      case LocalPreviewStatus.missingHtml:
        return 'ئەم ئامرازە پەڕەی پاشەکەوتکراوی نییە';
      case LocalPreviewStatus.corruptHtml:
        return 'پەڕەی پاشەکەوتکراو تەواو نییە — دووبارە دروستی بکەرەوە';
      case LocalPreviewStatus.writeFailed:
        return 'نەتوانرا فایلی پێشبینین دروست بکرێت — بۆشایی ئامێرەکەت بپشکنە';
      case LocalPreviewStatus.noApp:
        return 'هیچ وێبگەڕێک نەدۆزرایەوە بۆ کردنەوەی پەڕەکە';
      case LocalPreviewStatus.failed:
        return 'کردنەوەی پێشبینین سەرنەکەوت — دووبارە هەوڵ بدەرەوە';
    }
  }
}

class LocalHtmlPreview {
  LocalHtmlPreview._();

  static const MethodChannel _channel = MethodChannel('proxo/local_preview');

  /// Sub-folder of the app cache. MUST match the `path` in
  /// res/xml/proxo_file_paths.xml, or FileProvider refuses the file.
  static const String _dirName = 'proxo_preview';

  /// Preview files older than this are swept on the next successful open.
  static const Duration _maxAge = Duration(days: 3);

  /// Writes [html] to a private temp `.html` file and hands it to an
  /// external app. [id] only shapes the filename — one stable file per
  /// card, overwritten whenever the card's content changes (§31).
  static Future<LocalPreviewResult> open({
    required String? html,
    required String id,
    String? title,
  }) async {
    // ── 1. Guard the stored HTML ──────────────────────────────────────
    if (html == null || html.trim().isEmpty) {
      return const LocalPreviewResult(LocalPreviewStatus.missingHtml);
    }
    if (!html.contains('<')) {
      return const LocalPreviewResult(LocalPreviewStatus.corruptHtml);
    }

    // ── 2. Write it into the app cache (no storage permission needed) ──
    final File file;
    try {
      final tmp = await getTemporaryDirectory();
      final dir = Directory('${tmp.path}${Platform.pathSeparator}$_dirName');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      file = File(
        '${dir.path}${Platform.pathSeparator}proxo_preview_${_safeId(id)}.html',
      );
      // Overwrites in place, so an edited card never shows a stale page.
      await file.writeAsString(html, encoding: utf8, flush: true);
    } catch (e) {
      debugPrint('LocalHtmlPreview: write failed: $e');
      return const LocalPreviewResult(LocalPreviewStatus.writeFailed);
    }

    // ── 3. Hand it to an external app ─────────────────────────────────
    try {
      final ok = await _channel.invokeMethod<bool>('openHtml', <String, String>{
        'path': file.path,
        'title': title ?? '',
      });
      if (ok == true) {
        unawaited(_sweepOldFiles());
        return LocalPreviewResult(LocalPreviewStatus.opened, path: file.path);
      }
      return const LocalPreviewResult(LocalPreviewStatus.noApp);
    } on MissingPluginException {
      // Not Android (or an old build without the channel) — fall back to
      // url_launcher, which is enough on iOS/desktop.
      return _launchFallback(file);
    } on PlatformException catch (e) {
      debugPrint('LocalHtmlPreview: channel error ${e.code}: ${e.message}');
      if (e.code == 'no_app') {
        return const LocalPreviewResult(LocalPreviewStatus.noApp);
      }
      if (e.code == 'missing_file') {
        return const LocalPreviewResult(LocalPreviewStatus.writeFailed);
      }
      return const LocalPreviewResult(LocalPreviewStatus.failed);
    } catch (e) {
      debugPrint('LocalHtmlPreview: unexpected error: $e');
      return const LocalPreviewResult(LocalPreviewStatus.failed);
    }
  }

  static Future<LocalPreviewResult> _launchFallback(File file) async {
    try {
      final launched = await launchUrl(
        Uri.file(file.path),
        mode: LaunchMode.externalApplication,
      );
      return launched
          ? LocalPreviewResult(LocalPreviewStatus.opened, path: file.path)
          : const LocalPreviewResult(LocalPreviewStatus.noApp);
    } catch (e) {
      debugPrint('LocalHtmlPreview: fallback launch failed: $e');
      return const LocalPreviewResult(LocalPreviewStatus.noApp);
    }
  }

  /// `[A-Za-z0-9_-]` only — no separators, no `..`, so the path can never
  /// escape the preview folder no matter what a row's id contains.
  static String _safeId(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    if (cleaned.isEmpty) return 'card';
    return cleaned.length <= 60 ? cleaned : cleaned.substring(0, 60);
  }

  /// Best-effort housekeeping so preview files can't accumulate forever.
  /// Never throws, never blocks the UI.
  static Future<void> _sweepOldFiles() async {
    try {
      final tmp = await getTemporaryDirectory();
      final dir = Directory('${tmp.path}${Platform.pathSeparator}$_dirName');
      if (!await dir.exists()) return;
      final cutoff = DateTime.now().subtract(_maxAge);
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File || !entity.path.endsWith('.html')) continue;
        try {
          if ((await entity.stat()).modified.isBefore(cutoff)) {
            await entity.delete();
          }
        } catch (_) {/* a file we can't stat/delete is not worth failing on */}
      }
    } catch (_) {/* housekeeping only */}
  }
}
