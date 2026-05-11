import 'package:flutter/material.dart';

import '../../core/atmosphere/cinema_scaffold.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dimensions.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/cinema_appbar.dart';

class ImpressumScreen extends StatelessWidget {
  const ImpressumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CinemaScaffold(
      appBar: const CinemaAppBar(title: 'IMPRESSUM'),
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
                    Text('Impressum', style: MnTypography.display(size: 28)),
                    const SizedBox(height: 24),
                    Text(
                      'Mensaena ist ein gemeinnuetziges Projekt, betrieben von:',
                      style: MnTypography.body(color: MnColors.inkSoft),
                    ),
                    const SizedBox(height: 16),
                    Text('Uwe Vetter', style: MnTypography.body(weight: FontWeight.w600)),
                    Text(
                      'Via d\'Ascoli 25\n92021 Aragona AG\nItalien',
                      style: MnTypography.body(color: MnColors.inkSoft),
                    ),
                    const SizedBox(height: 12),
                    Text('Manuel Brandner', style: MnTypography.body(weight: FontWeight.w600)),
                    Text('Im Wahlsberg 10\n55543 Bad Kreuznach\nDeutschland',
                        style: MnTypography.body(color: MnColors.inkSoft)),
                    const SizedBox(height: 24),
                    Text('Kontakt', style: MnTypography.display(size: 20)),
                    const SizedBox(height: 8),
                    Text('info@mensaena.de',
                        style: MnTypography.body(color: MnColors.amber)),
                    const SizedBox(height: 24),
                    Text('Haftungsausschluss', style: MnTypography.display(size: 20)),
                    const SizedBox(height: 8),
                    Text(
                      'Die Inhalte unserer App wurden mit groesster Sorgfalt erstellt. '
                      'Fuer die Richtigkeit, Vollstaendigkeit und Aktualitaet der Inhalte '
                      'koennen wir jedoch keine Gewaehr uebernehmen.',
                      style: MnTypography.body(color: MnColors.inkSoft, height: 1.7),
                    ),
                    const SizedBox(height: 24),
                    Text('Streitschlichtung', style: MnTypography.display(size: 20)),
                    const SizedBox(height: 8),
                    Text(
                      'Wir sind nicht bereit oder verpflichtet, an Streitbeilegungsverfahren '
                      'vor einer Verbraucherschlichtungsstelle teilzunehmen.',
                      style: MnTypography.body(color: MnColors.inkSoft, height: 1.7),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
