import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mensaena/models/event.dart';

class EventService {
  final SupabaseClient _client;

  EventService(this._client);

  Future<List<Event>> getEvents({
    String? status,
    String? category,
    String? search,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
    var query = _client
        .from('events')
        .select('*, profiles!events_author_id_fkey(id, name, nickname, display_name, avatar_url, trust_score)');

    if (status != null) {
      query = query.eq('status', status);
    }
    if (category != null) {
      query = query.eq('category', category);
    }
    if (search != null && search.isNotEmpty) {
      query = query.or('title.ilike.%$search%,description.ilike.%$search%');
    }

    final data = await query.order('start_date').range(offset, offset + limit - 1);
    return (data as List).map((e) => Event.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Event>> getEventsByMonth(int year, int month) async {
    final start = DateTime(year, month, 1).toIso8601String().split('T')[0];
    final end = DateTime(year, month + 1, 0).toIso8601String().split('T')[0];
    final data = await _client
        .from('events')
        .select('*, profiles!events_author_id_fkey(id, name, nickname, display_name, avatar_url, trust_score)')
        .gte('start_date', start)
        .lte('start_date', end)
        .order('start_date');
    return (data as List).map((e) => Event.fromJson(e)).toList();
  }

  Future<List<Event>> getUpcomingEvents({int limit = 10}) async {
    final now = DateTime.now().toIso8601String().split('T')[0];
    final data = await _client
        .from('events')
        .select('*, profiles!events_author_id_fkey(id, name, nickname, display_name, avatar_url, trust_score)')
        .gte('start_date', now)
        .eq('status', 'upcoming')
        .order('start_date')
        .limit(limit);
    return (data as List).map((e) => Event.fromJson(e)).toList();
  }

  Future<Event?> getEvent(String eventId) async {
    final data = await _client
        .from('events')
        .select('*, profiles!events_author_id_fkey(id, name, nickname, display_name, avatar_url, trust_score)')
        .eq('id', eventId)
        .maybeSingle();
    if (data == null) return null;
    return Event.fromJson(data);
  }

  Future<Event> createEvent(Map<String, dynamic> eventData) async {
    final data = await _client
        .from('events')
        .insert(eventData)
        .select()
        .single();
    return Event.fromJson(data);
  }

  Future<void> updateEvent(
      String eventId, Map<String, dynamic> updates) async {
    await _client.from('events').update(updates).eq('id', eventId);
  }

  Future<void> deleteEvent(String eventId) async {
    await _client.from('events').delete().eq('id', eventId);
  }

  // Attendance
  Future<void> setAttendance(
      String eventId, String userId, String status) async {
    await _client.from('event_attendees').upsert({
      'event_id': eventId,
      'user_id': userId,
      'status': status,
    });
  }

  Future<void> removeAttendance(String eventId, String userId) async {
    await _client
        .from('event_attendees')
        .delete()
        .eq('event_id', eventId)
        .eq('user_id', userId);
  }

  Future<List<Map<String, dynamic>>> getAttendees(String eventId) async {
    final data = await _client
        .from('event_attendees')
        .select('*, profiles:user_id(id, name, nickname, avatar_url)')
        .eq('event_id', eventId);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<String?> getUserAttendance(String eventId, String userId) async {
    final data = await _client
        .from('event_attendees')
        .select('status')
        .eq('event_id', eventId)
        .eq('user_id', userId)
        .maybeSingle();
    return data?['status'] as String?;
  }

  // Volunteer Signups
  Future<void> signUpVolunteer(String eventId, String userId, String role) async {
    await _client.from('volunteer_signups').insert({'event_id': eventId, 'user_id': userId, 'role': role, 'status': 'active'});
  }

  Future<List<Map<String, dynamic>>> getVolunteers(String eventId) async {
    final data = await _client.from('volunteer_signups').select('*').eq('event_id', eventId).order('created_at');
    return List<Map<String, dynamic>>.from(data);
  }

  // Rideshares
  Future<List<Map<String, dynamic>>> getRideshares(String eventId) async {
    final data = await _client.from('event_rideshares').select('*').eq('event_id', eventId).order('departure_time');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> offerRideshare(Map<String, dynamic> rideData) async {
    await _client.from('event_rideshares').insert(rideData);
  }
}
