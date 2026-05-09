import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../routing/routes.dart';
import '../../theme/app_colors.dart';

/// /dashboard/warnungen — Aggregation amtlicher Warnquellen.
/// Pendant zu src/app/dashboard/warnungen/page.tsx.
class WarnungenPage extends StatelessWidget {
  const WarnungenPage({super.key});

  static const _categories = [
    (
      key: 'nina',
      emoji: '🚨',
      title: 'NINA Notfall-Warnungen',
      description:
          'Bevölkerungsschutz vom Bundesamt – Naturkatastrophen, '
              'Großschadenslagen, Gefahrstoffe.',
      url: 'https://warnung.bund.de',
      color: Color(0xFFB91C1C),
    ),
    (
      key: 'weather',
      emoji: '⛈️',
      title: 'Unwetter-Warnungen',
      description:
          'Aktuelle DWD-Warnungen für Sturm, Hagel, Starkregen, Hitze und Glätte.',
      url: 'https://www.dwd.de/DE/wetter/warnungen/warnungen_node.html',
      color: Color(0xFFF59E0B),
    ),
    (
      key: 'water',
      emoji: '🌊',
      title: 'Wasserstand & Hochwasser',
      description:
          'Pegelstände, Hochwasservorhersagen und akute Warnungen der Länder.',
      url: 'https://www.hochwasserzentralen.de/',
      color: Color(0xFF1D4ED8),
    ),
    (
      key: 'food',
      emoji: '🥦',
      title: 'Lebensmittel-Rückrufe',
      description:
          'Aktuelle Produkt-Rückrufe und -Warnungen vom BVL. Tap → eigene Liste.',
      url: 'INTERNAL',
      color: Color(0xFF15803D),
    ),
  ];

  Future<void> _open(BuildContext context, String url) async {
    if (url == 'INTERNAL') {
      context.go(Routes.dashboardWarnungenFood);
      return;
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Warnungen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFEE2E2), Color(0xFFFECACA)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFB91C1C), size: 24),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bleibe sicher: hier sammeln wir die wichtigsten amtlichen '
                    'Warn-Quellen für dich.',
                    style: TextStyle(
                      color: Color(0xFFB91C1C),
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._categories.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _WarningTile(
                emoji: c.emoji,
                title: c.title,
                description: c.description,
                accent: c.color,
                onTap: () => _open(context, c.url),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
            child: Text(
              'Weitere Quellen werden ergänzt – wenn du eine vermisst, '
              'schreib uns.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.ink400, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningTile extends StatelessWidget {
  const _WarningTile({
    required this.emoji,
    required this.title,
    required this.description,
    required this.accent,
    required this.onTap,
  });
  final String emoji, title, description;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border(left: BorderSide(color: accent, width: 4)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.ink400,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}
