enum ProxoPageType { contact, order, download }

extension ProxoPageTypeInfo on ProxoPageType {
  static const allowedProviders = <String, Set<String>>{
    'contact': {
      'whatsapp',
      'viber',
      'instagram',
      'telegram',
      'korek',
      'asiacell',
    },
    'order': {'talabat', 'toters'},
    'download': {'google_play', 'app_store'},
  };
  String get key => name;
  String get label => switch (this) {
    ProxoPageType.contact => 'پەیوەندی',
    ProxoPageType.order => 'خواردنگە و ڕێستۆرانت',
    ProxoPageType.download => 'داگرتنی ئەپ',
  };
  String get imageLabel => switch (this) {
    ProxoPageType.contact => 'وێنەی پەڕە',
    ProxoPageType.order => 'لۆگۆی ڕێستۆرانت',
    ProxoPageType.download => 'ئایکۆنی ئەپ',
  };
  String get nameLabel => switch (this) {
    ProxoPageType.contact => 'ناوی پەڕە',
    ProxoPageType.order => 'ناوی ڕێستۆرانت',
    ProxoPageType.download => 'ناوی ئەپ',
  };
  static ProxoPageType parse(String? value) => ProxoPageType.values.firstWhere(
    (t) => t.key == value,
    orElse: () => ProxoPageType.contact,
  );
}

class ProxoProvider {
  final String key, pageType, label, icon, inputKind;
  const ProxoProvider({
    required this.key,
    required this.pageType,
    required this.label,
    required this.icon,
    required this.inputKind,
  });
  factory ProxoProvider.fromJson(Map<String, dynamic> j) => ProxoProvider(
    key: j['provider_key'] as String,
    pageType: j['page_type'] as String,
    label: j['label'] as String,
    icon: j['icon'] as String,
    inputKind: j['input_kind'] as String,
  );
  String get hint => switch (inputKind) {
    'phone' => '+9647XXXXXXXXX',
    'handle' => 'username',
    _ => 'https://…',
  };
}
