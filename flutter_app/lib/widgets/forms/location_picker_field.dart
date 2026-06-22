/// SKILL: mensaena-features + mensaena-design
/// Wiederverwendbares Standort-Auswahl-Feld mit Mini-Karte + fixem Pin.
/// Muster „Karte unter festem Pin": der Kartenmittelpunkt ist der gewählte
/// Punkt; beim Verschieben meldet [onChanged] die neue Position. Ein GPS-Knopf
/// zentriert auf den aktuellen Standort. Opt-in — Screens nutzen es statt des
/// reinen „GPS"-Buttons, um den Standort sichtbar/immersiv zu wählen.
library;

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/location_service.dart';

class LocationPickerField extends StatefulWidget {
  const LocationPickerField({
    required this.onChanged,
    this.initialLat,
    this.initialLng,
    this.accent = AppColors.amber,
    super.key,
  });

  final double? initialLat;
  final double? initialLng;
  final Color accent;

  /// Wird gerufen, sobald der Nutzer eine Position wählt (Karte verschoben
  /// oder GPS). Liefert die aktuelle Karten-Mitte.
  final void Function(double lat, double lng) onChanged;

  @override
  State<LocationPickerField> createState() => _LocationPickerFieldState();
}

class _LocationPickerFieldState extends State<LocationPickerField> {
  final _mapCtrl = MapController();
  // Default: geografische Mitte DE/AT-Raum, bis GPS/Initial gesetzt ist.
  LatLng _center = const LatLng(50.5, 10.5);
  bool _hasPos = false;
  bool _locating = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _center = LatLng(widget.initialLat!, widget.initialLng!);
      _hasPos = true;
    }
  }

  @override
  void dispose() {
    _mapCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onMapEvent(MapEvent event) {
    if (event is MapEventMoveEnd) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        final c = _mapCtrl.camera.center;
        setState(() {
          _center = c;
          _hasPos = true;
        });
        widget.onChanged(c.latitude, c.longitude);
      });
    }
  }

  Future<void> _useGps() async {
    setState(() => _locating = true);
    try {
      final pos = await LocationService.getCurrentPosition(
          accuracy: LocationAccuracy.high);
      if (!mounted) return;
      final ll = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _center = ll;
        _hasPos = true;
      });
      _mapCtrl.move(ll, 15);
      widget.onChanged(ll.latitude, ll.longitude);
    } catch (_) {
      // Standort bleibt optional.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 180,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: _hasPos ? 15 : 5.5,
                minZoom: 3,
                maxZoom: 18,
                onMapEvent: _onMapEvent,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom |
                      InteractiveFlag.drag |
                      InteractiveFlag.doubleTapZoom,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'de.mensaena.app',
                ),
              ],
            ),
            // Fester Pin in der Mitte (markiert den gewählten Punkt).
            IgnorePointer(
              child: Center(
                child: Padding(
                  // Spitze des Pins zeigt auf die Mitte → leicht nach oben.
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Icon(LucideIcons.mapPin,
                      size: 32, color: widget.accent),
                ),
              ),
            ),
            // GPS-Knopf
            Positioned(
              right: 8,
              bottom: 8,
              child: Material(
                color: AppColors.surface,
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _locating ? null : _useGps,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: _locating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.bronze),
                          )
                        : const Icon(LucideIcons.locate,
                            size: 18, color: AppColors.bronze),
                  ),
                ),
              ),
            ),
            // Hinweis-Pille oben
            Positioned(
              left: 8,
              top: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.deep.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _hasPos
                      ? 'create.locationPickHint'.tr()
                      : 'create.locationPickEmpty'.tr(),
                  style:
                      AppTypography.label(size: 9, color: AppColors.ink),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
