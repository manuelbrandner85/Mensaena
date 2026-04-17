import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/widgets/editorial_header.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/providers/group_provider.dart';
import 'package:mensaena/models/group.dart';
import 'package:mensaena/widgets/empty_state.dart';

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});
  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  final _searchCtrl = TextEditingController();
  String? _selectedCategory;

  static const _categories = [
    (value: null, label: 'Alle', emoji: '📋'),
    (value: 'nachbarschaft', label: 'Nachbarschaft', emoji: '🏘️'),
    (value: 'hobby', label: 'Hobby', emoji: '🎨'),
    (value: 'sport', label: 'Sport', emoji: '⚽'),
    (value: 'eltern', label: 'Eltern', emoji: '👶'),
    (value: 'senioren', label: 'Senioren', emoji: '🧓'),
    (value: 'umwelt', label: 'Umwelt', emoji: '🌿'),
    (value: 'bildung', label: 'Bildung', emoji: '📚'),
    (value: 'tiere', label: 'Tiere', emoji: '🐾'),
    (value: 'handwerk', label: 'Handwerk', emoji: '🔧'),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gruppen')),
      body: Column(
        children: [
          const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: EditorialHeader(
                section: 'GRUPPEN',
                number: '10',
                title: 'Gruppen',
                subtitle: 'Gemeinschaften in deiner Nähe',
                icon: Icons.group_outlined,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Gruppen suchen...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtrl.clear(); setState(() {}); ref.invalidate(groupsProvider); })
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.border)),
                filled: true, fillColor: AppColors.background,
              ),
              onSubmitted: (_) => ref.invalidate(groupsProvider),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final c = _categories[i];
                final sel = _selectedCategory == c.value;
                return FilterChip(
                  label: Text('${c.emoji} ${c.label}', style: TextStyle(fontSize: 11, color: sel ? Colors.white : AppColors.textSecondary)),
                  selected: sel, selectedColor: AppColors.primary500,
                  onSelected: (_) { setState(() => _selectedCategory = c.value); ref.invalidate(groupsProvider); },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: groups.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Fehler: $e')),
              data: (list) {
                final filtered = _selectedCategory != null
                    ? list.where((g) => g.category == _selectedCategory).toList()
                    : list;
                if (filtered.isEmpty) {
                  return const EmptyState(icon: Icons.group_outlined, title: 'Keine Gruppen', message: 'Erstelle die erste Gruppe!');
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(groupsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _GroupCard(group: filtered[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateGroupDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Gruppe erstellen'),
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'nachbarschaft';
    bool isPublic = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: StatefulBuilder(builder: (ctx, setBS) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Neue Gruppe', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name *')),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Beschreibung'), maxLines: 3),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: category,
              decoration: const InputDecoration(labelText: 'Kategorie'),
              items: _categories.where((c) => c.value != null).map((c) => DropdownMenuItem(value: c.value, child: Text('${c.emoji} ${c.label}'))).toList(),
              onChanged: (v) => setBS(() => category = v ?? 'nachbarschaft'),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Öffentliche Gruppe'),
              subtitle: Text(isPublic ? 'Jeder kann beitreten' : 'Nur mit Einladung'),
              value: isPublic,
              onChanged: (v) => setBS(() => isPublic = v),
              contentPadding: EdgeInsets.zero,
              activeTrackColor: AppColors.primary500,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final userId = ref.read(currentUserIdProvider);
                  if (userId == null) return;
                  Navigator.pop(ctx);
                  try {
                    await ref.read(groupServiceProvider).createGroup({
                      'name': nameCtrl.text.trim(),
                      'description': descCtrl.text.trim(),
                      'category': category,
                      'is_public': isPublic,
                      'creator_id': userId,
                    });
                    ref.invalidate(groupsProvider);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gruppe erstellt!')));
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
                  }
                },
                child: const Text('Erstellen'),
              ),
            ),
          ],
        )),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final Group group;
  const _GroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final catEmoji = _getCategoryEmoji(group.category);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/dashboard/groups/${group.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary50,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(child: Text(catEmoji, style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(group.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        if (group.isPrivate) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.lock_outline, size: 14, color: AppColors.textMuted),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('${group.memberCount} Mitglieder', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    if (group.description != null && group.description!.isNotEmpty)
                      Text(group.description!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  String _getCategoryEmoji(String? cat) {
    switch (cat) {
      case 'nachbarschaft': return '🏘️';
      case 'hobby': return '🎨';
      case 'sport': return '⚽';
      case 'eltern': return '👶';
      case 'senioren': return '🧓';
      case 'umwelt': return '🌿';
      case 'bildung': return '📚';
      case 'tiere': return '🐾';
      case 'handwerk': return '🔧';
      default: return '💬';
    }
  }
}
