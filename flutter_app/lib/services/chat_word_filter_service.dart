import 'package:flutter/foundation.dart';

/// Leichter Wortfilter für Chat-Nachrichten.
///
/// Blockt beleidigende Inhalte *vor* dem Senden. Ziel ist nicht totale
/// Sicherheit — Server + Mod-Queue (admin_chat_moderation) sind die zweite
/// Instanz —, sondern sofortiges Feedback an den User, damit bekannte
/// Worte gar nicht erst rausgehen. Besonders relevant für den öffentlich
/// freigegebenen Community- und Livestream-Chat.
///
/// Die Liste ist bewusst konservativ (offensichtliche Slurs + Harassment-
/// Begriffe). Erweiterbar über [addCustomWords] aus einem späteren Server-
/// Config-Feed.
///
/// Adaptiert aus Weltenbibliothek-App (manuelbrandner85/Weltenbibliothekapp,
/// lib/services/chat/chat_word_filter_service.dart).
class ChatWordFilterService extends ChangeNotifier {
  ChatWordFilterService._();
  static final ChatWordFilterService instance = ChatWordFilterService._();

  /// Standardliste — DE + EN, case-insensitive matching als ganzes Wort.
  /// Bewusst klein gehalten, damit False-Positives selten sind.
  static const List<String> _defaultWords = <String>[
    // Generische Slurs (beide Sprachen, gängig)
    'nazi', 'hitler', 'heil hitler', 'sieg heil',
    'nigger', 'negro', 'nigga',
    'faggot', 'schwuchtel',
    'retard', 'retarded', 'spasti',
    'kys', 'killyourself',
    // Sex-bezogene Beleidigungen
    'fotze', 'hurensohn', 'hurentochter',
    'arschficker',
    // Harte Drohungen
    'ich töte dich', 'umbringen',
  ];

  /// Zusätzliche Worte (z.B. aus Server-Config).
  final Set<String> _customWords = <String>{};

  RegExp? _regex;

  ChatWordFilterService get init {
    _rebuildRegex();
    return this;
  }

  void addCustomWords(Iterable<String> words) {
    final before = _customWords.length;
    _customWords.addAll(
        words.map((w) => w.trim().toLowerCase()).where((w) => w.isNotEmpty));
    if (_customWords.length != before) {
      _rebuildRegex();
      notifyListeners();
    }
  }

  void clearCustomWords() {
    if (_customWords.isEmpty) return;
    _customWords.clear();
    _rebuildRegex();
    notifyListeners();
  }

  /// Liefert das erste gefundene Wort zurück, oder null wenn sauber.
  String? firstHit(String text) {
    if (_regex == null) _rebuildRegex();
    final r = _regex;
    if (r == null) return null;
    final m = r.firstMatch(text.toLowerCase());
    // Gruppe 2 ist das eigentliche Wort (1 + 3 sind die Wortgrenzen).
    return m?.group(2);
  }

  bool isClean(String text) => firstHit(text) == null;

  void _rebuildRegex() {
    final all = <String>{..._defaultWords, ..._customWords}
        .where((w) => w.trim().isNotEmpty)
        .map((w) => RegExp.escape(w.toLowerCase()))
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length)); // längste zuerst
    if (all.isEmpty) {
      _regex = null;
      return;
    }
    // Wortgrenze am Anfang/Ende — bei Mehrwortphrasen (z.B. "heil hitler")
    // reicht das nicht perfekt, aber für einzelne Begriffe funktioniert's.
    _regex =
        RegExp(r'(^|\W)(' + all.join('|') + r')(\W|$)', caseSensitive: false);
  }
}
