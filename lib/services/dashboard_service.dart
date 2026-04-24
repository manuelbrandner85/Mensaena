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
      _getNinaWarnings(),                    // 7
      _getWeeklyDigest(userId),              // 8
      _getThanksReceived(userId),            // 9
      _getSuccessStory(),                    // 10
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

    // Merge newest_neighbor_name into community_pulse
    final communityPulse = results[2] as Map<String, dynamic>;
    final newestNeighborName = await _getNewestNeighborName();
    communityPulse['newest_neighbor_name'] = newestNeighborName;

    return {
      'recent_posts': recentPosts,
      'recent_activity': results[1],
      'user_stats': userStats,
      'unread_messages': rpc['dm_count'] ?? 0,
      'community_pulse': communityPulse,
      'trust_score': results[3],
      'bot_tip': results[4],
      'onboarding': results[5],
      'weekly_challenge': results[6],
      'saved_ids': rpc['saved_ids'] ?? [],
      'crisis_count': rpc['crisis_count'] ?? 0,
      'recent_dms': rpc['recent_dms'] ?? [],
      'nina_warnings': results[7],
      'weekly_digest': results[8],
      'thanks_received': results[9],
      'success_story': results[10],
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

  // Recent Activity (matches Web useDashboard.ts: posts 7d, interactions+ratings 14d)
  Future<List<Map<String, dynamic>>> _getRecentActivity(String userId) async {
    final activities = <Map<String, dynamic>>[];
    final since7d = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
    final since14d = DateTime.now().subtract(const Duration(days: 14)).toIso8601String();
    try {
      final posts = await _client.from('posts')
          .select('id, title, type, created_at, user_id, profiles(name, avatar_url)')
          .eq('user_id', userId)
          .gte('created_at', since7d)
          .order('created_at', ascending: false)
          .limit(10);
      for (final p in posts as List) {
        final pType = p['type'] as String? ?? '';
        final isCrisis = pType == 'crisis';
        activities.add({
          'type': isCrisis ? 'crisis_alert' : 'new_post',
          'title': isCrisis ? 'Krisenmeldung erstellt' : 'Beitrag erstellt',
          'description': p['title'] ?? '',
          'timestamp': p['created_at'],
          'icon': isCrisis ? 'alert_triangle' : 'file_text',
          'color': isCrisis ? '#DC2626' : '#1EAAA6',
          'linkTo': '/dashboard/posts/${p['id']}',
        });
      }
    } catch (_) {}
    try {
      final interactions = await _client.from('interactions')
          .select('id, status, created_at, post_id, helper_id, posts(title)')
          .or('helper_id.eq.$userId')
          .eq('status', 'completed')
          .gte('created_at', since14d)
          .order('created_at', ascending: false)
          .limit(10);
      for (final i in interactions as List) {
        final postTitle = (i['posts'] is Map) ? i['posts']['title'] : 'Interaktion';
        activities.add({
          'type': 'interaction_completed',
          'title': 'Interaktion abgeschlossen',
          'description': postTitle ?? '',
          'timestamp': i['created_at'],
          'icon': 'handshake',
          'color': '#8B5CF6',
          'linkTo': '/dashboard/interactions',
        });
      }
    } catch (_) {}
    try {
      final ratings = await _client.from('trust_ratings')
          .select('id, rating, comment, created_at, rater_id, profiles!trust_ratings_rater_id_fkey(name, avatar_url)')
          .eq('rated_id', userId)
          .gte('created_at', since14d)
          .order('created_at', ascending: false)
          .limit(5);
      for (final r in ratings as List) {
        final raterName = (r['profiles'] is Map) ? r['profiles']['name'] : 'Jemand';
        final ratingVal = r['rating'] as int? ?? 0;
        activities.add({
          'type': 'trust_rating',
          'title': 'Neue Bewertung',
          'description': '$raterName hat dich mit $ratingVal/5 bewertet',
          'timestamp': r['created_at'],
          'icon': 'star',
          'color': '#F59E0B',
          'linkTo': '/dashboard/profile',
        });
      }
    } catch (_) {}
    activities.sort((a, b) => (b['timestamp'] as String? ?? '').compareTo(a['timestamp'] as String? ?? ''));
    return activities.take(15).toList();
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

  // Trust Score with Trend (matches Web useDashboard.ts: 30-day windows)
  Future<Map<String, dynamic>> _getTrustScore(String userId) async {
    try {
      final data = await _client.from('trust_ratings').select('rating, created_at').eq('rated_id', userId).order('created_at', ascending: false);
      final ratings = data as List;
      if (ratings.isEmpty) return {'average': 0.0, 'count': 0, 'trend': 'stable'};
      final scores = ratings.map((r) => r['rating'] as int).toList();
      final avg = scores.reduce((a, b) => a + b) / scores.length;
      String trend = 'stable';
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      final sixtyDaysAgo = now.subtract(const Duration(days: 60));
      final recentScores = <int>[];
      final olderScores = <int>[];
      for (final r in ratings) {
        final date = DateTime.parse(r['created_at'] as String);
        final rating = r['rating'] as int;
        if (date.isAfter(thirtyDaysAgo)) {
          recentScores.add(rating);
        } else if (date.isAfter(sixtyDaysAgo)) {
          olderScores.add(rating);
        }
      }
      if (recentScores.isNotEmpty && olderScores.isNotEmpty) {
        final recentAvg = recentScores.reduce((a, b) => a + b) / recentScores.length;
        final olderAvg = olderScores.reduce((a, b) => a + b) / olderScores.length;
        if (recentAvg > olderAvg + 0.1) {
          trend = 'up';
        } else if (recentAvg < olderAvg - 0.1) {
          trend = 'down';
        }
      }
      return {'average': (avg * 10).round() / 10.0, 'count': scores.length, 'trend': trend};
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

  // NINA Warnings (civil protection alerts)
  Future<List<Map<String, dynamic>>> _getNinaWarnings() async {
    try {
      final data = await _client.from('nina_warnings')
          .select('*')
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(10);
      return List<Map<String, dynamic>>.from(data as List);
    } catch (_) {
      // Table may not exist in all environments
      return [];
    }
  }

  // Weekly Digest for current user
  Future<Map<String, dynamic>?> _getWeeklyDigest(String userId) async {
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartStr = DateTime(weekStart.year, weekStart.month, weekStart.day).toIso8601String();
      final data = await _client.from('weekly_digests')
          .select('*')
          .eq('user_id', userId)
          .gte('created_at', weekStartStr)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return data;
    } catch (_) {
      // Table may not exist in all environments
      return null;
    }
  }

  // Thanks received by user (count + recent entries with sender info)
  Future<Map<String, dynamic>> _getThanksReceived(String userId) async {
    try {
      final results = await Future.wait([
        _client.from('thanks')
            .select('id')
            .eq('to_user_id', userId),
        _client.from('thanks')
            .select('from_user_id, emoji, message, created_at, profiles!thanks_from_user_id_fkey(name)')
            .eq('to_user_id', userId)
            .order('created_at', ascending: false)
            .limit(3),
      ]);
      final allThanks = results[0] as List;
      final recentThanks = results[1] as List;
      final recent = recentThanks.map((t) {
        final senderName = (t['profiles'] is Map) ? t['profiles']['name'] : null;
        return {
          'from_user_id': t['from_user_id'],
          'sender_name': senderName ?? 'Unbekannt',
          'emoji': t['emoji'],
          'message': t['message'],
          'created_at': t['created_at'],
        };
      }).toList();
      return {
        'count': allThanks.length,
        'recent': recent,
      };
    } catch (_) {
      // Table may not exist in all environments
      return {'count': 0, 'recent': []};
    }
  }

  // Random approved success story
  Future<Map<String, dynamic>?> _getSuccessStory() async {
    try {
      final data = await _client.from('success_stories')
          .select('*')
          .eq('is_approved', true);
      final stories = List<Map<String, dynamic>>.from(data as List);
      if (stories.isEmpty) return null;
      stories.shuffle();
      return stories.first;
    } catch (_) {
      // Table may not exist in all environments
      return null;
    }
  }

  // Newest neighbor name for community pulse
  Future<String?> _getNewestNeighborName() async {
    try {
      final data = await _client.from('profiles')
          .select('name')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return data?['name'] as String?;
    } catch (_) {
      return null;
    }
  }
}
