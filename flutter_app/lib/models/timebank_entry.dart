/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `timebank_entries` (huaqldjkgyosefzfhjnf).
class TimebankEntry {
  const TimebankEntry({
    required this.id,
    required this.giverId,
    required this.receiverId,
    required this.hours,
    required this.description,
    required this.createdAt,
    this.postId,
    this.category,
    this.status,
    this.confirmedAt,
  });

  final String id;
  final String giverId;
  final String receiverId;
  final double hours;
  final String description;
  final DateTime createdAt;
  final String? postId;
  final String? category;
  final String? status;
  final DateTime? confirmedAt;

  factory TimebankEntry.fromJson(Map<String, dynamic> j) {
    return TimebankEntry(
      id: j['id'] as String,
      giverId: j['giver_id'] as String,
      receiverId: j['receiver_id'] as String,
      hours: (j['hours'] as num?)?.toDouble() ?? 0.0,
      description: j['description'] as String,
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      postId: j['post_id'] as String?,
      category: j['category'] as String?,
      status: j['status'] as String?,
      confirmedAt: j['confirmed_at'] != null
          ? DateTime.tryParse(j['confirmed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'giver_id': giverId,
        'receiver_id': receiverId,
        'hours': hours,
        'description': description,
        'created_at': createdAt.toIso8601String(),
        'post_id': postId,
        'category': category,
        'status': status,
        'confirmed_at': confirmedAt?.toIso8601String(),
      };
}
