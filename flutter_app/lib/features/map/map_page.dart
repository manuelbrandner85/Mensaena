import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../routing/routes.dart';
import '../../theme/app_colors.dart';
import '../posts/models.dart';
import '../posts/posts_repository.dart';

/// Pendant zu /dashboard/map. Zeigt Posts mit Geo-Koordinaten als
/// geclusterte Marker. Default-Center: Wien (16.37, 48.21).
class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  final _mapController = MapController();
  static const _vienna = LatLng(48.2082, 16.3738);

  List<Post> _posts = [];
  bool _loading = true;
  LatLng _center = _vienna;
  int _radiusKm = 100;
  Position? _userLocation;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _resolveLocation();
    await _loadPosts();
  }

  Future<void> _resolveLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      ).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() {
        _userLocation = pos;
        _center = LatLng(pos.latitude, pos.longitude);
      });
    } catch (_) {
      // Silently fall back to Vienna
    }
  }

  Future<void> _loadPosts() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final list = await ref.read(postsRepositoryProvider).nearby(
            latitude: _center.latitude,
            longitude: _center.longitude,
            radiusKm: _radiusKm,
          );
      if (!mounted) return;
      setState(() {
        _posts = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  void _recenterToUser() {
    final loc = _userLocation;
    if (loc == null) return;
    final target = LatLng(loc.latitude, loc.longitude);
    _mapController.move(target, 13);
    setState(() => _center = target);
  }

  Marker _markerFor(Post post) {
    final cfg = post.typeConfig;
    return Marker(
      width: 40,
      height: 40,
      point: LatLng(post.latitude!, post.longitude!),
      child: GestureDetector(
        onTap: () => context.go('${Routes.dashboardPosts}/${post.id}'),
        child: Container(
          decoration: BoxDecoration(
            color: cfg.background,
            shape: BoxShape.circle,
            border: Border.all(color: cfg.color, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(cfg.emoji, style: const TextStyle(fontSize: 18)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = _posts
        .where((p) => p.latitude != null && p.longitude != null)
        .map(_markerFor)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Karte'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPosts,
            tooltip: 'Neu laden',
          ),
          PopupMenuButton<int>(
            icon: const Icon(Icons.tune),
            tooltip: 'Radius',
            onSelected: (km) {
              setState(() => _radiusKm = km);
              _loadPosts();
            },
            itemBuilder: (_) => const [
              PopupMenuItem<int>(value: 5, child: Text('5 km')),
              PopupMenuItem<int>(value: 10, child: Text('10 km')),
              PopupMenuItem<int>(value: 25, child: Text('25 km')),
              PopupMenuItem<int>(value: 50, child: Text('50 km')),
              PopupMenuItem<int>(value: 100, child: Text('100 km')),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 12,
              minZoom: 4,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'de.mensaena.app',
              ),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 60,
                  size: const Size(40, 40),
                  markers: markers,
                  builder: (context, cluster) => Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary500,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${cluster.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_loading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66FFFFFF),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          // Legend / count
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '${markers.length} Posts · ${_radiusKm} km',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _userLocation != null
          ? FloatingActionButton.small(
              onPressed: _recenterToUser,
              tooltip: 'Mein Standort',
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary500,
              child: const Icon(Icons.my_location),
            )
          : null,
    );
  }
}
