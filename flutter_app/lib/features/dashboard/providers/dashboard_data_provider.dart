// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, require_trailing_commas
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/user_provider.dart';
import '../../../services/supabase/supabase_service.dart';

/// Komplettes Dashboard-Datenmodell — 1:1 zu useDashboard im Web.
class DashboardData {
  final Map<String, dynamic>? profile;
  final List<Map<String, dynamic>> nearbyPosts;
  final List<Map<String, dynamic>> recentActivity;
  final DashboardStats stats;
  final List<Map<String, dynamic>> unreadMessages;
  final int activeCrises;
  final int totalNeighbors;
  final double trustScore;
  final int memberSinceDays;
  final OnboardingProgress onboardingProgress;

  const DashboardData({
    this.profile,
    this.nearbyPosts = const [],
    this.recentActivity = const [],
    required this.stats,
    this.unreadMessages = const [],
    this.activeCrises = 0,
    this.totalNeighbors = 0,
    this.trustScore = 0,
    this.memberSinceDays = 0,
    required this.onboardingProgress,
  });
}

class DashboardStats {
  final int activeNeighbors;
  final int helpOffers;
  final int interactions;
  final int regions;
  final int hoursGiven;
  final int hoursReceived;
  final int groups;
  final int challenges;
  final int memberSinceDays;

  const DashboardStats({
    this.activeNeighbors = 0,
    this.helpOffers = 0,
    this.interactions = 0,
    this.regions = 0,
    this.hoursGiven = 0,
    this.hoursReceived = 0,
    this.groups = 0,
    this.challenges = 0,
    this.memberSinceDays = 0,
  });
}

class OnboardingProgress {
  final bool completed;
  final int totalSteps;
  final int completedSteps;
  final List<String> missing;

  const OnboardingProgress({
    this.completed = false,
    this.totalSteps = 5,
    this.completedSteps = 0,
    this.missing = const [],
  });

  double get fraction =>
      totalSteps == 0 ? 1.0 : completedSteps / totalSteps;
}

/// Haupt-Provider — laedt das gesamte Dashboard parallel.
final dashboardDataProvider = FutureProvider<DashboardData>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return DashboardData(
      stats: const DashboardStats(),
      onboardingProgress: const OnboardingProgress(),
    );
  }
  final profile = ref.watch(currentProfileProvider).asData?.value;

  // Parallele Queries
  final results = await Future.wait([
    _fetchNearbyPosts(profile),
    _fetchRecentActivity(user.id),
    _fetchStats(user.id),
    _fetchUnreadMessages(user.id),
    _fetchActiveCrises(),
    _fetchTotalNeighbors(),
    _fetchTrustScore(user.id),
  ]);

  final stats = results[2] as DashboardStats;
  final memberSinceDays = profile == null
      ? 0
      : _memberSinceDays(profile['created_at'] as String?);

  return DashboardData(
    profile: profile,
    nearbyPosts: results[0] as List<Map<String, dynamic>>,
    recentActivity: results[1] as List<Map<String, dynamic>>,
    stats: DashboardStats(
      activeNeighbors: stats.activeNeighbors,
      helpOffers: stats.helpOffers,
      interactions: stats.interactions,
      regions: stats.regions,
      hoursGiven: stats.hoursGiven,
      hoursReceived: stats.hoursReceived,
      groups: stats.groups,
      challenges: stats.challenges,
      memberSinceDays: memberSinceDays,
    ),
    unreadMessages: results[3] as List<Map<String, dynamic>>,
    activeCrises: results[4] as int,
    totalNeighbors: results[5] as int,
    trustScore: results[6] as double,
    memberSinceDays: memberSinceDays,
    onboardingProgress: _calculateOnboarding(profile),
  );
});

// ── Query-Helpers ────────────────────────────────────────────────────

Future<List<Map<String, dynamic>>> _fetchNearbyPosts(
  Map<String, dynamic>? profile,
) async {
  try {
    final res = await supabase.client
        .from('posts')
        .select(
          '*, profiles!posts_user_id_fkey(id, full_name, avatar_url)',
        )
        .order('created_at', ascending: false)
        .limit(10);
    return List<Map<String, dynamic>>.from(res as List);
  } catch (_) {
    return const [];
  }
}

