// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, require_trailing_commas, unused_import
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../services/location_service.dart';
import '../../../services/supabase/supabase_service.dart';

final userPositionProvider = FutureProvider<Position?>((ref) {
  return locationService.requestPermissionAndFetch();
});

final mapMarkersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await supabase.client
      .from('posts')
      .select('id, type, content, image_url, lat, lng, created_at, profiles!posts_user_id_fkey(id, full_name, avatar_url)')
      .not('lat', 'is', null)
      .not('lng', 'is', null)
      .order('created_at', ascending: false)
      .limit(200);
  return List<Map<String, dynamic>>.from(res as List);
});
