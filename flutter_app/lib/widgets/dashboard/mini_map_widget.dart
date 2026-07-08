/// SKILL: mensaena-features
/// MiniMapWidget — kleine Karte mit Posts in der Naehe.
/// V7/V8: farbige Marker je Post-Typ + Emoji statt einheitlich Amber.
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

  /// Farbe je Post-Typ (1:1 zur map_screen-Logik).
  static Color _markerColor(String type) {
    switch (type) {
      case 'crisis':
      case 'help_request':
        return AppColors.herzrot;
      case 'help_offered':
        return AppColors.leben;
      case 'rescue':
        return const Color(0xFFFB923C);
      case 'animal':
        return const Color(0xFFEC4899);
      case 'housing':
        return const Color(0xFF60A5FA);
      case 'mobility':
        return const Color(0xFF818CF8);
      case 'sharing':
        return AppColors.teal;
      case 'mental':
        return AppColors.tealSoft;
      default:
        return AppColors.amber;
    }
  }

  /// Emoji je Post-Typ.
  static String _markerEmoji(String type) {
    switch (type) {
      case 'rescue':
        return '🧡';
      case 'animal':
        return '🐾';
      case 'housing':
        return '🏡';
      case 'supply':
        return '🌾';
      case 'mobility':
        return '🚗';
      case 'sharing':
        return '🔄';
      case 'community':
        return '🗳️';
      case 'crisis':
        return '🚨';
      case 'help_request':
        return '🆘';
      case 'help_offered':
        return '💚';
      case 'skill':
        return '🎯';
      case 'knowledge':
        return '📚';
      case 'mental':
        return '🧠';
      default:
        return '📍';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
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
                      lat: p.displayLat,
                      lng: p.displayLng,
                      color: _markerColor(p.type),
                      emoji: _markerEmoji(p.type),
                      type: p.type,
                      title: p.title,
                    ),
                ],
                initialZoom: 9,
                onMarkerTap: (m) =>
                    context.push('/dashboard/posts/${m.id}'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
