/// SKILL: mensaena-features + supabase
/// Repository fuer post_contact_preferences + post_contact_requests.
/// Inkl. Datenschutz-Logik: getRevealedContactInfo() liefert Daten nur
/// wenn der aktuelle User eine akzeptierte Anfrage hat (R7).
library;

import 'package:flutter/foundation.dart' show debugPrint;

import '../models/post_contact_preference.dart';
import '../models/post_contact_request.dart';
import '../services/supabase_service.dart';

class PostContactRepository {
  const PostContactRepository();

  // ── Preferences ────────────────────────────────────────────────────

  Future<PostContactPreference?> getPreferencesForPost(String postId) async {
    try {
      final row = await sb
          .from('post_contact_preferences')
          .select()
          .eq('post_id', postId)
          .maybeSingle();
      if (row == null) return null;
      return PostContactPreference.fromJson(row);
    } catch (e) {
      debugPrint('[PostContact] getPreferencesForPost failed: $e');
      return null;
    }
  }

  Future<bool> upsertPreferences(PostContactPreference pref) async {
    try {
      await sb
          .from('post_contact_preferences')
          .upsert(pref.toJson(), onConflict: 'post_id');
      return true;
    } catch (e) {
      debugPrint('[PostContact] upsertPreferences failed: $e');
      return false;
    }
  }

  Future<bool> deletePreferences(String postId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb
          .from('post_contact_preferences')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', uid);
      return true;
    } catch (e) {
      debugPrint('[PostContact] deletePreferences failed: $e');
      return false;
    }
  }

  // ── Requests ───────────────────────────────────────────────────────

  /// Wirft StateError('already_open') wenn bereits pending/accepted
  /// Anfrage des aktuellen Users existiert (R17 — Duplicate-Schutz).
  Future<PostContactRequest> createContactRequest({
    required String postId,
    required String postOwnerId,
    required String contactMethod,
    String? message,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) {
      throw StateError('not_authenticated');
    }
    // Existiert schon eine offene Anfrage?
    final existing = await sb
        .from('post_contact_requests')
        .select('id, status')
        .eq('post_id', postId)
        .eq('requester_id', uid)
        .inFilter('status', ['pending', 'accepted'])
        .limit(1);
    if ((existing as List).isNotEmpty) {
      throw StateError('already_open');
    }
    // .maybeSingle() statt .single(): wenn RLS den Returning-Select auf 0
    // Zeilen bringt, würde .single() eine rohe PostgrestException werfen.
    // So bleibt das Fehlermodell konsistent (StateError, vom Aufrufer
    // freundlich behandelt) statt eines ungefangenen Crashs.
    final row = await sb
        .from('post_contact_requests')
        .insert({
          'post_id': postId,
          'requester_id': uid,
          'post_owner_id': postOwnerId,
          'contact_method': contactMethod,
          if (message != null && message.isNotEmpty) 'message': message,
        })
        .select()
        .maybeSingle();
    if (row == null) {
      throw StateError('insert_failed');
    }
    return PostContactRequest.fromJson(row);
  }

  Future<bool> respondToRequest(String requestId, String status) async {
    try {
      await sb.from('post_contact_requests').update({
        'status': status,
        'responded_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', requestId);
      return true;
    } catch (e) {
      debugPrint('[PostContact] respondToRequest failed: $e');
      return false;
    }
  }

  Future<bool> markCompleted(String requestId) =>
      respondToRequest(requestId, 'completed');

  Future<List<PostContactRequest>> getRequestsForPost(String postId) async {
    try {
      final rows = await sb
          .from('post_contact_requests')
          .select(
              'id, post_id, requester_id, post_owner_id, contact_method, status, message, responded_at, created_at, requester:profiles!post_contact_requests_requester_id_fkey(display_name, avatar_url)')
          .eq('post_id', postId)
          .order('created_at', ascending: false);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(PostContactRequest.fromJson)
          .toList();
    } catch (e) {
      debugPrint('[PostContact] getRequestsForPost failed: $e');
      return const [];
    }
  }

  Future<List<PostContactRequest>> getMyIncomingRequests() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const [];
    try {
      final rows = await sb
          .from('post_contact_requests')
          .select(
              'id, post_id, requester_id, post_owner_id, contact_method, status, message, responded_at, created_at, requester:profiles!post_contact_requests_requester_id_fkey(display_name, avatar_url), post:posts!post_contact_requests_post_id_fkey(title)')
          .eq('post_owner_id', uid)
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(PostContactRequest.fromJson)
          .toList();
    } catch (e) {
      debugPrint('[PostContact] getMyIncomingRequests failed: $e');
      return const [];
    }
  }

  Future<List<PostContactRequest>> getMyOutgoingRequests() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const [];
    try {
      final rows = await sb
          .from('post_contact_requests')
          .select(
              'id, post_id, requester_id, post_owner_id, contact_method, status, message, responded_at, created_at, post:posts!post_contact_requests_post_id_fkey(title)')
          .eq('requester_id', uid)
          .order('created_at', ascending: false);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .map(PostContactRequest.fromJson)
          .toList();
    } catch (e) {
      debugPrint('[PostContact] getMyOutgoingRequests failed: $e');
      return const [];
    }
  }

  Future<int> getHelperCountForPost(String postId) async {
    try {
      final rows = await sb
          .from('post_contact_requests')
          .select('id')
          .eq('post_id', postId)
          .inFilter('status', ['accepted', 'completed']);
      return (rows as List).length;
    } catch (e) {
      debugPrint('[PostContact] getHelperCountForPost failed: $e');
      return 0;
    }
  }

  Future<PostContactRequest?> getMyRequestForPost(String postId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await sb
          .from('post_contact_requests')
          .select()
          .eq('post_id', postId)
          .eq('requester_id', uid)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return PostContactRequest.fromJson(row);
    } catch (e) {
      debugPrint('[PostContact] getMyRequestForPost failed: $e');
      return null;
    }
  }

  /// R7 Datenschutz: gibt PostContactPreference nur zurueck wenn:
  ///   a) der aktuelle User Owner ist (sieht eigene Daten), ODER
  ///   b) der aktuelle User eine status='accepted' Anfrage hat.
  /// Sonst null.
  Future<PostContactPreference?> getRevealedContactInfo(String postId) async {
    final pref = await getPreferencesForPost(postId);
    if (pref == null) return null;
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return null;
    if (pref.userId == uid) return pref; // eigene Daten
    final my = await getMyRequestForPost(postId);
    if (my == null || !my.isAccepted) return null;
    return pref;
  }
}
