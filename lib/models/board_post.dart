enum BoardPostCategory {
  suche('suche', 'Suche', '🔍'),
  biete('biete', 'Biete', '🎁'),
  info('info', 'Info', 'ℹ️'),
  event('event', 'Event', '📅'),
  warnung('warnung', 'Warnung', '⚠️'),
  lost('lost', 'Verloren', '📢'),
  found('found', 'Gefunden', '✅'),
  general('general', 'Allgemein', '📌');

  const BoardPostCategory(this.value, this.label, this.emoji);
  final String value;
  final String label;
  final String emoji;

  static BoardPostCategory fromString(String value) {
    return BoardPostCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => BoardPostCategory.general,
    );
  }
}

class BoardPost {
  final String id;
  final String userId;
  final String title;
  final String content;
  final String category;
  final String color;
  final String status;
  final String? imageUrl;
  final String? locationText;
  final double? latitude;
  final double? longitude;
  final DateTime? expiresAt;
  final int pinCount;
  final int commentCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Joined
  final Map<String, dynamic>? profile;
  final bool? isPinned;

  const BoardPost({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    this.category = 'general',
    this.color = 'yellow',
    this.status = 'active',
    this.imageUrl,
    this.locationText,
    this.latitude,
    this.longitude,
    this.expiresAt,
    this.pinCount = 0,
    this.commentCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.profile,
    this.isPinned,
  });

  factory BoardPost.fromJson(Map<String, dynamic> json) {
    return BoardPost(
      id: json['id'] as String,
      userId: json['author_id'] as String,
      title: '',
      content: json['content'] as String? ?? '',
      category: json['category'] as String? ?? 'general',
      color: json['color'] as String? ?? 'yellow',
      status: json['status'] as String? ?? 'active',
      imageUrl: json['image_url'] as String?,
      locationText: json['location_text'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      pinCount: json['pin_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      profile: json['profiles'] as Map<String, dynamic>?,
      isPinned: json['is_pinned'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'author_id': userId,
      'content': content,
      'category': category,
      'color': color,
      'status': status,
      'image_url': imageUrl,
      'location_text': locationText,
      'latitude': latitude,
      'longitude': longitude,
      'expires_at': expiresAt?.toIso8601String(),
    };
  }

  BoardPostCategory get boardCategory => BoardPostCategory.fromString(category);
}

class BoardComment {
  final String id;
  final String boardPostId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final Map<String, dynamic>? profile;

  const BoardComment({
    required this.id,
    required this.boardPostId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.profile,
  });

  factory BoardComment.fromJson(Map<String, dynamic> json) {
    return BoardComment(
      id: json['id'] as String,
      boardPostId: json['board_post_id'] as String,
      userId: json['author_id'] as String,
      content: json['content'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      profile: json['profiles'] as Map<String, dynamic>?,
    );
  }
}
