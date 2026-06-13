/// Spiegel der Supabase-Tabelle `emergency_alerts`.
class EmergencyAlert {
  const EmergencyAlert({
    required this.id,
    required this.userId,
    required this.alertType,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.respondents,
    required this.createdAt,
    this.description,
  });

  final String id;
  final String userId;
  final String alertType;
  final double latitude;
  final double longitude;
  final String? description;
  final String status;
  final List<String> respondents;
  final DateTime createdAt;

  bool get isActive => status == 'active';

  factory EmergencyAlert.fromJson(Map<String, dynamic> json) {
    return EmergencyAlert(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      alertType: json['alert_type'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      description: json['description'] as String?,
      status: json['status'] as String? ?? 'active',
      respondents: (json['respondents'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'user_id': userId,
        'alert_type': alertType,
        'latitude': latitude,
        'longitude': longitude,
        if (description != null && description!.isNotEmpty)
          'description': description,
      };
}
