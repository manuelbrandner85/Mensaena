/// SKILL: mensaena-features + mensaena-design
/// Strompreise-Screen — stündliche Börsen-Day-Ahead-Preise (DE-LU) via
/// Energy-Charts (Fraunhofer ISE), gratis & ohne Key. Zeigt den aktuellen
/// Preis, die günstigste Stunde und einen Tagesverlauf mit Ampel-Balken.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../services/electricity_price_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

class ElectricityPricesScreen extends ConsumerStatefulWidget {
  const ElectricityPricesScreen({super.key});

  @override
  ConsumerState<ElectricityPricesScreen> createState() =>
      _ElectricityPricesScreenState();
}

class _ElectricityPricesScreenState
    extends ConsumerState<ElectricityPricesScreen> {
  List<PricePoint>? _points;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final pts = await ElectricityPriceService.dayAhead();
    if (!mounted) return;
    setState(() {
      _points = pts;
      _loading = false;
    });
  }

  Color _color(double ct, double min, double max) {
    if (max <= min) return AppColors.teal;
    final t = ((ct - min) / (max - min)).clamp(0.0, 1.0);
    if (t < 0.33) return AppColors.teal;
    if (t < 0.66) return AppColors.amber;
    return AppColors.herzrotWarm;
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'strompreise.title'.tr(),
      currentRoute: '/dashboard/strompreise',
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
          child: CircularProgressIndicator(color: AppColors.tealSoft));
    }
    final pts = _points ?? const [];
    if (pts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Center(
            child: Text('strompreise.noData'.tr(),
                style: AppTypography.body(size: 13, color: AppColors.mute)),
          ),
        ],
      );
    }
    final prices = pts.map((p) => p.ctPerKwh).toList();
    final min = prices.reduce((a, b) => a < b ? a : b);
    final max = prices.reduce((a, b) => a > b ? a : b);
    final now = DateTime.now();
    // aktuelle Stunde finden
    PricePoint? current;
    for (final p in pts) {
      if (p.time.hour == now.hour && p.time.day == now.day) {
        current = p;
        break;
      }
    }
    final cheapest = pts.reduce((a, b) => a.ctPerKwh < b.ctPerKwh ? a : b);

    String fmtHour(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:00';

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        // Header-Karte: aktueller Preis + günstigste Stunde
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.teal.withValues(alpha: 0.22),
                AppColors.teal.withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: AppColors.teal.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.zap, size: 22, color: AppColors.teal),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      current != null
                          ? 'strompreise.now'.tr(namedArgs: {
                              'ct': current.ctPerKwh.toStringAsFixed(1)
                            })
                          : 'strompreise.title'.tr(),
                      style: AppTypography.display(
                          size: 20, color: AppColors.ink),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'strompreise.cheapest'.tr(namedArgs: {
                  'time': fmtHour(cheapest.time),
                  'ct': cheapest.ctPerKwh.toStringAsFixed(1),
                }),
                style: AppTypography.body(size: 13, color: AppColors.inkSoft),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Tagesverlauf
        ...pts.map((p) {
          final isNow = current != null &&
              p.time.hour == current.time.hour &&
              p.time.day == current.time.day;
          final frac = max > min
              ? ((p.ctPerKwh - min) / (max - min)).clamp(0.0, 1.0)
              : 0.5;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 46,
                  child: Text(fmtHour(p.time),
                      style: AppTypography.mono(
                          size: 11,
                          color: isNow ? AppColors.teal : AppColors.inkSoft)),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppColors.elevated,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: 0.08 + frac * 0.92,
                        child: Container(
                          height: 18,
                          decoration: BoxDecoration(
                            color: _color(p.ctPerKwh, min, max),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 56,
                  child: Text(
                    '${p.ctPerKwh.toStringAsFixed(1)} ct',
                    textAlign: TextAlign.right,
                    style: AppTypography.label(
                        size: 11,
                        color: isNow ? AppColors.teal : AppColors.ink),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),
        Text('strompreise.source'.tr(),
            style: AppTypography.label(size: 9, color: AppColors.mute)),
      ],
    );
  }
}
