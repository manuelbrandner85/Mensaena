import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../routing/routes.dart';
import '../../theme/app_colors.dart';
import 'models.dart';

/// Pendant zur Web-`EventMap.tsx` / `EventMapInner.tsx`.
/// Zeigt alle Events mit Geo-Koordinaten als geclusterte Marker.
class EventMapView extends StatefulWidget {
  const EventMapView({super.key, required this.events});
  final List<EventItem> events;

  @override
  State<EventMapView> createState() => _EventMapViewState();
}

class _EventMapViewState extends State<EventMapView> {
  final _mapController = MapController();
  static const _austriaCenter = LatLng(47.5, 13.5);

  List<EventItem> get _geoEvents => widget.events
      .where((e) => e.latitude != null && e.longitude != null)
      .toList();

  @override
  void didUpdateWidget(covariant EventMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fitBoundsIfNeeded();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitBoundsIfNeeded());
  }

  void _fitBoundsIfNeeded() {
    final geo = _geoEvents;
    if (geo.length < 2) return;
    var minLat = geo.first.latitude!;
    var maxLat = geo.first.latitude!;
    var minLng = geo.first.longitude!;
    var maxLng = geo.first.longitude!;
    for (final e in geo) {
      if (e.latitude! < minLat) minLat = e.latitude!;
      if (e.latitude! > maxLat) maxLat = e.latitude!;
      if (e.longitude! < minLng) minLng = e.longitude!;
      if (e.longitude! > maxLng) maxLng = e.longitude!;
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(minLat, minLng),
          LatLng(maxLat, maxLng),
        ),
        padding: const EdgeInsets.all(40),
        maxZoom: 12,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final geo = _geoEvents;
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
              for (final e in geo)
                Marker(
                  width: 36,
                  height: 36,
                  point: LatLng(e.latitude!, e.longitude!),
                  child: GestureDetector(
                    onTap: () =>
                        context.go('${Routes.dashboardEvents}/${e.id}'),
                    child: _EventMarker(event: e),
                  ),
                ),
            ],
            builder: (context, markers) => DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.primary500,
                shape: BoxShape.circle,
                boxShadow: [
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

class _EventMarker extends StatelessWidget {
  const _EventMarker({required this.event});
  final EventItem event;

  @override
  Widget build(BuildContext context) {
    final cat = event.categoryConfig;
    return Container(
      decoration: BoxDecoration(
        color: cat.color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        cat.emoji,
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
                'Keine Events mit Standort',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Text(
                'Online-Events oder ohne Geo-Koordinaten erscheinen nur in der Liste.',
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
