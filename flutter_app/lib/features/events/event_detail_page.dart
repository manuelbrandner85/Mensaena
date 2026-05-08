import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      if (!mounted) return;
      setState(() {
        _event = event;
        _myStatus = my[event.id];
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
        const SizedBox(height: 16),
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
