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
    int limit = 20,
    int offset = 0,
  }) async {
    var query = _client
        .from('posts')
        .select('*, profiles!posts_user_id_fkey(id, name, nickname, avatar_url, trust_score)')
        .eq('status', status ?? 'active')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    if (type != null) {
      query = query.eq('type', type);
    }
    if (category != null) {
      query = query.eq('category', category);
    }
    if (search != null && search.isNotEmpty) {
      query = query.or('title.ilike.%$search%,description.ilike.%$search%');
    }

    final data = await query;
    return (data as List).map((e) => Post.fromJson(e)).toList();
  }

  Future<Post?> getPost(String postId) async {
    final data = await _client
        .from('posts')
        .select('*, profiles!posts_user_id_fkey(id, name, nickname, avatar_url, trust_score)')
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
        'user_lat': lat,
        'user_lng': lng,
        'radius_km': radiusKm,
        'max_results': limit,
      });
      return (data as List).map((e) => Post.fromJson(e)).toList();
    } catch (_) {
      // Fallback: query posts with coordinates
      final data = await _client
          .from('posts')
          .select('*, profiles!posts_user_id_fkey(id, name, nickname, avatar_url, trust_score)')
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
        .select('*, profiles!posts_user_id_fkey(id, name, nickname, avatar_url, trust_score)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => Post.fromJson(e)).toList();
  }

  Future<Post> createPost(Map<String, dynamic> postData) async {
    final data = await _client
        .from('posts')
        .insert(postData)
        .select('*, profiles!posts_user_id_fkey(id, name, nickname, avatar_url, trust_score)')
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
        .select('posts(*, profiles!posts_user_id_fkey(id, name, nickname, avatar_url, trust_score))')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (data as List)
        .where((e) => e['posts'] != null)
        .map((e) => Post.fromJson(e['posts']))
        .toList();
  }

  // Voting
  Future<void> vote(String postId, String userId, int voteValue) async {
    await _client.from('post_votes').upsert({
      'post_id': postId,
      'user_id': userId,
      'vote': voteValue,
    });
  }

  Future<void> removeVote(String postId, String userId) async {
    await _client
        .from('post_votes')
        .delete()
        .eq('post_id', postId)
        .eq('user_id', userId);
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
