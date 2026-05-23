/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `events` (huaqldjkgyosefzfhjnf).
class Event {
  const Event({
    required this.id,
    required this.userId,
    required this.title,
    required this.date,
    required this.status,
    required this.createdAt,
    this.description,
    this.endDate,
    this.locationText,
    this.latitude,
    this.longitude,
    this.maxAttendees,
    this.category,
    this.imageUrl,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String title;
  final DateTime date;
  final String status;
  final DateTime createdAt;
  final String? description;
  final DateTime? endDate;
  final String? locationText;
  final double? latitude;
  final double? longitude;
  final int? maxAttendees;
  final String? category;
  final String? imageUrl;
  final DateTime? updatedAt;

  factory Event.fromJson(Map<String, dynamic> j) {
    return Event(
      id: j['id'] as String,
      userId: j['user_id'] as String,
      title: j['title'] as String,
      date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
      status: (j['status'] as String?) ?? 'active',
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      description: j['description'] as String?,
      endDate: j['end_date'] != null
          ? DateTime.tryParse(j['end_date'] as String)
          : null,
      locationText: j['location_text'] as String?,
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
      maxAttendees: (j['max_attendees'] as num?)?.toInt(),
      category: j['category'] as String?,
      imageUrl: j['image_url'] as String?,
      updatedAt: j['updated_at'] != null
          ? DateTime.tryParse(j['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'date': date.toIso8601String(),
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'description': description,
        'end_date': endDate?.toIso8601String(),
        'location_text': locationText,
        'latitude': latitude,
        'longitude': longitude,
        'max_attendees': maxAttendees,
        'category': category,
        'image_url': imageUrl,
        'updated_at': updatedAt?.toIso8601String(),
      };
}
