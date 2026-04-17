import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mensaena/models/post.dart';

class PostService {
  final SupabaseClient _client;

  PostService(this._client);

  Future<List<Post>> getPosts({
    String? type,
    String? category,
    String? search,
    String? status,
    String? urgency,
    double? lat,
    double? lng,
    double? radiusKm,
    int limit = 20,
    int offset = 0,
  }) async {
    // Use search_posts RPC for full-text search with geo + urgency sorting
    if (search != null && search.isNotEmpty || lat != null) {
      try {
        final data = await _client.rpc('search_posts', params: {
          'p_query': search,
          'p_type': type,
          'p_lat': lat,
          'p_lng': lng,
          'p_radius_km': radiusKm ?? 50,
          'p_limit': limit,
          'p_offset': offset,
        });
        return (data as List).map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        // Fallback to direct query
      }
    }

    try {
      var query = _client
          .from('posts')
          .select('*, profiles(name, avatar_url)')
          .eq('status', status ?? 'active');

      if (type != null) query = query.eq('type', type);
      if (category != null) query = query.eq('category', category);
      if (urgency != null) query = query.eq('urgency', urgency);

      final data = await query.order('urgency', ascending: false).order('created_at', ascending: false).range(offset, offset + limit - 1);
      return (data as List).map((e) => Post.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Post?> getPost(String postId) async {
    final data = await _client
        .from('posts')
        .select('*, profiles(name, avatar_url)')
        .eq('id', postId)
        .maybeSingle();
    if (data == null) return null;
    return Post.fromJson(data);
  }

  Future<List<Post>> getNearbyPosts({
    required double lat,
    required double lng,
    double radiusKm = 50,
    int limit = 50,
  }) async {
    try {
      final data = await _client.rpc('get_nearby_posts', params: {
        'p_lat': lat,
        'p_lng': lng,
        'p_radius_km': radiusKm,
        'p_limit': limit,
      });
      return (data as List).map((e) => Post.fromJson(e)).toList();
    } catch (_) {
      // Fallback: query posts with coordinates
      final data = await _client
          .from('posts')
          .select('*, profiles(name, avatar_url)')
          .eq('status', 'active')
          .not('latitude', 'is', null)
          .not('longitude', 'is', null)
          .order('created_at', ascending: false)
          .limit(limit);
      return (data as List).map((e) => Post.fromJson(e)).toList();
    }
  }

  Future<List<Post>> getUserPosts(String userId) async {
    final data = await _client
        .from('posts')
        .select('*, profiles(name, avatar_url)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => Post.fromJson(e)).toList();
  }

  Future<Post> createPost(Map<String, dynamic> postData) async {
    final data = await _client
        .from('posts')
        .insert(postData)
        .select('*, profiles(name, avatar_url)')
        .single();
    return Post.fromJson(data);
  }

  Future<void> updatePost(String postId, Map<String, dynamic> updates) async {
    await _client.from('posts').update(updates).eq('id', postId);
  }

  Future<void> deletePost(String postId) async {
    await _client.from('posts').delete().eq('id', postId);
  }

  Future<void> updateStatus(String postId, String status) async {
    await _client.from('posts').update({'status': status}).eq('id', postId);
  }

  // Saved Posts
  Future<bool> isPostSaved(String postId, String userId) async {
    final data = await _client
        .from('saved_posts')
        .select('id')
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();
    return data != null;
  }

  Future<void> savePost(String postId, String userId) async {
    await _client.from('saved_posts').insert({
      'post_id': postId,
      'user_id': userId,
    });
  }

  Future<void> unsavePost(String postId, String userId) async {
    await _client
        .from('saved_posts')
        .delete()
        .eq('post_id', postId)
        .eq('user_id', userId);
  }

  Future<List<Post>> getSavedPosts(String userId) async {
    final data = await _client
        .from('saved_posts')
        .select('posts(*, profiles(name, avatar_url))')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (data as List)
        .where((e) => e['posts'] != null)
        .map((e) => Post.fromJson(e['posts']))
        .toList();
  }

  // Image upload
  Future<String> uploadImage(Uint8List bytes, String fileName) async {
    final path = 'posts/$fileName';
    await _client.storage.from('post-images').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(upsert: true),
    );
    return _client.storage.from('post-images').getPublicUrl(path);
  }

  // Content Reporting
  Future<void> reportContent(
    String reporterId,
    String contentType,
    String contentId,
    String reason,
    String? details,
  ) async {
    await _client.from('content_reports').insert({
      'reporter_id': reporterId,
      'content_type': contentType,
      'content_id': contentId,
      'reason': reason,
      'details': details,
      'status': 'pending',
    });
  }

  // Realtime
  RealtimeChannel subscribeToNewPosts(void Function(Post) onNewPost) {
    return _client
        .channel('public:posts')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'posts',
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              onNewPost(Post.fromJson(payload.newRecord));
            }
          },
        )
        .subscribe();
  }
}
