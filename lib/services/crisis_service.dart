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
    try {
    var query = _client
        .from('crises')
        .select('*');

    if (status != null) {
      query = query.eq('status', status);
    }
    if (type != null) {
      query = query.eq('category', type);
    }

    final data = await query.order('created_at', ascending: false).range(offset, offset + limit - 1);
    return (data as List).map((e) => Crisis.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Crisis>> getActiveCrises() async {
    try {
      final data = await _client
          .from('crises')
          .select('*')
          .inFilter('status', ['active', 'in_progress'])
          .order('urgency', ascending: false)
          .order('created_at', ascending: false);
      return (data as List).map((e) => Crisis.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Crisis?> getCrisis(String crisisId) async {
    final data = await _client
        .from('crises')
        .select('*')
        .eq('id', crisisId)
        .maybeSingle();
    if (data == null) return null;
    return Crisis.fromJson(data);
  }

  Future<Crisis> createCrisis(Map<String, dynamic> crisisData) async {
    final data = await _client
        .from('crises')
        .insert(crisisData)
        .select('*')
        .single();
    return Crisis.fromJson(data);
  }

  Future<void> updateCrisisStatus(String crisisId, String status) async {
    final updates = <String, dynamic>{'status': status};
    if (status == 'resolved') {
      updates['resolved_at'] = DateTime.now().toIso8601String();
    }
    await _client.from('crises').update(updates).eq('id', crisisId);
  }

  // Helpers
  Future<List<CrisisHelper>> getHelpers(String crisisId) async {
    final data = await _client
        .from('crisis_helpers')
        .select('*')
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
        .select('*')
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
      'author_id': userId,
      'update_type': type,
      'content': content,
    });
  }

  // Stats (via RPC like Web)
  Future<Map<String, dynamic>> getCrisisStats() async {
    try {
      final data = await _client.rpc('get_crisis_stats');
      if (data is List && data.isNotEmpty) {
        return Map<String, dynamic>.from(data[0] as Map);
      }
    } catch (_) {}
    // Fallback: manual query
    try {
      final rows = await _client.from('crises').select('status');
      final counts = <String, int>{};
      for (final row in rows) {
        final status = row['status'] as String? ?? 'unknown';
        counts[status] = (counts[status] ?? 0) + 1;
      }
      return {'active_count': counts['active'] ?? 0, 'total_active_helpers': 0, 'resolved_last_30_days': 0};
    } catch (_) {
      return {'active_count': 0, 'total_active_helpers': 0, 'resolved_last_30_days': 0};
    }
  }

  // Nearby Crises (via RPC)
  Future<List<Map<String, dynamic>>> getNearbyCrises({
    required double lat,
    required double lng,
    double radiusKm = 50,
    int limit = 50,
  }) async {
    try {
      final data = await _client.rpc('get_nearby_crises', params: {
        'p_lat': lat, 'p_lng': lng, 'p_radius_km': radiusKm, 'p_limit': limit,
      });
      return List<Map<String, dynamic>>.from(data as List);
    } catch (_) {
      return [];
    }
  }

  // Crisis Resources
  Future<List<Map<String, dynamic>>> getCrisisResources(String crisisId) async {
    final data = await _client.from('crisis_resources').select('*').eq('crisis_id', crisisId).order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> offerResource(Map<String, dynamic> resourceData) async {
    await _client.from('crisis_resources').insert(resourceData);
  }

  // Emergency Numbers
  Future<List<Map<String, dynamic>>> getEmergencyNumbers({String? country}) async {
    var query = _client.from('emergency_numbers').select();
    if (country != null) {
      query = query.eq('country', country);
    }
    final data = await query.order('sort_order');
    return List<Map<String, dynamic>>.from(data);
  }
}
