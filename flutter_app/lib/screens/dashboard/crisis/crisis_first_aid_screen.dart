/// SKILL: mensaena-features (#R4)
/// Offline-Erste-Hilfe — funktioniert OHNE Internet (Inhalte sind in die
/// App gebacken). Bei einer Krise in der Nachbarschaft zählt jede Sekunde;
/// dieser Screen muss auch ohne Empfang sofort da sein.
///
/// Bewusst KEINE Netz-Abhängigkeit, KEINE Bilder von Servern. Reine
/// strukturierte Schritt-für-Schritt-Anleitungen + lokale Notrufnummern.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/emergency_numbers_config.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../services/locale_country_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

class CrisisFirstAidScreen extends StatelessWidget {
  const CrisisFirstAidScreen({super.key});

  // Struktur: jede Situation hat einen i18n-Titel + N i18n-Schritt-Keys.
  static const List<({String icon, String title, List<String> steps})>
      _topics = [
    (
      icon: 'recovery',
      title: 'firstAid.recoveryTitle',
      steps: [
        'firstAid.recovery1',
        'firstAid.recovery2',
        'firstAid.recovery3',
        'firstAid.recovery4',
      ],
    ),
    (
      icon: 'cpr',
      title: 'firstAid.cprTitle',
      steps: [
        'firstAid.cpr1',
        'firstAid.cpr2',
        'firstAid.cpr3',
        'firstAid.cpr4',
      ],
    ),
    (
      icon: 'bleeding',
      title: 'firstAid.bleedingTitle',
      steps: [
        'firstAid.bleeding1',
        'firstAid.bleeding2',
        'firstAid.bleeding3',
      ],
    ),
    (
      icon: 'burn',
      title: 'firstAid.burnTitle',
      steps: [
        'firstAid.burn1',
        'firstAid.burn2',
        'firstAid.burn3',
      ],
    ),
  ];

  IconData _iconFor(String key) => switch (key) {
        'recovery' => LucideIcons.userCheck,
        'cpr' => LucideIcons.heartPulse,
        'bleeding' => LucideIcons.droplet,
        'burn' => LucideIcons.flame,
        _ => LucideIcons.plusCircle,
      };

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'firstAid.title'.tr(),
      currentRoute: '/dashboard/crisis',
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Notruf-Banner — direkt wählbar.
            _EmergencyCallCard(),
            const SizedBox(height: 8),
            Text('firstAid.offlineHint'.tr(),
                style: AppTypography.caption()),
            const SizedBox(height: 16),
            for (final t in _topics) ...[
              _TopicCard(
                icon: _iconFor(t.icon),
                title: t.title.tr(),
                steps: [for (final s in t.steps) s.tr()],
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            Text('firstAid.disclaimer'.tr(),
                textAlign: TextAlign.center,
                style: AppTypography.caption()),
          ],
        ),
      ),
    );
  }
}

class _EmergencyCallCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final country = LocaleCountryService.forContext(context);
    final cfg = getCountryConfig(country);
    final number = cfg?.emergency ?? kEuEmergencyNumber;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.herzrot.withValues(alpha: 0.10),
        border: Border.all(color: AppColors.herzrot.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.phoneCall,
              color: AppColors.herzrot, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('firstAid.emergencyCall'.tr(),
                    style: AppTypography.body(
                        size: 14,
                        color: AppColors.ink,
                        weight: FontWeight.w700)),
                Text('firstAid.emergencyHint'.tr(),
                    style: AppTypography.caption()),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.herzrot,
                foregroundColor: Colors.white),
            onPressed: () async {
              HapticFeedback.heavyImpact();
              final uri = Uri.parse(
                  'tel:${number.replaceAll(RegExp(r'[^0-9+]'), '')}');
              try {
                await launchUrl(uri);
              } catch (_) {/* still */}
            },
            child: Text(number,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, letterSpacing: 1)),
          ),
        ],
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({
    required this.icon,
    required this.title,
    required this.steps,
  });
  final IconData icon;
  final String title;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.bronze),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: AppTypography.display(
                        size: 16, color: AppColors.ink)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.bronze.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Text('${i + 1}',
                        style: AppTypography.mono(
                            size: 11, color: AppColors.bronze)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(steps[i],
                        style: AppTypography.body(
                            size: 13,
                            color: AppColors.ink,
                            height: 1.45)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
