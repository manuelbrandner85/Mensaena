/// SKILL: mensaena-features + mensaena-design
/// Karte mit Wildfruchte-Spots + Verschenk-Schraenken via OSM Overpass.
/// Mundraub-Pattern als Free-Alternative (mundraub.org-API ist down).
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
import '../../../services/location_service.dart';
import '../../../services/mundraub_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/editorial_module_header.dart';
import '../../../widgets/shared/empty_state_card.dart';

class WildPicksScreen extends ConsumerStatefulWidget {
  const WildPicksScreen({super.key});

  @override
  ConsumerState<WildPicksScreen> createState() => _WildPicksScreenState();
}

class _WildPicksScreenState extends ConsumerState<WildPicksScreen> {
  final _mapCtrl = MapController();
  LatLng _center = const LatLng(51.1657, 10.4515);
  final double _zoom = 11;
  int _radiusKm = 10;
  List<FreePickSpot> _spots = const [];
  bool _loading = true;
  final Set<FreePickKind> _filter = {
    FreePickKind.fruit,
    FreePickKind.giveBox,
    FreePickKind.bookcase,
  };

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
    final spots = await MundraubService.nearby(
      lat: _center.latitude,
      lng: _center.longitude,
      radiusKm: _radiusKm,
    );
    if (!mounted) return;
    setState(() {
      _spots = spots;
      _loading = false;
    });
  }

  List<FreePickSpot> get _filtered =>
      _spots.where((s) => _filter.contains(s.kind)).toList();

  Color _color(FreePickKind k) {
    switch (k) {
      case FreePickKind.fruit:
        return AppColors.leben;
      case FreePickKind.giveBox:
        return AppColors.bronze;
      case FreePickKind.bookcase:
        return AppColors.tealSoft;
    }
  }

  IconData _icon(FreePickKind k) {
    switch (k) {
      case FreePickKind.fruit:
        return LucideIcons.apple;
      case FreePickKind.giveBox:
        return LucideIcons.gift;
      case FreePickKind.bookcase:
        return LucideIcons.bookOpen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final spots = _filtered;
    return DashboardScaffold(
      title: 'wildPicks.title'.tr(),
      currentRoute: '/dashboard/harvest/wild',
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: EditorialModuleHeader(
                metaIndex: '§ 12',
                metaCategory: 'wildPicks.section'.tr(),
                title: 'wildPicks.title'.tr(),
                subtitle: 'wildPicks.subtitle'.tr(),
              ),
            ),
            // Filter-Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 6,
                children: FreePickKind.values
                    .map((k) => _FilterChip(
                          icon: _icon(k),
                          label: 'wildPicks.kind.${k.name}'.tr(),
                          color: _color(k),
                          active: _filter.contains(k),
                          onToggle: () => setState(() {
                            if (_filter.contains(k)) {
                              _filter.remove(k);
                            } else {
                              _filter.add(k);
                            }
                          }),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Text('wildPicks.radius'.tr(namedArgs: {'km': '$_radiusKm'}),
                      style: AppTypography.label(size: 10)),
                  Expanded(
                    child: Slider(
                      value: _radiusKm.toDouble(),
                      min: 2,
                      max: 50,
                      divisions: 12,
                      activeColor: AppColors.leben,
                      onChanged: (v) =>
                          setState(() => _radiusKm = v.round()),
                      onChangeEnd: (_) => _load(),
                    ),
                  ),
                  IconButton(
                    onPressed: _loading ? null : _load,
                    icon: const Icon(LucideIcons.refreshCw,
                        size: 18, color: AppColors.leben),
                  ),
                ],
              ),
            ),
            Expanded(
              child: spots.isEmpty && !_loading
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: EmptyStateCard(
                        icon: LucideIcons.mapPin,
                        title: 'wildPicks.none'.tr(),
                        description: 'wildPicks.noneHint'.tr(),
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
                                for (final s in spots)
                                  Marker(
                                    point: LatLng(s.lat, s.lng),
                                    width: 34,
                                    height: 34,
                                    child: GestureDetector(
                                      onTap: () => _openSheet(s),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: _color(s.kind),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: AppColors.voidColor,
                                              width: 2),
                                        ),
                                        alignment: Alignment.center,
                                        child: Icon(_icon(s.kind),
                                            size: 16, color: Colors.white),
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
                                      color: AppColors.leben),
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

  void _openSheet(FreePickSpot s) {
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
                    decoration: BoxDecoration(
                        color: _color(s.kind), shape: BoxShape.circle),
                    child: Icon(_icon(s.kind),
                        size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(s.displayLabel,
                        style: AppTypography.display(
                            size: 16, color: AppColors.ink)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text('wildPicks.kind.${s.kind.name}'.tr(),
                  style: AppTypography.label(size: 10)),
              Text('${s.lat.toStringAsFixed(4)}, ${s.lng.toStringAsFixed(4)}',
                  style: AppTypography.caption()),
              const SizedBox(height: 8),
              Text('wildPicks.source'.tr(),
                  style: AppTypography.caption()),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.active,
    required this.onToggle,
  });
  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.18)
              : AppColors.elevated,
          border: Border.all(
              color: active ? color : AppColors.line, width: 1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: active ? color : AppColors.mute),
            const SizedBox(width: 4),
            Text(label,
                style: AppTypography.label(
                    size: 10, color: active ? color : AppColors.mute)),
          ],
        ),
      ),
    );
  }
}
