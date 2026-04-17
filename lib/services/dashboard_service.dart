import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardService {
  final SupabaseClient _client;

  DashboardService(this._client);

  Future<Map<String, dynamic>> getDashboardData(String userId, {double? lat, double? lng}) async {
    final results = await Future.wait([
      _getRecentPosts(),
      _getUserStats(userId),
      _getUnreadMessages(userId),
      _getCommunityPulse(),
      _getTrustScore(userId),
    ]);

    return {
      'recent_posts': results[0],
      'user_stats': results[1],
      'unread_messages': results[2],
      'community_pulse': results[3],
      'trust_score': results[4],
    };
  }

  Future<List<Map<String, dynamic>>> _getRecentPosts() async {
    try {
      final data = await _client
          .from('posts')
          .select('*, profiles(name, avatar_url)')
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(10);
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> _getUserStats(String userId) async {
    try {
      final posts = await _client.from('posts').select('id').eq('user_id', userId);
      final interactions = await _client.from('interactions').select('id').eq('helper_id', userId).eq('status', 'completed');
      final saved = await _client.from('saved_posts').select('id').eq('user_id', userId);

      return {
        'posts_count': (posts as List).length,
        'interactions_count': (interactions as List).length,
        'saved_count': (saved as List).length,
      };
    } catch (_) {
      return {'posts_count': 0, 'interactions_count': 0, 'saved_count': 0};
    }
  }

  Future<int> _getUnreadMessages(String userId) async {
    try {
      final data = await _client
          .from('v_unread_counts')
          .select('unread_count')
          .eq('user_id', userId);
      int total = 0;
      for (final row in data) total += (row['unread_count'] as int? ?? 0);
      return total;
    } catch (_) {
      return 0;
    }
  }

  Future<Map<String, dynamic>> _getCommunityPulse() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
      final weekStart = DateTime(now.year, now.month, now.day - now.weekday + 1).toIso8601String();

      final newPosts = await _client.from('posts').select('id').eq('status', 'active').gte('created_at', todayStart);
      final weekInteractions = await _client.from('interactions').select('id').gte('created_at', weekStart);

      return {
        'active_users': 0,
        'new_posts': (newPosts as List).length,
        'interactions_week': (weekInteractions as List).length,
      };
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, dynamic>> _getTrustScore(String userId) async {
    try {
      final ratings = await _client.from('trust_ratings').select('score').eq('rated_id', userId);
      if ((ratings as List).isEmpty) return {'average': 0.0, 'count': 0};
      final scores = ratings.map((r) => r['score'] as int).toList();
      return {
        'average': scores.reduce((a, b) => a + b) / scores.length,
        'count': scores.length,
      };
    } catch (_) {
      return {'average': 0.0, 'count': 0};
    }
  }
}
