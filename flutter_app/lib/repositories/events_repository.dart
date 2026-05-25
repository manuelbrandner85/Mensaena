import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/event.dart';
import '../services/supabase_service.dart';

/// SKILL: supabase + mensaena-features
/// Events-Repository: list, getById, create, RSVP per event_attendees.
class EventsRepository {
  const EventsRepository._();

  /// Kommende Events (start_date >= jetzt), sortiert aufsteigend.
  static Future<List<EventItem>> listUpcoming({int limit = 50}) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final rows = await sb
          .from('events')
          .select()
          .gte('start_date', now)
          .neq('status', 'cancelled')
          .order('start_date')
          .limit(limit);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(EventItem.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<EventItem?> getById(String id) async {
    try {
      final row = await sb.from('events').select().eq('id', id).maybeSingle();
      if (row == null) return null;
      return EventItem.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  /// Eigene RSVP-Status fuer ein Event.
  /// Returns going|maybe|declined oder null falls noch keine RSVP.
  static Future<String?> myRsvp(String eventId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await sb
          .from('event_attendees')
          .select('status')
          .eq('event_id', eventId)
          .eq('user_id', uid)
          .maybeSingle();
      return row?['status'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> rsvp({
    required String eventId,
    required String status,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('event_attendees').upsert({
        'event_id': eventId,
        'user_id': uid,
        'status': status,
      }, onConflict: 'event_id,user_id');
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Attendance ──────────────────────────────────────────

  /// Setzt eigenen Anwesenheits-Status. status ∈ ('going', 'interested', 'declined')
  /// Upsert in event_attendees.
  static Future<bool> setAttendance({
    required String eventId,
    required String status,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('event_attendees').upsert({
        'event_id': eventId,
        'user_id': uid,
        'status': status,
      }, onConflict: 'event_id,user_id');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Loescht eigene Teilnahme komplett.
  static Future<bool> removeAttendance(String eventId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('event_attendees')
          .delete()
          .eq('event_id', eventId)
          .eq('user_id', uid);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Laedt alle Teilnehmer mit profiles-Join (name, avatar_url, display_name, trust_score).
  static Future<List<Map<String, dynamic>>> loadAttendees(String eventId) async {
    try {
      final rows = await sb.from('event_attendees')
          .select('*, profiles:user_id(id, name, avatar_url, display_name, trust_score)')
          .eq('event_id', eventId);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  // ── Reminder ────────────────────────────────────────────

  /// Setzt Erinnerung (in Minuten vor Event). Sets reminder_set + reminder_minutes
  /// auf der event_attendees-Row.
  static Future<bool> setReminder({
    required String eventId,
    required int minutes,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('event_attendees').update({
        'reminder_set': true,
        'reminder_minutes': minutes,
      }).eq('event_id', eventId).eq('user_id', uid);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Entfernt Erinnerung (setzt reminder_set=false).
  static Future<bool> removeReminder(String eventId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('event_attendees').update({
        'reminder_set': false,
      }).eq('event_id', eventId).eq('user_id', uid);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Author Actions ──────────────────────────────────────

  /// Author cancelt Event (Status='cancelled').
  static Future<bool> cancelEvent(String eventId) async {
    try {
      await sb.from('events').update({'status': 'cancelled'}).eq('id', eventId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Author loescht Event (hard delete).
  static Future<bool> deleteEvent(String eventId) async {
    try {
      await sb.from('events').delete().eq('id', eventId);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> create({
    required String title,
    required String category,
    required DateTime startDate,
    DateTime? endDate,
    String? description,
    String? locationName,
    String? locationAddress,
    double? latitude,
    double? longitude,
    int? maxAttendees,
    bool isOnline = false,
    String? onlineUrl,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await sb
          .from('events')
          .insert({
            'author_id': uid,
            'title': title,
            'category': category,
            'start_date': startDate.toUtc().toIso8601String(),
            if (endDate != null) 'end_date': endDate.toUtc().toIso8601String(),
            'description': description,
            'location_name': locationName,
            'location_address': locationAddress,
            'latitude': latitude,
            'longitude': longitude,
            'max_attendees': maxAttendees,
            'is_online': isOnline,
            'online_url': onlineUrl,
            'status': 'active',
          })
          .select()
          .single();
      return row['id'] as String?;
    } catch (_) {
      return null;
    }
  }
}

final upcomingEventsProvider =
    FutureProvider<List<EventItem>>((ref) async => EventsRepository.listUpcoming());

final eventDetailProvider =
    FutureProvider.family<EventItem?, String>((ref, id) => EventsRepository.getById(id));

final myRsvpProvider =
    FutureProvider.family<String?, String>((ref, eventId) => EventsRepository.myRsvp(eventId));

/// Teilnehmer-Liste fuer ein Event.
final eventAttendeesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, eventId) => EventsRepository.loadAttendees(eventId),
);
