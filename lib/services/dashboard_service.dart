import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardService {
  final SupabaseClient _client;

  DashboardService(this._client);

  Future<Map<String, dynamic>> getDashboardData(String userId, {double? lat, double? lng}) async {
    // Use server-side RPC for core data (single round-trip), supplement with extra queries
    final results = await Future.wait([
      _getRpcDashboard(userId),              // 0 — profile, stats, posts, DMs
      _getRecentActivity(userId),            // 1
      _getCommunityPulse(),                  // 2
      _getTrustScore(userId),                // 3
      _getBotTip(),                          // 4
      _getOnboardingProgress(userId),        // 5
      _getWeeklyChallenge(),                 // 6
    ]);

    final rpc = results[0] as Map<String, dynamic>;
    final rpcStats = rpc['stats'] as Map<String, dynamic>? ?? {};

    // Merge RPC stats with supplementary data
    final userStats = <String, dynamic>{
      'posts_count': rpcStats['my_posts'] ?? 0,
      'saved_count': rpcStats['saved_count'] ?? 0,
      'active_posts_total': rpcStats['active_posts'] ?? 0,
      'notification_count': rpcStats['notification_count'] ?? 0,
      ...await _getExtendedUserStats(userId),
    };

    // Combine recent_posts from RPC (urgent + help_requests + help_offers)
    final recentPosts = <Map<String, dynamic>>[
      ...List<Map<String, dynamic>>.from(rpc['urgent_posts'] as List? ?? []),
      ...List<Map<String, dynamic>>.from(rpc['help_requests'] as List? ?? []),
      ...List<Map<String, dynamic>>.from(rpc['help_offers'] as List? ?? []),
    ];
    // Deduplicate by id
    final seen = <String>{};
    recentPosts.retainWhere((p) => seen.add(p['id'] as String? ?? ''));

    return {
      'recent_posts': recentPosts,
      'recent_activity': results[1],
      'user_stats': userStats,
      'unread_messages': rpc['dm_count'] ?? 0,
      'community_pulse': results[2],
      'trust_score': results[3],
      'bot_tip': results[4],
      'onboarding': results[5],
      'weekly_challenge': results[6],
      'saved_ids': rpc['saved_ids'] ?? [],
      'crisis_count': rpc['crisis_count'] ?? 0,
      'recent_dms': rpc['recent_dms'] ?? [],
    };
  }

  // Core dashboard data via server-side RPC (single round-trip)
  Future<Map<String, dynamic>> _getRpcDashboard(String userId) async {
    try {
      final data = await _client.rpc('get_dashboard_data', params: {
        'p_user_id': userId,
      });
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (_) {}
    // Fallback: manual queries
    return _getFallbackDashboard(userId);
  }

  Future<Map<String, dynamic>> _getFallbackDashboard(String userId) async {
    try {
      final posts = await _client.from('posts')
          .select('*, profiles(name, avatar_url)')
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(10);
      final unread = await _client.from('v_unread_counts').select('*').eq('user_id', userId);
      int dmCount = 0;
      for (final row in unread as List) {
        dmCount += (row['unread_count'] as int? ?? 0);
      }
      return {
        'stats': {'active_posts': 0, 'my_posts': 0, 'saved_count': 0, 'notification_count': 0},
        'urgent_posts': <Map<String, dynamic>>[],
        'help_requests': <Map<String, dynamic>>[],
        'help_offers': List<Map<String, dynamic>>.from(posts),
        'saved_ids': <String>[],
        'crisis_count': 0,
        'dm_count': dmCount,
        'recent_dms': <Map<String, dynamic>>[],
      };
    } catch (_) {
      return {
        'stats': {'active_posts': 0, 'my_posts': 0, 'saved_count': 0, 'notification_count': 0},
        'urgent_posts': [], 'help_requests': [], 'help_offers': [],
        'saved_ids': [], 'crisis_count': 0, 'dm_count': 0, 'recent_dms': [],
      };
    }
  }

  // Extended user stats (interactions, trust, member-since)
  Future<Map<String, dynamic>> _getExtendedUserStats(String userId) async {
    try {
      final results = await Future.wait<dynamic>([
        _client.from('interactions').select('id').or('helper_id.eq.$userId,helped_id.eq.$userId').eq('status', 'completed'),
        _client.from('interactions').select('post_id').eq('helper_id', userId).eq('status', 'completed'),
        _client.from('trust_ratings').select('rating').eq('rated_id', userId),
        _client.from('profiles').select('created_at').eq('id', userId).maybeSingle(),
      ]);
      final ratings = results[2] as List;
      final avgRating = ratings.isNotEmpty
          ? ratings.map((r) => r['rating'] as int).reduce((a, b) => a + b) / ratings.length
          : 0.0;
      final uniqueHelped = (results[1] as List).map((e) => e['post_id']).toSet().length;
      final profileData = results[3] as Map<String, dynamic>?;
      int memberSinceDays = 0;
      if (profileData != null && profileData['created_at'] != null) {
        memberSinceDays = DateTime.now().difference(DateTime.parse(profileData['created_at'] as String)).inDays;
      }
      return {
        'interactions_count': (results[0] as List).length,
        'people_helped': uniqueHelped,
        'trust_rating_avg': avgRating,
        'member_since_days': memberSinceDays,
      };
    } catch (_) {
      return {'interactions_count': 0, 'people_helped': 0, 'trust_rating_avg': 0.0, 'member_since_days': 0};
    }
  }

  // Recent Activity (posts + interactions + ratings from last 14 days)
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
          .select('id, status, created_at, post_id, helper_id, posts(title, user_id)')
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
          .select('id, score, comment, created_at, rater_id, profiles!trust_ratings_rater_id_fkey(name, avatar_url)')
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

  // Community Pulse (direct queries, no non-existent RPC)
  Future<Map<String, dynamic>> _getCommunityPulse() async {
    try {
      final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).toIso8601String();
      final weekStart = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1)).toIso8601String();
      final results = await Future.wait([
        _client.from('posts').select('id').eq('status', 'active').gte('created_at', todayStart),
        _client.from('interactions').select('id').gte('created_at', weekStart),
        _client.from('posts').select('id').eq('status', 'active'),
      ]);
      return {
        'active_users': 0,
        'new_posts': (results[0] as List).length,
        'interactions_week': (results[1] as List).length,
        'total_active_posts': (results[2] as List).length,
      };
    } catch (_) {
      return {'active_users': 0, 'new_posts': 0, 'interactions_week': 0, 'total_active_posts': 0};
    }
  }

  // Trust Score with Trend
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

  // Bot Tip
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

  // Onboarding Progress
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

  // Weekly Challenge
  Future<Map<String, dynamic>?> _getWeeklyChallenge() async {
    try {
      return await _client.from('challenges').select('*')
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }
}
