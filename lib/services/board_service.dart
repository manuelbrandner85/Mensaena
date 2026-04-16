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
    var query = _client
        .from('board_posts')
        .select('*, profiles(id, name, nickname, avatar_url)')
        .eq('status', 'active');

    if (category != null) {
      query = query.eq('category', category);
    }
    if (search != null && search.isNotEmpty) {
      query = query.or('title.ilike.%$search%,content.ilike.%$search%');
    }

    final data = await query.order('created_at', ascending: false).range(offset, offset + limit - 1);
    return (data as List).map((e) => BoardPost.fromJson(e)).toList();
  }

  Future<BoardPost?> getBoardPost(String postId) async {
    final data = await _client
        .from('board_posts')
        .select('*, profiles(id, name, nickname, avatar_url)')
        .eq('id', postId)
        .maybeSingle();
    if (data == null) return null;
    return BoardPost.fromJson(data);
  }

  Future<BoardPost> createBoardPost(Map<String, dynamic> postData) async {
    final data = await _client
        .from('board_posts')
        .insert(postData)
        .select('*, profiles(id, name, nickname, avatar_url)')
        .single();
    return BoardPost.fromJson(data);
  }

  Future<void> deleteBoardPost(String postId) async {
    await _client.from('board_posts').delete().eq('id', postId);
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
        .select('*, profiles(id, name, nickname, avatar_url)')
        .eq('board_post_id', postId)
        .order('created_at');
    return (data as List).map((e) => BoardComment.fromJson(e)).toList();
  }

  Future<void> addComment(
      String postId, String userId, String content) async {
    await _client.from('board_comments').insert({
      'board_post_id': postId,
      'user_id': userId,
      'content': content,
    });
  }
}
