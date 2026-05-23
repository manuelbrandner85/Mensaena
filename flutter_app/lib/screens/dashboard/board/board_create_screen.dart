import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/board_repository.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

class BoardCreateScreen extends ConsumerStatefulWidget {
  const BoardCreateScreen({super.key});

  @override
  ConsumerState<BoardCreateScreen> createState() => _BoardCreateScreenState();
}

class _BoardCreateScreenState extends ConsumerState<BoardCreateScreen> {
  final _content = TextEditingController();
  final _contactInfo = TextEditingController();
  String _category = 'general';
  String _color = 'yellow';
  bool _submitting = false;
  String? _error;

  static const List<({String value, String label, String emoji})> _categories = [
    (value: 'general', label: 'Allgemein', emoji: '💬'),
    (value: 'gesucht', label: 'Gesucht', emoji: '🔍'),
    (value: 'biete', label: 'Biete', emoji: '🎁'),
    (value: 'event', label: 'Event', emoji: '📅'),
    (value: 'info', label: 'Info', emoji: 'ℹ️'),
    (value: 'warnung', label: 'Warnung', emoji: '⚠️'),
    (value: 'verloren', label: 'Verloren', emoji: '😢'),
    (value: 'fundbuero', label: 'Fundbüro', emoji: '🔑'),
  ];

  static const Map<String, Color> _colors = {
    'yellow': Color(0xFFFEF08A),
    'green': Color(0xFFBBF7D0),
    'blue': Color(0xFFBFDBFE),
    'pink': Color(0xFFFBCFE8),
    'orange': Color(0xFFFED7AA),
    'purple': Color(0xFFE9D5FF),
  };

  Future<void> _submit() async {
    if (_content.text.trim().isEmpty) {
      setState(() => _error = 'Inhalt ist Pflicht.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final id = await BoardRepository.create(
      content: _content.text.trim(),
      category: _category,
      color: _color,
      contactInfo: _contactInfo.text.trim().isEmpty
          ? null
          : _contactInfo.text.trim(),
    );
    if (!mounted) return;
    if (id == null) {
      setState(() {
        _submitting = false;
        _error = 'Konnte Notiz nicht speichern.';
      });
      return;
    }
    context.go('/dashboard/board/$id');
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'Pinnwand-Notiz',
      currentRoute: '/dashboard/board',
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
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
            const SizedBox(height: 14),
            Text('Farbe', style: AppTypography.label(size: 10)),
            const SizedBox(height: 6),
            Row(
              children: _colors.entries.map((e) {
                final active = e.key == _color;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _color = e.key),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: e.value,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: active ? AppColors.amber : AppColors.line,
                          width: active ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _content,
              maxLines: 6,
              maxLength: 1000,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: const InputDecoration(
                labelText: 'Notiz',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contactInfo,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: const InputDecoration(
                labelText: 'Kontakt (optional)',
                hintText: 'Telefon / E-Mail / @mention',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: AppTypography.body(
                  size: 13,
                  color: AppColors.herzrotWarm,
                ),
              ),
            ],
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: const Icon(LucideIcons.stickyNote, size: 16),
              label: Text(_submitting ? 'Speichere…' : 'Notiz anpinnen'),
            ),
          ],
        ),
      ),
    );
  }
}
