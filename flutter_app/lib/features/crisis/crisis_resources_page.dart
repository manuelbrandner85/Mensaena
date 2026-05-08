import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_colors.dart';

class CrisisResourcesPage extends StatelessWidget {
  const CrisisResourcesPage({super.key});

  static const _emergency = [
    _Resource(
      label: 'Euronotruf',
      number: '112',
      hint: 'Feuerwehr / Rettung / Polizei (EU-weit)',
      color: Color(0xFFB91C1C),
    ),
    _Resource(
      label: 'Polizei',
      number: '110',
      hint: 'Deutschland · Österreich: 133',
      color: Color(0xFF1D4ED8),
    ),
    _Resource(
      label: 'Rettung',
      number: '144',
      hint: 'Österreich · CH/DE: 112',
      color: Color(0xFFC62828),
    ),
    _Resource(
      label: 'Feuerwehr',
      number: '122',
      hint: 'Österreich · DE/CH: 112',
      color: Color(0xFFD97706),
    ),
    _Resource(
      label: 'Vergiftungsinformation',
      number: '+43 1 406 43 43',
      hint: 'Wien (Österreich) · 24/7',
      color: Color(0xFF6D28D9),
    ),
  ];

  static const _supportLines = [
    _Resource(
      label: 'TelefonSeelsorge DE',
      number: '0800 111 0 111',
      hint: 'Kostenlos · anonym · 24/7',
      color: Color(0xFF0F766E),
    ),
    _Resource(
      label: 'TelefonSeelsorge AT',
      number: '142',
      hint: 'Kostenlos · anonym · 24/7',
      color: Color(0xFF0F766E),
    ),
    _Resource(
      label: 'Dargebotene Hand CH',
      number: '143',
      hint: 'Kostenlos · anonym · 24/7',
      color: Color(0xFF0F766E),
    ),
    _Resource(
      label: 'Rat auf Draht',
      number: '147',
      hint: 'Notruf für Kinder & Jugendliche · AT · 24/7',
      color: Color(0xFFBE185D),
    ),
    _Resource(
      label: 'Frauenhelpline',
      number: '0800 222 555',
      hint: 'Hilfe bei Gewalt gegen Frauen · AT · 24/7',
      color: Color(0xFFBE185D),
    ),
    _Resource(
      label: 'Hilfetelefon Gewalt',
      number: '08000 116 016',
      hint: 'Deutschland · 24/7',
      color: Color(0xFFBE185D),
    ),
  ];

  Future<void> _call(String number) async {
    final url = Uri.parse('tel:${number.replaceAll(' ', '')}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Notruf-Nummern')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _Header(
            title: 'Akute Lebensgefahr',
            subtitle: 'Diese Nummern wählen, wenn jemand verletzt ist, ein Brand brennt, '
                'eine Person in Lebensgefahr schwebt.',
          ),
          const SizedBox(height: 8),
          ..._emergency.map((r) => _ResourceCard(resource: r, onCall: _call)),
          const SizedBox(height: 20),
          const _Header(
            title: 'Beratung & Krisen-Hotlines',
            subtitle: 'Anonyme, kostenlose Hilfe bei psychischen Krisen, '
                'Selbstmordgedanken, Gewalt, Sucht. Du musst nicht alleine durch.',
          ),
          const SizedBox(height: 8),
          ..._supportLines.map((r) => _ResourceCard(resource: r, onCall: _call)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: const Text(
              'Wenn du Suizidgedanken hast: Bitte ruf eine der Beratungs-Nummern an. '
              'Sie sind kostenlos, anonym, und du musst nichts erklären. Es gibt einen Weg.',
              style: TextStyle(
                color: Color(0xFFB91C1C),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.ink400,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _Resource {
  const _Resource({
    required this.label,
    required this.number,
    required this.hint,
    required this.color,
  });
  final String label;
  final String number;
  final String hint;
  final Color color;
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({required this.resource, required this.onCall});
  final _Resource resource;
  final ValueChanged<String> onCall;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => onCall(resource.number),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: BorderSide(color: resource.color, width: 4),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: resource.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.phone, color: resource.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resource.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        resource.hint,
                        style: const TextStyle(
                          color: AppColors.ink400,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  resource.number,
                  style: TextStyle(
                    color: resource.color,
                    fontSize: 16,
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
