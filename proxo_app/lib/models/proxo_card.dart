class ProxoCard {
  static const safeColumns =
      'id,user_id,name,bio,tt,platforms,template_key,template_version,style,color_theme,card_language,page_type,avatar_path,status,publish_status,card_number,created_at,updated_at';
  final String id, userId, name, bio, tt, templateKey, colorTheme;
  final String language, status, publishStatus, pageType;
  final String? avatarPath;
  final bool hasAvatar;
  final int templateVersion, cardNumber;
  final DateTime createdAt, updatedAt;
  final Map<String, String> platforms;

  const ProxoCard({
    required this.id,
    required this.userId,
    required this.name,
    this.bio = '',
    this.tt = '',
    required this.templateKey,
    this.templateVersion = 2,
    this.colorTheme = 'purple',
    this.language = 'ku',
    this.pageType = 'contact',
    this.avatarPath,
    this.hasAvatar = false,
    this.status = 'inactive',
    this.publishStatus = 'creating',
    required this.cardNumber,
    required this.createdAt,
    required this.updatedAt,
    this.platforms = const {},
  });
  bool get available => status == 'active' && publishStatus == 'ready';
  bool get canPreview => publishStatus == 'ready';
  bool get canRetry =>
      publishStatus == 'failed' ||
      (publishStatus == 'creating' &&
          DateTime.now().difference(updatedAt).inMinutes >= 2);
  String get stateLabel => switch (publishStatus) {
    'creating' => 'لە دروستکردندایە...',
    'failed' => 'دروستکردن سەرکەوتوو نەبوو',
    _ => status == 'active' ? 'چالاکە' : 'ناچالاکە',
  };
  String get publicPath => '/contact/$id';
  String? get avatarUrl => avatarPath == null && !hasAvatar
      ? null
      : 'https://www.proxobalance.app/contact/$id/avatar';
  factory ProxoCard.fromJson(Map<String, dynamic> j) => ProxoCard(
    id: j['id'] as String,
    userId: j['user_id'] as String,
    name: j['name'] as String,
    bio: j['bio'] as String? ?? '',
    tt: j['tt'] as String? ?? '',
    templateKey: (j['template_key'] ?? j['style'] ?? 'pill-white') as String,
    templateVersion: (j['template_version'] as num?)?.toInt() ?? 2,
    colorTheme: j['color_theme'] as String? ?? 'purple',
    language: j['card_language'] as String? ?? 'ku',
    pageType: j['page_type'] as String? ?? 'contact',
    avatarPath: j['avatar_path'] as String?,
    hasAvatar: j['has_avatar'] == true,
    status: j['status'] as String? ?? 'inactive',
    publishStatus: j['publish_status'] as String? ?? 'creating',
    cardNumber: (j['card_number'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.parse(j['created_at'] as String),
    updatedAt: DateTime.parse((j['updated_at'] ?? j['created_at']) as String),
    platforms: {
      for (final e in (j['platforms'] as Map? ?? {}).entries)
        e.key.toString(): e.value.toString(),
    },
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'bio': bio,
    'tt': tt,
    'template_key': templateKey,
    'style': templateKey,
    'template_version': templateVersion,
    'color_theme': colorTheme,
    'card_language': language,
    'page_type': pageType,
    'avatar_path': avatarPath,
    'status': status,
    'publish_status': publishStatus,
    'card_number': cardNumber,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'platforms': platforms,
  };
}

class ProxoTemplate {
  final String key, label, previewPath;
  final int version;
  final bool requiresAvatar;
  const ProxoTemplate({
    required this.key,
    required this.label,
    required this.previewPath,
    required this.version,
    required this.requiresAvatar,
  });
  factory ProxoTemplate.fromJson(Map<String, dynamic> j) => ProxoTemplate(
    key: j['template_key'] as String,
    label: j['display_name_ckb'] as String,
    previewPath: j['preview_path'] as String,
    version: (j['version'] as num).toInt(),
    requiresAvatar: j['requires_avatar'] == true,
  );
}
