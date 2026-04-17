import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardService {
  final SupabaseClient _client;

  DashboardService(this._client);

  Future<Map<String, dynamic>> getDashboardData(String userId, {double? lat, double? lng}) async {
    final results = await Future.wait([
      _getNearbyPosts(lat, lng),         // 0
      _getRecentActivity(userId),         // 1
      _getUserStats(userId),              // 2
      _getUnreadMessages(userId),         // 3
      _getCommunityPulse(),               // 4
      _getTrustScore(userId),             // 5
      _getBotTip(),                       // 6
      _getOnboardingProgress(userId),     // 7
    ]);

    return {
      'recent_posts': results[0],
      'recent_activity': results[1],
      'user_stats': results[2],
      'unread_messages': results[3],
      'community_pulse': results[4],
      'trust_score': results[5],
      'bot_tip': results[6],
      'onboarding': results[7],
    };
  }

  // 1. Nearby Posts (RPC with fallback)
  Future<List<Map<String, dynamic>>> _getNearbyPosts(double? lat, double? lng) async {
    try {
      if (lat != null && lng != null) {
        final data = await _client.rpc('get_nearby_posts', params: {
          'p_lat': lat, 'p_lng': lng, 'p_radius_km': 50, 'p_limit': 10,
        });
        return List<Map<String, dynamic>>.from(data as List);
      }
    } catch (_) {}
    try {
      final data = await _client.from('posts')
          .select('*, profiles(name, avatar_url)')
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(10);
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      return [];
    }
  }

  // 2. Recent Activity (posts + interactions + ratings from last 14 days)
  Future<List<Map<String, dynamic>>> _getRecentActivity(String userId) async {
    final activities = <Map<String, dynamic>>[];
    final since = DateTime.now().subtract(const Duration(days: 14)).toIso8601String();
    try {
      final posts = await _client.from('posts')
          .select('id, title, type, created_at, user_id, profiles(name, avatar_url)')
          .eq('user_id', userId)
          .gte('created_at', since)
          .order('created_at', ascending: false)
          .limit(5);
      for (final p in posts as List) {
        activities.add({'type': 'new_post', 'title': 'Beitrag erstellt', 'description': p['title'] ?? '', 'timestamp': p['created_at'], 'icon': 'file_text', 'color': '#1EAAA6'});
      }
    } catch (_) {}
    try {
      final interactions = await _client.from('interactions')
          .select('id, status, created_at, post_id, helper_id, posts(title)')
          .or('helper_id.eq.$userId,helped_id.eq.$userId')
          .eq('status', 'completed')
          .gte('created_at', since)
          .order('created_at', ascending: false)
          .limit(5);
      for (final i in interactions as List) {
        final postTitle = (i['posts'] is Map) ? i['posts']['title'] : 'Interaktion';
        activities.add({'type': 'interaction_completed', 'title': 'Interaktion abgeschlossen', 'description': postTitle ?? '', 'timestamp': i['created_at'], 'icon': 'handshake', 'color': '#8B5CF6'});
      }
    } catch (_) {}
    try {
      final ratings = await _client.from('trust_ratings')
          .select('id, rating, comment, created_at, rater_id, profiles!trust_ratings_rater_id_fkey(name, avatar_url)')
          .eq('rated_id', userId)
          .gte('created_at', since)
          .order('created_at', ascending: false)
          .limit(5);
      for (final r in ratings as List) {
        final raterName = (r['profiles'] is Map) ? r['profiles']['name'] : 'Jemand';
        activities.add({'type': 'trust_rating', 'title': 'Neue Bewertung', 'description': '$raterName hat dich bewertet', 'timestamp': r['created_at'], 'icon': 'star', 'color': '#F59E0B'});
      }
    } catch (_) {}
    activities.sort((a, b) => (b['timestamp'] as String? ?? '').compareTo(a['timestamp'] as String? ?? ''));
    return activities.take(10).toList();
  }

  // 3. User Stats (5 parallel counts)
  Future<Map<String, dynamic>> _getUserStats(String userId) async {
    try {
      final results = await Future.wait([
        _client.from('posts').select('id').eq('user_id', userId).eq('status', 'active'),
        _client.from('interactions').select('id').or('helper_id.eq.$userId,helped_id.eq.$userId').eq('status', 'completed'),
        _client.from('interactions').select('post_id').eq('helper_id', userId).eq('status', 'completed'),
        _client.from('trust_ratings').select('rating').eq('rated_id', userId),
        _client.from('saved_posts').select('id').eq('user_id', userId),
      ]);
      final ratings = results[3] as List;
      final avgRating = ratings.isNotEmpty ? ratings.map((r) => r['rating'] as int).reduce((a, b) => a + b) / ratings.length : 0.0;
      final uniqueHelped = (results[2] as List).map((e) => e['post_id']).toSet().length;
      return {
        'posts_count': (results[0] as List).length,
        'interactions_count': (results[1] as List).length,
        'people_helped': uniqueHelped,
        'trust_rating_avg': avgRating,
        'saved_count': (results[4] as List).length,
      };
    } catch (_) {
      return {'posts_count': 0, 'interactions_count': 0, 'people_helped': 0, 'trust_rating_avg': 0.0, 'saved_count': 0};
    }
  }

  // 4. Unread Messages
  Future<int> _getUnreadMessages(String userId) async {
    try {
      final data = await _client.from('v_unread_counts').select('*').eq('user_id', userId);
      int total = 0;
      for (final row in data as List) {
        total += (row['unread_count'] as int? ?? 0);
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  // 5. Community Pulse
  Future<Map<String, dynamic>> _getCommunityPulse() async {
    try {
      final data = await _client.rpc('get_community_pulse');
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (_) {}
    try {
      final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).toIso8601String();
      final weekStart = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1)).toIso8601String();
      final newPosts = await _client.from('posts').select('id').eq('status', 'active').gte('created_at', todayStart);
      final weekInteractions = await _client.from('interactions').select('id').gte('created_at', weekStart);
      return {'active_users': 0, 'new_posts': (newPosts as List).length, 'interactions_week': (weekInteractions as List).length};
    } catch (_) {
      return {'active_users': 0, 'new_posts': 0, 'interactions_week': 0};
    }
  }

  // 6. Trust Score with Trend
  Future<Map<String, dynamic>> _getTrustScore(String userId) async {
    try {
      final data = await _client.from('trust_ratings').select('rating, created_at').eq('rated_id', userId).order('created_at', ascending: false);
      final ratings = data as List;
      if (ratings.isEmpty) return {'average': 0.0, 'count': 0, 'trend': 'stable'};
      final scores = ratings.map((r) => r['rating'] as int).toList();
      final avg = scores.reduce((a, b) => a + b) / scores.length;
      String trend = 'stable';
      if (scores.length >= 3) {
        final recent = scores.take(3).reduce((a, b) => a + b) / 3;
        final older = scores.skip(3).take(3).toList();
        if (older.isNotEmpty) {
          final olderAvg = older.reduce((a, b) => a + b) / older.length;
          trend = recent > olderAvg ? 'up' : recent < olderAvg ? 'down' : 'stable';
        }
      }
      return {'average': avg, 'count': scores.length, 'trend': trend};
    } catch (_) {
      return {'average': 0.0, 'count': 0, 'trend': 'stable'};
    }
  }

  // 7. Bot Tip
  Future<String?> _getBotTip() async {
    try {
      final data = await _client.from('bot_scheduled_messages')
          .select('content')
          .eq('status', 'pending')
          .eq('message_type', 'daily_tip')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return data?['content'] as String?;
    } catch (_) {
      return null;
    }
  }

  // 8. Onboarding Progress
  Future<Map<String, dynamic>> _getOnboardingProgress(String userId) async {
    try {
      final results = await Future.wait([
        _client.from('messages').select('id').eq('sender_id', userId).limit(1),
        _client.from('trust_ratings').select('id').eq('rater_id', userId).limit(1),
      ]);
      return {
        'has_sent_message': (results[0] as List).isNotEmpty,
        'has_given_rating': (results[1] as List).isNotEmpty,
      };
    } catch (_) {
      return {'has_sent_message': false, 'has_given_rating': false};
    }
  }
}
