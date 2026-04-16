import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mensaena/models/knowledge_article.dart';

class KnowledgeService {
  final SupabaseClient _client;

  KnowledgeService(this._client);

  Future<List<KnowledgeArticle>> getArticles({String? category, String? search, int limit = 20, int offset = 0}) async {
    var query = _client.from('knowledge_articles').select('*, profiles(id, name, nickname, avatar_url)').eq('status', 'published').eq('is_public', true);
    if (category != null) query = query.eq('category', category);
    if (search != null && search.isNotEmpty) query = query.or('title.ilike.%$search%,summary.ilike.%$search%');
    final data = await query.order('created_at', ascending: false).range(offset, offset + limit - 1);
    return (data as List).map((e) => KnowledgeArticle.fromJson(e)).toList();
  }

  Future<KnowledgeArticle?> getArticle(String id) async {
    final data = await _client.from('knowledge_articles').select('*, profiles(id, name, nickname, avatar_url)').eq('id', id).maybeSingle();
    if (data == null) return null;
    // Increment views
    await _client.rpc('increment_article_views', params: {'article_id': id}).catchError((_) => null);
    return KnowledgeArticle.fromJson(data);
  }

  Future<KnowledgeArticle> createArticle(Map<String, dynamic> articleData) async {
    final data = await _client.from('knowledge_articles').insert(articleData).select().single();
    return KnowledgeArticle.fromJson(data);
  }
}
