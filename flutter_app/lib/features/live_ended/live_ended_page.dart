import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routing/routes.dart';
import '../../theme/app_colors.dart';
import '../../widgets/buttons.dart';
import '../../widgets/cards.dart';

/// Pendant zu /live-ended – wird angezeigt, wenn ein LiveKit-Call beendet wurde.
class LiveEndedPage extends StatelessWidget {
  const LiveEndedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AppCard(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.call_end, size: 48, color: AppColors.emergency500),
                const SizedBox(height: 12),
                Text('Anruf beendet', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Der Live-Anruf wurde beendet.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                BtnPrimary(
                  onPressed: () => context.go(Routes.dashboard),
                  label: 'Zum Dashboard',
                  fullWidth: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
