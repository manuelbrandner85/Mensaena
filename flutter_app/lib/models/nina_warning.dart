/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `nina_warnings` (huaqldjkgyosefzfhjnf).
class NinaWarning {
  const NinaWarning({
    required this.id,
    required this.severity,
    required this.headline,
    this.description,
    this.areaText,
    this.ags,
    this.startDate,
    this.endDate,
    this.senderName,
    this.msgType,
  });

  final String id;
  final String severity;
  final String headline;
  final String? description;
  final String? areaText;
  final String? ags;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? senderName;
  final String? msgType;

  factory NinaWarning.fromJson(Map<String, dynamic> j) {
    return NinaWarning(
      id: j['id'] as String,
      severity: j['severity'] as String,
      headline: j['headline'] as String,
      description: j['description'] as String?,
      areaText: j['area_text'] as String?,
      ags: j['ags'] as String?,
      startDate: j['start_date'] != null
          ? DateTime.tryParse(j['start_date'] as String)
          : null,
      endDate: j['end_date'] != null
          ? DateTime.tryParse(j['end_date'] as String)
          : null,
      senderName: j['sender_name'] as String?,
      msgType: j['msg_type'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'severity': severity,
        'headline': headline,
        'description': description,
        'area_text': areaText,
        'ags': ags,
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'sender_name': senderName,
        'msg_type': msgType,
      };
}
