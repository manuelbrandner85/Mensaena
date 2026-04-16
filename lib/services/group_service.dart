import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mensaena/models/group.dart';

class GroupService {
  final SupabaseClient _client;

  GroupService(this._client);

  Future<List<Group>> getGroups({String? search, String? category}) async {
    var query = _client.from('groups').select('*, profiles(id, name, nickname, avatar_url)');
    if (search != null && search.isNotEmpty) {
      query = query.or('name.ilike.%$search%,description.ilike.%$search%');
    }
    if (category != null) query = query.eq('category', category);
    final data = await query.order('member_count', ascending: false);
    return (data as List).map((e) => Group.fromJson(e)).toList();
  }

  Future<Group?> getGroup(String groupId) async {
    final data = await _client.from('groups').select('*, profiles(id, name, nickname, avatar_url)').eq('id', groupId).maybeSingle();
    if (data == null) return null;
    return Group.fromJson(data);
  }

  Future<Group> createGroup(Map<String, dynamic> groupData) async {
    final data = await _client.from('groups').insert(groupData).select().single();
    // Auto-join creator
    await _client.from('group_members').insert({
      'group_id': data['id'],
      'user_id': groupData['creator_id'],
      'role': 'owner',
    });
    return Group.fromJson(data);
  }

  Future<void> joinGroup(String groupId, String userId) async {
    await _client.from('group_members').insert({
      'group_id': groupId,
      'user_id': userId,
      'role': 'member',
    });
  }

  Future<void> leaveGroup(String groupId, String userId) async {
    await _client.from('group_members').delete().eq('group_id', groupId).eq('user_id', userId);
  }

  Future<bool> isMember(String groupId, String userId) async {
    final data = await _client.from('group_members').select('id').eq('group_id', groupId).eq('user_id', userId).maybeSingle();
    return data != null;
  }

  Future<List<GroupMember>> getMembers(String groupId) async {
    final data = await _client.from('group_members').select('*, profiles(id, name, nickname, avatar_url)').eq('group_id', groupId).order('joined_at');
    return (data as List).map((e) => GroupMember.fromJson(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getGroupPosts(String groupId) async {
    final data = await _client
        .from('group_posts')
        .select('*, profiles:author_id(id, name, nickname, avatar_url)')
        .eq('group_id', groupId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> createGroupPost(String groupId, String userId, String content) async {
    await _client.from('group_posts').insert({
      'group_id': groupId,
      'author_id': userId,
      'content': content,
    });
  }
}
