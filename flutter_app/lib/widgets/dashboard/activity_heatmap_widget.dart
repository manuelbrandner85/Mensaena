/// SKILL: mensaena-features + mensaena-design
/// Activity-Heatmap-Widget (F33): 12-Wochen-Grid mit Bronze-Intensitaet
/// pro Tages-Aktivitaet. GitHub-style aber Mensaena-Cinema-Look.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/activity_heatmap_service.dart';
import 'tile_error.dart';
import '../effects/glass_card.dart';

final _heatmapProvider =
    FutureProvider.family<ActivityHeatmap, String?>((ref, userId) async {
  return ActivityHeatmapService.compute(userId: userId);
});

const int _weeks = 12;
const int _cellSize = 12;
const double _cellGap = 3;

class ActivityHeatmapWidget extends ConsumerWidget {
  const ActivityHeatmapWidget({this.userId, super.key});

  /// Optional: fremder User; null = aktueller User.
  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_heatmapProvider(userId));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => DashboardTileError(onRetry: () => ref.invalidate(_heatmapProvider)),
      data: (h) {
        if (h.totalCount == 0) return const SizedBox.shrink();
        return GlassCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.calendarDays,
                      size: 18, color: AppColors.bronze),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('heatmap.title'.tr(),
                        style: AppTypography.body(
                            size: 13,
                            color: AppColors.ink,
                            weight: FontWeight.w700)),
                  ),
                  Text(
                    'heatmap.totalCount'
                        .tr(namedArgs: {'count': '${h.totalCount}'}),
                    style: AppTypography.caption(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _Grid(h: h),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('heatmap.less'.tr(),
                      style: AppTypography.caption()),
                  const SizedBox(width: 6),
                  for (final i in const [0, 1, 2, 3, 4])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _colorForLevel(i),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  Text('heatmap.more'.tr(),
                      style: AppTypography.caption()),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.h});
  final ActivityHeatmap h;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final today0 = DateTime(today.year, today.month, today.day);
    final maxCount = h.maxCount;
    // Spalten = Wochen, Zeilen = Wochentag (7).
    final columns = <Widget>[];
    for (int w = _weeks - 1; w >= 0; w--) {
      final rows = <Widget>[];
      for (int d = 0; d < 7; d++) {
        // Zelle: heute, dann 1d zurueck, etc. Layout: Mo bis So von oben nach unten.
        // Wir berechnen Datum so: today - (w * 7 + (6 - dayIndexAdjusted))
        // Vereinfacht: counte Tage rueckwaerts ab today, indexiert ueber w*7 + d.
        final offset = w * 7 + d;
        final date = today0.subtract(Duration(days: offset));
        final c = h.countFor(date);
        final level = _level(c, maxCount);
        rows.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: _cellGap / 2),
          child: Tooltip(
            message:
                '${date.day}.${date.month}.${date.year} — $c',
            child: Container(
              width: _cellSize.toDouble(),
              height: _cellSize.toDouble(),
              decoration: BoxDecoration(
                color: _colorForLevel(level),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
        ));
      }
      columns.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: _cellGap / 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: rows,
        ),
      ));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: columns),
    );
  }
}

int _level(int count, int max) {
  if (count == 0) return 0;
  if (max <= 1) return 4;
  final ratio = count / max;
  if (ratio < 0.25) return 1;
  if (ratio < 0.5) return 2;
  if (ratio < 0.75) return 3;
  return 4;
}

Color _colorForLevel(int level) {
  switch (level) {
    case 0:
      return AppColors.elevated;
    case 1:
      return AppColors.bronze.withValues(alpha: 0.22);
    case 2:
      return AppColors.bronze.withValues(alpha: 0.45);
    case 3:
      return AppColors.bronze.withValues(alpha: 0.7);
    case 4:
    default:
      return AppColors.bronze;
  }
}
