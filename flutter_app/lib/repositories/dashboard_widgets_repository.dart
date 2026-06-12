/// SKILL: supabase + mensaena-features
/// DashboardWidgetsRepository — read-only Aggregations-Queries der
/// Home-Dashboard-Widgets (Neighbors, Mentor-Eignung, Pending-Ratings,
/// Success-Stories, Weekly-Challenge). Vorher lagen diese Queries direkt
/// in den jeweiligen Widgets (sb.from-Baseline). Jede Methode ist
/// fail-safe (leeres Ergebnis statt Exception).
library;

import '../services/supabase_service.dart';

class DashboardWidgetsRepository {
  const DashboardWidgetsRepository._();

  /// Neue Nachbar:innen mit Avatar im ~50km-BBox-Ring (letzte 14 Tage).
  static Future<List<Map<String, dynamic>>> nearbyNewNeighbors({
    required String meId,
    required double lat,
    required double lng,
    int limit = 12,
  }) async {
    try {
      final since = DateTime.now()
          .subtract(const Duration(days: 14))
          .toIso8601String();
      final rows = await sb
          .from('profiles')
          .select(
              'id, display_name, avatar_url, location, latitude, longitude, created_at')
          .neq('id', meId)
          .gte('created_at', since)
          .not('avatar_url', 'is', null)
          .gte('latitude', lat - 0.7)
          .lte('latitude', lat + 0.7)
          .gte('longitude', lng - 0.7)
          .lte('longitude', lng + 0.7)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// Roh-Profil-Felder fuer die Mentor-Eignungspruefung (oder null).
  static Future<Map<String, dynamic>?> mentorEligibilityRow(
      String userId) async {
    try {
      return await sb
          .from('profiles')
          .select('is_mentor, skills, offer_tags, karma_points, trust_score')
          .eq('id', userId)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  /// Offene Bewertungs-Aufforderungen (RPC zuerst, Fallback auf
  /// completed interactions).
  static Future<List<Map<String, dynamic>>> pendingRatings(
      String userId) async {
    try {
      final res = await sb
          .rpc<dynamic>('get_pending_ratings', params: {'p_user_id': userId});
      if (res is List) {
        return res.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {/* Fallback unten */}
    try {
      final rows = await sb
          .from('interactions')
          .select('id, helper_id, helped_id, post_id, status, completed_at')
          .or('helper_id.eq.$userId,helped_id.eq.$userId')
          .eq('status', 'completed')
          .order('completed_at', ascending: false)
          .limit(5);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// Freigegebene Success-Stories (mit Bild; Fallback ohne Bild-Spalte).
  static Future<List<Map<String, dynamic>>> successStories() async {
    try {
      final rows = await sb
          .from('success_stories')
          .select(
              'id, title, body, image_url, profiles!success_stories_author_id_fkey(name, location)')
          .eq('is_approved', true)
          .order('created_at', ascending: false)
          .limit(20);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      try {
        final rows = await sb
            .from('success_stories')
            .select(
                'id, title, body, profiles!success_stories_author_id_fkey(name, location)')
            .eq('is_approved', true)
            .order('created_at', ascending: false)
            .limit(20);
        return (rows as List).whereType<Map<String, dynamic>>().toList();
      } catch (_) {
        return const [];
      }
    }
  }

  /// Top-Weekly-Challenges der angegebenen Woche.
  static Future<List<Map<String, dynamic>>> weeklyChallenges(
      String weekOf) async {
    try {
      final rows = await sb
          .from('challenges')
          .select(
              'id, title, description, category, difficulty, points, participant_count')
          .eq('is_weekly', true)
          .eq('week_of', weekOf)
          .order('points', ascending: false)
          .limit(3);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }
}
