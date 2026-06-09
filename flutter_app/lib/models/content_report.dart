/// SKILL: mensaena-architektur + flutter-implement-json-serialization
/// Spiegel der Supabase-Tabelle `reports` (gyqujitkvymlmgroovch).
/// L1: Migration von content_reports → reports. Spalten-Mapping:
///   details → comment, resolvedBy → reviewedBy, resolvedAt → reviewedAt.
///   resolveNote entfällt (Spalte existiert in `reports` nicht).
/// Klassenname `ContentReport` bleibt aus Backwards-Compat-Gründen
/// erhalten — alle bestehenden Imports funktionieren unverändert.
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
  final DateTime? createdAt;

  factory ContentReport.fromJson(Map<String, dynamic> j) {
    return ContentReport(
      id: j['id'] as String? ?? '',
      reporterId: j['reporter_id'] as String? ?? '',
      contentType: j['content_type'] as String? ?? '',
      contentId: j['content_id'] as String? ?? '',
      reason: j['reason'] as String? ?? '',
      // L1: 'details' (alte Tabelle) ODER 'comment' (neue Tabelle).
      details: (j['comment'] ?? j['details']) as String?,
      status: j['status'] as String? ?? '',
      resolvedBy: (j['reviewed_by'] ?? j['resolved_by']) as String?,
      resolvedAt: (j['reviewed_at'] ?? j['resolved_at']) != null
          ? DateTime.tryParse(
              (j['reviewed_at'] ?? j['resolved_at']) as String)?.toUtc()
          : null,
      createdAt: j['created_at'] != null
          ? DateTime.tryParse(j['created_at'] as String)?.toUtc()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'reporter_id': reporterId,
        'content_type': contentType,
        'content_id': contentId,
        'reason': reason,
        'comment': details,
        'status': status,
        'reviewed_by': resolvedBy,
        'reviewed_at': resolvedAt?.toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
      };
}
