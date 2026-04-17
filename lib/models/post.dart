enum PostType {
  helpNeeded('help_needed', 'Hilfe gesucht', '🆘'),
  helpOffered('help_offered', 'Hilfe angeboten', '🤝'),
  rescue('rescue', 'Rettung', '🚨'),
  animal('animal', 'Tier', '🐾'),
  housing('housing', 'Wohnung', '🏠'),
  supply('supply', 'Versorgung', '📦'),
  mobility('mobility', 'Mobilität', '🚗'),
  sharing('sharing', 'Tauschen', '🔄'),
  crisis('crisis', 'Krise', '⚠️'),
  community('community', 'Gemeinschaft', '👥');

  const PostType(this.value, this.label, this.emoji);
  final String value;
  final String label;
  final String emoji;

  static PostType fromString(String value) {
    return PostType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PostType.community,
    );
  }
}

enum PostCategory {
  food('food', 'Lebensmittel'),
  everyday('everyday', 'Alltag'),
  moving('moving', 'Umzug'),
  animals('animals', 'Tiere'),
  housing('housing', 'Wohnen'),
  knowledge('knowledge', 'Wissen'),
  skills('skills', 'Fähigkeiten'),
  mental('mental', 'Mental'),
  mobility('mobility', 'Mobilität'),
  sharing('sharing', 'Teilen'),
  emergency('emergency', 'Notfall'),
  general('general', 'Allgemein');

  const PostCategory(this.value, this.label);
  final String value;
  final String label;

  static PostCategory fromString(String value) {
    return PostCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PostCategory.general,
    );
  }
}

enum PostStatus {
  active('active'),
  fulfilled('fulfilled'),
  archived('archived'),
  pending('pending');

  const PostStatus(this.value);
  final String value;

  static PostStatus fromString(String value) {
    return PostStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PostStatus.active,
    );
  }
}

class Post {
  final String id;
  final String userId;
  final String type;
  final String? category;
  final String title;
  final String? description;
  final String status;
  final List<String> imageUrls;
  final double? latitude;
  final double? longitude;
  final String? locationText;
  final String? urgency;
  final String? contactPhone;
  final String? contactWhatsapp;
  final String? contactEmail;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Joined fields
  final Map<String, dynamic>? profile;
  final int? commentCount;
  final int? voteScore;

  const Post({
    required this.id,
    required this.userId,
    required this.type,
    this.category,
    required this.title,
    this.description,
    this.status = 'active',
    this.imageUrls = const [],
    this.latitude,
    this.longitude,
    this.locationText,
    this.urgency,
    this.contactPhone,
    this.contactWhatsapp,
    this.contactEmail,
    this.tags = const [],
    required this.createdAt,
    this.updatedAt,
    this.profile,
    this.commentCount,
    this.voteScore,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String? ?? 'community',
      category: json['category'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'active',
      imageUrls: (json['image_urls'] as List<dynamic>?)?.cast<String>() ?? [],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationText: json['location_text'] as String?,
      urgency: json['urgency'] as String?,
      contactPhone: json['contact_phone'] as String?,
      contactWhatsapp: json['contact_whatsapp'] as String?,
      contactEmail: json['contact_email'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      profile: json['profiles'] is Map<String, dynamic>
          ? json['profiles'] as Map<String, dynamic>
          : (json['profiles'] is List && (json['profiles'] as List).isNotEmpty
              ? (json['profiles'] as List).first as Map<String, dynamic>?
              : null),
      commentCount: json['comment_count'] as int?,
      voteScore: json['vote_score'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'type': type,
      'category': category,
      'title': title,
      'description': description,
      'status': status,
      'image_urls': imageUrls,
      'latitude': latitude,
      'longitude': longitude,
      'location_text': locationText,
      'urgency': urgency,
      'contact_phone': contactPhone,
      'contact_whatsapp': contactWhatsapp,
      'contact_email': contactEmail,
      'tags': tags,
    };
  }

  PostType get postType => PostType.fromString(type);

  String get authorName {
    if (profile == null) return 'Unbekannt';
    return profile!['name'] as String? ??
        profile!['nickname'] as String? ??
        'Unbekannt';
  }

  String? get authorAvatarUrl => profile?['avatar_url'] as String?;

  List<String> get allImages =>
      imageUrls.where((u) => u.isNotEmpty).toList();
}
