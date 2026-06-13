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
}
