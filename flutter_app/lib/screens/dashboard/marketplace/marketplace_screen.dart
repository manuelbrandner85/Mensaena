import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/marketplace_listing.dart';
import '../../../repositories/marketplace_repository.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

class MarketplaceScreen extends ConsumerStatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  ConsumerState<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends ConsumerState<MarketplaceScreen> {
  String _type = 'all';

  static const List<({String value, String label, String emoji})> _types = [
    (value: 'all', label: 'Alle', emoji: '🛒'),
    (value: 'verschenken', label: 'Verschenken', emoji: '🎁'),
    (value: 'tauschen', label: 'Tauschen', emoji: '🔄'),
    (value: 'verkaufen', label: 'Günstig', emoji: '💶'),
    (value: 'leihen', label: 'Leihen', emoji: '📅'),
  ];

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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.08),
                  border:
                      Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
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
            SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: _types.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) {
                  final t = _types[i];
                  final active = t.value == _type;
                  return GestureDetector(
                    onTap: () => setState(() => _type = t.value),
                    child: Container(
                      alignment: Alignment.center,
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
                },
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.amber,
                backgroundColor: AppColors.surface,
                onRefresh: () async =>
                    ref.invalidate(marketplaceListingsProvider(_type)),
                child: async.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.amber),
                  ),
                  error: (e, _) =>
                      Center(child: Text('$e', style: AppTypography.caption())),
                  data: (list) {
                    if (list.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.store,
                                size: 32, color: AppColors.mute),
                            const SizedBox(height: 10),
                            Text(
                              'Keine Inserate in dieser Kategorie.',
                              style: AppTypography.body(
                                size: 14,
                                color: AppColors.mute,
                              ),
                            ),
                          ],
                        ),
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
                      itemBuilder: (context, i) => _Tile(item: list[i]),
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

class _Tile extends StatelessWidget {
  const _Tile({required this.item});
  final MarketplaceListing item;

  static const Map<String, Color> _typeColors = {
    'verschenken': AppColors.leben,
    'tauschen': AppColors.teal,
    'verkaufen': AppColors.amber,
    'leihen': AppColors.tealSoft,
  };

  @override
  Widget build(BuildContext context) {
    final color = _typeColors[item.listingType] ?? AppColors.amber;
    final firstImage =
        item.images.isNotEmpty ? item.images.first : item.thumbnailUrl;
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
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(11),
                ),
                child: firstImage != null
                    ? Image.network(
                        firstImage,
                        width: double.infinity,
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
