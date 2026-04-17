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
  final String? notifCategory;
  final String title;
  final String body;
  final String? content;
  final String? link;
  final String? actorId;
  final Map<String, dynamic>? metadata;
  final bool read;
  final DateTime? readAt;
  final String priority;
  final DateTime? scheduledFor;
  final DateTime? deletedAt;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    this.notifCategory,
    required this.title,
    required this.body,
    this.content,
    this.link,
    this.actorId,
    this.metadata,
    this.read = false,
    this.readAt,
    this.priority = 'normal',
    this.scheduledFor,
    this.deletedAt,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String? ?? 'system',
      notifCategory: json['category'] as String?,
      title: json['title'] as String? ?? '',
      body: json['content'] as String? ?? json['body'] as String? ?? '',
      content: json['content'] as String?,
      link: json['link'] as String?,
      actorId: json['actor_id'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      read: json['read'] as bool? ?? (json['read_at'] != null),
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at'] as String) : null,
      priority: json['priority'] as String? ?? 'normal',
      scheduledFor: json['scheduled_for'] != null ? DateTime.parse(json['scheduled_for'] as String) : null,
      deletedAt: json['deleted_at'] != null ? DateTime.parse(json['deleted_at'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isRead => read || readAt != null;
  bool get isHighPriority => priority == 'high' || priority == 'urgent';
  NotificationCategory get category => NotificationCategory.fromString(notifCategory ?? type);
}
