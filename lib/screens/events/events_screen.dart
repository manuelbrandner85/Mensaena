import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shimmer/shimmer.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/event_provider.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/models/event.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mensaena/widgets/empty_state.dart';
import 'package:mensaena/widgets/editorial_header.dart';

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});
  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  String? _selectedCategory;
  String _view = 'list';
  String _search = '';
  DateTime _monthCursor = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? _selectedDay;
  RealtimeChannel? _channel;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _channel = Supabase.instance.client.channel('events-realtime')
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'events',
          callback: (_) { if (mounted) ref.invalidate(eventsProvider); })
        .subscribe();
  }

  @override
  void dispose() { _channel?.unsubscribe(); super.dispose(); }

  static const _categories = [
    (value: null, label: 'Alle', emoji: '📋'),
    (value: 'meetup', label: 'Treffen', emoji: '👥'),
    (value: 'workshop', label: 'Workshop', emoji: '🎓'),
    (value: 'sport', label: 'Sport', emoji: '🏃'),
    (value: 'food', label: 'Essen', emoji: '🍽️'),
    (value: 'market', label: 'Markt', emoji: '🛍️'),
    (value: 'culture', label: 'Kultur', emoji: '🎵'),
    (value: 'kids', label: 'Kinder', emoji: '👶'),
    (value: 'seniors', label: 'Senioren', emoji: '❤️'),
    (value: 'cleanup', label: 'Aufräumaktion', emoji: '♻️'),
  ];

  List<Event> _applyFilters(List<Event> list) {
    var filtered = list;
    if (_selectedCategory != null) {
      filtered = filtered.where((e) => e.category == _selectedCategory).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      filtered = filtered.where((e) =>
          e.title.toLowerCase().contains(q) ||
          (e.description?.toLowerCase().contains(q) ?? false) ||
          e.locationDisplay.toLowerCase().contains(q)).toList();
    }
    return filtered;
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    ref.invalidate(eventsProvider);
    await ref.read(eventsProvider.future);
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final events = ref.watch(eventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('§ 05 · Termine'),
        actions: [
          IconButton(
            onPressed: _refreshing ? null : _refresh,
            icon: _refreshing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh, size: 22),
            tooltip: 'Aktualisieren',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'list', icon: Icon(Icons.list), label: Text('Liste')),
                ButtonSegment(value: 'calendar', icon: Icon(Icons.calendar_today), label: Text('Kalender')),
                ButtonSegment(value: 'map', icon: Icon(Icons.map), label: Text('Karte')),
              ],
              selected: {_view},
              onSelectionChanged: (v) => setState(() => _view = v.first),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final c = _categories[i];
                final sel = _selectedCategory == c.value;
                return FilterChip(
                  label: Text('${c.emoji} ${c.label}', style: TextStyle(fontSize: 11, color: sel ? Colors.white : AppColors.textSecondary)),
                  selected: sel, selectedColor: AppColors.primary500,
                  onSelected: (_) => setState(() => _selectedCategory = c.value),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: EditorialHeader(
              section: 'Veranstaltungen',
              number: '05',
              title: 'Events & Treffen',
              subtitle: 'Entdecke was in deiner Nachbarschaft passiert',
              icon: Icons.event_outlined,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Events suchen...',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (v) => setState(() => _search = v.trim()),
            ),
          ),
          Expanded(
            child: events.when(
              loading: () => const _EventSkeleton(),
              error: (e, _) => Center(child: Text('Fehler: $e')),
              data: (list) {
                final filtered = _applyFilters(list);
                switch (_view) {
                  case 'calendar':
                    return RefreshIndicator(
                      onRefresh: _refresh,
                      child: _CalendarView(
                        monthCursor: _monthCursor,
                        selectedDay: _selectedDay,
                        events: filtered,
                        onMonth: (d) => setState(() => _monthCursor = d),
                        onDay: (d) => setState(() => _selectedDay = d),
                      ),
                    );
                  case 'map':
                    return _MapView(events: filtered);
                  case 'list':
                  default:
                    if (filtered.isEmpty) {
                      return const EmptyState(icon: Icons.event_outlined, title: 'Keine Events', message: 'Erstelle das erste Event!');
                    }
                    return RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _EventCard(
                          event: filtered[i],
                          onTap: () => context.push('/dashboard/events/${filtered[i].id}'),
                        ),
                      ),
                    );
                }
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/dashboard/events/create'),
        icon: const Icon(Icons.add),
        label: const Text('Event erstellen'),
      ),
    );
  }
}

