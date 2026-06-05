/// SKILL: mensaena-architektur
/// Provider für "Mensa". Stil wie mega_providers.dart.
/// Hält den Gesprächsverlauf, sendet die letzten 6 Nachrichten als Gedächtnis
/// und baut eine persönliche Begrüßung (Vorname + Tageszeit).
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/chat_ai_repository.dart';
import '../services/supabase_service.dart';

class ChatAiState {
  const ChatAiState({this.messages = const [], this.isTyping = false});
  final List<ChatAiMessage> messages;
  final bool isTyping;

  ChatAiState copyWith({List<ChatAiMessage>? messages, bool? isTyping}) =>
      ChatAiState(
        messages: messages ?? this.messages,
        isTyping: isTyping ?? this.isTyping,
      );
}

class ChatAiNotifier extends StateNotifier<ChatAiState> {
  ChatAiNotifier(this._repo) : super(const ChatAiState());
  final ChatAiRepository _repo;

  String _screen = '';
  String _lang = 'de';
  String? _firstName;
  bool _greeted = false;

  /// Wird vom FAB beim Öffnen gesetzt (aktueller Screen + Sprache + Vorname).
  void setContext({
    required String screen,
    required String language,
    String? firstName,
  }) {
    _screen = screen;
    _lang = language;
    if (firstName != null && firstName.trim().isNotEmpty) {
      _firstName = _firstNameOnly(firstName);
    }
  }

  /// Nur den ERSTEN Vornamen ("Manuel Brandner" -> "Manuel").
  String _firstNameOnly(String full) => full.trim().split(RegExp(r'\s+')).first;

  /// Tageszeit-Gruß nach LOKALER Geräte-Uhrzeit (Zeitzone des Nutzers).
  String _greetingWord() {
    final h = DateTime.now().hour;
    if (h >= 5 && h <= 10) return 'assistant.greeting_morning'.tr();
    if (h >= 11 && h <= 17) return 'assistant.greeting_day'.tr();
    if (h >= 18 && h <= 21) return 'assistant.greeting_evening'.tr();
    return 'assistant.greeting_late'.tr(); // 22–4
  }

  /// Einmalige Begrüßung. Lädt bei Bedarf den Vornamen aus profiles
  /// (name, sonst nickname). Idempotent — fügt nur einmal eine Nachricht ein.
  Future<void> ensureGreeting() async {
    if (_greeted) return;
    _greeted = true;

    if (_firstName == null) {
      try {
        final uid = SupabaseService.currentUser?.id;
        if (uid != null) {
          final row = await SupabaseService.client
              .from('profiles')
              .select('name, nickname')
              .eq('id', uid)
              .maybeSingle();
          final name = (row?['name'] ?? '').toString().trim();
          final nick = (row?['nickname'] ?? '').toString().trim();
          final src = name.isNotEmpty ? name : nick;
          if (src.isNotEmpty) _firstName = _firstNameOnly(src);
        }
      } catch (_) {
        // Begrüßung ohne Namen ist ein gültiger Zustand.
      }
    }

    final greeting = _greetingWord();
    final text = (_firstName != null && _firstName!.isNotEmpty)
        ? 'assistant.greeting_named'
            .tr(namedArgs: {'greeting': greeting, 'name': _firstName!})
        : 'assistant.greeting_plain'.tr(namedArgs: {'greeting': greeting});

    state = state.copyWith(
      messages: [...state.messages, ChatAiMessage(text: text, fromUser: false)],
    );
  }

  Future<void> send(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || state.isTyping) return;

    state = state.copyWith(
      messages: [...state.messages, ChatAiMessage(text: msg, fromUser: true)],
      isTyping: true,
    );

    // Gedächtnis: letzte 6 Nachrichten als history.
    final history = state.messages
        .where((m) => m.text.isNotEmpty)
        .map((m) => {
              'role': m.fromUser ? 'user' : 'assistant',
              'content': m.text,
            })
        .toList();
    final trimmed =
        history.length > 6 ? history.sublist(history.length - 6) : history;

    try {
      final res = await _repo.ask(
        message: msg,
        history: trimmed,
        currentScreen: _screen,
        lang: _lang,
        firstName: _firstName,
      );
      final reply = res.reply.isNotEmpty
          ? res.reply
          : 'assistant.error'.tr();
      state = state.copyWith(
        isTyping: false,
        messages: [
          ...state.messages,
          ChatAiMessage(
            text: reply,
            fromUser: false,
            navRoute: res.navRoute,
            navLabel: res.navLabel,
            question: msg,
          ),
        ],
      );
    } catch (_) {
      state = state.copyWith(
        isTyping: false,
        messages: [
          ...state.messages,
          ChatAiMessage(text: 'assistant.error'.tr(), fromUser: false),
        ],
      );
    }
  }

  Future<void> rate(int rating, String question, String answer) async {
    try {
      await _repo.sendFeedback(
          rating: rating, question: question, answer: answer);
    } catch (_) {
      // Feedback ist best-effort.
    }
  }
}

final chatAiRepositoryProvider =
    Provider<ChatAiRepository>((ref) => ChatAiRepository());

final chatAiProvider =
    StateNotifierProvider<ChatAiNotifier, ChatAiState>(
  (ref) => ChatAiNotifier(ref.read(chatAiRepositoryProvider)),
);
