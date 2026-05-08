import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';
import 'models.dart';

final groupsRepositoryProvider = Provider<GroupsRepository>(
  (ref) => GroupsRepository(ref.read(supabaseProvider)),
);

class GroupsRepository {
  GroupsRepository(this._db);
  final SupabaseClient _db;
  static const _pageSize = 20;

  Future<List<Group>> list({String category = 'all', int page = 0}) async {
    var q = _db.from('groups').select('*');
    if (category != 'all') q = q.eq('category', category);
    final from = page * _pageSize;
    final to = from + _pageSize - 1;
    final rows = await q
        .order('member_count', ascending: false)
        .order('created_at', ascending: false)
        .range(from, to);
    return rows.map(Group.fromJson).toList();
  }

  Future<Group?> fetch(String idOrSlug) async {
    var row = await _db
        .from('groups')
        .select('*')
        .eq('slug', idOrSlug)
        .maybeSingle();
    row ??= await _db
        .from('groups')
        .select('*')
        .eq('id', idOrSlug)
        .maybeSingle();
    if (row == null) return null;
    return Group.fromJson(row);
  }

  Future<Set<String>> myGroupIds() async {
    final user = _db.auth.currentUser;
    if (user == null) return const {};
    final rows = await _db
        .from('group_members')
        .select('group_id')
        .eq('user_id', user.id);
    return rows.map((e) => e['group_id'] as String).toSet();
  }

  Future<void> join(String groupId) async {
    final user = _db.auth.currentUser;
    if (user == null) throw Exception('Nicht eingeloggt');
    await _db.from('group_members').insert(<String, dynamic>{
      'group_id': groupId,
      'user_id': user.id,
      'role': 'member',
    });
  }

  Future<void> leave(String groupId) async {
    final user = _db.auth.currentUser;
    if (user == null) return;
    await _db
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', user.id);
  }
}
