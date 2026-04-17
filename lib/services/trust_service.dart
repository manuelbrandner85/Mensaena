import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mensaena/models/trust_rating.dart';

class TrustService {
  final SupabaseClient _client;

  TrustService(this._client);

  Future<List<TrustRating>> getRatingsForUser(String userId) async {
    try {
      final data = await _client
          .from('trust_ratings')
          .select('*, profiles!trust_ratings_rater_id_fkey(id, name, nickname, avatar_url)')
          .eq('rated_id', userId)
          .order('created_at', ascending: false);
      return (data as List).map((e) => TrustRating.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<TrustScoreData> getTrustScore(String userId) async {
    final ratings = await _client
        .from('trust_ratings')
        .select('score')
        .eq('rated_id', userId);
    if ((ratings as List).isEmpty) return const TrustScoreData();
    final scores = ratings.map((r) => r['score'] as int).toList();
    final avg = scores.reduce((a, b) => a + b) / scores.length;
    return TrustScoreData.fromValues(avg, scores.length);
  }

  Future<void> createRating({
    required String raterId,
    required String ratedId,
    required int score,
    String? comment,
    String? category,
  }) async {
    await _client.from('trust_ratings').upsert({
      'rater_id': raterId,
      'rated_id': ratedId,
      'score': score,
      'comment': comment,
      'category': category,
    });
  }

  Future<TrustRating?> getExistingRating(String raterId, String ratedId) async {
    final data = await _client
        .from('trust_ratings')
        .select()
        .eq('rater_id', raterId)
        .eq('rated_id', ratedId)
        .maybeSingle();
    if (data == null) return null;
    return TrustRating.fromJson(data);
  }
}
