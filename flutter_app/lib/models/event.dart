/// SKILL: mensaena-architektur
/// Spiegel von `events` (Live-Schema 2026-05). Tolerantes Parsing
/// fuer aeltere Rows die noch `user_id`/`date`/`location_text` haben.
class EventItem {
  const EventItem({
    required this.id,
    required this.authorId,
    required this.title,
    required this.category,
    required this.startDate,
    required this.createdAt,
    this.description,
    this.endDate,
    this.isAllDay = false,
    this.locationName,
    this.locationAddress,
    this.latitude,
    this.longitude,
    this.regionId,
    this.imageUrl,
    this.maxAttendees,
    this.cost,
    this.whatToBring,
    this.contactInfo,
    this.isRecurring = false,
    this.recurringPattern,
    this.recurringParentId,
    this.status,
    this.attendeeCount = 0,
    this.updatedAt,
    this.isOnline = false,
    this.onlineUrl,
  });

  final String id;
  final String authorId;
  final String title;
  final String category;
  final DateTime startDate;
  final DateTime createdAt;
  final String? description;
  final DateTime? endDate;
  final bool isAllDay;
  final String? locationName;
  final String? locationAddress;
  final double? latitude;
  final double? longitude;
  final String? regionId;
  final String? imageUrl;
  final int? maxAttendees;
  final String? cost;
  final String? whatToBring;
  final String? contactInfo;
  final bool isRecurring;
  final Map<String, dynamic>? recurringPattern;
  final String? recurringParentId;
  final String? status;
  final int attendeeCount;
  final DateTime? updatedAt;
  final bool isOnline;
  final String? onlineUrl;

  factory EventItem.fromJson(Map<String, dynamic> j) {
    DateTime? parseDt(Object? v) =>
        v is String && v.isNotEmpty ? DateTime.tryParse(v)?.toUtc() : null;
    return EventItem(
      id: j['id'] as String,
      authorId: (j['author_id'] ?? j['user_id']) as String? ?? '',
      title: j['title'] as String? ?? '',
      category: j['category'] as String? ?? 'sonstiges',
      startDate: parseDt(j['start_date'] ?? j['date']) ?? DateTime.now(),
      createdAt: parseDt(j['created_at']) ?? DateTime.now(),
      description: j['description'] as String?,
      endDate: parseDt(j['end_date']),
      isAllDay: (j['is_all_day'] as bool?) ?? false,
      locationName: (j['location_name'] ?? j['location_text']) as String?,
      locationAddress: j['location_address'] as String?,
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
      regionId: j['region_id'] as String?,
      imageUrl: j['image_url'] as String?,
      maxAttendees: (j['max_attendees'] as num?)?.toInt(),
      cost: j['cost'] as String?,
      whatToBring: j['what_to_bring'] as String?,
      contactInfo: j['contact_info'] as String?,
      isRecurring: (j['is_recurring'] as bool?) ?? false,
      recurringPattern: (j['recurring_pattern'] is Map)
          ? Map<String, dynamic>.from(j['recurring_pattern'] as Map)
          : null,
      recurringParentId: j['recurring_parent_id'] as String?,
      status: j['status'] as String?,
      attendeeCount: (j['attendee_count'] as num?)?.toInt() ?? 0,
      updatedAt: parseDt(j['updated_at']),
      isOnline: (j['is_online'] as bool?) ?? false,
      onlineUrl: j['online_url'] as String?,
    );
  }
}
