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
import '../../../widgets/effects/animated_entrance.dart';
import '../../../widgets/effects/shimmer_skeleton.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/empty_state_widget.dart';
import '../../../widgets/shared/error_state_widget.dart';
import '../../../widgets/shared/image_carousel.dart';
import '../../../widgets/shared/module_search_bar.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class SharingScreen extends ConsumerStatefulWidget {
  const SharingScreen({super.key});

  @override
  ConsumerState<SharingScreen> createState() => _SharingScreenState();
}

class _SharingScreenState extends ConsumerState<SharingScreen> {
  String _search = '';
  String _filter = 'all'; // 'all' | 'giveaway' | 'swap'

  List<MarketplaceListing> _apply(List<MarketplaceListing> all) {
    final q = _search.trim().toLowerCase();
    return all.where((m) {
      if (_filter != 'all' && m.listingType != _filter) return false;
      if (q.isEmpty) return true;
      return m.title.toLowerCase().contains(q) ||
          m.description.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sharingListingsProvider);
    return DashboardScaffold(
      title: 'sharing.screenTitle'.tr(),
      currentRoute: '/dashboard/sharing',
      fab: FloatingActionButton.extended(
        backgroundColor: AppColors.primary500,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/dashboard/sharing/giveaway-create'),
        icon: const Icon(Icons.volunteer_activism_rounded),
        label: Text('sharing.fabLabel'.tr()),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header-Hint ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary500.withValues(alpha: 0.08),
                  border: Border.all(
                      color: AppColors.primary500.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.volunteer_activism_rounded,
                        size: 16, color: AppColors.primary500),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'sharing.hint'.tr(),
                        style: AppTypography.body(
                            size: 12, color: AppColors.inkSoft),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── Suche + Filter-Chips ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: ModuleSearchBar(
                hintText: 'sharing.searchPlaceholder'.tr(),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  _FilterChip(
                    label: 'sharing.filterAll'.tr(),
                    active: _filter == 'all',
                    onTap: () => setState(() => _filter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'sharing.filterGiveaway'.tr(),
                    active: _filter == 'giveaway',
                    color: AppColors.leben,
                    onTap: () => setState(() => _filter = 'giveaway'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'sharing.filterSwap'.tr(),
                    active: _filter == 'swap',
                    color: AppColors.teal,
                    onTap: () => setState(() => _filter = 'swap'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // ── Liste ─────────────────────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary500,
                backgroundColor: AppColors.surface,
                onRefresh: () async =>
                    ref.invalidate(sharingListingsProvider),
                child: async.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary500),
                  ),
                  error: (_, __) => Center(
                    child: ErrorStateWidget(
                      onRetry: () =>
                          ref.invalidate(sharingListingsProvider),
                    ),
                  ),
                  data: (all) {
                    final list = _apply(all);
                    if (list.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          const SizedBox(height: 40),
                          EmptyStateWidget(
                            icon: Icons.volunteer_activism_rounded,
                            title: _search.isNotEmpty || _filter != 'all'
                                ? 'sharing.noMatches'.tr()
                                : 'sharing.noListings'.tr(),
                            subtitle: _search.isNotEmpty || _filter != 'all'
                                ? 'sharing.noMatchesHint'.tr()
                                : 'sharing.beFirstHint'.tr(),
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
                        child: _SharingTile(item: list[i]),
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

// ── Filter-Chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.color,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary500;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? c.withValues(alpha: 0.18) : AppColors.elevated,
          border: Border.all(
            color: active ? c : AppColors.line,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: AppTypography.label(
            size: 11,
            color: active ? c : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}

// ── Listing-Tile ──────────────────────────────────────────────────────────────

class _SharingTile extends StatelessWidget {
  const _SharingTile({required this.item});
  final MarketplaceListing item;

  static const Map<String, List<Color>> _gradients = {
    'giveaway': [AppColors.leben, AppColors.lebenSoft],
    'swap': [AppColors.teal, AppColors.tealSoft],
  };

  static const Map<String, Color> _typeColors = {
    'giveaway': AppColors.leben,
    'swap': AppColors.teal,
  };

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
  Widget build(BuildContext context) {
    final gradient = _gradients[item.listingType] ??
        [AppColors.primary500, AppColors.tealSoft];
    final color = _typeColors[item.listingType] ?? AppColors.primary500;
    final urls = _resolveUrls();
    final isClaimed =
        item.status == 'claimed' || item.status == 'sold';

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
            // Type accent bar
            Container(
              height: 3,
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(11)),
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
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.zero,
                      child: urls.length > 1
                          ? ImageCarousel(
                              urls: urls,
                              borderRadius: 0,
                              height: 180,
                            )
                          : urls.length == 1
                              ? Hero(
                                  tag: 'sharing-image-${item.id}',
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
                                  child: const Icon(
                                    Icons.volunteer_activism_rounded,
                                    color: AppColors.mute,
                                    size: 32,
                                  ),
                                ),
                    ),
                  ),
                  if (isClaimed)
                    Positioned.fill(
                      child: ClipRRect(
                        child: BackdropFilter(
                          filter:
                              ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                          child: Container(
                            color: AppColors.voidColor.withValues(alpha: 0.25),
                            alignment: Alignment.center,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.herzrot.withValues(alpha: 0.85),
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
                          item.listingType == 'giveaway'
                              ? 'sharing.badgeGiveaway'.tr()
                              : 'sharing.badgeSwap'.tr(),
                          style: AppTypography.label(size: 8, color: color),
                        ),
                      ),
                      const Spacer(),
                      if (item.listingType == 'giveaway')
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.leben.withValues(alpha: 0.18),
                            border: Border.all(
                                color: AppColors.leben.withValues(alpha: 0.5)),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'sharing.badgeFree'.tr(),
                            style: AppTypography.mono(
                              size: 9,
                              color: AppColors.leben,
                              weight: FontWeight.w700,
                            ),
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
