/// SKILL: mensaena-features + mensaena-design
/// E-Auto-Ladestationen-Karte via OSM Overpass.
/// Viewport-basiert: bei jedem Map-Move wird neu geladen was sichtbar ist.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../services/charge_stations_service.dart';
import '../../../services/location_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

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
  LatLng? _userPos;
  Timer? _moveDebounce;
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
  /// desto groesser der Radius — Karten-Sicht passt zur Datenmenge.
  int _radiusFromZoom() {
    final z = _mapCtrl.camera.zoom;
    if (z >= 14) return 5;
    if (z >= 12) return 15;
    if (z >= 10) return 40;
    if (z >= 8) return 100;
    return 200;
  }

  Future<void> _load() async {
    // _load() wird nach async-Gaps aus _initAndLoad gerufen — Widget kann
    // zwischenzeitlich disposed sein → setState ohne mounted-Check crasht
    // ("Null check operator used on a null value", lt. error_logs).
    if (!mounted) return;
    setState(() => _loading = true);
    final list = await ChargeStationsService.nearby(
      lat: _center.latitude,
      lng: _center.longitude,
      radiusKm: _radiusFromZoom(),
    );
    if (!mounted) return;
    setState(() {
      _stations = list;
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
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'charge.title'.tr(),
      // Drawer-Highlight: tatsächliche Route ist /dashboard/charge-stations,
      // nicht /dashboard/mobility/charge → der Mobility-Eintrag im Drawer
      // wird sonst nicht aktiv markiert.
      currentRoute: '/dashboard/charge-stations',
      fab: FloatingActionButton(
        backgroundColor: AppColors.tealSoft,
        foregroundColor: AppColors.voidColor,
        onPressed: _recenterGps,
        tooltip: 'charge.recenter'.tr(),
        child: const Icon(LucideIcons.locate),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Karte — IMMER sichtbar
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
                            border:
                                Border.all(color: Colors.white, width: 3),
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
                                  color: AppColors.voidColor, width: 2),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(LucideIcons.zap,
                                size: 14, color: AppColors.voidColor),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            // Top-Pill: Anzahl / Loading
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.deep.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: AppColors.tealSoft.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_loading)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.tealSoft),
                        )
                      else
                        const Icon(LucideIcons.zap,
                            size: 12, color: AppColors.tealSoft),
                      const SizedBox(width: 6),
                      Text(
                        _loading
                            ? 'charge.loading'.tr()
                            : 'charge.count'
                                .tr(namedArgs: {'n': '${_stations.length}'}),
                        style: AppTypography.label(
                            size: 10, color: AppColors.ink),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Empty-Hint nur wenn nichts gefunden — als kleine Pill, NICHT
            // Vollbild. Karte bleibt sichtbar.
            if (!_loading && _stations.isEmpty)
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
                          'charge.noneHint'.tr(),
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

  /// Öffnet die System-Karte mit Routen-Navigation zur Station.
  /// Gleicher Mechanismus wie auf dem Spritpreise-Screen.
  Future<void> _navigateTo(ChargeStation s) async {
    final label = s.name ?? s.operator ?? 'charge.title'.tr();
    final candidates = <Uri>[
      if (Platform.isAndroid)
        Uri.parse('google.navigation:q=${s.lat},${s.lng}&mode=d'),
      if (Platform.isIOS)
        Uri.parse(
            'http://maps.apple.com/?daddr=${s.lat},${s.lng}&dirflg=d'),
      Uri.parse(
          'geo:${s.lat},${s.lng}?q=${s.lat},${s.lng}(${Uri.encodeComponent(label)})'),
      Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=${s.lat},${s.lng}&travelmode=driving'),
    ];
    for (final uri in candidates) {
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {/* nächster Kandidat */}
    }
  }

  void _openSheet(ChargeStation s) {
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
                    decoration: const BoxDecoration(
                        color: AppColors.tealSoft, shape: BoxShape.circle),
                    child: const Icon(LucideIcons.zap,
                        size: 18, color: AppColors.voidColor),
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
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).maybePop();
                    _navigateTo(s);
                  },
                  icon: const Icon(LucideIcons.navigation, size: 16),
                  label: Text('gas.navigate'.tr()),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.tealSoft,
                    foregroundColor: AppColors.voidColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
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
