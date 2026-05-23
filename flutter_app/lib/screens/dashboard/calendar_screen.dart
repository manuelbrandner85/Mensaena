import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/event.dart';
import '../../repositories/events_repository.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features
/// Kalender-Ansicht: einfache Monats-Liste mit Events nach Datum.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(upcomingEventsProvider);
    return DashboardScaffold(
      title: 'Kalender',
      currentRoute: '/dashboard/calendar',
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.amber,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            ref.invalidate(upcomingEventsProvider);
            await ref.read(upcomingEventsProvider.future);
          },
          child: async.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.amber),
          ),
          error: (e, _) => Center(child: Text('$e', style: AppTypography.caption())),
          data: (list) {
            if (list.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.calendar,
                        size: 32, color: AppColors.mute),
                    const SizedBox(height: 10),
                    Text('Keine Events im Kalender.',
                        style: AppTypography.body(
                          size: 14,
                          color: AppColors.mute,
                        )),
                  ],
                ),
              );
            }
            // Group by date (yyyy-mm-dd).
            final groups = <String, List<EventItem>>{};
            for (final e in list) {
              final key = DateFormat('yyyy-MM-dd').format(e.startDate);
              groups.putIfAbsent(key, () => []).add(e);
            }
            final sortedKeys = groups.keys.toList()..sort();
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final key in sortedKeys)
                  _DaySection(
                    date: DateTime.parse(key),
                    events: groups[key]!,
                  ),
              ],
            );
          },
        ),
        ),
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({required this.date, required this.events});
  final DateTime date;
  final List<EventItem> events;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEEE, dd.MM.', 'de');
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
            ),
            child: Text(
              df.format(date),
              style: AppTypography.label(
                size: 10,
                color: AppColors.amber,
                letterSpacing: 0.15,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...events.map((e) => _EventRow(event: e)),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});
  final EventItem event;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.go('/dashboard/events/${event.id}'),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.4),
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Text(
                event.isAllDay
                    ? 'Tag'
                    : DateFormat('HH:mm').format(event.startDate),
                style: AppTypography.mono(
                  size: 12,
                  color: AppColors.amber,
                  weight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Text(
                event.title,
                style: AppTypography.body(
                  size: 14,
                  color: AppColors.ink,
                  weight: FontWeight.w600,
                ),
              ),
            ),
            if (event.locationName != null)
              const Icon(LucideIcons.mapPin, size: 12, color: AppColors.mute),
          ],
        ),
      ),
    );
  }
}
