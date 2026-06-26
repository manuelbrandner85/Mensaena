/// SKILL: mensaena-features + mensaena-design
/// Karte mit Wildfruchte-Spots + Verschenk-Schraenken via OSM Overpass.
/// Viewport-basiert: bei jedem Map-Move wird neu geladen was sichtbar ist.
library;

import 'dart:async';

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

class WildPicksScreen extends ConsumerStatefulWidget {
  const WildPicksScreen({super.key});

  @override
  ConsumerState<WildPicksScreen> createState() => _WildPicksScreenState();
}

class _WildPicksScreenState extends ConsumerState<WildPicksScreen> {
  final _mapCtrl = MapController();
  LatLng _center = const LatLng(51.1657, 10.4515);
  final double _zoom = 12;
  LatLng? _userPos;
  Timer? _moveDebounce;
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
    _moveDebounce?.cancel();
    super.dispose();
  }

  Future<void> _initAndLoad() async {
    try {
      final pos = await LocationService.getCurrentPosition(
          accuracy: LocationAccuracy.medium);
      final ll = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _center = ll;
          _userPos = ll;
        });
        _mapCtrl.move(_center, _zoom);
      }
    } catch (_) {}
    await _load();
  }

  /// Lade-Radius wird aus Zoom-Level abgeleitet. Je weiter rausgezoomt,
  /// desto groesser der Radius — so passt die gefundene Datenmenge zur
  /// Karten-Sicht ohne expliziten Slider.
  int _radiusFromZoom() {
    final z = _mapCtrl.camera.zoom;
    if (z >= 14) return 3;
    if (z >= 12) return 8;
    if (z >= 10) return 25;
    if (z >= 8) return 60;
    return 120;
  }

  Future<void> _load() async {
    // _load() wird nach async-Gaps aus _initAndLoad gerufen (GPS-await) —
    // Widget kann zwischenzeitlich disposed sein → setState ohne mounted-Check
    // crasht.
    if (!mounted) return;
    setState(() => _loading = true);
    final spots = await MundraubService.nearby(
      lat: _center.latitude,
      lng: _center.longitude,
      radiusKm: _radiusFromZoom(),
    );
    if (!mounted) return;
    setState(() {
      _spots = spots;
      _loading = false;
    });
  }

  void _onMapEvent(MapEvent event) {
    if (event is MapEventMoveEnd) {
      _moveDebounce?.cancel();
      _moveDebounce = Timer(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        _center = _mapCtrl.camera.center;
        _load();
      });
    }
  }

  Future<void> _recenterGps() async {
    try {
      final pos = await LocationService.getCurrentPosition(
          accuracy: LocationAccuracy.high);
      final ll = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _userPos = ll;
        _center = ll;
      });
      _mapCtrl.move(_center, 14);
      _load();
    } catch (_) {/* GPS denied */}
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
      fab: FloatingActionButton(
        backgroundColor: AppColors.leben,
        foregroundColor: AppColors.voidColor,
        onPressed: _recenterGps,
        tooltip: 'wildPicks.recenter'.tr(),
        child: const Icon(LucideIcons.locate),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Layer 1: Karte — IMMER sichtbar, fuellt den ganzen Body.
            FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: _zoom,
                minZoom: 3,
                maxZoom: 18,
                onMapEvent: _onMapEvent,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'de.mensaena.app',
                ),
                // User-GPS-Punkt (blau, mit Glow)
                if (_userPos != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _userPos!,
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF4285F4),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4285F4)
                                    .withValues(alpha: 0.4),
                                blurRadius: 12,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                // Spot-Marker
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
                                  color: AppColors.voidColor, width: 2),
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
            // Layer 2: Filter-Bar + Loading-Indikator (Top)
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Column(
                children: [
                  // Karten-Info-Pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.deep.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: AppColors.leben.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_loading)
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.leben),
                          )
                        else
                          const Icon(LucideIcons.mapPin,
                              size: 12, color: AppColors.leben),
                        const SizedBox(width: 6),
                        Text(
                          _loading
                              ? 'wildPicks.loading'.tr()
                              : 'wildPicks.count'
                                  .tr(namedArgs: {'n': '${spots.length}'}),
                          style: AppTypography.label(
                              size: 10, color: AppColors.ink),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Filter-Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: FreePickKind.values
                          .map((k) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: _FilterChip(
                                  icon: _icon(k),
                                  label:
                                      'wildPicks.kind.${k.name}'.tr(),
                                  color: _color(k),
                                  active: _filter.contains(k),
                                  onToggle: () => setState(() {
                                    if (_filter.contains(k)) {
                                      _filter.remove(k);
                                    } else {
                                      _filter.add(k);
                                    }
                                  }),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
            // Layer 3: Empty-Hint nur wenn nichts gefunden — als kleine
            // unauffaellige Pill, NICHT Vollbild. Karte bleibt sichtbar.
            if (!_loading && spots.isEmpty)
              Positioned(
                bottom: 100,
                left: 24,
                right: 24,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.deep.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.info,
                          size: 14, color: AppColors.mute),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'wildPicks.none'.tr(),
                          style: AppTypography.body(
                              size: 12, color: AppColors.inkSoft),
                        ),
                      ),
                    ],
                  ),
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
      backgroundColor: AppColors.sheetBackground,
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.85)
              : AppColors.deep.withValues(alpha: 0.85),
          border: Border.all(
              color: active ? color : AppColors.line, width: 1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 12,
                color: active ? AppColors.voidColor : AppColors.mute),
            const SizedBox(width: 4),
            Text(label,
                style: AppTypography.label(
                    size: 10,
                    color: active ? AppColors.voidColor : AppColors.mute)),
          ],
        ),
      ),
    );
  }
}
