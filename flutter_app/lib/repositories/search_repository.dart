/// SKILL: supabase + mensaena-features
/// SearchRepository — alle Quellen der globalen Suche an einem Ort.
///
/// Jede Quelle: 8s-Timeout (eine haengende Query darf das Future.wait der
/// Suche nicht blockieren) + Fail-Safe (fehlende Tabelle/RLS -> leere
/// Liste statt Gesamtausfall). Vorher lagen diese 8 Queries direkt im
/// global_search_screen (UI-Schicht-Verstoss, sb.from-Baseline).
library;

import '../services/supabase_service.dart';

class SearchRepository {
  const SearchRepository._();

  static const _timeout = Duration(seconds: 8);

  static Future<List<Map<String, dynamic>>> _safe(
      Future<dynamic> Function() run) async {
    try {
      final res = await run().timeout(_timeout);
      if (res is List) {
        return res.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return const [];
  }

  static Future<List<Map<String, dynamic>>> profiles(String pattern) =>
      _safe(() => sb
          .from('profiles')
          .select('id, name, display_name, nickname, avatar_url, location')
          .or('name.ilike.$pattern,nickname.ilike.$pattern,display_name.ilike.$pattern')
          .limit(10));

  static Future<List<Map<String, dynamic>>> events(String pattern) =>
      _safe(() => sb
          .from('events')
          .select('id, title, description, start_date, location_name')
          .ilike('title', pattern)
          .eq('status', 'active')
          .order('start_date')
          .limit(10));

  static Future<List<Map<String, dynamic>>> organizations(String pattern) =>
      _safe(() => sb
          .from('organizations')
          .select('id, name, category, city, is_verified')
          .or('name.ilike.$pattern,description.ilike.$pattern')
          .limit(10));

  static Future<List<Map<String, dynamic>>> groups(String pattern) =>
      _safe(() => sb
          .from('groups')
          .select('id, name, slug, category, description, member_count')
          .or('name.ilike.$pattern,description.ilike.$pattern')
          .neq('is_archived', true)
          .order('member_count', ascending: false)
          .limit(10));

  static Future<List<Map<String, dynamic>>> marketplace(String pattern) =>
      _safe(() => sb
          .from('marketplace_listings')
          .select('id, title, listing_type, category, price, location_text')
          .or('title.ilike.$pattern,description.ilike.$pattern')
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(10));

  static Future<List<Map<String, dynamic>>> boardPosts(String pattern) =>
      _safe(() => sb
          .from('board_posts')
          .select('id, content, category, color, created_at')
          .ilike('content', pattern)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(10));

  static Future<List<Map<String, dynamic>>> knowledge(String pattern) =>
      _safe(() => sb
          .from('knowledge_articles')
          .select('id, slug, title, summary, category')
          .or('title.ilike.$pattern,summary.ilike.$pattern,content.ilike.$pattern')
          .eq('is_public', true)
          .limit(10));

  /// Fallback-Postsuche via direktem ilike (wenn search_posts-RPC scheitert).
  static Future<List<Map<String, dynamic>>> postsFallback(String q) =>
      _safe(() => sb
          .from('posts')
          .select('id, title, type, description, created_at')
          .or('title.ilike.%$q%,description.ilike.%$q%')
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(10));
}
