import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../core/supabase.dart';
import 'models.dart';

final postsRepositoryProvider = Provider<PostsRepository>(
  (ref) => PostsRepository(ref.read(supabaseProvider), ref.read(apiClientProvider)),
);

class AiAssistResult {
  const AiAssistResult({
    required this.titles,
    required this.description,
    required this.category,
  });
  final List<String> titles;
  final String description;
  final String category;
}

class PostsRepository {
  PostsRepository(this._db, this._api);
  final SupabaseClient _db;
  final ApiClient _api;
  static const _pageSize = 20;

  Future<List<Post>> list({
    String typeFilter = 'all',
    String search = '',
    String? activeTag,
    int page = 0,
  }) async {
    var query = _db
        .from('posts')
        .select('*, profiles(name, avatar_url, trust_score, trust_score_count), tags')
        .eq('status', 'active');

    if (typeFilter != 'all') {
      query = query.eq('type', typeFilter);
    }
    if (search.trim().isNotEmpty) {
      final safe = _escapeIlike(_sanitizeForOr(search));
      if (safe.isNotEmpty) {
        query = query.or('title.ilike.%$safe%,description.ilike.%$safe%');
      }
    }
    if (activeTag != null && activeTag.isNotEmpty) {
      query = query.contains('tags', [activeTag.replaceAll('#', '')]);
    }

    final from = page * _pageSize;
    final to = from + _pageSize - 1;

    final rows = await query
        .order('urgency', ascending: false)
        .order('created_at', ascending: false)
        .range(from, to);

    return rows.map(Post.fromJson).toList();
  }

  Future<Post?> fetch(String id) async {
    final row = await _db
        .from('posts')
        .select('*, profiles(name, avatar_url, trust_score, trust_score_count), tags')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return Post.fromJson(row);
  }

  Future<String> create({
    required String type,
    required String title,
    String? description,
    String? category,
    String? locationText,
    double? latitude,
    double? longitude,
    int? urgency,
    String? contactPhone,
    String? contactEmail,
    List<String> tags = const [],
    bool isAnonymous = false,
  }) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) throw Exception('Nicht eingeloggt');
    final row = await _db
        .from('posts')
        .insert(<String, dynamic>{
          'user_id': userId,
          'type': type,
          'title': title,
          if (description != null && description.isNotEmpty) 'description': description,
          if (category != null && category.isNotEmpty) 'category': category,
          if (locationText != null && locationText.isNotEmpty) 'location_text': locationText,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          if (urgency != null) 'urgency': urgency,
          if (contactPhone != null && contactPhone.isNotEmpty) 'contact_phone': contactPhone,
          if (contactEmail != null && contactEmail.isNotEmpty) 'contact_email': contactEmail,
          'tags': tags,
          'is_anonymous': isAnonymous,
          'status': 'active',
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> updateStatus(String id, String status) async {
    await _db.from('posts').update(<String, dynamic>{'status': status}).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _db.from('posts').delete().eq('id', id);
  }

  /// Calls /api/posts/ai-assist (Cloudflare Workers AI).
  /// Returns 3 title suggestions, a description draft and a category guess.
  Future<AiAssistResult> aiAssist({required String input, String? type}) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/posts/ai-assist',
      body: <String, dynamic>{
        'input': input.trim(),
        if (type != null) 'type': type,
      },
    );
    final data = response.data ?? const <String, dynamic>{};
    final titles = (data['titles'] as List?)?.whereType<String>().toList() ?? const <String>[];
    return AiAssistResult(
      titles: titles,
      description: data['description'] as String? ?? '',
      category: data['category'] as String? ?? '',
    );
  }

  Future<List<Post>> nearby({
    required double latitude,
    required double longitude,
    int radiusKm = 100,
    int limit = 200,
  }) async {
    // Fallback simple bbox filter (PostGIS RPC can't be assumed available)
    // Approximate: ±radiusKm/111 deg
    final dLat = radiusKm / 111.0;
    final dLng = radiusKm / (111.0 * 0.7); // rough cos(lat)
    final rows = await _db
        .from('posts')
        .select('*, profiles(name, avatar_url, trust_score, trust_score_count)')
        .eq('status', 'active')
        .not('latitude', 'is', null)
        .not('longitude', 'is', null)
        .gte('latitude', latitude - dLat)
        .lte('latitude', latitude + dLat)
        .gte('longitude', longitude - dLng)
        .lte('longitude', longitude + dLng)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(Post.fromJson).toList();
  }

  // ── Saved Posts (Bookmark) ──────────────────────────────────────────────

  /// IDs aller Posts, die der aktuelle User gespeichert hat.
  Future<Set<String>> savedPostIds() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return const {};
    final rows = await _db
        .from('saved_posts')
        .select('post_id')
        .eq('user_id', userId);
    return rows.map((r) => r['post_id'] as String).toSet();
  }

  /// Toggle: wenn schon gespeichert → entfernen, sonst → einfügen.
  /// Liefert true wenn Post jetzt gespeichert ist.
  Future<bool> toggleSavedPost(String postId) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) throw Exception('Nicht eingeloggt');
    final existing = await _db
        .from('saved_posts')
        .select('id')
        .eq('user_id', userId)
        .eq('post_id', postId)
        .maybeSingle();
    if (existing != null) {
      await _db
          .from('saved_posts')
          .delete()
          .eq('user_id', userId)
          .eq('post_id', postId);
      return false;
    }
    await _db.from('saved_posts').insert({
      'user_id': userId,
      'post_id': postId,
    });
    return true;
  }

  /// Liste der vom User gespeicherten Posts (für "Gemerkt"-Tab).
  Future<List<Post>> listSaved({int page = 0}) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return const [];
    final from = page * _pageSize;
    final to = from + _pageSize - 1;
    final rows = await _db
        .from('saved_posts')
        .select(
          'created_at, posts!inner(*, profiles(name, avatar_url, trust_score, trust_score_count), tags)',
        )
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .range(from, to);
    return rows
        .map((r) => Post.fromJson(r['posts'] as Map<String, dynamic>))
        .toList();
  }

  // ── Reports ─────────────────────────────────────────────────────────────

  /// Meldet einen Post bei den Moderatoren. Schreibt in `content_reports`.
  /// Wirft bei Doppel-Meldung (UNIQUE-Constraint) — Aufrufer fängt das ab.
  Future<void> reportPost({
    required String postId,
    required String reason,
  }) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) throw Exception('Nicht eingeloggt');
    await _db.from('content_reports').insert({
      'reporter_id': userId,
      'content_type': 'post',
      'content_id': postId,
      'reason': reason,
    });
  }

  static String _sanitizeForOr(String value) =>
      value.replaceAll(RegExp(r'[,()"\\]'), ' ').trim();

  static String _escapeIlike(String value) =>
      value.replaceAllMapped(RegExp(r'[%_\\]'), (m) => '\\${m[0]}');
}
