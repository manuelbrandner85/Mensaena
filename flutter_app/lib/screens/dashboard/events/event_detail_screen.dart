import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/events_repository.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({required this.eventId, super.key});
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ev = ref.watch(eventDetailProvider(eventId));
    final rsvp = ref.watch(myRsvpProvider(eventId));

    return DashboardScaffold(
      title: 'Event',
      currentRoute: '/dashboard/events',
      body: SafeArea(
        child: ev.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.amber),
          ),
          error: (e, _) => Center(
            child: Text('$e', style: AppTypography.caption()),
          ),
          data: (e) {
            if (e == null) {
              return Center(
                child: Text('Event nicht gefunden.',
                    style: AppTypography.caption()),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (e.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      e.imageUrl!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(height: 14),
                Text(
                  e.title,
                  style: AppTypography.display(
                    size: 26,
                    color: AppColors.ink,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(LucideIcons.calendar,
                        size: 14, color: AppColors.amber),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('EEEE, dd.MM.yyyy', 'de').format(e.startDate),
                      style: AppTypography.body(
                        size: 14,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
                if (!e.isAllDay)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.clock,
                            size: 14, color: AppColors.amber),
                        const SizedBox(width: 6),
                        Text(
                          '${DateFormat('HH:mm').format(e.startDate)}${e.endDate != null ? " – ${DateFormat('HH:mm').format(e.endDate!)}" : ""}',
                          style: AppTypography.body(
                            size: 14,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (e.locationName != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(LucideIcons.mapPin,
                          size: 14, color: AppColors.amber),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          [e.locationName, e.locationAddress]
                              .whereType<String>()
                              .where((s) => s.isNotEmpty)
                              .join(' · '),
                          style: AppTypography.body(
                            size: 13,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (e.isOnline && e.onlineUrl != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(e.onlineUrl!),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(LucideIcons.video, size: 16),
                    label: const Text('Online-Link öffnen'),
                  ),
                ],
                const SizedBox(height: 16),
                if (e.description != null && e.description!.isNotEmpty)
                  Text(
                    e.description!,
                    style: AppTypography.body(
                      size: 14,
                      color: AppColors.inkSoft,
                      height: 1.55,
                    ),
                  ),
                if (e.whatToBring != null && e.whatToBring!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text('Mitbringen', style: AppTypography.label(size: 10)),
                  const SizedBox(height: 4),
                  Text(
                    e.whatToBring!,
                    style:
                        AppTypography.body(size: 13, color: AppColors.inkSoft),
                  ),
                ],
                if (e.cost != null && e.cost!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(LucideIcons.euro,
                          size: 14, color: AppColors.amber),
                      const SizedBox(width: 6),
                      Text(
                        e.cost!,
                        style: AppTypography.body(
                          size: 13,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                Text('Zusage', style: AppTypography.label(size: 10)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _RsvpButton(
                      label: 'Ich komme',
                      icon: LucideIcons.checkCircle,
                      color: AppColors.leben,
                      active: rsvp.asData?.value == 'going',
                      onTap: () async {
                        await EventsRepository.rsvp(
                          eventId: eventId,
                          status: 'going',
                        );
                        ref.invalidate(myRsvpProvider(eventId));
                      },
                    ),
                    _RsvpButton(
                      label: 'Vielleicht',
                      icon: LucideIcons.helpCircle,
                      color: AppColors.amber,
                      active: rsvp.asData?.value == 'maybe',
                      onTap: () async {
                        await EventsRepository.rsvp(
                          eventId: eventId,
                          status: 'maybe',
                        );
                        ref.invalidate(myRsvpProvider(eventId));
                      },
                    ),
                    _RsvpButton(
                      label: 'Sage ab',
                      icon: LucideIcons.xCircle,
                      color: AppColors.mute,
                      active: rsvp.asData?.value == 'declined',
                      onTap: () async {
                        await EventsRepository.rsvp(
                          eventId: eventId,
                          status: 'declined',
                        );
                        ref.invalidate(myRsvpProvider(eventId));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${e.attendeeCount} Teilnehmer:innen'
                  '${e.maxAttendees != null ? ' / max. ${e.maxAttendees}' : ''}',
                  style: AppTypography.caption(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RsvpButton extends StatelessWidget {
  const _RsvpButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.active,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? color.withValues(alpha: 0.2)
              : AppColors.surface.withValues(alpha: 0.5),
          border: Border.all(
            color: active ? color : AppColors.line,
            width: active ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.label(
                size: 10,
                color: active ? color : AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
