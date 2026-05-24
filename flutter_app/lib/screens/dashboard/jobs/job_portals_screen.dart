/// SKILL: mensaena-features + mensaena-design
/// Job-Portale pro Land — kuratierte Direkt-Links zu offiziellen und
/// privaten Jobplattformen. Pragmatischer Fallback zur instabilen
/// EURES-API, analog zum Foodbanks-Screen.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../services/jobs_service.dart';
import '../../../services/locale_country_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/editorial_module_header.dart';

class JobPortalsScreen extends ConsumerStatefulWidget {
  const JobPortalsScreen({super.key});

  @override
  ConsumerState<JobPortalsScreen> createState() => _JobPortalsScreenState();
}

class _JobPortalsScreenState extends ConsumerState<JobPortalsScreen> {
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
    'EU': 'EU',
  };

  late Future<List<JobPortal>> _future;

  @override
  void initState() {
    super.initState();
    _future = JobPortalsService.all();
  }

  String _countryFor(BuildContext context) =>
      LocaleCountryService.forContext(context);

  @override
  Widget build(BuildContext context) {
    final highlight = _countryFor(context);
    final countryLabel = _countryNames[highlight] ?? highlight;
    return DashboardScaffold(
      title: 'jobs.portalsTitle'.tr(),
      currentRoute: '/dashboard/jobs',
      body: SafeArea(
        child: FutureBuilder<List<JobPortal>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.tealSoft),
              );
            }
            if (snap.hasError) {
              return Center(
                child: Text('${snap.error}', style: AppTypography.caption()),
              );
            }
            final all = snap.data ?? const <JobPortal>[];
            final groups = <String, List<JobPortal>>{};
            for (final p in all) {
              groups.putIfAbsent(p.country, () => []).add(p);
            }
            // Hervorgehobenes Land zuerst, dann EU, dann Rest alphabetisch.
            final keys = <String>[
              if (groups.containsKey(highlight)) highlight,
              if (groups.containsKey('EU') && highlight != 'EU') 'EU',
              ...(groups.keys.where((k) => k != highlight && k != 'EU').toList()
                ..sort()),
            ];

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                EditorialModuleHeader(
                  metaIndex: '§ 22',
                  metaCategory: 'jobs.portalsTitle'.tr(),
                  title: 'jobs.portalsTitle'.tr(),
                  subtitle: 'jobs.portalsSubtitle'
                      .tr(namedArgs: {'country': countryLabel}),
                ),
                const SizedBox(height: 12),
                for (final code in keys) ...[
                  _CountryHeader(
                    code: code,
                    label: _countryNames[code] ?? code,
                    isHighlighted: code == highlight,
                  ),
                  const SizedBox(height: 8),
                  for (final p in groups[code]!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PortalCard(
                        portal: p,
                        isHighlighted: code == highlight,
                      ),
                    ),
                  const SizedBox(height: 6),
                ],
                const SizedBox(height: 6),
                Text(
                  'jobs.portalsDisclaimer'.tr(),
                  style: AppTypography.caption(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CountryHeader extends StatelessWidget {
  const _CountryHeader({
    required this.code,
    required this.label,
    required this.isHighlighted,
  });

  final String code;
  final String label;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: isHighlighted
                ? AppColors.tealSoft.withValues(alpha: 0.18)
                : AppColors.elevated,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isHighlighted
                  ? AppColors.tealSoft.withValues(alpha: 0.5)
                  : AppColors.line,
            ),
          ),
          child: Text(
            code,
            style: AppTypography.label(
              size: 10,
              color: isHighlighted ? AppColors.tealSoft : AppColors.inkSoft,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTypography.body(
            size: 14,
            color: AppColors.ink,
            weight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PortalCard extends StatelessWidget {
  const _PortalCard({required this.portal, required this.isHighlighted});

  final JobPortal portal;
  final bool isHighlighted;

  Future<void> _launch(String url) async {
    if (url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  String _localizedDescription(BuildContext context) {
    final lang = context.locale.languageCode;
    if (lang == 'de' && portal.descriptionDe.isNotEmpty) {
      return portal.descriptionDe;
    }
    return portal.descriptionEn.isNotEmpty
        ? portal.descriptionEn
        : portal.descriptionDe;
  }

  @override
  Widget build(BuildContext context) {
    final desc = _localizedDescription(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighlighted
              ? AppColors.tealSoft.withValues(alpha: 0.45)
              : AppColors.line,
          width: 1,
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: AppColors.tealSoft.withValues(alpha: 0.18),
                  blurRadius: 14,
                  spreadRadius: -4,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.tealSoft.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  portal.official ? LucideIcons.shieldCheck : LucideIcons.briefcase,
                  size: 20,
                  color: AppColors.tealSoft,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            portal.name,
                            style: AppTypography.body(
                              size: 14,
                              color: AppColors.ink,
                              weight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                        ),
                        if (portal.official) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.leben.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppColors.leben.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              'jobs.officialBadge'.tr(),
                              style: AppTypography.label(
                                  size: 9, color: AppColors.leben),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      portal.operator,
                      style: AppTypography.caption(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              desc,
              style: AppTypography.body(
                size: 12,
                color: AppColors.inkSoft,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionPill(
                icon: LucideIcons.search,
                label: 'jobs.openSearch'.tr(),
                highlighted: true,
                onTap: () => _launch(portal.searchUrl),
              ),
              _ActionPill(
                icon: LucideIcons.globe,
                label: 'jobs.openPortal'.tr(),
                onTap: () => _launch(portal.website),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final fg = highlighted ? AppColors.voidColor : AppColors.tealSoft;
    final bg = highlighted
        ? AppColors.tealSoft
        : AppColors.tealSoft.withValues(alpha: 0.14);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: AppColors.tealSoft
                .withValues(alpha: highlighted ? 0.0 : 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.label(size: 10, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}
