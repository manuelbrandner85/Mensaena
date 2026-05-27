/// SKILL: mensaena-features (Phase 10 E4)
/// ProgressTrioWidget — kombiniert Karma + Streak + HelpStreak in einer
/// Row. Jede Zelle = Flexible(1) damit die drei Widgets gleichmäßig
/// nebeneinander stehen. Spart 2 Slots im Dashboard.
library;

import 'package:flutter/material.dart';

import 'help_streak_widget.dart';
import 'karma_widget.dart';
import 'streak_widget.dart';

class ProgressTrioWidget extends StatelessWidget {
  const ProgressTrioWidget({super.key});

  @override
  Widget build(BuildContext context) {
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
}
