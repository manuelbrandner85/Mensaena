import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

/// SKILL: mensaena-design
/// Wiederverwendbarer Karten-View — Pendant zu Web-`CrisisMap` / `EventMap` /
/// `SupplyMap`. OpenStreetMap-Tiles im Light-Mode, CartoDB Dark Matter im
/// Dark-Mode. Tile-Caching via FMTC (7-Tage-Cache). MarkerCluster ab >5
/// Markern. Tap auf Marker oeffnet [onMarkerTap] Callback.
class LocationMapView extends StatefulWidget {
  const LocationMapView({
    required this.markers,
    this.initialCenter,
    this.initialZoom = 11,
    this.onMarkerTap,
    super.key,
  });

  final List<MapMarkerData> markers;
  final LatLng? initialCenter;
  final double initialZoom;
  final ValueChanged<MapMarkerData>? onMarkerTap;

  @override
  State<LocationMapView> createState() => _LocationMapViewState();
}

class _LocationMapViewState extends State<LocationMapView> {
  static const LatLng _fallback = LatLng(51.1657, 10.4515);
  static const String _storeName = 'mensaena_tiles';

  final MapController _ctrl = MapController();
  bool _fmtcReady = false;

  @override
  void initState() {
    super.initState();
    _initFmtc();
  }

  Future<void> _initFmtc() async {
    try {
      // Wenn FMTC schon in main.dart initialisiert wurde, ist das idempotent.
      // Store-Erstellung ebenfalls idempotent ueber FMTCStore.manage.ready.
      await FMTCObjectBoxBackend().initialise();
      const store = FMTCStore(_storeName);
      final exists = await store.manage.ready;
      if (!exists) {
        await store.manage.create();
      }
      if (mounted) setState(() => _fmtcReady = true);
    } catch (_) {
      // FMTC nicht verfuegbar — Tiles werden ohne Cache geladen.
      _fmtcReady = false;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _tileUrl(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

  @override
  Widget build(BuildContext context) {
    final markersWithLocation = widget.markers
        .where((m) => m.lat != null && m.lng != null)
        .toList();
    LatLng center = widget.initialCenter ??
        (markersWithLocation.isNotEmpty
            ? LatLng(markersWithLocation.first.lat!,
                markersWithLocation.first.lng!)
            : _fallback);

    return Stack(
      children: [
        FlutterMap(
          mapController: _ctrl,
          options: MapOptions(
            initialCenter: center,
            initialZoom: widget.initialZoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: _tileUrl(context),
              userAgentPackageName: 'de.mensaena.app',
              tileProvider: _fmtcReady
                  ? const FMTCStore(_storeName).getTileProvider(
                      settings: FMTCTileProviderSettings(
                        cachedValidDuration: const Duration(days: 7),
                      ),
                    )
                  : NetworkTileProvider(),
            ),
            MarkerClusterLayerWidget(
              options: MarkerClusterLayerOptions(
                maxClusterRadius: 60,
                size: const Size(38, 38),
                markers: [
                  for (final m in markersWithLocation)
                    Marker(
                      point: LatLng(m.lat!, m.lng!),
                      width: 36,
                      height: 36,
                      child: GestureDetector(
                        onTap: () => widget.onMarkerTap?.call(m),
                        child: _Pin(
                          color: m.color,
                          icon: m.icon,
                          emoji: m.emoji,
                        ),
                      ),
                    ),
                ],
                builder: (ctx, mks) {
                  return Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.88),
                      border: Border.all(
                          color: AppColors.amberWarm, width: 2),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${mks.length}',
                      style: AppTypography.mono(
                          size: 13, color: AppColors.voidColor),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        // Attribution
        Positioned(
          right: 4,
          bottom: 2,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            color: AppColors.voidColor.withValues(alpha: 0.7),
            child: Text(
              '© OpenStreetMap',
              style: AppTypography.label(size: 7, color: AppColors.mute),
            ),
          ),
        ),
        // Empty-Marker Hint
        if (markersWithLocation.isEmpty)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.92),
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.mapPin,
                      size: 14, color: AppColors.mute),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.markers.isEmpty
                          ? 'Keine Einträge.'
                          : 'Keine Einträge mit Standort.',
                      style: AppTypography.caption(),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.color, this.icon, this.emoji});
  final Color color;
  final IconData? icon;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: AppColors.ink, width: 1.5),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: emoji != null
          ? Text(emoji!, style: const TextStyle(fontSize: 16))
          : Icon(
              icon ?? LucideIcons.mapPin,
              size: 16,
              color: AppColors.voidColor,
            ),
    );
  }
}

/// Marker-Datensatz: Position + Farbe + optional Icon/Emoji + Tap-Payload.
class MapMarkerData {
  const MapMarkerData({
    required this.id,
    required this.lat,
    required this.lng,
    required this.color,
    required this.title,
    this.subtitle,
    this.icon,
    this.emoji,
    this.type,
  });

  final String id;
  final double? lat;
  final double? lng;
  final Color color;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? emoji;
  final String? type;
}
