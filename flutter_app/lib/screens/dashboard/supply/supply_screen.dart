import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/farm_listing.dart';
import '../../../repositories/organizations_repository.dart';
import '../../../repositories/profiles_repository.dart';
import '../../../services/locale_country_service.dart';
import '../../../widgets/effects/shimmer_skeleton.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/effects/animated_entrance.dart';
import '../../../widgets/shared/editorial_module_header.dart';
import '../../../widgets/shared/empty_state_card.dart';
import '../../../widgets/shared/filter_chip_bar.dart';
import '../../../widgets/shared/location_map_view.dart';
import '../../../widgets/shared/module_search_bar.dart';
import '../../../widgets/shared/view_toggle.dart';

enum _SupplyView { list, map }

/// Versorgung — Bauernhöfe / Hofläden / Direktvermarkter.
/// 1:1 zu `src/app/dashboard/supply/page.tsx` (List + Map + Filter).
class SupplyScreen extends ConsumerStatefulWidget {
  const SupplyScreen({super.key});

  @override
  ConsumerState<SupplyScreen> createState() => _SupplyScreenState();
}

class _SupplyScreenState extends ConsumerState<SupplyScreen> {
  static const List<FilterOption<String>> _categories = [
    FilterOption(value: 'farm', label: '🚜 Hof'),
    FilterOption(value: 'shop', label: '🏪 Hofladen'),
    FilterOption(value: 'market', label: '🥬 Markt'),
    FilterOption(value: 'csa', label: '🌱 Solawi'),
    FilterOption(value: 'orchard', label: '🍎 Obstgarten'),
  ];

  _SupplyView _view = _SupplyView.list;
  String _search = '';
  String? _category;
  bool _bioOnly = false;

  bool get _hasFilters =>
      _search.isNotEmpty || _category != null || _bioOnly;

