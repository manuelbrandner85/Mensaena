import 'package:flutter/foundation.dart';

import '../services/supabase_service.dart';

/// SKILL: mensaena-features
/// KI-Moderations- und Krisen-Triage-Repository.
/// Liest reports/crises mit KI-Analyse-Spalten, triggert Batch-Analysen
/// via Edge Functions und führt Status-Updates aus.
class AiModerationRepository {
  const AiModerationRepository._();

  // ── Moderation ──────────────────────────────────────────────────────────

  /// Offene Meldungen mit KI-Empfehlung, sortiert: analysiert + hohe Sicherheit zuerst.
  static Future<List<Map<String, dynamic>>> fetchPendingReports() async {
    try {
      final rows = await sb
          .from('reports')
          .select(
            'id, content_type, content_id, reason, comment, created_at, '
            'ai_recommendation, ai_confidence, ai_reason, ai_analyzed_at',
          )
          .eq('status', 'pending')
          .order('ai_confidence', ascending: false, nullsFirst: false)
          .order('created_at', ascending: true)
          .limit(50);
      return (rows as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
    } catch (e) {
      debugPrint('[AiModeration] fetchPendingReports failed: $e');
      return const [];
    }
  }

  /// Triggert Batch-KI-Analyse für alle offenen Meldungen (Edge Function).
  static Future<Map<String, dynamic>> analyzeQueue({int limit = 20}) async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('ai-moderation-queue', body: {'limit': limit}).timeout(
        const Duration(seconds: 60),
      );
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiModeration] analyzeQueue failed: $e');
      return {'error': e.toString()};
    }
  }

  /// Führt Admin-Aktion aus:
  ///   'keep'     → status = dismissed
  ///   'remove'   → status = resolved  (Inhalt muss separat entfernt werden)
  ///   'escalate' → status = reviewing
  static Future<bool> updateReportStatus(String reportId, String action) async {
    final statusMap = {
      'keep': 'dismissed',
      'remove': 'resolved',
      'escalate': 'reviewing',
    };
    final status = statusMap[action];
    if (status == null) return false;
    try {
      final update = <String, dynamic>{'status': status};
      if (action != 'escalate') {
        update['resolved_by'] = sb.auth.currentUser?.id;
        update['resolved_at'] = DateTime.now().toIso8601String();
      }
      await sb.from('reports').update(update).eq('id', reportId);
      return true;
    } catch (e) {
      debugPrint('[AiModeration] updateReportStatus failed: $e');
      return false;
    }
  }

  // ── Krisen-Triage ───────────────────────────────────────────────────────

  /// Aktive Krisen mit KI-Triage-Daten.
  static Future<List<Map<String, dynamic>>> fetchActiveCrises() async {
    try {
      final rows = await sb
          .from('crises')
          .select(
            'id, title, description, category, urgency, affected_count, '
            'location_text, helper_count, needed_helpers, created_at, '
            'ai_triage, ai_triage_urgency, ai_triage_actions, ai_triage_at',
          )
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(30);
      return (rows as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
    } catch (e) {
      debugPrint('[AiModeration] fetchActiveCrises failed: $e');
      return const [];
    }
  }

  /// Triggert Batch-Triage für aktive Krisen (Edge Function).
  static Future<Map<String, dynamic>> triageCrises() async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('ai-crisis-triage', body: <String, dynamic>{}).timeout(
        const Duration(seconds: 90),
      );
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiModeration] triageCrises failed: $e');
      return {'error': e.toString()};
    }
  }
}
