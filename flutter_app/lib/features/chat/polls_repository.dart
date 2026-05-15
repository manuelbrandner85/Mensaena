import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';

/// Datenmodell für eine aktive Umfrage in einem Community-Channel.
/// Pendant zur Web-`Poll`-Type in ChatView.tsx.
class ChannelPoll {
  const ChannelPoll({
    required this.id,
    required this.channelId,
    required this.createdBy,
    required this.question,
    required this.options,
    required this.createdAt,
    this.endsAt,
  });

  final String id;
  final String channelId;
  final String createdBy;
  final String question;
  final List<String> options;
  final DateTime createdAt;
  final DateTime? endsAt;

  bool get isExpired =>
      endsAt != null && DateTime.now().isAfter(endsAt!);

  factory ChannelPoll.fromJson(Map<String, dynamic> j) {
    final raw = j['options'];
    final opts = <String>[];
    if (raw is List) {
      for (final o in raw) {
        if (o is String) opts.add(o);
      }
    }
    return ChannelPoll(
      id: j['id'] as String,
      channelId: j['channel_id'] as String,
      createdBy: j['created_by'] as String,
      question: j['question'] as String,
      options: opts,
      createdAt: DateTime.parse(j['created_at'] as String),
      endsAt: j['ends_at'] != null
          ? DateTime.tryParse(j['ends_at'] as String)
          : null,
    );
  }
}

/// Repo für channel_polls + poll_votes.
class PollsRepository {
  PollsRepository(this._db);
  final SupabaseClient _db;

  /// Liste der aktiven Polls in einem Channel (jüngste zuerst).
  Future<List<ChannelPoll>> listForChannel(String channelId,
      {int limit = 20,}) async {
    final rows = await _db
        .from('channel_polls')
        .select()
        .eq('channel_id', channelId)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(ChannelPoll.fromJson).toList(growable: false);
  }

  /// Erstellt eine neue Umfrage. `endsAt` optional (offene Umfrage).
  Future<ChannelPoll> create({
    required String channelId,
    required String question,
    required List<String> options,
    DateTime? endsAt,
  }) async {
    final user = _db.auth.currentUser;
    if (user == null) throw Exception('Nicht eingeloggt');
    final cleanOptions =
        options.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (cleanOptions.length < 2) {
      throw Exception('Mindestens 2 Optionen nötig');
    }
    final row = await _db
        .from('channel_polls')
        .insert({
          'channel_id': channelId,
          'created_by': user.id,
          'question': question.trim(),
          'options': cleanOptions,
          if (endsAt != null) 'ends_at': endsAt.toUtc().toIso8601String(),
        })
        .select()
        .single();
    return ChannelPoll.fromJson(row);
  }

  /// Holt alle Votes für eine Umfrage. Map: optionIndex → User-IDs.
  Future<Map<int, List<String>>> votesFor(String pollId) async {
    final rows = await _db
        .from('poll_votes')
        .select('option_index, user_id')
        .eq('poll_id', pollId);
    final out = <int, List<String>>{};
    for (final r in rows) {
      final idx = r['option_index'] as int?;
      final uid = r['user_id'] as String?;
      if (idx == null || uid == null) continue;
      out.putIfAbsent(idx, () => []).add(uid);
    }
    return out;
  }

  /// Setzt die Stimme des aktuellen Users. Vorhandene Stimme wird ersetzt.
  /// `optionIndex == null` entfernt die Stimme (Vote zurücknehmen).
  Future<void> vote({
    required String pollId,
    required int? optionIndex,
  }) async {
    final user = _db.auth.currentUser;
    if (user == null) throw Exception('Nicht eingeloggt');
    // Erst alte Stimme(n) entfernen — DB hat ggf. UNIQUE-Constraint, aber wir
    // sind defensiv und löschen sicherheitshalber.
    await _db
        .from('poll_votes')
        .delete()
        .eq('poll_id', pollId)
        .eq('user_id', user.id);
    if (optionIndex == null) return;
    await _db.from('poll_votes').insert({
      'poll_id': pollId,
      'user_id': user.id,
      'option_index': optionIndex,
    });
  }

  /// Schließt eine eigene Umfrage (setzt ends_at = now).
  Future<void> closePoll(String pollId) async {
    await _db.from('channel_polls').update({
      'ends_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', pollId);
  }

  /// Löscht eine eigene Umfrage. Cascading delete erledigt poll_votes.
  Future<void> deletePoll(String pollId) async {
    await _db.from('channel_polls').delete().eq('id', pollId);
  }
}

final pollsRepositoryProvider = Provider<PollsRepository>(
  (ref) => PollsRepository(ref.read(supabaseProvider)),
);
