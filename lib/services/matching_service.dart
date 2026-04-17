import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mensaena/models/match.dart';

class MatchingService {
  final SupabaseClient _client;

  MatchingService(this._client);

  Future<List<Match>> getMatches(String userId, {String? status}) async {
    var query = _client
        .from('matches')
        .select()
        .or('request_user_id.eq.$userId,offer_user_id.eq.$userId');
    if (status != null) query = query.eq('status', status);
    final data = await query.order('match_score', ascending: false);
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
        .or('request_user_id.eq.$userId,offer_user_id.eq.$userId');
    final counts = <String, int>{};
    for (final row in data) {
      final s = row['status'] as String? ?? 'unknown';
      counts[s] = (counts[s] ?? 0) + 1;
    }
    return counts;
  }

  // Match Preferences
  Future<Map<String, dynamic>?> getPreferences(String userId) async {
    final data = await _client.from('match_preferences').select('*').eq('user_id', userId).maybeSingle();
    return data;
  }

  Future<void> updatePreferences(String userId, Map<String, dynamic> prefs) async {
    await _client.from('match_preferences').upsert({'user_id': userId, ...prefs});
  }

  // Respond to match
  Future<void> respondToMatch(String matchId, bool accept) async {
    try {
      await _client.rpc('respond_to_match', params: {'p_match_id': matchId, 'p_accept': accept});
    } catch (_) {
      await _client.from('matches').update({'status': accept ? 'accepted' : 'declined'}).eq('id', matchId);
    }
  }
}
