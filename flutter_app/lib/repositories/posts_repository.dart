import 'package:flutter/foundation.dart' show debugPrint;

import '../models/post.dart';
import '../services/supabase_service.dart';
import 'user_blocks_repository.dart';

/// SKILL: supabase + mensaena-features
/// Posts-Repository: nearby (RPC), search_posts (RPC), feed, get-by-id.
/// 1:1 zum Web — gleiche RPC-Signaturen.
class PostsRepository {
  const PostsRepository._();

  /// Memoized blocked-IDs für einen Request-Zyklus.
  /// Wird vor jeder Feed-Liste neu geladen (lazy, single roundtrip).
  static Future<List<Post>> _filterBlocked(List<Post> posts) async {
    if (posts.isEmpty) return posts;
    // Expired-Posts hier client-seitig ausfiltern statt via PostgREST-OR,
    // damit eine fehlende/falsche or()-Syntax die ganze Query nicht
    // catch't und 0 Ergebnisse liefert.
    final visible = posts.where((p) => !p.isExpired).toList();
    final blocked = await UserBlocksRepository.myBlockedIds();
    if (blocked.isEmpty) return visible;
    return visible.where((p) => !blocked.contains(p.userId)).toList();
  }

  /// Posts in einem Umkreis um (lat, lng). Nutzt get_nearby_posts RPC.
  /// HINWEIS: Die RPC existiert in der DB aktuell nicht (nur get_nearby_crises).
  /// Bis die Funktion angelegt wird, fallen Calls immer auf _latestActive
  /// zurueck — wir loggen den Fehler aber damit man im LogCat sieht warum.
  static Future<List<Post>> getNearby({
    double? lat,
    double? lng,
    int radiusKm = 10,
    int limit = 10,
  }) async {
    if (lat == null || lng == null) {
      return _latestActive(limit: limit);
    }
    try {
      final result = await sb.rpc<dynamic>(
        'get_nearby_posts',
        params: <String, dynamic>{
          'lat': lat,
          'lng': lng,
          'radius': radiusKm,
          'limit_count': limit,
        },
      );
      if (result is List) {
        final posts = result
            .whereType<Map<String, dynamic>>()
            .map(Post.fromJson)
            .toList();
        return _filterBlocked(posts);
      }
      return const [];
    } catch (e) {
      debugPrint('[PostsRepository] get_nearby_posts RPC failed: $e');
      return _latestActive(limit: limit);
    }
  }

  /// Volltext-/Geo-Suche via `search_posts` RPC — gleicher Aufruf wie auf
  /// www.mensaena.de (`posts/page.tsx` Z. 130-148). Liefert Posts nach
  /// Relevanz sortiert; ggf. filterbar via [type] und [radiusKm].
  ///
  /// Wichtig: ALLE Parameter der DB-Signatur (p_query, p_category, p_type,
  /// p_urgency, p_lat, p_lng, p_radius_km, p_limit, p_offset) muessen
  /// gesendet werden bzw. explizit als null. Bei Supabase ist das mit Named-
  /// Params zwar nicht zwingend (Defaults greifen), aber das Web-Frontend
  /// sendet alle 9 — wir spiegeln das hier 1:1 um Drift zu vermeiden.
  static Future<List<Post>> search({
    String query = '',
    String? type,
    String? category,
    String? urgency,
    double? lat,
    double? lng,
    int radiusKm = 50,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final res = await sb.rpc<dynamic>('search_posts', params: {
        'p_query': query.trim().isEmpty ? null : query.trim(),
        'p_category': category,
        'p_type': (type == null || type == 'all') ? null : type,
        'p_urgency': urgency,
        'p_lat': lat,
        'p_lng': lng,
        'p_radius_km': radiusKm,
        'p_limit': limit,
        'p_offset': offset,
      });
      if (res is List) {
        final posts = res
            .whereType<Map<String, dynamic>>()
            .map(Post.fromJson)
            .toList();
        return _filterBlocked(posts);
      }
      return const [];
    } catch (e) {
      debugPrint('[PostsRepository] search_posts RPC failed: $e');
      return _filterFallback(
        type: type,
        query: query,
        limit: limit,
        offset: offset,
      );
    }
  }

