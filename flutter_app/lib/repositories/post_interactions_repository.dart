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

  static Future<void> toggle(String postId) async {
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
      await sb.from('content_reports').insert({
        'reporter_id': uid,
        'content_type': contentType,
        'content_id': contentId,
        'reason': reason,
        'details': details,
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

  /// Helfen-Button: legt eine Interaction an.
  static Future<bool> offerHelp({
    required String postId,
    String? message,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('interactions').insert({
        'post_id': postId,
        'helper_id': uid,
        'status': 'pending',
        'message': message,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}
