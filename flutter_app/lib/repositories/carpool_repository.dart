import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/carpool_route.dart';
import '../services/supabase_service.dart';

/// Fahrgemeinschafts-Routen — createRoute / myRoutes.
class CarpoolRepository {
  const CarpoolRepository._();

  static Future<String?> createRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    required DayOfWeek dayOfWeek,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await sb
          .from('carpool_routes')
          .insert({
            'user_id': uid,
            'start_lat': startLat,
            'start_lng': startLng,
            'end_lat': endLat,
            'end_lng': endLng,
            'day_of_week': dayOfWeek.name,
          })
          .select('id')
          .maybeSingle();
      return row?['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<List<CarpoolRoute>> myRoutes({int limit = 50}) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const [];
    try {
      final rows = await sb
          .from('carpool_routes')
          .select('id, user_id, start_lat, start_lng, end_lat, end_lng, day_of_week, created_at, updated_at')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(CarpoolRoute.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> deleteRoute(String id) async {
    try {
      await sb.from('carpool_routes').delete().eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final myCarpoolRoutesProvider =
    FutureProvider.autoDispose<List<CarpoolRoute>>(
  (ref) => CarpoolRepository.myRoutes(),
);
