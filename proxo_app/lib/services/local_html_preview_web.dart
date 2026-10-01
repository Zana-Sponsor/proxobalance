// ═══════════════════════════════════════════════════════════════════════
// LOCAL HTML PREVIEW — web implementation.
//
// The io path writes a .html file and hands it to an external app, which
// is meaningless in a browser tab. Here the page is wrapped in a Blob with
// an explicit `text/html` MIME type and opened as an object URL, so the
// browser renders it as a document instead of dumping the source as text.
//
// Uses package:web + dart:js_interop rather than the deprecated dart:html.
// ═══════════════════════════════════════════════════════════════════════

import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'local_html_preview_types.dart';

/// Object URLs hold their blob alive until revoked. Revoking immediately
/// races the new tab's load and yields a blank page, so the handle is kept
/// briefly and then released.
const Duration _revokeAfter = Duration(minutes: 2);

Future<LocalPreviewResult> openPreview({
  required String html,
  required String id,
  String? title,
}) async {
  try {
    // The MIME type is the whole fix: a Blob typed text/plain (or untyped)
    // is what makes the tab show `<!DOCTYPE html>...` as literal text.
    final blob = web.Blob(
      <JSAny>[html.toJS].toJS,
      web.BlobPropertyBag(type: 'text/html;charset=utf-8'),
    );
    final url = web.URL.createObjectURL(blob);

    web.window.open(url, '_blank');

    Future<void>.delayed(_revokeAfter, () {
      try {
        web.URL.revokeObjectURL(url);
      } catch (_) {
        // The tab may already be gone; nothing to recover.
      }
    });

    return LocalPreviewResult(LocalPreviewStatus.opened, path: url);
  } catch (e) {
    debugPrint('LocalHtmlPreview(web): open failed: $e');
    return const LocalPreviewResult(LocalPreviewStatus.failed);
  }
}