class _EventSkeleton extends StatelessWidget {
  const _EventSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.border,
      highlightColor: AppColors.background,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: 4,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 90,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _EventCard extends ConsumerWidget {
  final Event event;
  final VoidCallback onTap;
  const _EventCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catConfig = EventCategoryConfig.fromString(event.category);
    final userId = ref.watch(currentUserIdProvider);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(DateFormat('dd').format(event.startDate), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary700)),
                    Text(DateFormat('MMM', 'de').format(event.startDate), style: const TextStyle(fontSize: 11, color: AppColors.primary500)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(catConfig.emoji, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(event.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    if (event.locationDisplay.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Expanded(child: Text(event.locationDisplay, style: const TextStyle(fontSize: 11, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ]),
                    ],
                    if (!event.isAllDay) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.access_time, size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Text(DateFormat('HH:mm', 'de').format(event.startDate), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        if (event.cost != null && event.cost != 'kostenlos') ...[
                          const SizedBox(width: 10),
                          Text(event.cost!, style: const TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w500)),
                        ],
                      ]),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _AttendanceControl(event: event, userId: userId),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceControl extends ConsumerWidget {
  final Event event;
  final String? userId;
  const _AttendanceControl({required this.event, required this.userId});

  Future<void> _setStatus(WidgetRef ref, BuildContext context, String status) async {
    if (userId == null) return;
    await ref.read(eventServiceProvider).setAttendance(event.id, userId!, status);
    ref.invalidate(eventsProvider);
    if (!context.mounted) return;
    final msg = switch (status) {
      'going' => 'Du nimmst teil!',
      'interested' => 'Als interessiert markiert',
      _ => 'Absage eingetragen',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  Future<void> _remove(WidgetRef ref) async {
    if (userId == null) return;
    await ref.read(eventServiceProvider).removeAttendance(event.id, userId!);
    ref.invalidate(eventsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = event.myAttendance;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${event.attendeeCount}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const Text('Teilnehmer', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
        const SizedBox(height: 4),
        if (status == 'going') ...[
          SizedBox(
            width: 96, height: 26,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, foregroundColor: AppColors.success),
              onPressed: () => _remove(ref),
              child: const Text('✓ Dabei', style: TextStyle(fontSize: 10)),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 96, height: 22,
            child: TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
              onPressed: () => _setStatus(ref, context, 'interested'),
              child: const Text('Interessiert?', style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
            ),
          ),
        ] else if (status == 'interested') ...[
          SizedBox(
            width: 96, height: 26,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, foregroundColor: AppColors.warning),
              onPressed: () => _setStatus(ref, context, 'going'),
              child: const Text('⭐ Interesse', style: TextStyle(fontSize: 10)),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 96, height: 22,
            child: TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
              onPressed: () => _remove(ref),
              child: const Text('Absagen', style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
            ),
          ),
        ] else ...[
          SizedBox(
            width: 96, height: 26,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
              onPressed: userId == null ? null : () => _setStatus(ref, context, 'going'),
              child: const Text('Teilnehmen', style: TextStyle(fontSize: 10)),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 96, height: 22,
            child: TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
              onPressed: userId == null ? null : () => _setStatus(ref, context, 'interested'),
              child: const Text('Interessiert', style: TextStyle(fontSize: 9, color: AppColors.primary500)),
            ),
          ),
        ],
      ],
    );
  }
}

class _CalendarView extends StatelessWidget {
  final DateTime monthCursor;
  final DateTime? selectedDay;
  final List<Event> events;
  final ValueChanged<DateTime> onMonth;
  final ValueChanged<DateTime?> onDay;

  const _CalendarView({
    required this.monthCursor, required this.selectedDay, required this.events,
    required this.onMonth, required this.onDay,
  });

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(monthCursor.year, monthCursor.month, 1);
    final daysInMonth = DateTime(monthCursor.year, monthCursor.month + 1, 0).day;
    final firstWeekday = firstOfMonth.weekday;
    final dayEvents = <int, List<Event>>{};
    for (final e in events) {
      if (e.startDate.year == monthCursor.year && e.startDate.month == monthCursor.month) {
        dayEvents.putIfAbsent(e.startDate.day, () => []).add(e);
      }
    }
    final selDay = selectedDay;
    final selectedEvents = selDay == null ? const <Event>[] : (dayEvents[selDay.day] ?? const <Event>[]);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => onMonth(DateTime(monthCursor.year, monthCursor.month - 1, 1))),
            Expanded(child: Center(child: Text(DateFormat('MMMM yyyy', 'de').format(monthCursor), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)))),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => onMonth(DateTime(monthCursor.year, monthCursor.month + 1, 1))),
          ],
        ),
        const SizedBox(height: 4),
        Row(children: ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'].map((d) => Expanded(child: Center(child: Text(d, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted))))).toList()),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1,
          children: [
            ...List.generate(firstWeekday - 1, (_) => const SizedBox.shrink()),
            ...List.generate(daysInMonth, (i) {
              final day = i + 1;
              final hasEvents = dayEvents.containsKey(day);
              final isSelected = selDay != null && selDay.year == monthCursor.year && selDay.month == monthCursor.month && selDay.day == day;
              final now = DateTime.now();
              final isToday = now.year == monthCursor.year && now.month == monthCursor.month && now.day == day;
              return GestureDetector(
                onTap: () => onDay(DateTime(monthCursor.year, monthCursor.month, day)),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary500 : hasEvents ? AppColors.primary50 : null,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday ? Border.all(color: AppColors.primary500, width: 1.5) : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$day', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppColors.textPrimary)),
                      if (hasEvents) Container(margin: const EdgeInsets.only(top: 2), width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: isSelected ? Colors.white : AppColors.primary500)),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 16),
        if (selDay != null) ...[
          Text(DateFormat('EEEE, d. MMMM', 'de').format(selDay), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (selectedEvents.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Keine Events an diesem Tag', style: TextStyle(color: AppColors.textMuted)))
          else
            ...selectedEvents.map((e) => _EventCard(event: e, onTap: () => context.push('/dashboard/events/${e.id}'))),
        ],
      ],
    );
  }
}

class _MapView extends StatelessWidget {
  final List<Event> events;
  const _MapView({required this.events});

  @override
  Widget build(BuildContext context) {
    final withCoords = events.where((e) => e.latitude != null && e.longitude != null).toList();
    final center = withCoords.isNotEmpty ? LatLng(withCoords.first.latitude!, withCoords.first.longitude!) : const LatLng(48.2082, 16.3738);
    return FlutterMap(
      options: MapOptions(initialCenter: center, initialZoom: withCoords.isEmpty ? 6 : 11),
      children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'de.mensaena.app'),
        MarkerLayer(
          markers: withCoords.map((e) => Marker(
            point: LatLng(e.latitude!, e.longitude!), width: 40, height: 40,
            child: GestureDetector(
              onTap: () => context.push('/dashboard/events/${e.id}'),
              child: Container(
                decoration: BoxDecoration(color: AppColors.primary500, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2))]),
                child: const Icon(Icons.event, color: Colors.white, size: 20),
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }
}
