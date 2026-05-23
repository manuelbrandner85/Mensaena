import 'dart:convert';

import 'package:http/http.dart' as http;

import '../services/supabase_service.dart';

/// SKILL: mensaena-features
/// Server-side LiveKit-JWT — ruft den Web-Endpoint /api/live-room/token
/// auf www.mensaena.de auf. Die LIVEKIT_SELF_KEY/SECRET sind dort als
/// Cloudflare Worker Secrets gesetzt — keine doppelte Secret-Pflege noetig.
/// Authentifizierung erfolgt via Supabase Access-Token Bearer.
class LivekitTokenService {
  const LivekitTokenService._();

  static const _tokenUrl = 'https://www.mensaena.de/api/live-room/token';

  /// Holt JWT + WSS-URL fuer einen Room.
  /// Return null bei Fehler (Logging im Caller).
  static Future<({String token, String url})?> fetch({
    required String roomName,
    String displayName = 'Mitglied',
    bool canPublish = true,
  }) async {
    try {
      final session = sb.auth.currentSession;
      final accessToken = session?.accessToken;
      if (accessToken == null) return null;

      final res = await http
          .post(
            Uri.parse(_tokenUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode({
              'roomName': roomName,
              'displayName': displayName,
              // Web-Endpoint nutzt grant.canPublish=true Default; falls
              // canPublish=false noetig, im Web-Code ergaenzen.
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
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