  /// Fallback wenn RPC nicht verfuegbar — Client-side LIKE/eq.
  static Future<List<Post>> _filterFallback({
    String? type,
    String query = '',
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      var q = sb.from('posts').select().eq('status', 'active');
      if (type != null && type != 'all') {
        q = q.eq('type', type);
      }
      if (query.trim().isNotEmpty) {
        final esc = query.trim().replaceAll('%', r'\%');
        q = q.or('title.ilike.%$esc%,description.ilike.%$esc%');
      }
      // expires_at-Filter passiert in _filterBlocked client-seitig.
      final rows = await q
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      final posts = (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(Post.fromJson)
          .toList();
      return _filterBlocked(posts);
    } catch (e) {
      debugPrint('[PostsRepository] _filterFallback failed: $e');
      return const [];
    }
  }

  static Future<List<Post>> _latestActive({int limit = 10}) async {
    try {
      // expires_at-Filter passiert in _filterBlocked client-seitig.
      final rows = await sb
          .from('posts')
          .select()
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(limit);
      final posts = (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(Post.fromJson)
          .toList();
      return _filterBlocked(posts);
    } catch (e) {
      debugPrint('[PostsRepository] _latestActive failed: $e');
      return const [];
    }
  }

  /// Einzelnen Post per ID holen.
  static Future<Post?> getById(String id) async {
    try {
      final row =
          await sb.from('posts').select().eq('id', id).maybeSingle();
      if (row == null) return null;
      return Post.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  /// Bookmark toggle — saved_posts(user_id, post_id) UPSERT/DELETE.
  /// Returns neuen Status (true = jetzt gespeichert).
  static Future<bool> toggleSave(String postId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      final existing = await sb
          .from('saved_posts')
          .select('post_id')
          .eq('user_id', uid)
          .eq('post_id', postId)
          .maybeSingle();
      if (existing != null) {
        await sb
            .from('saved_posts')
            .delete()
            .eq('user_id', uid)
            .eq('post_id', postId);
        return false;
      }
      await sb.from('saved_posts').insert({
        'user_id': uid,
        'post_id': postId,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Prueft ob ein Post bereits gespeichert ist.
  static Future<bool> isSaved(String postId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      final row = await sb
          .from('saved_posts')
          .select('post_id')
          .eq('user_id', uid)
          .eq('post_id', postId)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  /// Alle gespeicherten Posts des aktuellen Users.
  static Future<List<Post>> listSaved({String? collectionId}) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const [];
    try {
      var q = sb
          .from('saved_posts')
          .select('post_id, collection_id, posts(*)')
          .eq('user_id', uid);
      if (collectionId != null) {
        q = q.eq('collection_id', collectionId);
      }
      final rows = await q
          .order('created_at', ascending: false)
          .limit(100);
      final out = <Post>[];
      for (final r in (rows as List).whereType<Map<String, dynamic>>()) {
        final p = r['posts'];
        if (p is Map<String, dynamic>) {
          out.add(Post.fromJson(p));
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// Loescht einen eigenen Post (RLS pruef caller-id == author).
  /// Returns true bei Erfolg.
  static Future<bool> delete(String postId) async {
    try {
      await sb.from('posts').delete().eq('id', postId);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Populaere Tags — 1:1 aus `src/app/dashboard/posts/page.tsx` Z. 12.
const List<String> kPopularPostTags = [
  '#hilfe',
  '#notfall',
  '#tauschen',
  '#wien',
  '#graz',
  '#österreich',
  '#lebensmittel',
  '#wohnen',
  '#transport',
];

/// Radius-Presets — 1:1 aus Web `posts/page.tsx` Radius-Buttons.
const List<int> kRadiusPresetsKm = [5, 10, 25, 50, 100];
