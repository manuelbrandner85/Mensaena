/// SKILL: mensaena-features
/// Spritpreise via Tankerkönig — Liste nahegelegener Tankstellen
/// mit E5/E10/Diesel-Preis. Ersatz für die alte E-Lade-Stations-View.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../services/location_service.dart';
import '../../../services/tankerkoenig_service.dart';
import '../../../widgets/effects/glass_card.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

final _gasStationsProvider =
    FutureProvider.autoDispose<List<GasStation>>((ref) async {
  try {
    final pos = await LocationService.getCurrentPosition()
        .timeout(const Duration(seconds: 6));
    return TankerkoenigService.nearby(
      lat: pos.latitude,
      lng: pos.longitude,
      radiusKm: 8,
    );
  } catch (_) {
    return const [];
  }
});

class GasPricesScreen extends ConsumerWidget {
  const GasPricesScreen({super.key});

  String _fmt(double? p) => p == null ? '—' : '${p.toStringAsFixed(3)} €';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_gasStationsProvider);
    return DashboardScaffold(
      title: 'gas.title'.tr(),
      currentRoute: '/dashboard/mobility/gas',
      onRefresh: () async {
        ref.invalidate(_gasStationsProvider);
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.bronze)),
        error: (_, __) => const SizedBox.shrink(),
        data: (stations) {
          if (stations.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(LucideIcons.fuel,
                      size: 32, color: AppColors.mute),
                  const SizedBox(height: 8),
                  Text('gas.empty'.tr(), style: AppTypography.caption()),
                ]),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: stations.length,
            itemBuilder: (_, i) {
              final s = stations[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(
                            s.isOpen ? LucideIcons.fuel : LucideIcons.fuel,
                            size: 18,
                            color:
                                s.isOpen ? AppColors.leben : AppColors.mute,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${s.brand} · ${s.name}',
                              style: AppTypography.body(
                                  size: 14,
                                  color: AppColors.ink,
                                  weight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${s.distanceKm.toStringAsFixed(1)} km',
                            style: AppTypography.caption(),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Text('${s.street}, ${s.place}',
                            style: AppTypography.caption()),
                        const SizedBox(height: 10),
                        Row(children: [
                          _PricePill(label: 'E5', value: _fmt(s.e5)),
                          const SizedBox(width: 8),
                          _PricePill(label: 'E10', value: _fmt(s.e10)),
                          const SizedBox(width: 8),
                          _PricePill(
                              label: 'Diesel', value: _fmt(s.diesel)),
                          if (!s.isOpen) ...[
                            const Spacer(),
                            Text('gas.closed'.tr(),
                                style: AppTypography.body(
                                    size: 11,
                                    color: AppColors.herzrotWarm,
                                    weight: FontWeight.w700)),
                          ],
                        ]),
                      ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PricePill extends StatelessWidget {
  const _PricePill({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: AppTypography.label(size: 9, color: AppColors.inkSoft)),
        Text(value,
            style: AppTypography.body(
                size: 12,
                color: AppColors.ink,
                weight: FontWeight.w700)),
      ]),
    );
  }
}
