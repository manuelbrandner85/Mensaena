import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../routing/routes.dart';
import '../../theme/app_colors.dart';

/// Pendant zum Web-`SOSModal` (`src/app/dashboard/crisis/components/SOSModal.tsx`).
///
/// Globaler Soforthilfe-Dialog: einmal angetippt führt der Nutzer mit drei
/// Optionen weg (112 anrufen, 110 anrufen, TelefonSeelsorge), kann eine Krise
/// melden oder die volle Notruf-Übersicht öffnen.
///
/// Design-Prinzip aus CLAUDE.md: rot, dringlich, ohne Animations-Kitsch.
class CrisisSosModal extends StatelessWidget {
  const CrisisSosModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => const CrisisSosModal(),
    );
  }

  Future<void> _dial(BuildContext context, String number) async {
    final clean = number.replaceAll(' ', '');
    final ok = await launchUrl(Uri(scheme: 'tel', path: clean));
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Anruf zu $number konnte nicht gestartet werden')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              _SosHeader(onClose: () => Navigator.of(context).pop()),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _SosTile(
                      autofocus: true,
                      icon: Icons.phone,
                      iconBg: const Color(0xFFB91C1C),
                      surfaceColor: const Color(0xFFFEF2F2),
                      borderColor: const Color(0xFFFCA5A5),
                      title: '112 anrufen',
                      titleColor: const Color(0xFFB91C1C),
                      subtitle: 'EU-weit kostenlos, 24/7 — Feuerwehr & Rettung',
                      subtitleColor: const Color(0xFFDC2626),
                      onTap: () => _dial(context, '112'),
                    ),
                    const SizedBox(height: 10),
                    _SosTile(
                      icon: Icons.shield_outlined,
                      iconBg: const Color(0xFF2563EB),
                      surfaceColor: const Color(0xFFEFF6FF),
                      borderColor: const Color(0xFFBFDBFE),
                      title: 'Polizei: 110',
                      titleColor: const Color(0xFF1D4ED8),
                      subtitle: 'Deutschlandweit kostenlos, 24/7',
                      subtitleColor: const Color(0xFF2563EB),
                      onTap: () => _dial(context, '110'),
                    ),
                    const SizedBox(height: 10),
                    _SosTile(
                      icon: Icons.warning_amber_rounded,
                      iconBg: const Color(0xFFF97316),
                      surfaceColor: const Color(0xFFFFF7ED),
                      borderColor: const Color(0xFFFED7AA),
                      title: 'Krise melden',
                      titleColor: const Color(0xFFC2410C),
                      subtitle: 'Nachbarn mobilisieren und Hilfe koordinieren',
                      subtitleColor: const Color(0xFFEA580C),
                      onTap: () {
                        Navigator.of(context).pop();
                        context.go(Routes.dashboardCrisisCreate);
                      },
                    ),
                    const SizedBox(height: 10),
                    _SosTile(
                      icon: Icons.favorite_outline,
                      iconBg: const Color(0xFF06B6D4),
                      surfaceColor: const Color(0xFFECFEFF),
                      borderColor: const Color(0xFFA5F3FC),
                      title: 'TelefonSeelsorge: 0800 111 0 111',
                      titleColor: const Color(0xFF0E7490),
                      subtitle: 'Kostenlos, anonym, 24/7',
                      subtitleColor: const Color(0xFF0891B2),
                      onTap: () => _dial(context, '08001110111'),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.local_phone_outlined),
                      label: const Text('Alle Notruf-Nummern'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.go(Routes.dashboardCrisisResources);
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Bei akuter Lebensgefahr immer zuerst 112 anrufen!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.ink400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SosHeader extends StatelessWidget {
  const _SosHeader({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFDC2626),
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        children: [
          const Icon(Icons.crisis_alert, color: Colors.white, size: 24),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'SOS — Soforthilfe',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: 'Schließen',
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _SosTile extends StatelessWidget {
  const _SosTile({
    required this.icon,
    required this.iconBg,
    required this.surfaceColor,
    required this.borderColor,
    required this.title,
    required this.titleColor,
    required this.subtitle,
    required this.subtitleColor,
    required this.onTap,
    this.autofocus = false,
  });

  final IconData icon;
  final Color iconBg;
  final Color surfaceColor;
  final Color borderColor;
  final String title;
  final Color titleColor;
  final String subtitle;
  final Color subtitleColor;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        autofocus: autofocus,
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
