import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api_client.dart';
import '../../core/supabase.dart';
import 'models.dart';

final challengesRepositoryProvider = Provider<ChallengesRepository>(
  (ref) => ChallengesRepository(
    ref.read(supabaseProvider),
    ref.read(apiClientProvider),
  ),
);

class ChallengesRepository {
  ChallengesRepository(this._db, this._api);
  final SupabaseClient _db;
  final ApiClient _api;

  Future<List<Challenge>> list() async {
    final rows = await _db
        .from('challenges')
        .select('*')
        .order('start_date', ascending: false)
        .limit(50);
    return rows.map(Challenge.fromJson).toList();
  }

  Future<Challenge?> fetch(String id) async {
    final row = await _db
        .from('challenges')
        .select('*')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return Challenge.fromJson(row);
  }

  Future<Set<String>> myJoinedIds() async {
    final user = _db.auth.currentUser;
    if (user == null) return const {};
    final rows = await _db
        .from('challenge_participants')
        .select('challenge_id')
        .eq('user_id', user.id);
    return rows.map((e) => e['challenge_id'] as String).toSet();
  }

  Future<void> join(String challengeId) async {
    final user = _db.auth.currentUser;
    if (user == null) throw Exception('Nicht eingeloggt');
    await _db.from('challenge_participants').insert(<String, dynamic>{
      'challenge_id': challengeId,
      'user_id': user.id,
    });
  }

  Future<void> leave(String challengeId) async {
    final user = _db.auth.currentUser;
    if (user == null) return;
    await _db
        .from('challenge_participants')
        .delete()
        .eq('challenge_id', challengeId)
        .eq('user_id', user.id);
  }

  /// Calls /api/challenges/[id]/checkin – adds a today's check-in.
  Future<void> checkIn(String challengeId) async {
    await _api.post<void>('/api/challenges/$challengeId/checkin');
  }

  Future<ChallengeProgress?> myProgress(String challengeId) async {
    final user = _db.auth.currentUser;
    if (user == null) return null;
    final rows = await _db
        .from('challenge_progress')
        .select('date, checked_in')
        .eq('challenge_id', challengeId)
        .eq('user_id', user.id)
        .order('date', ascending: false);
    final checkins = rows.where((r) => r['checked_in'] as bool? ?? false).length;
    final lastDate = rows.isNotEmpty
        ? DateTime.tryParse(rows.first['date'] as String? ?? '')
        : null;
    return ChallengeProgress(
      challengeId: challengeId,
      userId: user.id,
      checkins: checkins,
      lastCheckinDate: lastDate,
    );
  }
}
