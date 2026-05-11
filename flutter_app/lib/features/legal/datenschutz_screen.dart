// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, require_trailing_commas
import 'package:flutter/material.dart';

import '../../core/atmosphere/cinema_scaffold.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dimensions.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/cinema_appbar.dart';

class DatenschutzScreen extends StatelessWidget {
  const DatenschutzScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CinemaScaffold(
      level: AtmosphereLevel.app,
      appBar: const CinemaAppBar(title: 'DATENSCHUTZ'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: MnColors.elevated,
                  borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
                  border: Border.all(color: MnColors.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Datenschutzerklaerung',
                        style: MnTypography.display(size: 28)),
                    const SizedBox(height: 24),
                    _section('1. Verantwortliche',
                        'Uwe Vetter, Via d\'Ascoli 25, 92021 Aragona AG (Italien)\n'
                            'Manuel Brandner, Im Wahlsberg 10, 55543 Bad Kreuznach (Deutschland)\n\n'
                            'Kontakt: info@mensaena.de'),
                    _section('2. Datenerhebung',
                        'Wir erheben nur die Daten, die fuer den Betrieb der App notwendig sind: '
                        'Profilinformationen, Beitraege, Nachrichten und Standort (nur wenn freigegeben).'),
                    _section('3. Supabase (EU-Server)',
                        'Daten werden in der EU bei Supabase gehostet, gesichert durch Row-Level-Security.'),
                    _section('4. Cookies & lokale Speicherung',
                        'Wir verwenden lokale Speicherung fuer Auth-Sessions und Praeferenzen. Keine Tracking-Cookies.'),
                    _section('5. Cloudflare',
                        'Statische Inhalte werden ueber Cloudflare bereitgestellt. Standard-Web-Logs.'),
                    _section('6. Deine Rechte',
                        'Du hast jederzeit Anspruch auf Auskunft, Berichtigung und Loeschung. '
                        'Sende uns dafuer eine Nachricht an info@mensaena.de.'),
                    const SizedBox(height: 16),
                    Text('Stand: April 2026',
                        style: MnTypography.mono(size: 12, color: MnColors.mute)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(String title, String body) => Padding(
        padding: const EdgeInsets.only(top: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: MnTypography.display(size: 20)),
            const SizedBox(height: 8),
            Text(body, style: MnTypography.body(color: MnColors.inkSoft, height: 1.7)),
          ],
        ),
      );
}
