/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `event_attendees` (gyqujitkvymlmgroovch).
class EventAttendee {
  const EventAttendee({
    required this.id,
    required this.eventId,
    required this.userId,
    this.status,
    this.reminderSet,
    this.reminderMinutes,
    this.createdAt,
  });

  final String id;
  final String eventId;
  final String userId;
  final String? status;
  final bool? reminderSet;
  final int? reminderMinutes;
  final DateTime? createdAt;

  factory EventAttendee.fromJson(Map<String, dynamic> j) {
    return EventAttendee(
      id: j['id'] as String? ?? '',
      eventId: j['event_id'] as String? ?? '',
      userId: j['user_id'] as String? ?? '',
      status: j['status'] as String?,
      reminderSet: j['reminder_set'] as bool?,
      reminderMinutes: (j['reminder_minutes'] as num?)?.toInt(),
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'] as String)?.toUtc()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'event_id': eventId,
        'user_id': userId,
        'status': status,
        'reminder_set': reminderSet,
        'reminder_minutes': reminderMinutes,
        'created_at': createdAt?.toIso8601String(),
      };
}
