import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Typed Query-Helpers fuer die wichtigsten Tabellen. Halten die
/// Screens schlank — Filterung/Joins/Orders zentral hier.
class DatabaseService {
  const DatabaseService();

  SupabaseClient get _c => supabase.client;

  // ── PROFILES ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    final res = await _c.from('profiles').select().eq('id', userId).maybeSingle();
    return res;
  }

  Future<void> updateProfile(String userId, Map<String, dynamic> patch) {
    return _c.from('profiles').update(patch).eq('id', userId);
  }

  // ── POSTS ───────────────────────────────────────────────────────────
  /// Feed-Posts mit Verfasser-Profil; sortiert nach created_at DESC.
  Future<List<Map<String, dynamic>>> listFeedPosts({
    int limit = 20,
    int offset = 0,
    List<String>? typeFilter,
    String? regionId,
  }) async {
    var q = _c
        .from('posts')
        .select('*, profiles!posts_user_id_fkey(id, full_name, avatar_url)');
    if (typeFilter != null && typeFilter.isNotEmpty) {
      q = q.inFilter('type', typeFilter);
    }
    if (regionId != null) q = q.eq('region_id', regionId);
    return (await q
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1)) as List<Map<String, dynamic>>;
  }

  Future<Map<String, dynamic>?> getPost(String id) {
    return _c
        .from('posts')
        .select('*, profiles!posts_user_id_fkey(id, full_name, avatar_url)')
        .eq('id', id)
        .maybeSingle();
  }

  Future<Map<String, dynamic>> createPost(Map<String, dynamic> data) async {
    final res = await _c.from('posts').insert(data).select().single();
    return res;
  }

  // ── INTERACTIONS / VOTES / SAVED ────────────────────────────────────
  Future<void> togglePostVote(String postId, String userId) async {
    final existing = await _c
        .from('post_votes')
        .select('id')
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();
    if (existing != null) {
      await _c.from('post_votes').delete().eq('id', existing['id'] as Object);
    } else {
      await _c.from('post_votes').insert({'post_id': postId, 'user_id': userId});
    }
  }

  Future<void> toggleSavedPost(String postId, String userId) async {
    final existing = await _c
        .from('saved_posts')
        .select('id')
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();
    if (existing != null) {
      await _c.from('saved_posts').delete().eq('id', existing['id'] as Object);
    } else {
      await _c.from('saved_posts').insert({'post_id': postId, 'user_id': userId});
    }
  }

  // ── CONVERSATIONS / MESSAGES ────────────────────────────────────────
  Future<List<Map<String, dynamic>>> listConversations(String userId) async {
    return (await _c
        .from('conversation_members')
        .select('conversation_id, conversations!inner(*)')
        .eq('user_id', userId)
        .order('conversations(updated_at)', ascending: false)) as List<Map<String, dynamic>>;
  }

  Future<List<Map<String, dynamic>>> listMessages(String conversationId, {int limit = 50}) async {
    return (await _c
        .from('messages')
        .select('*, profiles(id, full_name, avatar_url)')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .limit(limit)) as List<Map<String, dynamic>>;
  }

  // ── NOTIFICATIONS ───────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> listNotifications(String userId, {bool unreadOnly = false}) async {
    var q = _c.from('notifications').select().eq('user_id', userId);
    if (unreadOnly) q = q.eq('read', false);
    return (await q.order('created_at', ascending: false).limit(50)) as List<Map<String, dynamic>>;
  }

  Future<void> markAllRead(String userId) {
    return _c.from('notifications').update({'read': true}).eq('user_id', userId).eq('read', false);
  }

  // ── CRISES ──────────────────────────────────────────────────────────
  Stream<List<Map<String, dynamic>>> watchActiveCrises() {
    return _c
        .from('crises')
        .stream(primaryKey: ['id'])
        .eq('active', true)
        .order('created_at', ascending: false);
  }
}

const db = DatabaseService();
