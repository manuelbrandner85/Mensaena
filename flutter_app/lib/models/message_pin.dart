/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `message_pins` (huaqldjkgyosefzfhjnf).
class MessagePin {
  const MessagePin({
    required this.id,
    required this.messageId,
    required this.conversationId,
    required this.pinnedBy,
    this.pinnedAt,
  });

  final String id;
  final String messageId;
  final String conversationId;
  final String pinnedBy;
  final DateTime? pinnedAt;

  factory MessagePin.fromJson(Map<String, dynamic> j) {
    return MessagePin(
      id: j['id'] as String,
      messageId: j['message_id'] as String,
      conversationId: j['conversation_id'] as String,
      pinnedBy: j['pinned_by'] as String,
      pinnedAt: j['pinned_at'] != null
          ? DateTime.tryParse(j['pinned_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'message_id': messageId,
        'conversation_id': conversationId,
        'pinned_by': pinnedBy,
        'pinned_at': pinnedAt?.toIso8601String(),
      };
}
