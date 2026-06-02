import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/farm_listing.dart';
import '../../../repositories/organizations_repository.dart';
import '../../../utils/safe_launch.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/image_carousel.dart';

class FarmDetailScreen extends ConsumerStatefulWidget {
  const FarmDetailScreen({required this.slug, super.key});
  final String slug;

  @override
  ConsumerState<FarmDetailScreen> createState() => _FarmDetailScreenState();
}

class _FarmDetailScreenState extends ConsumerState<FarmDetailScreen> {
  Future<FarmListing?>? _future;

  @override
  void initState() {
    super.initState();
    _future = FarmsRepository.getBySlug(widget.slug);
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'modules.farm'.tr(),
      currentRoute: '/dashboard/supply',
      body: SafeArea(
        child: FutureBuilder<FarmListing?>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.amber),
              );
            }
            final f = snap.data;
            if (f == null) {
              return Center(
                child: Text('supply.farmNotFound'.tr(),
                    style: AppTypography.caption()),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Vorher wurde nur f.imageUrl (1 Bild) gezeigt, obwohl der
                // Create-Screen bis zu 5 Fotos hochladen lässt → 4 Fotos
                // waren faktisch unsichtbar. Jetzt: vollständige Galerie mit
                // Lightbox (Tap → Vollbild). Fallback auf imageUrl falls
                // media_urls leer ist (alte Datensätze).
                if (f.mediaUrls.isNotEmpty || f.imageUrl != null)
                  ImageCarousel(
                    urls: f.mediaUrls.isNotEmpty
                        ? f.mediaUrls
                        : <String>[f.imageUrl!],
                    height: 220,
                    borderRadius: 14,
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        f.name,
                        style: AppTypography.display(
                          size: 26,
                          color: AppColors.ink,
                          height: 1.2,
                        ),
                      ),
                    ),
                    if (f.isBio == true)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.leben.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('BIO',
                            style: AppTypography.label(
                              size: 9,
                              color: AppColors.lebenSoft,
                            )),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('${f.category} · ${f.city}',
                    style: AppTypography.label(size: 10)),
                if (f.description != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    f.description!,
                    style: AppTypography.body(
                      size: 14,
                      color: AppColors.inkSoft,
                      height: 1.55,
                    ),
                  ),
                ],
                if (f.products.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text('supply.products'.tr(), style: AppTypography.label(size: 10)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: f.products
                        .map((p) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.elevated,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(p,
                                  style: AppTypography.body(
                                    size: 11,
                                    color: AppColors.inkSoft,
                                  )),
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 14),
                if (f.address != null)
                  _Row(icon: LucideIcons.mapPin, label: f.address!),
                if (f.phone != null)
                  _Row(
                    icon: LucideIcons.phone,
                    label: f.phone!,
                    onTap: () =>
                        safeLaunch('tel:${f.phone}', context: context),
                  ),
                if (f.email != null)
                  _Row(
                    icon: LucideIcons.mail,
                    label: f.email!,
                    onTap: () =>
                        safeLaunch('mailto:${f.email}', context: context),
                  ),
                if (f.website != null)
                  _Row(
                    icon: LucideIcons.globe,
                    label: f.website!,
                    onTap: () => safeLaunch(
                      f.website!,
                      mode: LaunchMode.externalApplication,
                      autoHttps: true,
                      context: context,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Icon(icon, size: 14, color: AppColors.amber),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: AppTypography.body(
              size: 13,
              color: onTap != null ? AppColors.amber : AppColors.ink,
            ),
          ),
        ),
      ],
    );
    return onTap == null
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: row,
          )
        : InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4), child: row),
          );
  }
}
