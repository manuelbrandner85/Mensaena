import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mensaena/models/board_post.dart';

class BoardService {
  final SupabaseClient _client;

  BoardService(this._client);

  Future<List<BoardPost>> getBoardPosts({
    String? category,
    String? search,
    int limit = 30,
    int offset = 0,
  }) async {
    // Try RPC first (like Web)
    if (search != null && search.isNotEmpty) {
      try {
        final data = await _client.rpc('search_board_posts', params: {
          'p_query': search,
          'p_category': category,
          'p_limit': limit,
          'p_offset': offset,
        });
        return (data as List).map((e) => BoardPost.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
    try {
      var query = _client
          .from('board_posts')
          .select('*, profiles!board_posts_author_id_fkey(name, display_name, avatar_url, trust_score)')
          .eq('status', 'active');

      if (category != null) {
        query = query.eq('category', category);
      }

      final data = await query.order('pinned', ascending: false).order('created_at', ascending: false).range(offset, offset + limit - 1);
      return (data as List).map((e) => BoardPost.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<BoardPost?> getBoardPost(String postId) async {
    final data = await _client
        .from('board_posts')
        .select('*, profiles(name, avatar_url, trust_score)')
        .eq('id', postId)
        .maybeSingle();
    if (data == null) return null;
    return BoardPost.fromJson(data);
  }

  Future<BoardPost> createBoardPost(Map<String, dynamic> postData) async {
    final data = await _client
        .from('board_posts')
        .insert(postData)
        .select('*, profiles(name, avatar_url, trust_score)')
        .single();
    return BoardPost.fromJson(data);
  }

  Future<void> updateBoardPost(String postId, Map<String, dynamic> data) async {
    await _client.from('board_posts').update(data).eq('id', postId);
  }

  Future<void> deleteBoardPost(String postId) async {
    await _client.from('board_posts').delete().eq('id', postId);
  }

  Future<String> uploadImage(Uint8List bytes, String fileName) async {
    final path = 'board/$fileName';
    await _client.storage.from('post-images').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(upsert: true),
    );
    return _client.storage.from('post-images').getPublicUrl(path);
  }

  Future<void> pinBoardPost(String postId, String userId) async {
    await _client.from('board_pins').insert({
      'board_post_id': postId,
      'user_id': userId,
    });
  }

  Future<void> unpinBoardPost(String postId, String userId) async {
    await _client
        .from('board_pins')
        .delete()
        .eq('board_post_id', postId)
        .eq('user_id', userId);
  }

  Future<List<BoardComment>> getComments(String postId) async {
    final data = await _client
        .from('board_comments')
        .select('*, profiles(name, avatar_url, trust_score)')
        .eq('board_post_id', postId)
        .order('created_at');
    return (data as List).map((e) => BoardComment.fromJson(e)).toList();
  }

  Future<void> addComment(
      String postId, String userId, String content) async {
    await _client.from('board_comments').insert({
      'board_post_id': postId,
      'author_id': userId,
      'content': content,
    });
  }

  Future<void> deleteComment(String commentId) async {
    await _client.from('board_comments').delete().eq('id', commentId);
  }
}
