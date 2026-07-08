import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/organization_categories.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/organization.dart';
import '../../../models/organization_stats.dart';
import '../../../repositories/organizations_repository.dart';
import '../../../services/location_service.dart';
import '../../../widgets/effects/bloom.dart';
import '../../../widgets/effects/glass_card.dart';
import '../../../widgets/effects/parallax_hero.dart';
import '../../../widgets/effects/animated_entrance.dart';
import '../../../widgets/effects/shimmer_skeleton.dart';
import '../../../widgets/effects/tilt_card.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/editorial_module_header.dart';
import '../../../widgets/shared/empty_state_card.dart';
import '../../../widgets/shared/error_state_widget.dart';
import '../../../widgets/shared/location_map_view.dart';
import '../../../widgets/shared/module_search_bar.dart';
import '../../../widgets/shared/view_toggle.dart';

enum _OrgView { list, map }

/// SKILL: mensaena-features + mensaena-design
/// Organisationen-Verzeichnis — 1:1-Spiegel zur Web-`/dashboard/organizations`.
///
/// Aufbau (Phase O2):
///   - EditorialModuleHeader mit § 14 + ParallaxHero
///   - Stats-Bar (Total / Verifiziert / Bewertungen / Ø-Sterne) als
///     animierte TiltCard-Reihe in einer GlassCard.subtle.
///   - Country-Chip-Row (Alle / DE / AT / CH mit Flaggen).
///   - Filter-Row (Kategorie-BottomSheet + Sort-BottomSheet + Reset).
///   - ViewToggle Liste/Karte.
///   - ModuleSearchBar (350 ms Debounce) + GPS-Button fuer Distanz-Sort.
///   - Liste mit `_OrgCard` (Accent-Linie, Badges, Quick-Actions) ODER
///     LocationMapView mit kategorisierten Markern.
///   - FAB → /dashboard/organizations/suggest.
class OrganizationsScreen extends ConsumerStatefulWidget {
  const OrganizationsScreen({super.key});

  @override
  ConsumerState<OrganizationsScreen> createState() =>
      _OrganizationsScreenState();
}

class _OrganizationsScreenState extends ConsumerState<OrganizationsScreen> {
  // Filter-State
  String _country = 'all';
  String _category = 'all';
  String _search = '';
  String _sortBy = 'name';
  final bool _verifiedOnly = false;
  double? _lat;
  double? _lng;

  _OrgView _view = _OrgView.list;

  late final TextEditingController _searchCtrl;
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  bool get _hasFilters =>
      _country != 'all' ||
      _category != 'all' ||
      _search.isNotEmpty ||
      _sortBy != 'name' ||
      _lat != null;

