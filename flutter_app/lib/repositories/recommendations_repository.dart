import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../services/supabase_service.dart';

/// SKILL: mensaena-features
/// Nachbarschafts-Empfehlungen — Personen & Betriebe mit Kategorie,
/// Sterne, Freitext und optionalem Foto. Vertrauens-Score steigt,
/// wenn mehrere Empfehlungen aus demselben Stadtteil stammen.
class RecommendationsRepository {
  const RecommendationsRepository._();

  static const _table = 'recommendations';
  static const _bucket = 'recommendation-images';

  // ── Lesen ────────────────────────────────────────────────────────

  /// Sucht Empfehlungen nach Kategorie und/oder PLZ-Präfix.
  /// [category] null → alle Kategorien.
  /// [postalPrefix] null → kein PLZ-Filter.
  /// Liefert max [limit] Einträge mit Autor-Profil + trust_count.
  static Future<List<Map<String, dynamic>>> search({
    String? category,
    String? postalPrefix,
    int limit = 50,
  }) async {
    try {
      var query = sb
          .from(_table)
          .select(
            'id, type, name, category, stars, text, photo_url, postal_code, '
            'neighborhood, created_at, user_id, '
            'profiles!recommendations_user_id_fkey(id, display_name, name, avatar_url)',
          )
          .order('created_at', ascending: false)
          .limit(limit);

      if (category != null && category.isNotEmpty) {
        query = query.eq('category', category);
      }
      if (postalPrefix != null && postalPrefix.isNotEmpty) {
        query = query.ilike('postal_code', '$postalPrefix%');
      }

      final rows = await query;
      final list = (rows as List).whereType<Map<String, dynamic>>().toList();
      return _attachTrustCounts(list);
    } catch (_) {
      return const [];
    }
  }

  /// Alle Empfehlungen eines Nutzers (eigene Erstellungen).
  static Future<List<Map<String, dynamic>>> byUser(String userId,
      {int limit = 50}) async {
    try {
      final rows = await sb
          .from(_table)
          .select(
            'id, type, name, category, stars, text, photo_url, postal_code, '
            'neighborhood, created_at',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  // ── Schreiben ────────────────────────────────────────────────────

  /// Erstellt eine neue Empfehlung. Gibt `true` bei Erfolg zurück.
  static Future<bool> create({
    required String type, // 'person' | 'business'
    required String name,
    required String category,
    required int stars,
    required String text,
    String? postalCode,
    String? neighborhood,
    String? photoUrl,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    if (stars < 1 || stars > 5) return false;
    try {
      await sb.from(_table).insert({
        'user_id': uid,
        'type': type,
        'name': name.trim(),
        'category': category,
        'stars': stars,
        'text': text.trim(),
        if (postalCode != null && postalCode.trim().isNotEmpty)
          'postal_code': postalCode.trim(),
        if (neighborhood != null && neighborhood.trim().isNotEmpty)
          'neighborhood': neighborhood.trim(),
        if (photoUrl != null) 'photo_url': photoUrl,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Lädt ein Bild nach Supabase Storage und gibt die public URL zurück.
  static Future<String?> uploadPhoto(Uint8List bytes, String ext) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return null;
    final path =
        'recommendations/$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    try {
      await sb.storage.from(_bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$ext'),
          );
      return sb.storage.from(_bucket).getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }

  // ── Vertrauens-Score ─────────────────────────────────────────────

  /// Berechnet den Vertrauens-Score einer Empfehlungs-Gruppe (gleiches
  /// [name] + [category]): Basiswert aus Durchschnitts-Sternen, Bonus
  /// durch mehrere Empfehlungen aus demselben Stadtteil.
  static double trustScore({
    required double avgStars,
    required int neighborhoodCount,
  }) {
    final base = (avgStars / 5.0) * 80.0;
    final bonus = (neighborhoodCount.clamp(0, 5) * 4.0);
    return (base + bonus).clamp(0.0, 100.0);
  }

  // ── Intern ───────────────────────────────────────────────────────

  /// Fügt jedem Eintrag eine `trust_count`-Zahl hinzu: wie viele
  /// Empfehlungen es für denselben `name`+`category`-Key gibt.
  static List<Map<String, dynamic>> _attachTrustCounts(
      List<Map<String, dynamic>> rows) {
    final counts = <String, int>{};
    for (final r in rows) {
      final key = '${r['name']}_${r['category']}';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return rows.map((r) {
      final key = '${r['name']}_${r['category']}';
      return {...r, 'trust_count': counts[key] ?? 1};
    }).toList();
  }
}
