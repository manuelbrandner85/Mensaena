import '../models/emergency_alert.dart';
import '../services/supabase_service.dart';

/// Supabase-Zugriff für emergency_alerts.
/// Streams: immer .limit() + vom Provider mit autoDispose gewrapped.
class EmergencyRepository {
  const EmergencyRepository._();

  static const _table = 'emergency_alerts';

  /// Legt einen neuen SOS-Alert an und gibt die id zurück.
  static Future<EmergencyAlert?> createAlert({
    required String userId,
    required String alertType,
    required double latitude,
    required double longitude,
    String? description,
  }) async {
    try {
      await SupabaseService.ensureFreshSession();
      final row = await sb.from(_table).insert({
        'user_id': userId,
        'alert_type': alertType,
        'latitude': latitude,
        'longitude': longitude,
        if (description != null && description.isNotEmpty)
          'description': description,
      }).select().single();
      return EmergencyAlert.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  /// Realtime-Stream aktiver Alerts in der Nähe (SELECT-RLS filtert <500 m).
  static Stream<List<EmergencyAlert>> watchNearby() {
    return sb
        .from(_table)
        .stream(primaryKey: ['id'])
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(150)
        .map(
          (rows) => rows
              .map((r) => EmergencyAlert.fromJson(r))
              .toList(),
        );
  }

  /// Trägt den aktuellen User als Responder ein.
  static Future<bool> respondToAlert(String alertId, String userId) async {
    try {
      // Aktuelle Respondents lesen, User anhängen (falls noch nicht dabei).
      final row = await sb
          .from(_table)
          .select('respondents')
          .eq('id', alertId)
          .maybeSingle();
      if (row == null) return false;
      final current = List<String>.from(
          (row['respondents'] as List<dynamic>? ?? []).map((e) => '$e'));
      if (current.contains(userId)) return true;
      current.add(userId);
      await sb
          .from(_table)
          .update({'respondents': current})
          .eq('id', alertId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Schließt einen Alert (nur Creator).
  static Future<bool> resolveAlert(String alertId) async {
    try {
      await sb
          .from(_table)
          .update({'status': 'resolved'})
          .eq('id', alertId)
          .eq('user_id', sb.auth.currentUser?.id ?? '');
      return true;
    } catch (_) {
      return false;
    }
  }
}
