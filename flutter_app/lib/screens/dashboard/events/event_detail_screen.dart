import 'dart:io';

import 'package:add_2_calendar/add_2_calendar.dart' as a2c;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/event.dart';
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
      title: 'events.title'.tr(),
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
                child: Text('events.notFound'.tr(),
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
                    label: Text('events.openOnlineLink'.tr()),
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
                  Text('events.bring'.tr(), style: AppTypography.label(size: 10)),
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
                Text('events.rsvp'.tr(), style: AppTypography.label(size: 10)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _RsvpButton(
                      label: 'events.rsvpGoing'.tr(),
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
                      label: 'events.rsvpMaybe'.tr(),
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
                      label: 'events.rsvpDeclined'.tr(),
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
                  e.maxAttendees != null
                      ? 'events.attendeesWithMax'.tr(namedArgs: {
                          'count': '${e.attendeeCount}',
                          'max': '${e.maxAttendees}',
                        })
                      : 'events.attendees'.tr(
                          namedArgs: {'count': '${e.attendeeCount}'}),
                  style: AppTypography.caption(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _addToSystemCalendar(context, e),
                        icon: const Icon(LucideIcons.calendarPlus, size: 14),
                        label: Text('events.addToCalendar'.tr()),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.bronze,
                          foregroundColor: AppColors.voidColor,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _exportToCalendar(context, e),
                      icon: const Icon(LucideIcons.share2, size: 14),
                      label: const Text('.ics'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.bronze,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 1-Tap: System-Kalender öffnen mit vorbefülltem Event.
  Future<void> _addToSystemCalendar(BuildContext context, EventItem e) async {
    try {
      final endDate = e.endDate ?? e.startDate.add(const Duration(hours: 2));
      final location = [e.locationName, e.locationAddress]
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .join(', ');
      final entry = a2c.Event(
        title: e.title,
        description: e.description ?? '',
        location: location.isEmpty ? null : location,
        startDate: e.startDate,
        endDate: endDate,
        iosParams: const a2c.IOSParams(reminder: Duration(minutes: 60)),
        androidParams:
            const a2c.AndroidParams(emailInvites: <String>[]),
      );
      final ok = await a2c.Add2Calendar.addEvent2Cal(entry);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text(
          ok ? 'events.openedInCalendar'.tr() : 'events.calendarNotOpened'.tr(),
          style: AppTypography.body(size: 13, color: AppColors.ink),
        ),
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('events.error'.tr(namedArgs: {'error': '$e'}),
            style: AppTypography.body(size: 13, color: AppColors.ink)),
      ));
    }
  }

  /// ICS (iCalendar) Export — Pendant zu Web `event-to-ics` Util.
  /// Generiert RFC-5545 konforme .ics-Datei und teilt sie via Share-Sheet.
  /// Apple Kalender / Google Kalender / Outlook erkennen das Format automatisch.
  Future<void> _exportToCalendar(BuildContext context, EventItem e) async {
    String fmt(DateTime d) {
      final utc = d.toUtc();
      final y = utc.year.toString().padLeft(4, '0');
      final m = utc.month.toString().padLeft(2, '0');
      final dd = utc.day.toString().padLeft(2, '0');
      final hh = utc.hour.toString().padLeft(2, '0');
      final mm = utc.minute.toString().padLeft(2, '0');
      final ss = utc.second.toString().padLeft(2, '0');
      return '$y$m${dd}T$hh$mm${ss}Z';
    }

    String esc(String s) =>
        s.replaceAll(r'\', r'\\')
            .replaceAll(',', r'\,')
            .replaceAll(';', r'\;')
            .replaceAll('\n', r'\n');

    final start = fmt(e.startDate);
    final end = fmt(e.endDate ?? e.startDate.add(const Duration(hours: 2)));
    final now = fmt(DateTime.now());
    final location = [e.locationName, e.locationAddress]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(', ');

    final ics = [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Mensaena//EventExport 1.0//DE',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'BEGIN:VEVENT',
      'UID:event-${e.id}@mensaena.de',
      'DTSTAMP:$now',
      'DTSTART:$start',
      'DTEND:$end',
      'SUMMARY:${esc(e.title)}',
      if (e.description != null && e.description!.isNotEmpty)
        'DESCRIPTION:${esc(e.description!)}',
      if (location.isNotEmpty) 'LOCATION:${esc(location)}',
      if (e.onlineUrl != null) 'URL:${esc(e.onlineUrl!)}',
      'STATUS:CONFIRMED',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n');

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/event-${e.id}.ics');
      await file.writeAsString(ics);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/calendar')],
        text: '${e.title} — Mensaena',
        subject: e.title,
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('events.exportFailed'.tr(),
            style: AppTypography.body(
                size: 13, color: AppColors.ink)),
      ));
    }
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
