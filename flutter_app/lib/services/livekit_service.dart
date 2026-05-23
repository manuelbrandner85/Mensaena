import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../config/app_config.dart';
import '../config/env.dart';

/// SKILL: livekit-agents + mensaena-architektur
/// Lightweight LiveKit JWT-Generator (HMAC-SHA256). Kein
/// livekit_server_sdk benoetigt.
///
/// Sicherheitshinweis: API-Secret wird im Client gehalten — fuer
/// Dev-Builds OK, in Production sollte Tokens vom Server kommen.
class LivekitService {
  const LivekitService._();

  /// Generiert ein LiveKit Access Token fuer einen Room-Join.
  ///
  /// - [identity]: User-ID (eindeutig pro Teilnehmer)
  /// - [room]: Room-Name
  /// - [name]: Display-Name (optional)
  /// - [metadata]: User-Metadata JSON-String (optional)
  /// - [ttl]: Token-Lifetime (default 4h, matched Brief)
  static String buildToken({
    required String identity,
    required String room,
    String? name,
    String? metadata,
    Duration ttl = const Duration(hours: AppConfig.livekitJwtHours),
    bool canPublish = true,
    bool canSubscribe = true,
    bool canPublishData = true,
    bool hidden = false,
  }) {
    if (Env.livekitApiKey.isEmpty || Env.livekitApiSecret.isEmpty) {
      throw StateError(
        'LIVEKIT_API_KEY/SECRET nicht gesetzt — Token-Generierung nicht moeglich.',
      );
    }

    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final exp = now + ttl.inSeconds;

    final header = <String, dynamic>{'alg': 'HS256', 'typ': 'JWT'};
    final payload = <String, dynamic>{
      'iss': Env.livekitApiKey,
      'sub': identity,
      'iat': now,
      'exp': exp,
      'video': <String, dynamic>{
        'roomJoin': true,
        'room': room,
        'canPublish': canPublish,
        'canSubscribe': canSubscribe,
        'canPublishData': canPublishData,
        'hidden': hidden,
      },
      if (name != null) 'name': name,
      if (metadata != null) 'metadata': metadata,
    };

    final headerB64 = _base64UrlEncode(jsonEncode(header));
    final payloadB64 = _base64UrlEncode(jsonEncode(payload));
    final signingInput = '$headerB64.$payloadB64';

    final hmac = Hmac(sha256, utf8.encode(Env.livekitApiSecret));
    final sigBytes = hmac.convert(utf8.encode(signingInput)).bytes;
    final sigB64 = _base64UrlEncode(sigBytes);

    return '$signingInput.$sigB64';
  }

  static String _base64UrlEncode(Object input) {
    final bytes = input is String ? utf8.encode(input) : input as List<int>;
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
