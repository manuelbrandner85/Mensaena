import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/marketplace_repository.dart';
import '../../../services/open_food_facts_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../shared/barcode_scanner_screen.dart';

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

  /// Öffnet Barcode-Scanner → Open Food Facts Lookup → füllt Titel +
  /// Beschreibung. Snackbar bei Erfolg/Fehler.
  Future<void> _scanAndFillFromFood() async {
    final code = await BarcodeScannerScreen.open(context,
        title: 'Lebensmittel scannen');
    if (code == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.elevated,
      duration: const Duration(seconds: 1),
      content: Text('marketplace.searching'.tr(namedArgs: {'code': code}),
          style: AppTypography.body(size: 12, color: AppColors.inkSoft)),
    ));
    final p = await OpenFoodFactsService.lookup(code);
    if (!mounted) return;
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('marketplace.productNotFound'.tr(namedArgs: {'code': code}),
            style: AppTypography.body(size: 13, color: AppColors.ink)),
      ));
      return;
    }
    setState(() {
      _title.text = p.displayTitle ?? p.name;
      final parts = <String>[
        if (p.quantity != null && p.quantity!.isNotEmpty) 'Menge: ${p.quantity}',
        if (p.ingredients != null && p.ingredients!.isNotEmpty)
          'Zutaten: ${p.ingredients}',
        if (p.categories != null && p.categories!.isNotEmpty)
          'Kategorie: ${p.categories!.split(",").take(2).join(", ")}',
      ];
      if (parts.isNotEmpty) _desc.text = parts.join('\n\n');
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.surface,
      content: Text('✓ ${p.name} eingefügt',
          style: AppTypography.body(size: 13, color: AppColors.leben)),
    ));
  }

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
            Text('marketplace.type'.tr(), style: AppTypography.label(size: 10)),
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
            OutlinedButton.icon(
              onPressed: _scanAndFillFromFood,
              icon: const Icon(LucideIcons.scanLine, size: 16),
              label: Text('marketplace.scanBarcode'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.bronze,
                side: BorderSide(
                    color: AppColors.bronze.withValues(alpha: 0.5)),
                minimumSize: const Size.fromHeight(44),
              ),
            ),
            const SizedBox(height: 10),
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
