import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/crisis.dart';
import '../models/crisis_helper.dart';
import '../models/crisis_update.dart';
import '../models/emergency_number.dart';
import '../services/supabase_service.dart';

/// SKILL: supabase + mensaena-features
/// Crisis-Repository: aktive Krisen, Helpers (Realtime), Updates (Realtime).
class CrisisRepository {
  const CrisisRepository._();

  /// Alle aktiven Krisen (status != 'resolved' && resolved_at IS NULL).
  static Future<List<Crisis>> listActive() async {
    try {
      final rows = await sb
          .from('crises')
          .select()
          .filter('resolved_at', 'is', null)
          .neq('status', 'resolved')
          .order('created_at', ascending: false);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(Crisis.fromJson)
          .toList();
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
          })
          .select()
          .single();
      return row['id'] as String?;
    } catch (_) {
      return null;
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
}

// ── Providers ────────────────────────────────────────────────────────────
final activeCrisesProvider = FutureProvider<List<Crisis>>((ref) async {
  return CrisisRepository.listActive();
});

final crisisDetailProvider =
    FutureProvider.family<Crisis?, String>((ref, id) async {
  return CrisisRepository.getById(id);
});

final crisisHelpersStreamProvider =
    StreamProvider.family<List<CrisisHelper>, String>((ref, crisisId) {
  return CrisisRepository.watchHelpers(crisisId);
});

final crisisUpdatesStreamProvider =
    StreamProvider.family<List<CrisisUpdate>, String>((ref, crisisId) {
  return CrisisRepository.watchUpdates(crisisId);
});

final emergencyNumbersProvider =
    FutureProvider.family<List<EmergencyNumber>, String>((ref, country) async {
  return EmergencyNumbersRepository.listForCountry(country);
});
