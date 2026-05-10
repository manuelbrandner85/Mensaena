import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../routing/routes.dart';
import '../../theme/app_colors.dart';
import 'models.dart';

/// Pendant zur Web-`CrisisMap.tsx`. Zeigt alle Krisen mit Geo-Koordinaten als
/// geclusterte Marker. Farbe pro Urgency, Emoji aus Category-Config.
class CrisisMapView extends StatefulWidget {
  const CrisisMapView({super.key, required this.items});
  final List<Crisis> items;

  @override
  State<CrisisMapView> createState() => _CrisisMapViewState();
}

class _CrisisMapViewState extends State<CrisisMapView> {
  final _mapController = MapController();
  static const _austriaCenter = LatLng(47.5, 13.5);

  List<Crisis> get _geoCrises =>
      widget.items.where((c) => c.latitude != null && c.longitude != null).toList();

  @override
  void didUpdateWidget(covariant CrisisMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fitBoundsIfNeeded();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitBoundsIfNeeded());
  }

  void _fitBoundsIfNeeded() {
    final geo = _geoCrises;
    if (geo.length < 2) return;
    var minLat = geo.first.latitude!;
    var maxLat = geo.first.latitude!;
    var minLng = geo.first.longitude!;
    var maxLng = geo.first.longitude!;
    for (final c in geo) {
      if (c.latitude! < minLat) minLat = c.latitude!;
      if (c.latitude! > maxLat) maxLat = c.latitude!;
      if (c.longitude! < minLng) minLng = c.longitude!;
      if (c.longitude! > maxLng) maxLng = c.longitude!;
    }
    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(40),
        maxZoom: 12,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final geo = _geoCrises;
    if (geo.isEmpty) {
      return const _EmptyMap();
    }
    return FlutterMap(
      mapController: _mapController,
      options: const MapOptions(
        initialCenter: _austriaCenter,
        initialZoom: 7,
        minZoom: 4,
        maxZoom: 18,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'de.mensaena.app',
        ),
        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            maxClusterRadius: 50,
            size: const Size(44, 44),
            markers: [
              for (final c in geo)
                Marker(
                  width: 36,
                  height: 36,
                  point: LatLng(c.latitude!, c.longitude!),
                  child: GestureDetector(
                    onTap: () =>
                        context.go('${Routes.dashboardCrisis}/${c.id}'),
                    child: _CrisisMarker(crisis: c),
                  ),
                ),
            ],
            builder: (context, markers) => DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.emergency500,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 6),
                ],
              ),
              child: Center(
                child: Text(
                  '${markers.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CrisisMarker extends StatelessWidget {
  const _CrisisMarker({required this.crisis});
  final Crisis crisis;

  @override
  Widget build(BuildContext context) {
    final urg = crisis.urgency;
    final isCriticalActive = urg == CrisisUrgency.critical &&
        (crisis.status == CrisisStatus.active ||
            crisis.status == CrisisStatus.inProgress);
    return Container(
      decoration: BoxDecoration(
        color: urg.color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
          if (isCriticalActive)
            BoxShadow(
              color: urg.color.withValues(alpha: 0.6),
              blurRadius: 12,
              spreadRadius: 2,
            ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        crisis.categoryConfig.emoji,
        style: const TextStyle(fontSize: 14),
      ),
    );
  }
}

class _EmptyMap extends StatelessWidget {
  const _EmptyMap();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.stone100,
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 48, color: AppColors.stone400),
              SizedBox(height: 12),
              Text(
                'Keine Krisen mit Standort',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Text(
                'Krisen ohne Geo-Koordinaten erscheinen nur in der Liste.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.ink400),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
