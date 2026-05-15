import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';

class SectionDivider extends StatelessWidget {
  final String? sectionNumber;
  final double height;

  const SectionDivider({
    super.key,
    this.sectionNumber,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (sectionNumber != null)
            Text(
              sectionNumber!,
              style: MnTypography.mono(
                size: 72,
                color: MnColors.ghost.withValues(alpha: 0.05),
              ),
            ),
          Center(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    MnColors.amber.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
