import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/badge.dart';
import '../models/challenge.dart';
import '../models/challenge_progress.dart';
import '../models/user_badge.dart';
import '../services/supabase_service.dart';

/// SKILL: supabase + mensaena-features
/// Challenges + Badges Repository (huaqldjkgyosefzfhjnf).
class ChallengesRepository {
  const ChallengesRepository._();

  static Future<List<Challenge>> listActive() async {
    try {
      final rows = await sb
          .from('challenges')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(50);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(Challenge.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<Challenge?> getById(String id) async {
    try {
      final row = await sb
          .from('challenges')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return Challenge.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  static Future<List<ChallengeProgress>> myProgress() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const [];
    try {
      final rows = await sb
          .from('challenge_progress')
          .select()
          .eq('user_id', uid);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(ChallengeProgress.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<ChallengeProgress?> myProgressFor(String challengeId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await sb
          .from('challenge_progress')
          .select()
          .eq('user_id', uid)
          .eq('challenge_id', challengeId)
          .maybeSingle();
      if (row == null) return null;
      return ChallengeProgress.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> join(String challengeId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('challenge_progress').insert({
        'user_id': uid,
        'challenge_id': challengeId,
        'current_count': 0,
        'completed': false,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<BadgeModel>> listAllBadges() async {
    try {
      final rows = await sb
          .from('badges')
          .select()
          .order('points', ascending: true)
          .limit(200);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(BadgeModel.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<UserBadge>> myBadges() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const [];
    try {
      final rows = await sb
          .from('user_badges')
          .select()
          .eq('user_id', uid)
          .order('earned_at', ascending: false);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(UserBadge.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

final activeChallengesProvider =
    FutureProvider<List<Challenge>>((ref) async {
  return ChallengesRepository.listActive();
});

final myChallengeProgressProvider =
    FutureProvider<List<ChallengeProgress>>((ref) async {
  return ChallengesRepository.myProgress();
});

final allBadgesProvider = FutureProvider<List<BadgeModel>>((ref) async {
  return ChallengesRepository.listAllBadges();
});

final myBadgesProvider = FutureProvider<List<UserBadge>>((ref) async {
  return ChallengesRepository.myBadges();
});
