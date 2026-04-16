import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/group_provider.dart';
import 'package:mensaena/providers/auth_provider.dart';

class GroupDetailScreen extends ConsumerWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});
  @override Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(groupDetailProvider(groupId));
    final members = ref.watch(groupMembersProvider(groupId));
    return Scaffold(
      appBar: AppBar(title: const Text('Gruppe')),
      body: group.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (g) {
          if (g == null) return const Center(child: Text('Nicht gefunden'));
          return ListView(padding: const EdgeInsets.all(16), children: [
            Text(g.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            if (g.description != null) ...[const SizedBox(height: 8), Text(g.description!, style: const TextStyle(color: AppColors.textMuted))],
            const SizedBox(height: 16), Text('${g.memberCount} Mitglieder', style: const TextStyle(fontWeight: FontWeight.w600)),
            const Divider(),
            members.when(
              data: (list) => Column(children: list.map((m) => ListTile(
                leading: CircleAvatar(child: Text((m.profile?['nickname'] as String? ?? '?')[0])),
                title: Text(m.profile?['nickname'] as String? ?? 'Unbekannt'),
                subtitle: Text(m.role), contentPadding: EdgeInsets.zero)).toList()),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Fehler')),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () async {
              final userId = ref.read(currentUserIdProvider);
              if (userId == null) return;
              await ref.read(groupServiceProvider).joinGroup(groupId, userId);
              ref.invalidate(groupDetailProvider(groupId));
            }, child: const Text('Beitreten')),
          ]);
        },
      ),
    );
  }
}