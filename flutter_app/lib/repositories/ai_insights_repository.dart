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
  /// Optional mit Screenshots ([imageUrls], Vision) und Review-Gate
  /// ([awaitReview]=true → manuelle Freigabe statt Auto-Merge).
  static Future<Map<String, dynamic>> createDevTask(
    String instruction, {
    List<String> imageUrls = const [],
    bool awaitReview = false,
    List<String> plan = const [],
    bool wantScreens = false,
    String? origin,
    bool noSplit = false,
    String? model,
  }) async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-agent', body: {
            'instruction': instruction,
            if (imageUrls.isNotEmpty) 'image_urls': imageUrls,
            if (awaitReview) 'await_review': true,
            if (plan.isNotEmpty) 'plan': plan,
            if (wantScreens) 'want_screens': true,
            if (origin != null) 'origin': origin,
            if (noSplit) 'no_split': true,
            if (model != null && model.isNotEmpty) 'model': model,
          })
          .timeout(const Duration(seconds: 30));
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiInsights] createDevTask failed: $e');
      return {'error': e.toString()};
    }
  }

  /// Zerlegt eine Aufgabe in einen Multi-Step-Plan (Liste von Schritten).
  static Future<List<String>> planDevTask(String instruction) async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-agent',
              body: {'action': 'plan', 'instruction': instruction})
          .timeout(const Duration(seconds: 35));
      final data = Map<String, dynamic>.from((res.data as Map?) ?? const {});
      return ((data['steps'] as List?) ?? const [])
          .map((e) => e.toString())
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[AiInsights] planDevTask failed: $e');
      return const [];
    }
  }

  /// Lädt die hinterlegten freien API-Keys (NUR Metadaten, nie der Roh-Key).
  static Future<List<Map<String, dynamic>>> fetchApiKeys() async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-agent', body: {'action': 'keys_list'})
          .timeout(const Duration(seconds: 30));
      final data = Map<String, dynamic>.from((res.data as Map?) ?? const {});
      return ((data['keys'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      debugPrint('[AiInsights] fetchApiKeys failed: $e');
      return const [];
    }
  }

  /// Legt einen freien API-Key an/aktualisiert ihn (optional mit Ablaufdatum).
  static Future<Map<String, dynamic>> setApiKey({
    required String service,
    required String apiKey,
    String? label,
    String? expiresAtIso,
  }) async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-agent', body: {
            'action': 'key_set',
            'service': service,
            'api_key': apiKey,
            if (label != null) 'label': label,
            if (expiresAtIso != null) 'expires_at': expiresAtIso,
          })
          .timeout(const Duration(seconds: 30));
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiInsights] setApiKey failed: $e');
      return {'error': e.toString()};
    }
  }

  /// Löscht einen hinterlegten API-Key.
  static Future<Map<String, dynamic>> deleteApiKey(String service) async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-agent',
              body: {'action': 'key_delete', 'service': service})
          .timeout(const Duration(seconds: 30));
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiInsights] deleteApiKey failed: $e');
      return {'error': e.toString()};
    }
  }

  /// Bessert einen offenen Auftrag per Folge-Anweisung nach (gleicher Branch/PR).
  static Future<Map<String, dynamic>> refineDevTask(
      String id, String instruction) async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-agent',
              body: {'action': 'refine', 'id': id, 'instruction': instruction})
          .timeout(const Duration(seconds: 30));
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiInsights] refineDevTask failed: $e');
      return {'error': e.toString()};
    }
  }

  /// Setzt eine gemergte Godmode-Änderung zurück (Revert-PR → OTA).
  static Future<Map<String, dynamic>> rollbackDevTask(String id) async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-agent', body: {'action': 'rollback', 'id': id})
          .timeout(const Duration(seconds: 30));
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiInsights] rollbackDevTask failed: $e');
      return {'error': e.toString()};
    }
  }

  /// Lädt die Health-/Metrics-Kennzahlen des Godmode-Systems.
  static Future<Map<String, dynamic>> fetchDevMetrics() async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-agent', body: {'action': 'metrics'})
          .timeout(const Duration(seconds: 30));
      final data = Map<String, dynamic>.from((res.data as Map?) ?? const {});
      return Map<String, dynamic>.from((data['metrics'] as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiInsights] fetchDevMetrics failed: $e');
      return const {};
    }
  }

  // ── Wiederkehrende Aufträge (Schedules) ────────────────────────────────────

  /// Lädt alle wiederkehrenden Godmode-Aufträge.
  static Future<List<Map<String, dynamic>>> fetchDevSchedules() async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-agent', body: {'action': 'schedules_list'})
          .timeout(const Duration(seconds: 30));
      final data = Map<String, dynamic>.from((res.data as Map?) ?? const {});
      return ((data['schedules'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      debugPrint('[AiInsights] fetchDevSchedules failed: $e');
      return const [];
    }
  }

  /// Speichert einen wiederkehrenden Auftrag (neu, wenn [id] null; sonst Update).
  static Future<Map<String, dynamic>> saveDevSchedule({
    String? id,
    required String title,
    required String instruction,
    required String cadence,
    int dayOfWeek = 1,
    int dayOfMonth = 1,
    int hourUtc = 6,
    bool awaitReview = false,
    bool enabled = true,
  }) async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-agent', body: {
            'action': 'schedule_save',
            if (id != null) 'id': id,
            'title': title,
            'instruction': instruction,
            'cadence': cadence,
            'day_of_week': dayOfWeek,
            'day_of_month': dayOfMonth,
            'hour_utc': hourUtc,
            'await_review': awaitReview,
            'enabled': enabled,
          })
          .timeout(const Duration(seconds: 30));
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiInsights] saveDevSchedule failed: $e');
      return {'error': e.toString()};
    }
  }

  /// Aktiviert/deaktiviert einen wiederkehrenden Auftrag.
  static Future<Map<String, dynamic>> toggleDevSchedule(
      String id, bool enabled) async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-agent', body: {
            'action': 'schedule_toggle',
            'id': id,
            'enabled': enabled,
          })
          .timeout(const Duration(seconds: 30));
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiInsights] toggleDevSchedule failed: $e');
      return {'error': e.toString()};
    }
  }

  /// Löscht einen wiederkehrenden Auftrag.
  static Future<Map<String, dynamic>> deleteDevSchedule(String id) async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-agent',
              body: {'action': 'schedule_delete', 'id': id})
          .timeout(const Duration(seconds: 30));
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiInsights] deleteDevSchedule failed: $e');
      return {'error': e.toString()};
    }
  }

  /// Bricht einen laufenden Auftrag ab (Workflow + offener PR).
  static Future<Map<String, dynamic>> cancelDevTask(String id) async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-agent', body: {'action': 'cancel', 'id': id})
          .timeout(const Duration(seconds: 30));
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiInsights] cancelDevTask failed: $e');
      return {'error': e.toString()};
    }
  }

  /// Gibt einen wartenden Auftrag (await_review) frei und mergt den PR.
  static Future<Map<String, dynamic>> mergeDevTask(String id) async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-agent', body: {'action': 'merge', 'id': id})
          .timeout(const Duration(seconds: 40));
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiInsights] mergeDevTask failed: $e');
      return {'error': e.toString()};
    }
  }

  /// Lädt die geänderten Dateien (Diff) des PRs eines Auftrags.
  static Future<Map<String, dynamic>> fetchDevTaskDiff(String id) async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-agent', body: {'action': 'diff', 'id': id})
          .timeout(const Duration(seconds: 30));
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiInsights] fetchDevTaskDiff failed: $e');
      return {'error': e.toString()};
    }
  }

  // ── Notizen / Backlog (Admin) ──────────────────────────────────────────────

  /// Lädt die gespeicherten Godmode-Notizen (Ideen/Prompts).
  static Future<List<Map<String, dynamic>>> fetchDevNotes() async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-agent', body: {'action': 'notes_list'})
          .timeout(const Duration(seconds: 30));
      final data = Map<String, dynamic>.from((res.data as Map?) ?? const {});
      return ((data['notes'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      debugPrint('[AiInsights] fetchDevNotes failed: $e');
      return const [];
    }
  }

  /// Speichert eine Notiz (neu, wenn [id] null; sonst Update).
  static Future<Map<String, dynamic>> saveDevNote(
      {String? id, required String content}) async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-agent', body: {
            'action': 'note_save',
            if (id != null) 'id': id,
            'content': content,
          })
          .timeout(const Duration(seconds: 30));
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiInsights] saveDevNote failed: $e');
      return {'error': e.toString()};
    }
  }

  /// Löscht eine Notiz.
  static Future<Map<String, dynamic>> deleteDevNote(String id) async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-agent', body: {'action': 'note_delete', 'id': id})
          .timeout(const Duration(seconds: 30));
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiInsights] deleteDevNote failed: $e');
      return {'error': e.toString()};
    }
  }

  // ── Modul-Intelligenz (Admin) ─────────────────────────────────────────────

  /// Lädt ausstehende Modul-Erkenntnisse + letzten Scan-Lauf.
  static Future<Map<String, dynamic>> fetchModuleInsights() async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-modules', body: {'action': 'list'})
          .timeout(const Duration(seconds: 30));
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiInsights] fetchModuleInsights failed: $e');
      return const {};
    }
  }

  /// Startet einen Modul-Intelligenz-Scan.
  static Future<Map<String, dynamic>> startModuleScan() async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-modules', body: {'action': 'scan_start'})
          .timeout(const Duration(seconds: 30));
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiInsights] startModuleScan failed: $e');
      return {'error': e.toString()};
    }
  }

  /// Nimmt eine Modul-Erkenntnis an → erstellt Dev-Task.
  static Future<Map<String, dynamic>> acceptModuleInsight(String id) async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-modules', body: {'action': 'accept', 'id': id})
          .timeout(const Duration(seconds: 30));
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiInsights] acceptModuleInsight failed: $e');
      return {'error': e.toString()};
    }
  }

  /// Verwirft eine Modul-Erkenntnis.
  static Future<Map<String, dynamic>> dismissModuleInsight(String id) async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-modules', body: {'action': 'dismiss', 'id': id})
          .timeout(const Duration(seconds: 30));
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiInsights] dismissModuleInsight failed: $e');
      return {'error': e.toString()};
    }
  }

  /// Löscht eine Modul-Erkenntnis dauerhaft.
  static Future<Map<String, dynamic>> deleteModuleInsight(String id) async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-modules', body: {'action': 'delete', 'id': id})
          .timeout(const Duration(seconds: 30));
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiInsights] deleteModuleInsight failed: $e');
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

  /// Lädt den Godmode-Änderungsverlauf (gemergte Aufträge, Admin-only via RLS).
  static Future<List<Map<String, dynamic>>> fetchGodmodeChangelog() async {
    try {
      final rows = await sb
          .from('godmode_changelog')
          .select('id, title, pr_number, created_at')
          .order('created_at', ascending: false)
          .limit(50);
      return (rows as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
    } catch (e) {
      debugPrint('[AiInsights] fetchGodmodeChangelog failed: $e');
      return const [];
    }
  }

  /// Lädt die letzten Entwicklungs-Aufträge (Admin-only via RLS).
  static Future<List<Map<String, dynamic>>> fetchDevTasks() async {
    try {
      final rows = await sb
          .from('admin_dev_tasks')
          .select('id, instruction, status, pr_url, pr_number, run_url, '
              'ci_status, ci_run_url, error, summary, image_urls, '
              'await_review, plan, origin, merge_commit_sha, '
              'created_at, updated_at')
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

  /// Löscht einen einzelnen Entwicklungs-Auftrag (nur abgeschlossene).
  static Future<Map<String, dynamic>> deleteDevTask(String id) async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-agent', body: {'action': 'delete', 'id': id})
          .timeout(const Duration(seconds: 30));
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiInsights] deleteDevTask failed: $e');
      return {'error': e.toString()};
    }
  }

  /// Löscht alle abgeschlossenen Aufträge (merged/failed/no_changes) auf einmal.
  static Future<Map<String, dynamic>> clearDevTasks() async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-agent', body: {'action': 'clear'})
          .timeout(const Duration(seconds: 30));
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiInsights] clearDevTasks failed: $e');
      return {'error': e.toString()};
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

  /// Markiert Vorschläge als angenommen, OHNE selbst Tasks zu erzeugen.
  /// Wird genutzt, wenn der (ggf. bearbeitete/gebündelte) Auftrag bereits via
  /// [createDevTask] angelegt wurde und nur noch verknüpft werden muss.
  static Future<Map<String, dynamic>> markSuggestionsAccepted(
      List<String> ids, String? taskId) async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('admin-dev-suggestions', body: {
            'action': 'mark_accepted',
            'ids': ids,
            if (taskId != null) 'task_id': taskId,
          })
          .timeout(const Duration(seconds: 30));
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiInsights] markSuggestionsAccepted failed: $e');
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
