/// SKILL: mensaena-architektur
/// Spiegel von `zeitbank_notifications` — triggert Bestaetigungs-Banner
/// via Realtime.
class ZeitbankNotification {
  const ZeitbankNotification({
    required this.id,
    required this.userId,
    required this.entryId,
    required this.type,
    required this.message,
    required this.seen,
    required this.clicked,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String entryId;
  final String type; // confirmation_request | confirmed | rejected
  final String message;
  final bool seen;
  final bool clicked;
  final DateTime createdAt;

  factory ZeitbankNotification.fromJson(Map<String, dynamic> j) {
    return ZeitbankNotification(
      id: j['id'] as String,
      userId: j['user_id'] as String,
      entryId: j['entry_id'] as String,
      type: j['type'] as String? ?? 'confirmation_request',
      message: j['message'] as String? ?? '',
      seen: (j['seen'] as bool?) ?? false,
      clicked: (j['clicked'] as bool?) ?? false,
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '')?.toUtc() ??
          DateTime.now(),
    );
  }
}
