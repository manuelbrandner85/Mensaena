import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../routing/routes.dart';
import '../../theme/app_colors.dart';

/// Pendant zu /dashboard/mental-support. Listet anonyme Krisen-Hotlines
/// und Beratungs-Angebote, gruppiert nach Land. Quellen sind verifiziert
/// (telefonseelsorge.de/at, 143.ch, rataufdraht.at).
class MentalSupportPage extends StatelessWidget {
  const MentalSupportPage({super.key});

  static const _countries = <_Country>[
    _Country(
      flag: '🇩🇪',
      label: 'Deutschland',
      hotlines: [
        _Hotline(
          name: 'TelefonSeelsorge (evangelisch)',
          number: '0800 111 0 111',
          desc: 'Kostenlos · anonym · 24/7',
        ),
        _Hotline(
          name: 'TelefonSeelsorge (katholisch)',
          number: '0800 111 0 222',
          desc: 'Kostenlos · anonym · 24/7',
        ),
        _Hotline(
          name: 'EU-Helpline',
          number: '116 123',
          desc: 'Kostenlos · anonym · 24/7',
        ),
        _Hotline(
          name: 'Hilfetelefon „Gewalt gegen Frauen"',
          number: '08000 116 016',
          desc: 'Kostenlos · 18 Sprachen · 24/7',
        ),
        _Hotline(
          name: 'Nummer gegen Kummer (Kinder)',
          number: '116 111',
          desc: 'Mo–Sa 14–20 Uhr',
        ),
      ],
    ),
    _Country(
      flag: '🇦🇹',
      label: 'Österreich',
      hotlines: [
        _Hotline(
          name: 'TelefonSeelsorge AT',
          number: '142',
          desc: 'Kostenlos · anonym · 24/7',
        ),
        _Hotline(
          name: 'Rat auf Draht (Kinder & Jugendliche)',
          number: '147',
          desc: 'Kostenlos · anonym · 24/7',
        ),
        _Hotline(
          name: 'Frauen-Helpline',
          number: '0800 222 555',
          desc: 'Hilfe bei Gewalt · 24/7',
        ),
        _Hotline(
          name: 'Männerinfo',
          number: '0800 400 777',
          desc: 'Mo–Fr 9–13 + 18–22 Uhr',
        ),
      ],
    ),
    _Country(
      flag: '🇨🇭',
      label: 'Schweiz',
      hotlines: [
        _Hotline(
          name: 'Die Dargebotene Hand',
          number: '143',
          desc: 'Kostenlos · anonym · 24/7',
        ),
        _Hotline(
          name: 'Pro Juventute (Kinder & Jugendliche)',
          number: '147',
          desc: 'Kostenlos · 24/7',
        ),
        _Hotline(
          name: 'Frauenhausnotruf',
          number: '0848 800 388',
          desc: '24/7',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Psychische Unterstützung'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Anfrage stellen',
            onPressed: () => context.go(Routes.dashboardMentalSupportCreate),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary500.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary500.withValues(alpha: 0.2),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🧠 Du musst nicht alleine durch.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 6),
                Text(
                  'Wenn du gerade in einer schweren Phase bist, gibt es kostenlose, '
                  'anonyme Anlaufstellen. Ein Anruf kostet nichts und hilft oft.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.ink700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          for (final country in _countries) ...[
            _CountryHeader(country: country),
            const SizedBox(height: 6),
            ...country.hotlines.map((h) => _HotlineCard(hotline: h)),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _Country {
  const _Country({
    required this.flag,
    required this.label,
    required this.hotlines,
  });
  final String flag;
  final String label;
  final List<_Hotline> hotlines;
}

class _Hotline {
  const _Hotline({
    required this.name,
    required this.number,
    required this.desc,
  });
  final String name;
  final String number;
  final String desc;
}

class _CountryHeader extends StatelessWidget {
  const _CountryHeader({required this.country});
  final _Country country;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(country.flag, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text(
            country.label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _HotlineCard extends StatelessWidget {
  const _HotlineCard({required this.hotline});
  final _Hotline hotline;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () {
            final n = hotline.number.replaceAll(' ', '');
            // Flutter: tel: launch via url_launcher; route through a parent if needed
            // For brevity we use a minimal launcher inline:
            _launchTel(n);
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary500.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.phone,
                    color: AppColors.primary500,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hotline.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hotline.desc,
                        style: const TextStyle(
                          color: AppColors.ink400,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  hotline.number,
                  style: const TextStyle(
                    color: AppColors.primary500,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _launchTel(String number) async {
  final url = Uri.parse('tel:$number');
  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}
