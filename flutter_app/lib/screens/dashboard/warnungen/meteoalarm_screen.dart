/// SKILL: mensaena-features + mensaena-design
/// MeteoAlarm-Screen — EU-weite Wetterwarnungen (EUMETNET).
/// Auto-Country aus locale.countryCode, Sortierung nach Severity.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../services/locale_country_service.dart';
import '../../../services/meteoalarm_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

class MeteoAlarmScreen extends ConsumerStatefulWidget {
  const MeteoAlarmScreen({super.key});

  @override
  ConsumerState<MeteoAlarmScreen> createState() => _MeteoAlarmScreenState();
}

class _MeteoAlarmScreenState extends ConsumerState<MeteoAlarmScreen> {
  static const _countryNames = {
    'DE': 'Deutschland',
    'AT': 'Österreich',
    'CH': 'Schweiz',
    'IT': 'Italia',
    'ES': 'España',
    'FR': 'France',
    'TR': 'Türkiye',
    'RU': 'Россия',
    'GB': 'United Kingdom',
    'PL': 'Polska',
    'HU': 'Magyarország',
    'GR': 'Ελλάδα',
    'PT': 'Portugal',
    'NL': 'Nederland',
    'BE': 'België',
    'CZ': 'Česko',
    'SK': 'Slovensko',
    'SI': 'Slovenija',
    'HR': 'Hrvatska',
    'IE': 'Ireland',
  };

  Future<List<MeteoAlarmWarning>>? _future;
  late String _country;

  @override
  void initState() {
    super.initState();
    _country = _initialCountry();
    _future = MeteoAlarmService.forCountry(_country);
  }

  String _initialCountry() => LocaleCountryService.forContext(context);

  Future<void> _refresh() async {
    MeteoAlarmService.clearCache();
    final fresh = MeteoAlarmService.forCountry(_country);
    setState(() => _future = fresh);
    await fresh;
  }

  void _changeCountry(String code) {
    setState(() {
      _country = code;
      _future = MeteoAlarmService.forCountry(code);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'meteo.title'.tr(),
      currentRoute: '/dashboard/warnungen',
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.amber,
          backgroundColor: AppColors.surface,
          onRefresh: _refresh,
          child: FutureBuilder<List<MeteoAlarmWarning>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.amber),
                );
              }
              final list = snap.data ?? const <MeteoAlarmWarning>[];
              return ListView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _Header(
                    country: _country,
                    countryName: _countryNames[_country] ?? _country,
                    count: list.length,
                  ),
                  const SizedBox(height: 12),
                  _CountryPicker(
                    current: _country,
                    names: _countryNames,
                    onChange: _changeCountry,
                  ),
                  const SizedBox(height: 12),
                  if (list.isEmpty)
                    _EmptyState(country: _countryNames[_country] ?? _country)
                  else
                    ...list.map((w) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _WarningCard(
                            warning: w,
                            onTap: () => _openDetail(w),
                          ),
                        )),
                  const SizedBox(height: 16),
                  Text(
                    'Quelle: MeteoAlarm / EUMETNET',
                    style: AppTypography.label(size: 9, color: AppColors.mute),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _openDetail(MeteoAlarmWarning w) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DetailSheet(warning: w),
    );
  }
}

// ---------------------------------------------------------------------------

const _severityColors = <int, Color>{
  1: AppColors.herzrot, // Extreme rot
  2: Color(0xFFFB923C), // Severe orange
  3: AppColors.amber, // Moderate gelb
  4: AppColors.leben, // Minor gruen
};

