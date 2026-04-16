import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/event_provider.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/models/event.dart';
import 'package:mensaena/widgets/avatar_widget.dart';
import 'package:mensaena/widgets/section_header.dart';
import 'package:mensaena/widgets/badge_widget.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  bool _attendanceLoading = false;
  List<Map<String, dynamic>> _attendees = [];
  bool _attendeesLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAttendees();
  }

  Future<void> _loadAttendees() async {
    try {
      final service = ref.read(eventServiceProvider);
      final attendees = await service.getAttendees(widget.eventId);
      if (mounted) {
        setState(() {
          _attendees = attendees;
          _attendeesLoaded = true;
        });
      }
    } catch (_) {
      // Stille Fehlerbehandlung
    }
  }

  Future<void> _setAttendance(String status) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bitte zuerst anmelden')),
        );
      }
      return;
    }

    setState(() => _attendanceLoading = true);
    try {
      final service = ref.read(eventServiceProvider);
      await service.setAttendance(widget.eventId, userId, status);
      ref.invalidate(eventDetailProvider(widget.eventId));
      await _loadAttendees();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _attendanceLoading = false);
    }
  }

  Future<void> _removeAttendance() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    setState(() => _attendanceLoading = true);
    try {
      final service = ref.read(eventServiceProvider);
      await service.removeAttendance(widget.eventId, userId);
      ref.invalidate(eventDetailProvider(widget.eventId));
      await _loadAttendees();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _attendanceLoading = false);
    }
  }

  String _formatEventDate(Event event) {
    final df = DateFormat('EEEE, d. MMMM yyyy', 'de_DE');
    final tf = DateFormat('HH:mm', 'de_DE');

    if (event.isAllDay) {
      if (event.endDate != null &&
          event.endDate!.day != event.startDate.day) {
        final dfShort = DateFormat('d. MMM', 'de_DE');
        return '${dfShort.format(event.startDate)} – ${dfShort.format(event.endDate!)} ${event.startDate.year} · Ganztaegig';
      }
      return '${df.format(event.startDate)} · Ganztaegig';
    }

    final startTime = tf.format(event.startDate);
    if (event.endDate != null) {
      final endTime = tf.format(event.endDate!);
      if (event.endDate!.day != event.startDate.day) {
        final dfShort = DateFormat('d. MMM', 'de_DE');
        return '${dfShort.format(event.startDate)}, $startTime – ${dfShort.format(event.endDate!)}, $endTime Uhr';
      }
      return '${df.format(event.startDate)} · $startTime – $endTime Uhr';
    }

    return '${df.format(event.startDate)} · $startTime Uhr';
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventDetailProvider(widget.eventId));
    final currentUserId = ref.watch(currentUserIdProvider);

    return Scaffold(
      body: eventAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text('Fehler beim Laden', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              )),
              const SizedBox(height: 4),
              Text('$e', style: const TextStyle(
                fontSize: 13, color: AppColors.textMuted,
              )),
            ],
          ),
        ),
        data: (event) {
          if (event == null) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_busy, size: 64, color: AppColors.textMuted),
                    SizedBox(height: 16),
                    Text('Event nicht gefunden',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            );
          }

          // Determine user attendance from attendees list
          String? myAttendance = event.myAttendance;
          if (myAttendance == null && currentUserId != null && _attendeesLoaded) {
            for (final a in _attendees) {
              if (a['user_id'] == currentUserId) {
                myAttendance = a['status'] as String?;
                break;
              }
            }
          }

          final catConfig = event.categoryConfig;
          final authorName = event.profile?['name'] as String? ??
              event.profile?['display_name'] as String? ??
              'Unbekannt';
          final authorAvatar = event.profile?['avatar_url'] as String?;

          final goingCount = _attendees
              .where((a) => a['status'] == 'going')
              .length;
          final interestedCount = _attendees
              .where((a) => a['status'] == 'interested')
              .length;

          return CustomScrollView(
            slivers: [
              // -- Header / Hero Image --
              SliverAppBar(
                expandedHeight: event.imageUrl != null ? 250 : 0,
                pinned: true,
                title: Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share_outlined),
                    tooltip: 'Teilen',
                    onPressed: () {
                      Share.share(
                        '${event.title} – ${_formatEventDate(event)}',
                        subject: event.title,
                      );
                    },
                  ),
                ],
                flexibleSpace: event.imageUrl != null
                    ? FlexibleSpaceBar(
                        background: CachedNetworkImage(
                          imageUrl: event.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: AppColors.primary50,
                            child: const Center(
                              child: Icon(Icons.event, size: 48, color: AppColors.primary300),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.primary50,
                            child: const Center(
                              child: Icon(Icons.event, size: 48, color: AppColors.primary300),
                            ),
                          ),
                        ),
                      )
                    : null,
              ),

              // -- Content --
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Kategorie-Badge & Status
                      Row(
                        children: [
                          AppBadge(
                            label: '${catConfig.emoji} ${catConfig.label}',
                            color: AppColors.primary500,
                          ),
                          const SizedBox(width: 8),
                          if (event.isRecurring)
                            const AppBadge(
                              label: '🔄 Wiederkehrend',
                              color: AppColors.info,
                              small: true,
                            ),
                          if (event.isPast)
                            const AppBadge(
                              label: 'Vergangen',
                              color: AppColors.textMuted,
                              small: true,
                            ),
                          if (event.isFull) ...[
                            const SizedBox(width: 8),
                            const AppBadge(
                              label: 'Ausgebucht',
                              color: AppColors.warning,
                              small: true,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Titel
                      Text(
                        event.title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Datum & Uhrzeit
                      _DetailInfoCard(
                        icon: Icons.calendar_today_outlined,
                        iconColor: AppColors.primary500,
                        title: 'Datum & Uhrzeit',
                        content: _formatEventDate(event),
                      ),
                      const SizedBox(height: 10),

                      // Ort
                      if (event.locationDisplay.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _DetailInfoCard(
                            icon: Icons.location_on_outlined,
                            iconColor: AppColors.emergency,
                            title: 'Ort',
                            content: event.locationDisplay,
                          ),
                        ),

                      // Teilnehmer
                      _DetailInfoCard(
                        icon: Icons.people_outline,
                        iconColor: AppColors.trust,
                        title: 'Teilnehmer',
                        content: _buildAttendeeText(
                          goingCount: _attendeesLoaded ? goingCount : event.attendeeCount,
                          interestedCount: _attendeesLoaded ? interestedCount : 0,
                          maxAttendees: event.maxAttendees,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Kosten
                      _DetailInfoCard(
                        icon: Icons.euro_outlined,
                        iconColor: AppColors.success,
                        title: 'Kosten',
                        content: event.isFree ? 'Kostenlos' : (event.cost ?? 'Kostenlos'),
                      ),
                      const SizedBox(height: 20),

                      // -- Teilnahme-Buttons --
                      if (!event.isPast) ...[
                        const SectionHeader(
                          title: 'Teilnahme',
                          icon: Icons.how_to_reg_outlined,
                        ),
                        const SizedBox(height: 8),
                        _AttendanceButtons(
                          currentStatus: myAttendance,
                          isLoading: _attendanceLoading,
                          isFull: event.isFull,
                          onSetAttendance: _setAttendance,
                          onRemoveAttendance: _removeAttendance,
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Beschreibung
                      if (event.description != null &&
                          event.description!.isNotEmpty) ...[
                        const SectionHeader(
                          title: 'Beschreibung',
                          icon: Icons.description_outlined,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            event.description!,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.6,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Was mitbringen
                      if (event.whatToBring != null &&
                          event.whatToBring!.isNotEmpty) ...[
                        const SectionHeader(
                          title: 'Was mitbringen?',
                          icon: Icons.backpack_outlined,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF9E6),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.warning.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.lightbulb_outline,
                                  size: 20, color: AppColors.warning),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  event.whatToBring!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Kontaktinfo
                      if (event.contactInfo != null &&
                          event.contactInfo!.isNotEmpty) ...[
                        const SectionHeader(
                          title: 'Kontakt',
                          icon: Icons.contact_mail_outlined,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline,
                                  size: 20, color: AppColors.info),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  event.contactInfo!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Teilnehmerliste
                      if (_attendeesLoaded && _attendees.isNotEmpty) ...[
                        SectionHeader(
                          title: 'Teilnehmerliste (${_attendees.length})',
                          icon: Icons.group_outlined,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: _attendees.map((attendee) {
                              final profile = attendee['profiles']
                                  as Map<String, dynamic>?;
                              final name = profile?['name'] as String? ??
                                  profile?['nickname'] as String? ??
                                  'Unbekannt';
                              final avatar =
                                  profile?['avatar_url'] as String?;
                              final status = attendee['status'] as String?;

                              return ListTile(
                                leading: AvatarWidget(
                                  imageUrl: avatar,
                                  name: name,
                                  size: 36,
                                ),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                trailing: _attendanceStatusChip(status),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Ersteller
                      const SectionHeader(
                        title: 'Erstellt von',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            AvatarWidget(
                              imageUrl: authorAvatar,
                              name: authorName,
                              size: 44,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    authorName,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Erstellt ${timeago.format(event.createdAt, locale: 'de')}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_ios,
                                  size: 16, color: AppColors.textMuted),
                              onPressed: () {
                                // Navigation zum Profil
                              },
                              tooltip: 'Profil anzeigen',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _buildAttendeeText({
    required int goingCount,
    required int interestedCount,
    int? maxAttendees,
  }) {
    final parts = <String>[];
    parts.add('$goingCount Zusage${goingCount != 1 ? 'n' : ''}');
    if (interestedCount > 0) {
      parts.add('$interestedCount interessiert');
    }
    if (maxAttendees != null) {
      parts.add('(max. $maxAttendees)');
    }
    return parts.join(' · ');
  }

  Widget _attendanceStatusChip(String? status) {
    switch (status) {
      case 'going':
        return const AppBadge(
          label: 'Dabei',
          color: AppColors.success,
          small: true,
        );
      case 'interested':
        return const AppBadge(
          label: 'Interessiert',
          color: AppColors.info,
          small: true,
        );
      case 'declined':
        return const AppBadge(
          label: 'Abgesagt',
          color: AppColors.textMuted,
          small: true,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// -- Teilnahme-Buttons --
class _AttendanceButtons extends StatelessWidget {
  final String? currentStatus;
  final bool isLoading;
  final bool isFull;
  final Future<void> Function(String status) onSetAttendance;
  final Future<void> Function() onRemoveAttendance;

  const _AttendanceButtons({
    required this.currentStatus,
    required this.isLoading,
    required this.isFull,
    required this.onSetAttendance,
    required this.onRemoveAttendance,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Zusagen
        Expanded(
          child: _AttendanceBtn(
            label: 'Zusagen',
            icon: Icons.check_circle_outline,
            isSelected: currentStatus == 'going',
            isLoading: isLoading,
            isDisabled: isFull && currentStatus != 'going',
            selectedColor: AppColors.success,
            onTap: () {
              if (currentStatus == 'going') {
                onRemoveAttendance();
              } else {
                onSetAttendance('going');
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        // Interessiert
        Expanded(
          child: _AttendanceBtn(
            label: 'Interessiert',
            icon: Icons.star_outline,
            isSelected: currentStatus == 'interested',
            isLoading: isLoading,
            selectedColor: AppColors.info,
            onTap: () {
              if (currentStatus == 'interested') {
                onRemoveAttendance();
              } else {
                onSetAttendance('interested');
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        // Absagen
        Expanded(
          child: _AttendanceBtn(
            label: 'Absagen',
            icon: Icons.close,
            isSelected: currentStatus == 'declined',
            isLoading: isLoading,
            selectedColor: AppColors.textMuted,
            onTap: () {
              if (currentStatus == 'declined') {
                onRemoveAttendance();
              } else {
                onSetAttendance('declined');
              }
            },
          ),
        ),
      ],
    );
  }
}

class _AttendanceBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isLoading;
  final bool isDisabled;
  final Color selectedColor;
  final VoidCallback onTap;

  const _AttendanceBtn({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isLoading,
    this.isDisabled = false,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading || isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? selectedColor.withValues(alpha: 0.1)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? selectedColor
                  : isDisabled
                      ? AppColors.border.withValues(alpha: 0.5)
                      : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              if (isLoading)
                SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: selectedColor,
                  ),
                )
              else
                Icon(
                  isSelected ? Icons.check_circle : icon,
                  size: 20,
                  color: isSelected
                      ? selectedColor
                      : isDisabled
                          ? AppColors.textMuted.withValues(alpha: 0.5)
                          : AppColors.textSecondary,
                ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? selectedColor
                      : isDisabled
                          ? AppColors.textMuted.withValues(alpha: 0.5)
                          : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -- Info-Karte --
class _DetailInfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String content;

  const _DetailInfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}