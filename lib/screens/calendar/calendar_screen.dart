import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/event_provider.dart';
import 'package:mensaena/models/event.dart';
import 'package:mensaena/widgets/empty_state.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Kalender')),
      body: Column(
        children: [
          // Month selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() {
                    _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1);
                  }),
                ),
                Text(
                  DateFormat('MMMM yyyy', 'de').format(_selectedDate),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() {
                    _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1);
                  }),
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
                          child: Text(d, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                        ),
                      ))
                  .toList(),
            ),
          ),

          const Divider(height: 1),

          // Calendar grid
          eventsAsync.when(
            loading: () => const Expanded(child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Expanded(child: Center(child: Text('Fehler: $e'))),
            data: (events) {
              final eventDates = events.map((e) => DateFormat('yyyy-MM-dd').format(e.eventDate)).toSet();
              return _buildCalendarGrid(eventDates);
            },
          ),

          const Divider(height: 1),

          // Events for selected date
          Expanded(
            child: eventsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (events) {
                final dayEvents = events.where((e) =>
                    e.eventDate.year == _selectedDate.year &&
                    e.eventDate.month == _selectedDate.month &&
                    e.eventDate.day == _selectedDate.day).toList();

                if (dayEvents.isEmpty) {
                  return Center(
                    child: Text(
                      'Keine Events am ${DateFormat('dd.MM.yyyy', 'de').format(_selectedDate)}',
                      style: const TextStyle(color: AppColors.textMuted),
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
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.event, color: AppColors.primary500, size: 20),
                        ),
                        title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: event.eventTime != null ? Text(event.eventTime!, style: const TextStyle(fontSize: 12)) : null,
                        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                        onTap: () => context.push('/dashboard/events/${event.id}'),
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

  Widget _buildCalendarGrid(Set<String> eventDates) {
    final firstDay = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final lastDay = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    final startWeekday = firstDay.weekday; // 1=Mon, 7=Sun

    final days = <Widget>[];
    // Empty cells for days before first
    for (int i = 1; i < startWeekday; i++) {
      days.add(const SizedBox());
    }
    // Day cells
    for (int d = 1; d <= lastDay.day; d++) {
      final date = DateTime(_selectedDate.year, _selectedDate.month, d);
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final isSelected = date.day == _selectedDate.day &&
          date.month == _selectedDate.month &&
          date.year == _selectedDate.year;
      final isToday = date.day == DateTime.now().day &&
          date.month == DateTime.now().month &&
          date.year == DateTime.now().year;
      final hasEvent = eventDates.contains(dateStr);

      days.add(
        GestureDetector(
          onTap: () => setState(() => _selectedDate = date),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary500 : null,
              borderRadius: BorderRadius.circular(8),
              border: isToday && !isSelected ? Border.all(color: AppColors.primary500) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$d',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.normal,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                if (hasEvent)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : AppColors.primary500,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 240,
      child: GridView.count(
        crossAxisCount: 7,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        children: days,
      ),
    );
  }
}
