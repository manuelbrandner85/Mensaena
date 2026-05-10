import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_colors.dart';

/// /dashboard/warnungen/food — Lebensmittel-Rückrufe.
/// Pendant zu src/app/dashboard/warnungen/food/page.tsx.
/// Aktuell: Linkliste auf BVL-Seite + Erinnerung. Edge-Function für
/// echtes API-Pulling kommt später (siehe wb-Pattern).
class WarnungenFoodPage extends StatelessWidget {
  const WarnungenFoodPage({super.key});

  Future<void> _openBvl() async {
    final uri = Uri.parse('https://www.lebensmittelwarnung.de/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Lebensmittel-Warnungen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.stone200),
            ),
            child: Column(
              children: [
                const Text('🥦', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                const Text(
                  'Aktuelle Lebensmittel-Rückrufe',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Die offizielle Datenbank des Bundesamts für Verbraucher-'
                  'schutz und Lebensmittelsicherheit (BVL) listet alle '
                  'aktuellen Rückrufe und Warnungen mit Hersteller, '
                  'Charge und Grund.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.ink700,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _openBvl,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Lebensmittelwarnung.de öffnen'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF15803D),
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline,
                    color: Color(0xFFD97706), size: 20,),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Tipp: Bei verpackten Produkten immer Charge und '
                    'Mindesthaltbarkeitsdatum vergleichen, bevor du sie '
                    'verzehrst.',
                    style: TextStyle(
                      color: Color(0xFF92400E),
                      fontSize: 12,
                      height: 1.4,
                    ),
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
