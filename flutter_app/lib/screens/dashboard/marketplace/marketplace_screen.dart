import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/marketplace_listing.dart';
import '../../../repositories/marketplace_repository.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/editorial_module_header.dart';
import '../../../widgets/shared/empty_state_card.dart';
import '../../../widgets/shared/filter_chip_bar.dart';
import '../../../widgets/shared/module_search_bar.dart';

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  String _type = 'all';
  String _search = '';
  String? _category;
  String? _condition;

  static const List<FilterOption<String>> _types = [
    FilterOption(value: 'verschenken', label: '🎁 Verschenken'),
    FilterOption(value: 'tauschen', label: '🔄 Tauschen'),
    FilterOption(value: 'verkaufen', label: '💶 Günstig'),
    FilterOption(value: 'leihen', label: '📅 Leihen'),
  ];

  // Kategorien aus Web `marketplace/page.tsx` CATEGORY_OPTIONS.
  static const List<FilterOption<String>> _categories = [
    FilterOption(value: 'electronics', label: '📱 Elektronik'),
    FilterOption(value: 'clothing', label: '👕 Kleidung'),
    FilterOption(value: 'furniture', label: '🪑 Möbel'),
    FilterOption(value: 'kitchen', label: '🍴 Küche'),
    FilterOption(value: 'kids', label: '🧸 Kinder'),
    FilterOption(value: 'books', label: '📚 Bücher'),
    FilterOption(value: 'sports', label: '⚽ Sport'),
    FilterOption(value: 'garden', label: '🌱 Garten'),
    FilterOption(value: 'tools', label: '🔧 Werkzeug'),
    FilterOption(value: 'other', label: '❓ Sonstiges'),
  ];

  // Zustand aus Web CONDITION_OPTIONS.
  static const List<FilterOption<String>> _conditions = [
    FilterOption(value: 'new', label: 'Neu'),
    FilterOption(value: 'like_new', label: 'Wie neu'),
    FilterOption(value: 'good', label: 'Gut'),
    FilterOption(value: 'used', label: 'Gebraucht'),
  ];

  bool get _hasFilters =>
      _search.isNotEmpty ||
      _category != null ||
      _condition != null ||
      _type != 'all';

  List<MarketplaceListing> _apply(List<MarketplaceListing> all) {
    final q = _search.trim().toLowerCase();
    return all.where((m) {
      if (_category != null && m.category != _category) return false;
      if (_condition != null && m.condition != _condition) return false;
      if (q.isEmpty) return true;
      return m.title.toLowerCase().contains(q) ||
          m.description.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(marketplaceListingsProvider(_type));
    return DashboardScaffold(
      title: 'Marktplatz',
      currentRoute: '/dashboard/marketplace',
      fab: FloatingActionButton.extended(
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.voidColor,
        onPressed: () => context.go('/dashboard/marketplace/create'),
        icon: const Icon(LucideIcons.plus),
        label: const Text('Inserieren'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: EditorialModuleHeader(
                metaIndex: '§ 11',
                metaCategory: 'Marktplatz',
                title: 'Verschenken, Tauschen, Leihen',
                subtitle: 'Kein kommerzieller Handel — nur Nachbarschaft',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.08),
                  border: Border.all(
                      color: AppColors.amber.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.info,
                        size: 14, color: AppColors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Kein kommerzieller Handel — verschenken, tauschen, leihen.',
                        style: AppTypography.body(
                          size: 11,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: ModuleSearchBar(
                hintText: 'Inserate durchsuchen…',
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: FilterChipBar<String>(
                options: _types,
                selected: _type == 'all' ? const <String>{} : {_type},
                onChanged: (s) =>
                    setState(() => _type = s.isEmpty ? 'all' : s.first),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: FilterChipBar<String>(
                options: _categories,
                selected: _category == null ? const <String>{} : {_category!},
                allLabel: 'Alle Kategorien',
                onChanged: (s) =>
                    setState(() => _category = s.isEmpty ? null : s.first),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: FilterChipBar<String>(
                options: _conditions,
                selected:
                    _condition == null ? const <String>{} : {_condition!},
                allLabel: 'Alle Zustände',
                onChanged: (s) =>
                    setState(() => _condition = s.isEmpty ? null : s.first),
              ),
            ),
            if (_hasFilters)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ActiveFilterStrip(
                  chips: [
                    if (_type != 'all')
                      ActiveFilterChip(
                        label: _types
                            .firstWhere((t) => t.value == _type)
                            .label,
                        onRemove: () => setState(() => _type = 'all'),
                      ),
                    if (_category != null)
                      ActiveFilterChip(
                        label: _categories
                            .firstWhere((c) => c.value == _category)
                            .label,
                        onRemove: () => setState(() => _category = null),
                      ),
                    if (_condition != null)
                      ActiveFilterChip(
                        label: _conditions
                            .firstWhere((c) => c.value == _condition)
                            .label,
                        onRemove: () => setState(() => _condition = null),
                      ),
                    if (_search.isNotEmpty)
                      ActiveFilterChip(
                        label: '🔍 $_search',
                        onRemove: () => setState(() => _search = ''),
                      ),
                  ],
                  onClearAll: () => setState(() {
                    _type = 'all';
                    _category = null;
                    _condition = null;
                    _search = '';
                  }),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.amber,
                backgroundColor: AppColors.surface,
                onRefresh: () async =>
                    ref.invalidate(marketplaceListingsProvider(_type)),
                child: async.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.amber),
                  ),
                  error: (e, _) =>
                      Center(child: Text('$e', style: AppTypography.caption())),
                  data: (all) {
                    final list = _apply(all);
                    if (list.isEmpty) {
                      return ListView(
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          const SizedBox(height: 40),
                          EmptyStateCard(
                            icon: LucideIcons.store,
                            title: _hasFilters
                                ? 'Keine Treffer.'
                                : 'Keine Inserate vorhanden.',
                            description: _hasFilters
                                ? 'Filter zurücksetzen oder andere wählen.'
                                : 'Sei der/die Erste:r — Plus-Button.',
                            actionLabel:
                                _hasFilters ? 'Filter zurücksetzen' : null,
                            onAction: _hasFilters
                                ? () => setState(() {
                                      _type = 'all';
                                      _category = null;
                                      _condition = null;
                                      _search = '';
                                    })
                                : null,
                          ),
                        ],
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.all(12),
                      physics: const AlwaysScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 240,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: list.length,
                      itemBuilder: (context, i) =>
                          _Tile(item: list[i]),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends ConsumerWidget {
  const _Tile({required this.item});
  final MarketplaceListing item;

  static const Map<String, Color> _typeColors = {
    'verschenken': AppColors.leben,
    'tauschen': AppColors.teal,
    'verkaufen': AppColors.amber,
    'leihen': AppColors.tealSoft,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _typeColors[item.listingType] ?? AppColors.amber;
    final firstImage =
        item.images.isNotEmpty ? item.images.first : item.thumbnailUrl;
    final savedAsync = ref.watch(savedListingIdsProvider);
    final isSaved = savedAsync.value?.contains(item.id) ?? false;
    return InkWell(
      onTap: () => context.go('/dashboard/marketplace/${item.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.5),
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(11),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: firstImage != null
                          ? Image.network(
                              firstImage,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppColors.elevated,
                                child: const Center(
                                  child: Icon(LucideIcons.imageOff,
                                      color: AppColors.mute),
                                ),
                              ),
                            )
                          : Container(
                              color: AppColors.elevated,
                              alignment: Alignment.center,
                              child: const Icon(LucideIcons.package,
                                  color: AppColors.mute, size: 32),
                            ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () async {
                        await MarketplaceFavorites.toggle(item.id);
                        ref.invalidate(savedListingIdsProvider);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.voidColor.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSaved
                              ? LucideIcons.heart
                              : LucideIcons.bookmark,
                          size: 14,
                          color: isSaved
                              ? AppColors.amber
                              : AppColors.inkSoft,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          item.listingType.toUpperCase(),
                          style: AppTypography.label(size: 8, color: color),
                        ),
                      ),
                      const Spacer(),
                      if (item.price != null && item.listingType == 'verkaufen')
                        Text(
                          '${item.price!.toStringAsFixed(0)} €',
                          style: AppTypography.mono(
                            size: 13,
                            color: AppColors.amber,
                            weight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      size: 12,
                      color: AppColors.ink,
                      weight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