  List<FarmListing> _apply(List<FarmListing> all) {
    final q = _search.trim().toLowerCase();
    return all.where((f) {
      if (_category != null && f.category != _category) return false;
      if (_bioOnly && f.isBio != true) return false;
      if (q.isEmpty) return true;
      return f.name.toLowerCase().contains(q) ||
          f.city.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final country = LocaleCountryService.forContext(context);
    final myProfile = ref.watch(myProfileProvider).valueOrNull;
    // Bauernhoefe-Directory zeigt ALLE Hoefe im Land — kein restriktiver
    // Radius. User wollen browsen, nicht nur "neben mir". Radius bleibt
    // verfuegbar als Sortierung (naheste zuerst) via location-Filter im
    // Repo, aber alle anderen sind weiter sichtbar.
    // null = kein Radius-Filter, alle 500+ Farms im Land sichtbar.
    const int? radius = null;
    final lat = myProfile?.latitude ?? myProfile?.homeLat;
    final lng = myProfile?.longitude ?? myProfile?.homeLng;
    final args = (
      country: country,
      lat: lat,
      lng: lng,
      radiusKm: radius,
    );
    final async = ref.watch(farmsForUserProvider(args));
    return DashboardScaffold(
      title: 'supply.screenTitle'.tr(),
      currentRoute: '/dashboard/supply',
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: EditorialModuleHeader(
                metaIndex: '§ 13',
                metaCategory: 'supply.screenTitle'.tr(),
                title: 'modules.farms.title'.tr(),
                subtitle: 'modules.farms.subtitle'.tr(),
              ),
            ),
            // Info-Karte: erklärt was "Versorgung" meint.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.10),
                  border: Border.all(
                      color: AppColors.amber.withValues(alpha: 0.35)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(LucideIcons.info,
                      size: 16, color: AppColors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hier findest du Solidarische Landwirtschaft (Solawi), '
                      'Tafeln, Hofläden und Foodsharing-Stellen in deiner '
                      'Nähe — plus eigene Tausch- und Mitnehm-Angebote.',
                      style: AppTypography.body(
                          size: 12, color: AppColors.inkSoft, height: 1.4),
                    ),
                  ),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: InkWell(
                onTap: () => context.push('/dashboard/supply/foodbanks'),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.amber.withValues(alpha: 0.08),
                    border: Border.all(
                      color: AppColors.amber.withValues(alpha: 0.35),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.heartHandshake,
                          size: 18, color: AppColors.amber),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'foodbanks.title'.tr(),
                          style: AppTypography.body(
                            size: 13,
                            color: AppColors.ink,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(LucideIcons.chevronRight,
                          size: 16, color: AppColors.mute),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: ModuleSearchBar(
                      hintText: 'supply.searchPlaceholder'.tr(),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ViewToggle<_SupplyView>(
                    value: _view,
                    onChanged: (v) => setState(() => _view = v),
                    options: const [
                      ViewToggleOption(
                          value: _SupplyView.list,
                          label: 'Liste',
                          icon: LucideIcons.list),
                      ViewToggleOption(
                          value: _SupplyView.map,
                          label: 'Karte',
                          icon: LucideIcons.mapPin),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: FilterChipBar<String>(
                options: _categories,
                selected: _category == null ? const <String>{} : {_category!},
                onChanged: (s) =>
                    setState(() => _category = s.isEmpty ? null : s.first),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Row(
                children: [
                  Switch(
                    value: _bioOnly,
                    onChanged: (v) => setState(() => _bioOnly = v),
                    activeColor: AppColors.leben,
                  ),
                  Text('🌱 Nur BIO',
                      style: AppTypography.label(
                          size: 10,
                          color: _bioOnly
                              ? AppColors.lebenSoft
                              : AppColors.inkSoft)),
                ],
              ),
            ),
            if (_hasFilters)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ActiveFilterStrip(
                  chips: [
                    if (_category != null)
                      ActiveFilterChip(
                        label: _categories
                            .firstWhere((c) => c.value == _category)
                            .label,
                        onRemove: () => setState(() => _category = null),
                      ),
                    if (_bioOnly)
                      ActiveFilterChip(
                        label: '🌱 BIO',
                        onRemove: () => setState(() => _bioOnly = false),
                      ),
                    if (_search.isNotEmpty)
                      ActiveFilterChip(
                        label: '🔍 $_search',
                        onRemove: () => setState(() => _search = ''),
                      ),
                  ],
                  onClearAll: () => setState(() {
                    _search = '';
                    _category = null;
                    _bioOnly = false;
                  }),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.amber,
                backgroundColor: AppColors.surface,
                onRefresh: () async => ref.invalidate(farmsForUserProvider(args)),
                child: async.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.amber),
                  ),
                  error: (e, _) => Center(
                      child: Text('$e', style: AppTypography.caption())),
                  data: (all) {
                    final list = _apply(all);
                    if (_view == _SupplyView.map) {
                      return LocationMapView(
                        markers: [
                          for (final f in list)
                            MapMarkerData(
                              id: f.slug,
                              lat: f.latitude,
                              lng: f.longitude,
                              color: f.isBio == true
                                  ? AppColors.leben
                                  : AppColors.amber,
                              title: f.name,
                              subtitle: f.city,
                              icon: LucideIcons.wheat,
                            ),
                        ],
                        onMarkerTap: (m) =>
                            context.go('/dashboard/supply/${m.id}'),
                      );
                    }
                    if (list.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          const SizedBox(height: 60),
                          EmptyStateCard(
                            icon: LucideIcons.wheat,
                            title: _hasFilters
                                ? 'Keine Treffer.'
                                : 'Keine Höfe in deiner Region.',
                            description: _hasFilters
                                ? 'Andere Filter probieren.'
                                : null,
                            actionLabel:
                                _hasFilters ? 'Filter zurücksetzen' : null,
                            onAction: _hasFilters
                                ? () => setState(() {
                                      _search = '';
                                      _category = null;
                                      _bioOnly = false;
                                    })
                                : null,
                          ),
                        ],
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: list.length,
                      itemBuilder: (context, i) => AnimatedEntrance(
                        index: i,
                        child: _FarmTile(farm: list[i]),
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

class _FarmTile extends StatelessWidget {
  const _FarmTile({required this.farm});
  final FarmListing farm;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/dashboard/supply/${farm.slug}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.5),
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (farm.imageUrl != null)
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(11)),
                child: CachedNetworkImage(
                  imageUrl: farm.imageUrl!,
                  fadeInDuration: const Duration(milliseconds: 200),
                  height: 130,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const ShimmerBox(
                    width: double.infinity,
                    height: 130,
                    borderRadius: 0,
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: AppColors.elevated,
                    height: 130,
                    alignment: Alignment.center,
                    child: const Icon(LucideIcons.imageOff,
                        size: 20, color: AppColors.mute),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          farm.name,
                          style: AppTypography.body(
                            size: 15,
                            color: AppColors.ink,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (farm.isBio == true)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.leben.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'BIO',
                            style: AppTypography.label(
                              size: 8,
                              color: AppColors.lebenSoft,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(LucideIcons.mapPin,
                          size: 11, color: AppColors.mute),
                      const SizedBox(width: 3),
                      Text(farm.city, style: AppTypography.caption()),
                      const SizedBox(width: 8),
                      Text(farm.category,
                          style: AppTypography.label(size: 9)),
                    ],
                  ),
                  if (farm.products.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      farm.products.take(5).join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                        size: 12,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
