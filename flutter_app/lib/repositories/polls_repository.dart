/// SKILL: supabase + mensaena-features
/// PollsRepository — Umfragen an Posts (post_polls + post_poll_votes).
/// Vorher lagen diese Queries direkt in post_poll_widget /
/// poll_create_sheet (UI-Schicht-Verstoss, sb.from-Baseline).
library;

import '../services/supabase_service.dart';

class PollsRepository {
  const PollsRepository._();

  /// Roh-Daten fuer eine Post-Umfrage: Poll-Row + alle Votes.
  /// null = Post hat keine Umfrage. Wirft bei DB-Fehlern (Aufrufer
  /// faengt — der Provider mappt auf "keine Umfrage").
  static Future<({Map<String, dynamic> poll, List<Map<String, dynamic>> votes})?>
      fetch(String postId) async {
    final pollRow = await sb
        .from('post_polls')
        .select()
        .eq('post_id', postId)
        .maybeSingle();
    if (pollRow == null) return null;
    final votes = await sb
        .from('post_poll_votes')
        .select('user_id, option_index')
        .eq('poll_id', pollRow['id'] as String);
    return (
      poll: pollRow,
      votes: (votes as List).whereType<Map<String, dynamic>>().toList(),
    );
  }

  /// Erststimme abgeben.
  static Future<void> vote({
    required String pollId,
    required String userId,
    required int optionIndex,
  }) async {
    await sb.from('post_poll_votes').insert({
      'poll_id': pollId,
      'user_id': userId,
      'option_index': optionIndex,
    });
  }

  /// Eigene Stimme aendern.
  static Future<void> changeVote({
    required String pollId,
    required String userId,
    required int optionIndex,
  }) async {
    await sb
        .from('post_poll_votes')
        .update({'option_index': optionIndex})
        .eq('poll_id', pollId)
        .eq('user_id', userId);
  }

  /// Neue Umfrage an einem Post anlegen.
  static Future<void> create({
    required String postId,
    required String question,
    required List<String> options,
    Duration? closesIn,
  }) async {
    await sb.from('post_polls').insert({
      'post_id': postId,
      'question': question,
      'options': options,
      'closes_at': closesIn == null
          ? null
          // UTC speichern: toIso8601String() einer LOKALEN Zeit hat keinen
          // Zeitzonen-Offset → Postgres (timestamptz) liest sie als UTC und
          // verschiebt um den lokalen Offset. .toUtc() macht den Wert eindeutig
          // (passt zur Lese-Seite, die closes_at bereits via .toUtc() parst).
          : DateTime.now().toUtc().add(closesIn).toIso8601String(),
    });
  }
}
