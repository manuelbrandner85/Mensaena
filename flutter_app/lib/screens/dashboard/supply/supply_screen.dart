import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/farm_listing.dart';
import '../../../repositories/organizations_repository.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

/// Versorgung — Bauernhöfe / Hofläden / Direktvermarkter
class SupplyScreen extends ConsumerWidget {
  const SupplyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(farmsListProvider);
    return DashboardScaffold(
      title: 'Versorgung',
      currentRoute: '/dashboard/supply',
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.amber,
          backgroundColor: AppColors.surface,
          onRefresh: () async => ref.invalidate(farmsListProvider),
          child: async.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.amber),
            ),
            error: (e, _) => Center(child: Text('$e', style: AppTypography.caption())),
            data: (list) {
              if (list.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    Center(
                      child: Column(
                        children: [
                          const Icon(LucideIcons.wheat,
                              size: 32, color: AppColors.mute),
                          const SizedBox(height: 10),
                          Text(
                            'Noch keine Hoflisten in deiner Region.',
                            style: AppTypography.body(
                              size: 14,
                              color: AppColors.mute,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (context, i) => _FarmTile(farm: list[i]),
              );
            },
          ),
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
                child: Image.network(
                  farm.imageUrl!,
                  height: 130,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.elevated,
                    height: 130,
                    child: const Center(
                      child:
                          Icon(LucideIcons.imageOff, color: AppColors.mute),
                    ),
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
