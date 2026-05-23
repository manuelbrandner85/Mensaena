/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `regions` (huaqldjkgyosefzfhjnf).
class Region {
  const Region({
    required this.id,
    required this.name,
    required this.slug,
    required this.createdAt,
    this.lat,
    this.lng,
    this.radiusKm,
  });

  final String id;
  final String name;
  final String slug;
  final DateTime createdAt;
  final double? lat;
  final double? lng;
  final int? radiusKm;

  factory Region.fromJson(Map<String, dynamic> j) {
    return Region(
      id: j['id'] as String,
      name: j['name'] as String,
      slug: j['slug'] as String,
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
      lat: (j['lat'] as num?)?.toDouble(),
      lng: (j['lng'] as num?)?.toDouble(),
      radiusKm: (j['radius_km'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'created_at': createdAt.toIso8601String(),
        'lat': lat,
        'lng': lng,
        'radius_km': radiusKm,
      };
}
