import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/emergency_number.dart';
import '../../../repositories/crisis_repository.dart';
import '../../../services/locale_country_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features
/// Notruf-Nummern + Resourcen-Page (emergency_numbers tabelle).
///
/// Zeigt ausschliesslich die Nummern fuer das durch User-Sprache
/// abgeleitete Land. Wer reist oder ein anderes Land braucht, wechselt
/// die App-Sprache in Settings. Kein manueller Country-Picker mehr
/// (User-Feedback: "nur das eigene Land soll sichtbar sein").
class CrisisResourcesScreen extends ConsumerWidget {
  const CrisisResourcesScreen({super.key});

  static const _flagByCountry = {
    'DE': '🇩🇪', 'AT': '🇦🇹', 'CH': '🇨🇭', 'IT': '🇮🇹', 'ES': '🇪🇸',
    'FR': '🇫🇷', 'TR': '🇹🇷', 'RU': '🇷🇺', 'GB': '🇬🇧', 'US': '🇺🇸',
    'IE': '🇮🇪',
  };

  static const _categoryEmoji = {
    'emergency': '🚨',
    'crisis': '💬',
    'children': '👶',
    'women': '🆘',
    'health': '🏥',
    'poison': '☠️',
    'eu': '🇪🇺',
    'other': '📞',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final country = LocaleCountryService.forContext(context);
    final async = ref.watch(emergencyNumbersProvider(country));
    final flag = _flagByCountry[country] ?? '🌍';

    return DashboardScaffold(
      title: 'crisis.resourcesTitle'.tr(),
      currentRoute: '/dashboard/crisis',
      body: SafeArea(
        child: Column(
          children: [
            // Country-Indicator-Banner (zeigt automatisch erkanntes Land)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.6),
                border:
                    Border.all(color: AppColors.line.withValues(alpha: 0.6)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(flag, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'crisis.localCountryLabel'
                              .tr(namedArgs: {'country': country}),
                          style: AppTypography.body(
                            size: 13,
                            color: AppColors.ink,
                            weight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'crisis.switchLanguageHint'.tr(),
                          style: AppTypography.label(
                              size: 9, color: AppColors.mute),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.herzrot),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'crisis.resourceError'.tr(namedArgs: {'error': '$e'}),
                    style: AppTypography.caption(),
                  ),
                ),
                data: (list) {
                  Future<void> onRefresh() async {
                    ref.invalidate(emergencyNumbersProvider(country));
                    await Future<void>.delayed(
                        const Duration(milliseconds: 400));
                  }

                  if (list.isEmpty) {
                    return RefreshIndicator(
                      color: AppColors.amber,
                      backgroundColor: AppColors.surface,
                      onRefresh: onRefresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 120),
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'crisis.noResources'.tr(),
                              style: AppTypography.caption(),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  final groups = <String, List<EmergencyNumber>>{};
                  for (final n in list) {
                    groups.putIfAbsent(n.category, () => []).add(n);
                  }
                  return RefreshIndicator(
                    color: AppColors.amber,
                    backgroundColor: AppColors.surface,
                    onRefresh: onRefresh,
                    child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      for (final entry in groups.entries) ...[
                        Row(
                          children: [
                            Text(
                              _categoryEmoji[entry.key] ?? '📞',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'crisis.cat_${entry.key}'.tr(),
                              style: AppTypography.label(size: 10),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ...entry.value.map(_Tile.new),
                        const SizedBox(height: 16),
                      ],
                    ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.n);
  final EmergencyNumber n;

  Future<void> _call() async {
    await launchUrl(Uri.parse('tel:${n.number}'));
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _call,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.5),
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.herzrot,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                n.number,
                style: AppTypography.mono(
                  size: 13,
                  color: AppColors.ink,
                  weight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.label,
                    style: AppTypography.body(
                      size: 14,
                      color: AppColors.ink,
                      weight: FontWeight.w600,
                    ),
                  ),
                  if (n.description != null)
                    Text(
                      n.description!,
                      style: AppTypography.caption(),
                    ),
                  if (n.is24h == true || n.isFree == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          if (n.is24h == true)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.leben.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text('crisis.badge24h'.tr(),
                                  style: AppTypography.label(
                                      size: 8, color: AppColors.lebenSoft)),
                            ),
                          if (n.isFree == true)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.amber.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text('crisis.badgeFree'.tr(),
                                  style: AppTypography.label(
                                      size: 8, color: AppColors.amber)),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Icon(LucideIcons.phone, color: AppColors.amber, size: 18),
          ],
        ),
      ),
    );
  }
}
