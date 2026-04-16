import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mensaena/models/map_pin.dart';

class MapService {
  final SupabaseClient _client;

  MapService(this._client);

  Future<List<MapPin>> getMapPins({
    double? lat,
    double? lng,
    double radiusKm = 50,
    String? type,
  }) async {
    try {
      if (lat != null && lng != null) {
        final data = await _client.rpc('get_nearby_posts', params: {
          'user_lat': lat,
          'user_lng': lng,
          'radius_km': radiusKm,
          'max_results': 200,
        });
        return (data as List)
            .where((e) => e['latitude'] != null && e['longitude'] != null)
            .map((e) => MapPin.fromPost(e))
            .toList();
      }
    } catch (_) {}

    // Fallback
    var query = _client
        .from('posts')
        .select('id, title, description, type, latitude, longitude, location_text, image_url, user_id, created_at, status')
        .eq('status', 'active')
        .not('latitude', 'is', null)
        .not('longitude', 'is', null)
        .limit(200);

    if (type != null) query = query.eq('type', type);

    final data = await query;
    return (data as List).map((e) => MapPin.fromPost(e)).toList();
  }

  Future<List<MapPin>> getOrganizationPins({String? category}) async {
    var query = _client
        .from('organizations')
        .select('id, name, description, category, latitude, longitude, city')
        .eq('is_active', true)
        .not('latitude', 'is', null)
        .not('longitude', 'is', null);

    if (category != null) query = query.eq('category', category);

    final data = await query;
    return (data as List).map((e) => MapPin.fromOrganization(e)).toList();
  }
}
