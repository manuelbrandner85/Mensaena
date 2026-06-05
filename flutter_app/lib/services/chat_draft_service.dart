import 'package:flutter/foundation.dart';

/// Hält pro Konversation den aktuellen (ungesendeten) Textentwurf.
///
/// Use-Case: User tippt in Chat A, springt zu B (oder navigiert weg, um
/// etwas nachzuschauen), kommt zurück → der Text steht noch im Eingabefeld.
/// In-Memory only — das reicht für die Session; bei App-Neustart frisch.
///
/// Adaptiert aus Weltenbibliothek-App (manuelbrandner85/Weltenbibliothekapp,
/// lib/services/chat/chat_draft_service.dart). Mensaena hatte nur
/// post_draft_service (für Beiträge), nichts für den Chat-Composer.
class ChatDraftService extends ChangeNotifier {
  ChatDraftService._();
  static final ChatDraftService instance = ChatDraftService._();

  final Map<String, String> _drafts = <String, String>{};

  String get(String conversationId) => _drafts[conversationId] ?? '';

  void set(String conversationId, String text) {
    final t = text.trim();
    if (t.isEmpty) {
      if (_drafts.remove(conversationId) != null) notifyListeners();
      return;
    }
    if (_drafts[conversationId] == text) return;
    _drafts[conversationId] = text;
    notifyListeners();
  }

  void clear(String conversationId) {
    if (_drafts.remove(conversationId) != null) notifyListeners();
  }

  void clearAll() {
    if (_drafts.isEmpty) return;
    _drafts.clear();
    notifyListeners();
  }
}
