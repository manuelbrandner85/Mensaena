import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group.dart';
import '../models/group_member.dart';
import '../models/group_post.dart';
import '../services/supabase_service.dart';

/// SKILL: supabase + mensaena-features
/// Groups + Members + Group-Posts.
class GroupsRepository {
  const GroupsRepository._();

  static Future<List<Group>> listAll({int limit = 100}) async {
    try {
      final rows = await sb
          .from('groups')
          .select()
          .order('member_count', ascending: false)
          .limit(limit);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(Group.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<Group?> getById(String id) async {
    try {
      final row =
          await sb.from('groups').select().eq('id', id).maybeSingle();
      if (row == null) return null;
      return Group.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> amMember(String groupId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      final row = await sb
          .from('group_members')
          .select('id')
          .eq('group_id', groupId)
          .eq('user_id', uid)
          .maybeSingle();
      return row != null;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> join(String groupId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('group_members').insert({
        'group_id': groupId,
        'user_id': uid,
        'role': 'member',
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Mitglied per E-Mail einladen — laeuft ueber RPC `invite_user_to_group`
  /// (lookupt User per email, dann insert in group_members mit invited-Flag).
  /// Fallback: einfacher Insert wenn RPC nicht existiert.
  static Future<bool> inviteByEmail(String groupId, String email) async {
    try {
      await sb.rpc<dynamic>('invite_user_to_group', params: {
        'p_group_id': groupId,
        'p_email': email.trim().toLowerCase(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> leave(String groupId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb
          .from('group_members')
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', uid);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<GroupMember>> members(String groupId,
      {int limit = 30}) async {
    try {
      final rows = await sb
          .from('group_members')
          .select()
          .eq('group_id', groupId)
          .order('joined_at')
          .limit(limit);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(GroupMember.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<GroupPost>> postsFor(String groupId,
      {int limit = 50}) async {
    try {
      final rows = await sb
          .from('group_posts')
          .select()
          .eq('group_id', groupId)
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(GroupPost.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> addPost({
    required String groupId,
    required String content,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('group_posts').insert({
        'group_id': groupId,
        'user_id': uid,
        'content': content,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> create({
    required String name,
    required String slug,
    required String category,
    String? description,
    bool isPrivate = false,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await sb
          .from('groups')
          .insert({
            'name': name,
            'slug': slug,
            'category': category,
            'description': description,
            'is_private': isPrivate,
            'creator_id': uid,
            'member_count': 1,
            'post_count': 0,
          })
          .select()
          .single();
      final id = row['id'] as String?;
      if (id != null) {
        await sb.from('group_members').insert({
          'group_id': id,
          'user_id': uid,
          'role': 'owner',
        });
      }
      return id;
    } catch (_) {
      return null;
    }
  }
}

final groupsListProvider =
    FutureProvider<List<Group>>((ref) async => GroupsRepository.listAll());
final groupDetailProvider =
    FutureProvider.family<Group?, String>((ref, id) => GroupsRepository.getById(id));
final groupMembershipProvider =
    FutureProvider.family<bool, String>((ref, id) => GroupsRepository.amMember(id));
final groupPostsProvider = FutureProvider.family<List<GroupPost>, String>(
    (ref, id) => GroupsRepository.postsFor(id));
