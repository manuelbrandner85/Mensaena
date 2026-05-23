import '../services/supabase_service.dart';

/// SKILL: mensaena-features
/// Server-side LiveKit-JWT — ruft Supabase Edge Function `livekit-token`.
/// Niemals client-side signieren (Secret darf nicht im APK landen).
class LivekitTokenService {
  const LivekitTokenService._();

  /// Holt JWT + WSS-URL fuer einen Room.
  /// Return null bei Fehler (Logging im Caller).
  static Future<({String token, String url})?> fetch({
    required String roomName,
    String displayName = 'Mitglied',
    bool canPublish = true,
  }) async {
    try {
      final res = await sb.functions.invoke(
        'livekit-token',
        body: <String, dynamic>{
          'roomName': roomName,
          'displayName': displayName,
          'canPublish': canPublish,
        },
      );
      final data = res.data;
      if (data is Map &&
          data['token'] is String &&
          data['url'] is String) {
        final t = data['token'] as String;
        final u = data['url'] as String;
        if (t.isEmpty || u.isEmpty) return null;
        return (token: t, url: u);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
