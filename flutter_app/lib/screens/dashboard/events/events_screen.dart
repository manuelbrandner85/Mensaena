import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/event.dart';
import '../../../repositories/events_repository.dart';
import '../../../widgets/effects/animated_entrance.dart';
import '../../../widgets/effects/shimmer_skeleton.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/editorial_module_header.dart';
import '../../../widgets/shared/empty_state_card.dart';
import '../../../widgets/shared/filter_chip_bar.dart';
import '../../../widgets/shared/location_map_view.dart';
import '../../../widgets/shared/module_search_bar.dart';
import '../../../widgets/shared/view_toggle.dart';
import '../../../widgets/shared/weather_forecast_strip.dart';

enum _EventView { list, calendar, map }

/// SKILL: mensaena-features
/// Events — 1:1-Spiegel von `src/app/dashboard/events/page.tsx`.
/// View-Toggle (Liste / Kalender), Kategorie-Filter, Such-Bar,
/// Aktive-Filter-Strip, Empty-State mit Reset.
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  static const List<FilterOption<String>> _categories = [
    FilterOption(value: 'community', label: '🏘️ Community'),
    FilterOption(value: 'helping', label: '💚 Helfen'),
    FilterOption(value: 'sharing', label: '🔄 Teilen'),
    FilterOption(value: 'learning', label: '📚 Lernen'),
    FilterOption(value: 'celebration', label: '🎉 Feiern'),
    FilterOption(value: 'sport', label: '⚽ Sport'),
    FilterOption(value: 'crisis', label: '🚨 Krise'),
    FilterOption(value: 'other', label: '❓ Sonstiges'),
  ];

  _EventView _view = _EventView.list;
  String? _category;
  String _search = '';
  bool _onlySaved = false;
  Set<String> _savedIds = const <String>{};
  DateTime _calendarMonth =
      DateTime(DateTime.now().year, DateTime.now().month);

  bool get _hasFilters =>
      _category != null || _search.isNotEmpty || _onlySaved;

  @override
  void initState() {
    super.initState();
    _refreshSavedIds();
  }

  Future<void> _refreshSavedIds() async {
    final ids = await EventsRepository.listSavedEventIds();
    if (!mounted) return;
    setState(() => _savedIds = ids.toSet());
  }

  List<EventItem> _apply(List<EventItem> all) {
    final q = _search.trim().toLowerCase();
    return all.where((e) {
      if (_category != null && e.category != _category) return false;
      if (_onlySaved && !_savedIds.contains(e.id)) return false;
      if (q.isEmpty) return true;
      return e.title.toLowerCase().contains(q) ||
          (e.locationName ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(upcomingEventsProvider);
    return DashboardScaffold(
      title: 'events.screenTitle'.tr(),
      currentRoute: '/dashboard/events',
      fab: FloatingActionButton.extended(
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.voidColor,
        onPressed: () => context.push('/dashboard/events/create'),
        icon: const Icon(LucideIcons.plus),
        label: Text('events.create'.tr()),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: EditorialModuleHeader(
                metaIndex: '§ 07',
                metaCategory: 'events.screenTitle'.tr(),
                title: 'modules.eventsHero.title'.tr(),
                subtitle: 'modules.eventsHero.subtitle'.tr(),
              ),
            ),
            // ── Header: View-Toggle + Refresh ──────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: ModuleSearchBar(
                      hintText: 'events.searchPlaceholder'.tr(),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ViewToggle<_EventView>(
                    value: _view,
                    onChanged: (v) => setState(() => _view = v),
                    options: const [
                      ViewToggleOption(
                          value: _EventView.list,
                          label: 'Liste',
                          icon: LucideIcons.list),
                      ViewToggleOption(
                          value: _EventView.calendar,
                          label: 'Kalender',
                          icon: LucideIcons.calendar),
                      ViewToggleOption(
                          value: _EventView.map,
                          label: 'Karte',
                          icon: LucideIcons.mapPin),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: FilterChipBar<String>(
                      options: _categories,
                      selected:
                          _category == null ? const <String>{} : {_category!},
                      onChanged: (s) => setState(
                          () => _category = s.isEmpty ? null : s.first),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () {
                      setState(() => _onlySaved = !_onlySaved);
                      if (_onlySaved) _refreshSavedIds();
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _onlySaved
                            ? AppColors.amber.withValues(alpha: 0.22)
                            : AppColors.elevated,
                        border: Border.all(
                          color: _onlySaved
                              ? AppColors.amber.withValues(alpha: 0.6)
                              : AppColors.line,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _onlySaved
                                ? LucideIcons.bookMarked
                                : LucideIcons.bookmark,
                            size: 14,
                            color: _onlySaved
                                ? AppColors.amber
                                : AppColors.inkSoft,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'events.savedFilter'.tr(),
                            style: AppTypography.body(
                              size: 11,
                              color: _onlySaved
                                  ? AppColors.amber
                                  : AppColors.inkSoft,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_hasFilters)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ActiveFilterStrip(
                  chips: [
                    if (_category != null)
                      ActiveFilterChip(
                        label: _categories.labelFor(_category!),
                        onRemove: () => setState(() => _category = null),
                      ),
                    if (_search.isNotEmpty)
                      ActiveFilterChip(
                        label: '🔍 $_search',
                        onRemove: () => setState(() => _search = ''),
                      ),
                    if (_onlySaved)
                      ActiveFilterChip(
                        label: 'events.savedFilter'.tr(),
                        onRemove: () => setState(() => _onlySaved = false),
                      ),
                  ],
                  onClearAll: () => setState(() {
                    _category = null;
                    _search = '';
                    _onlySaved = false;
                  }),
                ),
              ),
            // ── Wetter-Strip (Pendant zu Web WeatherForecastStrip) ──
            if (_view == _EventView.list) const WeatherForecastStrip(),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.amber,
                backgroundColor: AppColors.surface,
                onRefresh: () async =>
                    ref.invalidate(upcomingEventsProvider),
                child: async.when(
                  loading: () => const ListSkeleton(count: 4),
                  error: (e, _) => Center(
                      child: Text('$e', style: AppTypography.caption())),
                  data: (all) {
                    final list = _apply(all);
                    if (_view == _EventView.calendar) {
                      return _CalendarView(
                        events: list,
                        month: _calendarMonth,
                        onMonthChange: (m) =>
                            setState(() => _calendarMonth = m),
                      );
                    }
                    if (_view == _EventView.map) {
                      return LocationMapView(
                        markers: [
                          for (final e in list)
                            MapMarkerData(
                              id: e.id,
                              lat: e.latitude,
                              lng: e.longitude,
                              color: AppColors.amber,
                              title: e.title,
                              subtitle: e.locationName,
                              icon: LucideIcons.calendar,
                            ),
                        ],
                        onMarkerTap: (m) =>
                            context.push('/dashboard/events/${m.id}'),
                      );
                    }
                    if (list.isEmpty) {
                      return ListView(
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          const SizedBox(height: 60),
                          EmptyStateCard(
                            icon: LucideIcons.calendar,
                            title: _hasFilters
                                ? 'Keine Treffer.'
                                : 'Keine kommenden Events.',
                            description: _hasFilters
                                ? 'Andere Filter probieren.'
                                : 'Sei der/die Erste:r — Plus-Button.',
                            actionLabel: _hasFilters
                                ? 'Filter zurücksetzen'
                                : null,
                            onAction: _hasFilters
                                ? () => setState(() {
                                      _category = null;
                                      _search = '';
                                    })
                                : null,
                          ),
                        ],
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: list.length,
                      itemBuilder: (context, i) => AnimatedEntrance(
                        index: i,
                        child: _EventTile(event: list[i]),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Calendar-View (Monatsansicht mit Event-Dots)
// ──────────────────────────────────────────────────────────────
class _CalendarView extends StatelessWidget {
  const _CalendarView({
    required this.events,
    required this.month,
    required this.onMonthChange,
  });

  final List<EventItem> events;
  final DateTime month;
  final ValueChanged<DateTime> onMonthChange;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('MMMM yyyy', 'de');
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth =
        DateTime(month.year, month.month + 1, 0).day;
    // Mo=1...So=7 → Spalten-Index (0-basiert) für Wochenstart Mo.
    final firstWeekday = firstDay.weekday - 1;
    final eventsByDay = <int, List<EventItem>>{};
    for (final e in events) {
      if (e.startDate.year == month.year &&
          e.startDate.month == month.month) {
        eventsByDay.putIfAbsent(e.startDate.day, () => []).add(e);
      }
    }

    final today = DateTime.now();
    final isCurrentMonth =
        today.year == month.year && today.month == month.month;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // ── Monats-Header ──
        Row(
          children: [
            IconButton(
              icon: const Icon(LucideIcons.chevronLeft,
                  size: 18, color: AppColors.inkSoft),
              onPressed: () => onMonthChange(
                  DateTime(month.year, month.month - 1)),
            ),
            Expanded(
              child: Text(
                df.format(month),
                textAlign: TextAlign.center,
                style: AppTypography.display(
                    size: 18, color: AppColors.ink),
              ),
            ),
            IconButton(
              icon: const Icon(LucideIcons.chevronRight,
                  size: 18, color: AppColors.inkSoft),
              onPressed: () => onMonthChange(
                  DateTime(month.year, month.month + 1)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // ── Wochentags-Header ──
        Row(
          children: [
            for (final d in const ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'])
              Expanded(
                child: Text(d,
                    textAlign: TextAlign.center,
                    style: AppTypography.label(size: 9)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        // ── Grid: 6 Reihen × 7 Spalten ──
        for (var row = 0; row < 6; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: _CalendarCell(
                    day: row * 7 + col - firstWeekday + 1,
                    daysInMonth: daysInMonth,
                    events: eventsByDay,
                    isToday: isCurrentMonth &&
                        today.day == row * 7 + col - firstWeekday + 1,
                  ),
                ),
            ],
          ),
        const SizedBox(height: 12),
        // ── Liste der Events im Monat ──
        if (events.isNotEmpty) ...[
          Text('events.eventsInMonth'.tr(),
              style: AppTypography.label(size: 10)),
          const SizedBox(height: 6),
          for (final e in events) _EventTile(event: e),
        ],
      ],
    );
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
    required this.day,
    required this.daysInMonth,
    required this.events,
    required this.isToday,
  });

  final int day;
  final int daysInMonth;
  final Map<int, List<EventItem>> events;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    if (day < 1 || day > daysInMonth) {
      return const SizedBox(height: 44);
    }
    final list = events[day] ?? const [];
    return Container(
      height: 44,
      margin: const EdgeInsets.all(1),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isToday
            ? AppColors.amber.withValues(alpha: 0.16)
            : list.isNotEmpty
                ? AppColors.elevated
                : null,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$day',
              style: AppTypography.mono(
                size: 12,
                color: isToday ? AppColors.amber : AppColors.ink,
                weight: isToday ? FontWeight.w800 : FontWeight.w500,
              )),
          if (list.isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < list.length && i < 3; i++) ...[
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: AppColors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 2),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});
  final EventItem event;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEE, dd.MM.', 'de');
    final tf = DateFormat('HH:mm');
    return InkWell(
      onTap: () => context.push('/dashboard/events/${event.id}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.5),
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.12),
                border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    df.format(event.startDate).split(',').last.trim(),
                    style: AppTypography.mono(
                      size: 16,
                      color: AppColors.amber,
                      weight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    df.format(event.startDate).split(',').first,
                    style: AppTypography.label(size: 9, color: AppColors.amber),
                  ),
                  if (!event.isAllDay)
                    Text(
                      tf.format(event.startDate),
                      style: AppTypography.mono(
                        size: 10,
                        color: AppColors.inkSoft,
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
                    style: AppTypography.body(
                      size: 15,
                      color: AppColors.ink,
                      weight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.elevated,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          event.category,
                          style: AppTypography.label(
                            size: 9,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (event.attendeeCount > 0)
                        Text(
                          'events.attendeesCount'.tr(namedArgs: {
                            'count': '${event.attendeeCount}'
                          }),
                          style: AppTypography.caption(),
                        ),
                    ],
                  ),
                  if (event.locationName != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(LucideIcons.mapPin,
                            size: 11, color: AppColors.mute),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            event.locationName!,
                            style: AppTypography.body(
                              size: 11,
                              color: AppColors.mute,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (event.isOnline) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(LucideIcons.video,
                            size: 11, color: AppColors.teal),
                        const SizedBox(width: 4),
                        Text(
                          'Online',
                          style: AppTypography.label(
                              size: 9, color: AppColors.teal),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
