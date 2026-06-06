import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/crisis.dart';
import '../models/crisis_helper.dart';
import '../models/crisis_update.dart';
import '../models/emergency_number.dart';
import '../services/location_service.dart';
import '../services/supabase_service.dart';
import 'profiles_repository.dart';

/// SKILL: supabase + mensaena-features
/// Crisis-Repository: aktive Krisen, Helpers (Realtime), Updates (Realtime).
class CrisisRepository {
  const CrisisRepository._();

  /// Aktive Krisen (status != 'resolved' && resolved_at IS NULL).
  /// User-Wunsch: nach eingestelltem Standort filtern. [lat]/[lng] = Profil-
  /// Standort; ohne Angabe → global. SICHERHEIT: Krisen OHNE Koordinaten
  /// werden IMMER gezeigt (nie eine Notlage verstecken).
  static Future<List<Crisis>> listActive({
    double? lat,
    double? lng,
    double radiusKm = 150,
  }) async {
    try {
      final rows = await sb
          .from('crises')
          .select()
          .filter('resolved_at', 'is', null)
          .neq('status', 'resolved')
          .order('created_at', ascending: false);
      final all = (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(Crisis.fromJson)
          .toList();
      if (lat == null || lng == null) return all;
      return all.where((c) {
        if (c.latitude == null || c.longitude == null) return true; // safety
        final d = LocationService.haversineKm(
            lat, lng, c.latitude!, c.longitude!);
        return d <= radiusKm;
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<Crisis?> getById(String id) async {
    try {
      final row =
          await sb.from('crises').select().eq('id', id).maybeSingle();
      if (row == null) return null;
      return Crisis.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  /// Realtime-Stream: alle Helpers fuer eine Krise.
  static Stream<List<CrisisHelper>> watchHelpers(String crisisId) {
    return sb
        .from('crisis_helpers')
        .stream(primaryKey: ['id'])
        .eq('crisis_id', crisisId)
        .order('created_at')
        .map((rows) => rows.map(CrisisHelper.fromJson).toList());
  }

  /// Realtime-Stream: alle Updates fuer eine Krise.
  static Stream<List<CrisisUpdate>> watchUpdates(String crisisId) {
    return sb
        .from('crisis_updates')
        .stream(primaryKey: ['id'])
        .eq('crisis_id', crisisId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(CrisisUpdate.fromJson).toList());
  }

  /// Hilfe anbieten — INSERT in crisis_helpers.
  static Future<bool> offerHelp({
    required String crisisId,
    String? message,
    int? etaMinutes,
    List<String> skills = const [],
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('crisis_helpers').upsert({
        'crisis_id': crisisId,
        'user_id': uid,
        'status': 'offered',
        'message': message,
        'eta_minutes': etaMinutes,
        'skills': skills,
      }, onConflict: 'crisis_id,user_id');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Status des eigenen Helper-Eintrags aktualisieren.
  static Future<bool> updateHelperStatus({
    required String crisisId,
    required String status,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb
          .from('crisis_helpers')
          .update({'status': status})
          .eq('crisis_id', crisisId)
          .eq('user_id', uid);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Crisis erstellen.
  static Future<String?> create({
    required String title,
    required String description,
    required String category,
    required String urgency,
    String? locationText,
    double? latitude,
    double? longitude,
    double? radiusKm,
    bool isAnonymous = false,
    // Erweiterte, krisen-spezifische Felder (nutzen bestehende Spalten).
    int? affectedCount,
    int? neededHelpers,
    List<String> neededSkills = const [],
    List<String> neededResources = const [],
    String? contactName,
    String? contactPhone,
    List<String> imageUrls = const [],
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await sb
          .from('crises')
          .insert({
            'creator_id': uid,
            'title': title,
            'description': description,
            'category': category,
            'urgency': urgency,
            'status': 'active',
            'location_text': locationText,
            'latitude': latitude,
            'longitude': longitude,
            'radius_km': radiusKm,
            'is_anonymous': isAnonymous,
            if (affectedCount != null) 'affected_count': affectedCount,
            if (neededHelpers != null) 'needed_helpers': neededHelpers,
            if (neededSkills.isNotEmpty) 'needed_skills': neededSkills,
            if (neededResources.isNotEmpty)
              'needed_resources': neededResources,
            if (contactName != null && contactName.isNotEmpty)
              'contact_name': contactName,
            if (contactPhone != null && contactPhone.isNotEmpty)
              'contact_phone': contactPhone,
            if (imageUrls.isNotEmpty) 'image_urls': imageUrls,
          })
          .select()
          .maybeSingle();
      if (row == null) return null;
      return row['id'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ── R2: Krisen-Team — Aufgaben-Koordination ────────────────────────
  /// Realtime-Stream aller Aufgaben einer Krise (offen zuerst).
  static Stream<List<Map<String, dynamic>>> watchTasks(String crisisId) {
    return sb
        .from('crisis_tasks')
        .stream(primaryKey: ['id'])
        .eq('crisis_id', crisisId)
        .order('created_at')
        .map((rows) => rows.whereType<Map<String, dynamic>>().toList());
  }

  /// Neue Aufgabe anlegen.
  static Future<bool> createTask({
    required String crisisId,
    required String title,
    String? description,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('crisis_tasks').insert({
        'crisis_id': crisisId,
        'created_by': uid,
        'title': title.trim(),
        'description': (description != null && description.trim().isNotEmpty)
            ? description.trim()
            : null,
        'status': 'open',
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Aufgabe übernehmen (assigned_to = ich, status = claimed).
  static Future<bool> claimTask(String taskId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('crisis_tasks').update({
        'assigned_to': uid,
        'status': 'claimed',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', taskId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Aufgabe als erledigt markieren.
  static Future<bool> completeTask(String taskId) async {
    try {
      await sb.from('crisis_tasks').update({
        'status': 'done',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', taskId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Aufgabe wieder freigeben (zurück auf offen, niemandem zugewiesen).
  static Future<bool> releaseTask(String taskId) async {
    try {
      await sb.from('crisis_tasks').update({
        'assigned_to': null,
        'status': 'open',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', taskId);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteTask(String taskId) async {
    try {
      await sb.from('crisis_tasks').delete().eq('id', taskId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Status-Update an Krise anhaengen.
  static Future<bool> addUpdate({
    required String crisisId,
    required String content,
    String updateType = 'info',
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('crisis_updates').insert({
        'crisis_id': crisisId,
        'author_id': uid,
        'content': content,
        'update_type': updateType,
      });
      return true;
    } catch (_) {
      return false;
    }
  }
}

class EmergencyNumbersRepository {
  const EmergencyNumbersRepository._();

  static Future<List<EmergencyNumber>> listForCountry(
    String country,
  ) async {
    try {
      final rows = await sb
          .from('emergency_numbers')
          .select()
          .eq('country', country)
          .order('sort_order');
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(EmergencyNumber.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Lädt ALLE Notrufnummern (alle Länder) für Country-Tabs in Resources-Screen.
  static Future<List<EmergencyNumber>> listAll() async {
    try {
      final rows = await sb
          .from('emergency_numbers')
          .select()
          .order('country')
          .order('sort_order');
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(EmergencyNumber.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

// ── Providers ────────────────────────────────────────────────────────────
final activeCrisesProvider = FutureProvider<List<Crisis>>((ref) async {
  // User-Wunsch: Krisen nach eingestelltem (Profil-)Standort filtern.
  final profile = ref.watch(myProfileProvider).asData?.value;
  final lat = profile?.latitude ?? profile?.homeLat;
  final lng = profile?.longitude ?? profile?.homeLng;
  return CrisisRepository.listActive(lat: lat, lng: lng);
});

final crisisDetailProvider =
    FutureProvider.family<Crisis?, String>((ref, id) async {
  return CrisisRepository.getById(id);
});

// MEMORY-FIX: autoDispose auf alle Crisis-Detail-Stream-Provider.
// Ein geöffneter Krisen-Screen öffnete 3 Supabase-Realtime-Channels,
// die nach Verlassen des Screens nie geschlossen wurden.
final crisisHelpersStreamProvider =
    StreamProvider.family.autoDispose<List<CrisisHelper>, String>((ref, crisisId) {
  return CrisisRepository.watchHelpers(crisisId);
});

final crisisUpdatesStreamProvider =
    StreamProvider.family.autoDispose<List<CrisisUpdate>, String>((ref, crisisId) {
  return CrisisRepository.watchUpdates(crisisId);
});

/// R2: Aufgaben-Stream für das Krisen-Team.
final crisisTasksStreamProvider =
    StreamProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, crisisId) {
  return CrisisRepository.watchTasks(crisisId);
});

final emergencyNumbersProvider =
    FutureProvider.family<List<EmergencyNumber>, String>((ref, country) async {
  return EmergencyNumbersRepository.listForCountry(country);
});

final allEmergencyNumbersProvider = FutureProvider<List<EmergencyNumber>>((ref) async {
  return EmergencyNumbersRepository.listAll();
});
