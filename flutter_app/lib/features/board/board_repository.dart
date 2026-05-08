import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';
import 'models.dart';

final boardRepositoryProvider = Provider<BoardRepository>(
  (ref) => BoardRepository(ref.read(supabaseProvider)),
);

class BoardRepository {
  BoardRepository(this._db);
  final SupabaseClient _db;

  Future<List<BoardPost>> list({String category = 'all'}) async {
    var q = _db
        .from('board_posts')
        .select(
          '*, profiles:author_id(name, display_name, avatar_url)',
        )
        .eq('status', 'active');
    if (category != 'all') q = q.eq('category', category);
    final rows = await q
        .order('pinned', ascending: false)
        .order('created_at', ascending: false)
        .limit(80);
    return rows.map(BoardPost.fromJson).toList();
  }

  Future<void> create({
    required String content,
    required String category,
    String color = 'yellow',
    String? contactInfo,
    DateTime? expiresAt,
  }) async {
    final user = _db.auth.currentUser;
    if (user == null) throw Exception('Nicht eingeloggt');
    await _db.from('board_posts').insert(<String, dynamic>{
      'author_id': user.id,
      'content': content.trim(),
      'category': category,
      'color': color,
      if (contactInfo != null && contactInfo.isNotEmpty) 'contact_info': contactInfo,
      if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
      'status': 'active',
    });
  }

  Future<void> delete(String id) async {
    await _db.from('board_posts').delete().eq('id', id);
  }
}