Future<List<Map<String, dynamic>>> _fetchRecentActivity(String userId) async {
  try {
    final res = await supabase.client
        .from('interactions')
        .select()
        .order('created_at', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(res as List);
  } catch (_) {
    return const [];
  }
}

Future<DashboardStats> _fetchStats(String userId) async {
  Future<int> countRows(
    String table, {
    Map<String, Object>? eq,
  }) async {
    try {
      dynamic q = supabase.client.from(table).select('id');
      if (eq != null) {
        for (final e in eq.entries) {
          q = q.eq(e.key, e.value);
        }
      }
      final r = await q;
      return (r as List).length;
    } catch (_) {
      return 0;
    }
  }

  final since = DateTime.now()
      .subtract(const Duration(hours: 24))
      .toIso8601String();

  final values = await Future.wait<int>([
    () async {
      try {
        final r = await supabase.client
            .from('profiles')
            .select('id')
            .gte('last_active', since);
        return (r as List).length;
      } catch (_) {
        return 0;
      }
    }(),
    countRows('posts', eq: {'type': 'hilfeAnbieten'}),
    countRows('interactions'),
    countRows('regions'),
    countRows('group_members', eq: {'user_id': userId}),
    countRows('challenge_progress', eq: {'user_id': userId}),
  ]);

  // Zeitbank-Saldo: + earned, - spent
  int earned = 0, spent = 0;
  try {
    final tb = await supabase.client
        .from('timebank_entries')
        .select('hours, type')
        .eq('user_id', userId);
    for (final r in (tb as List)) {
      final m = r as Map<String, dynamic>;
      final h = ((m['hours'] as num?) ?? 0).round();
      if (m['type'] == 'earned') {
        earned += h;
      } else {
        spent += h;
      }
    }
  } catch (_) {}

  return DashboardStats(
    activeNeighbors: values[0],
    helpOffers: values[1],
    interactions: values[2],
    regions: values[3],
    groups: values[4],
    challenges: values[5],
    hoursGiven: earned,
    hoursReceived: spent,
  );
}

Future<List<Map<String, dynamic>>> _fetchUnreadMessages(String userId) async {
  try {
    final res = await supabase.client
        .from('messages')
        .select('id, content, conversation_id, created_at, sender_id')
        .neq('sender_id', userId)
        .order('created_at', ascending: false)
        .limit(5);
    return List<Map<String, dynamic>>.from(res as List);
  } catch (_) {
    return const [];
  }
}

Future<int> _fetchActiveCrises() async {
  try {
    final res = await supabase.client.from('crisis_reports').select('id').limit(20);
    return (res as List).length;
  } catch (_) {
    return 0;
  }
}

Future<int> _fetchTotalNeighbors() async {
  try {
    final res = await supabase.client.from('profiles').select('id');
    return (res as List).length;
  } catch (_) {
    return 0;
  }
}

Future<double> _fetchTrustScore(String userId) async {
  try {
    final res = await supabase.client
        .from('trust_ratings')
        .select('rating')
        .eq('rated_user_id', userId);
    final list = res as List;
    if (list.isEmpty) return 0;
    final sum = list.fold<num>(
      0,
      (acc, r) => acc + (((r as Map)['rating'] as num?) ?? 0),
    );
    return (sum / list.length).toDouble();
  } catch (_) {
    return 0;
  }
}

int _memberSinceDays(String? iso) {
  if (iso == null) return 0;
  final created = DateTime.tryParse(iso);
  if (created == null) return 0;
  return DateTime.now().difference(created).inDays;
}

OnboardingProgress _calculateOnboarding(Map<String, dynamic>? p) {
  if (p == null) return const OnboardingProgress();
  final hasAvatar = (p['avatar_url'] as String?)?.isNotEmpty == true;
  final hasBio = (p['bio'] as String?)?.isNotEmpty == true;
  final hasLocation = (p['location'] as String?)?.isNotEmpty == true ||
      (p['latitude'] != null && p['longitude'] != null);
  final hasName = (p['full_name'] as String?)?.isNotEmpty == true;
  final firstPost = p['has_first_post'] == true; // optional flag

  final steps = [hasAvatar, hasBio, hasLocation, hasName, firstPost];
  final completed = steps.where((s) => s).length;
  final missing = <String>[
    if (!hasAvatar) 'Avatar hochladen',
    if (!hasBio) 'Bio schreiben',
    if (!hasLocation) 'Standort setzen',
    if (!hasName) 'Namen ergaenzen',
    if (!firstPost) 'Ersten Beitrag erstellen',
  ];
  return OnboardingProgress(
    completed: missing.isEmpty,
    totalSteps: 5,
    completedSteps: completed,
    missing: missing,
  );
}
