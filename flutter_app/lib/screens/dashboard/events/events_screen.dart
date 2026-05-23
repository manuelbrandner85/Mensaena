import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/event.dart';
import '../../../repositories/events_repository.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features
/// Events-Liste: kommende Events sortiert nach Startdatum.
class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(upcomingEventsProvider);
    return DashboardScaffold(
      title: 'Events',
      currentRoute: '/dashboard/events',
      fab: FloatingActionButton.extended(
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.voidColor,
        onPressed: () => context.go('/dashboard/events/create'),
        icon: const Icon(LucideIcons.plus),
        label: const Text('Event erstellen'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.amber,
          backgroundColor: AppColors.surface,
          onRefresh: () async => ref.invalidate(upcomingEventsProvider),
          child: async.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.amber),
            ),
            error: (e, _) => Center(
              child: Text('$e', style: AppTypography.caption()),
            ),
            data: (list) {
              if (list.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    Center(
                      child: Column(
                        children: [
                          const Icon(
                            LucideIcons.calendar,
                            size: 32,
                            color: AppColors.mute,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Keine kommenden Events.',
                            style: AppTypography.body(
                              size: 14,
                              color: AppColors.mute,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (context, i) => _EventTile(event: list[i]),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});
  final EventItem event;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEE, dd.MM.', 'de');
    final tf = DateFormat('HH:mm');
    return InkWell(
      onTap: () => context.go('/dashboard/events/${event.id}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.5),
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.12),
                border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    df.format(event.startDate).split(',').last.trim(),
                    style: AppTypography.mono(
                      size: 16,
                      color: AppColors.amber,
                      weight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    df.format(event.startDate).split(',').first,
                    style: AppTypography.label(size: 9, color: AppColors.amber),
                  ),
                  if (!event.isAllDay)
                    Text(
                      tf.format(event.startDate),
                      style: AppTypography.mono(
                        size: 10,
                        color: AppColors.inkSoft,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: AppTypography.body(
                      size: 15,
                      color: AppColors.ink,
                      weight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.elevated,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          event.category,
                          style: AppTypography.label(
                            size: 9,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (event.attendeeCount > 0)
                        Text(
                          '${event.attendeeCount} Zusagen',
                          style: AppTypography.caption(),
                        ),
                    ],
                  ),
                  if (event.locationName != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(LucideIcons.mapPin,
                            size: 11, color: AppColors.mute),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            event.locationName!,
                            style: AppTypography.body(
                              size: 11,
                              color: AppColors.mute,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (event.isOnline) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(LucideIcons.video,
                            size: 11, color: AppColors.teal),
                        const SizedBox(width: 4),
                        Text(
                          'Online',
                          style: AppTypography.label(
                              size: 9, color: AppColors.teal),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
