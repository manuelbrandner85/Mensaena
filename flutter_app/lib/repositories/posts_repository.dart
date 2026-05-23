import '../models/post.dart';
import '../services/supabase_service.dart';

/// SKILL: supabase + mensaena-features
/// Posts-Repository: nearby (RPC), feed, create, watch.
class PostsRepository {
  const PostsRepository._();

  /// Posts in einem Umkreis um (lat, lng). Nutzt get_nearby_posts RPC.
  /// Fallback: ohne lat/lng wird die naechste active-Liste ohne Geo-Sort
  /// gezogen — z.B. wenn User Standort noch nicht freigegeben hat.
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
        return result
            .whereType<Map<String, dynamic>>()
            .map(Post.fromJson)
            .toList();
      }
      return const [];
    } catch (_) {
      // RPC nicht verfuegbar / Geo-Fehler → fallback.
      return _latestActive(limit: limit);
    }
  }

  static Future<List<Post>> _latestActive({int limit = 10}) async {
    try {
      final rows = await sb
          .from('posts')
          .select()
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(Post.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Einzelnen Post per ID holen.
  static Future<Post?> getById(String id) async {
    try {
      final row = await sb.from('posts').select().eq('id', id).maybeSingle();
      if (row == null) return null;
      return Post.fromJson(row);
    } catch (_) {
      return null;
    }
  }
}
