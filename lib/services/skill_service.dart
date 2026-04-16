import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mensaena/models/skill_offer.dart';

class SkillService {
  final SupabaseClient _client;

  SkillService(this._client);

  Future<List<SkillOffer>> getSkillOffers({String? category, String? search, int limit = 20}) async {
    var query = _client.from('skill_offers').select('*, profiles(id, name, nickname, avatar_url)').eq('status', 'active');
    if (category != null) query = query.eq('skill_category', category);
    if (search != null && search.isNotEmpty) query = query.or('title.ilike.%$search%,description.ilike.%$search%');
    final data = await query.order('created_at', ascending: false).limit(limit);
    return (data as List).map((e) => SkillOffer.fromJson(e)).toList();
  }

  Future<SkillOffer> createSkillOffer(Map<String, dynamic> offerData) async {
    final data = await _client.from('skill_offers').insert(offerData).select().single();
    return SkillOffer.fromJson(data);
  }

  Future<void> deleteSkillOffer(String id) async {
    await _client.from('skill_offers').delete().eq('id', id);
  }
}
