import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';

class GreetingHeader extends StatelessWidget {
  final String name;

  const GreetingHeader({super.key, required this.name});

  String get _tageszeit {
    final h = DateTime.now().hour;
    if (h >= 5 && h <= 11) return 'Morgen';
    if (h >= 12 && h <= 17) return 'Tag';
    if (h >= 18 && h <= 21) return 'Abend';
    return 'Nacht';
  }

  @override
  Widget build(BuildContext context) {
    final atNight = _tageszeit == 'Nacht';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        'Guten $_tageszeit, $name',
        style: MnTypography.display(
          size: 28,
          shadows: atNight
              ? [
                  Shadow(
                    color: MnColors.amber.withValues(alpha: 0.5),
                    blurRadius: 20,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}
