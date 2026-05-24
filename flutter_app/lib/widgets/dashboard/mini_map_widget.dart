/// SKILL: mensaena-features
/// MiniMapWidget — kleine Karte mit Posts in der Naehe.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/post.dart';
import '../shared/location_map_view.dart';

class MiniMapWidget extends StatelessWidget {
  const MiniMapWidget({super.key, required this.posts});
  final List<Post> posts;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
            child: Row(
              children: [
                const Icon(LucideIcons.mapPin,
                    color: AppColors.amber, size: 14),
                const SizedBox(width: 6),
                Text('home.map'.tr(),
                    style: AppTypography.label(
                        size: 10, color: AppColors.amber)),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/dashboard/map'),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 24),
                  ),
                  child: Text('home.fullscreen'.tr(),
                      style: AppTypography.label(
                          size: 9, color: AppColors.amber)),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 180,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(11)),
              child: LocationMapView(
                markers: [
                  for (final p in posts)
                    MapMarkerData(
                      id: p.id,
                      lat: p.latitude,
                      lng: p.longitude,
                      color: AppColors.amber,
                      title: p.title,
                    ),
                ],
                initialZoom: 9,
                onMarkerTap: (m) =>
                    context.go('/dashboard/posts/${m.id}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
