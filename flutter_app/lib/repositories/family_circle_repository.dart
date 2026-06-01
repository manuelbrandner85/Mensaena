import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/location_service.dart';
import '../services/supabase_service.dart';

/// SKILL: supabase + mensaena-features
/// R3: Familien-Kreis — vertrauenswürdige Kontakte + Sicherheits-Alarme.
class FamilyCircleRepository {
  const FamilyCircleRepository._();

  /// Angenommene Kontakte (in beide Richtungen) + Profil der anderen Person.
  static Future<List<Map<String, dynamic>>> myCircle() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const [];
    try {
      final rows = await sb
          .from('trusted_contacts')
          .select('id, owner_id, contact_id, relation_label, status, '
              'created_at, '
              'owner:profiles!trusted_contacts_owner_id_fkey'
              '(id, name, display_name, avatar_url, email), '
              'contact:profiles!trusted_contacts_contact_id_fkey'
              '(id, name, display_name, avatar_url, email)')
          .eq('status', 'accepted')
          .or('owner_id.eq.$uid,contact_id.eq.$uid')
          .order('created_at', ascending: false);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// Eingehende, offene Anfragen (jemand möchte MICH in seinen Kreis).
  static Future<List<Map<String, dynamic>>> incomingRequests() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const [];
    try {
      final rows = await sb
          .from('trusted_contacts')
          .select('id, owner_id, relation_label, created_at, '
              'owner:profiles!trusted_contacts_owner_id_fkey'
              '(id, name, display_name, avatar_url)')
          .eq('contact_id', uid)
          .eq('status', 'pending')
          .order('created_at', ascending: true);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// Von mir gesendete, noch offene Anfragen.
  static Future<List<Map<String, dynamic>>> outgoingRequests() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const [];
    try {
      final rows = await sb
          .from('trusted_contacts')
          .select('id, contact_id, relation_label, created_at, '
              'contact:profiles!trusted_contacts_contact_id_fkey'
              '(id, name, display_name, avatar_url)')
          .eq('owner_id', uid)
          .eq('status', 'pending')
          .order('created_at', ascending: true);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// Kontakt per E-Mail anfragen. Rückgabe: 'ok' | 'not_found' | 'self' |
  /// 'error'.
  static Future<String> requestByEmail(String email, String? relation) async {
    try {
      final res = await sb.rpc<dynamic>('request_trusted_contact', params: {
        'p_email': email.trim(),
        'p_relation': relation,
      });
      return (res as String?) ?? 'error';
    } catch (_) {
      return 'error';
    }
  }

  static Future<bool> acceptRequest(String id) async {
    try {
      await sb.from('trusted_contacts').update({
        'status': 'accepted',
        'decided_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> declineRequest(String id) async {
    try {
      await sb.from('trusted_contacts').update({
        'status': 'declined',
        'decided_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> removeContact(String id) async {
    try {
      await sb.from('trusted_contacts').delete().eq('id', id);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Sicherheits-Alarm an den eigenen Kreis senden. [kind] = 'sos' | 'safe'.
  /// Versucht den aktuellen Standort anzuhängen (best effort).
  static Future<bool> sendAlert({
    required String kind,
    String? message,
    bool includeLocation = true,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    double? lat;
    double? lng;
    if (includeLocation) {
      try {
        final pos = await LocationService.getBestPosition();
        lat = pos?.latitude;
        lng = pos?.longitude;
      } catch (_) {/* Standort optional — Alarm geht trotzdem raus */}
    }
    try {
      await sb.from('circle_alerts').insert({
        'sender_id': uid,
        'kind': kind,
        'message': (message != null && message.trim().isNotEmpty)
            ? message.trim()
            : null,
        if (lat != null) 'latitude': lat,
        if (lng != null) 'longitude': lng,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Letzte Alarme aus meinem Kreis (inkl. eigener), neueste zuerst.
  static Future<List<Map<String, dynamic>>> recentAlerts() async {
    try {
      final rows = await sb
          .from('circle_alerts')
          .select('id, sender_id, kind, message, latitude, longitude, '
              'created_at, '
              'sender:profiles!circle_alerts_sender_id_fkey'
              '(id, name, display_name, avatar_url)')
          .gte('created_at',
              DateTime.now().subtract(const Duration(days: 7))
                  .toUtc()
                  .toIso8601String())
          .order('created_at', ascending: false)
          .limit(30);
      return (rows as List).whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }
}

// ── Providers ──────────────────────────────────────────────────────────
final myCircleProvider = FutureProvider<List<Map<String, dynamic>>>(
    (ref) => FamilyCircleRepository.myCircle());
final circleIncomingProvider = FutureProvider<List<Map<String, dynamic>>>(
    (ref) => FamilyCircleRepository.incomingRequests());
final circleOutgoingProvider = FutureProvider<List<Map<String, dynamic>>>(
    (ref) => FamilyCircleRepository.outgoingRequests());
final circleAlertsProvider = FutureProvider<List<Map<String, dynamic>>>(
    (ref) => FamilyCircleRepository.recentAlerts());
