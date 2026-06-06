/// SKILL: mensaena-architektur
/// Datenschicht für alle KI-Zusatzfunktionen (aufbauend auf der Fallback-Kette
/// in den Edge Functions). KOSTENSCHUTZ: Klassifikation + Moderation laufen
/// ZUERST lokal (Heuristik) und rufen die KI nur im Zweifel.
///
/// STABILITÄT: Alle Edge-Function-Calls laufen über [_safeInvoke] — mit
/// Timeout (gegen Hänger bei schlechtem Netz) und try/catch (ein Netzwerk-
/// fehler darf NIE bis in die UI durchschlagen). Bei Fehler: null → die
/// jeweilige Funktion liefert ihren sicheren Default (lokales Teilergebnis
/// bzw. null/fail-open).
library;

import 'package:flutter/foundation.dart' show debugPrint;

import '../services/supabase_service.dart';

class AiClassifyResult {
  const AiClassifyResult({this.type, this.category, this.fromAi = false});
  final String? type;
  final String? category;
  final bool fromAi;
}

class AiModerationResult {
  const AiModerationResult({
    required this.flagged,
    this.reason = '',
    this.severity = 'low',
    this.fromAi = false,
  });
  final bool flagged;
  final String reason;
  final String severity;
  final bool fromAi;
}

class AiFeaturesRepository {
  /// KI-Generierung kann serverseitig (LLM) einige Sekunden dauern, aber NIE
  /// ewig — danach lieber sauberer Fehler als toter Spinner.
  static const Duration _aiTimeout = Duration(seconds: 30);

  /// Ruft eine Edge Function auf und gibt `res.data` zurück — oder null bei
  /// Timeout/Netzwerk-/Funktionsfehler. Wirft NIE.
  Future<dynamic> _safeInvoke(String fn, Map<String, dynamic> body) async {
    try {
      final res = await SupabaseService.client.functions
          .invoke(fn, body: body)
          .timeout(_aiTimeout);
      return res.data;
    } catch (e) {
      debugPrint('[AiFeatures] $fn failed: $e');
      return null;
    }
  }

  static const _types = [
    'help_needed', 'help_offered', 'rescue', 'animal', 'housing', 'supply',
    'mobility', 'sharing', 'crisis', 'community',
  ];
  static const _cats = [
    'food', 'everyday', 'moving', 'animals', 'housing', 'knowledge', 'skills',
    'mental', 'mobility', 'sharing', 'emergency', 'general',
  ];

  // ── A) Beitrags-Texthilfe ───────────────────────────────────────────────
  Future<String?> improvePost(String rawText, String lang) async {
    final d = await _safeInvoke('ai-improve-post',
        {'rawText': rawText, 'lang': lang});
    if (d is Map && d['improved'] != null) return d['improved'].toString();
    return null;
  }

  // ── B) Kategorie-/Typ-Erkennung: lokal zuerst, KI nur im Zweifel ────────
  static const Map<String, List<String>> _typeKeywords = {
    'animal': ['hund', 'katze', 'tier', 'haustier', 'vermisst', 'fundtier'],
    'housing': ['wohnung', 'zimmer', 'wg', 'unterkunft', 'miete', 'obdach'],
    'mobility': ['mitfahr', 'fahrt', 'transport', 'auto', 'fahrrad', 'umzug'],
    'supply': ['ernte', 'lebensmittel', 'gemüse', 'obst', 'hof', 'milch', 'eier'],
    'sharing': ['leihen', 'verleih', 'teilen', 'werkzeug', 'gegenstand'],
    'crisis': ['notfall', 'krise', 'dringend', 'gefahr', 'katastrophe'],
    'community': ['treffen', 'gruppe', 'nachbarschaft', 'veranstaltung', 'fest'],
    'rescue': ['retten', 'tafel', 'spende', 'foodsharing', 'übrig'],
    'help_offered': ['biete', 'helfe', 'unterstütze', 'gebe', 'kann helfen'],
    'help_needed': ['suche', 'brauche', 'benötige', 'hilfe gesucht', 'wer kann'],
  };
  static const Map<String, List<String>> _catKeywords = {
    'food': ['essen', 'lebensmittel', 'mahlzeit', 'kochen'],
    'animals': ['hund', 'katze', 'tier', 'haustier'],
    'housing': ['wohnung', 'zimmer', 'unterkunft', 'wg'],
    'moving': ['umzug', 'transport', 'kisten', 'möbel'],
    'mobility': ['fahrt', 'mitfahr', 'auto', 'fahrrad'],
    'knowledge': ['wissen', 'lernen', 'erklär', 'kurs'],
    'skills': ['handwerk', 'reparatur', 'fähigkeit', 'nachhilfe'],
    'mental': ['einsam', 'reden', 'zuhören', 'seelisch', 'trost'],
    'sharing': ['leihen', 'teilen', 'verleih', 'werkzeug'],
    'emergency': ['notfall', 'dringend', 'sofort', 'gefahr'],
  };

