import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/event_provider.dart';
import 'package:mensaena/models/event.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _currentMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month);
    _selectedDate = now;
  }

  String get _monthKey =>
      '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}';

  void _goToPreviousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _goToNextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _currentMonth = DateTime(now.year, now.month);
      _selectedDate = now;
    });
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(monthEventsProvider(_monthKey));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalender'),
        actions: [
          TextButton(
            onPressed: _goToToday,
            child: const Text('Heute'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Month navigation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _goToPreviousMonth,
                ),
                GestureDetector(
                  onTap: _goToToday,
                  child: Text(
                    DateFormat('MMMM yyyy', 'de').format(_currentMonth),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _goToNextMonth,
                ),
              ],
            ),
          ),

          // Weekday header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: AppColors.surface,
            child: Row(
              children: ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: (d == 'Sa' || d == 'So')
                                  ? AppColors.textMuted
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),

          const Divider(height: 1),

          // Calendar grid
          eventsAsync.when(
            loading: () => const SizedBox(
              height: 280,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SizedBox(
              height: 280,
              child: Center(child: Text('Fehler: $e')),
            ),
            data: (events) {
              final eventsByDate = <String, List<Event>>{};
              for (final event in events) {
                final key = DateFormat('yyyy-MM-dd').format(event.startDate);
                eventsByDate.putIfAbsent(key, () => []).add(event);
              }
              return _buildCalendarGrid(eventsByDate);
            },
          ),

          const Divider(height: 1),

          // Selected date header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.surface,
            child: Row(
              children: [
                const Icon(Icons.event, size: 18, color: AppColors.primary500),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEEE, dd. MMMM yyyy', 'de')
                      .format(_selectedDate),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Events for selected date
          Expanded(
            child: eventsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (events) {
                final dayEvents = events
                    .where((e) =>
                        e.startDate.year == _selectedDate.year &&
                        e.startDate.month == _selectedDate.month &&
                        e.startDate.day == _selectedDate.day)
                    .toList();

                if (dayEvents.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy,
                            size: 48,
                            color: AppColors.textMuted.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        const Text(
                          'Keine Events an diesem Tag',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: dayEvents.length,
                  itemBuilder: (context, index) {
                    final event = dayEvents[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.event,
                                  color: AppColors.primary500, size: 18),
                              if (!event.isAllDay)
                                Text(
                                  DateFormat('HH:mm').format(event.startDate),
                                  style: const TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        title: Text(
                          event.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!event.isAllDay)
                              Text(
                                'Uhrzeit: ${DateFormat('HH:mm').format(event.startDate)}${event.endDate != null ? ' - ${DateFormat('HH:mm').format(event.endDate!)}' : ''}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            if (event.locationDisplay.isNotEmpty)
                              Text(
                                event.locationDisplay,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textMuted),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right,
                            color: AppColors.textMuted),
                        onTap: () =>
                            context.push('/dashboard/events/${event.id}'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(Map<String, List<Event>> eventsByDate) {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startWeekday = firstDay.weekday; // 1=Mon, 7=Sun
    final now = DateTime.now();

    // Calculate number of rows needed
    final totalCells = (startWeekday - 1) + lastDay.day;
    final rows = (totalCells / 7).ceil();

    final days = <Widget>[];

    // Empty cells for days before first day of month
    for (int i = 1; i < startWeekday; i++) {
      days.add(const SizedBox());
    }

    // Day cells
    for (int d = 1; d <= lastDay.day; d++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, d);
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final isSelected = date.day == _selectedDate.day &&
          date.month == _selectedDate.month &&
          date.year == _selectedDate.year;
      final isToday = date.day == now.day &&
          date.month == now.month &&
          date.year == now.year;
      final dayEvents = eventsByDate[dateStr] ?? [];
      final hasEvents = dayEvents.isNotEmpty;
      final isWeekend = date.weekday == 6 || date.weekday == 7;

      days.add(
        GestureDetector(
          onTap: () => setState(() => _selectedDate = date),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary500
                  : isToday
                      ? AppColors.primary50
                      : null,
              borderRadius: BorderRadius.circular(10),
              border: isToday && !isSelected
                  ? Border.all(color: AppColors.primary500, width: 2)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$d',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        isSelected || isToday ? FontWeight.w700 : FontWeight.w400,
                    color: isSelected
                        ? Colors.white
                        : isWeekend
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                if (hasEvents)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < dayEvents.length.clamp(0, 3); i++)
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color:
                                isSelected ? Colors.white : AppColors.primary500,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  )
                else
                  const SizedBox(height: 5),
              ],
            ),
          ),
        ),
      );
    }

    // Fill remaining cells in last row
    final remainingCells = (rows * 7) - days.length;
    for (int i = 0; i < remainingCells; i++) {
      days.add(const SizedBox());
    }

    return SizedBox(
      height: rows * 48.0,
      child: GridView.count(
        crossAxisCount: 7,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        children: days,
      ),
    );
  }
}
