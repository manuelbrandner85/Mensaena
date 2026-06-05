/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `bot_scheduled_messages` (gyqujitkvymlmgroovch).
class BotScheduledMessage {
  const BotScheduledMessage({
    required this.id,
    required this.messageType,
    required this.title,
    required this.content,
    required this.scheduledFor,
    required this.status,
    this.targetAudience,
    this.sentAt,
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String messageType;
  final String title;
  final String content;
  final String? targetAudience;
  final DateTime scheduledFor;
  final DateTime? sentAt;
  final String status;
  final String? createdBy;
  final DateTime? createdAt;

  factory BotScheduledMessage.fromJson(Map<String, dynamic> j) {
    return BotScheduledMessage(
      id: j['id'] as String? ?? '',
      messageType: j['message_type'] as String? ?? '',
      title: j['title'] as String? ?? '',
      content: j['content'] as String? ?? '',
      targetAudience: j['target_audience'] as String?,
      scheduledFor: DateTime.tryParse(j['scheduled_for'] as String? ?? '') ??
          DateTime.now(),
      sentAt: j['sent_at'] != null
          ? DateTime.tryParse(j['sent_at'] as String)
          : null,
      status: j['status'] as String? ?? '',
      createdBy: j['created_by'] as String?,
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'message_type': messageType,
        'title': title,
        'content': content,
        'target_audience': targetAudience,
        'scheduled_for': scheduledFor.toIso8601String(),
        'sent_at': sentAt?.toIso8601String(),
        'status': status,
        'created_by': createdBy,
        'created_at': createdAt?.toIso8601String(),
      };
}
