import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/safety_report.dart';
import '../services/supabase_service.dart';

/// SKILL: supabase + mensaena-features
/// Safety-Reports-Repository: Nachbarschafts-Sicherheitsmeldungen.
/// - listNearby() / watchNearby(): Meldungen in der Nähe (Geo-Filter).
/// - create() / upvote() / markResolved(): Schreibzugriffe.
/// Anonymität: bei anonymous=true setzt die RPC reporter_id serverseitig auf
/// null — der Client kann den Melder nie auflösen.
class SafetyRepository {
  const SafetyRepository._();

  static const String _table = 'safety_reports';

  /// Meldungen in der Nähe (Future, max. 100). Nutzt die RPC
  /// `get_nearby_safety_reports` (Bounding-Box + Haversine + Auto-Hide bei
  /// >3 Content-Reports + Anonymisierung). Bei RPC-Fehler: leere Liste.
  static Future<List<SafetyReport>> listNearby({
    required double lat,
    required double lng,
    int radiusKm = 5,
  }) async {
    try {
      final res = await sb.rpc<dynamic>(
        'get_nearby_safety_reports',
        params: <String, dynamic>{
          'p_lat': lat,
          'p_lng': lng,
          'p_radius_km': radiusKm,
          'p_limit': 100,
        },
      );
      if (res is! List) return const [];
      return res
          .whereType<Map<String, dynamic>>()
          .map(SafetyReport.fromJson)
          .toList();
    } catch (e) {
      debugPrint('[SafetyRepository.listNearby] failed: $e');
      return const [];
    }
  }

  /// Realtime-Stream aktiver Meldungen (autoDispose + limit(100)).
  /// Server-Filter `status='active'` VOR dem client-seitigen map().
  /// Hinweis: Der Stream blendet Auto-Hide/Anonymisierung NICHT serverseitig
  /// aus — er dient dem Live-Refresh; die kuratierte Liste liefert listNearby().
  static Stream<List<SafetyReport>> watchNearby() {
    return sb
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(100)
        .map((rows) => rows
            .whereType<Map<String, dynamic>>()
            .map(SafetyReport.fromJson)
            .toList());
  }

  /// Neue Meldung anlegen. reporter_id = aktueller User. Returns id oder null.
  static Future<String?> create(SafetyReport report) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await sb
          .from(_table)
          .insert({
            ...report.toInsert(),
            'reporter_id': uid,
          })
          .select('id')
          .maybeSingle();
      return row?['id'] as String?;
    } catch (e) {
      debugPrint('[SafetyRepository.create] failed: $e');
      return null;
    }
  }

  /// Stimme abgeben (idempotent über UNIQUE(report_id, user_id)).
  /// upvote_count pflegt der DB-Trigger. Returns true bei Erfolg.
  static Future<bool> upvote(String reportId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('safety_report_upvotes').upsert({
        'report_id': reportId,
        'user_id': uid,
      }, onConflict: 'report_id,user_id', ignoreDuplicates: true);
      return true;
    } catch (e) {
      debugPrint('[SafetyRepository.upvote] failed: $e');
      return false;
    }
  }

  /// Meldung als erledigt markieren (Owner oder Moderation via RLS).
  static Future<bool> markResolved(String reportId) async {
    try {
      await sb
          .from(_table)
          .update({'status': 'resolved'})
          .eq('id', reportId);
      return true;
    } catch (e) {
      debugPrint('[SafetyRepository.markResolved] failed: $e');
      return false;
    }
  }
}

/// Realtime-Stream aktiver Safety-Reports (autoDispose → Channel schließt beim
/// Verlassen des Screens).
final safetyReportsStreamProvider =
    StreamProvider.autoDispose<List<SafetyReport>>((ref) {
  return SafetyRepository.watchNearby();
});

/// Meldungen in der Nähe (Future, parametrisiert nach Koordinaten/Radius).
typedef SafetyNearbyArgs = ({double lat, double lng, int radiusKm});

final safetyNearbyProvider = FutureProvider.autoDispose
    .family<List<SafetyReport>, SafetyNearbyArgs>((ref, args) {
  return SafetyRepository.listNearby(
    lat: args.lat,
    lng: args.lng,
    radiusKm: args.radiusKm,
  );
});
