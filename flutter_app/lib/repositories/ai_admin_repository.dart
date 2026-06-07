import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';

/// SKILL: supabase + mensaena-features
/// KI-Admin-Repository — Fundament für die zentrale KI-Steuerung.
///
/// Tabellen: ai_feature_flags (Schalter), ai_admin_digests (Tages-Zusammen-
/// fassung), ai_admin_audit (KI-Aktivität). Toggle nur via SECURITY-DEFINER-
/// RPC set_ai_feature_flag (admin-only). Digest via Edge Function ai-admin-digest.
class AiFeatureFlag {
  const AiFeatureFlag({
    required this.key,
    required this.category,
    required this.label,
    required this.description,
    required this.enabled,
    required this.sortOrder,
  });

  final String key;
  final String category;
  final String label;
  final String description;
  final bool enabled;
  final int sortOrder;

  factory AiFeatureFlag.fromMap(Map<String, dynamic> m) => AiFeatureFlag(
        key: (m['key'] ?? '').toString(),
        category: (m['category'] ?? 'general').toString(),
        label: (m['label'] ?? '').toString(),
        description: (m['description'] ?? '').toString(),
        enabled: m['enabled'] == true,
        sortOrder: (m['sort_order'] as num?)?.toInt() ?? 100,
      );

  AiFeatureFlag copyWith({bool? enabled}) => AiFeatureFlag(
        key: key,
        category: category,
        label: label,
        description: description,
        enabled: enabled ?? this.enabled,
        sortOrder: sortOrder,
      );
}

class AiAdminRepository {
  const AiAdminRepository._();

  /// Alle Feature-Flags, sortiert nach Kategorie + sort_order.
  static Future<List<AiFeatureFlag>> fetchFlags() async {
    try {
      final rows = await sb
          .from('ai_feature_flags')
          .select('key, category, label, description, enabled, sort_order')
          .order('sort_order');
      return (rows as List)
          .map((r) => AiFeatureFlag.fromMap(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      debugPrint('[AiAdmin] fetchFlags failed: $e');
      return const [];
    }
  }

  /// Schaltet ein Feature an/aus. true bei Erfolg.
  static Future<bool> toggleFlag(String key, bool enabled) async {
    try {
      final res = await sb.rpc('set_ai_feature_flag',
          params: {'p_key': key, 'p_enabled': enabled});
      return res == true;
    } catch (e) {
      debugPrint('[AiAdmin] toggleFlag failed: $e');
      return false;
    }
  }

  /// Neueste gecachte Tages-Zusammenfassung (oder null).
  static Future<Map<String, dynamic>?> latestDigest() async {
    try {
      final row = await sb
          .from('ai_admin_digests')
          .select('summary, stats, provider, period, created_at')
          .order('period', ascending: false)
          .limit(1)
          .maybeSingle();
      return row == null ? null : Map<String, dynamic>.from(row);
    } catch (e) {
      debugPrint('[AiAdmin] latestDigest failed: $e');
      return null;
    }
  }

  /// Erzeugt (oder erneuert) die Tages-Zusammenfassung via Edge Function.
  static Future<Map<String, dynamic>> generateDigest({bool force = false}) async {
    try {
      final res = await SupabaseService.client.functions
          .invoke('ai-admin-digest', body: {'force': force})
          .timeout(const Duration(seconds: 30));
      return Map<String, dynamic>.from((res.data as Map?) ?? const {});
    } catch (e) {
      debugPrint('[AiAdmin] generateDigest failed: $e');
      return {'error': e.toString()};
    }
  }

  /// Letzte KI-Audit-Einträge (was die KI getan/empfohlen hat).
  static Future<List<Map<String, dynamic>>> recentAudit({int limit = 20}) async {
    try {
      final rows = await sb
          .from('ai_admin_audit')
          .select('feature, action, summary, provider, created_at')
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
    } catch (e) {
      debugPrint('[AiAdmin] recentAudit failed: $e');
      return const [];
    }
  }
}

// ── Riverpod-Provider (autoDispose: Channel/State schließt beim Verlassen) ──

final aiFlagsProvider =
    FutureProvider.autoDispose<List<AiFeatureFlag>>((ref) async {
  return AiAdminRepository.fetchFlags();
});

final aiLatestDigestProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  return AiAdminRepository.latestDigest();
});

final aiAuditProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return AiAdminRepository.recentAudit();
});
