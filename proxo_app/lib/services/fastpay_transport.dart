import '../config/backend_config.dart';

/// A reviewed route and protocol, selected before a checkout is persisted.
/// Merely changing the build config cannot upgrade an older payment's protocol.
class FastPayTransport {
  static const legacyProtocol = 'legacy-v1';
  static const durableStagingProtocol = 'journal-staging-v1';
  static const legacyBase = 'https://email.proxopages.com/webhook/fastpay';
  static const stagingBase =
      'https://email.proxopages.com/webhook/proxo-fastpay-staging';

  final String protocol;
  final String webhookBase;
  final String backendOrigin;

  const FastPayTransport._(this.protocol, this.webhookBase, this.backendOrigin);

  factory FastPayTransport.fromValues({
    required BackendConfig backendConfig,
    String stagingWebhookBase = '',
  }) {
    if (!backendConfig.isStaging) {
      if (stagingWebhookBase.isNotEmpty) {
        throw const FormatException('fastpay_staging_backend_required');
      }
      return FastPayTransport._(
          legacyProtocol, legacyBase, backendConfig.supabaseUrl);
    }
    if (stagingWebhookBase.isEmpty) {
      throw StateError('staging_fastpay_transport_disabled');
    }
    if (stagingWebhookBase != stagingBase) {
      throw const FormatException('fastpay_staging_route_not_reviewed');
    }
    return FastPayTransport._(durableStagingProtocol,
        stagingWebhookBase, backendConfig.supabaseUrl);
  }

  static FastPayTransport resolve({BackendConfig? backendConfig}) =>
      FastPayTransport.fromValues(
        backendConfig: backendConfig ?? BackendConfig.current,
        stagingWebhookBase:
            const String.fromEnvironment('PROXO_FASTPAY_STAGING_WEBHOOK_BASE'),
      );

  Uri get createUri => Uri.parse('$webhookBase/order-create');
  Uri get statusUri => Uri.parse('$webhookBase/order-status');
  bool get durableStaging => protocol == durableStagingProtocol;

  bool matches({required String protocol, required String webhookBase,
      required String backendOrigin}) =>
      this.protocol == protocol && this.webhookBase == webhookBase &&
      this.backendOrigin == backendOrigin;

  /// Unrecognized or partially persisted bindings must never gain replay rights.
  static bool validBinding(String protocol, String base, String backend) {
    if (protocol == legacyProtocol) {
      return base == legacyBase && backend == BackendConfig.productionSupabaseUrl;
    }
    return protocol == durableStagingProtocol && base == stagingBase &&
        backend != BackendConfig.productionSupabaseUrl &&
        RegExp(r'^https://[a-z]{20}\.supabase\.co$').hasMatch(backend);
  }
}
