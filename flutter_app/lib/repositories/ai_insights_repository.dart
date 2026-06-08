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

  /// Chatbot-Modus: schickt den Gesprächsverlauf an die KI und bekommt eine
  /// Antwort zurück. Erst wenn `ready==true` ist, liegt ein bestätigungsreifer
  /// Auftrag (`instruction`) vor, den der Admin per createDevTask absenden kann.
  static Future<Map<String, dynamic>> chatDev(
      List<Map<String, String>> messages) async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-chat', body: {'messages': messages})
          .timeout(const Duration(seconds: 40));
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiInsights] chatDev failed: $e');
      return {'error': e.toString()};
    }
  }

  /// Lädt die letzten Entwicklungs-Aufträge (Admin-only via RLS).
  static Future<List<Map<String, dynamic>>> fetchDevTasks() async {
    try {
      final rows = await sb
          .from('admin_dev_tasks')
          .select('id, instruction, status, pr_url, pr_number, run_url, '
              'ci_status, ci_run_url, error, summary, created_at, updated_at')
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

  // ── KI-Tiefenanalyse / Vorschläge (Admin) ──────────────────────────────────

  /// Lädt offene KI-Vorschläge (optional nach Kategorie gefiltert) plus den
  /// Status des letzten Scan-Laufs. Rückgabe: {suggestions: [...], scan: {...}}.
  static Future<Map<String, dynamic>> fetchDevSuggestions(
      {String? category}) async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-suggestions', body: {
            'action': 'list',
            if (category != null) 'category': category,
          })
          .timeout(const Duration(seconds: 30));
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiInsights] fetchDevSuggestions failed: $e');
      return {'error': e.toString()};
    }
  }

  /// Startet die Tiefenanalyse der gesamten App (triggert admin_scan.yml).
  static Future<Map<String, dynamic>> scanApp() async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-suggestions', body: {'action': 'scan'})
          .timeout(const Duration(seconds: 30));
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiInsights] scanApp failed: $e');
      return {'error': e.toString()};
    }
  }

  /// Nimmt einen Vorschlag an → erzeugt einen Dev-Auftrag (PR → CI → OTA).
  static Future<Map<String, dynamic>> acceptSuggestion(String id) async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-suggestions',
              body: {'action': 'accept', 'id': id})
          .timeout(const Duration(seconds: 30));
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiInsights] acceptSuggestion failed: $e');
      return {'error': e.toString()};
    }
  }

  /// Lehnt einen Vorschlag ab.
  static Future<Map<String, dynamic>> rejectSuggestion(String id) async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-suggestions',
              body: {'action': 'reject', 'id': id})
          .timeout(const Duration(seconds: 30));
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiInsights] rejectSuggestion failed: $e');
      return {'error': e.toString()};
    }
  }

  /// Nimmt mehrere Vorschläge auf einmal an (je ein Dev-Auftrag pro Vorschlag).
  static Future<Map<String, dynamic>> acceptManySuggestions(
      List<String> ids) async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-suggestions',
              body: {'action': 'accept_many', 'ids': ids})
          .timeout(const Duration(seconds: 90));
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiInsights] acceptManySuggestions failed: $e');
      return {'error': e.toString()};
    }
  }

  /// Lehnt mehrere Vorschläge auf einmal ab.
  static Future<Map<String, dynamic>> rejectManySuggestions(
      List<String> ids) async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-suggestions',
              body: {'action': 'reject_many', 'ids': ids})
          .timeout(const Duration(seconds: 30));
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiInsights] rejectManySuggestions failed: $e');
      return {'error': e.toString()};
    }
  }
}
