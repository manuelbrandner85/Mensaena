/// SKILL: mensaena-features (P10) — Karma-Verlauf.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../providers/wave_final_providers.dart';
import '../../widgets/effects/glass_card.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';

class KarmaHistoryScreen extends ConsumerWidget {
  const KarmaHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(karmaLogProvider);
    return DashboardScaffold(
      title: 'karma.history_title'.tr(),
      currentRoute: '/dashboard/karma-history',
      onRefresh: () async {
        ref.invalidate(karmaLogProvider);
        await Future<void>.delayed(const Duration(milliseconds: 250));
      },
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.bronze)),
        error: (_, __) => const SizedBox.shrink(),
        data: (rows) {
          if (rows.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(LucideIcons.sparkles,
                      size: 32, color: AppColors.mute),
                  const SizedBox(height: 8),
                  Text('karma.no_history'.tr(),
                      style: AppTypography.caption()),
                ]),
              ),
            );
          }
          final df = DateFormat('dd.MM. HH:mm');
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: rows.length,
            itemBuilder: (_, i) {
              final r = rows[i];
              final delta = (r['delta'] as num?)?.toInt() ?? 0;
              final reason = r['reason'] as String? ?? '';
              final ts =
                  DateTime.tryParse(r['created_at'] as String? ?? '')?.toUtc() ??
                      DateTime.now();
              final positive = delta >= 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (positive ? AppColors.amber : AppColors.herzrotWarm)
                            .withValues(alpha: 0.18),
                      ),
                      child: Icon(
                        positive
                            ? LucideIcons.trendingUp
                            : LucideIcons.trendingDown,
                        size: 18,
                        color: positive
                            ? AppColors.amber
                            : AppColors.herzrotWarm,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(reason,
                              style: AppTypography.body(
                                  size: 13,
                                  color: AppColors.ink,
                                  weight: FontWeight.w600)),
                          Text(df.format(ts),
                              style: AppTypography.caption()),
                        ],
                      ),
                    ),
                    Text(
                      positive ? '+$delta' : '$delta',
                      style: AppTypography.display(
                          size: 16,
                          color: positive
                              ? AppColors.amber
                              : AppColors.herzrotWarm),
                    ),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
