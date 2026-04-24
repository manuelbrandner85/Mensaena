import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mensaena/models/user_profile.dart';

class ProfileService {
  final SupabaseClient _client;

  ProfileService(this._client);

  Future<UserProfile?> getProfile(String userId) async {
    final data = await _client
        .from('profiles')
        .select('*')
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return UserProfile.fromJson(data);
  }

  Future<UserProfile?> getMyProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    return getProfile(userId);
  }

  Future<void> updateProfile(String userId, Map<String, dynamic> data) async {
    await _client.from('profiles').update(data).eq('id', userId);
  }

  Future<String?> uploadAvatar(String userId, Uint8List bytes, String ext) async {
    final path = '$userId/avatar.$ext';
    await _client.storage.from('avatars').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(upsert: true),
    );
    final url = _client.storage.from('avatars').getPublicUrl(path);
    await updateProfile(userId, {'avatar_url': url});
    return url;
  }

  Future<List<UserProfile>> searchUsers(String query) async {
    final data = await _client
        .from('profiles')
        .select()
        .or('name.ilike.%$query%,nickname.ilike.%$query%')
        .limit(20);
    return (data as List).map((e) => UserProfile.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> getProfileStats(String userId) async {
    final posts = await _client
        .from('posts')
        .select('id')
        .eq('user_id', userId)
        .eq('status', 'active');

    final interactions = await _client
        .from('interactions')
        .select('id')
        .eq('helper_id', userId)
        .eq('status', 'completed');

    final ratings = await _client
        .from('trust_ratings')
        .select('rating')
        .eq('rated_id', userId);

    double avgRating = 0;
    if ((ratings as List).isNotEmpty) {
      final sum = ratings.fold<int>(0, (s, r) => s + (r['rating'] as int));
      avgRating = sum / ratings.length;
    }

    // Timebank hours given
    double hoursGiven = 0;
    try {
      final givenEntries = await _client
          .from('timebank_entries')
          .select('hours')
          .eq('giver_id', userId)
          .eq('status', 'confirmed');
      for (final row in (givenEntries as List)) {
        hoursGiven += (row['hours'] as num).toDouble();
      }
    } catch (_) {}

    // Timebank hours received
    double hoursReceived = 0;
    try {
      final receivedEntries = await _client
          .from('timebank_entries')
          .select('hours')
          .eq('receiver_id', userId)
          .eq('status', 'confirmed');
      for (final row in (receivedEntries as List)) {
        hoursReceived += (row['hours'] as num).toDouble();
      }
    } catch (_) {}

    // Groups count
    int groupsCount = 0;
    try {
      final groups = await _client
          .from('group_members')
          .select('id')
          .eq('user_id', userId);
      groupsCount = (groups as List).length;
    } catch (_) {}

    // Challenges count
    int challengesCount = 0;
    try {
      final challenges = await _client
          .from('challenge_progress')
          .select('challenge_id')
          .eq('user_id', userId);
      // Unique challenges
      final uniqueIds = (challenges as List)
          .map((e) => e['challenge_id'])
          .toSet();
      challengesCount = uniqueIds.length;
    } catch (_) {}

    return {
      'posts_count': (posts as List).length,
      'interactions_count': (interactions as List).length,
      'ratings_count': ratings.length,
      'average_rating': avgRating,
      'hours_given': hoursGiven,
      'hours_received': hoursReceived,
      'groups_count': groupsCount,
      'challenges_count': challengesCount,
    };
  }

  // User Blocking
  Future<void> blockUser(String blockerId, String blockedId) async {
    await _client.from('user_blocks').insert({
      'blocker_id': blockerId,
      'blocked_id': blockedId,
    });
  }

  Future<void> unblockUser(String blockerId, String blockedId) async {
    await _client
        .from('user_blocks')
        .delete()
        .eq('blocker_id', blockerId)
        .eq('blocked_id', blockedId);
  }

  Future<bool> isBlocked(String blockerId, String blockedId) async {
    final data = await _client
        .from('user_blocks')
        .select('id')
        .eq('blocker_id', blockerId)
        .eq('blocked_id', blockedId)
        .maybeSingle();
    return data != null;
  }

  Future<List<Map<String, dynamic>>> getBlockedUsers(String userId) async {
    final data = await _client
        .from('user_blocks')
        .select('*')
        .eq('blocker_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  /// Fetches recent activity items for the profile activity feed.
  Future<List<Map<String, dynamic>>> getRecentActivity(String userId) async {
    final List<Map<String, dynamic>> activities = [];

    // Recent timebank entries
    try {
      final tbEntries = await _client
          .from('timebank_entries')
          .select('id, hours, description, status, created_at, giver_id, receiver_id')
          .or('giver_id.eq.$userId,receiver_id.eq.$userId')
          .order('created_at', ascending: false)
          .limit(5);
      for (final e in (tbEntries as List)) {
        final isGiver = e['giver_id'] == userId;
        activities.add({
          'type': 'timebank',
          'title': isGiver ? 'Stunden gegeben' : 'Stunden erhalten',
          'description': '${e['hours']}h${e['description'] != null ? ' - ${e['description']}' : ''}',
          'created_at': e['created_at'],
          'icon': 'clock',
        });
      }
    } catch (_) {}

    // Recent group memberships
    try {
      final groupJoins = await _client
          .from('group_members')
          .select('id, joined_at, groups(name)')
          .eq('user_id', userId)
          .order('joined_at', ascending: false)
          .limit(5);
      for (final e in (groupJoins as List)) {
        final groupName = e['groups']?['name'] ?? 'Gruppe';
        activities.add({
          'type': 'group',
          'title': 'Gruppe beigetreten',
          'description': groupName,
          'created_at': e['joined_at'],
          'icon': 'users',
        });
      }
    } catch (_) {}

    // Recent challenge participations
    try {
      final challengeProgress = await _client
          .from('challenge_progress')
          .select('id, date, challenges(title)')
          .eq('user_id', userId)
          .order('date', ascending: false)
          .limit(5);
      for (final e in (challengeProgress as List)) {
        final challengeTitle = e['challenges']?['title'] ?? 'Challenge';
        activities.add({
          'type': 'challenge',
          'title': 'Challenge-Teilnahme',
          'description': challengeTitle,
          'created_at': e['date'],
          'icon': 'trophy',
        });
      }
    } catch (_) {}

    // Recent posts
    try {
      final posts = await _client
          .from('posts')
          .select('id, title, created_at')
          .eq('user_id', userId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(5);
      for (final e in (posts as List)) {
        activities.add({
          'type': 'post',
          'title': 'Beitrag erstellt',
          'description': e['title'] ?? 'Neuer Beitrag',
          'created_at': e['created_at'],
          'icon': 'file_text',
        });
      }
    } catch (_) {}

    // Sort all by date descending
    activities.sort((a, b) {
      final dateA = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(2000);
      final dateB = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(2000);
      return dateB.compareTo(dateA);
    });

    return activities.take(15).toList();
  }
}
