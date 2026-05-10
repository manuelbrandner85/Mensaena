import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/holidays.dart';
import '../../routing/routes.dart';
import '../../theme/app_colors.dart';
import '../../widgets/page_chrome.dart';
import '../../widgets/realtime_feed.dart';
import '../../widgets/weather_forecast_strip.dart';
import 'event_calendar_view.dart';
import 'event_map_view.dart';
import 'events_repository.dart';
import 'models.dart';

enum _EventViewMode { list, calendar, map }

class EventsPage extends ConsumerStatefulWidget {
  const EventsPage({super.key});

  @override
  ConsumerState<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends ConsumerState<EventsPage>
    with RealtimeFeedMixin {
  List<EventItem> _events = [];
  Map<String, AttendeeStatus> _attendances = const {};
  bool _loading = true;
  String _category = 'all';
  _EventViewMode _viewMode = _EventViewMode.list;
  double? _userLat;
  double? _userLng;
  BundeslandCode _bundesland = BundeslandCode.national;

  @override
  String get realtimeChannelName => 'events-feed-realtime';

  @override
  List<FeedRealtimeRule> get realtimeRules => const [
        FeedRealtimeRule(
          event: PostgresChangeEvent.insert,
          table: 'events',
          action: FeedRealtimeAction.bumpNewCount,
        ),
        FeedRealtimeRule(
          event: PostgresChangeEvent.update,
          table: 'events',
          action: FeedRealtimeAction.reloadImmediately,
        ),
        FeedRealtimeRule(
          event: PostgresChangeEvent.insert,
          table: 'event_attendees',
          action: FeedRealtimeAction.reloadImmediately,
        ),
        FeedRealtimeRule(
          event: PostgresChangeEvent.delete,
          table: 'event_attendees',
          action: FeedRealtimeAction.reloadImmediately,
        ),
      ];

  @override
  Future<void> reloadFeed() => _load();

  @override
  void initState() {
    super.initState();
    _load();
    _loadUserGeo();
    subscribeRealtime();
  }

  Future<void> _loadUserGeo() async {
    try {
      final db = ref.read(supabaseProvider);
      final user = db.auth.currentUser;
      if (user == null) return;
      final row = await db
          .from('profiles')
          .select('latitude, longitude, postal_code')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted || row == null) return;
      final lat = (row['latitude'] as num?)?.toDouble();
      final lng = (row['longitude'] as num?)?.toDouble();
      final plz = row['postal_code'] as String?;
      setState(() {
        _userLat = lat;
        _userLng = lng;
        if (plz != null && plz.isNotEmpty) {
          _bundesland = plzToBundesland(plz);
        } else if (lat != null && lng != null) {
          _bundesland = coordsToBundesland(lat, lng);
        }
      });
    } catch (_) {}
  }

