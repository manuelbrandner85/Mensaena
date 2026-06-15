/// SKILL: mensaena-features
/// Event-Detail-Screen — Komplett-Overhaul (Phase E3).
/// Hero-Image mit Gradient + Kategorie-Badge, Countdown, Date/Time/Location,
/// Author-Zeile, Description, Attendance-Sheet, Reminder-Widget,
/// Attendees-Sektion, Action-Bar (Calendar/Share) + Author-Actions
/// (Bearbeiten/Absagen/Loeschen) mit ConfirmDialog.
library;

import 'dart:io';

import 'package:add_2_calendar/add_2_calendar.dart' as a2c;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/event.dart';
import '../../../models/profile.dart';
import '../../../repositories/events_repository.dart';
import '../../../repositories/profiles_repository.dart';
import '../../../services/event_reminder_service.dart';
import '../../../services/haptics.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/effects/shimmer_skeleton.dart';
import '../../../widgets/event_attendees_section.dart';
import '../../../widgets/events/event_photos_gallery.dart';
import '../../../widgets/shared/premium_image.dart';
import '../../../widgets/events/event_qr_checkin_sheet.dart';
import '../../../widgets/effects/parallax_image_header.dart';
import '../../../widgets/event_countdown.dart';
import '../../../widgets/event_reminder_widget.dart';
import '../../../widgets/event_share_sheet.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/empty_state_card.dart';
import '../../../widgets/shared/app_snackbar.dart';

// Akzent-Farben fuer Event-Kategorien (Hero-Border + Badge).
const Map<String, Color> _categoryAccent = {
  'community': Color(0xFF1EAAA6),
  'sports': Color(0xFF3B82F6),
  'sport': Color(0xFF3B82F6),
  'culture': Color(0xFF8B5CF6),
  'kultur': Color(0xFF8B5CF6),
  'education': Color(0xFFF59E0B),
  'workshop': Color(0xFFF59E0B),
  'nature': Color(0xFF10B981),
  'food': Color(0xFFEF4444),
  'music': Color(0xFFEC4899),
  'volunteer': Color(0xFF1EAAA6),
  'kids': Color(0xFFF97316),
  'familie': Color(0xFFF97316),
  'other': Color(0xFF4F6D8A),
  'sonstiges': Color(0xFF4F6D8A),
};

Color _categoryColor(String? cat) =>
    _categoryAccent[cat ?? ''] ?? AppColors.amber;

String _categoryLabel(String? cat) {
  switch (cat) {
    case 'community':
      return 'Community';
    case 'sports':
    case 'sport':
      return 'Sport';
    case 'culture':
    case 'kultur':
      return 'Kultur';
    case 'education':
    case 'workshop':
      return 'Workshop';
    case 'nature':
      return 'Natur';
    case 'food':
      return 'Essen';
    case 'music':
      return 'Musik';
    case 'volunteer':
      return 'Ehrenamt';
    case 'kids':
    case 'familie':
      return 'Familie';
    default:
      return 'Sonstiges';
  }
}

/// Provider fuer Profil eines beliebigen Users (fuer Author-Zeile).
final _authorProfileProvider =
    FutureProvider.autoDispose.family<Profile?, String>((ref, userId) async {
  if (userId.isEmpty) return null;
  return ProfilesRepository.getById(userId);
});

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({required this.eventId, super.key});
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ev = ref.watch(eventDetailProvider(eventId));

    return DashboardScaffold(
      title: ev.asData?.value?.title ?? 'events.title'.tr(),
      currentRoute: '/dashboard/events',
      body: SafeArea(
        child: ev.when(
          loading: () => const _DetailSkeleton(),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: EmptyStateCard(
              title: 'events.notFound'.tr(),
              description: '$e',
              icon: LucideIcons.alertTriangle,
            ),
          ),
          data: (e) {
            if (e == null) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: EmptyStateCard(
                  title: 'events.notFound'.tr(),
                  icon: LucideIcons.calendarX,
                ),
              );
            }
            return _EventDetailBody(event: e);
          },
        ),
      ),
    );
  }
}

