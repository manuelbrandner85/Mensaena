import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/group_provider.dart';

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('👥 Gruppen')),
      body: groups.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (list) => list.isEmpty ? const Center(child: Text('Keine Gruppen')) :
          ListView.builder(padding: const EdgeInsets.all(12), itemCount: list.length,
            itemBuilder: (_, i) => Card(margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Icon(Icons.group, color: AppColors.primary500))),
                title: Text(list[i].name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${list[i].memberCount} Mitglieder', style: const TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/dashboard/groups/${list[i].id}')))),
      ),
    );
  }
}