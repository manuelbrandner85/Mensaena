import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../routing/routes.dart';
import '../theme/app_colors.dart';

/// SOS-Button für die Topbar – öffnet ein Bottom-Sheet mit:
/// - Notruf-Nummern (112, 110, 144, 122, TelefonSeelsorge)
/// - Link zu Krise melden
/// - Link zu Krisen-Ressourcen
/// Pendant zu src/app/dashboard/crisis/components/GlobalSOSButton.tsx.
class SOSButton extends StatelessWidget {
  const SOSButton({super.key});

  Future<void> _open(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (_) => const _SOSSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: Color(0xFFB91C1C),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Text(
          'SOS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 9,
            letterSpacing: 0.4,
          ),
        ),
      ),
      tooltip: 'Notruf / Krise melden',
      onPressed: () => _open(context),
    );
  }
}

class _SOSSheet extends StatelessWidget {
  const _SOSSheet();

  Future<void> _call(String number) async {
    final url = Uri.parse('tel:${number.replaceAll(' ', '')}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                '🚨 Notfall-Hilfe',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 4),
            const Center(
              child: Text(
                'Bei akuter Lebensgefahr zuerst 112 anrufen.',
                style: TextStyle(color: AppColors.ink400, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            // Hauptnotruf
            _BigCallTile(
              label: '112 anrufen',
              sub: 'Feuerwehr · Rettung · Polizei (EU)',
              number: '112',
              accent: const Color(0xFFB91C1C),
              icon: Icons.local_phone_outlined,
              onCall: _call,
            ),
            const SizedBox(height: 8),
            // Polizei
            _BigCallTile(
              label: '110 (Polizei DE) · 133 (AT)',
              sub: 'Polizei direkt',
              number: '110',
              accent: const Color(0xFF1D4ED8),
              icon: Icons.shield_outlined,
              onCall: _call,
            ),
            const SizedBox(height: 8),
            // TelefonSeelsorge
            _BigCallTile(
              label: 'TelefonSeelsorge',
              sub: 'Kostenlos · anonym · 24/7',
              number: '0800 111 0 111',
              accent: const Color(0xFF0F766E),
              icon: Icons.psychology_outlined,
              onCall: _call,
            ),
            const SizedBox(height: 20),
            // Mensaena-Aktionen
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.go(Routes.dashboardCrisisCreate);
                      },
                      icon: const Icon(Icons.warning_amber_rounded),
                      label: const Text('Krise melden'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFB91C1C),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.go(Routes.dashboardCrisisResources);
                      },
                      icon: const Icon(Icons.list_alt_outlined),
                      label: const Text('Hotlines'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BigCallTile extends StatelessWidget {
  const _BigCallTile({
    required this.label,
    required this.sub,
    required this.number,
    required this.accent,
    required this.icon,
    required this.onCall,
  });

  final String label;
  final String sub;
  final String number;
  final Color accent;
  final IconData icon;
  final ValueChanged<String> onCall;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => onCall(number),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: accent, width: 4)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      style: const TextStyle(
                        color: AppColors.ink400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                number,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
