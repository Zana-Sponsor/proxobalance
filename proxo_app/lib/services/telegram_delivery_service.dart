// ═══════════════════════════════════════════════════════════════════════
// TELEGRAM DELIVERY SERVICE
//
// Flutter -> Cloudflare Worker -> Telegram Bot API.
//
// This is the client half of the delivery pipeline. It does NOT know the
// Telegram bot token or chat id — those live only in the Worker's
// encrypted environment secrets (see the companion `cloudflare_worker.js`
// deployment). This intentionally replaces the old code path that used
// to call `api.telegram.org` directly from Flutter with a hardcoded bot
// token compiled into the app binary.
//
// SECURITY NOTE: if this project previously shipped a build with the bot
// token hardcoded in tools_screen.dart, that token is already exposed
// (readable from the compiled APK/IPA) and should be revoked/rotated in
// BotFather — deploying this Worker does not retroactively protect a
// token that already leaked.
// ═══════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class TelegramDeliveryResult {
  final bool success;
  final String? error;
  const TelegramDeliveryResult.ok()
      : success = true, error = null;
  const TelegramDeliveryResult.fail(String message)
      : success = false, error = message;
}

class TelegramDeliveryService {
  /// The deployed Cloudflare Worker endpoint (see cloudflare_worker.js).
  /// Point this at your real Worker URL after deploying it — do NOT put
  /// a bot token or chat id here, only the Worker's public URL.
  ///
  /// Prefer injecting this via --dart-define rather than hardcoding it,
  /// e.g.:
  ///   flutter build apk --dart-define=PROXO_TG_WORKER_URL=https://...
  static const String _workerUrl = String.fromEnvironment(
    'PROXO_TG_WORKER_URL',
    defaultValue: 'https://REPLACE_WITH_YOUR_WORKER.workers.dev/send-card',
  );

  /// Optional shared secret the Worker can require (env `WORKER_SHARED_SECRET`
  /// in cloudflare_worker.js) so the endpoint can't be spammed by anyone who
  /// finds the URL. Leave both empty to skip this check entirely.
  static const String _workerKey = String.fromEnvironment('PROXO_TG_WORKER_KEY');

  static bool get isConfigured =>
      !_workerUrl.contains('REPLACE_WITH_YOUR_WORKER') && _workerUrl.startsWith('https://');

  /// Sends the generated card HTML to the Worker as a document upload
  /// (multipart/form-data), along with a short caption. The Worker
  /// re-posts it to Telegram's `sendDocument` endpoint so it arrives as
  /// an actual `.html` file, not plain text.
  static Future<TelegramDeliveryResult> sendHtmlDocument({
    required String htmlContent,
    required String filename,
    required String caption,
  }) async {
    if (!isConfigured) {
      return const TelegramDeliveryResult.fail(
          'Cloudflare Worker URL is not configured (see telegram_delivery_service.dart).');
    }
    try {
      final uri = Uri.parse(_workerUrl);
      final request = http.MultipartRequest('POST', uri)
        ..fields['caption'] = caption
        ..fields['filename'] = filename;
      if (_workerKey.isNotEmpty) {
        request.headers['X-Proxo-Worker-Key'] = _workerKey;
      }
      request.files.add(http.MultipartFile.fromBytes(
          'document',
          utf8.encode(htmlContent),
          filename: filename,
          contentType: MediaType('text', 'html'),
        ));

      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        return const TelegramDeliveryResult.ok();
      }
      return TelegramDeliveryResult.fail(
          'Delivery failed (${response.statusCode}): ${response.body}');
    } catch (e) {
      return TelegramDeliveryResult.fail('Delivery failed: $e');
    }
  }
}
