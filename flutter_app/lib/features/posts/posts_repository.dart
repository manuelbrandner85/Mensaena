import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';
import 'models.dart';

final postsRepositoryProvider = Provider<PostsRepository>(
  (ref) => PostsRepository(ref.read(supabaseProvider)),
);

class PostsRepository {
  PostsRepository(this._db);
  final SupabaseClient _db;
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

  static String _sanitizeForOr(String value) =>
      value.replaceAll(RegExp(r'[,()"\\]'), ' ').trim();

  static String _escapeIlike(String value) =>
      value.replaceAllMapped(RegExp(r'[%_\\]'), (m) => '\\${m[0]}');
}
