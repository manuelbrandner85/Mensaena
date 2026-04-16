import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mensaena/models/crisis.dart';

class CrisisService {
  final SupabaseClient _client;

  CrisisService(this._client);

  Future<List<Crisis>> getCrises({
    String? status,
    String? type,
    int limit = 20,
    int offset = 0,
  }) async {
    var query = _client
        .from('crisis_reports')
        .select('*, profiles(id, name, nickname, avatar_url)')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    if (status != null) {
      query = query.eq('status', status);
    }
    if (type != null) {
      query = query.eq('type', type);
    }

    final data = await query;
    return (data as List).map((e) => Crisis.fromJson(e)).toList();
  }

  Future<List<Crisis>> getActiveCrises() async {
    final data = await _client
        .from('crisis_reports')
        .select('*, profiles(id, name, nickname, avatar_url)')
        .inFilter('status', ['active', 'in_progress'])
        .order('created_at', ascending: false);
    return (data as List).map((e) => Crisis.fromJson(e)).toList();
  }

  Future<Crisis?> getCrisis(String crisisId) async {
    final data = await _client
        .from('crisis_reports')
        .select('*, profiles(id, name, nickname, avatar_url)')
        .eq('id', crisisId)
        .maybeSingle();
    if (data == null) return null;
    return Crisis.fromJson(data);
  }

  Future<Crisis> createCrisis(Map<String, dynamic> crisisData) async {
    final data = await _client
        .from('crisis_reports')
        .insert(crisisData)
        .select()
        .single();
    return Crisis.fromJson(data);
  }

  Future<void> updateCrisisStatus(String crisisId, String status) async {
    final updates = <String, dynamic>{'status': status};
    if (status == 'resolved') {
      updates['resolved_at'] = DateTime.now().toIso8601String();
    }
    await _client.from('crisis_reports').update(updates).eq('id', crisisId);
  }

  // Helpers
  Future<List<CrisisHelper>> getHelpers(String crisisId) async {
    final data = await _client
        .from('crisis_helpers')
        .select('*, profiles(id, name, nickname, avatar_url, trust_score)')
        .eq('crisis_id', crisisId)
        .order('created_at');
    return (data as List).map((e) => CrisisHelper.fromJson(e)).toList();
  }

  Future<void> offerHelp({
    required String crisisId,
    required String userId,
    String? message,
    List<String>? skills,
    List<String>? resources,
  }) async {
    await _client.from('crisis_helpers').insert({
      'crisis_id': crisisId,
      'user_id': userId,
      'message': message,
      'skills': skills ?? [],
      'resources': resources ?? [],
      'status': 'offered',
    });
  }

  Future<void> updateHelperStatus(String helperId, String status) async {
    await _client
        .from('crisis_helpers')
        .update({'status': status})
        .eq('id', helperId);
  }

  // Updates / Timeline
  Future<List<CrisisUpdate>> getUpdates(String crisisId) async {
    final data = await _client
        .from('crisis_updates')
        .select('*, profiles(id, name, nickname, avatar_url)')
        .eq('crisis_id', crisisId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => CrisisUpdate.fromJson(e)).toList();
  }

  Future<void> addUpdate({
    required String crisisId,
    required String userId,
    required String type,
    required String content,
  }) async {
    await _client.from('crisis_updates').insert({
      'crisis_id': crisisId,
      'user_id': userId,
      'type': type,
      'content': content,
    });
  }

  // Stats
  Future<Map<String, int>> getCrisisStats() async {
    final data =
        await _client.from('crisis_reports').select('status');
    final counts = <String, int>{};
    for (final row in data) {
      final status = row['status'] as String? ?? 'unknown';
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return counts;
  }
}
