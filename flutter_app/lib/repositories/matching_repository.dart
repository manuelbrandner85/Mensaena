import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/match_summary.dart';
import '../services/supabase_service.dart';

/// SKILL: supabase + mensaena-features
/// Matching-Repository — wrappt die RPCs get_my_matches, respond_to_match,
/// get_match_counts (huaqldjkgyosefzfhjnf).
class MatchingRepository {
  const MatchingRepository._();

  /// Eigene Matches laden. `status` ∈ {all,pending,accepted,completed}.
  static Future<List<MatchSummary>> fetchMine({
    String status = 'all',
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final res = await sb.rpc<dynamic>('get_my_matches', params: {
        'p_status': status == 'all' ? null : status,
        'p_limit': limit,
        'p_offset': offset,
      });
      if (res is! List) return const [];
      return res
          .whereType<Map<String, dynamic>>()
          .map(MatchSummary.fromRpcRow)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Match-Counts {suggested,pending,accepted,completed} fuer das Dashboard.
  static Future<MatchCounts> fetchCounts() async {
    try {
      final res = await sb.rpc<dynamic>('get_match_counts', params: {
        'p_user_id': SupabaseService.currentUser?.id,
      });
      if (res is! Map) return const MatchCounts.empty();
      final m = Map<String, dynamic>.from(res);
      int n(String k) => (m[k] as num?)?.toInt() ?? 0;
      return MatchCounts(
        suggested: n('suggested'),
        pending: n('pending'),
        accepted: n('accepted'),
        completed: n('completed'),
      );
    } catch (_) {
      return const MatchCounts.empty();
    }
  }

  /// Auf Match reagieren — accept=true/false. Optionaler decline-Grund.
  /// Returns conversation_id wenn beide Seiten accepted haben.
  static Future<MatchResponseResult> respond({
    required String matchId,
    required bool accept,
    String? declineReason,
  }) async {
    try {
      final res = await sb.rpc<dynamic>('respond_to_match', params: {
        'p_match_id': matchId,
        'p_accept': accept,
        'p_decline_reason': declineReason,
      });
      if (res is Map) {
        final m = Map<String, dynamic>.from(res);
        final err = m['error'];
        if (err is String) {
          return MatchResponseResult(success: false, error: err);
        }
        return MatchResponseResult(
          success: true,
          status: m['status'] as String?,
          conversationId: m['conversation_id'] as String?,
        );
      }
      return const MatchResponseResult(success: true);
    } catch (e) {
      return MatchResponseResult(success: false, error: e.toString());
    }
  }

  /// Match-Praeferenzen laden (oder DEFAULTS).
  static Future<MatchPreferences> fetchPreferences() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return MatchPreferences.defaults();
    try {
      final row = await sb
          .from('match_preferences')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
      if (row == null) return MatchPreferences.defaults();
      return MatchPreferences.fromJson(row);
    } catch (_) {
      return MatchPreferences.defaults();
    }
  }

  /// Match-Praeferenzen speichern (upsert).
  static Future<bool> savePreferences(MatchPreferences prefs) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('match_preferences').upsert({
        'user_id': uid,
        'matching_enabled': prefs.matchingEnabled,
        'max_distance_km': prefs.maxDistanceKm,
        'preferred_categories': prefs.preferredCategories,
        'excluded_categories': prefs.excludedCategories,
        'min_trust_score': prefs.minTrustScore,
        'max_matches_per_day': prefs.maxMatchesPerDay,
        'notify_on_match': prefs.notifyOnMatch,
        'auto_accept_threshold': prefs.autoAcceptThreshold,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markSeen(String matchId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    try {
      final row = await sb
          .from('matches')
          .select('offer_user_id,request_user_id')
          .eq('id', matchId)
          .maybeSingle();
      if (row == null) return;
      final isOffer = row['offer_user_id'] == uid;
      await sb
          .from('matches')
          .update(isOffer
              ? {'seen_by_offer': true}
              : {'seen_by_request': true})
          .eq('id', matchId);
    } catch (_) {}
  }
}

class MatchCounts {
  const MatchCounts({
    required this.suggested,
    required this.pending,
    required this.accepted,
    required this.completed,
  });
  const MatchCounts.empty()
      : suggested = 0,
        pending = 0,
        accepted = 0,
        completed = 0;

  final int suggested;
  final int pending;
  final int accepted;
  final int completed;
}

class MatchResponseResult {
  const MatchResponseResult({
    required this.success,
    this.status,
    this.conversationId,
    this.error,
  });

  final bool success;
  final String? status;
  final String? conversationId;
  final String? error;
}

/// Match-Praeferenzen — 1:1 zu DEFAULT_PREFERENCES aus matching/types.ts.
class MatchPreferences {
  const MatchPreferences({
    required this.matchingEnabled,
    required this.maxDistanceKm,
    required this.preferredCategories,
    required this.excludedCategories,
    required this.minTrustScore,
    required this.maxMatchesPerDay,
    required this.notifyOnMatch,
    this.autoAcceptThreshold,
  });

  factory MatchPreferences.defaults() => const MatchPreferences(
        matchingEnabled: true,
        maxDistanceKm: 25,
        preferredCategories: [],
        excludedCategories: [],
        minTrustScore: 0,
        maxMatchesPerDay: 5,
        notifyOnMatch: true,
      );

  factory MatchPreferences.fromJson(Map<String, dynamic> j) {
    return MatchPreferences(
      matchingEnabled: (j['matching_enabled'] as bool?) ?? true,
      maxDistanceKm: (j['max_distance_km'] as num?)?.toInt() ?? 25,
      preferredCategories: (j['preferred_categories'] as List?)
              ?.whereType<String>()
              .toList() ??
          const [],
      excludedCategories: (j['excluded_categories'] as List?)
              ?.whereType<String>()
              .toList() ??
          const [],
      minTrustScore: (j['min_trust_score'] as num?)?.toInt() ?? 0,
      maxMatchesPerDay: (j['max_matches_per_day'] as num?)?.toInt() ?? 5,
      notifyOnMatch: (j['notify_on_match'] as bool?) ?? true,
      autoAcceptThreshold:
          (j['auto_accept_threshold'] as num?)?.toDouble(),
    );
  }

  final bool matchingEnabled;
  final int maxDistanceKm;
  final List<String> preferredCategories;
  final List<String> excludedCategories;
  final int minTrustScore;
  final int maxMatchesPerDay;
  final bool notifyOnMatch;
  final double? autoAcceptThreshold;

  MatchPreferences copyWith({
    bool? matchingEnabled,
    int? maxDistanceKm,
    List<String>? preferredCategories,
    List<String>? excludedCategories,
    int? minTrustScore,
    int? maxMatchesPerDay,
    bool? notifyOnMatch,
    double? autoAcceptThreshold,
  }) {
    return MatchPreferences(
      matchingEnabled: matchingEnabled ?? this.matchingEnabled,
      maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
      preferredCategories: preferredCategories ?? this.preferredCategories,
      excludedCategories: excludedCategories ?? this.excludedCategories,
      minTrustScore: minTrustScore ?? this.minTrustScore,
      maxMatchesPerDay: maxMatchesPerDay ?? this.maxMatchesPerDay,
      notifyOnMatch: notifyOnMatch ?? this.notifyOnMatch,
      autoAcceptThreshold: autoAcceptThreshold ?? this.autoAcceptThreshold,
    );
  }
}

final matchingFilterProvider = StateProvider<String>((ref) => 'all');

final matchPreferencesProvider =
    FutureProvider<MatchPreferences>((ref) async {
  return MatchingRepository.fetchPreferences();
});

final matchingListProvider =
    FutureProvider<List<MatchSummary>>((ref) async {
  final filter = ref.watch(matchingFilterProvider);
  return MatchingRepository.fetchMine(status: filter);
});

final matchingCountsProvider = FutureProvider<MatchCounts>((ref) async {
  return MatchingRepository.fetchCounts();
});
