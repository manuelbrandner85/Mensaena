import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/emergency_number.dart';
import '../../../repositories/crisis_repository.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features
/// Notruf-Nummern + Resourcen-Page (emergency_numbers tabelle).
///
/// Auto-Locale: bestimmt aus context.locale primaeres Land (de=DE, en=GB,
/// it=IT, es=ES, fr=FR, tr=TR, ru=RU). Country-Override via Chip-Row
/// fuer User die ein anderes Land sehen wollen (z.B. Reisende).
class CrisisResourcesScreen extends ConsumerStatefulWidget {
  const CrisisResourcesScreen({super.key});

  @override
  ConsumerState<CrisisResourcesScreen> createState() =>
      _CrisisResourcesScreenState();
}

class _CrisisResourcesScreenState
    extends ConsumerState<CrisisResourcesScreen> {
  static const _localeCountry = {
    'de': 'DE',
    'en': 'GB',
    'it': 'IT',
    'es': 'ES',
    'fr': 'FR',
    'tr': 'TR',
    'ru': 'RU',
  };

  // Alle Länder mit Daten in emergency_numbers (siehe Migration
  // emergency_numbers_expand_country_category).
  static const _allCountries = <_CountryOption>[
    _CountryOption('DE', '🇩🇪', 'Deutschland'),
    _CountryOption('AT', '🇦🇹', 'Österreich'),
    _CountryOption('CH', '🇨🇭', 'Schweiz'),
    _CountryOption('IT', '🇮🇹', 'Italia'),
    _CountryOption('ES', '🇪🇸', 'España'),
    _CountryOption('FR', '🇫🇷', 'France'),
    _CountryOption('TR', '🇹🇷', 'Türkiye'),
    _CountryOption('RU', '🇷🇺', 'Россия'),
    _CountryOption('GB', '🇬🇧', 'United Kingdom'),
    _CountryOption('US', '🇺🇸', 'United States'),
    _CountryOption('IE', '🇮🇪', 'Ireland'),
  ];

  String? _override;

  String _countryFor(BuildContext context) {
    if (_override != null) return _override!;
    final loc = context.locale;
    final c = loc.countryCode;
    if (c != null && c.isNotEmpty && _allCountries.any((o) => o.code == c)) {
      return c;
    }
    return _localeCountry[loc.languageCode] ?? 'DE';
  }

  static const _categoryLabels = {
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
  Widget build(BuildContext context) {
    final country = _countryFor(context);
    final async = ref.watch(emergencyNumbersProvider(country));
    return DashboardScaffold(
      title: 'crisis.resourcesTitle'.tr(),
      currentRoute: '/dashboard/crisis',
      body: SafeArea(
        child: Column(
          children: [
            _CountryChipBar(
              options: _allCountries,
              selected: country,
              onTap: (c) => setState(() => _override = c),
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.herzrot),
                ),
                error: (e, _) => Center(
                  child: Text(
                      'crisis.resourceError'.tr(namedArgs: {'error': '$e'}),
                      style: AppTypography.caption()),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return Center(
                      child: Text(
                        'crisis.noResources'.tr(),
                        style: AppTypography.caption(),
                      ),
                    );
                  }
                  final groups = <String, List<EmergencyNumber>>{};
                  for (final n in list) {
                    groups.putIfAbsent(n.category, () => []).add(n);
                  }
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final entry in groups.entries) ...[
                        Row(
                          children: [
                            Text(
                              _categoryLabels[entry.key] ?? '📞',
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

class _CountryOption {
  const _CountryOption(this.code, this.flag, this.label);
  final String code;
  final String flag;
  final String label;
}

class _CountryChipBar extends StatelessWidget {
  const _CountryChipBar({
    required this.options,
    required this.selected,
    required this.onTap,
  });

  final List<_CountryOption> options;
  final String selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final o = options[i];
          final active = o.code == selected;
          return GestureDetector(
            onTap: () => onTap(o.code),
            child: Container(
              alignment: Alignment.center,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.herzrot.withValues(alpha: 0.20)
                    : AppColors.surface.withValues(alpha: 0.5),
                border: Border.all(
                  color: active ? AppColors.herzrot : AppColors.line,
                  width: active ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(o.flag, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    o.label,
                    style: AppTypography.label(
                      size: 10,
                      color: active ? AppColors.herzrot : AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
