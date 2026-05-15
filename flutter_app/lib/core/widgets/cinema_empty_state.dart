import 'package:flutter/material.dart';

import '../painters/lantern_particles.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class CinemaEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final bool withLanternBackdrop;

  const CinemaEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.withLanternBackdrop = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 320,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (withLanternBackdrop)
            const Positioned.fill(child: LanternParticlesWidget(count: 5)),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: MnColors.mute.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: MnTypography.body(
                    size: 16,
                    color: MnColors.inkSoft,
                    weight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (message != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    message!,
                    style: MnTypography.body(color: MnColors.mute),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: 20),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
