import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';
import 'models.dart';

final eventsRepositoryProvider = Provider<EventsRepository>(
  (ref) => EventsRepository(ref.read(supabaseProvider)),
);

class EventsRepository {
  EventsRepository(this._db);
  final SupabaseClient _db;

  Future<List<EventItem>> upcoming({String category = 'all'}) async {
    var q = _db
        .from('events')
        .select(
          '*, profiles:author_id(name, display_name, avatar_url, trust_score)',
        )
        .gte('start_date', DateTime.now().toIso8601String())
        .eq('status', 'active');
    if (category != 'all') q = q.eq('category', category);
    final rows = await q.order('start_date').limit(50);
    return rows.map(EventItem.fromJson).toList();
  }

  Future<EventItem?> fetch(String id) async {
    final row = await _db
        .from('events')
        .select(
          '*, profiles:author_id(name, display_name, avatar_url, trust_score)',
        )
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return EventItem.fromJson(row);
  }

  /// Map of eventId → AttendeeStatus for the current user.
  Future<Map<String, AttendeeStatus>> myAttendances() async {
    final user = _db.auth.currentUser;
    if (user == null) return const {};
    final rows = await _db
        .from('event_attendees')
        .select('event_id, status')
        .eq('user_id', user.id);
    final out = <String, AttendeeStatus>{};
    for (final r in rows) {
      final s = AttendeeStatus.fromString(r['status'] as String?);
      if (s != null) out[r['event_id'] as String] = s;
    }
    return out;
  }

  Future<void> setAttendance(String eventId, AttendeeStatus status) async {
    final user = _db.auth.currentUser;
    if (user == null) throw Exception('Nicht eingeloggt');
    await _db.from('event_attendees').upsert(<String, dynamic>{
      'event_id': eventId,
      'user_id': user.id,
      'status': status.value,
    });
  }

  Future<void> withdrawAttendance(String eventId) async {
    final user = _db.auth.currentUser;
    if (user == null) return;
    await _db
        .from('event_attendees')
        .delete()
        .eq('event_id', eventId)
        .eq('user_id', user.id);
  }
}
