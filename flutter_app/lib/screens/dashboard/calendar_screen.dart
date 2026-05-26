import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../config/theme/app_typography.dart' show AppTypography;
import '../../models/event.dart';
import '../../repositories/events_repository.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features (E1)
/// Kalender-Ansicht mit zwei Modi (Tab): "Liste" + "Monat".
/// Monats-Grid mit Bronze-Dot pro Tag mit Events; Tap auf Tag öffnet
/// die Day-Liste am Tagesende.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  late DateTime _visibleMonth;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _shiftMonth(int delta) {
    setState(() {
      _visibleMonth =
          DateTime(_visibleMonth.year, _visibleMonth.month + delta);
      _selectedDay = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(upcomingEventsProvider);
    return DashboardScaffold(
      title: 'calendar.screenTitle'.tr(),
      currentRoute: '/dashboard/calendar',
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.line),
              ),
              child: TabBar(
                controller: _tab,
                indicator: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: AppColors.amber.withValues(alpha: 0.5)),
                ),
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: AppColors.amber,
                unselectedLabelColor: AppColors.inkSoft,
                labelStyle: AppTypography.body(
                    size: 12, weight: FontWeight.w700),
                unselectedLabelStyle: AppTypography.body(size: 12),
                tabs: [
                  Tab(height: 36, text: 'calendar.tabList'.tr()),
                  Tab(height: 36, text: 'calendar.tabMonth'.tr()),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.amber),
                ),
                error: (e, _) => Center(
                    child: Text('$e', style: AppTypography.caption())),
                data: (list) => TabBarView(
                  controller: _tab,
                  children: [
                    _ListView(events: list, onRefresh: () async {
                      ref.invalidate(upcomingEventsProvider);
                      await ref.read(upcomingEventsProvider.future);
                    }),
                    _MonthView(
                      events: list,
                      month: _visibleMonth,
                      selectedDay: _selectedDay,
                      onShiftMonth: _shiftMonth,
                      onSelectDay: (d) => setState(() => _selectedDay = d),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListView extends StatelessWidget {
  const _ListView({required this.events, required this.onRefresh});
  final List<EventItem> events;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return RefreshIndicator(
        color: AppColors.amber,
        backgroundColor: AppColors.surface,
        onRefresh: onRefresh,
        child: ListView(
          children: [
            const SizedBox(height: 80),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.calendar,
                      size: 32, color: AppColors.mute),
                  const SizedBox(height: 10),
                  Text('calendar.noEvents'.tr(),
                      style: AppTypography.body(
                          size: 14, color: AppColors.mute)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final groups = <String, List<EventItem>>{};
    for (final e in events) {
      final key = DateFormat('yyyy-MM-dd').format(e.startDate);
      groups.putIfAbsent(key, () => []).add(e);
    }
    final sortedKeys = groups.keys.toList()..sort();
    return RefreshIndicator(
      color: AppColors.amber,
      backgroundColor: AppColors.surface,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final key in sortedKeys)
            _DaySection(
              date: DateTime.parse(key),
              events: groups[key]!,
            ),
        ],
      ),
    );
  }
}

class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.events,
    required this.month,
    required this.selectedDay,
    required this.onShiftMonth,
    required this.onSelectDay,
  });
  final List<EventItem> events;
  final DateTime month;
  final DateTime? selectedDay;
  final void Function(int delta) onShiftMonth;
  final void Function(DateTime day) onSelectDay;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Monday=1..Sunday=7. Wir starten die Woche montags.
    final leadingBlanks = (first.weekday + 6) % 7; // Mon=0..Sun=6
    final totalCells = ((leadingBlanks + daysInMonth + 6) ~/ 7) * 7;
    final today = DateTime.now();
    final monthEvents = events.where((e) =>
        e.startDate.year == month.year && e.startDate.month == month.month);
    final perDay = <int, int>{};
    for (final e in monthEvents) {
      perDay[e.startDate.day] = (perDay[e.startDate.day] ?? 0) + 1;
    }
    final daySelected = selectedDay != null &&
        selectedDay!.year == month.year &&
        selectedDay!.month == month.month;
    final dayEvents = daySelected
        ? monthEvents.where((e) => e.startDate.day == selectedDay!.day).toList()
        : <EventItem>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => onShiftMonth(-1),
              icon: const Icon(LucideIcons.chevronLeft,
                  size: 18, color: AppColors.amber),
            ),
            Expanded(
              child: Text(
                DateFormat('MMMM yyyy', 'de').format(month),
                textAlign: TextAlign.center,
                style: AppTypography.body(
                    size: 15,
                    color: AppColors.ink,
                    weight: FontWeight.w700),
              ),
            ),
            IconButton(
              onPressed: () => onShiftMonth(1),
              icon: const Icon(LucideIcons.chevronRight,
                  size: 18, color: AppColors.amber),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final wd in const ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'])
              Expanded(
                child: Center(
                  child: Text(
                    wd,
                    style: AppTypography.label(
                        size: 9, color: AppColors.mute),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalCells,
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 0.95,
          ),
          itemBuilder: (_, i) {
            final dayNum = i - leadingBlanks + 1;
            if (dayNum < 1 || dayNum > daysInMonth) {
              return const SizedBox.shrink();
            }
            final day = DateTime(month.year, month.month, dayNum);
            final isToday = today.year == day.year &&
                today.month == day.month &&
                today.day == day.day;
            final isSelected = selectedDay != null &&
                selectedDay!.year == day.year &&
                selectedDay!.month == day.month &&
                selectedDay!.day == day.day;
            final count = perDay[dayNum] ?? 0;
            return InkWell(
              onTap: () => onSelectDay(day),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.amber.withValues(alpha: 0.20)
                      : isToday
                          ? AppColors.bronze.withValues(alpha: 0.10)
                          : AppColors.surface.withValues(alpha: 0.35),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.amber.withValues(alpha: 0.7)
                        : isToday
                            ? AppColors.bronze.withValues(alpha: 0.6)
                            : AppColors.line,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$dayNum',
                      style: AppTypography.body(
                        size: 13,
                        color: isSelected || isToday
                            ? AppColors.amber
                            : AppColors.ink,
                        weight: FontWeight.w600,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(height: 2),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.bronze,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors.bronze.withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        if (daySelected) ...[
          Text(
            DateFormat('EEEE, dd.MM.yyyy', 'de').format(selectedDay!),
            style: AppTypography.body(
                size: 13,
                color: AppColors.inkSoft,
                weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (dayEvents.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'calendar.noEventsThisDay'.tr(),
                style:
                    AppTypography.body(size: 12, color: AppColors.mute),
              ),
            )
          else
            ...dayEvents.map((e) => _EventRow(event: e)),
        ],
      ],
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({required this.date, required this.events});
  final DateTime date;
  final List<EventItem> events;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEEE, dd.MM.', 'de');
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            label: 'calendar.daySectionSr'.tr(namedArgs: {
              'date': df.format(date),
              'count': '${events.length}',
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
              ),
              child: Text(
                df.format(date),
                style: AppTypography.label(
                  size: 10,
                  color: AppColors.amber,
                  letterSpacing: 0.15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...events.map((e) => _EventRow(event: e)),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});
  final EventItem event;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/dashboard/events/${event.id}'),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.4),
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Text(
                event.isAllDay
                    ? 'Tag'
                    : DateFormat('HH:mm').format(event.startDate),
                style: AppTypography.mono(
                  size: 12,
                  color: AppColors.amber,
                  weight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Text(
                event.title,
                style: AppTypography.body(
                  size: 14,
                  color: AppColors.ink,
                  weight: FontWeight.w600,
                ),
              ),
            ),
            if (event.locationName != null)
              const Icon(LucideIcons.mapPin, size: 12, color: AppColors.mute),
          ],
        ),
      ),
    );
  }
}
