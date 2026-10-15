import '../theme/app_locale.dart';
import 'proxo_messages.dart';

/// Only call for application copy, never for user names, campaign titles,
/// submitted form values, IDs or server-owned content.
abstract final class ProxoStrings {
  static final _sourceForTranslation = <String,String>{
    for (final entry in proxoMessages.entries) entry.value.$1: entry.key,
    for (final entry in proxoMessages.entries) entry.value.$2: entry.key,
  };
  static String text(String source, {String? arabic, String? language}) {
    language ??= ProxoLocale.current.value.languageCode;
    final canonical = proxoMessages.containsKey(source) ? source : _sourceForTranslation[source] ?? source;
    final entry = proxoMessages[canonical];
    if (language == 'ar') return arabic ?? entry?.$1 ?? source;
    if (language == 'kmr') return entry?.$2 ?? source;
    return canonical;
  }

  static String format(String source, Map<String, Object> values) {
    var result = text(source);
    for (final entry in values.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value.toString());
    }
    return result;
  }
}
