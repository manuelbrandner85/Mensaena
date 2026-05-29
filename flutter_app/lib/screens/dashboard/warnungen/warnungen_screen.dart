import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/app_config.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../services/civil_protection_service.dart';
import '../../../services/locale_country_service.dart';
import '../../../services/nina_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features
/// NINA-Warnungen (Bundesamt fuer Bevoelkerungsschutz und Katastrophenhilfe).
/// Sortiert nach Severity (Extreme > Severe > Moderate > Minor).
/// 15min Cache via NinaService singleton.
class WarnungenScreen extends ConsumerStatefulWidget {
  const WarnungenScreen({super.key});

  @override
  ConsumerState<WarnungenScreen> createState() => _WarnungenScreenState();
}

class _WarnungenScreenState extends ConsumerState<WarnungenScreen> {
  /// Länder in denen NINA tatsächlich Sinn ergibt (BBK-Quelle = Deutschland).
  /// AT/CH user koennen NINA ebenfalls hilfreich finden (Grenzregionen).
  static const _ninaCountries = {'DE', 'AT', 'CH'};

  Future<List<Map<String, dynamic>>>? _future;
  String get _ags => AppConfig.defaultAgs;

  bool _ninaRelevantForLocale() {
    final country = LocaleCountryService.forContext(context);
    return _ninaCountries.contains(country);
  }

