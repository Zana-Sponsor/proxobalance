import '../theme/app_locale.dart';
import 'proxo_messages.dart';

/// Only call for application copy, never for user names, campaign titles,
/// submitted form values, IDs or server-owned content.
abstract final class ProxoStrings {
  static String text(String source, {String? arabic, String? language}) {
    language ??= ProxoLocale.current.value.languageCode;
    final entry = proxoMessages[source];
    if (language == 'ar') return arabic ?? entry?.$1 ?? source;
    if (language == 'kmr') return entry?.$2 ?? source;
    return source;
  }

  static String format(String source, Map<String, Object> values) {
    var result = text(source);
    for (final entry in values.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value.toString());
    }
    return result;
  }
}
