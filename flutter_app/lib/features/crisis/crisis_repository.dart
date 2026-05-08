import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';
import 'models.dart';

final crisisRepositoryProvider = Provider<CrisisRepository>(
  (ref) => CrisisRepository(ref.read(supabaseProvider)),
);

class CrisisRepository {
  CrisisRepository(this._db);
  final SupabaseClient _db;
  static const _pageSize = 20;

  Future<List<Crisis>> list({
    String status = 'active',
    String category = 'all',
    String urgency = 'all',
    int page = 0,
  }) async {
    var query = _db
        .from('crisis_reports')
        .select('*, profiles(name, avatar_url, trust_score, is_crisis_volunteer)');
    if (status != 'all') {
      query = query.eq('status', status);
    }
    if (category != 'all') {
      query = query.eq('category', category);
    }
    if (urgency != 'all') {
      query = query.eq('urgency', urgency);
    }

    final from = page * _pageSize;
    final to = from + _pageSize - 1;

    final rows = await query
        .order('urgency', ascending: false)
        .order('created_at', ascending: false)
        .range(from, to);
    return rows.map(Crisis.fromJson).toList();
  }

  Future<Crisis?> fetch(String id) async {
    final row = await _db
        .from('crisis_reports')
        .select(
          '*, profiles(name, avatar_url, trust_score, is_crisis_volunteer)',
        )
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return Crisis.fromJson(row);
  }

  Future<List<CrisisHelper>> helpersFor(String crisisId) async {
    final rows = await _db
        .from('crisis_helpers')
        .select('*, profiles(name, avatar_url, trust_score, is_crisis_volunteer)')
        .eq('crisis_id', crisisId)
        .order('created_at', ascending: false);
    return rows.map(CrisisHelper.fromJson).toList();
  }

  Future<String> create({
    required String title,
    required String description,
    required String category,
    required CrisisUrgency urgency,
    String? locationText,
    double? latitude,
    double? longitude,
    double radiusKm = 5,
    int affectedCount = 1,
    int neededHelpers = 1,
    String? contactPhone,
    String? contactName,
    bool isAnonymous = false,
    List<String> neededSkills = const [],
    List<String> neededResources = const [],
  }) async {
    final user = _db.auth.currentUser;
    if (user == null) throw Exception('Nicht eingeloggt');
    final row = await _db
        .from('crisis_reports')
        .insert(<String, dynamic>{
          'creator_id': user.id,
          'title': title,
          'description': description,
          'category': category,
          'urgency': urgency.value,
          'status': 'active',
          if (locationText != null && locationText.isNotEmpty) 'location_text': locationText,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          'radius_km': radiusKm,
          'affected_count': affectedCount,
          'needed_helpers': neededHelpers,
          if (contactPhone != null && contactPhone.isNotEmpty) 'contact_phone': contactPhone,
          if (contactName != null && contactName.isNotEmpty) 'contact_name': contactName,
          'is_anonymous': isAnonymous,
          'needed_skills': neededSkills,
          'needed_resources': neededResources,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> offerHelp({
    required String crisisId,
    String? message,
    List<String> skills = const [],
    int? etaMinutes,
  }) async {
    final user = _db.auth.currentUser;
    if (user == null) throw Exception('Nicht eingeloggt');
    await _db.from('crisis_helpers').insert(<String, dynamic>{
      'crisis_id': crisisId,
      'user_id': user.id,
      'status': 'offered',
      if (message != null && message.isNotEmpty) 'message': message,
      'skills': skills,
      if (etaMinutes != null) 'eta_minutes': etaMinutes,
    });
  }

  Future<void> withdrawHelp(String crisisId) async {
    final user = _db.auth.currentUser;
    if (user == null) return;
    await _db
        .from('crisis_helpers')
        .update(<String, dynamic>{'status': 'withdrawn'})
        .eq('crisis_id', crisisId)
        .eq('user_id', user.id);
  }

  Future<void> markResolved(String crisisId) async {
    final user = _db.auth.currentUser;
    if (user == null) return;
    await _db.from('crisis_reports').update(<String, dynamic>{
      'status': 'resolved',
      'resolved_at': DateTime.now().toIso8601String(),
      'resolved_by': user.id,
    }).eq('id', crisisId);
  }
}