String _severityKey(int s) {
  switch (s) {
    case 1:
      return 'meteo.severityExtreme';
    case 2:
      return 'meteo.severitySevere';
    case 3:
      return 'meteo.severityModerate';
    default:
      return 'meteo.severityMinor';
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.country,
    required this.countryName,
    required this.count,
  });

  final String country;
  final String countryName;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.cloudLightning,
              size: 22, color: AppColors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'meteo.title'.tr(),
                  style: AppTypography.display(size: 18, color: AppColors.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  'meteo.subtitle'.tr(namedArgs: {
                    'country': countryName,
                    'count': '$count',
                  }),
                  style: AppTypography.body(
                    size: 12,
                    color: AppColors.inkSoft,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.country});
  final String country;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.shieldCheck,
              size: 36, color: AppColors.leben),
          const SizedBox(height: 10),
          Text(
            'meteo.noWarnings'.tr(namedArgs: {'country': country}),
            textAlign: TextAlign.center,
            style: AppTypography.body(size: 13, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _CountryPicker extends StatelessWidget {
  const _CountryPicker({
    required this.current,
    required this.names,
    required this.onChange,
  });

  final String current;
  final Map<String, String> names;
  final void Function(String) onChange;

  @override
  Widget build(BuildContext context) {
    final entries = names.entries.toList();
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final e = entries[i];
          final selected = e.key == current;
          return InkWell(
            onTap: () => onChange(e.key),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.amber.withValues(alpha: 0.18)
                    : AppColors.elevated,
                border: Border.all(
                  color: selected
                      ? AppColors.amber.withValues(alpha: 0.6)
                      : AppColors.line,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    e.key,
                    style: AppTypography.label(
                      size: 10,
                      color: selected ? AppColors.amber : AppColors.inkSoft,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    e.value,
                    style: AppTypography.body(
                      size: 12,
                      color: selected ? AppColors.ink : AppColors.inkSoft,
                      weight: selected ? FontWeight.w600 : FontWeight.w400,
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

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.warning, required this.onTap});
  final MeteoAlarmWarning warning;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _severityColors[warning.severity] ?? AppColors.amber;
    final sev = _severityKey(warning.severity).tr();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.55), width: 1.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    sev.toUpperCase(),
                    style: AppTypography.label(
                      size: 9,
                      color: AppColors.voidColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const Spacer(),
                if (warning.expires != null)
                  Text(
                    DateFormat('dd.MM. HH:mm')
                        .format(warning.expires!.toLocal()),
                    style: AppTypography.caption(),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              warning.headline,
              style: AppTypography.body(
                size: 14,
                color: AppColors.ink,
                weight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            if (warning.areaName.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(LucideIcons.mapPin,
                      size: 11, color: AppColors.mute),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      warning.areaName,
                      style: AppTypography.caption(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailSheet extends StatelessWidget {
  const _DetailSheet({required this.warning});
  final MeteoAlarmWarning warning;

  Future<void> _open(String url) async {
    if (url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final color = _severityColors[warning.severity] ?? AppColors.amber;
    final sev = _severityKey(warning.severity).tr();
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollCtrl) => ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              sev.toUpperCase(),
              style: AppTypography.label(
                size: 10,
                color: AppColors.voidColor,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            warning.headline,
            style: AppTypography.display(
              size: 22,
              color: AppColors.ink,
              height: 1.2,
            ),
          ),
          if (warning.areaName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'meteo.areaLabel'.tr(namedArgs: {'area': warning.areaName}),
              style: AppTypography.body(
                size: 13,
                color: AppColors.inkSoft,
              ),
            ),
          ],
          if (warning.expires != null) ...[
            const SizedBox(height: 4),
            Text(
              'meteo.expiresLabel'.tr(namedArgs: {
                'time': DateFormat('dd.MM.yyyy HH:mm')
                    .format(warning.expires!.toLocal()),
              }),
              style: AppTypography.caption(),
            ),
          ],
          const SizedBox(height: 16),
          if (warning.description.isNotEmpty)
            Text(
              warning.description,
              style: AppTypography.body(
                size: 14,
                color: AppColors.inkSoft,
                height: 1.55,
              ),
            ),
          if (warning.web.isNotEmpty) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () => _open(warning.web),
              icon: const Icon(LucideIcons.externalLink, size: 16),
              label: Text('meteo.openSource'.tr()),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'MeteoAlarm · ${warning.country}',
            style: AppTypography.label(size: 9, color: AppColors.mute),
          ),
        ],
      ),
    );
  }
}
