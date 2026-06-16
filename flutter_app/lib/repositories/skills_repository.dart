/// SKILL: supabase + mensaena-features
/// Skills-Repository — Fähigkeiten-Angebote (skill_offers) aus der
/// UI-Schicht gebündelt.
library;

import '../models/skill_offer.dart';
import '../services/supabase_service.dart';

class SkillsRepository {
  const SkillsRepository._();

  /// Aktive Skill-Angebote, neueste zuerst.
  static Future<List<SkillOffer>> listActive({int limit = 50}) async {
    try {
      final rows = await sb
          .from('skill_offers')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(SkillOffer.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Neues Skill-Angebot anlegen. Gibt die neue ID zurück oder null bei Fehler.
  static Future<String?> create({
    required String title,
    required String description,
    String? skillCategory,
    String? level,
    bool isFree = true,
    double? hourlyRate,
    bool isOnline = false,
    String? locationAddress,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await sb
          .from('skill_offers')
          .insert({
            'user_id': uid,
            'title': title,
            'description': description,
            if (skillCategory != null) 'skill_category': skillCategory,
            if (level != null) 'level': level,
            'is_free': isFree,
            if (hourlyRate != null && !isFree) 'hourly_rate': hourlyRate,
            'is_online': isOnline,
            if (locationAddress != null && locationAddress.isNotEmpty)
              'location_address': locationAddress,
            'is_active': true,
          })
          .select()
          .maybeSingle();
      if (row == null) return null;
      return row['id'] as String?;
    } catch (_) {
      return null;
    }
  }
}
