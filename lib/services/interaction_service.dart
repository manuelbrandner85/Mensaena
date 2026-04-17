import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mensaena/models/interaction.dart';

class InteractionService {
  final SupabaseClient _client;

  InteractionService(this._client);

  Future<List<Interaction>> getInteractions(String userId, {String? status}) async {
    try {
      var query = _client
          .from('interactions')
          .select('*, posts(title, type, user_id), profiles!interactions_helper_id_fkey(name, avatar_url)')
          .or('helper_id.eq.$userId,helped_id.eq.$userId');
      if (status != null) query = query.eq('status', status);
      final data = await query.order('created_at', ascending: false);
      return (data as List).map((e) => Interaction.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Interaction?> getInteraction(String interactionId) async {
    final data = await _client
        .from('interactions')
        .select('*, posts(title, type, user_id), profiles!interactions_helper_id_fkey(name, avatar_url)')
        .eq('id', interactionId)
        .maybeSingle();
    if (data == null) return null;
    return Interaction.fromJson(data);
  }

  Future<Interaction> createInteraction({
    required String postId,
    required String helperId,
    String? message,
  }) async {
    final data = await _client
        .from('interactions')
        .insert({
          'post_id': postId,
          'helper_id': helperId,
          'status': 'requested',
          'message': message,
        })
        .select()
        .single();
    return Interaction.fromJson(data);
  }

  Future<void> updateStatus(String interactionId, String status) async {
    final updates = <String, dynamic>{'status': status};
    if (status == 'completed') {
      updates['completed_at'] = DateTime.now().toIso8601String();
    }
    await _client.from('interactions').update(updates).eq('id', interactionId);
  }

  Future<Map<String, int>> getStats(String userId) async {
    final data = await _client
        .from('interactions')
        .select('status')
        .or('helper_id.eq.$userId,helped_id.eq.$userId');
    final counts = <String, int>{};
    for (final row in data) {
      final s = row['status'] as String? ?? 'unknown';
      counts[s] = (counts[s] ?? 0) + 1;
    }
    return counts;
  }

  // Interaction Updates (timeline)
  Future<List<Map<String, dynamic>>> getUpdates(String interactionId) async {
    final data = await _client.from('interaction_updates').select('*').eq('interaction_id', interactionId).order('created_at');
    return List<Map<String, dynamic>>.from(data);
  }
}