class _EventDetailBody extends ConsumerStatefulWidget {
  const _EventDetailBody({required this.event});
  final EventItem event;

  @override
  ConsumerState<_EventDetailBody> createState() => _EventDetailBodyState();
}

class _EventDetailBodyState extends ConsumerState<_EventDetailBody> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final accent = _categoryColor(event.category);
    final now = DateTime.now();
    final isUpcoming = event.startDate.isAfter(now);
    final isCancelled = event.status == 'cancelled';
    final isFull = event.maxAttendees != null &&
        event.attendeeCount >= (event.maxAttendees ?? 0);
    final myUid = SupabaseService.currentUser?.id;
    final isAuthor = myUid != null && myUid == event.authorId;
    final rsvpAsync = ref.watch(myRsvpProvider(event.id));
    final rsvp = rsvpAsync.asData?.value;

    return SingleChildScrollView(
      controller: _scroll,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1) Hero ──────────────────────────────────────────────
          _HeroBlock(event: event, accent: accent, scrollController: _scroll),

          // ── 2) Status-Badges ─────────────────────────────────────
          if (isCancelled || isFull) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  if (isCancelled)
                    _StatusPill(
                      icon: LucideIcons.xCircle,
                      label: 'events.eventCancelled'.tr(),
                      color: AppColors.herzrot,
                    ),
                  if (isCancelled && isFull) const SizedBox(width: 8),
                  if (isFull)
                    _StatusPill(
                      icon: LucideIcons.users,
                      label: 'events.attendeesWithMax'.tr(namedArgs: {
                        'count': '${event.attendeeCount}',
                        'max': '${event.maxAttendees}',
                      }),
                      color: AppColors.amberDeep,
                    ),
                ],
              ),
            ),
          ],

          // ── 3) Countdown ─────────────────────────────────────────
          if (isUpcoming && !isCancelled) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: EventCountdown(startsAt: event.startDate),
            ),
          ],

          // ── 4) Date/Time/Location ────────────────────────────────
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _DateTimeBlock(event: event),
          ),

          // ── 5) Author-Info ───────────────────────────────────────
          if (event.authorId.isNotEmpty) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _AuthorRow(authorId: event.authorId),
            ),
          ],

          // ── 6) Description ───────────────────────────────────────
          if (event.description != null && event.description!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                event.description!,
                style: AppTypography.body(
                  size: 14,
                  color: AppColors.inkSoft,
                  height: 1.55,
                ),
              ),
            ),
          ],

          // ── 7) Mitbringen / Cost ─────────────────────────────────
          if (event.whatToBring != null && event.whatToBring!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('events.bring'.tr(),
                      style: AppTypography.label(size: 10)),
                  const SizedBox(height: 4),
                  Text(
                    event.whatToBring!,
                    style: AppTypography.body(
                      size: 13,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (event.cost == null ||
              event.cost == 'free' ||
              (event.cost != null && event.cost!.isNotEmpty)) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(LucideIcons.euro,
                      size: 14, color: AppColors.amber),
                  const SizedBox(width: 6),
                  Text(
                    (event.cost == null || event.cost == 'free')
                        ? 'event.free'.tr()
                        : event.cost!,
                    style: AppTypography.body(
                      size: 13,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── 8) Attendance ────────────────────────────────────────
          if (!isCancelled) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _AttendanceBlock(
                event: event,
                rsvp: rsvp,
                accent: accent,
                // Capacity-Full + noch keine RSVP → Button gesperrt, sonst
                // koennte User tippen + Server reject ohne UI-Feedback.
                onOpenSheet: (isFull && rsvp == null)
                    ? null
                    : () => _openAttendanceSheet(
                          context,
                          ref,
                          eventId: event.id,
                          currentRsvp: rsvp,
                        ),
              ),
            ),
          ],

          // ── 9) Reminder ──────────────────────────────────────────
          if (rsvp == 'going' && isUpcoming && !isCancelled) ...[
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: EventReminderWidget(
                eventId: event.id,
                eventStart: event.startDate,
                eventTitle: event.title,
                initialReminderMinutes: null,
              ),
            ),
          ],

          // ── 10) Attendees ────────────────────────────────────────
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: EventAttendeesSection(eventId: event.id),
          ),

          // ── 10b) Foto-Galerie (P9 F94) ──────────────────────────
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: EventPhotosGallery(eventId: event.id),
          ),

          // ── 11) Action-Bar ───────────────────────────────────────
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _addToSystemCalendar(context, event),
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
                  onPressed: () => _exportToCalendar(context, event),
                  icon: const Icon(LucideIcons.calendar, size: 14),
                  label: const Text('.ics'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.bronze,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
                const SizedBox(width: 8),
                _SavedToggleButton(event: event),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'events.share'.tr(),
                  onPressed: () => EventShareSheet.show(
                    context,
                    eventId: event.id,
                    title: event.title,
                    startsAt: event.startDate,
                  ),
                  icon: const Icon(LucideIcons.share2, size: 18),
                  color: AppColors.bronze,
                ),
                if (!isAuthor) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'events.checkin_title'.tr(),
                    onPressed: () => EventQrCheckinSheet.show(
                      context,
                      eventId: event.id,
                      eventTitle: event.title,
                      isOrganizer: false,
                    ),
                    icon: const Icon(LucideIcons.qrCode, size: 18),
                    color: AppColors.bronze,
                  ),
                ],
              ],
            ),
          ),

          // ── 12) Author-Actions ───────────────────────────────────
          if (isAuthor) ...[
            const SizedBox(height: 24),
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'events.authorActions.title'.tr(),
                    style: AppTypography.label(size: 10),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => EventQrCheckinSheet.show(
                      context,
                      eventId: event.id,
                      eventTitle: event.title,
                      isOrganizer: true,
                    ),
                    icon: const Icon(LucideIcons.qrCode, size: 14),
                    label: Text('events.checkin_title'.tr()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.bronze,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      // Placeholder: Edit-Screen
                      AppSnackBar.info(context, 'events.authorActions.editComingSoon'.tr());
                    },
                    icon: const Icon(LucideIcons.edit3, size: 14),
                    label: Text('events.authorActions.edit'.tr()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!isCancelled)
                    OutlinedButton.icon(
                      onPressed: () => _confirmCancel(context, ref, event),
                      icon: const Icon(LucideIcons.xCircle, size: 14),
                      label: Text('events.authorActions.cancel'.tr()),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.mute,
                        side: const BorderSide(color: AppColors.line),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _confirmDelete(context, ref, event),
                    icon: const Icon(LucideIcons.trash2, size: 14),
                    label: Text('events.authorActions.delete'.tr()),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.herzrot,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Attendance-BottomSheet ─────────────────────────────────────
  Future<void> _openAttendanceSheet(
    BuildContext context,
    WidgetRef ref, {
    required String eventId,
    required String? currentRsvp,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'events.attendanceSheet.title'.tr(),
                      style: AppTypography.label(size: 11),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _AttendanceTile(
                  icon: LucideIcons.checkCircle,
                  color: AppColors.leben,
                  label: 'events.attendStatus.going'.tr(),
                  active: currentRsvp == 'going',
                  onTap: () async {
                    Haptics.tap();
                    Navigator.pop(ctx);
                    await EventsRepository.setAttendance(
                      eventId: eventId,
                      status: 'going',
                    );
                    ref.invalidate(myRsvpProvider(eventId));
                    ref.invalidate(eventAttendeesProvider(eventId));
                    ref.invalidate(eventDetailProvider(eventId));
                  },
                ),
                _AttendanceTile(
                  icon: LucideIcons.helpCircle,
                  color: AppColors.amber,
                  label: 'events.attendStatus.interested'.tr(),
                  active: currentRsvp == 'interested',
                  onTap: () async {
                    Haptics.tap();
                    Navigator.pop(ctx);
                    await EventsRepository.setAttendance(
                      eventId: eventId,
                      status: 'interested',
                    );
                    ref.invalidate(myRsvpProvider(eventId));
                    ref.invalidate(eventAttendeesProvider(eventId));
                    ref.invalidate(eventDetailProvider(eventId));
                  },
                ),
                _AttendanceTile(
                  icon: LucideIcons.xCircle,
                  color: AppColors.mute,
                  label: 'events.attendStatus.declined'.tr(),
                  active: currentRsvp == 'declined',
                  onTap: () async {
                    Haptics.tap();
                    Navigator.pop(ctx);
                    await EventsRepository.setAttendance(
                      eventId: eventId,
                      status: 'declined',
                    );
                    ref.invalidate(myRsvpProvider(eventId));
                    ref.invalidate(eventAttendeesProvider(eventId));
                    ref.invalidate(eventDetailProvider(eventId));
                  },
                ),
                if (currentRsvp != null)
                  _AttendanceTile(
                    icon: LucideIcons.userMinus,
                    color: AppColors.herzrot,
                    label: 'events.attendanceSheet.signOff'.tr(),
                    active: false,
                    onTap: () async {
                      Haptics.tap();
                      Navigator.pop(ctx);
                      await EventsRepository.removeAttendance(eventId);
                      ref.invalidate(myRsvpProvider(eventId));
                      ref.invalidate(eventAttendeesProvider(eventId));
                      ref.invalidate(eventDetailProvider(eventId));
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Author-Actions ─────────────────────────────────────────────
  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    EventItem e,
  ) async {
    final ok = await ConfirmDialog.show(
      context,
      title: 'events.authorActions.cancelConfirm'.tr(),
      message: 'events.authorActions.cancelConfirmMessage'.tr(),
      danger: true,
    );
    if (!ok || !context.mounted) return;
    final success = await EventsRepository.cancelEvent(e.id);
    if (!context.mounted) return;
    AppSnackBar.info(context, success ? 'events.authorActions.cancelled'.tr() : 'events.error'.tr(namedArgs: {'error': '500'}));
    if (success) {
      ref.invalidate(eventDetailProvider(e.id));
      if (context.mounted) context.pop();
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    EventItem e,
  ) async {
    final ok = await ConfirmDialog.show(
      context,
      title: 'events.authorActions.deleteConfirm'.tr(),
      message: 'events.authorActions.deleteConfirmMessage'.tr(),
      danger: true,
    );
    if (!ok || !context.mounted) return;
    final success = await EventsRepository.deleteEvent(e.id);
    if (!context.mounted) return;
    AppSnackBar.info(context, success ? 'events.authorActions.deleted'.tr() : 'events.error'.tr(namedArgs: {'error': '500'}));
    if (success && context.mounted) {
      context.pop();
    }
  }

  // ── Calendar (unveraendert: add_2_calendar + share_plus .ics) ──
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
        androidParams: const a2c.AndroidParams(emailInvites: <String>[]),
      );
      final ok = await a2c.Add2Calendar.addEvent2Cal(entry);
      if (!context.mounted) return;
      AppSnackBar.info(context, ok ? 'events.openedInCalendar'.tr() : 'events.calendarNotOpened'.tr());
    } catch (err) {
      if (!context.mounted) return;
      AppSnackBar.error(context, 'events.error'.tr(namedArgs: {'error': '$err'}));
    }
  }

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

    String esc(String s) => s
        .replaceAll(r'\', r'\\')
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
      AppSnackBar.error(context, 'events.exportFailed'.tr());
    }
  }
}

// ──────────────────────────────────────────────────────────────────
// Hero
// ──────────────────────────────────────────────────────────────────
class _HeroBlock extends StatelessWidget {
  const _HeroBlock({
    required this.event,
    required this.accent,
    required this.scrollController,
  });
  final EventItem event;
  final Color accent;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (event.imageUrl == null || event.imageUrl!.isEmpty) {
      // Kein Hero-Image → Titel-Block mit Akzent
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          border: Border(bottom: BorderSide(color: accent, width: 2)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CategoryBadge(category: event.category, accent: accent),
            const SizedBox(height: 12),
            Text(
              event.title,
              style: AppTypography.display(
                size: 26,
                color: AppColors.ink,
                height: 1.2,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: accent, width: 2)),
      ),
      child: Stack(
        children: [
          // Cinema: Parallax-Hero (Bild scrollt langsamer) + Scrim.
          ParallaxImageHeader(
            scrollController: scrollController,
            height: 240,
            borderRadius: 0,
            child: PremiumImage(
              url: event.imageUrl,
              height: 240,
              width: double.infinity,
              borderRadius: BorderRadius.zero,
              bottomGradient: true,
              heroTag: 'event_cover_${event.id}',
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.60),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: _CategoryBadge(category: event.category, accent: accent),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: Text(
              event.title,
              style: AppTypography.display(
                size: 26,
                color: Colors.white,
                height: 1.2,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category, required this.accent});
  final String? category;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _categoryLabel(category),
        style: AppTypography.label(
          size: 10,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// Status-Pill
// ──────────────────────────────────────────────────────────────────
class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.label(size: 10, color: color),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// Date/Time/Location
// ──────────────────────────────────────────────────────────────────
class _DateTimeBlock extends StatelessWidget {
  const _DateTimeBlock({required this.event});
  final EventItem event;

  @override
  Widget build(BuildContext context) {
    String formattedDate;
    // UTC->Local: Events sind in DB als UTC gespeichert. Ohne .toLocal()
    // wird ein Berliner 19:00-Termin als 17:00 angezeigt (Sommerzeit).
    final localStart = event.startDate.toLocal();
    final localEnd = event.endDate?.toLocal();
    try {
      formattedDate =
          DateFormat('EEEE, dd. MMMM yyyy', context.locale.languageCode)
              .format(localStart);
    } catch (_) {
      formattedDate = DateFormat('EEEE, dd.MM.yyyy').format(localStart);
    }
    final timeStr = event.isAllDay
        ? null
        : '${DateFormat('HH:mm').format(localStart)}${localEnd != null ? " – ${DateFormat('HH:mm').format(localEnd)}" : ""}';
    final locationStr = [event.locationName, event.locationAddress]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.calendar,
                size: 14, color: AppColors.amber),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                formattedDate,
                style: AppTypography.body(
                  size: 14,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
        if (timeStr != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(LucideIcons.clock,
                  size: 14, color: AppColors.amber),
              const SizedBox(width: 8),
              Text(
                timeStr,
                style: AppTypography.body(
                  size: 14,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ],
        if (locationStr.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(LucideIcons.mapPin,
                    size: 14, color: AppColors.amber),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  locationStr,
                  style: AppTypography.body(
                    size: 13,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (event.isOnline &&
            event.onlineUrl != null &&
            event.onlineUrl!.isNotEmpty) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _openOnlineLink(context, event.onlineUrl!),
            icon: const Icon(LucideIcons.video, size: 16),
            label: Text('events.openOnlineLink'.tr()),
          ),
        ],
      ],
    );
  }

  /// Öffnet den Online-Link robust: normalisiert die URL (ergänzt https://
  /// falls Schema fehlt) und fängt Fehler ab statt still zu scheitern.
  Future<void> _openOnlineLink(BuildContext context, String raw) async {
    final messenger = ScaffoldMessenger.of(context);
    var url = raw.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.tryParse(url);
    var ok = false;
    if (uri != null) {
      try {
        ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        ok = false;
      }
    }
    if (!ok) {
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('events.linkOpenFailed'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.ink)),
      ));
    }
  }
}

// ──────────────────────────────────────────────────────────────────
// Author-Row
// ──────────────────────────────────────────────────────────────────
class _AuthorRow extends ConsumerWidget {
  const _AuthorRow({required this.authorId});
  final String authorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(_authorProfileProvider(authorId));
    final p = profileAsync.asData?.value;
    final name = p?.displayName ?? p?.name ?? p?.username ?? '—';
    final avatar = p?.avatarUrl;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push('/dashboard/profile/$authorId'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.elevated,
              backgroundImage:
                  (avatar != null && avatar.isNotEmpty)
                      ? CachedNetworkImageProvider(avatar, maxWidth: 128)
                      : null,
              child: (avatar == null || avatar.isEmpty)
                  ? const Icon(LucideIcons.user,
                      size: 14, color: AppColors.mute)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTypography.body(
                      size: 12,
                      color: AppColors.ink,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'events.organizer'.tr(),
                    style: AppTypography.caption(),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight,
                size: 14, color: AppColors.mute),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// Attendance-Block
// ──────────────────────────────────────────────────────────────────
class _AttendanceBlock extends StatelessWidget {
  const _AttendanceBlock({
    required this.event,
    required this.rsvp,
    required this.accent,
    required this.onOpenSheet,
  });
  final EventItem event;
  final String? rsvp;
  final Color accent;
  final VoidCallback? onOpenSheet;

  @override
  Widget build(BuildContext context) {
    if (rsvp == null) {
      return SizedBox(
        width: double.infinity,
        height: 60,
        child: FilledButton.icon(
          onPressed: onOpenSheet,
          icon: const Icon(LucideIcons.userPlus, size: 16),
          label: Text(
            'events.joinEvent'.tr(),
            style: AppTypography.body(
              size: 14,
              color: AppColors.voidColor,
              weight: FontWeight.w700,
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: AppColors.voidColor,
          ),
        ),
      );
    }
    final (icon, label, color) = _statusMeta(rsvp!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: AppTypography.body(
                size: 14,
                color: color,
                weight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            tooltip: 'events.attendanceSheet.title'.tr(),
            onPressed: onOpenSheet,
            icon: const Icon(LucideIcons.chevronDown,
                size: 18, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }

  (IconData, String, Color) _statusMeta(String s) {
    switch (s) {
      case 'going':
        return (
          LucideIcons.checkCircle,
          'events.attendStatus.going'.tr(),
          AppColors.leben
        );
      case 'interested':
      case 'maybe':
        return (
          LucideIcons.helpCircle,
          'events.attendStatus.interested'.tr(),
          AppColors.amber
        );
      case 'declined':
      default:
        return (
          LucideIcons.xCircle,
          'events.attendStatus.declined'.tr(),
          AppColors.mute
        );
    }
  }
}

class _AttendanceTile extends StatelessWidget {
  const _AttendanceTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.active,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        label,
        style: AppTypography.body(
          size: 14,
          color: AppColors.ink,
          weight: active ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      trailing: active
          ? const Icon(LucideIcons.check, size: 16, color: AppColors.amber)
          : null,
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// Skeleton-Loading
// ──────────────────────────────────────────────────────────────────
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(height: 240, width: double.infinity, borderRadius: 0),
          SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(height: 14, width: 220),
                SizedBox(height: 10),
                ShimmerBox(height: 12, width: 160),
                SizedBox(height: 8),
                ShimmerBox(height: 12, width: 200),
                SizedBox(height: 24),
                ShimmerBox(height: 48, borderRadius: 12),
                SizedBox(height: 10),
                ShimmerBox(height: 48, borderRadius: 12),
                SizedBox(height: 10),
                ShimmerBox(height: 48, borderRadius: 12),
                SizedBox(height: 10),
                ShimmerBox(height: 48, borderRadius: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── E2: Save (Bookmark) + lokale Reminder-Notification ───────────────
class _SavedToggleButton extends ConsumerStatefulWidget {
  const _SavedToggleButton({required this.event});
  final EventItem event;

  @override
  ConsumerState<_SavedToggleButton> createState() =>
      _SavedToggleButtonState();
}

class _SavedToggleButtonState extends ConsumerState<_SavedToggleButton> {
  bool _saved = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final v = await EventsRepository.isSaved(widget.event.id);
    if (!mounted) return;
    setState(() {
      _saved = v;
      _loading = false;
    });
  }

  Future<void> _tap() async {
    Haptics.tap();
    final wasSaved = _saved;
    final now = await EventsRepository.toggleSave(widget.event.id);
    if (!mounted) return;
    setState(() => _saved = now);
    if (wasSaved && !now) {
      await EventReminderService.cancel(widget.event.id);
    }
    if (!mounted) return;
    AppSnackBar.info(context, now ? 'events.saved'.tr() : 'events.unsaved'.tr());
  }

  Future<void> _longPress() async {
    Haptics.longPress();
    final mins = await showModalBottomSheet<int?>(
      context: context,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'events.reminderTitle'.tr(),
                style: AppTypography.body(
                  size: 15,
                  color: AppColors.ink,
                  weight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final m in const [15, 60, 360, 1440])
              ListTile(
                leading: const Icon(LucideIcons.bell, color: AppColors.amber),
                title: Text(
                  _reminderLabel(m),
                  style: AppTypography.body(size: 14, color: AppColors.ink),
                ),
                onTap: () => Navigator.pop(sheetCtx, m),
              ),
            ListTile(
              leading: const Icon(LucideIcons.bellOff, color: AppColors.mute),
              title: Text(
                'events.reminderNone'.tr(),
                style: AppTypography.body(size: 14, color: AppColors.inkSoft),
              ),
              onTap: () => Navigator.pop(sheetCtx, 0),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (mins == null || !mounted) return;
    if (!_saved) {
      final now = await EventsRepository.toggleSave(
        widget.event.id,
        reminderMinutesBefore: mins > 0 ? mins : null,
      );
      if (!mounted) return;
      setState(() => _saved = now);
    }
    if (mins == 0) {
      await EventReminderService.cancel(widget.event.id);
    } else {
      await EventReminderService.schedule(
        eventId: widget.event.id,
        eventStart: widget.event.startDate,
        minutesBefore: mins,
        title: widget.event.title,
      );
    }
    if (!mounted) return;
    AppSnackBar.info(context, mins == 0 ? 'events.reminderRemoved'.tr() : 'events.reminderSet' .tr(namedArgs: {'label': _reminderLabel(mins)}));
  }

  String _reminderLabel(int minutes) {
    if (minutes < 60) {
      return 'events.reminderMinutes'.tr(namedArgs: {'n': '$minutes'});
    }
    if (minutes < 1440) {
      return 'events.reminderHours'.tr(namedArgs: {'n': '${minutes ~/ 60}'});
    }
    return 'events.reminderDays'.tr(namedArgs: {'n': '${minutes ~/ 1440}'});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
          width: 48,
          height: 48,
          child: Center(
              child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.bronze))));
    }
    return GestureDetector(
      onLongPress: _longPress,
      child: IconButton(
        tooltip: _saved ? 'events.unsave'.tr() : 'events.save'.tr(),
        onPressed: _tap,
        icon: Icon(
          _saved ? LucideIcons.bookMarked : LucideIcons.bookmark,
          size: 20,
        ),
        color: _saved ? AppColors.amber : AppColors.bronze,
      ),
    );
  }
}

