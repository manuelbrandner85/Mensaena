/// SKILL: mensaena-features (Phase 10 E4)
/// ProgressTrioWidget — kombiniert Karma + Streak + HelpStreak.
///
/// Responsive (Bugfix Layout): 3 vollwertige Cards nebeneinander
/// funktionieren nur bei breiten Screens (Tablet/Landscape). Auf
/// typischen Mobile-Displays (Portrait, <600 dp) reichten 130 dp pro
/// Card nicht für die i18n-Texte → "Dranbleiben" und "Nachbar:in"
/// wurden Buchstabe für Buchstabe vertikal gewickelt.
/// Jetzt: < 600 dp = untereinander gestapelt; ≥ 600 dp = 3-spaltig.
library;

import 'package:flutter/material.dart';

import 'help_streak_widget.dart';
import 'karma_widget.dart';
import 'streak_widget.dart';

class ProgressTrioWidget extends StatelessWidget {
  const ProgressTrioWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 600 dp = klassische Tablet-/Foldable-Schwelle.
        final wide = constraints.maxWidth >= 600;
        if (wide) {
          return const IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: KarmaWidget()),
                SizedBox(width: 8),
                Expanded(child: StreakWidget()),
                SizedBox(width: 8),
                Expanded(child: HelpStreakWidget()),
              ],
            ),
          );
        }
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KarmaWidget(),
            SizedBox(height: 8),
            StreakWidget(),
            SizedBox(height: 8),
            HelpStreakWidget(),
          ],
        );
      },
    );
  }
}
