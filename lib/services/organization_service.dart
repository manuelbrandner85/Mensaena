import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mensaena/models/organization.dart';

class OrganizationService {
  final SupabaseClient _client;

  OrganizationService(this._client);

  Future<List<Organization>> getOrganizations({
    String? category,
    String? search,
    String? country,
    String? city,
    int limit = 30,
    int offset = 0,
  }) async {
    var query = _client
        .from('organizations')
        .select()
        .eq('is_active', true);

    if (category != null) {
      query = query.eq('category', category);
    }
    if (search != null && search.isNotEmpty) {
      query = query.or('name.ilike.%$search%,description.ilike.%$search%,city.ilike.%$search%');
    }
    if (country != null) {
      query = query.eq('country', country);
    }
    if (city != null) {
      query = query.ilike('city', '%$city%');
    }

    final data = await query.order('name').range(offset, offset + limit - 1);
    return (data as List).map((e) => Organization.fromJson(e)).toList();
  }

  Future<Organization?> getOrganization(String orgId) async {
    final data = await _client
        .from('organizations')
        .select()
        .eq('id', orgId)
        .maybeSingle();
    if (data == null) return null;
    return Organization.fromJson(data);
  }

  Future<List<Organization>> getNearbyOrganizations({
    required double lat,
    required double lng,
    double radiusKm = 50,
    int limit = 30,
  }) async {
    final data = await _client
        .from('organizations')
        .select()
        .eq('is_active', true)
        .not('latitude', 'is', null)
        .not('longitude', 'is', null)
        .limit(limit);
    return (data as List).map((e) => Organization.fromJson(e)).toList();
  }

  // Members
  Future<List<Map<String, dynamic>>> getOrgMembers(String orgId) async {
    final data = await _client
        .from('organization_members')
        .select('*, profiles:user_id(id, name, nickname, avatar_url, trust_score)')
        .eq('organization_id', orgId)
        .order('joined_at');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> joinOrganization(String orgId, String userId) async {
    await _client.from('organization_members').insert({
      'organization_id': orgId,
      'user_id': userId,
      'role': 'member',
    });
  }

  Future<void> leaveOrganization(String orgId, String userId) async {
    await _client
        .from('organization_members')
        .delete()
        .eq('organization_id', orgId)
        .eq('user_id', userId);
  }

  // Reviews
  Future<List<OrganizationReview>> getReviews(String orgId) async {
    final data = await _client
        .from('organization_reviews')
        .select('*, profiles(id, name, nickname, avatar_url)')
        .eq('organization_id', orgId)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => OrganizationReview.fromJson(e))
        .toList();
  }

  Future<void> createReview({
    required String orgId,
    required String userId,
    required int rating,
    String? comment,
  }) async {
    await _client.from('organization_reviews').insert({
      'organization_id': orgId,
      'user_id': userId,
      'rating': rating,
      'comment': comment,
    });
  }

  // Suggestions
  Future<void> suggestOrganization(Map<String, dynamic> data) async {
    await _client.from('organization_suggestions').insert(data);
  }

  // Categories
  Future<Map<String, int>> getCategoryCounts() async {
    final data = await _client
        .from('organizations')
        .select('category')
        .eq('is_active', true);
    final counts = <String, int>{};
    for (final row in data) {
      final cat = row['category'] as String? ?? 'allgemein';
      counts[cat] = (counts[cat] ?? 0) + 1;
    }
    return counts;
  }
}
