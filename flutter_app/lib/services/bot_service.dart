import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'supabase_service.dart';

/// SKILL: mensaena-features
/// MensaenaBot — Streaming-Client gegen `https://www.mensaena.de/api/bot`.
/// Pendant zu `src/components/bot/MensaenaBot.tsx` (Z.628 ff).
/// SSE-Format: `data: {"token":"..."}\n\n` und `data: [DONE]\n\n`.
class BotService {
  const BotService._();

  /// Sendet [messages] (oldest-first) und streamt Tokens via [onToken].
  /// Liefert die gesamte Antwort als String. Bei Fehler: leerer String.
  static Future<String> chatStream({
    required List<BotMessage> messages,
    required String route,
    required void Function(String token) onToken,
    String? userName,
    String locale = 'de',
  }) async {
    final token = sb.auth.currentSession?.accessToken;
    if (token == null) return '';
    final client = http.Client();
    try {
      final req = http.Request(
        'POST',
        Uri.parse('https://www.mensaena.de/api/bot'),
      );
      req.headers
        ..['Content-Type'] = 'application/json'
        ..['Accept'] = 'text/event-stream'
        ..['Authorization'] = 'Bearer $token';
      req.body = jsonEncode({
        'messages': messages
            .map((m) => {'role': m.role, 'content': m.content})
            .toList(),
        'route': route,
        if (userName != null) 'userName': userName,
        'locale': locale,
      });
      final res = await client.send(req).timeout(
            const Duration(seconds: 60),
          );
      if (res.statusCode != 200) return '';
      final completer = Completer<String>();
      final buffer = StringBuffer();
      var carry = '';

      res.stream.transform(utf8.decoder).listen(
        (chunk) {
          carry += chunk;
          while (true) {
            final idx = carry.indexOf('\n\n');
            if (idx == -1) break;
            final frame = carry.substring(0, idx).trim();
            carry = carry.substring(idx + 2);
            if (!frame.startsWith('data:')) continue;
            final payload = frame.substring(5).trim();
            if (payload == '[DONE]') continue;
            try {
              final data = jsonDecode(payload) as Map<String, dynamic>;
              final tok = data['token'] as String?;
              if (tok != null && tok.isNotEmpty) {
                buffer.write(tok);
                onToken(tok);
              }
            } catch (_) {
              // ignore malformed frames
            }
          }
        },
        onDone: () => completer.complete(buffer.toString()),
        onError: (_) => completer.complete(buffer.toString()),
        cancelOnError: true,
      );

      return completer.future;
    } catch (_) {
      return '';
    } finally {
      client.close();
    }
  }
}

class BotMessage {
  const BotMessage({
    required this.role,
    required this.content,
    DateTime? at,
  }) : at = at;

  final String role; // 'user' | 'assistant' | 'system'
  final String content;
  final DateTime? at;
}
