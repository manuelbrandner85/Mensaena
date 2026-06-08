import 'package:flutter/foundation.dart';

import '../services/supabase_service.dart';

/// SKILL: mensaena-features
/// KI-Insights-Repository — Risikoprofile, Trends, NL-Analytik.
class AiInsightsRepository {
  const AiInsightsRepository._();

  // ── Nutzer-Risikoprofil ─────────────────────────────────────────────────

  /// Gespeicherte Hochrisiko-Nutzer aus ai_user_risk.
  static Future<List<Map<String, dynamic>>> fetchRiskProfiles() async {
    try {
      final rows = await sb
          .from('ai_user_risk')
          .select(
            'user_id, risk_score, level, signals, updated_at, '
            'profiles!ai_user_risk_user_id_fkey(display_name, avatar_url)',
          )
          .order('risk_score', ascending: false)
          .limit(30);
      return (rows as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
    } catch (e) {
      debugPrint('[AiInsights] fetchRiskProfiles failed: $e');
      return const [];
    }
  }

  /// Triggert Batch-Risiko-Analyse via Edge Function.
  static Future<Map<String, dynamic>> analyzeRisks() async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('ai-user-risk', body: <String, dynamic>{})
          .timeout(const Duration(seconds: 60));
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiInsights] analyzeRisks failed: $e');
      return {'error': e.toString()};
    }
  }

  // ── Trend-Erkennung ──────────────────────────────────────────────────────

  /// Gecachte oder neue Trend-Analyse.
  static Future<Map<String, dynamic>> detectTrends({bool force = false}) async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('ai-trend-detect', body: {'force': force})
          .timeout(const Duration(seconds: 30));
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiInsights] detectTrends failed: $e');
      return {'error': e.toString()};
    }
  }

  // ── NL-Analytik ──────────────────────────────────────────────────────────

  /// Stellt eine natürlichsprachliche Frage an die KI-Analytik.
  static Future<Map<String, dynamic>> nlQuery(String question) async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('ai-nl-analytics', body: {'question': question})
          .timeout(const Duration(seconds: 30));
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiInsights] nlQuery failed: $e');
      return {'error': e.toString()};
    }
  }

  // ── Entwicklungs-Agent (Admin) ────────────────────────────────────────────

  /// Schickt einen Entwicklungs-Auftrag an den Admin-Dev-Agenten.
  /// Triggert die GitHub Action (Code-Änderung → PR → CI → Auto-Merge → OTA).
  static Future<Map<String, dynamic>> createDevTask(String instruction) async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-agent', body: {'instruction': instruction})
          .timeout(const Duration(seconds: 30));
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiInsights] createDevTask failed: $e');
      return {'error': e.toString()};
    }
  }

  /// Lädt die letzten Entwicklungs-Aufträge (Admin-only via RLS).
  static Future<List<Map<String, dynamic>>> fetchDevTasks() async {
    try {
      final rows = await sb
          .from('admin_dev_tasks')
          .select('id, instruction, status, pr_url, pr_number, run_url, '
              'error, summary, created_at, updated_at')
          .order('created_at', ascending: false)
          .limit(40);
      return (rows as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
    } catch (e) {
      debugPrint('[AiInsights] fetchDevTasks failed: $e');
      return const [];
    }
  }
}
