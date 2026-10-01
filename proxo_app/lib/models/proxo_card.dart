class ProxoCard {
    final String id;
    final String userId;
    final String name;
    final String? bio;
    final String style;
    final String colorTheme;
    final String? avatarB64;
    final String htmlContent;
    final int cardNumber;
    final DateTime createdAt;

    const ProxoCard({
      required this.id,
      required this.userId,
      required this.name,
      this.bio,
      required this.style,
      required this.colorTheme,
      this.avatarB64,
      required this.htmlContent,
      required this.cardNumber,
      required this.createdAt,
    });

    factory ProxoCard.fromJson(Map<String, dynamic> json) {
      return ProxoCard(
        id:          json['id']           as String,
        userId:      json['user_id']      as String,
        name:        json['name']         as String,
        bio:         json['bio']          as String?,
        style:       json['style']        as String? ?? 'dark',
        colorTheme:  json['color_theme']  as String? ?? 'purple',
        avatarB64:   json['avatar_b64']   as String?,
        htmlContent: json['html_content'] as String,
        cardNumber:  (json['card_number'] as num).toInt(),
        createdAt:   DateTime.parse(json['created_at'] as String),
      );
    }

    Map<String, dynamic> toJson() => {
      'id':           id,
      'user_id':      userId,
      'name':         name,
      'bio':          bio,
      'style':        style,
      'color_theme':  colorTheme,
      'avatar_b64':   avatarB64,
      'html_content': htmlContent,
      'card_number':  cardNumber,
      'created_at':   createdAt.toIso8601String(),
    };
  }
  