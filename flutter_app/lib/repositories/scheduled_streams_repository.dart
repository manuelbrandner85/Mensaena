/// SKILL: supabase + mensaena-features
/// ScheduledStreamsRepository — geplante Livestreams + Erinnerungen
/// (scheduled_streams + scheduled_stream_reminders). Vorher lagen diese
/// 5 Queries direkt im scheduled_streams_screen (sb.from-Baseline).
library;

import '../services/supabase_service.dart';

class ScheduledStreamsRepository {
  const ScheduledStreamsRepository._();

  /// Kommende, nicht abgesagte Streams (max 100, frueheste zuerst).
  static Future<List<Map<String, dynamic>>> listUpcoming() async {
    try {
      final rows = await sb
          .from('scheduled_streams')
          .select()
          .eq('is_cancelled', false)
          .gte('scheduled_at', DateTime.now().toUtc().toIso8601String())
          .order('scheduled_at', ascending: true)
          .limit(100);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// Stream-IDs, fuer die der User eine Erinnerung gesetzt hat.
  static Future<Set<String>> myReminderIds(String userId) async {
    try {
      final rows = await sb
          .from('scheduled_stream_reminders')
          .select('stream_id')
          .eq('user_id', userId);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map((r) => r['stream_id'] as String)
          .toSet();
    } catch (_) {
      return const {};
    }
  }

  static Future<void> addReminder({
    required String streamId,
    required String userId,
  }) async {
    await sb.from('scheduled_stream_reminders').insert({
      'stream_id': streamId,
      'user_id': userId,
    });
  }

  static Future<void> removeReminder({
    required String streamId,
    required String userId,
  }) async {
    await sb
        .from('scheduled_stream_reminders')
        .delete()
        .eq('stream_id', streamId)
        .eq('user_id', userId);
  }

  /// Neuen geplanten Stream anlegen.
  static Future<void> create({
    required String hostId,
    required String title,
    String? description,
    required DateTime scheduledAt,
  }) async {
    await sb.from('scheduled_streams').insert({
      'host_id': hostId,
      'title': title,
      'description': description,
      'scheduled_at': scheduledAt.toIso8601String(),
    });
  }
}
