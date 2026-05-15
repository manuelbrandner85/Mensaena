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
    return await q.order('created_at', ascending: false).range(offset, offset + limit - 1);
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

  /// Aktualisiert einen Post. `patch` enthaelt nur die geaenderten Felder
  /// (z.B. {title, content, tags, image_url}).
  Future<Map<String, dynamic>> updatePost(
    String id,
    Map<String, dynamic> patch,
  ) async {
    final res =
        await _c.from('posts').update(patch).eq('id', id).select().single();
    return res;
  }

  Future<void> deletePost(String id) {
    return _c.from('posts').delete().eq('id', id);
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
    return await _c
        .from('conversation_members')
        .select('conversation_id, conversations!inner(*)')
        .eq('user_id', userId)
        .order('conversations(updated_at)', ascending: false);
  }

  Future<List<Map<String, dynamic>>> listMessages(String conversationId, {int limit = 50}) async {
    return await _c
        .from('messages')
        .select('*, profiles(id, full_name, avatar_url)')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .limit(limit);
  }

  /// Bearbeitet den Inhalt einer Nachricht und setzt `edited_at`.
  Future<void> editMessage(String messageId, String content) {
    return _c
        .from('messages')
        .update({
          'content': content,
          'edited_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', messageId);
  }

  /// Soft-Delete einer Nachricht.
  Future<void> deleteMessage(String messageId) {
    return _c
        .from('messages')
        .update({
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', messageId);
  }

  /// Toggle Pin einer Nachricht im Kanal.
  Future<void> togglePinMessage(
    String messageId,
    String conversationId,
    String userId,
  ) async {
    final existing = await _c
        .from('message_pins')
        .select('id')
        .eq('message_id', messageId)
        .maybeSingle();
    if (existing != null) {
      await _c.from('message_pins').delete().eq('id', existing['id'] as Object);
    } else {
      await _c.from('message_pins').insert({
        'message_id': messageId,
        'conversation_id': conversationId,
        'pinned_by': userId,
      });
    }
  }

  /// IDs aller gepinnten Nachrichten in einer Konversation.
  Future<Set<String>> listPinnedMessageIds(String conversationId) async {
    final res = await _c
        .from('message_pins')
        .select('message_id')
        .eq('conversation_id', conversationId);
    return {
      for (final r in res)
        if (r['message_id'] != null) r['message_id'] as String,
    };
  }

  // ── CHAT CHANNELS (Admin) ───────────────────────────────────────────
  Future<List<Map<String, dynamic>>> listChannels() async {
    return await _c
        .from('chat_channels')
        .select()
        .order('sort_order', ascending: true);
  }

  Future<Map<String, dynamic>> createChannel({
    required String name,
    String? description,
    String? slug,
  }) async {
    final effectiveSlug = (slug == null || slug.isEmpty)
        ? name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        : slug;
    // Anlegen einer System-Conversation fuer den Kanal.
    final conv = await _c
        .from('conversations')
        .insert({'type': 'system', 'title': 'Kanal: $name'})
        .select()
        .single();
    final res = await _c
        .from('chat_channels')
        .insert({
          'name': name,
          'description': description,
          'slug': effectiveSlug,
          'conversation_id': conv['id'],
        })
        .select()
        .single();
    return res;
  }

  Future<void> updateChannel(String id, Map<String, dynamic> patch) {
    return _c.from('chat_channels').update(patch).eq('id', id);
  }

  Future<void> deleteChannel(String id) {
    return _c.from('chat_channels').delete().eq('id', id);
  }

  // ── ANNOUNCEMENTS ───────────────────────────────────────────────────
  /// Aktive Ankuendigung (Schema hat keine conversation_id, daher global).
  Future<Map<String, dynamic>?> getActiveAnnouncement(String conversationId) async {
    final res = await _c
        .from('chat_announcements')
        .select()
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return res;
  }

  Future<void> setChannelAnnouncement(
    String conversationId,
    String text, {
    String? createdBy,
  }) async {
    // Bestehende aktive Announcements deaktivieren.
    await _c
        .from('chat_announcements')
        .update({'is_active': false})
        .eq('is_active', true);
    if (text.trim().isEmpty) return;
    await _c.from('chat_announcements').insert({
      'title': 'Ankuendigung',
      'content': text,
      'type': 'info',
      'is_active': true,
      'created_by': createdBy,
    });
  }

  // ── DM HELPER ───────────────────────────────────────────────────────
  /// Findet oder erzeugt eine direkte 1-zu-1 Konversation zwischen
  /// `myUserId` und `otherUserId`.
  Future<String> findOrCreateDirectConversation(
    String myUserId,
    String otherUserId,
  ) async {
    final mine = await _c
        .from('conversation_members')
        .select('conversation_id, conversations!inner(type)')
        .eq('user_id', myUserId);
    final ids = <String>[
      for (final r in mine)
        if ((r['conversations'] as Map?)?['type'] == 'direct')
          r['conversation_id'] as String,
    ];
    if (ids.isNotEmpty) {
      final shared = await _c
          .from('conversation_members')
          .select('conversation_id')
          .eq('user_id', otherUserId)
          .inFilter('conversation_id', ids);
      if (shared.isNotEmpty) {
        return shared.first['conversation_id'] as String;
      }
    }
    final conv = await _c
        .from('conversations')
        .insert({'type': 'direct'})
        .select()
        .single();
    final convId = conv['id'] as String;
    await _c.from('conversation_members').insert([
      {'conversation_id': convId, 'user_id': myUserId},
      {'conversation_id': convId, 'user_id': otherUserId},
    ]);
    return convId;
  }

  /// Prueft via profiles.role ob ein User Admin ist.
  Future<bool> isAdmin(String userId) async {
    final res = await _c
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
    return (res?['role'] as String?) == 'admin';
  }

  // ── NOTIFICATIONS ───────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> listNotifications(String userId, {bool unreadOnly = false}) async {
    var q = _c.from('notifications').select().eq('user_id', userId);
    if (unreadOnly) q = q.eq('read', false);
    return await q.order('created_at', ascending: false).limit(50);
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

  Future<Map<String, dynamic>> activateCrisis({
    required String type,
    required String description,
    String? region,
    required String activatedBy,
  }) async {
    final res = await _c.from('crises').insert(<String, dynamic>{
      'type': type,
      'description': description,
      if (region != null && region.isNotEmpty) 'region': region,
      'active': true,
      'activated_by': activatedBy,
      'activated_at': DateTime.now().toUtc().toIso8601String(),
    }).select().single();
    return res;
  }

  Future<void> deactivateCrisis(String id) {
    return _c.from('crises').update(<String, dynamic>{
      'active': false,
      'deactivated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  /// Stats fuer den Admin-Krise-Tab:
  /// - Aktive Krisen
  /// - Krisenhilfe-Posts der letzten 7 Tage
  /// - Distinct Helfer:innen der letzten 7 Tage
  Future<Map<String, int>> getCrisisStats() async {
    final since = DateTime.now()
        .toUtc()
        .subtract(const Duration(days: 7))
        .toIso8601String();

    int active = 0;
    int posts = 0;
    int helpers = 0;

    try {
      final res = await _c.from('crises').select('id').eq('active', true);
      active = (res as List).length;
    } catch (_) {}

    try {
      final res = await _c
          .from('posts')
          .select('user_id')
          .eq('type', 'krisenhilfe')
          .gte('created_at', since);
      final list = List<Map<String, dynamic>>.from(res as List);
      posts = list.length;
      helpers = list
          .map((r) => r['user_id'] as String?)
          .where((u) => u != null)
          .toSet()
          .length;
    } catch (_) {}

    return <String, int>{
      'active': active,
      'posts': posts,
      'helpers': helpers,
    };
  }

  // ── ADMIN MODERATION ────────────────────────────────────────────────
  Future<void> adminDeleteRow(String table, String id) {
    return _c.from(table).delete().eq('id', id);
  }

  Future<void> setUserBanned(
    String userId, {
    required bool banned,
    String? reason,
  }) {
    final patch = <String, dynamic>{'banned': banned};
    if (banned) {
      patch['banned_reason'] = reason ?? '';
      patch['banned_at'] = DateTime.now().toUtc().toIso8601String();
    } else {
      patch['banned_reason'] = null;
      patch['banned_at'] = null;
    }
    return _c.from('profiles').update(patch).eq('id', userId);
  }

  Future<void> setReportStatus(String reportId, String status) {
    return _c.from('content_reports').update(<String, dynamic>{
      'status': status,
      'resolved_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', reportId);
  }

  Future<void> toggleBoardPin(String postId) async {
    final existing = await _c
        .from('board_pins')
        .select('post_id')
        .eq('post_id', postId)
        .maybeSingle();
    if (existing != null) {
      await _c.from('board_pins').delete().eq('post_id', postId);
    } else {
      await _c.from('board_pins').insert(<String, dynamic>{'post_id': postId});
    }
  }

  // ── PROFILE TABS ────────────────────────────────────────────────────
  /// Beitraege eines Users (Beitraege-Tab im Profil).
  Future<List<Map<String, dynamic>>> listUserPosts(
    String userId, {
    int limit = 30,
  }) async {
    return await _c
        .from('posts')
        .select('*, profiles!posts_user_id_fkey(id, name, avatar_url)')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
  }

  /// Erhaltene Trust-Bewertungen + Rater-Profil (Bewertungen-Tab).
  Future<List<Map<String, dynamic>>> listUserRatings(
    String userId, {
    int limit = 50,
  }) async {
    return await _c
        .from('trust_ratings')
        .select(
          'id, rating, comment, created_at, rater_id, '
          'rater:profiles!trust_ratings_rater_id_fkey(id, name, avatar_url)',
        )
        .eq('rated_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
  }

  /// Gruppen-Mitgliedschaften (Gruppen-Tab).
  Future<List<Map<String, dynamic>>> listUserGroups(
    String userId, {
    int limit = 50,
  }) async {
    return await _c
        .from('group_members')
        .select('joined_at, group_id, groups(id, name, description)')
        .eq('user_id', userId)
        .order('joined_at', ascending: false)
        .limit(limit);
  }

  /// Letzte Aktivitaeten / Interaktionen (Aktivitaet-Tab).
  Future<List<Map<String, dynamic>>> listUserActivity(
    String userId, {
    int limit = 20,
  }) async {
    return await _c
        .from('interactions')
        .select(
          'id, status, message, created_at, post_id, helper_id, '
          'posts(id, title, type)',
        )
        .eq('helper_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
  }

  // ── TRUST RATING / REPORTS / BLOCKS ────────────────────────────────
  Future<void> submitTrustRating({
    required String raterId,
    required String ratedUserId,
    required int rating,
    String? comment,
  }) {
    return _c.from('trust_ratings').insert(<String, dynamic>{
      'rater_id': raterId,
      'rated_id': ratedUserId,
      'rating': rating,
      if (comment != null && comment.trim().isNotEmpty)
        'comment': comment.trim(),
    });
  }

  /// Meldet ein Profil (content_reports mit content_type='profile').
  Future<void> reportUser({
    required String reporterId,
    required String targetUserId,
    required String reason,
    String? description,
  }) {
    final fullReason = description == null || description.trim().isEmpty
        ? reason
        : '$reason — ${description.trim()}';
    return _c.from('content_reports').insert(<String, dynamic>{
      'reporter_id': reporterId,
      'content_type': 'profile',
      'content_id': targetUserId,
      'reason': fullReason,
    });
  }

  Future<List<Map<String, dynamic>>> listBlockedUsers(String blockerId) async {
    return await _c
        .from('user_blocks')
        .select(
          'id, blocked_id, created_at, '
          'blocked:profiles!user_blocks_blocked_id_fkey(id, name, avatar_url)',
        )
        .eq('blocker_id', blockerId)
        .order('created_at', ascending: false);
  }

  Future<void> blockUser({
    required String blockerId,
    required String blockedId,
  }) {
    return _c.from('user_blocks').insert(<String, dynamic>{
      'blocker_id': blockerId,
      'blocked_id': blockedId,
    });
  }

  Future<void> unblockUser(String blockId) {
    return _c.from('user_blocks').delete().eq('id', blockId);
  }
}

const db = DatabaseService();
