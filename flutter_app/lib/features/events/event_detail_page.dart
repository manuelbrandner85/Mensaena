import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_colors.dart';
import 'events_repository.dart';
import 'models.dart';

class EventDetailPage extends ConsumerStatefulWidget {
  const EventDetailPage({super.key, required this.eventId});
  final String eventId;

  @override
  ConsumerState<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends ConsumerState<EventDetailPage> {
  EventItem? _event;
  AttendeeStatus? _myStatus;
  List<EventAttendee> _attendeesPreview = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(eventsRepositoryProvider);
      final event = await repo.fetch(widget.eventId);
      if (event == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Event nicht gefunden';
          _loading = false;
        });
        return;
      }
      final my = await repo.myAttendances();
      List<EventAttendee> preview = const [];
      try {
        preview = await repo.attendees(event.id, limit: 12);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _event = event;
        _myStatus = my[event.id];
        _attendeesPreview =
            preview.where((a) => a.status == AttendeeStatus.going).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _setStatus(AttendeeStatus? status) async {
    final event = _event;
    if (event == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      final repo = ref.read(eventsRepositoryProvider);
      if (status == null) {
        await repo.withdrawAttendance(event.id);
      } else {
        await repo.setAttendance(event.id, status);
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _launch(String uri) async {
    final url = Uri.parse(uri);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_event?.title ?? 'Event')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildBody(_event!),
    );
  }

  Widget _buildBody(EventItem e) {
    final cat = e.categoryConfig;
    final dateFmt = DateFormat('EEEE, d. MMMM yyyy · HH:mm', 'de');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (e.imageUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              e.imageUrl!,
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: cat.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${cat.emoji} ${cat.label}',
            style: TextStyle(
              color: cat.color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          e.title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        _Countdown(target: e.startDate),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _meta(
                Icons.event_outlined,
                'Wann',
                e.isAllDay
                    ? 'Ganztägig · ${DateFormat('d. MMM yyyy', 'de').format(e.startDate)}'
                    : dateFmt.format(e.startDate),
              ),
              if (e.isOnline)
                _meta(
                  Icons.videocam_outlined,
                  'Online',
                  e.onlineUrl ?? 'Link kommt vor dem Event',
                  onTap: e.onlineUrl != null ? () => _launch(e.onlineUrl!) : null,
                )
              else if (e.locationName != null || e.locationAddress != null)
                _meta(
                  Icons.location_on_outlined,
                  'Ort',
                  [e.locationName, e.locationAddress].whereType<String>().join(', '),
                  onTap: e.locationAddress != null
                      ? () => _launch(
                            'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(e.locationAddress!)}',
                          )
                      : null,
                ),
              if (e.cost != null)
                _meta(Icons.euro_outlined, 'Kosten', e.cost!),
              _meta(
                Icons.people_outline,
                'Teilnehmer',
                e.maxAttendees != null
                    ? '${e.attendeeCount} / ${e.maxAttendees}'
                    : '${e.attendeeCount}',
              ),
            ],
          ),
        ),
        if ((e.description ?? '').isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            e.description!,
            style: const TextStyle(fontSize: 14, height: 1.6),
          ),
        ],
        if (_attendeesPreview.isNotEmpty) ...[
          const SizedBox(height: 24),
          _AttendeesPreview(
            attendees: _attendeesPreview,
            totalCount: e.attendeeCount,
            onSeeAll: () =>
                context.go('/dashboard/events/${e.id}/attendees'),
          ),
        ],
        const SizedBox(height: 24),
        // RSVP buttons
        Row(
          children: [
            for (final s in AttendeeStatus.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: SizedBox(
                    height: 44,
                    child: _myStatus == s
                        ? FilledButton(
                            onPressed: _busy ? null : () => _setStatus(null),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary500,
                            ),
                            child: Text(s.label),
                          )
                        : OutlinedButton(
                            onPressed: _busy ? null : () => _setStatus(s),
                            child: Text(
                              s.label,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _meta(IconData icon, String label, String value, {VoidCallback? onTap}) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.ink400),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.ink400, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: onTap != null ? FontWeight.w600 : FontWeight.w400,
                color: onTap != null ? AppColors.primary500 : AppColors.ink700,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

class _AttendeesPreview extends StatelessWidget {
  const _AttendeesPreview({
    required this.attendees,
    required this.totalCount,
    required this.onSeeAll,
  });
  final List<EventAttendee> attendees;
  final int totalCount;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final preview = attendees.take(6).toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Teilnehmer',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (totalCount > preview.length)
                TextButton(
                  onPressed: onSeeAll,
                  child: Text('Alle ($totalCount)'),
                )
              else
                TextButton(
                  onPressed: onSeeAll,
                  child: const Text('Liste anzeigen'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: preview.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final a = preview[i];
                final initial = (a.name ?? '?').isNotEmpty
                    ? a.name![0].toUpperCase()
                    : '?';
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          AppColors.primary500.withValues(alpha: 0.18),
                      backgroundImage: a.avatarUrl != null
                          ? NetworkImage(a.avatarUrl!)
                          : null,
                      child: a.avatarUrl == null
                          ? Text(
                              initial,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary700,
                                fontSize: 13,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 56,
                      child: Text(
                        a.name ?? '—',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.ink700,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Countdown extends StatefulWidget {
  const _Countdown({required this.target});
  final DateTime target;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diff = widget.target.difference(_now);
    final past = diff.isNegative;
    final d = diff.abs();
    final days = d.inDays;
    final hours = d.inHours.remainder(24);
    final minutes = d.inMinutes.remainder(60);

    String label;
    Color accent;
    IconData icon;
    if (past) {
      label = 'Hat begonnen';
      accent = AppColors.stone400;
      icon = Icons.event_busy_outlined;
    } else if (days > 1) {
      label = 'Beginnt in $days Tagen, $hours Std';
      accent = AppColors.primary500;
      icon = Icons.event_outlined;
    } else if (days == 1) {
      label = 'Morgen, in $hours Std';
      accent = AppColors.primary500;
      icon = Icons.event_outlined;
    } else if (hours >= 1) {
      label = 'Heute, in $hours Std $minutes Min';
      accent = const Color(0xFFD97706);
      icon = Icons.timer_outlined;
    } else if (minutes > 0) {
      label = 'In $minutes Min – fast los';
      accent = AppColors.emergency500;
      icon = Icons.bolt;
    } else {
      label = 'Beginnt jetzt!';
      accent = AppColors.emergency500;
      icon = Icons.bolt;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: accent,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
