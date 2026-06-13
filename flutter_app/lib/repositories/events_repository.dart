import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

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

  // ── E2: Saved Events (bookmark, unabhängig vom RSVP) ────────────

  static Future<bool> isSaved(String eventId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      final rows = await sb
          .from('saved_events')
          .select('event_id')
          .eq('user_id', uid)
          .eq('event_id', eventId)
          .limit(1);
      return (rows as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Toggle bookmark. Returns the new saved-state (true = jetzt gespeichert).
  /// Optional `reminderMinutesBefore` wird in der saved_events-Row hinterlegt
  /// (das eigentliche Scheduling übernimmt `EventReminderService`).
  static Future<bool> toggleSave(
    String eventId, {
    int? reminderMinutesBefore,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    final currently = await isSaved(eventId);
    try {
      if (currently) {
        await sb
            .from('saved_events')
            .delete()
            .eq('user_id', uid)
            .eq('event_id', eventId);
        return false;
      }
      await sb.from('saved_events').insert({
        'user_id': uid,
        'event_id': eventId,
        if (reminderMinutesBefore != null)
          'reminder_minutes_before': reminderMinutesBefore,
      });
      return true;
    } catch (_) {
      return currently;
    }
  }

  static Future<List<String>> listSavedEventIds() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const [];
    try {
      final rows = await sb
          .from('saved_events')
          .select('event_id')
          .eq('user_id', uid);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map((r) => r['event_id'] as String)
          .toList();
    } catch (_) {
      return const [];
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

  /// Erstellt ein Event mit allen Feldern. Returns event-id bei Erfolg, null sonst.
  static Future<String?> create({
    required String title,
    String? description,
    required String category,
    required DateTime startDate,
    DateTime? endDate,
    bool isAllDay = false,
    String? locationName,
    String? locationAddress,
    double? latitude,
    double? longitude,
    String? imageUrl,
    int? maxAttendees,
    String? cost,
    String? whatToBring,
    String? contactInfo,
    bool isRecurring = false,
    String? recurringPattern, // 'daily' | 'weekly' | 'monthly'
    bool isOnline = false,
    String? onlineUrl,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await sb.from('events').insert({
        'author_id': uid,
        'title': title,
        if (description != null && description.isNotEmpty)
          'description': description,
        'category': category,
        'start_date': startDate.toUtc().toIso8601String(),
        if (endDate != null) 'end_date': endDate.toUtc().toIso8601String(),
        'is_all_day': isAllDay,
        if (locationName != null && locationName.isNotEmpty)
          'location_name': locationName,
        if (locationAddress != null && locationAddress.isNotEmpty)
          'location_address': locationAddress,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (imageUrl != null) 'image_url': imageUrl,
        if (maxAttendees != null) 'max_attendees': maxAttendees,
        if (cost != null && cost.isNotEmpty) 'cost': cost,
        if (whatToBring != null && whatToBring.isNotEmpty)
          'what_to_bring': whatToBring,
        if (contactInfo != null && contactInfo.isNotEmpty)
          'contact_info': contactInfo,
        'is_recurring': isRecurring,
        if (recurringPattern != null) 'recurring_pattern': recurringPattern,
        'is_online': isOnline,
        if (onlineUrl != null && onlineUrl.isNotEmpty) 'online_url': onlineUrl,
        'status': 'active',
      }).select('id').maybeSingle();
      if (row == null) return null;
      return row['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Bild-Upload zu Supabase Storage. Returns public-URL oder null bei Fehler.
  /// Vorher: silently auf 'chat-images' gefallen, wenn 'event-images' Fehler
  /// warf → Event-Bilder landeten im Chat-Bucket. Jetzt: nur event-images,
  /// Fehler wird sichtbar (debugPrint) und null zurückgegeben, damit die UI
  /// einen Hinweis zeigen kann.
  static Future<String?> uploadEventImage({
    required Uint8List bytes,
    required String userId,
    required String fileExt, // 'jpg' | 'png' | 'webp'
  }) async {
    final filename = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
    final path = '$userId/$filename';
    try {
      await sb.storage.from('event-images').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$fileExt'),
          );
      return sb.storage.from('event-images').getPublicUrl(path);
    } catch (e) {
      debugPrint('uploadEventImage failed: $e');
      return null;
    }
  }

  /// Event-Fotos (neueste zuerst). Best-effort, leere Liste bei Fehler.
  static Future<List<Map<String, dynamic>>> listPhotos(
    String eventId, {
    int limit = 100,
  }) async {
    try {
      final rows = await sb
          .from('event_photos')
          .select()
          .eq('event_id', eventId)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// Hängt ein hochgeladenes Foto (bereits in Storage) an ein Event.
  static Future<bool> addPhoto({
    required String eventId,
    required String imageUrl,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('event_photos').insert({
        'event_id': eventId,
        'user_id': uid,
        'image_url': imageUrl,
      });
      return true;
    } catch (_) {
      return false;
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
