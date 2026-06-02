import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';

/// SKILL: supabase + mensaena-features
/// Bundles fuer Post-relatierte Aktionen (Comments, Votes, Saves, Shares,
/// Reports). Eine Klasse pro Post-Sub-Entity, alle static.
class PostCommentsRepository {
  const PostCommentsRepository._();

  static Future<List<Map<String, dynamic>>> listFor(String postId) async {
    try {
      final rows = await sb
          .from('post_comments')
          .select(
              '*, profiles!post_comments_user_id_fkey(name,display_name,avatar_url)')
          .eq('post_id', postId)
          .filter('deleted_at', 'is', null)
          .order('created_at');
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> add({
    required String postId,
    required String content,
    String? parentId,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('post_comments').insert({
        'post_id': postId,
        'user_id': uid,
        'content': content,
        'parent_id': parentId,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Eigenen Kommentar editieren (Soft via is_edited + updated_at).
  static Future<bool> edit({
    required String commentId,
    required String newContent,
  }) async {
    try {
      await sb.from('post_comments').update({
        'content': newContent.trim(),
        'is_edited': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', commentId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Soft-Delete (setzt deleted_at), behaelt parent_id-Threads intakt.
  static Future<bool> deleteComment(String commentId) async {
    try {
      await sb.from('post_comments').update({
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', commentId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Anzahl der nicht-geloeschten Kommentare.
  static Future<int> count(String postId) async {
    try {
      final rows = await sb
          .from('post_comments')
          .select('id')
          .eq('post_id', postId)
          .filter('deleted_at', 'is', null);
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }
}

class PostVotesRepository {
  const PostVotesRepository._();

  /// Voted: 1 = up, -1 = down, null = nicht gevoted.
  static Future<int?> myVote(String postId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await sb
          .from('post_votes')
          .select('vote')
          .eq('post_id', postId)
          .eq('user_id', uid)
          .maybeSingle();
      if (row == null) return null;
      return (row['vote'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  static Future<int> totalScore(String postId) async {
    try {
      final rows =
          await sb.from('post_votes').select('vote').eq('post_id', postId);
      var sum = 0;
      for (final r in (rows as List)) {
        sum += ((r as Map)['vote'] as num?)?.toInt() ?? 0;
      }
      return sum;
    } catch (_) {
      return 0;
    }
  }

  /// Toggle: gleicher Vote → entfernen. Anderer/neuer → upsert.
  static Future<void> vote({
    required String postId,
    required int value,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    try {
      final current = await myVote(postId);
      if (current == value) {
        await sb
            .from('post_votes')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', uid);
      } else {
        await sb.from('post_votes').upsert({
          'post_id': postId,
          'user_id': uid,
          'vote': value,
        }, onConflict: 'post_id,user_id');
      }
    } catch (_) {}
  }

  /// Up/Down-Counts separat.
  static Future<({int up, int down})> counts(String postId) async {
    try {
      final rows =
          await sb.from('post_votes').select('vote').eq('post_id', postId);
      int up = 0, down = 0;
      for (final r in (rows as List)) {
        final v = ((r as Map)['vote'] as num?)?.toInt();
        if (v == 1) {
          up++;
        } else if (v == -1) {
          down++;
        }
      }
      return (up: up, down: down);
    } catch (_) {
      return (up: 0, down: 0);
    }
  }
}

class SavedPostsRepository {
  const SavedPostsRepository._();

  static Future<bool> isSaved(String postId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      final row = await sb
          .from('saved_posts')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', uid)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  static Future<void> toggle(String postId, {String? collectionId}) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    try {
      if (await isSaved(postId)) {
        await sb
            .from('saved_posts')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', uid);
      } else {
        await sb.from('saved_posts').insert({
          'post_id': postId,
          'user_id': uid,
          if (collectionId != null) 'collection_id': collectionId,
        });
      }
    } catch (_) {}
  }
}

class ContentReportsRepository {
  const ContentReportsRepository._();

  static Future<bool> report({
    required String contentType,
    required String contentId,
    required String reason,
    String? details,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      // L1: content_reports → reports. details → comment.
      await sb.from('reports').insert({
        'reporter_id': uid,
        'content_type': contentType,
        'content_id': contentId,
        'reason': reason,
        if (details != null) 'comment': details,
        'status': 'pending',
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}

class InteractionsCreateRepository {
  const InteractionsCreateRepository._();

  /// Helfen-Button: legt eine Interaction an. Verhindert Doppel-Angebote
  /// (gleiche:r Helfer:in auf demselben Post mit offenem Status) und setzt
  /// helped_id = Post-Eigentümer:in, damit die bidirektionale Verknüpfung
  /// (Bewertungs-Partner, Benachrichtigung) stimmt — vorher blieb sie null.
  static Future<bool> offerHelp({
    required String postId,
    String? message,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      // Schon ein offenes Angebot von mir auf diesem Post? → nicht doppeln.
      final existing = await sb
          .from('interactions')
          .select('id')
          .eq('post_id', postId)
          .eq('helper_id', uid)
          .inFilter('status', ['pending', 'accepted', 'on_way', 'arrived'])
          .limit(1);
      if ((existing as List).isNotEmpty) return false;

      // Post-Eigentümer:in für helped_id ermitteln (eigenen Post nicht helfen).
      final post = await sb
          .from('posts')
          .select('user_id')
          .eq('id', postId)
          .maybeSingle();
      final ownerId = post?['user_id'] as String?;
      if (ownerId != null && ownerId == uid) return false;

      await sb.from('interactions').insert({
        'post_id': postId,
        'helper_id': uid,
        if (ownerId != null) 'helped_id': ownerId,
        'status': 'pending',
        'message': message,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ── Riverpod Provider ──────────────────────────────────────

final postCommentsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, postId) => PostCommentsRepository.listFor(postId),
);

final postCommentCountProvider = FutureProvider.family<int, String>(
  (ref, postId) => PostCommentsRepository.count(postId),
);

final postMyVoteProvider = FutureProvider.family<int?, String>(
  (ref, postId) => PostVotesRepository.myVote(postId),
);

final postVoteCountsProvider =
    FutureProvider.family<({int up, int down}), String>(
  (ref, postId) => PostVotesRepository.counts(postId),
);

final postVoteScoreProvider = FutureProvider.family<int, String>(
  (ref, postId) => PostVotesRepository.totalScore(postId),
);