  /// Versucht lokal zu klassifizieren; ruft die KI nur, wenn unklar.
  Future<AiClassifyResult> classifyPost(String title, String description) async {
    final text = '$title $description'.toLowerCase();
    String? type = _bestMatch(text, _typeKeywords);
    String? category = _bestMatch(text, _catKeywords);
    if (type != null && category != null) {
      return AiClassifyResult(type: type, category: category);
    }
    // Unklar -> KI-Fallback (gedrosselt serverseitig via ai_classify).
    final d = await _safeInvoke('ai-classify-post',
        {'title': title, 'description': description});
    if (d is Map) {
      final t = d['type']?.toString();
      final c = d['category']?.toString();
      return AiClassifyResult(
        type: _types.contains(t) ? t : type,
        category: _cats.contains(c) ? c : category,
        fromAi: true,
      );
    }
    return AiClassifyResult(type: type, category: category);
  }

  String? _bestMatch(String text, Map<String, List<String>> map) {
    for (final e in map.entries) {
      for (final kw in e.value) {
        if (text.contains(kw)) return e.key;
      }
    }
    return null;
  }

  // ── C) Übersetzung ───────────────────────────────────────────────────────
  Future<String?> translate(String text, String targetLang) async {
    final d = await _safeInvoke('ai-translate',
        {'text': text, 'targetLang': targetLang});
    if (d is Map && d['translated'] != null) return d['translated'].toString();
    return null;
  }

  // ── D) Moderation: lokale Wortliste zuerst, KI nur im Graubereich ───────
  static final RegExp _obvious = RegExp(
    r'\b(hurensohn|fick dich|nazi|verrecke|umbringen|t[öo]te dich)\b',
    caseSensitive: false,
  );

  Future<AiModerationResult> moderate(
    String text, {
    String? contentType,
    String? contentId,
  }) async {
    if (_obvious.hasMatch(text)) {
      return const AiModerationResult(
          flagged: true, reason: 'Offensichtlicher Verstoß', severity: 'high');
    }
    // Graubereich -> KI (serverseitig gedrosselt; legt ggf. reports-Eintrag an).
    final d = await _safeInvoke('ai-moderate', {
      'text': text,
      if (contentType != null) 'contentType': contentType,
      if (contentId != null) 'contentId': contentId,
    });
    if (d is Map) {
      return AiModerationResult(
        flagged: d['flagged'] == true,
        reason: (d['reason'] ?? '').toString(),
        severity: (d['severity'] ?? 'low').toString(),
        fromAi: true,
      );
    }
    // fail-open: bei Fehler nicht blockieren.
    return const AiModerationResult(flagged: false);
  }

  // ── E) Wiki-Entwurf (nur Admin; serverseitig geprüft) ───────────────────
  Future<Map<String, dynamic>?> wikiDraft(String topic, String lang) async {
    final d = await _safeInvoke('ai-wiki-draft', {'topic': topic, 'lang': lang});
    if (d is Map && d['draft'] != null) {
      return Map<String, dynamic>.from(d['draft'] as Map);
    }
    return null;
  }

  /// Veröffentlicht einen zuvor generierten Wiki-Entwurf (status draft -> published).
  Future<bool> publishWikiArticle(String id) async {
    try {
      await SupabaseService.client
          .from('knowledge_articles')
          .update({'status': 'published'}).eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── F) Krisen-Zusammenfassung (gecacht serverseitig) ────────────────────
  Future<String?> crisisSummary(String crisisId, String lang) async {
    final d = await _safeInvoke('ai-crisis-summary',
        {'crisis_id': crisisId, 'lang': lang});
    if (d is Map && d['summary'] != null) return d['summary'].toString();
    return null;
  }

  // ── G) Match-Begründung ──────────────────────────────────────────────────
  Future<String?> matchReason(String matchId, String lang) async {
    final d = await _safeInvoke('ai-match-reason',
        {'match_id': matchId, 'lang': lang});
    if (d is Map && d['reason'] != null) return d['reason'].toString();
    return null;
  }

  // ── H) Wöchentliche Community-Zusammenfassung (lesen; Erzeugung via Cron) ─
  Future<Map<String, dynamic>?> latestRecap() async {
    try {
      final rows = await SupabaseService.client
          .from('community_recaps')
          .select('week_start, content, stats, created_at')
          .order('week_start', ascending: false)
          .limit(1);
      if (rows.isNotEmpty) {
        return Map<String, dynamic>.from(rows.first as Map);
      }
    } catch (e) {
      debugPrint('[AiFeatures] latestRecap failed: $e');
    }
    return null;
  }
}
