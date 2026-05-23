import 'supabase_service.dart';

/// SKILL: supabase
/// Server-seitiges Rate-Limiting via Postgres RPC check_rate_limit.
/// Fail-open: bei RPC-Fehler wird die Aktion erlaubt (kein Self-DoS).
class RateLimitService {
  const RateLimitService._();

  static const int defaultPerMinute = 5;
  static const int defaultPerHour = 30;

  /// Prueft ob der User die Aktion ausfuehren darf.
  /// Returns true wenn erlaubt, false wenn rate-limited.
  static Future<bool> check({
    required String action,
    String? userId,
    int maxPerMinute = defaultPerMinute,
    int maxPerHour = defaultPerHour,
  }) async {
    final uid = userId ?? SupabaseService.currentUser?.id;
    if (uid == null) return true; // not logged in — nothing to limit yet
    try {
      final result = await sb.rpc<dynamic>(
        'check_rate_limit',
        params: <String, dynamic>{
          'p_user_id': uid,
          'p_action': action,
          'p_max_per_hour': maxPerHour,
          'p_max_per_minute': maxPerMinute,
        },
      );
      if (result is bool) return result;
      return true;
    } catch (_) {
      // Fail-open: bei Backend-Fehler nicht den User blocken.
      return true;
    }
  }
}
