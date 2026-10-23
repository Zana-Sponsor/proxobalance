import 'package:supabase_flutter/supabase_flutter.dart';

/// No persisted/local override. Failures revoke the client affordance; the
/// database independently rechecks every new acceptance and worker claim.
class AdFeatureConfig {
  const AdFeatureConfig({this.meta = false, this.serverTime});
  final bool meta;
  final DateTime? serverTime;
  static Future<AdFeatureConfig> load(SupabaseClient client) async {
    try {
      final value = await client.rpc('pa_ad_capabilities')
          .timeout(const Duration(seconds: 8));
      return AdFeatureConfig(meta: value['meta_enabled'] == true,
          serverTime: DateTime.tryParse('${value['server_time']}'));
    } catch (_) { return const AdFeatureConfig(); }
  }
}