  @override
  void initState() {
    super.initState();
    // Initiales Future erst lazy in didChangeDependencies, weil
    // context.locale dort verfuegbar ist. Beim ersten Build pruefen
    // wir die Locale; ist NINA nicht relevant, sparen wir den API-Call.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_future == null && _ninaRelevantForLocale()) {
      _future = NinaService.instance.fetchDashboard(ags: _ags);
    }
  }

  Future<void> _refresh() async {
    if (!_ninaRelevantForLocale()) return;
    NinaService.instance.clearCache();
    final fresh = NinaService.instance.fetchDashboard(ags: _ags);
    setState(() => _future = fresh);
    await fresh;
  }

  String? _civilCountry() {
    final country = LocaleCountryService.forContext(context);
    if (CivilProtectionService.isSupported(country)) return country;
    return null;
  }

  void _openDetail(Map<String, dynamic> w) {
    final id = w['id'] as String? ?? w['identifier'] as String?;
    if (id == null) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xF0121A28),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _DetailSheet(warningId: id, summary: w),
    );
  }

  @override
  Widget build(BuildContext context) {
    final civilCountry = _civilCountry();
    final ninaRelevant = _ninaRelevantForLocale();
    return DashboardScaffold(
      title: 'civil.navTitle'.tr(),
      currentRoute: '/dashboard/warnungen',
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.herzrot,
          backgroundColor: AppColors.surface,
          onRefresh: _refresh,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snap) {
              final list = snap.data ?? const <Map<String, dynamic>>[];
              final loading =
                  ninaRelevant && snap.connectionState != ConnectionState.done;
              return ListView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _OverviewGrid(civilCountry: civilCountry),
                  const SizedBox(height: 16),
                  if (!ninaRelevant)
                    _NinaDeOnlyCard(civilCountry: civilCountry)
                  else if (loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.amber),
                      ),
                    )
                  else if (list.isEmpty)
                    _NinaEmpty()
                  else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.herzrot.withValues(alpha: 0.1),
                        border: Border.all(
                          color: AppColors.herzrot.withValues(alpha: 0.4),
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.alertOctagon,
                            size: 18,
                            color: AppColors.herzrot,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'civil.ninaActiveCount'.tr(namedArgs: {
                                'count': '${list.length}',
                              }),
                              style: AppTypography.body(
                                size: 13,
                                color: AppColors.inkSoft,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...list.map(
                      (w) => _WarningTile(
                        warning: w,
                        onTap: () => _openDetail(w),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _OverviewGrid extends StatelessWidget {
  const _OverviewGrid({required this.civilCountry});
  final String? civilCountry;

  @override
  Widget build(BuildContext context) {
    final tiles = <_TileSpec>[
      const _TileSpec(
        labelKey: 'civil.tileNina',
        icon: LucideIcons.alertOctagon,
        color: AppColors.herzrot,
        // NINA-Screen ist diese Seite selbst — Tap fokussiert die Liste unten.
        route: null,
      ),
      const _TileSpec(
        labelKey: 'civil.tileMeteo',
        icon: LucideIcons.cloudLightning,
        color: AppColors.amber,
        route: '/dashboard/warnungen/meteo',
      ),
      const _TileSpec(
        labelKey: 'civil.tileAir',
        icon: LucideIcons.wind,
        color: AppColors.teal,
        route: '/dashboard/warnungen/air',
      ),
      const _TileSpec(
        labelKey: 'civil.tileFood',
        icon: LucideIcons.apple,
        color: AppColors.leben,
        route: '/dashboard/warnungen/food',
      ),
      if (civilCountry != null)
        _TileSpec(
          labelKey: 'civil.tileCivil',
          labelArgs: {'country': civilCountry!},
          icon: LucideIcons.shieldAlert,
          color: AppColors.amberWarm,
          route: '/dashboard/warnungen/civil',
        ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: tiles.map((t) => _Tile(spec: t)).toList(),
    );
  }
}

class _TileSpec {
  const _TileSpec({
    required this.labelKey,
    required this.icon,
    required this.color,
    required this.route,
    this.labelArgs,
  });
  final String labelKey;
  final Map<String, String>? labelArgs;
  final IconData icon;
  final Color color;
  final String? route;
}

class _Tile extends StatelessWidget {
  const _Tile({required this.spec});
  final _TileSpec spec;

  @override
  Widget build(BuildContext context) {
    final label = spec.labelArgs == null
        ? spec.labelKey.tr()
        : spec.labelKey.tr(namedArgs: spec.labelArgs!);
    return InkWell(
      onTap: spec.route == null
          ? null
          : () => context.go(spec.route!),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: spec.color.withValues(alpha: 0.08),
          border: Border.all(color: spec.color.withValues(alpha: 0.35)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(spec.icon, size: 22, color: spec.color),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(
                size: 13,
                color: AppColors.ink,
                weight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NinaEmpty extends StatelessWidget {
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
            'civil.ninaEmpty'.tr(),
            textAlign: TextAlign.center,
            style: AppTypography.body(
              size: 13,
              color: AppColors.inkSoft,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hinweis-Card fuer non-DE-Locales: NINA ist ein deutscher Dienst
/// und ohne deutsches AGS nicht sinnvoll. Verweist auf MeteoAlarm
/// und (falls verfuegbar) auf den nationalen Zivilschutz.
class _NinaDeOnlyCard extends StatelessWidget {
  const _NinaDeOnlyCard({required this.civilCountry});
  final String? civilCountry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.info,
                  size: 22, color: AppColors.teal),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'civil.ninaDeOnlyTitle'.tr(),
                  style: AppTypography.display(
                    size: 16,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'civil.ninaDeOnlyBody'.tr(),
            style: AppTypography.body(
              size: 13,
              color: AppColors.inkSoft,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.go('/dashboard/warnungen/meteo'),
                icon: const Icon(LucideIcons.cloudLightning, size: 16),
                label: Text('civil.openMeteoAlarm'.tr()),
              ),
              if (civilCountry != null)
                OutlinedButton.icon(
                  onPressed: () => context.go('/dashboard/warnungen/civil'),
                  icon: const Icon(LucideIcons.shieldAlert, size: 16),
                  label: Text('civil.openCivilProtection'.tr()),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'civil.ninaDeOnlyHint'.tr(),
            style: AppTypography.label(size: 9, color: AppColors.mute),
          ),
        ],
      ),
    );
  }
}

class _WarningTile extends StatelessWidget {
  const _WarningTile({required this.warning, required this.onTap});
  final Map<String, dynamic> warning;
  final VoidCallback onTap;

  static const Map<String, ({Color color, String key})> _severities = {
    'Extreme': (color: AppColors.herzrot, key: 'civil.severityExtreme'),
    'Severe': (color: Color(0xFFFB923C), key: 'civil.severitySevere'),
    'Moderate': (color: AppColors.amber, key: 'civil.severityModerate'),
    'Minor': (color: AppColors.teal, key: 'civil.severityMinor'),
  };

  @override
  Widget build(BuildContext context) {
    final payload = warning['payload'] as Map<String, dynamic>?;
    final data = payload?['data'] as Map<String, dynamic>? ?? warning;
    final severity =
        (warning['severity'] ?? data['severity'])?.toString() ?? 'Moderate';
    final cfg = _severities[severity] ??
        (color: AppColors.amber, key: 'civil.severityModerate');
    final label = cfg.key.tr().toUpperCase();
    final locale = context.locale.languageCode;
    final i18nTitle = warning['i18nTitle'] as Map<String, dynamic>?;
    final headline = (i18nTitle?[locale] ??
                i18nTitle?['de'] ??
                data['headline'] ??
                warning['headline'])
            ?.toString() ??
        'civil.fallbackTitle'.tr();
    final sentRaw = warning['sent'] ?? data['sent'];
    final sent = sentRaw is String ? DateTime.tryParse(sentRaw) : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cfg.color.withValues(alpha: 0.08),
          border: Border.all(color: cfg.color.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: cfg.color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    label,
                    style: AppTypography.label(
                      size: 9,
                      color: AppColors.voidColor,
                      letterSpacing: 0.15,
                    ),
                  ),
                ),
                const Spacer(),
                if (sent != null)
                  Text(
                    DateFormat('dd.MM. HH:mm').format(sent),
                    style: AppTypography.caption(),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              headline,
              style: AppTypography.body(
                size: 14,
                color: AppColors.ink,
                weight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailSheet extends StatefulWidget {
  const _DetailSheet({required this.warningId, required this.summary});
  final String warningId;
  final Map<String, dynamic> summary;

  @override
  State<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<_DetailSheet> {
  Future<Map<String, dynamic>?>? _future;

  @override
  void initState() {
    super.initState();
    _future = NinaService.instance.fetchWarningDetail(widget.warningId);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollCtrl) => FutureBuilder<Map<String, dynamic>?>(
        future: _future,
        builder: (context, snap) {
          final d = snap.data;
          final headline = d?['info']?[0]?['headline'] ??
              widget.summary['i18nTitle']?['de'] ??
              widget.summary['headline'] ??
              'civil.fallbackTitle'.tr();
          final description = d?['info']?[0]?['description'] ?? '';
          final instruction = d?['info']?[0]?['instruction'] ?? '';
          final sender = d?['sender'] ?? widget.summary['sender'];
          return ListView(
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
              if (snap.connectionState != ConnectionState.done)
                const Center(
                  child: CircularProgressIndicator(color: AppColors.amber),
                )
              else ...[
                Text(
                  headline.toString(),
                  style: AppTypography.display(
                    size: 22,
                    color: AppColors.ink,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                if (description.toString().isNotEmpty)
                  Text(
                    description.toString(),
                    style: AppTypography.body(
                      size: 14,
                      color: AppColors.inkSoft,
                      height: 1.55,
                    ),
                  ),
                if (instruction.toString().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'civil.instructionLabel'.tr(),
                    style: AppTypography.label(size: 10),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    instruction.toString(),
                    style: AppTypography.body(
                      size: 13,
                      color: AppColors.amber,
                      height: 1.55,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
                if (sender != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    'civil.sourceLabel'.tr(namedArgs: {
                      'source': sender.toString(),
                    }),
                    style: AppTypography.caption(),
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}
