import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/atmosphere/cinema_scaffold.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/glow_button.dart';

class OfflineScreen extends StatelessWidget {
  final VoidCallback? onRetry;
  const OfflineScreen({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return CinemaScaffold(
      level: AtmosphereLevel.immersive,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.wifiOff, size: 48, color: MnColors.mute),
                const SizedBox(height: 16),
                Text('Du bist offline', style: MnTypography.display(size: 28)),
                const SizedBox(height: 8),
                Text(
                  'Sobald du wieder verbunden bist, gehts weiter.',
                  style: MnTypography.body(color: MnColors.inkSoft),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                GlowButton(
                  label: 'Erneut versuchen',
                  variant: GlowVariant.ghost,
                  onPressed: onRetry,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
