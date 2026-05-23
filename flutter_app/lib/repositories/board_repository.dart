import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/board_comment.dart';
import '../models/board_post.dart';
import '../services/supabase_service.dart';

/// SKILL: supabase + mensaena-features
/// Board (Schwarzes Brett) — Posts, Comments, Pins.
class BoardRepository {
  const BoardRepository._();

  static Future<List<BoardPost>> listActive({int limit = 50}) async {
    try {
      final rows = await sb
          .from('board_posts')
          .select()
          .eq('status', 'active')
          .order('pinned', ascending: false)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(BoardPost.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<BoardPost?> getById(String id) async {
    try {
      final row = await sb
          .from('board_posts')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return BoardPost.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> create({
    required String content,
    required String category,
    required String color,
    String? contactInfo,
    DateTime? expiresAt,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await sb
          .from('board_posts')
          .insert({
            'author_id': uid,
            'content': content,
            'category': category,
            'color': color,
            'contact_info': contactInfo,
            'expires_at': expiresAt?.toUtc().toIso8601String(),
            'status': 'active',
            'pinned': false,
            'pin_count': 0,
            'comment_count': 0,
          })
          .select()
          .single();
      return row['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> togglePin(String boardPostId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      final existing = await sb
          .from('board_pins')
          .select('id')
          .eq('board_post_id', boardPostId)
          .eq('user_id', uid)
          .maybeSingle();
      if (existing != null) {
        await sb
            .from('board_pins')
            .delete()
            .eq('board_post_id', boardPostId)
            .eq('user_id', uid);
      } else {
        await sb.from('board_pins').insert({
          'board_post_id': boardPostId,
          'user_id': uid,
        });
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isPinned(String boardPostId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      final row = await sb
          .from('board_pins')
          .select('id')
          .eq('board_post_id', boardPostId)
          .eq('user_id', uid)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  static Future<List<BoardComment>> commentsFor(String boardPostId) async {
    try {
      final rows = await sb
          .from('board_comments')
          .select()
          .eq('board_post_id', boardPostId)
          .order('created_at');
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(BoardComment.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> addComment({
    required String boardPostId,
    required String content,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('board_comments').insert({
        'board_post_id': boardPostId,
        'author_id': uid,
        'content': content,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Inhalt eines eigenen Board-Posts aktualisieren.
  static Future<bool> update({
    required String id,
    String? content,
    String? category,
    String? color,
  }) async {
    try {
      final patch = <String, dynamic>{
        if (content != null) 'content': content,
        if (category != null) 'category': category,
        if (color != null) 'color': color,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      await sb.from('board_posts').update(patch).eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Eigenen Board-Post loeschen (RLS prueft Eigentuemer).
  static Future<bool> delete(String id) async {
    try {
      await sb.from('board_posts').delete().eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final boardPostsProvider =
    FutureProvider<List<BoardPost>>((ref) async => BoardRepository.listActive());

final boardPostDetailProvider =
    FutureProvider.family<BoardPost?, String>((ref, id) => BoardRepository.getById(id));

final boardCommentsProvider =
    FutureProvider.family<List<BoardComment>, String>(
        (ref, id) => BoardRepository.commentsFor(id));

final boardIsPinnedProvider =
    FutureProvider.family<bool, String>((ref, id) => BoardRepository.isPinned(id));
