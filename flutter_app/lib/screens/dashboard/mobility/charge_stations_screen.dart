/// SKILL: mensaena-features + mensaena-design
/// E-Auto-Ladestationen-Karte via OSM Overpass.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../services/charge_stations_service.dart';
import '../../../services/location_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/editorial_module_header.dart';
import '../../../widgets/shared/empty_state_card.dart';

class ChargeStationsScreen extends ConsumerStatefulWidget {
  const ChargeStationsScreen({super.key});
  @override
  ConsumerState<ChargeStationsScreen> createState() =>
      _ChargeStationsScreenState();
}

class _ChargeStationsScreenState
    extends ConsumerState<ChargeStationsScreen> {
  final _mapCtrl = MapController();
  LatLng _center = const LatLng(51.1657, 10.4515);
  final double _zoom = 12;
  int _radiusKm = 15;
  List<ChargeStation> _stations = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  @override
  void dispose() {
    _mapCtrl.dispose();
    super.dispose();
  }

  Future<void> _initAndLoad() async {
    try {
      final pos = await LocationService.getCurrentPosition(
          accuracy: LocationAccuracy.medium);
      if (mounted) {
        setState(() => _center = LatLng(pos.latitude, pos.longitude));
        _mapCtrl.move(_center, _zoom);
      }
    } catch (_) {}
    await _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await ChargeStationsService.nearby(
      lat: _center.latitude,
      lng: _center.longitude,
      radiusKm: _radiusKm,
    );
    if (!mounted) return;
    setState(() {
      _stations = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'charge.title'.tr(),
      currentRoute: '/dashboard/mobility/charge',
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: EditorialModuleHeader(
                metaIndex: '§ 18',
                metaCategory: 'charge.section'.tr(),
                title: 'charge.title'.tr(),
                subtitle: 'charge.subtitle'.tr(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Text('charge.radius'.tr(namedArgs: {'km': '$_radiusKm'}),
                      style: AppTypography.label(size: 10)),
                  Expanded(
                    child: Slider(
                      value: _radiusKm.toDouble(),
                      min: 3,
                      max: 50,
                      divisions: 9,
                      activeColor: AppColors.tealSoft,
                      onChanged: (v) =>
                          setState(() => _radiusKm = v.round()),
                      onChangeEnd: (_) => _load(),
                    ),
                  ),
                  Text('${_stations.length}',
                      style: AppTypography.mono(
                          size: 12, color: AppColors.tealSoft)),
                ],
              ),
            ),
            Expanded(
              child: _stations.isEmpty && !_loading
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: EmptyStateCard(
                        icon: LucideIcons.zap,
                        title: 'charge.none'.tr(),
                        description: 'charge.noneHint'.tr(),
                      ),
                    )
                  : Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapCtrl,
                          options: MapOptions(
                            initialCenter: _center,
                            initialZoom: _zoom,
                            minZoom: 3,
                            maxZoom: 18,
                            onMapEvent: (event) {
                              if (event is MapEventMoveEnd) {
                                _center = _mapCtrl.camera.center;
                              }
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'de.mensaena.app',
                            ),
                            MarkerLayer(
                              markers: [
                                for (final s in _stations)
                                  Marker(
                                    point: LatLng(s.lat, s.lng),
                                    width: 32,
                                    height: 32,
                                    child: GestureDetector(
                                      onTap: () => _openSheet(s),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.tealSoft,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: AppColors.voidColor,
                                              width: 2),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Icon(LucideIcons.zap,
                                            size: 14, color: Colors.white),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        if (_loading)
                          const Positioned(
                            top: 12,
                            right: 12,
                            child: Card(
                              color: AppColors.deep,
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.tealSoft),
                                ),
                              ),
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

  void _openSheet(ChargeStation s) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                        color: AppColors.tealSoft, shape: BoxShape.circle),
                    child: const Icon(LucideIcons.zap,
                        size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.name ?? s.operator ?? 'charge.unnamed'.tr(),
                      style: AppTypography.display(
                          size: 16, color: AppColors.ink),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (s.operator != null)
                Text(s.operator!,
                    style: AppTypography.body(
                        size: 12, color: AppColors.inkSoft)),
              Wrap(
                spacing: 6,
                children: [
                  if (s.socket != null) _MetaPill(text: s.socket!.toUpperCase()),
                  if (s.capacityKw != null)
                    _MetaPill(text: '${s.capacityKw!.toStringAsFixed(0)} kW'),
                  if (s.fee == true)
                    _MetaPill(text: 'charge.fee'.tr()),
                  if (s.fee == false)
                    _MetaPill(text: 'charge.free'.tr()),
                ],
              ),
              const SizedBox(height: 8),
              Text('${s.lat.toStringAsFixed(4)}, ${s.lng.toStringAsFixed(4)}',
                  style: AppTypography.caption()),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.tealSoft.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: AppTypography.mono(size: 10, color: AppColors.tealSoft)),
    );
  }
}
