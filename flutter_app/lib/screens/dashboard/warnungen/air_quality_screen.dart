/// SKILL: mensaena-features + mensaena-design
/// Air-Quality-Screen — OpenAQ Messungen rund um den GPS-Punkt des Users.
/// Gratis-API ohne Key, global verfügbar.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../services/air_quality_service.dart';
import '../../../services/pollen_service.dart';
import '../../../services/location_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

class AirQualityScreen extends ConsumerStatefulWidget {
  const AirQualityScreen({super.key});

  @override
  ConsumerState<AirQualityScreen> createState() => _AirQualityScreenState();
}

class _AirQualityScreenState extends ConsumerState<AirQualityScreen> {
  List<AirQualitySample>? _samples;
  List<PollenSample> _pollen = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pos = await LocationService.getCurrentPosition();
      final samples = await AirQualityService.nearby(
        lat: pos.latitude,
        lng: pos.longitude,
        radiusKm: 25,
      );
      // Pollen zusätzlich laden (non-fatal: leer = Sektion wird ausgeblendet).
      final pollen = await PollenService.current(
        lat: pos.latitude,
        lng: pos.longitude,
      );
      if (!mounted) return;
      setState(() {
        _samples = samples;
        _pollen = pollen;
        _loading = false;
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'air.locationDenied'.tr();
      });
      return;
    }
  }

  static const _paramLabels = {
    'pm25': 'PM2.5',
    'pm10': 'PM10',
    'o3': 'Ozon (O₃)',
    'no2': 'Stickstoffdioxid (NO₂)',
    'so2': 'Schwefeldioxid (SO₂)',
    'co': 'Kohlenmonoxid (CO)',
  };

  static const _levelColors = [
    Color(0xFF22C55E), // 0 grün
    Color(0xFF84CC16), // 1 hellgrün
    Color(0xFFEAB308), // 2 gelb
    Color(0xFFF59E0B), // 3 amber
    Color(0xFFEA580C), // 4 orange
    Color(0xFFDC2626), // 5 rot
  ];

  static const _levelLabels = [
    'air.levelExcellent',
    'air.levelGood',
    'air.levelModerate',
    'air.levelPoor',
    'air.levelBad',
    'air.levelHazardous',
  ];

  static const _pollenLabels = {
    'grass': 'pollen.grass',
    'birch': 'pollen.birch',
    'alder': 'pollen.alder',
    'mugwort': 'pollen.mugwort',
    'olive': 'pollen.olive',
    'ragweed': 'pollen.ragweed',
  };
  static const _pollenLevelKeys = [
    'pollen.level0',
    'pollen.level1',
    'pollen.level2',
    'pollen.level3',
    'pollen.level4',
  ];

  /// Pollen-Sektion (nur Typen mit Wert > 0, stärkste zuerst). Leer → [].
  List<Widget> _pollenWidgets() {
    final p = _pollen.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (p.isEmpty) return const [];
    return [
      const SizedBox(height: 18),
      Row(
        children: [
          const Icon(Icons.local_florist, size: 18, color: AppColors.tealSoft),
          const SizedBox(width: 8),
          Text('pollen.title'.tr(),
              style: AppTypography.display(size: 16, color: AppColors.ink)),
        ],
      ),
      const SizedBox(height: 10),
      ...p.map((s) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.elevated,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _levelColors[s.level],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((_pollenLabels[s.type] ?? s.type).tr(),
                          style: AppTypography.body(
                              size: 14,
                              color: AppColors.ink,
                              weight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        '${s.value.toStringAsFixed(0)} ${s.unit} · ${_pollenLevelKeys[s.level].tr()}',
                        style: AppTypography.label(
                            size: 10, color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'air.title'.tr(),
      currentRoute: '/dashboard/warnungen',
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.tealSoft,
          backgroundColor: AppColors.surface,
          onRefresh: _load,
          child: _build(),
        ),
      ),
    );
  }

  Widget _build() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.tealSoft),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: AppTypography.caption()),
        ),
      );
    }
    final s = _samples ?? const [];
    if (s.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Center(
            child: Text('air.noStations'.tr(),
                style: AppTypography.body(
                    size: 13, color: AppColors.mute)),
          ),
        ],
      );
    }
    // Pro Parameter den jüngsten Messwert nehmen
    final byParam = <String, AirQualitySample>{};
    for (final sample in s) {
      final ex = byParam[sample.parameter];
      if (ex == null || sample.measuredAt.isAfter(ex.measuredAt)) {
        byParam[sample.parameter] = sample;
      }
    }
    final worst = byParam.values
        .fold<int>(0, (acc, s) => s.whoLevel > acc ? s.whoLevel : acc);
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _levelColors[worst].withValues(alpha: 0.25),
                _levelColors[worst].withValues(alpha: 0.10),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border:
                Border.all(color: _levelColors[worst].withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.wind,
                      size: 22, color: _levelColors[worst]),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_levelLabels[worst].tr(),
                        style: AppTypography.display(
                            size: 20, color: AppColors.ink)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'air.subtitle'.tr(namedArgs: {
                  'city': s.first.city ?? s.first.location,
                  'country': s.first.country,
                }),
                style: AppTypography.caption(),
              ),
              const SizedBox(height: 10),
              // Empfehlung „heute lüften?" abgeleitet aus dem schlechtesten Wert.
              Row(
                children: [
                  Icon(
                      worst <= 1
                          ? LucideIcons.checkCircle
                          : LucideIcons.alertTriangle,
                      size: 16,
                      color: _levelColors[worst]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      worst <= 1
                          ? 'air.ventilateGood'.tr()
                          : worst == 2
                              ? 'air.ventilateModerate'.tr()
                              : 'air.ventilateBad'.tr(),
                      style: AppTypography.body(
                          size: 13,
                          color: AppColors.ink,
                          weight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...byParam.values.map((sample) => _Card(
              sample: sample,
              label: _paramLabels[sample.parameter] ?? sample.parameter,
              color: _levelColors[sample.whoLevel],
              levelLabel: _levelLabels[sample.whoLevel].tr(),
            )),
        ..._pollenWidgets(),
        const SizedBox(height: 20),
        Text(
          'Quelle: Open-Meteo (Luft & Pollen)',
          style: AppTypography.label(size: 9, color: AppColors.mute),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.sample,
    required this.label,
    required this.color,
    required this.levelLabel,
  });

  final AirQualitySample sample;
  final String label;
  final Color color;
  final String levelLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTypography.body(
                        size: 14,
                        color: AppColors.ink,
                        weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${sample.value.toStringAsFixed(1)} ${sample.unit} · $levelLabel',
                  style: AppTypography.label(
                      size: 10, color: AppColors.inkSoft),
                ),
                Text(
                  '${sample.location} · ${DateFormat('dd.MM. HH:mm').format(sample.measuredAt.toLocal())}',
                  style: AppTypography.label(size: 9, color: AppColors.mute),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
