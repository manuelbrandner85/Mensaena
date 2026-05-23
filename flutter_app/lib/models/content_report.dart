/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `content_reports` (huaqldjkgyosefzfhjnf).
class ContentReport {
  const ContentReport({
    required this.id,
    required this.reporterId,
    required this.contentType,
    required this.contentId,
    required this.reason,
    required this.status,
    this.details,
    this.resolvedBy,
    this.resolvedAt,
    this.resolveNote,
    this.createdAt,
  });

  final String id;
  final String reporterId;
  final String contentType;
  final String contentId;
  final String reason;
  final String? details;
  final String status;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final String? resolveNote;
  final DateTime? createdAt;

  factory ContentReport.fromJson(Map<String, dynamic> j) {
    return ContentReport(
      id: j['id'] as String? ?? '',
      reporterId: j['reporter_id'] as String? ?? '',
      contentType: j['content_type'] as String? ?? '',
      contentId: j['content_id'] as String? ?? '',
      reason: j['reason'] as String? ?? '',
      details: j['details'] as String?,
      status: j['status'] as String? ?? '',
      resolvedBy: j['resolved_by'] as String?,
      resolvedAt: j['resolved_at'] != null ? DateTime.tryParse(j['resolved_at'] as String) : null,
      resolveNote: j['resolve_note'] as String?,
      createdAt: j['created_at'] != null ? DateTime.tryParse(j['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'reporter_id': reporterId,
        'content_type': contentType,
        'content_id': contentId,
        'reason': reason,
        'details': details,
        'status': status,
        'resolved_by': resolvedBy,
        'resolved_at': resolvedAt?.toIso8601String(),
        'resolve_note': resolveNote,
        'created_at': createdAt?.toIso8601String(),
      };
}
