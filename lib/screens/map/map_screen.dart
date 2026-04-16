import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/map_provider.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/models/map_pin.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  double _radiusKm = 50;
  LatLng _center = const LatLng(48.2082, 16.3738); // Wien default
  MapPin? _selectedPin;

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
  }

  Future<void> _loadUserLocation() async {
    final profile = await ref.read(currentProfileProvider.future);
    if (profile != null && profile.latitude != null && profile.longitude != null) {
      setState(() {
        _center = LatLng(profile.latitude!, profile.longitude!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pinsAsync = ref.watch(mapPinsProvider({
      'lat': _center.latitude,
      'lng': _center.longitude,
      'radius': _radiusKm,
    }));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Karte'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_outlined),
            onPressed: _showRadiusSheet,
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
              onTap: (_, __) => setState(() => _selectedPin = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'de.mensaena.app',
              ),
              pinsAsync.when(
                loading: () => const MarkerLayer(markers: []),
                error: (_, __) => const MarkerLayer(markers: []),
                data: (pins) => MarkerLayer(
                  markers: pins.map((pin) => _buildMarker(pin)).toList(),
                ),
              ),
            ],
          ),

          // Radius slider
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.radar, size: 18, color: AppColors.primary500),
                      const SizedBox(width: 8),
                      Text(
                        'Radius: ${_radiusKm.round()} km',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const Spacer(),
                      Text(
                        '${pinsAsync.valueOrNull?.length ?? 0} Ergebnisse',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  Slider(
                    value: _radiusKm,
                    min: 1,
                    max: 200,
                    divisions: 199,
                    activeColor: AppColors.primary500,
                    onChanged: (v) => setState(() => _radiusKm = v),
                    onChangeEnd: (v) {
                      ref.invalidate(mapPinsProvider);
                    },
                  ),
                ],
              ),
            ),
          ),

          // Selected pin detail
          if (_selectedPin != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 100,
              child: _buildPinDetail(_selectedPin!),
            ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100),
        child: FloatingActionButton(
          mini: true,
          onPressed: () {
            _mapController.move(_center, 12);
          },
          child: const Icon(Icons.my_location),
        ),
      ),
    );
  }

  Marker _buildMarker(MapPin pin) {
    Color markerColor;
    switch (pin.type) {
      case 'help_needed':
        markerColor = AppColors.emergency;
        break;
      case 'help_offered':
        markerColor = AppColors.success;
        break;
      case 'crisis':
        markerColor = AppColors.emergency;
        break;
      case 'organization':
        markerColor = AppColors.trust;
        break;
      default:
        markerColor = AppColors.primary500;
    }

    return Marker(
      point: LatLng(pin.latitude, pin.longitude),
      width: 36,
      height: 36,
      child: GestureDetector(
        onTap: () => setState(() => _selectedPin = pin),
        child: Container(
          decoration: BoxDecoration(
            color: markerColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: const Icon(Icons.location_on, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  Widget _buildPinDetail(MapPin pin) {
    return GestureDetector(
      onTap: () {
        if (pin.type == 'organization') {
          context.push('/dashboard/organizations/${pin.id}');
        } else {
          context.push('/dashboard/posts/${pin.id}');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.location_on, color: AppColors.primary500),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pin.title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (pin.locationText != null)
                    Text(
                      pin.locationText!,
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  void _showRadiusSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filteroptionen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            const Text('Suchradius', style: TextStyle(fontWeight: FontWeight.w600)),
            StatefulBuilder(
              builder: (context, setSheetState) => Slider(
                value: _radiusKm,
                min: 1,
                max: 200,
                divisions: 199,
                label: '${_radiusKm.round()} km',
                activeColor: AppColors.primary500,
                onChanged: (v) {
                  setSheetState(() => _radiusKm = v);
                  setState(() => _radiusKm = v);
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ref.invalidate(mapPinsProvider);
                  Navigator.pop(context);
                },
                child: const Text('Anwenden'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
