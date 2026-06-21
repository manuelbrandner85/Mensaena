/// SKILL: mensaena-features + mensaena-design
/// ÖPNV-Screen — Verbindungsauskunft (Von/Nach) via Transitous/MOTIS, gratis
/// und ohne API-Key. Adressen werden über Nominatim geocodiert.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../services/geocoding_service.dart';
import '../../../services/location_service.dart';
import '../../../services/transit_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/app_snackbar.dart';
import '../../../widgets/shared/readable_width.dart';

class TransitScreen extends ConsumerStatefulWidget {
  const TransitScreen({super.key});

  @override
  ConsumerState<TransitScreen> createState() => _TransitScreenState();
}

class _TransitScreenState extends ConsumerState<TransitScreen> {
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  double? _fromLat, _fromLng;
  bool _loading = false;
  bool _searched = false;
  List<TransitItinerary> _results = const [];

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  Future<void> _useGps() async {
    try {
      final pos = await LocationService.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _fromLat = pos.latitude;
        _fromLng = pos.longitude;
        _fromCtrl.text = 'oepnv.myLocation'.tr();
      });
    } catch (_) {
      if (mounted) AppSnackBar.error(context, 'oepnv.gpsFailed'.tr());
    }
  }

  Future<void> _search() async {
    if (_toCtrl.text.trim().isEmpty ||
        (_fromCtrl.text.trim().isEmpty && _fromLat == null)) {
      AppSnackBar.info(context, 'oepnv.fillBoth'.tr());
      return;
    }
    setState(() {
      _loading = true;
      _searched = true;
    });
    try {
      double? fLat = _fromLat, fLng = _fromLng;
      if (fLat == null) {
        final hits = await GeocodingService.search(
            query: _fromCtrl.text.trim(), limit: 1);
        if (hits.isNotEmpty) {
          fLat = hits.first.lat;
          fLng = hits.first.lng;
        }
      }
      final toHits =
          await GeocodingService.search(query: _toCtrl.text.trim(), limit: 1);
      if (fLat == null || fLng == null || toHits.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _results = const [];
        });
        return;
      }
      final res = await TransitService.plan(
        fromLat: fLat,
        fromLng: fLng,
        toLat: toHits.first.lat,
        toLng: toHits.first.lng,
      );
      if (!mounted) return;
      setState(() {
        _results = res;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _results = const [];
      });
    }
  }

  IconData _modeIcon(String mode) {
    switch (mode.toUpperCase()) {
      case 'WALK':
        return Icons.directions_walk;
      case 'BUS':
        return Icons.directions_bus;
      case 'TRAM':
      case 'SUBWAY':
      case 'METRO':
        return Icons.tram;
      case 'RAIL':
      case 'REGIONAL_RAIL':
      case 'HIGHSPEED_RAIL':
      case 'TRAIN':
        return Icons.train;
      default:
        return Icons.directions;
    }
  }

  String _fmt(DateTime? t) => t == null
      ? '--:--'
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'oepnv.title'.tr(),
      currentRoute: '/dashboard/oepnv',
      body: SafeArea(
        child: ReadableWidth(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _fromCtrl,
                style: AppTypography.body(size: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  labelText: 'oepnv.from'.tr(),
                  prefixIcon: const Icon(Icons.trip_origin, size: 18),
                  suffixIcon: IconButton(
                    tooltip: 'oepnv.useGps'.tr(),
                    onPressed: _useGps,
                    icon: const Icon(LucideIcons.locate, size: 18),
                  ),
                ),
                onChanged: (_) => _fromLat = null,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _toCtrl,
                style: AppTypography.body(size: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  labelText: 'oepnv.to'.tr(),
                  prefixIcon: const Icon(LucideIcons.mapPin, size: 18),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: AppColors.voidColor,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: _loading ? null : _search,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.voidColor),
                      )
                    : const Icon(LucideIcons.search, size: 16),
                label: Text(_loading
                    ? 'oepnv.searching'.tr()
                    : 'oepnv.search'.tr()),
              ),
              const SizedBox(height: 16),
              if (_searched && !_loading && _results.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text('oepnv.noResults'.tr(),
                        style: AppTypography.body(
                            size: 13, color: AppColors.mute)),
                  ),
                ),
              ..._results.map(_itineraryCard),
              if (_results.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('oepnv.source'.tr(),
                    style: AppTypography.label(size: 9, color: AppColors.mute)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _itineraryCard(TransitItinerary it) {
    final transitLegs = it.legs.where((l) => l.mode.toUpperCase() != 'WALK');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${_fmt(it.start)} – ${_fmt(it.end)}',
                  style: AppTypography.body(
                      size: 15,
                      color: AppColors.ink,
                      weight: FontWeight.w700)),
              const Spacer(),
              Text(
                'oepnv.minutes'.tr(namedArgs: {'n': '${it.durationMin}'}),
                style: AppTypography.label(size: 11, color: AppColors.teal),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final l in transitLegs)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_modeIcon(l.mode), size: 13, color: AppColors.teal),
                      if (l.line.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(l.line,
                            style: AppTypography.label(
                                size: 10, color: AppColors.ink)),
                      ],
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'oepnv.transfers'.tr(namedArgs: {'n': '${it.transfers}'}),
            style: AppTypography.label(size: 10, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}
