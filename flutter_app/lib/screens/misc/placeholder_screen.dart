import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

/// SKILL: mensaena-architektur
/// Platzhalter fuer Routen deren Screen noch nicht implementiert ist.
/// Verschwindet sobald die jeweilige Phase (2/3/4/5) die Route befuellt.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    required this.title,
    this.phase = '',
    super.key,
  });

  final String title;
  final String phase;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(LucideIcons.arrowLeft),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(title, style: AppTypography.appBarTitle()),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.hammer,
                size: 48,
                color: AppColors.amber,
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: AppTypography.display(size: 28, color: AppColors.ink),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                phase.isNotEmpty
                    ? 'Wird in $phase implementiert.'
                    : 'Dieses Modul ist noch im Aufbau.',
                style: AppTypography.body(color: AppColors.inkSoft),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(LucideIcons.home, size: 16),
                label: const Text('Zur Startseite'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
