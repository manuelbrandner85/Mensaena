/// SKILL: mensaena-architektur
/// Spiegel der Supabase-Tabelle `crisis_helpers`. Realtime-relevant fuer
/// CrisisDetail-Screen (Live-Helfer-Count).
class CrisisHelper {
  const CrisisHelper({
    required this.id,
    required this.crisisId,
    required this.userId,
    required this.status,
    this.message,
    this.skills = const [],
    this.etaMinutes,
    this.latitude,
    this.longitude,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String crisisId;
  final String userId;
  final String status; // offered | accepted | on_way | arrived | completed | withdrawn
  final String? message;
  final List<String> skills;
  final int? etaMinutes;
  final double? latitude;
  final double? longitude;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory CrisisHelper.fromJson(Map<String, dynamic> j) {
    return CrisisHelper(
      id: j['id'] as String,
      crisisId: j['crisis_id'] as String,
      userId: j['user_id'] as String,
      status: j['status'] as String? ?? 'offered',
      message: j['message'] as String?,
      skills: (j['skills'] is List)
          ? (j['skills'] as List).whereType<String>().toList()
          : const [],
      etaMinutes: (j['eta_minutes'] as num?)?.toInt(),
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'] as String)
          : null,
      updatedAt: j['updated_at'] != null
          ? DateTime.tryParse(j['updated_at'] as String)
          : null,
    );
  }
}
