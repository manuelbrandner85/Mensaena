/// Heisst bewusst AppNotification, weil `Notification` mit
/// Flutter-Frameworks Notification-Klasse kollidiert.
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
    this.priority = 'normal',
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
  final String priority;
  final DateTime? deletedAt;

  bool get isRead => read || readAt != null;
  bool get isDeleted => deletedAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> j) {
    DateTime? parseDt(Object? v) =>
        v is String ? DateTime.tryParse(v) : null;
    return AppNotification(
      id: j['id'] as String,
      userId: j['user_id'] as String? ?? '',
      type: j['type'] as String? ?? '',
      title: j['title'] as String? ?? '',
      body: j['body'] as String? ?? '',
      createdAt: parseDt(j['created_at']) ?? DateTime.now(),
      link: j['link'] as String?,
      readAt: parseDt(j['read_at']),
      scheduledFor: parseDt(j['scheduled_for']),
      category: j['category'] as String?,
      content: j['content'] as String?,
      actorId: j['actor_id'] as String?,
      metadata: (j['metadata'] is Map)
          ? Map<String, dynamic>.from(j['metadata'] as Map)
          : const {},
      read: (j['read'] as bool?) ?? false,
      priority: j['priority'] as String? ?? 'normal',
      deletedAt: parseDt(j['deleted_at']),
    );
  }
}
