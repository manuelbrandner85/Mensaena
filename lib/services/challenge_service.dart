import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mensaena/models/challenge.dart';

class ChallengeService {
  final SupabaseClient _client;

  ChallengeService(this._client);

  Future<List<Challenge>> getChallenges({String? status}) async {
    try {
      var query = _client.from('challenges').select('*, profiles(id, name, nickname, avatar_url)');
      if (status != null) query = query.eq('status', status);
      final data = await query.order('created_at', ascending: false);
      return (data as List).map((e) => Challenge.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Challenge?> getChallenge(String id) async {
    final data = await _client.from('challenges').select('*, profiles(id, name, nickname, avatar_url)').eq('id', id).maybeSingle();
    if (data == null) return null;
    return Challenge.fromJson(data);
  }

  Future<Challenge> createChallenge(Map<String, dynamic> challengeData) async {
    final data = await _client.from('challenges').insert(challengeData).select().single();
    return Challenge.fromJson(data);
  }

  Future<void> joinChallenge(String challengeId, String userId) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    await _client.from('challenge_progress').insert({
      'challenge_id': challengeId,
      'user_id': userId,
      'date': today,
      'checked_in': true,
      'verified_by_admin': false,
    });
  }

  Future<void> checkIn(String challengeId, String userId, {String? proofUrl}) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    await _client.from('challenge_progress').insert({
      'challenge_id': challengeId,
      'user_id': userId,
      'date': today,
      'checked_in': true,
      'verified_by_admin': false,
    });
  }

  Future<void> deleteChallenge(String id) async {
    await _client.from('challenges').delete().eq('id', id);
  }
}
