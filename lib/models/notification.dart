enum NotificationCategory {
  message('message'),
  interaction('interaction'),
  trustRating('trust_rating'),
  postNearby('post_nearby'),
  postResponse('post_response'),
  system('system'),
  comment('comment'),
  event('event'),
  crisis('crisis'),
  matching('matching');

  const NotificationCategory(this.value);
  final String value;

  static NotificationCategory fromString(String value) {
    return NotificationCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NotificationCategory.system,
    );
  }
}

class AppNotification {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final String? link;
  final DateTime? readAt;
  final DateTime createdAt;

  // Joined
  final Map<String, dynamic>? actorProfile;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.link,
    this.readAt,
    required this.createdAt,
    this.actorProfile,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String? ?? 'system',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      link: json['link'] as String?,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isRead => readAt != null;
  NotificationCategory get category => NotificationCategory.fromString(type);
}
