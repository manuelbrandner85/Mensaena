import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/dimensions.dart';
import '../theme/typography.dart';

class CinemaProgress extends StatelessWidget {
  final double value; // 0..1
  final String? label;
  final Color color;
  final double height;

  const CinemaProgress({
    super.key,
    required this.value,
    this.label,
    this.color = MnColors.amber,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(MnDimensions.radiusPill),
            child: Stack(
              children: [
                Container(height: height, color: MnColors.surface),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  widthFactor: clamped,
                  child: Container(
                    height: height,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0.7)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (label != null) ...[
          const SizedBox(width: 10),
          Text(label!, style: MnTypography.mono(size: 12, color: color)),
        ],
      ],
    );
  }
}
