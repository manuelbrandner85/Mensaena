import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mensaena/models/match.dart';

class MatchingService {
  final SupabaseClient _client;

  MatchingService(this._client);

  Future<List<Match>> getMatches(String userId, {String? status}) async {
    var query = _client
        .from('matches')
        .select()
        .or('seeker_user_id.eq.$userId,offer_user_id.eq.$userId');
    if (status != null) query = query.eq('status', status);
    final data = await query.order('score', ascending: false);
    return (data as List).map((e) => Match.fromJson(e)).toList();
  }

  Future<Match?> getMatch(String matchId) async {
    final data = await _client.from('matches').select().eq('id', matchId).maybeSingle();
    if (data == null) return null;
    return Match.fromJson(data);
  }

  Future<void> updateMatchStatus(String matchId, String status) async {
    await _client.from('matches').update({'status': status}).eq('id', matchId);
  }

  Future<Map<String, int>> getMatchCounts(String userId) async {
    final data = await _client
        .from('matches')
        .select('status')
        .or('seeker_user_id.eq.$userId,offer_user_id.eq.$userId');
    final counts = <String, int>{};
    for (final row in data) {
      final s = row['status'] as String? ?? 'unknown';
      counts[s] = (counts[s] ?? 0) + 1;
    }
    return counts;
  }
}
