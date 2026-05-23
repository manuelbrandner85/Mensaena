import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/marketplace_repository.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

class MarketplaceCreateScreen extends ConsumerStatefulWidget {
  const MarketplaceCreateScreen({super.key});

  @override
  ConsumerState<MarketplaceCreateScreen> createState() =>
      _MarketplaceCreateScreenState();
}

class _MarketplaceCreateScreenState
    extends ConsumerState<MarketplaceCreateScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _location = TextEditingController();
  final _price = TextEditingController();
  String _listingType = 'verschenken';
  String _category = 'haushalt';
  String _condition = 'gut';
  bool _submitting = false;
  String? _error;

  static const List<({String value, String label, String emoji})> _types = [
    (value: 'verschenken', label: 'Verschenken', emoji: '🎁'),
    (value: 'tauschen', label: 'Tauschen', emoji: '🔄'),
    (value: 'verkaufen', label: 'Günstig abgeben', emoji: '💶'),
    (value: 'leihen', label: 'Leihen', emoji: '📅'),
  ];

  static const List<String> _categories = [
    'haushalt',
    'kleidung',
    'kinder',
    'moebel',
    'elektronik',
    'sport',
    'buecher',
    'garten',
    'werkzeug',
    'sonstiges',
  ];

  static const List<String> _conditions = [
    'neu',
    'sehr_gut',
    'gut',
    'gebraucht',
    'defekt',
  ];

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _desc.text.trim().isEmpty) {
      setState(() => _error = 'Titel und Beschreibung sind Pflicht.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final id = await MarketplaceRepository.create(
      title: _title.text.trim(),
      description: _desc.text.trim(),
      category: _category,
      listingType: _listingType,
      conditionState: _condition,
      price: _listingType == 'verkaufen'
          ? double.tryParse(_price.text.trim().replaceAll(',', '.'))
          : null,
      locationText: _location.text.trim().isEmpty
          ? null
          : _location.text.trim(),
    );
    if (!mounted) return;
    if (id == null) {
      setState(() {
        _submitting = false;
        _error = 'Konnte Inserat nicht speichern.';
      });
      return;
    }
    context.go('/dashboard/marketplace/$id');
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'Inserat',
      currentRoute: '/dashboard/marketplace',
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Art', style: AppTypography.label(size: 10)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: _types.map((t) {
                final active = t.value == _listingType;
                return GestureDetector(
                  onTap: () => setState(() => _listingType = t.value),
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
                        Text(t.emoji, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                        Text(
                          t.label,
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
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              maxLength: 120,
              style: AppTypography.body(size: 15, color: AppColors.ink),
              decoration: const InputDecoration(labelText: 'Titel'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _desc,
              maxLines: 4,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: const InputDecoration(
                labelText: 'Beschreibung',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Kategorie'),
              dropdownColor: AppColors.surface,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _condition,
              decoration: const InputDecoration(labelText: 'Zustand'),
              dropdownColor: AppColors.surface,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              items: _conditions
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _condition = v ?? _condition),
            ),
            if (_listingType == 'verkaufen') ...[
              const SizedBox(height: 10),
              TextField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: AppTypography.body(size: 14, color: AppColors.ink),
                decoration: const InputDecoration(labelText: 'Preis in €'),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _location,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: const InputDecoration(labelText: 'Standort'),
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
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: const Icon(LucideIcons.plus, size: 16),
              label: Text(_submitting ? 'Speichere…' : 'Inserieren'),
            ),
          ],
        ),
      ),
    );
  }
}