  void _showNewItems() {
    resetNewItemCount();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(eventsRepositoryProvider);
      final list = await repo.upcoming(category: _category);
      final my = await repo.myAttendances();
      if (!mounted) return;
      setState(() {
        _events = list;
        _attendances = my;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Veranstaltungen'),
        actions: [
          PopupMenuButton<_EventViewMode>(
            tooltip: 'Ansicht wechseln',
            icon: Icon(_viewIcon(_viewMode)),
            onSelected: (m) => setState(() => _viewMode = m),
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: _EventViewMode.list,
                checked: _viewMode == _EventViewMode.list,
                child: const Text('Liste'),
              ),
              CheckedPopupMenuItem(
                value: _EventViewMode.calendar,
                checked: _viewMode == _EventViewMode.calendar,
                child: const Text('Kalender'),
              ),
              CheckedPopupMenuItem(
                value: _EventViewMode.map,
                checked: _viewMode == _EventViewMode.map,
                child: const Text('Karte'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Event erstellen',
            onPressed: () => context.go(Routes.dashboardEventsCreate),
          ),
        ],
      ),
      body: Column(
        children: [
          const HeroHeader(
            metaLabel: 'Events',
            title: 'Events in deiner Nachbarschaft',
            subtitle:
                'Treffen, Workshops, Sport — finde was zu dir passt oder organisiere selbst.',
            icon: Icons.event,
          ),
          if (_userLat != null && _userLng != null) ...[
            WeatherForecastStrip(
              latitude: _userLat,
              longitude: _userLng,
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _Chip(
                  label: 'Alle',
                  selected: _category == 'all',
                  onTap: () {
                    setState(() => _category = 'all');
                    _load();
                  },
                ),
                ...EventCategory.all.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _Chip(
                      label: '${c.emoji} ${c.label}',
                      selected: _category == c.value,
                      color: c.color,
                      onTap: () {
                        setState(() => _category = c.value);
                        _load();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          NewItemsBanner(
            count: newItemCount,
            singularLabel: 'Event',
            pluralLabel: 'Events',
            onTap: _showNewItems,
            icon: Icons.event,
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_events.isEmpty && _viewMode == _EventViewMode.list) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Keine bevorstehenden Events',
            style: TextStyle(color: AppColors.ink400),
          ),
        ),
      );
    }
    switch (_viewMode) {
      case _EventViewMode.list:
        return RefreshIndicator(
          onRefresh: _load,
          child: _GroupedList(
            events: _events,
            attendances: _attendances,
          ),
        );
      case _EventViewMode.calendar:
        return EventCalendarView(
          events: _events,
          attendances: _attendances,
          bundesland: _bundesland,
          onAttend: (id, status) async {
            // Calendar-Sheet hat eigene Buttons; Re-load nach Aktion.
            await _load();
            return true;
          },
          onRemove: (id) {
            _load();
          },
          eventTileBuilder: (event, my) =>
              _EventTile(event: event, myStatus: my),
        );
      case _EventViewMode.map:
        return EventMapView(events: _events);
    }
  }

  IconData _viewIcon(_EventViewMode mode) {
    switch (mode) {
      case _EventViewMode.list:
        return Icons.list_alt;
      case _EventViewMode.calendar:
        return Icons.calendar_month_outlined;
      case _EventViewMode.map:
        return Icons.map_outlined;
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.primary500;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: accent.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: selected ? accent : AppColors.ink700,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        fontSize: 12,
      ),
    );
  }
}

class _GroupedList extends StatelessWidget {
  const _GroupedList({required this.events, required this.attendances});
  final List<EventItem> events;
  final Map<String, AttendeeStatus> attendances;

  @override
  Widget build(BuildContext context) {
    final byDate = <String, List<EventItem>>{};
    final fmt = DateFormat('EEEE, d. MMMM', 'de');
    for (final e in events) {
      final key = fmt.format(e.startDate);
      byDate.putIfAbsent(key, () => []).add(e);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: byDate.length,
      itemBuilder: (_, i) {
        final entry = byDate.entries.elementAt(i);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                entry.key,
                style: const TextStyle(
                  color: AppColors.ink400,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            ...entry.value.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _EventTile(
                  event: e,
                  myStatus: attendances[e.id],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, this.myStatus});
  final EventItem event;
  final AttendeeStatus? myStatus;

  @override
  Widget build(BuildContext context) {
    final cat = event.categoryConfig;
    final time = event.isAllDay
        ? 'Ganztägig'
        : DateFormat('HH:mm').format(event.startDate);
    final loc = event.isOnline
        ? 'Online'
        : (event.locationName ?? event.locationAddress ?? 'Vor Ort');
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => context.go('${Routes.dashboardEvents}/${event.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: cat.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(cat.emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(height: 2),
                    Text(
                      time,
                      style: TextStyle(
                        color: cat.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cat.label,
                      style: TextStyle(
                        color: cat.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          event.isOnline
                              ? Icons.videocam_outlined
                              : Icons.location_on_outlined,
                          size: 12,
                          color: AppColors.ink400,
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            loc,
                            style: const TextStyle(
                              color: AppColors.ink400,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.people_outline, size: 12, color: AppColors.ink400),
                        const SizedBox(width: 2),
                        Text(
                          '${event.attendeeCount}',
                          style: const TextStyle(
                            color: AppColors.ink400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (myStatus != null) ...[
                const SizedBox(width: 6),
                _StatusBadge(status: myStatus!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final AttendeeStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AttendeeStatus.going => AppColors.primary500,
      AttendeeStatus.maybe => const Color(0xFFD97706),
      AttendeeStatus.notGoing => const Color(0xFF64748B),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
