import 'proxolink_page_type.dart';

class ProxoCard {
  static const safeColumns =
      'id,user_id,name,bio,tt,platforms,template_key,template_version,style,color_theme,card_language,avatar_path,status,publish_status,card_number,created_at,updated_at';
  final String id, userId, name, bio, tt, templateKey, colorTheme;
  final String language, status, publishStatus;
  final String? moderationStatus;
  final String? avatarPath;
  final int templateVersion, cardNumber;
  final DateTime createdAt, updatedAt;
  final Map<String, String> platforms;
  final String? pageKind, clientRequestId;
  final Map<String, dynamic> settings;

  const ProxoCard({
    required this.id,
    required this.userId,
    required this.name,
    this.bio = '',
    this.tt = '',
    required this.templateKey,
    this.templateVersion = 1,
    this.colorTheme = 'purple',
    this.language = 'ku',
    this.avatarPath,
    this.status = 'inactive',
    this.publishStatus = 'creating',
    this.moderationStatus,
    required this.cardNumber,
    required this.createdAt,
    required this.updatedAt,
    this.platforms = const {},
    this.pageKind,
    this.clientRequestId,
    this.settings = const {},
  });
  String get moderationLabel => switch (moderationStatus) {
    'approved' => 'پەسەندکراوە',
    'rejected' => 'ڕەتکراوە',
    'pending' => 'چاوەڕوانی',
    _ => '', // Unmigrated data is not assigned a fabricated moderation decision.
  };
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
  ProxoPageType get pageType => ProxoPageTypeInfo.parse(pageKind);
  String get publicPath => '/${pageType.key}/$id';
  // The private image is served using the same short-lived owner preview.
  // No account UUID or storage object path is embedded in a public image URL.
  String? get avatarUrl => null;
  factory ProxoCard.fromJson(Map<String, dynamic> j) => ProxoCard(
    id: j['id'] as String,
    userId: j['user_id'] as String,
    name: j['name'] as String,
    bio: j['bio'] as String? ?? '',
    tt: j['tt'] as String? ?? '',
    templateKey: (j['template_key'] ?? j['style'] ?? 'classic') as String,
    templateVersion: (j['template_version'] as num?)?.toInt() ?? 1,
    colorTheme: j['color_theme'] as String? ?? 'purple',
    language: j['card_language'] as String? ?? 'ku',
    avatarPath: j['avatar_path'] as String?,
    status: j['status'] as String? ?? 'inactive',
    publishStatus: j['publish_status'] as String? ?? 'creating',
    moderationStatus: switch (j['moderation_status']) {
      'pending' => 'pending', 'approved' => 'approved', 'rejected' => 'rejected', _ => null,
    },
    cardNumber: (j['card_number'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.parse(j['created_at'] as String),
    updatedAt: DateTime.parse((j['updated_at'] ?? j['created_at']) as String),
    pageKind: j['page_kind'] as String?,
    clientRequestId: j['client_request_id'] as String?,
    settings: Map<String,dynamic>.from(j['settings'] as Map? ?? {}),
    platforms: {
      for (final e in (j['platforms'] as Map? ?? {}).entries)
        if (j['page_kind'] != null || !{'tg', 'telegram'}.contains(e.key.toString().toLowerCase()))
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
    'avatar_path': avatarPath,
    'status': status,
    'publish_status': publishStatus,
    if (moderationStatus != null) 'moderation_status': moderationStatus,
    'card_number': cardNumber,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'platforms': platforms,
    if(pageKind != null) 'page_kind': pageKind,
    if(clientRequestId != null) 'client_request_id': clientRequestId,
    'settings': settings,
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
