import 'dart:convert';

/// One validated configuration for foreground, background and page API traffic.
/// Staging must opt in as a complete set; it never inherits production Auth.
class BackendConfig {
  static const productionProjectRef = 'cojchkwssmasiejcgvbk';
  static const productionSupabaseUrl =
      'https://cojchkwssmasiejcgvbk.supabase.co';
  static const productionPublicBase = 'https://www.proxobalance.app';
  // This is the existing public anon key, not a server/service credential.
  static const productionAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
      '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNvamNoa3dzc21hc2llamNndmJrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzczMTE1MTIsImV4cCI6MjA5Mjg4NzUxMn0'
      '.RCALy3wpKHGAkmXWcBqEb_QFEUmh6ErdRbfrBmagvtw';

  static final BackendConfig current = BackendConfig.fromValues(
    mode: const String.fromEnvironment(
      'PROXO_BACKEND_MODE',
      defaultValue: 'production',
    ),
    supabaseUrl: const String.fromEnvironment('PROXO_SUPABASE_URL'),
    supabaseAnonKey: const String.fromEnvironment('PROXO_SUPABASE_ANON_KEY'),
    publicBase: const String.fromEnvironment('PROXO_PUBLIC_BASE_URL'),
  );

  final bool isStaging;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String publicBase;

  // Isolated page acceptance uses an injected synthetic session. Production
  // mail, payment and Firebase delivery have no isolated provider configured.
  bool get productionTransportsEnabled => !isStaging;

  void requireProductionTransport() {
    if (!productionTransportsEnabled) {
      throw StateError('staging_production_transport_disabled');
    }
  }

  const BackendConfig._({
    required this.isStaging,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.publicBase,
  });

  factory BackendConfig.fromValues({
    String mode = 'production',
    String supabaseUrl = '',
    String supabaseAnonKey = '',
    String publicBase = '',
  }) {
    if (mode != 'production' && mode != 'staging') {
      throw const FormatException('backend_mode_invalid');
    }
    if (mode == 'production') {
      if (supabaseUrl.isNotEmpty || supabaseAnonKey.isNotEmpty) {
        throw const FormatException('staging_mode_required');
      }
      final base = publicBase.isEmpty ? productionPublicBase : publicBase;
      final uri = _origin(base);
      // Preserve the existing read-only preview override, but never combine
      // the dedicated staging server with the default production Auth client.
      if (_isStagingHost(uri.host)) {
        throw const FormatException('staging_mode_required');
      }
      return BackendConfig._(
        isStaging: false,
        supabaseUrl: productionSupabaseUrl,
        supabaseAnonKey: productionAnonKey,
        publicBase: uri.origin,
      );
    }
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty || publicBase.isEmpty) {
      throw const FormatException('staging_settings_required');
    }
    final database = _origin(supabaseUrl);
    final match =
        RegExp(r'^([a-z]{20})\.supabase\.co$').firstMatch(database.host);
    final ref = match?.group(1);
    if (ref == null || ref == productionProjectRef) {
      throw const FormatException('isolated_supabase_required');
    }
    final api = _origin(publicBase);
    if (!_isStagingHost(api.host)) {
      throw const FormatException('isolated_api_required');
    }
    _validatePublishableKey(supabaseAnonKey, ref);
    return BackendConfig._(
      isStaging: true,
      supabaseUrl: database.origin,
      supabaseAnonKey: supabaseAnonKey,
      publicBase: api.origin,
    );
  }

  static Uri _origin(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        value != value.trim() ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('backend_origin_invalid');
    }
    return uri;
  }

  static bool _isStagingHost(String host) =>
      RegExp(r'^proxolink-staging(?:-[a-z0-9-]+)?\.vercel\.app$')
          .hasMatch(host);

  static void _validatePublishableKey(String key, String projectRef) {
    if (RegExp(r'^sb_publishable_[A-Za-z0-9_-]+$').hasMatch(key)) return;
    // JWT claims are only a configuration mismatch check, not authentication.
    // The isolated server still verifies the key and user session normally.
    try {
      final parts = key.split('.');
      if (parts.length == 3 && parts.every((part) => part.isNotEmpty)) {
        final payload = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
        );
        if (payload is Map &&
            payload['role'] == 'anon' &&
            payload['ref'] == projectRef) {
          return;
        }
      }
    } catch (_) {
      // Do not include supplied credentials in a diagnostic or exception.
    }
    throw const FormatException('isolated_publishable_key_required');
  }
}
