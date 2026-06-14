/// Spiegel der Supabase-Tabelle `carpool_routes`.
enum DayOfWeek {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday;

  static DayOfWeek fromString(String value) {
    return DayOfWeek.values.firstWhere(
      (d) => d.name == value,
      orElse: () => DayOfWeek.monday,
    );
  }
}

class CarpoolRoute {
  const CarpoolRoute({
    required this.id,
    required this.userId,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
    required this.dayOfWeek,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final double startLat;
  final double startLng;
  final double endLat;
  final double endLng;
  final DayOfWeek dayOfWeek;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CarpoolRoute.fromJson(Map<String, dynamic> j) {
    return CarpoolRoute(
      id: j['id'] as String,
      userId: j['user_id'] as String,
      startLat: (j['start_lat'] as num).toDouble(),
      startLng: (j['start_lng'] as num).toDouble(),
      endLat: (j['end_lat'] as num).toDouble(),
      endLng: (j['end_lng'] as num).toDouble(),
      dayOfWeek: DayOfWeek.fromString(j['day_of_week'] as String),
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '')?.toUtc() ??
              DateTime.now().toUtc(),
      updatedAt:
          DateTime.tryParse(j['updated_at'] as String? ?? '')?.toUtc() ??
              DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'start_lat': startLat,
        'start_lng': startLng,
        'end_lat': endLat,
        'end_lng': endLng,
        'day_of_week': dayOfWeek.name,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
