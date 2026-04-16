import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/services/map_service.dart';
import 'package:mensaena/models/map_pin.dart';

final mapServiceProvider = Provider<MapService>((ref) {
  return MapService(ref.watch(supabaseProvider));
});

final mapPinsProvider = FutureProvider.family<List<MapPin>, Map<String, double?>>((ref, params) async {
  return ref.read(mapServiceProvider).getMapPins(
    lat: params['lat'],
    lng: params['lng'],
    radiusKm: params['radius'] ?? 50,
  );
});

final orgMapPinsProvider = FutureProvider<List<MapPin>>((ref) async {
  return ref.read(mapServiceProvider).getOrganizationPins();
});
