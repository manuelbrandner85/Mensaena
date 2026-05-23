/// SKILL: mensaena-architektur
/// Spiegel von `emergency_numbers` — DE/AT/CH Notruf-Nummern.
class EmergencyNumber {
  const EmergencyNumber({
    required this.id,
    required this.country,
    required this.category,
    required this.label,
    required this.number,
    this.description,
    this.is24h,
    this.isFree,
    this.sortOrder,
    this.createdAt,
  });

  final String id;
  final String country;
  final String category;
  final String label;
  final String number;
  final String? description;
  final bool? is24h;
  final bool? isFree;
  final int? sortOrder;
  final DateTime? createdAt;

  factory EmergencyNumber.fromJson(Map<String, dynamic> j) {
    return EmergencyNumber(
      id: j['id'] as String,
      country: j['country'] as String,
      category: j['category'] as String,
      label: j['label'] as String,
      number: j['number'] as String,
      description: j['description'] as String?,
      is24h: j['is_24h'] as bool?,
      isFree: j['is_free'] as bool?,
      sortOrder: (j['sort_order'] as num?)?.toInt(),
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'] as String)
          : null,
    );
  }
}
