/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `notifications` (huaqldjkgyosefzfhjnf).
/// Renamed to AppNotification to avoid collision with Flutter's Notification class.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.link,
    this.readAt,
    this.scheduledFor,
    this.category,
    this.content,
    this.actorId,
    this.metadata = const {},
    this.read = false,
    this.priority,
    this.deletedAt,
  });

  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? link;
  final DateTime? readAt;
  final DateTime? scheduledFor;
  final String? category;
  final String? content;
  final String? actorId;
  final Map<String, dynamic> metadata;
  final bool read;
  final String? priority;
  final DateTime? deletedAt;

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    return AppNotification(
      id: j['id'] as String,
      userId: j['user_id'] as String,
      type: j['type'] as String,
      title: j['title'] as String,
      body: j['body'] as String,
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      link: j['link'] as String?,
      readAt: j['read_at'] != null
          ? DateTime.tryParse(j['read_at'] as String)
          : null,
      scheduledFor: j['scheduled_for'] != null
          ? DateTime.tryParse(j['scheduled_for'] as String)
          : null,
      category: j['category'] as String?,
      content: j['content'] as String?,
      actorId: j['actor_id'] as String?,
      metadata: (j['metadata'] is Map)
          ? Map<String, dynamic>.from(j['metadata'] as Map)
          : const {},
      read: (j['read'] as bool?) ?? false,
      priority: j['priority'] as String?,
      deletedAt: j['deleted_at'] != null
          ? DateTime.tryParse(j['deleted_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'type': type,
        'title': title,
        'body': body,
        'created_at': createdAt.toIso8601String(),
        'link': link,
        'read_at': readAt?.toIso8601String(),
        'scheduled_for': scheduledFor?.toIso8601String(),
        'category': category,
        'content': content,
        'actor_id': actorId,
        'metadata': metadata,
        'read': read,
        'priority': priority,
        'deleted_at': deletedAt?.toIso8601String(),
      };

  AppNotification copyWith({
    String? title,
    String? body,
    bool? read,
    DateTime? readAt,
  }) {
    return AppNotification(
      id: id,
      userId: userId,
      type: type,
      title: title ?? this.title,
      body: body ?? this.body,
      createdAt: createdAt,
      link: link,
      readAt: readAt ?? this.readAt,
      scheduledFor: scheduledFor,
      category: category,
      content: content,
      actorId: actorId,
      metadata: metadata,
      read: read ?? this.read,
      priority: priority,
      deletedAt: deletedAt,
    );
  }
}
