import 'package:supabase_flutter/supabase_flutter.dart';

class ContextHelpService {
  ContextHelpService({SupabaseClient? client}) : _client = client;
  final SupabaseClient? _client;

  static Uri? validVideoUrl(Object? value) {
    if (value is! String) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        value.contains(RegExp(r'\s'))) return null;
    return uri;
  }

  Future<Uri?> tutorialFor(String key) async {
    final row = await (_client ?? Supabase.instance.client)
        .from('pa_settings')
        .select('value')
        .eq('key', 'tutorial_${key}_url')
        .maybeSingle()
        .timeout(const Duration(seconds: 5));
    return validVideoUrl(row?['value']);
  }
}
