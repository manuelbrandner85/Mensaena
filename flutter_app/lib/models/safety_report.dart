// SKILL: mensaena-architektur + flutter-implement-json-serialization
// Spiegel der Supabase-Tabelle `safety_reports` (gyqujitkvymlmgroovch).
// Nachbarschafts-Sicherheitsmeldungen (Einbruch, Diebstahl, …).
import '../services/location_anonymizer.dart';

/// Mögliche Vorfall-Typen (= DB-CHECK auf `incident_type`).
class SafetyIncidentType {
  const SafetyIncidentType._();

  static const String einbruch = 'einbruch';
  static const String diebstahl = 'diebstahl';
  static const String vandalismus = 'vandalismus';
  static const String verdaechtig = 'verdaechtig';
  static const String unfall = 'unfall';
  static const String fundgegenstand = 'fundgegenstand';
  static const String other = 'other';

  static const List<String> all = [
    einbruch,
    diebstahl,
    vandalismus,
    verdaechtig,
    unfall,
    fundgegenstand,
    other,
  ];
}

class SafetyReport {
  const SafetyReport({
    required this.id,
    required this.reporterId,
    required this.title,
    required this.incidentType,
    required this.anonymous,
    required this.status,
    this.description,
    this.locationAddress,
    this.locationLat,
    this.locationLng,
    this.happenedAt,
    this.imageUrls = const [],
    this.upvoteCount = 0,
    this.createdAt,
    this.distanceKm,
  });

  final String id;

  /// Bei anonymen Meldungen serverseitig (RPC) auf null gesetzt — nie auflösbar.
  final String? reporterId;
  final String title;
  final String? description;
  final String incidentType;
  final bool anonymous;
  final String? locationAddress;
  final double? locationLat;
  final double? locationLng;
  final DateTime? happenedAt;
  final List<String> imageUrls;
  final String status;
  final int upvoteCount;
  final DateTime? createdAt;

  /// Nur über die RPC `get_nearby_safety_reports` gefüllt (km).
  final double? distanceKm;

  /// Anzeige-Name: bei anonymen Meldungen IMMER 'Anonym'-Key, sonst null
  /// (Aufrufer lädt dann das Profil). Anonymität wird zusätzlich serverseitig
  /// durch die RPC erzwungen (reporter_id = null).
  bool get isAnonymous => anonymous || reporterId == null;

  /// Anonymisierte Anzeigekoordinaten (≈1 km Genauigkeit) — schützt die
  /// exakte Position des Vorfalls/der meldenden Person auf der Karte.
  double? get displayLat =>
      locationLat != null ? LocationAnonymizer.lat(locationLat!) : null;
  double? get displayLng =>
      locationLng != null ? LocationAnonymizer.lng(locationLng!) : null;

  factory SafetyReport.fromJson(Map<String, dynamic> j) {
    return SafetyReport(
      id: j['id'] as String? ?? '',
      reporterId: j['reporter_id'] as String?,
      title: j['title'] as String? ?? '',
      description: j['description'] as String?,
      incidentType: j['incident_type'] as String? ?? SafetyIncidentType.other,
      anonymous: j['anonymous'] as bool? ?? false,
      locationAddress: j['location_address'] as String?,
      locationLat: (j['location_lat'] as num?)?.toDouble(),
      locationLng: (j['location_lng'] as num?)?.toDouble(),
      happenedAt: j['happened_at'] != null
          ? DateTime.tryParse(j['happened_at'] as String)?.toUtc()
          : null,
      imageUrls: (j['image_urls'] is List)
          ? (j['image_urls'] as List).whereType<String>().toList()
          : const [],
      status: j['status'] as String? ?? 'active',
      upvoteCount: (j['upvote_count'] as num?)?.toInt() ?? 0,
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'] as String)?.toUtc()
          : null,
      distanceKm: (j['distance_km'] as num?)?.toDouble(),
    );
  }

  /// Insert-Payload (nur vom Client gesetzte Felder; reporter_id ergänzt das
  /// Repository, Defaults/Counts übernimmt die DB).
  Map<String, dynamic> toInsert() => {
        'title': title,
        if (description != null && description!.isNotEmpty)
          'description': description,
        'incident_type': incidentType,
        'anonymous': anonymous,
        if (locationAddress != null && locationAddress!.isNotEmpty)
          'location_address': locationAddress,
        if (locationLat != null) 'location_lat': locationLat,
        if (locationLng != null) 'location_lng': locationLng,
        if (happenedAt != null) 'happened_at': happenedAt!.toIso8601String(),
        if (imageUrls.isNotEmpty) 'image_urls': imageUrls,
      };
}
