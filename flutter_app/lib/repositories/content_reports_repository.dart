import 'package:flutter/foundation.dart';

import '../services/supabase_service.dart';

/// SKILL: supabase + mensaena-features
/// L1: umgestellt von content_reports auf reports. Alte Tabelle wird
/// gedropped. Spalten-Mapping: details → comment, resolved_by →
/// reviewed_by, resolved_at → reviewed_at. resolve_note entfällt.
/// 1:1 zu Web `/api/reports/create`.
class ContentReportsRepository {
  const ContentReportsRepository._();

  /// Meldet einen Beitrag/Kommentar/User.
  /// [contentType] = 'post' | 'comment' | 'user' | 'message'
  static Future<bool> report({
    required String contentType,
    required String contentId,
    required String reason,
    String? details,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('reports').insert({
        'reporter_id': uid,
        'content_type': contentType,
        'content_id': contentId,
        'reason': reason,
        if (details != null) 'comment': details,
        'status': 'pending',
      });
      return true;
    } catch (e) {
      debugPrint('[ContentReportsRepository.report] failed: $e');
      return false;
    }
  }
}
