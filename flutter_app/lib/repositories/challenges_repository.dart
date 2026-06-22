import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/badge.dart';
import '../models/challenge.dart';
import '../models/challenge_progress.dart';
import '../models/user_badge.dart';
import '../services/supabase_service.dart';

/// SKILL: supabase + mensaena-features
/// Challenges + Badges Repository (gyqujitkvymlmgroovch).
class ChallengesRepository {
  const ChallengesRepository._();

  static Future<List<Challenge>> listActive() async {
    try {
      // BUGFIX: DB-Schema nutzt status='active' (TEXT), KEINE is_active-
      // Bool-Spalte. Vorher: .eq('is_active', true) lieferte immer leer →
      // Admin-aktive Challenges erschienen nicht im Modul.
      final rows = await sb
          .from('challenges')
          .select()
          .eq('status', 'active')
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

  /// Erstellt eine neue Challenge. Mapped 1:1 zu Web-Form
  /// /dashboard/challenges/create. Gibt die neue ID zurück oder null.
  static Future<String?> create({
    required String title,
    required String category, // umwelt|sozial|fitness|bildung|kreativ|ernaehrung|gemeinschaft
    required String difficulty, // leicht|mittel|schwer
    required int durationDays, // 1-90
    String? description,
    int points = 50,
    int? maxParticipants,
    bool isWeekly = false,
    String? rewardBadge,
    String? coverUrl,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return null;
    if (title.trim().length < 5 || title.trim().length > 80) return null;
    if (durationDays < 1 || durationDays > 90) return null;
    if (points < 10 || points > 500) return null;
    final start = DateTime.now().toUtc();
    final end = start.add(Duration(days: durationDays));
    try {
      final row = await sb
          .from('challenges')
          .insert({
            'title': title.trim(),
            if (description != null && description.trim().isNotEmpty)
              'description': description.trim(),
            'category': category,
            'difficulty': difficulty,
            'points': points,
            'start_date': start.toIso8601String(),
            'end_date': end.toIso8601String(),
            'status': 'active',
            'participant_count': 0,
            'creator_id': uid,
            if (maxParticipants != null && maxParticipants > 0)
              'max_participants': maxParticipants,
            if (rewardBadge != null && rewardBadge.trim().isNotEmpty)
              'reward_badge': rewardBadge.trim(),
            if (coverUrl != null && coverUrl.isNotEmpty) 'cover_url': coverUrl,
            'is_weekly': isWeekly,
          })
          .select('id')
          .maybeSingle();
      return row?['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> join(String challengeId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      // Schema-Fix: DB hat status+progress_pct, NICHT current_count+completed.
      // Vorher schlug der Insert mit "column does not exist" fehl → silent
      // catch → User sah "Konnte nicht beitreten".
      // upsert damit doppeltes Join nicht crash't (idempotent).
      await sb.from('challenge_progress').upsert({
        'user_id': uid,
        'challenge_id': challengeId,
        'status': 'active',
        'progress_pct': 0,
      }, onConflict: 'challenge_id,user_id');
      return true;
    } catch (e) {
      // Debug-Print damit man im LogCat sehen kann wenn DB-Schema sich
      // wieder ändert.
      // ignore: avoid_print
      print('ChallengesRepository.join failed: $e');
      return false;
    }
  }

  /// Aktualisiert den Fortschritt des Users für eine Challenge.
  /// Bei 100 % wird die Challenge automatisch als abgeschlossen markiert.
  static Future<bool> updateProgress(
      String challengeId, int progressPct) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    final pct = progressPct.clamp(0, 100);
    try {
      final Map<String, dynamic> data = {
        'progress_pct': pct,
        if (pct >= 100) ...{
          'status': 'completed',
          'completed_at': DateTime.now().toUtc().toIso8601String(),
        } else ...{
          'status': 'active',
        },
      };
      await sb
          .from('challenge_progress')
          .update(data)
          .eq('challenge_id', challengeId)
          .eq('user_id', uid);
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('ChallengesRepository.updateProgress failed: $e');
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

  /// Prüft alle berechenbaren Badge-Kriterien server-seitig und verleiht
  /// erreichte Badges (idempotent) inkl. Karma. Gibt die Anzahl NEU
  /// vergebener Badges zurück. Vorher waren fast alle Katalog-Badges
  /// unerreichbar (es gab keine Vergabe-Logik).
  static Future<int> checkAndAwardBadges() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return 0;
    try {
      final res = await sb.rpc<dynamic>('check_and_award_badges');
      if (res is int) return res;
      if (res is num) return res.toInt();
      return int.tryParse('$res') ?? 0;
    } catch (_) {
      return 0;
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
