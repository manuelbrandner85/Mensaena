import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/atmosphere/cinema_scaffold.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dimensions.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/cinema_appbar.dart';
import '../../core/widgets/cinema_empty_state.dart';
import '../../core/widgets/cinema_loading_skeleton.dart';
import '../../services/supabase/supabase_service.dart';

/// Warnungen aus der `warnings`-Tabelle (von NINA/DWD-Workern befuellt).
final activeWarningsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await supabase.client
        .from('warnings')
        .select()
        .eq('active', true)
        .order('starts_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(res as List);
  } catch (_) {
    return const [];
  }
});

class WarnungenScreen extends ConsumerWidget {
  const WarnungenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warnings = ref.watch(activeWarningsProvider);

    return CinemaScaffold(
      appBar: const CinemaAppBar(title: 'WARNUNGEN'),
      body: SafeArea(
        child: warnings.when(
          loading: () => const CinemaLoadingSkeleton(variant: SkeletonVariant.list),
          error: (e, _) => CinemaEmptyState(
            icon: LucideIcons.alertCircle,
            title: 'Fehler',
            message: e.toString(),
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return const CinemaEmptyState(
                icon: LucideIcons.shieldCheck,
                title: 'Keine aktiven Warnungen.',
                message: 'In deiner Region sind aktuell keine Notfall- oder Wetterwarnungen aktiv.',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              itemBuilder: (_, i) => _WarningCard(warning: rows[i]),
            );
          },
        ),
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  final Map<String, dynamic> warning;
  const _WarningCard({required this.warning});

  Color _severityColor(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'extreme':
      case 'severe':
        return MnColors.herzrot;
      case 'moderate':
        return MnColors.amber;
      default:
        return MnColors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final severity = warning['severity'] as String?;
    final color = _severityColor(severity);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MnColors.elevated,
        borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.alertTriangle, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  (warning['headline'] as String?) ?? 'Warnung',
                  style: MnTypography.body(
                    color: MnColors.ink,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              if (severity != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius:
                        BorderRadius.circular(MnDimensions.radiusPill),
                  ),
                  child: Text(
                    severity.toUpperCase(),
                    style: MnTypography.label(size: 10, color: color),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            (warning['description'] as String?) ?? '',
            style: MnTypography.body(color: MnColors.inkSoft, size: 13),
          ),
          if (warning['region'] != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(LucideIcons.mapPin, size: 13, color: MnColors.mute),
                const SizedBox(width: 4),
                Text(
                  warning['region'].toString(),
                  style: MnTypography.mono(size: 11, color: MnColors.mute),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
