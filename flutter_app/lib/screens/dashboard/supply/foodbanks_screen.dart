import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../services/foodbanks_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/editorial_module_header.dart';

/// SKILL: mensaena-features + mensaena-design
/// Foodbanks-Verzeichnis — kuratierte Liste von Dachverbänden in
/// DE/AT/CH/IT/ES/FR/TR/RU/GB/US/IE. Auto-Highlight des Landes basierend
/// auf `context.locale.countryCode`, Fallback via Sprache → Land Mapping.
class FoodbanksScreen extends ConsumerStatefulWidget {
  const FoodbanksScreen({super.key});

  @override
  ConsumerState<FoodbanksScreen> createState() => _FoodbanksScreenState();
}

class _FoodbanksScreenState extends ConsumerState<FoodbanksScreen> {
  static const _localeCountry = {
    'de': 'DE',
    'en': 'GB',
    'it': 'IT',
    'es': 'ES',
    'fr': 'FR',
    'tr': 'TR',
    'ru': 'RU',
  };

  late Future<List<Foodbank>> _future;

  @override
  void initState() {
    super.initState();
    _future = FoodbanksService.all();
  }

  String _countryFor(BuildContext context) {
    final loc = context.locale;
    final c = loc.countryCode;
    if (c != null && c.isNotEmpty) return c.toUpperCase();
    return _localeCountry[loc.languageCode] ?? 'DE';
  }

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
    'US': 'United States',
    'IE': 'Ireland',
  };

  @override
  Widget build(BuildContext context) {
    final highlight = _countryFor(context);
    final countryLabel = _countryNames[highlight] ?? highlight;
    return DashboardScaffold(
      title: 'foodbanks.title'.tr(),
      currentRoute: '/dashboard/supply',
      body: SafeArea(
        child: FutureBuilder<List<Foodbank>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.amber),
              );
            }
            if (snap.hasError) {
              return Center(
                child: Text('${snap.error}', style: AppTypography.caption()),
              );
            }
            final all = snap.data ?? const <Foodbank>[];
            // Gruppieren nach country, Highlight-Land zuerst.
            final groups = <String, List<Foodbank>>{};
            for (final fb in all) {
              groups.putIfAbsent(fb.country, () => []).add(fb);
            }
            final orderedKeys = <String>[
              if (groups.containsKey(highlight)) highlight,
              ...groups.keys.where((k) => k != highlight),
            ];
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                EditorialModuleHeader(
                  metaIndex: '§ 13',
                  metaCategory: 'foodbanks.title'.tr(),
                  title: 'foodbanks.title'.tr(),
                  subtitle: 'foodbanks.subtitle'
                      .tr(namedArgs: {'country': countryLabel}),
                ),
                const SizedBox(height: 12),
                for (final code in orderedKeys) ...[
                  _CountryHeader(
                    code: code,
                    label: _countryNames[code] ?? code,
                    isHighlighted: code == highlight,
                  ),
                  const SizedBox(height: 8),
                  for (final fb in groups[code]!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _FoodbankCard(
                        foodbank: fb,
                        isHighlighted: code == highlight,
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
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
                ? AppColors.amber.withValues(alpha: 0.2)
                : AppColors.elevated,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isHighlighted
                  ? AppColors.amber.withValues(alpha: 0.5)
                  : AppColors.line,
            ),
          ),
          child: Text(
            code,
            style: AppTypography.label(
              size: 10,
              color: isHighlighted ? AppColors.amberSoft : AppColors.inkSoft,
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

class _FoodbankCard extends StatelessWidget {
  const _FoodbankCard({required this.foodbank, required this.isHighlighted});

  final Foodbank foodbank;
  final bool isHighlighted;

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _localizedDescription(BuildContext context) {
    final lang = context.locale.languageCode;
    if (lang == 'de' && foodbank.descriptionDe.isNotEmpty) {
      return foodbank.descriptionDe;
    }
    return foodbank.descriptionEn.isNotEmpty
        ? foodbank.descriptionEn
        : foodbank.descriptionDe;
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
              ? AppColors.amber.withValues(alpha: 0.45)
              : AppColors.line,
          width: 1,
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: AppColors.amber.withValues(alpha: 0.18),
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
                  color: AppColors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.heartHandshake,
                  size: 20,
                  color: AppColors.amber,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      foodbank.name,
                      style: AppTypography.body(
                        size: 14,
                        color: AppColors.ink,
                        weight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(LucideIcons.mapPin,
                            size: 11, color: AppColors.mute),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            foodbank.address,
                            style: AppTypography.caption(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
              if (foodbank.phone.isNotEmpty)
                _ActionPill(
                  icon: LucideIcons.phone,
                  label: 'foodbanks.callBtn'.tr(),
                  onTap: () => _launch('tel:${foodbank.phone}'),
                ),
              if (foodbank.email.isNotEmpty)
                _ActionPill(
                  icon: LucideIcons.mail,
                  label: 'foodbanks.emailBtn'.tr(),
                  onTap: () => _launch('mailto:${foodbank.email}'),
                ),
              _ActionPill(
                icon: LucideIcons.globe,
                label: 'foodbanks.websiteBtn'.tr(),
                onTap: () => _launch(foodbank.website),
              ),
              _ActionPill(
                icon: LucideIcons.mapPin,
                label: 'foodbanks.findLocal'.tr(),
                highlighted: true,
                onTap: () => _launch(foodbank.findLocalUrl),
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
    final fg = highlighted ? AppColors.voidColor : AppColors.amberSoft;
    final bg = highlighted
        ? AppColors.amber
        : AppColors.amber.withValues(alpha: 0.14);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: AppColors.amber.withValues(alpha: highlighted ? 0.0 : 0.4),
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
