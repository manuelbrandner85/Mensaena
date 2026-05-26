import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/marketplace_listing.dart';
import '../../../repositories/marketplace_repository.dart';
import '../../../widgets/effects/shimmer_skeleton.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/editorial_module_header.dart';
import '../../../widgets/shared/empty_state_card.dart';
import '../../../widgets/shared/filter_chip_bar.dart';
import '../../../widgets/shared/image_carousel.dart';
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
  bool _showClaimed = false;

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
    final async = ref.watch(marketplaceListingsFilteredProvider(
      (type: _type, includeClaimed: _showClaimed),
    ));
    final statsAsync = ref.watch(marketplaceStatsProvider);
    return DashboardScaffold(
      title: 'marketplace.screenTitle'.tr(),
      currentRoute: '/dashboard/marketplace',
      fab: FloatingActionButton.extended(
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.voidColor,
        onPressed: () => context.push('/dashboard/marketplace/create'),
        icon: const Icon(LucideIcons.plus),
        label: Text('marketplace.advertise'.tr()),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: EditorialModuleHeader(
                metaIndex: '§ 11',
                metaCategory: 'marketplace.screenTitle'.tr(),
                title: 'modules.marketplaceHero.title'.tr(),
                subtitle: 'modules.marketplaceHero.subtitle'.tr(),
              ),
            ),
            // Stats-Pill-Row
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: _StatsPillRow(
                stats: statsAsync.value,
                showClaimed: _showClaimed,
                onToggleClaimed: () =>
                    setState(() => _showClaimed = !_showClaimed),
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
                hintText: 'marketplace.searchPlaceholder'.tr(),
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
                onRefresh: () async {
                  ref.invalidate(marketplaceListingsFilteredProvider);
                  ref.invalidate(marketplaceStatsProvider);
                },
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

/// Stats-Pill-Row: 3 Pills (Anzeigen / gratis / vergeben).
/// Letzter Pill ist togglebar → schaltet _showClaimed in der Parent-State.
class _StatsPillRow extends StatelessWidget {
  const _StatsPillRow({
    required this.stats,
    required this.showClaimed,
    required this.onToggleClaimed,
  });

  final Map<String, int>? stats;
  final bool showClaimed;
  final VoidCallback onToggleClaimed;

  @override
  Widget build(BuildContext context) {
    final active = stats?['active'] ?? 0;
    final free = stats?['free'] ?? 0;
    final claimed = stats?['claimed'] ?? 0;
    return Row(
      children: [
        Expanded(
          child: _Pill(
            icon: LucideIcons.shoppingBag,
            color: AppColors.amber,
            label: 'marketplace.statsActive'
                .tr(namedArgs: {'n': active.toString()}),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Pill(
            icon: LucideIcons.gift,
            color: AppColors.leben,
            label: 'marketplace.statsFree'
                .tr(namedArgs: {'n': free.toString()}),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Pill(
            icon: LucideIcons.checkCircle,
            color: AppColors.mute,
            label: 'marketplace.statsClaimed'
                .tr(namedArgs: {'n': claimed.toString()}),
            active: showClaimed,
            activeColor: AppColors.mute,
            onTap: onToggleClaimed,
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.color,
    required this.label,
    this.active = false,
    this.activeColor,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final bool active;
  final Color? activeColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tint = activeColor ?? color;
    final bg = active
        ? tint.withValues(alpha: 0.18)
        : AppColors.surface;
    final borderColor = active ? tint : AppColors.line;
    final textColor = active ? tint : AppColors.inkSoft;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label(size: 10, color: textColor),
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
    'giveaway': AppColors.leben,
    'swap': AppColors.teal,
    'sell': AppColors.bronze,
  };

  /// 3px Top-Gradient pro listing_type.
  /// Akzeptiert DE-Werte (verschenken/tauschen/verkaufen) als Alias.
  static const Map<String, List<Color>> _typeGradient = {
    'giveaway': [AppColors.leben, AppColors.lebenSoft],
    'swap': [AppColors.teal, AppColors.tealSoft],
    'sell': [AppColors.bronze, AppColors.bronzeSoft],
    'verschenken': [AppColors.leben, AppColors.lebenSoft],
    'tauschen': [AppColors.teal, AppColors.tealSoft],
    'verkaufen': [AppColors.bronze, AppColors.bronzeSoft],
  };

  /// Robuste Bilder-Extraktion: item.images ist bereits List<String>,
  /// aber Fallback zu thumbnail_url + imageUrls für Altdaten.
  List<String> _resolveUrls() {
    final urls = <String>[];
    urls.addAll(item.images.where((u) => u.isNotEmpty));
    if (urls.isEmpty) {
      urls.addAll(item.imageUrls.where((u) => u.isNotEmpty));
    }
    if (urls.isEmpty && item.thumbnailUrl != null &&
        item.thumbnailUrl!.isNotEmpty) {
      urls.add(item.thumbnailUrl!);
    }
    return urls;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _typeColors[item.listingType] ?? AppColors.amber;
    final gradient = _typeGradient[item.listingType] ??
        const [AppColors.amber, AppColors.amberSoft];
    final urls = _resolveUrls();
    final savedAsync = ref.watch(savedListingIdsProvider);
    final isSaved = savedAsync.value?.contains(item.id) ?? false;
    final isClaimed = item.status == 'claimed' || item.status == 'sold';
    final isReserved = item.status == 'reserved';
    return InkWell(
      onTap: () => context.push('/dashboard/marketplace/${item.id}'),
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
            // 3px Top-Gradient pro listing_type.
            Container(
              height: 3,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(11),
                ),
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  // Image: Carousel wenn >1 Bild, sonst Single-Image.
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.zero,
                      child: urls.length > 1
                          ? ImageCarousel(
                              urls: urls,
                              borderRadius: 0,
                              height: 180,
                            )
                          : (urls.length == 1
                              ? Hero(
                                  tag: 'marketplace-image-${item.id}',
                                  child: CachedNetworkImage(
                                    imageUrl: urls.first,
                                    memCacheWidth: 400,
                                    memCacheHeight: 400,
                                    fadeInDuration:
                                        const Duration(milliseconds: 200),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    placeholder: (_, __) => const ShimmerBox(
                                      width: double.infinity,
                                      height: double.infinity,
                                      borderRadius: 0,
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      color: AppColors.elevated,
                                      alignment: Alignment.center,
                                      child: const Icon(LucideIcons.imageOff,
                                          size: 20, color: AppColors.mute),
                                    ),
                                  ),
                                )
                              : Container(
                                  color: AppColors.elevated,
                                  alignment: Alignment.center,
                                  child: const Icon(LucideIcons.package,
                                      color: AppColors.mute, size: 32),
                                )),
                    ),
                  ),
                  // Claimed-Overlay (blur + 'Vergeben'-Badge).
                  if (isClaimed)
                    Positioned.fill(
                      child: ClipRRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                          child: Container(
                            color: AppColors.voidColor.withValues(alpha: 0.25),
                            alignment: Alignment.center,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.herzrot
                                    .withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'marketplace.claimedBadge'.tr(),
                                style: AppTypography.label(
                                  size: 11,
                                  color: Colors.white,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Reserved-Badge (amber oben rechts auf dem Bild).
                  if (isReserved)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.amber.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'marketplace.reservedBadge'.tr(),
                          style: AppTypography.label(
                            size: 9,
                            color: AppColors.voidColor,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  // Favoriten-Button (top-right).
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
