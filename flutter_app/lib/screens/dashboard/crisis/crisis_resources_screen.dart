import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/emergency_numbers_config.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/emergency_number.dart';
import '../../../repositories/crisis_repository.dart';
import '../../../services/locale_country_service.dart';
import '../../../utils/safe_launch.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

/// Bereinigt eine Telefonnummer für den `tel:`-Aufruf: entfernt Leerzeichen,
/// Bindestriche und Klammern, damit der Dialer eine gültige Nummer erhält.
/// Genutzt von [_Tile] und [_FallbackTile], damit beide identisch bereinigen.
String _sanitizePhoneNumber(String number) =>
    number.replaceAll(RegExp(r'[\s\-()]'), '');

/// SKILL: mensaena-features
/// Notruf-Nummern + Resourcen-Page (emergency_numbers tabelle).
///
/// Country-Tabs (DACH prominent + "Mehr Länder" für 30 Konfigurationen).
/// Fallback auf statische Config wenn DB für ein Land leer ist.
class CrisisResourcesScreen extends ConsumerStatefulWidget {
  const CrisisResourcesScreen({super.key});

  @override
  ConsumerState<CrisisResourcesScreen> createState() =>
      _CrisisResourcesScreenState();
}

class _CrisisResourcesScreenState
    extends ConsumerState<CrisisResourcesScreen> {
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

  String? _selectedCountry;

  String get _country {
    return _selectedCountry ?? LocaleCountryService.forContext(context);
  }

  void _openCountryPicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text('crisis.selectCountry'.tr(),
                        style: AppTypography.display(
                            size: 18, color: AppColors.ink)),
                  ),
                  IconButton(
                    tooltip: 'common.close'.tr(),
                    icon: const Icon(LucideIcons.x, color: AppColors.mute),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.line),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: kCountryEmergencyConfigs.length,
                itemBuilder: (_, i) {
                  final cfg = kCountryEmergencyConfigs[i];
                  final active = cfg.code == _country;
                  return ListTile(
                    leading: Text(cfg.flag,
                        style: const TextStyle(fontSize: 24)),
                    title: Text(cfg.label,
                        style: AppTypography.body(
                          size: 14,
                          color: AppColors.ink,
                          weight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                        )),
                    subtitle: Text('${cfg.code} · ${cfg.emergency}',
                        style: AppTypography.caption()),
                    trailing: active
                        ? const Icon(LucideIcons.check,
                            color: AppColors.amber)
                        : null,
                    onTap: () {
                      setState(() => _selectedCountry = cfg.code);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a fallback list of EmergencyNumber-equivalents from static config.
  List<_FallbackNumber> _fallbackFromConfig(CountryEmergencyConfig cfg) {
    final result = <_FallbackNumber>[];
    void add(String? n, String cat, String label) {
      if (n != null && n.isNotEmpty) {
        result.add(_FallbackNumber(
            number: n, category: cat, label: label));
      }
    }
    add(cfg.emergency, 'emergency', 'crisis.countryEmergency'.tr());
    add(cfg.police, 'emergency', 'crisis.countryPolice'.tr());
    add(cfg.fire, 'emergency', 'crisis.countryFire'.tr());
    if (cfg.ambulance != null && cfg.ambulance != cfg.emergency) {
      add(cfg.ambulance, 'health', 'crisis.countryAmbulance'.tr());
    }
    add(cfg.crisisHotline, 'crisis',
        cfg.crisisHotlineLabel ?? 'crisis.mentalHealth'.tr());
    add(cfg.childHotline, 'children', 'crisis.childHelp'.tr());
    add(cfg.womenHotline, 'women', 'crisis.womenHelp'.tr());
    add(cfg.poisonHotline, 'poison', 'crisis.poisonHelp'.tr());
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final country = _country;
    final async = ref.watch(emergencyNumbersProvider(country));
    final config = getCountryConfig(country);

    return DashboardScaffold(
      title: 'crisis.resourcesTitle'.tr(),
      currentRoute: '/dashboard/crisis',
      body: SafeArea(
        child: Column(
          children: [
            // Country-Chip-Row: DACH + "Mehr Länder"
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: _CountryChipRow(
                selected: country,
                onSelect: (c) => setState(() => _selectedCountry = c),
                onMore: _openCountryPicker,
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

                  // Fallback: DB leer → static config
                  final useFallback = list.isEmpty && config != null;
                  if (useFallback) {
                    final fallback = _fallbackFromConfig(config);
                    final groups = <String, List<_FallbackNumber>>{};
                    for (final n in fallback) {
                      groups.putIfAbsent(n.category, () => []).add(n);
                    }
                    return RefreshIndicator(
                      color: AppColors.amber,
                      backgroundColor: AppColors.surface,
                      onRefresh: onRefresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        children: [
                          _OfflineHintBanner(),
                          const SizedBox(height: 12),
                          for (final entry in groups.entries) ...[
                            _CategoryHeader(category: entry.key,
                                emoji: _categoryEmoji[entry.key] ?? '📞'),
                            const SizedBox(height: 6),
                            ...entry.value.map((n) => _FallbackTile(n: n)),
                            const SizedBox(height: 16),
                          ],
                        ],
                      ),
                    );
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
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        for (final entry in groups.entries) ...[
                          _CategoryHeader(
                              category: entry.key,
                              emoji: _categoryEmoji[entry.key] ?? '📞'),
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

// ── Country-Chip-Row (DACH + "Mehr Länder") ─────────────────────────────
class _CountryChipRow extends StatelessWidget {
  const _CountryChipRow({
    required this.selected,
    required this.onSelect,
    required this.onMore,
  });

  final String selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: [
          for (final cfg in kDachCountries) ...[
            _CountryChip(
              flag: cfg.flag,
              label: cfg.code,
              active: cfg.code == selected,
              onTap: () => onSelect(cfg.code),
            ),
            const SizedBox(width: 6),
          ],
          () {
            final isDach =
                selected == 'DE' || selected == 'AT' || selected == 'CH';
            final cfg = getCountryConfig(selected);
            if (!isDach && cfg != null) {
              return _CountryChip(
                flag: cfg.flag,
                label: cfg.code,
                active: true,
                onTap: onMore,
              );
            }
            return _CountryChip(
              flag: '🌍',
              label: 'crisis.moreCountries'.tr(),
              active: false,
              onTap: onMore,
            );
          }(),
        ],
      ),
    );
  }
}

class _CountryChip extends StatelessWidget {
  const _CountryChip({
    required this.flag,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String flag;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppColors.amber.withValues(alpha: 0.20)
              : AppColors.surface,
          border: Border.all(
            color: active
                ? AppColors.amber.withValues(alpha: 0.7)
                : AppColors.line,
            width: active ? 1.4 : 1,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(flag, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(label,
                style: AppTypography.label(
                  size: 11,
                  color: active ? AppColors.amber : AppColors.mute,
                )),
          ],
        ),
      ),
    );
  }
}

// ── Offline-Hint-Banner (wenn DB leer + Fallback aktiv) ─────────────────
class _OfflineHintBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.10),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.wifiOff,
              size: 16, color: AppColors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text('crisis.offlineHint'.tr(),
                style: AppTypography.caption(color: AppColors.amber)),
          ),
        ],
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category, required this.emoji});
  final String category;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 6),
        Text(
          'crisis.cat_$category'.tr(),
          style: AppTypography.label(size: 10),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.n);
  final EmergencyNumber n;

  Future<void> _call() async {
    await safeLaunch('tel:${_sanitizePhoneNumber(n.number)}');
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

// ── Fallback-Tile (static config) ───────────────────────────────────────
class _FallbackNumber {
  const _FallbackNumber(
      {required this.number, required this.category, required this.label});
  final String number;
  final String category;
  final String label;
}

class _FallbackTile extends StatelessWidget {
  const _FallbackTile({required this.n});
  final _FallbackNumber n;

  Future<void> _call() async {
    await safeLaunch('tel:${_sanitizePhoneNumber(n.number)}');
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
              width: 70,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.herzrot,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                n.number,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.mono(
                  size: 12,
                  color: AppColors.ink,
                  weight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(n.label,
                  style: AppTypography.body(
                    size: 14,
                    color: AppColors.ink,
                    weight: FontWeight.w600,
                  )),
            ),
            const Icon(LucideIcons.phone, color: AppColors.amber, size: 18),
          ],
        ),
      ),
    );
  }
}
