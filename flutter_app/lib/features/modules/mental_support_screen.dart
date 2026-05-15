import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/atmosphere/cinema_scaffold.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dimensions.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/cinema_appbar.dart';
import '../../core/widgets/cinema_toast.dart';

class MentalSupportScreen extends StatelessWidget {
  const MentalSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CinemaScaffold(
      appBar: const CinemaAppBar(title: 'MENTAL SUPPORT'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Du bist nicht allein.',
                    style: MnTypography.display(size: 24),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hier findest du Hilfe — anonym, kostenfrei, sofort.',
                    style: MnTypography.body(color: MnColors.inkSoft),
                  ),
                ],
              ),
            ),
            _CrisisCard(
              icon: LucideIcons.phone,
              title: 'TelefonSeelsorge',
              subtitle: '0800 111 0 111 — kostenlos, 24/7, anonym',
              tag: 'Akute Krise',
              accent: MnColors.herzrot,
              onTap: () => _launchTel(context, '08001110111'),
            ),
            const SizedBox(height: 12),
            _CrisisCard(
              icon: LucideIcons.phone,
              title: 'TelefonSeelsorge (Mobil)',
              subtitle: '116 123 — EU-weit kostenlos',
              tag: 'Akute Krise',
              accent: MnColors.herzrot,
              onTap: () => _launchTel(context, '116123'),
            ),
            const SizedBox(height: 12),
            _CrisisCard(
              icon: LucideIcons.phone,
              title: 'Kinder- & Jugendtelefon',
              subtitle: '116 111 — Mo-Sa 14-20 Uhr',
              tag: 'Jugendliche',
              accent: MnColors.amber,
              onTap: () => _launchTel(context, '116111'),
            ),
            const SizedBox(height: 24),
            Text(
              'Selbsthilfe-Techniken',
              style: MnTypography.label(color: MnColors.mute),
            ),
            const SizedBox(height: 12),
            const _TechniqueCard(
              title: '4-7-8 Atmung',
              body: '4 Sekunden einatmen — 7 Sekunden halten — 8 Sekunden ausatmen. '
                  'Dreimal wiederholen. Aktiviert den Parasympathikus.',
            ),
            const SizedBox(height: 12),
            const _TechniqueCard(
              title: '5-4-3-2-1 Erdung',
              body: 'Benenne: 5 Dinge die du SIEHST, 4 die du HOEREST, 3 die du SPUERST, '
                  '2 die du RIECHST, 1 die du SCHMECKST. Holt dich zurueck ins Hier und Jetzt.',
            ),
            const SizedBox(height: 12),
            const _TechniqueCard(
              title: 'Schmetterlingsumarmung',
              body: 'Verschraenke die Arme vor der Brust, klopfe abwechselnd auf die Schultern, '
                  'langsam und ruhig. Bilaterale Stimulation beruhigt das Nervensystem.',
            ),
            const SizedBox(height: 24),
            Text(
              'Wichtig',
              style: MnTypography.label(color: MnColors.mute),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MnColors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
                border: Border.all(
                  color: MnColors.amber.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(LucideIcons.info, size: 18, color: MnColors.amber),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Mensaena ersetzt keine professionelle Therapie. Bei akuter '
                      'Suizidgefahr: 112 oder die naechste psychiatrische Notaufnahme.',
                      style: MnTypography.body(color: MnColors.inkSoft, size: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _launchTel(BuildContext context, String number) async {
    final uri = Uri.parse('tel:$number');
    if (!await canLaunchUrl(uri)) {
      if (!context.mounted) return;
      CinemaToast.show(
        context,
        variant: ToastVariant.warning,
        message: 'Telefon nicht verfuegbar. Nummer: $number',
      );
      return;
    }
    await launchUrl(uri);
  }
}

class _CrisisCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String tag;
  final Color accent;
  final VoidCallback onTap;

  const _CrisisCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MnColors.elevated,
          borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
          border: Border.all(color: accent.withValues(alpha: 0.30)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: MnTypography.body(
                          color: MnColors.ink,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.18),
                          borderRadius:
                              BorderRadius.circular(MnDimensions.radiusPill),
                        ),
                        child: Text(
                          tag,
                          style: MnTypography.label(size: 10, color: accent),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: MnTypography.body(color: MnColors.inkSoft, size: 13),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, color: MnColors.mute, size: 18),
          ],
        ),
      ),
    );
  }
}

class _TechniqueCard extends StatelessWidget {
  final String title;
  final String body;
  const _TechniqueCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MnColors.surface,
        borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
        border: Border.all(color: MnColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: MnTypography.body(
              color: MnColors.ink,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: MnTypography.body(
              color: MnColors.inkSoft,
              size: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
