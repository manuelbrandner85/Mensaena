import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../routing/routes.dart';
import '../../theme/app_colors.dart';
import 'events_repository.dart';
import 'models.dart';

/// /dashboard/events/:id/attendees — Pendant zu EventAttendees.tsx.
class EventAttendeesPage extends ConsumerStatefulWidget {
  const EventAttendeesPage({super.key, required this.eventId});
  final String eventId;

  @override
  ConsumerState<EventAttendeesPage> createState() =>
      _EventAttendeesPageState();
}

class _EventAttendeesPageState extends ConsumerState<EventAttendeesPage> {
  bool _loading = true;
  String? _error;
  List<EventAttendee> _attendees = const [];
  AttendeeStatus _filter = AttendeeStatus.going;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await ref
          .read(eventsRepositoryProvider)
          .attendees(widget.eventId, limit: 200);
      if (!mounted) return;
      setState(() {
        _attendees = list;
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

  @override
  Widget build(BuildContext context) {
    final filtered =
        _attendees.where((a) => a.status == _filter).toList(growable: false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Teilnehmer')),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: AttendeeStatus.values.map((s) {
                final count =
                    _attendees.where((a) => a.status == s).length;
                final selected = _filter == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    selected: selected,
                    onSelected: (_) => setState(() => _filter = s),
                    label: Text('${s.label} · $count'),
                    selectedColor:
                        AppColors.primary500.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected
                          ? AppColors.primary500
                          : AppColors.ink700,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : filtered.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text(
                                'Niemand in dieser Kategorie',
                                style: TextStyle(color: AppColors.ink400),
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1, indent: 76),
                              itemBuilder: (_, i) {
                                final a = filtered[i];
                                return _AttendeeTile(attendee: a);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _AttendeeTile extends StatelessWidget {
  const _AttendeeTile({required this.attendee});
  final EventAttendee attendee;

  @override
  Widget build(BuildContext context) {
    final initial = (attendee.name ?? '?').isNotEmpty
        ? attendee.name![0].toUpperCase()
        : '?';
    return ListTile(
      onTap: () => context.go('${Routes.dashboardProfile}/${attendee.userId}'),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.primary500.withValues(alpha: 0.18),
        backgroundImage: attendee.avatarUrl != null
            ? NetworkImage(attendee.avatarUrl!)
            : null,
        child: attendee.avatarUrl == null
            ? Text(
                initial,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary700,
                ),
              )
            : null,
      ),
      title: Text(
        attendee.name ?? 'Unbekannt',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
