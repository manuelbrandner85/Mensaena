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
  final String? imageUrl;
  final List<String> mediaUrls;
  final double? latitude;
  final double? longitude;
  final String? locationText;
  final String? urgency;
  final String? contactPhone;
  final String? contactWhatsapp;
  final String? contactEmail;
  final List<String> tags;
  final bool isAnonymous;
  final bool isPinned;
  final bool isRecurring;
  final String? recurringInterval;
  final String? moduleSlug;
  final DateTime? eventDate;
  final String? eventTime;
  final double? durationHours;
  final List<String> availabilityDays;
  final String? availabilityStart;
  final String? availabilityEnd;
  final DateTime? expiresAt;
  final DateTime? deletedAt;
  final int reactionCount;
  final int commentCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  // Joined fields
  final Map<String, dynamic>? profile;
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
    this.imageUrl,
    this.mediaUrls = const [],
    this.latitude,
    this.longitude,
    this.locationText,
    this.urgency,
    this.contactPhone,
    this.contactWhatsapp,
    this.contactEmail,
    this.tags = const [],
    this.isAnonymous = false,
    this.isPinned = false,
    this.isRecurring = false,
    this.recurringInterval,
    this.moduleSlug,
    this.eventDate,
    this.eventTime,
    this.durationHours,
    this.availabilityDays = const [],
    this.availabilityStart,
    this.availabilityEnd,
    this.expiresAt,
    this.deletedAt,
    this.reactionCount = 0,
    this.commentCount = 0,
    required this.createdAt,
    this.updatedAt,
    this.profile,
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
      imageUrl: json['image_url'] as String?,
      mediaUrls: (json['media_urls'] as List<dynamic>?)?.cast<String>() ?? [],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationText: json['location_text'] as String?,
      urgency: json['urgency'] as String?,
      contactPhone: json['contact_phone'] as String?,
      contactWhatsapp: json['contact_whatsapp'] as String?,
      contactEmail: json['contact_email'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      isPinned: json['is_pinned'] as bool? ?? false,
      isRecurring: json['is_recurring'] as bool? ?? false,
      recurringInterval: json['recurring_interval'] as String?,
      moduleSlug: json['module_slug'] as String?,
      eventDate: json['event_date'] != null ? DateTime.tryParse(json['event_date'] as String) : null,
      eventTime: json['event_time'] as String?,
      durationHours: (json['duration_hours'] as num?)?.toDouble(),
      availabilityDays: (json['availability_days'] as List<dynamic>?)?.cast<String>() ?? [],
      availabilityStart: json['availability_start'] as String?,
      availabilityEnd: json['availability_end'] as String?,
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at'] as String) : null,
      deletedAt: json['deleted_at'] != null ? DateTime.tryParse(json['deleted_at'] as String) : null,
      reactionCount: json['reaction_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      profile: json['profiles'] is Map<String, dynamic>
          ? json['profiles'] as Map<String, dynamic>
          : (json['profiles'] is List && (json['profiles'] as List).isNotEmpty
              ? (json['profiles'] as List).first as Map<String, dynamic>?
              : (json['author_name'] != null
                  ? {'name': json['author_name'], 'avatar_url': json['author_avatar']}
                  : null)),
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
      'media_urls': mediaUrls,
      'latitude': latitude,
      'longitude': longitude,
      'location_text': locationText,
      'urgency': urgency,
      'contact_phone': contactPhone,
      'contact_whatsapp': contactWhatsapp,
      'contact_email': contactEmail,
      'tags': tags,
      'is_anonymous': isAnonymous,
      'module_slug': moduleSlug,
      if (eventDate != null) 'event_date': eventDate!.toIso8601String().split('T').first,
      if (eventTime != null) 'event_time': eventTime,
      if (durationHours != null) 'duration_hours': durationHours,
      if (availabilityDays.isNotEmpty) 'availability_days': availabilityDays,
      if (availabilityStart != null) 'availability_start': availabilityStart,
      if (availabilityEnd != null) 'availability_end': availabilityEnd,
      if (isRecurring) 'is_recurring': isRecurring,
      if (recurringInterval != null) 'recurring_interval': recurringInterval,
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

  List<String> get allImages {
    final images = <String>[];
    images.addAll(imageUrls.where((u) => u.isNotEmpty));
    if (imageUrl != null && imageUrl!.isNotEmpty && !images.contains(imageUrl)) {
      images.insert(0, imageUrl!);
    }
    images.addAll(mediaUrls.where((u) => u.isNotEmpty && !images.contains(u)));
    return images;
  }
}
