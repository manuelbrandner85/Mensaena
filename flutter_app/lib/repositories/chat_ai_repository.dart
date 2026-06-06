/// SKILL: mensaena-architektur
/// Repository für "Mensa" — den warmherzigen KI-Assistenten.
/// Spricht ausschließlich mit der Edge Function `chat-ai` (Schlüssel liegen
/// als Supabase Secrets, NIE im Client). Stil: wie mega_repositories.dart.
library;

import 'package:flutter/foundation.dart' show debugPrint;

import '../services/supabase_service.dart';

/// Eine Nachricht im Assistenten-Verlauf.
class ChatAiMessage {
  const ChatAiMessage({
    required this.text,
    required this.fromUser,
    this.navRoute,
    this.navLabel,
    this.question,
  });

  final String text;
  final bool fromUser;
  final String? navRoute;
  final String? navLabel;

  /// Für Feedback: die Nutzerfrage, die zu dieser Bot-Antwort führte.
  final String? question;
}

/// Antwort der Edge Function.
class ChatAiResult {
  const ChatAiResult({
    required this.reply,
    this.navRoute,
    this.navLabel,
    this.provider,
    this.limited = false,
  });

  final String reply;
  final String? navRoute;
  final String? navLabel;
  final String? provider;
  final bool limited;
}

class ChatAiRepository {
  /// Fragt Mensa. `history` = letzte (max 6) Nachrichten als
  /// [{role:'user'|'assistant', content:...}].
  Future<ChatAiResult> ask({
    required String message,
    required List<Map<String, String>> history,
    required String currentScreen,
    required String lang,
    String? firstName,
  }) async {
    // STABILITÄT: Timeout gegen Hänger + try/catch — ein Netzwerkfehler darf
    // den Chat nicht crashen, sondern liefert eine freundliche Fehlerantwort.
    try {
      final res = await SupabaseService.client.functions.invoke(
        'chat-ai',
        body: {
          'message': message,
          'history': history,
          'currentScreen': currentScreen,
          'lang': lang,
          'firstName': firstName ?? '',
        },
      ).timeout(const Duration(seconds: 30));
      final data = res.data;
      if (data is Map) {
        final nav = data['nav'];
        return ChatAiResult(
          reply: (data['reply'] ?? '').toString(),
          navRoute: nav is Map ? nav['route']?.toString() : null,
          navLabel: nav is Map ? nav['label']?.toString() : null,
          provider: data['provider']?.toString(),
          limited: data['limited'] == true,
        );
      }
    } catch (e) {
      debugPrint('[ChatAi] ask failed: $e');
    }
    // Leerer reply → die UI zeigt ihren lokalisierten Fehler-/Retry-Hinweis.
    return const ChatAiResult(reply: '');
  }

  /// Daumen hoch (1) / runter (-1) zu einer Antwort.
  Future<void> sendFeedback({
    required int rating,
    required String question,
    required String answer,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    // Fire-and-forget: ein fehlgeschlagenes Feedback darf den Chat nicht
    // crashen — nur loggen.
    try {
      await SupabaseService.client.from('ai_chat_feedback').insert({
        'user_id': uid,
        'rating': rating,
        'question': question,
        'answer': answer,
      });
    } catch (e) {
      debugPrint('[ChatAi] sendFeedback failed: $e');
    }
  }
}
