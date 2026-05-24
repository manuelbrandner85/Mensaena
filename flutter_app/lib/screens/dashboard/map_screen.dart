import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/post.dart';
import '../../repositories/posts_repository.dart';
import '../../services/location_service.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: flutter-build-responsive-layout + mensaena-features
/// Karten-Screen — Pendant zur Web /dashboard/map mit Leaflet.
/// Tiles: OpenStreetMap (KEIN Google Maps).
/// Cluster bei vielen Markern. Tap auf Marker oeffnet Post-Bottom-Sheet.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const LatLng _defaultCenter = LatLng(51.1657, 10.4515); // Mitte DE
  static const List<int> _radiusOptions = [5, 10, 25, 50, 100];

  final MapController _mapController = MapController();
  LatLng _center = _defaultCenter;
  double _zoom = 6;
  int _radiusKm = 10;
  List<Post> _posts = const [];
  bool _loading = true;
  String? _error;
  bool _hasGps = false;

  @override
  void initState() {
    super.initState();
    _initLocationAndLoad();
  }

  Future<void> _initLocationAndLoad() async {
    try {
      final pos = await LocationService.getCurrentPosition(
        accuracy: LocationAccuracy.medium,
      );
      if (!mounted) return;
      setState(() {
        _center = LatLng(pos.latitude, pos.longitude);
        _zoom = 12;
        _hasGps = true;
      });
      _mapController.move(_center, _zoom);
    } catch (_) {
      // GPS verweigert / nicht verfuegbar — Default-Center (Mitte DE).
    }
    await _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final posts = await PostsRepository.getNearby(
        lat: _hasGps ? _center.latitude : null,
        lng: _hasGps ? _center.longitude : null,
        radiusKm: _radiusKm,
        limit: 100,
      );
      if (!mounted) return;
      setState(() {
        _posts = posts.where(_hasGeo).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Konnte Beiträge nicht laden.';
        _loading = false;
      });
    }
  }

  bool _hasGeo(Post p) => p.latitude != null && p.longitude != null;

  Future<void> _recenterOnGps() async {
    try {
      final pos = await LocationService.getCurrentPosition(
        accuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _center = loc;
        _hasGps = true;
      });
      _mapController.move(loc, 13);
      await _loadPosts();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('map.locationUnavailable'.tr()),
        ),
      );
    }
  }

  void _openPostSheet(Post post) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PostBottomSheet(post: post),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'Karte',
      currentRoute: '/dashboard/map',
      fab: FloatingActionButton(
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.voidColor,
        onPressed: _recenterOnGps,
        child: const Icon(LucideIcons.locate),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: _zoom,
              minZoom: 3,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'de.mensaena.app',
              ),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 50,
                  size: const Size(40, 40),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(50),
                  markers: _posts.map(_buildMarker).toList(),
                  builder: (context, markers) {
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.amber,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.voidColor,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${markers.length}',
                          style: AppTypography.mono(
                            size: 13,
                            color: AppColors.voidColor,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          // ── Radius-Selector oben ────────────────────────────────────
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _RadiusBar(
              options: _radiusOptions,
              selected: _radiusKm,
              loading: _loading,
              count: _posts.length,
              error: _error,
              onSelect: (km) {
                setState(() => _radiusKm = km);
                _loadPosts();
              },
            ),
          ),
        ],
      ),
    );
  }

  Marker _buildMarker(Post p) {
    final color = _markerColor(p.type);
    return Marker(
      point: LatLng(p.latitude!, p.longitude!),
      width: 36,
      height: 36,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () => _openPostSheet(p),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.voidColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.6),
                blurRadius: 8,
              ),
            ],
          ),
          child: Center(
            child: Text(
              _markerEmoji(p.type),
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }

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
}

// ── Radius-Bar ───────────────────────────────────────────────────────────
class _RadiusBar extends StatelessWidget {
  const _RadiusBar({
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.loading,
    required this.count,
    required this.error,
  });

  final List<int> options;
  final int selected;
  final ValueChanged<int> onSelect;
  final bool loading;
  final int count;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.deep.withValues(alpha: 0.92),
        border: Border.all(color: AppColors.lineActive),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.target,
                size: 13,
                color: AppColors.amber,
              ),
              const SizedBox(width: 6),
              Text(
                'Radius',
                style: AppTypography.label(size: 9),
              ),
              const Spacer(),
              if (loading)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    color: AppColors.amber,
                  ),
                )
              else if (error != null)
                Text(
                  error!,
                  style: AppTypography.body(
                    size: 11,
                    color: AppColors.herzrotWarm,
                  ),
                )
              else
                Text(
                  '$count Beiträge',
                  style: AppTypography.mono(
                    size: 11,
                    color: AppColors.ink,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: options
                .map(
                  (km) => GestureDetector(
                    onTap: () => onSelect(km),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: km == selected
                            ? AppColors.amber.withValues(alpha: 0.2)
                            : AppColors.surface.withValues(alpha: 0.7),
                        border: Border.all(
                          color:
                              km == selected ? AppColors.amber : AppColors.line,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$km km',
                        style: AppTypography.mono(
                          size: 11,
                          color: km == selected
                              ? AppColors.amber
                              : AppColors.inkSoft,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ── Post-Bottom-Sheet ────────────────────────────────────────────────────
class _PostBottomSheet extends StatelessWidget {
  const _PostBottomSheet({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
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
            const SizedBox(height: 18),
            Text(
              post.title,
              style: AppTypography.display(
                size: 22,
                height: 1.2,
                color: AppColors.ink,
              ),
            ),
            if (post.description != null && post.description!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                post.description!,
                style: AppTypography.body(
                  size: 14,
                  color: AppColors.inkSoft,
                  height: 1.55,
                ),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (post.locationText != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    LucideIcons.mapPin,
                    size: 14,
                    color: AppColors.mute,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      post.locationText!,
                      style: AppTypography.body(
                        size: 13,
                        color: AppColors.mute,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('common.close'.tr()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.go('/dashboard/posts/${post.id}');
                    },
                    icon: const Icon(LucideIcons.arrowRight, size: 16),
                    label: Text('common.open'.tr()),
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
