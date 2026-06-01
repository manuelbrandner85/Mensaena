import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group.dart';
import '../models/group_member.dart';
import '../models/group_post.dart';
import '../services/supabase_service.dart';

/// SKILL: supabase + mensaena-features
/// Groups + Members + Group-Posts.
class GroupsRepository {
  const GroupsRepository._();

  /// F74: Gruppen in der Nähe (Haversine-Filter clientseitig, weil ohne
  /// PostGIS-Funktion einfacher). Limitiert auf top 50 nach Mitglieder-
  /// zahl, dann filtert clientseitig per Radius.
  static Future<List<Group>> nearby({
    required double lat,
    required double lng,
    double radiusKm = 5,
    int limit = 20,
  }) async {
    try {
      final rows = await sb
          .from('groups')
          .select()
          .eq('is_archived', false)
          .not('latitude', 'is', null)
          .order('member_count', ascending: false)
          .limit(50);
      final groups = (rows as List)
          .whereType<Map<String, dynamic>>()
          .where((r) {
        final gl = (r['latitude'] as num?)?.toDouble();
        final gn = (r['longitude'] as num?)?.toDouble();
        if (gl == null || gn == null) return false;
        return _haversineKm(lat, lng, gl, gn) <= radiusKm;
      }).take(limit).map(Group.fromJson).toList();
      return groups;
    } catch (_) {
      return const [];
    }
  }

  static double _haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _deg(lat2 - lat1);
    final dLon = _deg(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg(lat1)) *
            math.cos(_deg(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.asin(math.sqrt(a.clamp(0.0, 1.0)));
    return r * c;
  }

  static double _deg(double d) => d * math.pi / 180.0;

  static Future<List<Group>> listAll({int limit = 100}) async {
    try {
      final rows = await sb
          .from('groups')
          .select()
          // Audit-Fix: archivierte/gelöschte Gruppen ausblenden (nearby()
          // hatte den Filter, listAll() nicht → zeigte tote Gruppen).
          .eq('is_archived', false)
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

  /// G2: meine Rolle in der Gruppe ('owner' | 'admin' | 'member' | null).
  static Future<String?> myRoleInGroup(String groupId) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await sb
          .from('group_members')
          .select('role')
          .eq('group_id', groupId)
          .eq('user_id', uid)
          .maybeSingle();
      return row?['role'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// G2: löscht einen Gruppen-Post. RLS erlaubt nur dem Autor ODER einem
  /// Owner/Admin der Gruppe das Löschen.
  static Future<bool> deletePost(String postId) async {
    try {
      await sb.from('group_posts').delete().eq('id', postId);
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
    String? coverImageUrl,
    int? maxMembers,
    double? latitude,
    double? longitude,
    int? radiusKm,
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
            if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
            if (maxMembers != null) 'max_members': maxMembers,
            if (latitude != null) 'latitude': latitude,
            if (longitude != null) 'longitude': longitude,
            if (radiusKm != null) 'radius_km': radiusKm,
          })
          .select()
          .maybeSingle();
      if (row == null) return null;
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
final groupMyRoleProvider = FutureProvider.family<String?, String>(
    (ref, id) => GroupsRepository.myRoleInGroup(id));
final groupPostsProvider = FutureProvider.family<List<GroupPost>, String>(
    (ref, id) => GroupsRepository.postsFor(id));
