/// SKILL: mensaena-features + mensaena-design
/// Today-Events-Widget (F86): naechstes Event in den naechsten 24h.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/event.dart';
import '../../repositories/events_repository.dart';
import '../effects/bloom.dart';
import '../effects/glass_card.dart';

final _todayEventProvider = FutureProvider<EventItem?>((ref) async {
  final all = await EventsRepository.listUpcoming(limit: 10);
  final cutoff = DateTime.now().add(const Duration(hours: 24));
  for (final e in all) {
    if (e.startDate.isBefore(cutoff)) return e;
  }
  return null;
});

class TodayEventsWidget extends ConsumerWidget {
  const TodayEventsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_todayEventProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (e) {
        if (e == null) return const SizedBox.shrink();
        final time = DateFormat.Hm().format(e.startDate.toLocal());
        final isToday = e.startDate.toLocal().day == DateTime.now().day;
        final dayLabel = isToday
            ? 'todayEvents.today'.tr()
            : 'todayEvents.tomorrow'.tr();
        return GlassCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: InkWell(
            onTap: () => context.push('/dashboard/events/${e.id}'),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Bloom(
                    color: AppColors.lebenSoft,
                    intensity: 0.5,
                    radius: 12,
                    child: Icon(LucideIcons.calendar,
                        size: 20, color: AppColors.lebenSoft),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.lebenSoft
                                    .withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('$dayLabel · $time',
                                  style: AppTypography.body(
                                      size: 10,
                                      color: AppColors.lebenSoft,
                                      weight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(e.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body(
                                size: 14,
                                color: AppColors.ink,
                                weight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const Icon(LucideIcons.chevronRight,
                      size: 14, color: AppColors.mute),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
