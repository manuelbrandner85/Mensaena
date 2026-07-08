/// SKILL: mensaena-features
/// Spritpreise — Live-Liste umliegender Tankstellen mit E5/E10/Diesel.
/// AT via E-Control, DE via Tankerkönig (server-seitig via Edge-Function
/// 'fuel-prices'). Pull-to-Refresh + "Route"-Button öffnet die System-Karte.
library;

import 'dart:io' show Platform;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../services/location_service.dart';
import '../../../services/tankerkoenig_service.dart';
import '../../../widgets/effects/animated_entrance.dart';
import '../../../widgets/effects/glass_card.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/error_state_widget.dart';

final _gasStationsProvider =
    FutureProvider.autoDispose<FuelPricesResult>((ref) async {
  try {
    final pos = await LocationService.getCurrentPosition()
        .timeout(const Duration(seconds: 6));
    return TankerkoenigService.nearby(
      lat: pos.latitude,
      lng: pos.longitude,
      radiusKm: 10,
    );
  } catch (_) {
    return FuelPricesResult.empty;
  }
});

class GasPricesScreen extends ConsumerWidget {
  const GasPricesScreen({super.key});

  String _fmt(double? p) =>
      p == null ? '—' : '${p.toStringAsFixed(3)} €';

  /// Öffnet die System-Karte mit Routen-Navigation zur Tankstelle.
  /// Reihenfolge: google.navigation: (Google Maps Android) → Apple Maps →
  /// geo:?q= → maps.google.com Webfallback.
  Future<void> _navigateTo(GasStation s) async {
    final candidates = <Uri>[
      if (Platform.isAndroid)
        Uri.parse('google.navigation:q=${s.lat},${s.lng}&mode=d'),
      if (Platform.isIOS)
        Uri.parse(
            'http://maps.apple.com/?daddr=${s.lat},${s.lng}&dirflg=d'),
      Uri.parse(
          'geo:${s.lat},${s.lng}?q=${s.lat},${s.lng}(${Uri.encodeComponent("${s.brand} ${s.name}")})'),
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
        error: (_, __) => Center(
          child: ErrorStateWidget(
            onRetry: () => ref.invalidate(_gasStationsProvider),
          ),
        ),
        data: (result) {
          final stations = result.stations;
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
            itemCount: stations.length + (result.demo ? 1 : 0),
            itemBuilder: (_, i) {
              if (result.demo && i == 0) return const _DemoBanner();
              final s = stations[i - (result.demo ? 1 : 0)];
              return AnimatedEntrance(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(
                            LucideIcons.fuel,
                            size: 18,
                            color: s.isOpen
                                ? AppColors.leben
                                : AppColors.mute,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.brand.isNotEmpty
                                  ? '${s.brand} · ${s.name}'
                                  : s.name,
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
                          // E10 ist in AT nicht gebräuchlich → Pille
                          // dezent grau wenn null.
                          _PricePill(label: 'E10', value: _fmt(s.e10)),
                          const SizedBox(width: 8),
                          _PricePill(
                              label: 'Diesel', value: _fmt(s.diesel)),
                          const Spacer(),
                          if (!s.isOpen)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text('gas.closed'.tr(),
                                  style: AppTypography.body(
                                      size: 11,
                                      color: AppColors.herzrotWarm,
                                      weight: FontWeight.w700)),
                            ),
                        ]),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _navigateTo(s),
                            icon: const Icon(LucideIcons.navigation,
                                size: 14),
                            label: Text('gas.navigate'.tr()),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.bronze,
                              side: BorderSide(
                                  color: AppColors.bronze
                                      .withValues(alpha: 0.5)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Hinweis-Banner wenn der Server gerade den Tankerkönig-Demo-Key benutzt
/// (alle Preise wären dann fake/identisch). Admin muss einen echten Key
/// in private.push_config (key='tankerkoenig_api_key') hinterlegen.
class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(LucideIcons.alertTriangle,
                size: 16, color: AppColors.amber),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('gas.demoTitle'.tr(),
                      style: AppTypography.body(
                          size: 13,
                          color: AppColors.ink,
                          weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('gas.demoBody'.tr(),
                      style: AppTypography.caption()),
                ],
              ),
            ),
          ],
        ),
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
    final isPlaceholder = value == '—';
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
                color: isPlaceholder ? AppColors.mute : AppColors.ink,
                weight: FontWeight.w700)),
      ]),
    );
  }
}
