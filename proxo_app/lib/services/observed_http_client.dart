import 'package:http/http.dart' as http;
import 'app_telemetry_service.dart';

/// Supabase transport diagnostics, without URLs, parameters, headers or bodies.
/// Duration means request-to-response-headers, not screen interactive readiness.
class ObservedHttpClient extends http.BaseClient {
  ObservedHttpClient(this.inner);
  final http.Client inner;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path.endsWith('/pa_record_app_telemetry')) return inner.send(request);
    final telemetry = AppTelemetryService.active;
    final section = telemetry?.currentSection;
    final category = request.url.path.startsWith('/rest/') ? 'database' :
        request.url.path.startsWith('/functions/') ? 'edge' :
        request.url.path.startsWith('/auth/') ? 'auth' : 'storage';
    final watch = Stopwatch()..start();
    try {
      final response = await inner.send(request);
      if (response.statusCode >= 400) {
        telemetry?.event('error', '${category}_http_${response.statusCode}', outcome: 'failure', sectionName: section);
      }
      return response;
    } catch (_) {
      telemetry?.event('error', '${category}_network', outcome: 'failure', sectionName: section);
      rethrow;
    } finally {
      telemetry?.event('performance', '${category}_response_headers', durationMs: watch.elapsedMilliseconds, sectionName: section);
    }
  }
  @override void close() => inner.close();
}
