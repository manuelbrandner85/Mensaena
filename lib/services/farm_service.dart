import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mensaena/models/farm_listing.dart';

class FarmService {
  final SupabaseClient _client;

  FarmService(this._client);

  Future<List<FarmListing>> getFarmListings({String? category, String? search, String? country, int limit = 30}) async {
    var query = _client.from('farm_listings').select().eq('is_public', true).order('name').limit(limit);
    if (category != null) query = query.eq('category', category);
    if (country != null) query = query.eq('country', country);
    if (search != null && search.isNotEmpty) query = query.or('name.ilike.%$search%,city.ilike.%$search%,products.cs.{$search}');
    final data = await query;
    return (data as List).map((e) => FarmListing.fromJson(e)).toList();
  }

  Future<FarmListing?> getFarmBySlug(String slug) async {
    final data = await _client.from('farm_listings').select().eq('slug', slug).maybeSingle();
    if (data == null) return null;
    return FarmListing.fromJson(data);
  }

  Future<FarmListing> createFarmListing(Map<String, dynamic> farmData) async {
    final data = await _client.from('farm_listings').insert(farmData).select().single();
    return FarmListing.fromJson(data);
  }
}
