// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, require_trailing_commas
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/dimensions.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/cinema_app_shell.dart';
import '../../core/widgets/cinema_empty_state.dart';
import '../../core/widgets/cinema_loading_skeleton.dart';
import '../../services/supabase/supabase_service.dart';

/// Web-Pendant `/dashboard/calendar` — chronologische Liste der naechsten
/// Events des Users + alle aktiven Community-Events.
final upcomingEventsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final res = await supabase.client
      .from('events')
      .select()
      .gte('starts_at', DateTime.now().toIso8601String())
      .order('starts_at', ascending: true)
      .limit(50);
  return List<Map<String, dynamic>>.from(res as List);
});

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(upcomingEventsProvider);

    return CinemaAppShell(
      currentRoute: '/calendar',
      title: 'KALENDER',
      body: SafeArea(
        child: events.when(
          loading: () => const CinemaLoadingSkeleton(variant: SkeletonVariant.list),
          error: (e, _) => CinemaEmptyState(
            icon: LucideIcons.alertCircle,
            title: 'Fehler',
            message: e.toString(),
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return const CinemaEmptyState(
                icon: LucideIcons.calendar,
                title: 'Keine bevorstehenden Events.',
                message: 'Sobald jemand ein Event erstellt, taucht es hier auf.',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              itemBuilder: (_, i) => _EventTile(event: rows[i]),
            );
          },
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final Map<String, dynamic> event;
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final start = DateTime.tryParse((event['starts_at'] as String?) ?? '');
    final day = start == null ? '--' : start.day.toString().padLeft(2, '0');
    final month = start == null ? '---' : _monthShort(start.month);
    return InkWell(
      onTap: () => GoRouter.of(context).push('/modules/events/${event['id']}'),
      borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MnColors.elevated,
          borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
          border: Border.all(color: MnColors.line),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: MnColors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: MnColors.amber.withValues(alpha: 0.20)),
              ),
              child: Column(
                children: [
                  Text(
                    day,
                    style: MnTypography.mono(
                      size: 22,
                      color: MnColors.amber,
                      weight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    month,
                    style: MnTypography.label(color: MnColors.amberSoft),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (event['title'] as String?) ?? 'Event',
                    style: MnTypography.body(
                      color: MnColors.ink,
                      weight: FontWeight.w600,
                    ),
                  ),
                  if ((event['location'] as String?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.mapPin,
                          size: 12,
                          color: MnColors.mute,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event['location'] as String,
                            style: MnTypography.body(
                              color: MnColors.mute,
                              size: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, color: MnColors.mute, size: 16),
          ],
        ),
      ),
    );
  }

  String _monthShort(int m) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAI', 'JUN', 'JUL', 'AUG', 'SEP', 'OKT', 'NOV', 'DEZ'];
    return months[(m - 1).clamp(0, 11)];
  }
}
