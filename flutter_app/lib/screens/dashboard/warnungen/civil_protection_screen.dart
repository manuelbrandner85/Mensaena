/// SKILL: mensaena-features + mensaena-design
/// Civil-Protection-Screen — nationale Behoerden-Alerts fuer IT/ES/FR/TR/RU.
/// Auto-Country aus locale, fuer DE/AT/CH/GB/US/IE freundlicher Fallback
/// mit Verweisen auf NINA und MeteoAlarm.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../services/civil_protection_service.dart';
import '../../../services/locale_country_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../utils/safe_launch.dart';

class CivilProtectionScreen extends ConsumerStatefulWidget {
  const CivilProtectionScreen({super.key});

  @override
  ConsumerState<CivilProtectionScreen> createState() =>
      _CivilProtectionScreenState();
}

class _CivilProtectionScreenState
    extends ConsumerState<CivilProtectionScreen> {
  static const Map<String, String> _countryNames = {
    'IT': 'Italia',
    'ES': 'España',
    'FR': 'France',
    'TR': 'Türkiye',
    'RU': 'Россия',
  };

  late final String _country;
  late final bool _supported;
  Future<List<CivilProtectionAlert>>? _future;

  @override
  void initState() {
    super.initState();
    _country = _detectCountry();
    _supported = CivilProtectionService.isSupported(_country);
    if (_supported) {
      _future = CivilProtectionService.forCountry(_country);
    }
  }

  String _detectCountry() {
    final auto = LocaleCountryService.forContext(context);
    if (CivilProtectionService.isSupported(auto)) return auto;
    return '';
  }

  Future<void> _refresh() async {
    if (!_supported) return;
    CivilProtectionService.clearCache();
    final fresh = CivilProtectionService.forCountry(_country);
    setState(() => _future = fresh);
    await fresh;
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'civil.title'.tr(),
      currentRoute: '/dashboard/warnungen',
      body: SafeArea(
        child: _supported ? _buildAlerts() : _buildFallback(),
      ),
    );
  }

  Widget _buildAlerts() {
    final countryName = _countryNames[_country] ?? _country;
    final source = CivilProtectionService.sourceLabel(_country);
    return RefreshIndicator(
      color: AppColors.amber,
      backgroundColor: AppColors.surface,
      onRefresh: _refresh,
      child: FutureBuilder<List<CivilProtectionAlert>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.amber),
            );
          }
          final list = snap.data ?? const <CivilProtectionAlert>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _Header(country: countryName, source: source),
              const SizedBox(height: 12),
              if (list.isEmpty)
                _EmptyState(country: countryName, source: source)
              else
                ...list.map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AlertCard(
                      alert: a,
                      onTap: () => _open(a.link),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'civil.sourceFallback'.tr(namedArgs: {'source': source}),
                style: AppTypography.label(size: 9, color: AppColors.mute),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFallback() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.elevated,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.shieldCheck,
                  size: 28, color: AppColors.leben),
              const SizedBox(height: 10),
              Text(
                'civil.coveredByNina'.tr(),
                style: AppTypography.body(
                  size: 14,
                  color: AppColors.ink,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.go('/dashboard/warnungen'),
                    icon: const Icon(LucideIcons.alertOctagon, size: 16),
                    label: const Text('NINA'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/dashboard/warnungen/meteo'),
                    icon: const Icon(LucideIcons.cloudLightning, size: 16),
                    label: Text('civil.meteoAlarm'.tr()),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'civil.coveredByMeteo'.tr(),
                style: AppTypography.body(
                  size: 12,
                  color: AppColors.inkSoft,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _open(String url) async {
    if (url.isEmpty) return;
    await safeLaunch(url, mode: LaunchMode.externalApplication);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.country, required this.source});
  final String country;
  final String source;

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
          const Icon(LucideIcons.shieldAlert, size: 22, color: AppColors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'civil.title'.tr(),
                  style: AppTypography.display(size: 18, color: AppColors.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  'civil.subtitle'.tr(namedArgs: {
                    'country': country,
                    'source': source,
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
  const _EmptyState({required this.country, required this.source});
  final String country;
  final String source;

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
            'civil.noAlerts'.tr(namedArgs: {
              'country': country,
              'source': source,
            }),
            textAlign: TextAlign.center,
            style: AppTypography.body(size: 13, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.onTap});
  final CivilProtectionAlert alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final desc = alert.description.length > 220
        ? '${alert.description.substring(0, 220)}…'
        : alert.description;
    return InkWell(
      onTap: alert.link.isEmpty ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.amber.withValues(alpha: 0.06),
          border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
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
                    color: AppColors.amber,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    alert.source.toUpperCase(),
                    style: AppTypography.label(
                      size: 9,
                      color: AppColors.voidColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const Spacer(),
                if (alert.publishedAt != null)
                  Text(
                    DateFormat('dd.MM. HH:mm')
                        .format(alert.publishedAt!.toLocal()),
                    style: AppTypography.caption(),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              alert.title,
              style: AppTypography.body(
                size: 14,
                color: AppColors.ink,
                weight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                desc,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(
                  size: 12,
                  color: AppColors.inkSoft,
                  height: 1.45,
                ),
              ),
            ],
            if (alert.link.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.externalLink,
                      size: 12, color: AppColors.amber),
                  const SizedBox(width: 4),
                  Text(
                    'civil.openSource'.tr(),
                    style: AppTypography.label(size: 10, color: AppColors.amber),
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