  void _resetFilters() {
    setState(() {
      _country = 'all';
      _category = 'all';
      _sortBy = 'name';
      _search = '';
      _searchCtrl.clear();
      _lat = null;
      _lng = null;
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _search = value.trim());
    });
  }

  Future<void> _useGps() async {
    try {
      final pos = await LocationService.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _sortBy = 'distance';
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.raised,
          content: Text(
            'organizations.gpsError'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.ink),
          ),
        ),
      );
    }
  }

  /// Sortiert ein Result-Set lokal nach dem aktuellen `_sortBy` und
  /// filtert clientseitig nach Land (das RPC kennt keinen Country-Param).
  List<Organization> _processList(List<Organization> raw) {
    final filtered = raw.where((o) {
      if (_country != 'all' && o.country != _country) return false;
      return true;
    }).toList();
    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'rating':
          final cmp = b.ratingAvg.compareTo(a.ratingAvg);
          if (cmp != 0) return cmp;
          return b.ratingCount.compareTo(a.ratingCount);
        case 'newest':
          return b.createdAt.compareTo(a.createdAt);
        case 'distance':
          final da = a.distanceKm ?? double.infinity;
          final db = b.distanceKm ?? double.infinity;
          return da.compareTo(db);
        case 'name':
        default:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });
    return filtered;
  }

  ({
    String? searchText,
    String? category,
    bool verifiedOnly,
    double? lat,
    double? lng,
    double radiusKm,
    int limit,
    int offset,
  }) get _searchArgs => (
        searchText: _search.isEmpty ? null : _search,
        category: _category == 'all' ? null : _category,
        verifiedOnly: _verifiedOnly,
        lat: _lat,
        lng: _lng,
        radiusKm: 100.0,
        limit: 200,
        offset: 0,
      );

  @override
  Widget build(BuildContext context) {
    final asyncList = ref.watch(orgSearchProvider(_searchArgs));
    final asyncStats = ref.watch(orgStatsProvider);

    return DashboardScaffold(
      title: 'organizations.organizationsTitle'.tr(),
      currentRoute: '/dashboard/organizations',
      fab: Bloom(
        color: AppColors.amber,
        radius: 28,
        intensity: 0.85,
        child: FloatingActionButton.extended(
          backgroundColor: AppColors.amber,
          foregroundColor: AppColors.voidColor,
          onPressed: () => context.go('/dashboard/organizations/suggest'),
          icon: const Icon(LucideIcons.plus),
          label: Text('organizations.suggestOrg'.tr()),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.amber,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            ref.invalidate(orgSearchProvider(_searchArgs));
            ref.invalidate(orgStatsProvider);
          },
          child: CustomScrollView(
            controller: _scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Header (ParallaxHero) ─────────────────────────────
              SliverToBoxAdapter(
                child: ParallaxHero(
                  scrollController: _scrollCtrl,
                  height: 150,
                  factor: 0.35,
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.deep,
                          AppColors.surface,
                          AppColors.elevated,
                        ],
                      ),
                    ),
                  ),
                  foreground: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    child: EditorialModuleHeader(
                      metaIndex: '§ 14',
                      metaCategory: 'organizations.organizationsTitle'.tr(),
                      title: 'organizations.organizationsTitle'.tr(),
                      subtitle: 'organizations.subtitle'.tr(),
                    ),
                  ),
                ),
              ),

              // ── Stats-Bar ────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: GlassCard.subtle(
                    padding: const EdgeInsets.all(10),
                    child: _StatsBar(stats: asyncStats),
                  ),
                ),
              ),

              // ── Country-Chips ────────────────────────────────────
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _CountryChip(
                        label: 'organizations.allCountries'.tr(),
                        active: _country == 'all',
                        onTap: () => setState(() => _country = 'all'),
                      ),
                      for (final entry in kCountryFlags.entries)
                        _CountryChip(
                          label:
                              '${entry.value}  ${kCountryLabels[entry.key] ?? entry.key}',
                          active: _country == entry.key,
                          onTap: () => setState(() => _country = entry.key),
                        ),
                    ],
                  ),
                ),
              ),

              // ── Filter-Row + ViewToggle ──────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  child: Row(
                    children: [
                      _FilterChipButton(
                        icon: LucideIcons.filter,
                        label: _category == 'all'
                            ? 'organizations.filter'.tr()
                            : getCategoryConfig(_category).label,
                        active: _category != 'all',
                        onTap: _openCategorySheet,
                      ),
                      const SizedBox(width: 6),
                      _FilterChipButton(
                        icon: LucideIcons.arrowUpDown,
                        label: _sortLabel(_sortBy),
                        active: _sortBy != 'name',
                        onTap: _openSortSheet,
                      ),
                      const Spacer(),
                      ViewToggle<_OrgView>(
                        value: _view,
                        options: [
                          ViewToggleOption(
                            value: _OrgView.list,
                            label: 'organizations.view.list'.tr(),
                            icon: LucideIcons.list,
                          ),
                          ViewToggleOption(
                            value: _OrgView.map,
                            label: 'organizations.view.map'.tr(),
                            icon: LucideIcons.mapPin,
                          ),
                        ],
                        onChanged: (v) => setState(() => _view = v),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Search-Bar + GPS-Button ──────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: ModuleSearchBar(
                          hintText:
                              'organizations.searchPlaceholder'.tr(),
                          onChanged: _onSearchChanged,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: _lat != null
                              ? AppColors.amber.withValues(alpha: 0.18)
                              : AppColors.elevated,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _lat != null
                                ? AppColors.amber.withValues(alpha: 0.4)
                                : AppColors.line,
                          ),
                        ),
                        child: IconButton(
                          onPressed: _useGps,
                          tooltip: 'organizations.useGps'.tr(),
                          icon: Icon(
                            LucideIcons.crosshair,
                            size: 16,
                            color: _lat != null
                                ? AppColors.amber
                                : AppColors.inkSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Reset-Button wenn Filter aktiv ───────────────────
              if (_hasFilters)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _resetFilters,
                        icon: const Icon(LucideIcons.x,
                            size: 12, color: AppColors.mute),
                        label: Text(
                          'organizations.resetFilters'.tr(),
                          style: AppTypography.label(
                            size: 10,
                            color: AppColors.mute,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Content (Liste oder Karte) ───────────────────────
              ..._buildContentSlivers(asyncList),

              // Spacing fuer FAB.
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildContentSlivers(AsyncValue<List<Organization>> async) {
    return [
      async.when(
        loading: () => SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  const _OrgCardSkeleton(),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
        error: (e, _) => SliverToBoxAdapter(
          child: ErrorStateWidget(
            onRetry: () => ref.invalidate(orgSearchProvider(_searchArgs)),
          ),
        ),
        data: (raw) {
          final list = _processList(raw);
          if (list.isEmpty) {
            return SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: EmptyStateCard(
                  icon: LucideIcons.building2,
                  title: 'organizations.empty.title'.tr(),
                  description: 'organizations.empty.description'.tr(),
                  actionLabel: 'organizations.suggestOrg'.tr(),
                  onAction: () =>
                      context.go('/dashboard/organizations/suggest'),
                ),
              ),
            );
          }
          if (_view == _OrgView.map) {
            return SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                child: SizedBox(
                  height: 480,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: LocationMapView(
                      initialCenter: (_lat != null && _lng != null)
                          ? LatLng(_lat!, _lng!)
                          : null,
                      markers: [
                        for (final o in list)
                          MapMarkerData(
                            id: o.id,
                            lat: o.displayLat,
                            lng: o.displayLng,
                            color: _hexToColor(
                                getCategoryConfig(o.category).markerColor),
                            title: o.name,
                            subtitle: o.city,
                            icon: getCategoryConfig(o.category).icon,
                          ),
                      ],
                      onMarkerTap: (m) {
                        // CRASH-FIX (Audit): firstWhere ohne orElse warf
                        // StateError, wenn ein Marker noch vom alten State
                        // sichtbar war, die Org aber bereits entfernt
                        // wurde. Jetzt: Tap fällt sauber auf m.id zurück.
                        final match = list.where((o) => o.id == m.id);
                        final slugOrId =
                            match.isNotEmpty ? (match.first.slug ?? m.id) : m.id;
                        context.go('/dashboard/organizations/$slugOrId');
                      },
                    ),
                  ),
                ),
              ),
            );
          }
          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            sliver: SliverList.builder(
              itemCount: list.length,
              itemBuilder: (context, i) => AnimatedEntrance(
                index: i,
                child: _OrgCard(org: list[i]),
              ),
            ),
          );
        },
      ),
    ];
  }

  String _sortLabel(String key) {
    switch (key) {
      case 'rating':
        return 'organizations.sortRating'.tr();
      case 'newest':
        return 'organizations.sortNewest'.tr();
      case 'distance':
        return 'organizations.sortDistance'.tr();
      case 'name':
      default:
        return 'organizations.sort'.tr();
    }
  }

  void _openCategorySheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.deep,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (sheetCtx) {
        return _CategorySheet(
          selected: _category,
          onPick: (value) {
            setState(() => _category = value);
            Navigator.of(sheetCtx).pop();
          },
        );
      },
    );
  }

  void _openSortSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.deep,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        final entries = <(String, String)>[
          ('name', 'organizations.sortName'.tr()),
          ('rating', 'organizations.sortRating'.tr()),
          ('newest', 'organizations.sortNewest'.tr()),
          ('distance', 'organizations.sortDistance'.tr()),
        ];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'organizations.sort'.tr(),
                  style: AppTypography.display(size: 18, color: AppColors.ink),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in entries)
                      ChoiceChip(
                        backgroundColor: AppColors.elevated,
                        selectedColor: AppColors.amber.withValues(alpha: 0.22),
                        side: BorderSide(
                          color: _sortBy == e.$1
                              ? AppColors.amber.withValues(alpha: 0.5)
                              : AppColors.line,
                        ),
                        label: Text(
                          e.$2,
                          style: AppTypography.body(
                            size: 12,
                            color: _sortBy == e.$1
                                ? AppColors.amber
                                : AppColors.inkSoft,
                            weight: FontWeight.w600,
                          ),
                        ),
                        selected: _sortBy == e.$1,
                        onSelected: (_) {
                          setState(() => _sortBy = e.$1);
                          Navigator.of(sheetCtx).pop();
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// Stats-Bar
// ═════════════════════════════════════════════════════════════════

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.stats});
  final AsyncValue<OrganizationStats> stats;

  @override
  Widget build(BuildContext context) {
    return stats.when(
      loading: () => Row(
        children: List.generate(
          4,
          (i) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == 3 ? 0 : 8),
              child: const ShimmerBox(height: 64, borderRadius: 12),
            ),
          ),
        ),
      ),
      error: (_, __) => const SizedBox(height: 4),
      data: (s) {
        return Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: LucideIcons.building2,
                color: AppColors.amber,
                value: s.total.toString(),
                label: 'organizations.stats.total'.tr(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                icon: LucideIcons.badgeCheck,
                color: AppColors.leben,
                value: s.verified.toString(),
                label: 'organizations.stats.verified'.tr(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                icon: LucideIcons.messageSquare,
                color: AppColors.teal,
                value: s.withReviews.toString(),
                label: 'organizations.stats.reviews'.tr(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                icon: LucideIcons.star,
                color: AppColors.trust,
                value: s.avgRating > 0
                    ? s.avgRating.toStringAsFixed(1)
                    : '—',
                label: 'organizations.stats.avgRating'.tr(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TiltCard(
      intensity: 0.5,
      borderRadius: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.elevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.mono(
                size: 18,
                color: AppColors.ink,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label(size: 8, color: AppColors.mute),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// Country-Chip
// ═════════════════════════════════════════════════════════════════

class _CountryChip extends StatelessWidget {
  const _CountryChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? AppColors.amber.withValues(alpha: 0.2)
                : AppColors.elevated,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active
                  ? AppColors.amber.withValues(alpha: 0.5)
                  : AppColors.line,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.body(
              size: 12,
              color: active ? AppColors.amber : AppColors.inkSoft,
              weight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// Filter-Chip-Button (Top-Bar)
// ═════════════════════════════════════════════════════════════════

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppColors.amber.withValues(alpha: 0.18)
              : AppColors.elevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active
                ? AppColors.amber.withValues(alpha: 0.4)
                : AppColors.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: active ? AppColors.amber : AppColors.inkSoft),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.label(
                size: 10,
                color: active ? AppColors.amber : AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// Category-Sheet
// ═════════════════════════════════════════════════════════════════

class _CategorySheet extends StatelessWidget {
  const _CategorySheet({required this.selected, required this.onPick});
  final String selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final all = <_CategoryEntry>[
      _CategoryEntry(
        value: 'all',
        label: 'organizations.allCategories'.tr(),
        icon: LucideIcons.layoutGrid,
        color: AppColors.amber,
        bgColor: AppColors.amber,
      ),
      for (final c in kOrgCategories)
        _CategoryEntry(
          value: c.value,
          label: c.label,
          icon: c.icon,
          color: c.color,
          bgColor: c.bgColor,
        ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'organizations.filter'.tr(),
              style: AppTypography.display(size: 18, color: AppColors.ink),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 130,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.0,
                ),
                itemCount: all.length,
                itemBuilder: (context, i) {
                  final e = all[i];
                  final isSelected = selected == e.value;
                  return GestureDetector(
                    onTap: () => onPick(e.value),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: e.bgColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? e.color.withValues(alpha: 0.6)
                              : AppColors.line,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(e.icon, size: 22, color: e.color),
                          const SizedBox(height: 6),
                          Text(
                            e.label,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body(
                              size: 10,
                              color: AppColors.ink,
                              weight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryEntry {
  const _CategoryEntry({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
  });
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
}

// ═════════════════════════════════════════════════════════════════
// Organisation-Card
// ═════════════════════════════════════════════════════════════════

class _OrgCard extends StatelessWidget {
  const _OrgCard({required this.org});
  final Organization org;

  @override
  Widget build(BuildContext context) {
    final cat = getCategoryConfig(org.category);
    final openStatus = isCurrentlyOpen(org.openingHoursJson);
    final accentColor =
        org.isEmergency ? AppColors.herzrot : AppColors.amber;

    return GestureDetector(
      onTap: () => context
          .go('/dashboard/organizations/${org.slug ?? org.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 3px Accent-Linie
            Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor, Colors.transparent],
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon-Box / Logo
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: cat.bgColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: org.logoUrl != null && org.logoUrl!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: org.logoUrl!,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  fadeInDuration:
                                      const Duration(milliseconds: 180),
                                  errorWidget: (_, __, ___) =>
                                      Icon(cat.icon,
                                          color: cat.color, size: 22),
                                ),
                              )
                            : Icon(cat.icon, color: cat.color, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    org.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.body(
                                      size: 14,
                                      color: AppColors.ink,
                                      weight: FontWeight.w700,
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                                if (org.country.isNotEmpty &&
                                    kCountryFlags[org.country] != null) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    kCountryFlags[org.country]!,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _Pill(
                                  label: cat.label,
                                  color: cat.color,
                                  bgColor: cat.bgColor
                                      .withValues(alpha: 0.18),
                                ),
                                if (org.isVerified)
                                  _MicroBadge(
                                    icon: LucideIcons.shieldCheck,
                                    label: 'organizations.verified'.tr(),
                                    color: AppColors.leben,
                                  ),
                                if (org.isEmergency)
                                  _MicroBadge(
                                    icon: LucideIcons.alertTriangle,
                                    label: 'organizations.emergency'.tr(),
                                    color: AppColors.herzrot,
                                  ),
                                if (org.city.isNotEmpty)
                                  _IconText(
                                    icon: LucideIcons.mapPin,
                                    label: org.city,
                                  ),
                                if (openStatus == 'open')
                                  _IconText(
                                    icon: LucideIcons.clock,
                                    label:
                                        'organizations.nowOpen'.tr(),
                                    color: AppColors.leben,
                                  )
                                else if (openStatus == 'closed')
                                  _IconText(
                                    icon: LucideIcons.clock,
                                    label:
                                        'organizations.nowClosed'.tr(),
                                    color: AppColors.mute,
                                  ),
                                if (org.distanceKm != null)
                                  Text(
                                    '${org.distanceKm!.toStringAsFixed(1)} km',
                                    style: AppTypography.mono(
                                      size: 10,
                                      color: AppColors.bronze,
                                    ),
                                  ),
                              ],
                            ),
                            if (org.ratingCount > 0) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  for (var i = 0; i < 5; i++)
                                    Icon(
                                      i < org.ratingAvg.round()
                                          ? LucideIcons.star
                                          : LucideIcons.star,
                                      size: 12,
                                      color: i < org.ratingAvg.round()
                                          ? AppColors.trust
                                          : AppColors.ghost,
                                    ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '(${org.ratingCount})',
                                    style: AppTypography.caption(),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 6),
                            if ((org.shortDescription != null &&
                                    org.shortDescription!.isNotEmpty) ||
                                (org.description != null &&
                                    org.description!.isNotEmpty))
                              Text(
                                org.shortDescription ?? org.description ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.body(
                                  size: 12,
                                  color: AppColors.inkSoft,
                                  height: 1.45,
                                ),
                              ),
                            if (org.tags.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  for (final t in org.tags.take(4))
                                    _TagPill(label: t),
                                  if (org.tags.length > 4)
                                    _TagPill(
                                        label: '+${org.tags.length - 4}'),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Quick-Actions
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        if (org.phone != null && org.phone!.isNotEmpty)
                          _ActionChip(
                            icon: LucideIcons.phone,
                            label: 'organizations.actions.call'.tr(),
                            onTap: () => _open('tel:${org.phone}'),
                          ),
                        if (org.website != null && org.website!.isNotEmpty)
                          _ActionChip(
                            icon: LucideIcons.globe,
                            label: 'organizations.actions.web'.tr(),
                            onTap: () => _open(org.website!),
                          ),
                        if (org.email != null && org.email!.isNotEmpty)
                          _ActionChip(
                            icon: LucideIcons.mail,
                            label: 'organizations.actions.mail'.tr(),
                            onTap: () => _open('mailto:${org.email}'),
                          ),
                        if (org.displayLat != null && org.displayLng != null)
                          _ActionChip(
                            icon: LucideIcons.mapPin,
                            label: 'organizations.actions.map'.tr(),
                            onTap: () => _open(
                                'https://www.openstreetmap.org/?mlat=${org.displayLat}&mlon=${org.displayLng}#map=15/${org.displayLat}/${org.displayLng}'),
                          ),
                        _ActionChip(
                          icon: LucideIcons.arrowRight,
                          label: 'organizations.actions.details'.tr(),
                          highlight: true,
                          onTap: () => context.go(
                              '/dashboard/organizations/${org.slug ?? org.id}'),
                        ),
                      ],
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

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
    required this.bgColor,
  });
  final String label;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTypography.label(size: 9, color: color),
      ),
    );
  }
}

class _MicroBadge extends StatelessWidget {
  const _MicroBadge({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTypography.label(size: 8, color: color),
          ),
        ],
      ),
    );
  }
}

class _IconText extends StatelessWidget {
  const _IconText({
    required this.icon,
    required this.label,
    this.color,
  });
  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.mute;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: c),
        const SizedBox(width: 3),
        Text(label, style: AppTypography.caption(color: c)),
      ],
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.line),
      ),
      child: Text(
        label,
        style: AppTypography.label(
          size: 8,
          color: AppColors.inkSoft,
          letterSpacing: 0.04,
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final fg = highlight ? AppColors.amber : AppColors.inkSoft;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: highlight
                ? AppColors.amber.withValues(alpha: 0.12)
                : AppColors.elevated,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: highlight
                  ? AppColors.amber.withValues(alpha: 0.4)
                  : AppColors.line,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: fg),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppTypography.label(size: 9, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// Skeleton-Card
// ═════════════════════════════════════════════════════════════════

class _OrgCardSkeleton extends StatelessWidget {
  const _OrgCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerBox(width: 44, height: 44, borderRadius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerBox(height: 13, width: 160),
                const SizedBox(height: 8),
                ShimmerBox(
                  height: 10,
                  width: MediaQuery.sizeOf(context).width * 0.5,
                ),
                const SizedBox(height: 8),
                ShimmerBox(
                  height: 10,
                  width: MediaQuery.sizeOf(context).width * 0.4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// Hex-Color Helper
// ═════════════════════════════════════════════════════════════════

Color _hexToColor(String hex) {
  var clean = hex.replaceAll('#', '').toUpperCase();
  if (clean.length == 6) clean = 'FF$clean';
  return Color(int.parse(clean, radix: 16));
}
