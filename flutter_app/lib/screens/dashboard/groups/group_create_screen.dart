import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/groups_repository.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

class GroupCreateScreen extends ConsumerStatefulWidget {
  const GroupCreateScreen({super.key});

  @override
  ConsumerState<GroupCreateScreen> createState() => _GroupCreateScreenState();
}

class _GroupCreateScreenState extends ConsumerState<GroupCreateScreen> {
  final _name = TextEditingController();
  final _desc = TextEditingController();
  String _category = 'nachbarschaft';
  bool _isPrivate = false;
  bool _submitting = false;
  String? _error;

  static const List<({String value, String label, String emoji})> _categories = [
    (value: 'nachbarschaft', label: 'Nachbarschaft', emoji: '🏘️'),
    (value: 'hobby', label: 'Hobby', emoji: '🎨'),
    (value: 'sport', label: 'Sport', emoji: '⚽'),
    (value: 'eltern', label: 'Eltern', emoji: '👶'),
    (value: 'senioren', label: 'Senioren', emoji: '🧓'),
    (value: 'umwelt', label: 'Umwelt', emoji: '🌿'),
    (value: 'bildung', label: 'Bildung', emoji: '📚'),
    (value: 'tiere', label: 'Tiere', emoji: '🐾'),
    (value: 'handwerk', label: 'Handwerk', emoji: '🔧'),
    (value: 'sonstiges', label: 'Sonstiges', emoji: '💬'),
  ];

  String _slugify(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[äÄ]'), 'ae')
        .replaceAll(RegExp(r'[öÖ]'), 'oe')
        .replaceAll(RegExp(r'[üÜ]'), 'ue')
        .replaceAll(RegExp(r'[ß]'), 'ss')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Name ist Pflicht.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final id = await GroupsRepository.create(
      name: _name.text.trim(),
      slug: _slugify(_name.text.trim()),
      category: _category,
      description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      isPrivate: _isPrivate,
    );
    if (!mounted) return;
    if (id == null) {
      setState(() {
        _submitting = false;
        _error = 'Konnte Gruppe nicht speichern.';
      });
      return;
    }
    context.go('/dashboard/groups/$id');
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'Gruppe erstellen',
      currentRoute: '/dashboard/groups',
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _name,
              maxLength: 60,
              style: AppTypography.body(size: 15, color: AppColors.ink),
              decoration: const InputDecoration(labelText: 'Gruppenname'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _desc,
              maxLines: 4,
              maxLength: 500,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: const InputDecoration(
                labelText: 'Beschreibung',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),
            Text('Kategorie', style: AppTypography.label(size: 10)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _categories.map((c) {
                final active = c.value == _category;
                return GestureDetector(
                  onTap: () => setState(() => _category = c.value),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.amber.withValues(alpha: 0.2)
                          : AppColors.surface.withValues(alpha: 0.5),
                      border: Border.all(
                        color: active ? AppColors.amber : AppColors.line,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(c.emoji, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                        Text(
                          c.label,
                          style: AppTypography.label(
                            size: 10,
                            color: active
                                ? AppColors.amber
                                : AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.amber,
              value: _isPrivate,
              onChanged: (v) => setState(() => _isPrivate = v),
              title: Text(
                'Private Gruppe',
                style: AppTypography.body(size: 14, color: AppColors.ink),
              ),
              subtitle: Text(
                'Nur via Einladung beitretbar.',
                style: AppTypography.caption(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: AppTypography.body(
                  size: 13,
                  color: AppColors.herzrotWarm,
                ),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: const Icon(LucideIcons.plus, size: 16),
              label: Text(_submitting ? 'Speichere…' : 'Gruppe gründen'),
            ),
          ],
        ),
      ),
    );
  }
}
