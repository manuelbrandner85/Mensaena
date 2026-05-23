import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/emergency_number.dart';
import '../../../repositories/crisis_repository.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features
/// Notruf-Nummern + Resourcen-Page (emergency_numbers tabelle).
class CrisisResourcesScreen extends ConsumerWidget {
  const CrisisResourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(emergencyNumbersProvider('DE'));
    return DashboardScaffold(
      title: 'Notruf-Nummern',
      currentRoute: '/dashboard/crisis',
      body: SafeArea(
        child: async.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.herzrot),
          ),
          error: (e, _) => Center(
            child: Text('Fehler: $e', style: AppTypography.caption()),
          ),
          data: (list) {
            if (list.isEmpty) {
              return Center(
                child: Text(
                  'Keine Notruf-Nummern hinterlegt.',
                  style: AppTypography.caption(),
                ),
              );
            }
            // Gruppieren nach Kategorie.
            final groups = <String, List<EmergencyNumber>>{};
            for (final n in list) {
              groups.putIfAbsent(n.category, () => []).add(n);
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final entry in groups.entries) ...[
                  Text(
                    entry.key.toUpperCase(),
                    style: AppTypography.label(size: 10),
                  ),
                  const SizedBox(height: 6),
                  ...entry.value.map(_Tile.new),
                  const SizedBox(height: 16),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.n);
  final EmergencyNumber n;

  Future<void> _call() async {
    await launchUrl(Uri.parse('tel:${n.number}'));
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _call,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.5),
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.herzrot,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                n.number,
                style: AppTypography.mono(
                  size: 13,
                  color: AppColors.ink,
                  weight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.label,
                    style: AppTypography.body(
                      size: 14,
                      color: AppColors.ink,
                      weight: FontWeight.w600,
                    ),
                  ),
                  if (n.description != null)
                    Text(
                      n.description!,
                      style: AppTypography.caption(),
                    ),
                  if (n.is24h == true || n.isFree == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          if (n.is24h == true)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.leben.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text('24h',
                                  style: AppTypography.label(
                                      size: 8, color: AppColors.lebenSoft)),
                            ),
                          if (n.isFree == true)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.amber.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text('kostenlos',
                                  style: AppTypography.label(
                                      size: 8, color: AppColors.amber)),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Icon(LucideIcons.phone, color: AppColors.amber, size: 18),
          ],
        ),
      ),
    );
  }
}
