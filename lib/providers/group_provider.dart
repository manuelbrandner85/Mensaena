import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/services/group_service.dart';
import 'package:mensaena/models/group.dart';

final groupServiceProvider = Provider<GroupService>((ref) {
  return GroupService(ref.watch(supabaseProvider));
});

final groupsProvider = FutureProvider<List<Group>>((ref) async {
  return ref.read(groupServiceProvider).getGroups();
});

final groupDetailProvider = FutureProvider.family<Group?, String>((ref, groupId) async {
  return ref.read(groupServiceProvider).getGroup(groupId);
});

final groupMembersProvider = FutureProvider.family<List<GroupMember>, String>((ref, groupId) async {
  return ref.read(groupServiceProvider).getMembers(groupId);
});
