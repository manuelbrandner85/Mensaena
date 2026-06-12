/// SKILL: mensaena-features
/// WeeklyChallengeHighlight — Top-3 Wochen-Challenges.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/dashboard_widgets_repository.dart';

class WeeklyChallengeHighlight extends StatefulWidget {
  const WeeklyChallengeHighlight({super.key});

  @override
  State<WeeklyChallengeHighlight> createState() =>
      _WeeklyChallengeHighlightState();
}

class _WeeklyChallengeHighlightState extends State<WeeklyChallengeHighlight> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    try {
      final now = DateTime.now();
      final weekday = now.weekday;
      final monday = now.subtract(Duration(days: weekday - 1));
      final weekOf =
          '${monday.year.toString().padLeft(4, '0')}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
      return DashboardWidgetsRepository.weeklyChallenges(weekOf);
    } catch (_) {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final list = snap.data ?? const <Map<String, dynamic>>[];
        if (list.isEmpty) return const SizedBox.shrink();
        return InkWell(
          onTap: () => context.go('/dashboard/challenges'),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.bronze.withValues(alpha: 0.18),
                  AppColors.amber.withValues(alpha: 0.10),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border:
                  Border.all(color: AppColors.bronze.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.sparkles,
                        color: AppColors.bronze, size: 14),
                    const SizedBox(width: 6),
                    Text('home.challengesThisWeek'.tr(),
                        style: AppTypography.label(
                            size: 10, color: AppColors.bronzeSoft)),
                    const Spacer(),
                    Text('home.allArrow'.tr(),
                        style: AppTypography.label(
                            size: 9, color: AppColors.bronze)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('home.weeklyImpulses'.tr(),
                    style: AppTypography.body(
                        size: 11, color: AppColors.mute)),
                const SizedBox(height: 10),
                for (final c in list)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.elevated,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (c['title'] as String?) ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.body(
                                      size: 13,
                                      color: AppColors.ink,
                                      weight: FontWeight.w600),
                                ),
                                if ((c['description'] as String?)
                                        ?.isNotEmpty ==
                                    true) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    c['description'] as String,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.body(
                                        size: 11,
                                        color: AppColors.mute),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.amber.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              children: [
                                const Icon(LucideIcons.trophy,
                                    size: 10, color: AppColors.amber),
                                const SizedBox(width: 3),
                                Text('${c['points'] ?? 0}',
                                    style: AppTypography.mono(
                                        size: 10,
                                        color: AppColors.amberWarm)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
