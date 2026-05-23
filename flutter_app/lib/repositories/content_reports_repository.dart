import '../services/supabase_service.dart';

/// SKILL: supabase + mensaena-features
/// Content-Reports — content_reports(reporter_id, content_type,
/// content_id, reason, status, created_at).
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
      await sb.from('content_reports').insert({
        'reporter_id': uid,
        'content_type': contentType,
        'content_id': contentId,
        'reason': reason,
        if (details != null) 'details': details,
        'status': 'open',
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}
