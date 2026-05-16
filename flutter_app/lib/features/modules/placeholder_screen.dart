import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/cinema_app_shell.dart';
import '../../core/widgets/cinema_empty_state.dart';

/// Generischer Stub fuer Module die in der Web-Sidebar existieren aber
/// in Flutter (noch) nicht ausimplementiert sind. Behaelt die Navigation
/// 1:1 zur Webseite konsistent — Phase 3.3.0 fuellt mit echtem Content.
class PlaceholderScreen extends StatelessWidget {
  final String currentRoute;
  final String title;
  final IconData icon;
  final String description;

  const PlaceholderScreen({
    super.key,
    required this.currentRoute,
    required this.title,
    required this.icon,
    this.description = 'Diese Funktion wird in einem naechsten Update verfuegbar.',
  });

  @override
  Widget build(BuildContext context) {
    return CinemaAppShell(
      currentRoute: currentRoute,
      title: title.toUpperCase(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CinemaEmptyState(
                  icon: icon,
                  title: title,
                  message: description,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: MnColors.amber.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: MnColors.amber.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.clock,
                        size: 13,
                        color: MnColors.amber,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Demnaechst verfuegbar',
                        style: MnTypography.label(color: MnColors.amber),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
