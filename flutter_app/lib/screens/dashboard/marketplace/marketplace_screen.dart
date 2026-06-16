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
import '../../../services/location_service.dart';
import '../../../widgets/effects/animated_entrance.dart';
import '../../../widgets/effects/shimmer_skeleton.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/editorial_module_header.dart';
import '../../../widgets/shared/empty_state_widget.dart';
import '../../../widgets/shared/error_state_widget.dart';
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
  double? _maxPrice;
  double? _maxDistanceKm;
  ({double lat, double lng})? _myPos;

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
    FilterOption(value: 'neu', label: 'Neu'),
    FilterOption(value: 'sehr_gut', label: 'Wie neu'),
    FilterOption(value: 'gut', label: 'Gut'),
    FilterOption(value: 'gebraucht', label: 'Gebraucht'),
  ];

  bool get _hasFilters =>
      _search.isNotEmpty ||
      _category != null ||
      _condition != null ||
      _type != 'all' ||
      _maxPrice != null ||
      _maxDistanceKm != null;

  List<MarketplaceListing> _apply(List<MarketplaceListing> all) {
    final q = _search.trim().toLowerCase();
    return all.where((m) {
      if (_category != null && m.category != _category) return false;
      if (_condition != null && m.condition != _condition) return false;
      if (_maxPrice != null && m.price != null && m.price! > _maxPrice!) {
        return false;
      }
      if (_maxDistanceKm != null &&
          _myPos != null &&
          m.latitude != null &&
          m.longitude != null) {
        final d = LocationService.haversineKm(
            _myPos!.lat, _myPos!.lng, m.latitude!, m.longitude!);
        if (d > _maxDistanceKm!) return false;
      }
      if (q.isEmpty) return true;
      return m.title.toLowerCase().contains(q) ||
          m.description.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _ensureMyPos() async {
    if (_myPos != null) return;
    try {
      final pos = await LocationService.getCurrentPosition()
          .timeout(const Duration(seconds: 6));
      if (!mounted) return;
      setState(() => _myPos = (lat: pos.latitude, lng: pos.longitude));
    } catch (_) {/* keep null — distance filter then ignored */}
  }

  Future<void> _openAdvancedFilters() async {
    final result = await showModalBottomSheet<(double?, double?)>(
      context: context,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => _AdvancedFilterSheet(
        initialMaxPrice: _maxPrice,
        initialMaxDistanceKm: _maxDistanceKm,
      ),
    );
    if (result == null) return;
    setState(() {
      _maxPrice = result.$1;
      _maxDistanceKm = result.$2;
    });
    if (_maxDistanceKm != null) await _ensureMyPos();
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
                        'marketplace.nonCommercialHint'.tr(),
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
              child: Row(
                children: [
                  Expanded(
                    child: ModuleSearchBar(
                      hintText: 'marketplace.searchPlaceholder'.tr(),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: (_maxPrice != null || _maxDistanceKm != null)
                          ? AppColors.amber.withValues(alpha: 0.18)
                          : AppColors.elevated,
                      border: Border.all(
                        color: (_maxPrice != null || _maxDistanceKm != null)
                            ? AppColors.amber.withValues(alpha: 0.6)
                            : AppColors.line,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      tooltip: 'marketplace.advancedFilters'.tr(),
                      icon: const Icon(LucideIcons.slidersHorizontal,
                          size: 18, color: AppColors.amber),
                      onPressed: _openAdvancedFilters,
                    ),
                  ),
                ],
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
                allLabel: 'marketplace.allCategories'.tr(),
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
                allLabel: 'marketplace.allConditions'.tr(),
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
                            .firstWhere((t) => t.value == _type,
                                orElse: () => _types.first)
                            .label,
                        onRemove: () => setState(() => _type = 'all'),
                      ),
                    if (_category != null)
                      ActiveFilterChip(
                        label: _categories
                            .firstWhere((c) => c.value == _category,
                                orElse: () => _categories.first)
                            .label,
                        onRemove: () => setState(() => _category = null),
                      ),
                    if (_condition != null)
                      ActiveFilterChip(
                        label: _conditions
                            .firstWhere((c) => c.value == _condition,
                                orElse: () => _conditions.first)
                            .label,
                        onRemove: () => setState(() => _condition = null),
                      ),
                    if (_search.isNotEmpty)
                      ActiveFilterChip(
                        label: '🔍 $_search',
                        onRemove: () => setState(() => _search = ''),
                      ),
                    if (_maxPrice != null)
                      ActiveFilterChip(
                        label: '≤ ${_maxPrice!.toStringAsFixed(0)} €',
                        onRemove: () => setState(() => _maxPrice = null),
                      ),
                    if (_maxDistanceKm != null)
                      ActiveFilterChip(
                        label: '≤ ${_maxDistanceKm!.toStringAsFixed(0)} km',
                        onRemove: () =>
                            setState(() => _maxDistanceKm = null),
                      ),
                  ],
                  onClearAll: () => setState(() {
                    _type = 'all';
                    _category = null;
                    _condition = null;
                    _search = '';
                    _maxPrice = null;
                    _maxDistanceKm = null;
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
                  error: (e, _) => Center(
                    child: ErrorStateWidget(
                      onRetry: () {
                        ref.invalidate(marketplaceListingsFilteredProvider);
                        ref.invalidate(marketplaceStatsProvider);
                      },
                    ),
                  ),
                  data: (all) {
                    final list = _apply(all);
                    if (list.isEmpty) {
                      return ListView(
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          const SizedBox(height: 40),
                          EmptyStateWidget(
                            icon: LucideIcons.store,
                            title: _hasFilters
                                ? 'marketplace.noMatches'.tr()
                                : 'marketplace.noListings'.tr(),
                            subtitle: _hasFilters
                                ? 'marketplace.noMatchesHint'.tr()
                                : 'marketplace.beFirstHint'.tr(),
                            actionLabel: _hasFilters
                                ? 'marketplace.resetFilters'.tr()
                                : null,
                            onAction: _hasFilters
                                ? () => setState(() {
                                      _type = 'all';
                                      _category = null;
                                      _condition = null;
                                      _search = '';
                                      _maxPrice = null;
                                      _maxDistanceKm = null;
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
                      itemBuilder: (context, i) => AnimatedEntrance(
                        index: i,
                        child: _Tile(item: list[i]),
                      ),
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
    final isReserved = item.reservedUntil != null &&
        item.reservedUntil!.isAfter(DateTime.now());
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
                  // Reserved-Badge (amber oben links auf dem Bild).
                  if (isReserved)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.amber.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'marketplace.reserved'.tr(),
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
                      // F70: Preis-Indikator je Listing-Typ farb-codiert.
                      _PriceBadge(
                        listingType: item.listingType,
                        price: item.price,
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

/// E3: BottomSheet mit Preis- und Distanz-Slider. Liefert beim Schließen
/// ein Tuple zurück (maxPrice, maxDistanceKm), beide nullable.
class _AdvancedFilterSheet extends StatefulWidget {
  const _AdvancedFilterSheet({
    required this.initialMaxPrice,
    required this.initialMaxDistanceKm,
  });
  final double? initialMaxPrice;
  final double? initialMaxDistanceKm;

  @override
  State<_AdvancedFilterSheet> createState() => _AdvancedFilterSheetState();
}

class _AdvancedFilterSheetState extends State<_AdvancedFilterSheet> {
  late double? _price = widget.initialMaxPrice;
  late double? _km = widget.initialMaxDistanceKm;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('marketplace.advancedFilters'.tr(),
                style: AppTypography.body(
                    size: 16,
                    color: AppColors.ink,
                    weight: FontWeight.w700)),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(LucideIcons.banknote,
                    size: 16, color: AppColors.amber),
                const SizedBox(width: 8),
                Text('marketplace.maxPrice'.tr(),
                    style: AppTypography.body(
                        size: 13, color: AppColors.inkSoft)),
                const Spacer(),
                Text(
                  _price == null
                      ? 'marketplace.anyPrice'.tr()
                      : '≤ ${_price!.toStringAsFixed(0)} €',
                  style: AppTypography.body(
                      size: 13,
                      color: AppColors.amber,
                      weight: FontWeight.w700),
                ),
              ],
            ),
            Slider(
              value: _price ?? 500,
              min: 0,
              max: 500,
              divisions: 50,
              activeColor: AppColors.amber,
              onChanged: (v) => setState(() => _price = v >= 500 ? null : v),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(LucideIcons.mapPin,
                    size: 16, color: AppColors.bronze),
                const SizedBox(width: 8),
                Text('marketplace.maxDistance'.tr(),
                    style: AppTypography.body(
                        size: 13, color: AppColors.inkSoft)),
                const Spacer(),
                Text(
                  _km == null
                      ? 'marketplace.anyDistance'.tr()
                      : '≤ ${_km!.toStringAsFixed(0)} km',
                  style: AppTypography.body(
                      size: 13,
                      color: AppColors.bronze,
                      weight: FontWeight.w700),
                ),
              ],
            ),
            Slider(
              value: _km ?? 100,
              min: 1,
              max: 100,
              divisions: 99,
              activeColor: AppColors.bronze,
              onChanged: (v) => setState(() => _km = v >= 100 ? null : v),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _price = null;
                        _km = null;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.inkSoft,
                      side: const BorderSide(color: AppColors.line),
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: Text('common.reset'.tr()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, (_price, _km)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.amber,
                      foregroundColor: AppColors.voidColor,
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: Text('common.confirm'.tr()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// F70: Preis-Indikator für Listing-Tile.
/// Gratis → leben-grün · Tausch → tealSoft · Verkauf → bronze · Leihen → amber.
class _PriceBadge extends StatelessWidget {
  const _PriceBadge({required this.listingType, required this.price});
  final String listingType;
  final double? price;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (listingType) {
      'verschenken' => (AppColors.leben, 'marketplace.badgeFree'.tr()),
      'tauschen' => (AppColors.tealSoft, 'marketplace.badgeSwap'.tr()),
      'verkaufen' => (
          AppColors.bronze,
          price != null && price! > 0
              ? '${price!.toStringAsFixed(0)} €'
              : 'marketplace.badgeFree'.tr(),
        ),
      'leihen' => (AppColors.amber, 'marketplace.badgeLend'.tr()),
      _ => (AppColors.amber, ''),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.mono(
          size: 11,
          color: color,
          weight: FontWeight.w700,
        ),
      ),
    );
  }
}
