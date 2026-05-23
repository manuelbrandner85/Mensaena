import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' show Session;

import '../services/supabase_service.dart';

/// SKILL: mensaena-features
/// Server-side LiveKit-JWT — ruft Web-Endpoint /api/live-room/token auf
/// (Cloudflare Worker, LIVEKIT_SELF_KEY/SECRET als Worker-Secrets).
/// Auth via Supabase Access-Token.
class LivekitTokenService {
  const LivekitTokenService._();

  static const _tokenUrl = 'https://www.mensaena.de/api/live-room/token';

  /// Holt JWT + WSS-URL fuer einen Room.
  /// Wirft LivekitTokenError mit lesbarer Message statt null —
  /// so kann der UI-Layer den genauen Grund anzeigen.
  static Future<({String token, String url})> fetch({
    required String roomName,
    String displayName = 'Mitglied',
    bool canPublish = true,
  }) async {
    // 1) Session sicherstellen (refresh wenn expired)
    Session? session = sb.auth.currentSession;
    if (session == null) {
      throw const LivekitTokenError('Nicht angemeldet.');
    }
    final expiresAt = session.expiresAt; // seconds since epoch
    if (expiresAt != null) {
      final expiresAtMs = expiresAt * 1000;
      final isExpiringSoon = DateTime.now().millisecondsSinceEpoch >
          expiresAtMs - 60000;
      if (isExpiringSoon) {
        try {
          final refresh = await sb.auth.refreshSession();
          session = refresh.session ?? session;
        } catch (_) {}
      }
    }
    final accessToken = session?.accessToken ?? '';
    if (accessToken.isEmpty) {
      throw const LivekitTokenError('Kein gueltiger Access-Token.');
    }

    // 2) POST an Web-Endpoint
    http.Response res;
    try {
      res = await http
          .post(
            Uri.parse(_tokenUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
              'User-Agent': 'Mensaena-Flutter/4.0',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'roomName': roomName,
              'displayName': displayName,
            }),
          )
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      throw LivekitTokenError('Netzwerk-Fehler: $e');
    }

    if (res.statusCode != 200) {
      String detail = '';
      try {
        final json = jsonDecode(res.body);
        if (json is Map && json['error'] is String) {
          detail = ': ${json['error']}';
        }
      } catch (_) {}
      throw LivekitTokenError('HTTP ${res.statusCode}$detail');
    }

    final data = jsonDecode(res.body);
    if (data is! Map || data['token'] is! String || data['url'] is! String) {
      throw const LivekitTokenError(
          'Server-Response unguelt­ig (kein token/url).');
    }
    final t = data['token'] as String;
    final u = data['url'] as String;
    if (t.isEmpty || u.isEmpty) {
      throw const LivekitTokenError('Token oder URL leer.');
    }
    return (token: t, url: u);
  }
}

class LivekitTokenError implements Exception {
  const LivekitTokenError(this.message);
  final String message;
  @override
  String toString() => message;
}
