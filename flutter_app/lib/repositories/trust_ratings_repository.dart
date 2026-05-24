import '../services/supabase_service.dart';

/// SKILL: supabase + mensaena-features
/// Trust-Ratings — Bewertung nach abgeschlossener Interaktion.
/// 1:1 zu Web RatingModal.tsx + calculate_trust_score RPC.
class TrustRatingsRepository {
  const TrustRatingsRepository._();

  /// Submits a new trust rating after a completed interaction.
  /// Triggers recalculation of trust_score on the rated user.
  static Future<bool> rate({
    required String ratedUserId,
    required int score, // 1-5
    String? comment,
    String? interactionId,
    List<String> categories = const [],
    bool helpful = true,
    bool wouldRecommend = true,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null || uid == ratedUserId) return false;
    if (score < 1 || score > 5) return false;
    try {
      await sb.from('trust_ratings').insert({
        'rater_id': uid,
        'rated_id': ratedUserId,
        'score': score,
        if (comment != null && comment.trim().isNotEmpty)
          'comment': comment.trim(),
        if (interactionId != null) 'interaction_id': interactionId,
        if (categories.isNotEmpty) 'categories': categories,
        'helpful': helpful,
        'would_recommend': wouldRecommend,
      });
      // Trigger recalculation (RLS allows users to recalc their own rated).
      try {
        await sb.rpc<dynamic>('calculate_trust_score',
            params: {'uid': ratedUserId});
      } catch (_) {
        // Fail-silent: trigger on DB-side will recalc eventually.
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Lookup my pending interactions where the partner has not been rated yet.
  /// Used by the post-interaction prompt and the rating-prompt-banner.
  static Future<List<Map<String, dynamic>>> myPendingToRate() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const [];
    try {
      // 1) All my completed interactions
      final inters = await sb
          .from('interactions')
          .select(
              'id, post_id, helper_id, posts!inner(user_id, title), profiles!interactions_helper_id_fkey(id, name, display_name, avatar_url)')
          .eq('status', 'completed')
          .or('helper_id.eq.$uid,posts.user_id.eq.$uid')
          .limit(20);
      final list =
          (inters as List).whereType<Map<String, dynamic>>().toList();
      if (list.isEmpty) return const [];
      // 2) Filter out those where I already rated the partner.
      final ratings = await sb
          .from('trust_ratings')
          .select('rated_id, interaction_id')
          .eq('rater_id', uid);
      final ratedKeys = (ratings as List)
          .whereType<Map<String, dynamic>>()
          .map((r) => '${r['rated_id']}_${r['interaction_id']}')
          .toSet();
      return list.where((i) {
        // Partner is whoever isn't me in this interaction.
        final helperId = i['helper_id'] as String?;
        final post = i['posts'] as Map<String, dynamic>?;
        final postOwnerId = post?['user_id'] as String?;
        final partnerId =
            helperId == uid ? postOwnerId : helperId;
        if (partnerId == null) return false;
        return !ratedKeys.contains('${partnerId}_${i['id']}');
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Ratings I have given (newest first). Joins profiles for rated user.
  static Future<List<Map<String, dynamic>>> getGiven({int limit = 50}) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const [];
    try {
      final res = await sb
          .from('trust_ratings')
          .select(
              'id, score, comment, categories, helpful, would_recommend, created_at, rated_id, profiles!trust_ratings_rated_id_fkey(id, name, display_name, avatar_url)')
          .eq('rater_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);
      return (res as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// Ratings I have received (newest first). Joins profiles for rater.
  static Future<List<Map<String, dynamic>>> getReceived(
      {int limit = 50}) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const [];
    try {
      final res = await sb
          .from('trust_ratings')
          .select(
              'id, score, comment, categories, helpful, would_recommend, created_at, rater_id, profiles!trust_ratings_rater_id_fkey(id, name, display_name, avatar_url)')
          .eq('rated_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);
      return (res as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// Trust-Score-Breakdown for a user (calls get_trust_breakdown RPC).
  static Future<Map<String, dynamic>?> getBreakdown(String userId) async {
    try {
      final res = await sb.rpc<dynamic>('get_trust_breakdown',
          params: {'uid': userId});
      if (res is Map) return Map<String, dynamic>.from(res);
      if (res is List && res.isNotEmpty && res.first is Map) {
        return Map<String, dynamic>.from(res.first as Map);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
