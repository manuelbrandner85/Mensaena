import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/marketplace_repository.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

class MarketplaceDetailScreen extends ConsumerWidget {
  const MarketplaceDetailScreen({required this.listingId, super.key});
  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(marketplaceDetailProvider(listingId));
    return DashboardScaffold(
      title: 'Inserat',
      currentRoute: '/dashboard/marketplace',
      body: SafeArea(
        child: async.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.amber),
          ),
          error: (e, _) => Center(child: Text('$e', style: AppTypography.caption())),
          data: (l) {
            if (l == null) {
              return Center(
                child: Text('Inserat nicht gefunden.',
                    style: AppTypography.caption()),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (l.images.isNotEmpty)
                  SizedBox(
                    height: 240,
                    child: PageView.builder(
                      itemCount: l.images.length,
                      itemBuilder: (context, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(l.images[i], fit: BoxFit.cover),
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(l.listingType.toUpperCase(),
                          style: AppTypography.label(size: 9)),
                    ),
                    const SizedBox(width: 6),
                    Text(l.category, style: AppTypography.label(size: 9)),
                    const Spacer(),
                    if (l.price != null)
                      Text(
                        '${l.price!.toStringAsFixed(0)} €',
                        style: AppTypography.mono(
                          size: 18,
                          color: AppColors.amber,
                          weight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  l.title,
                  style: AppTypography.display(
                    size: 24,
                    color: AppColors.ink,
                    height: 1.2,
                  ),
                ),
                if (l.conditionState != null) ...[
                  const SizedBox(height: 6),
                  Text('Zustand: ${l.conditionState}',
                      style: AppTypography.caption()),
                ],
                const SizedBox(height: 12),
                Text(
                  l.description,
                  style: AppTypography.body(
                    size: 14,
                    color: AppColors.inkSoft,
                    height: 1.55,
                  ),
                ),
                if (l.locationText != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(LucideIcons.mapPin,
                          size: 14, color: AppColors.amber),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(l.locationText!,
                            style: AppTypography.body(
                              size: 13,
                              color: AppColors.inkSoft,
                            )),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  'Inseriert am ${DateFormat('dd.MM.yyyy').format(l.createdAt)}',
                  style: AppTypography.caption(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
