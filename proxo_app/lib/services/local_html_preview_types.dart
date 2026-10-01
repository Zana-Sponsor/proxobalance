// Shared result types for the local HTML preview. Kept in their own
// library so the io/web implementations can import them without a cycle
// back through the conditional-import facade.

import 'package:flutter/foundation.dart';

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
