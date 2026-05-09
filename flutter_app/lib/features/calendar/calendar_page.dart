import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/supabase.dart';
import '../../routing/routes.dart';
import '../../theme/app_colors.dart';
import '../../widgets/page_chrome.dart';

/// /dashboard/calendar – persönlicher Kalender mit Events des aktuellen Users.
/// Zeigt eigene Posts/Events des aktuellen Monats als Liste pro Tag.
class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  Map<int, List<Map<String, dynamic>>> _eventsByDay = const {};
  bool _loading = true;
  int? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now().day;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final db = ref.read(supabaseProvider);
      final user = db.auth.currentUser;
      if (user == null) {
        setState(() => _loading = false);
        return;
      }
      final start = DateTime(_month.year, _month.month);
      final end = DateTime(_month.year, _month.month + 1);
      final rows = await db
          .from('events')
          .select('id, title, start_date, category, location_name')
          .eq('author_id', user.id)
          .gte('start_date', start.toIso8601String())
          .lt('start_date', end.toIso8601String())
          .order('start_date');
      if (!mounted) return;
      final grouped = <int, List<Map<String, dynamic>>>{};
      for (final r in rows) {
        final d = DateTime.parse(r['start_date'] as String);
        grouped.putIfAbsent(d.day, () => []).add(r);
      }
      setState(() {
        _eventsByDay = grouped;
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

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _selectedDay = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Kalender')),
      body: Column(
        children: [
          _MonthHeader(
            month: _month,
            onPrev: () => _changeMonth(-1),
            onNext: () => _changeMonth(1),
          ),
          _CalendarGrid(
            month: _month,
            eventsByDay: _eventsByDay,
            selectedDay: _selectedDay,
            onDayTap: (d) => setState(() => _selectedDay = d),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const SkeletonList(count: 3)
                : _selectedDay == null
                    ? const EmptyState(
                        emoji: '🗓️',
                        title: 'Tag auswählen',
                        subtitle:
                            'Tippe einen Tag im Kalender an, um deine Events '
                            'für diesen Tag zu sehen.',
                      )
                    : _buildEventsForDay(_selectedDay!),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsForDay(int day) {
    final events = _eventsByDay[day] ?? const <Map<String, dynamic>>[];
    if (events.isEmpty) {
      return const EmptyState(
        emoji: '📭',
        title: 'Keine Events',
        subtitle: 'An diesem Tag stehen keine Events in deinem Kalender.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final e = events[i];
        final time = DateFormat('HH:mm', 'de').format(
          DateTime.parse(e['start_date'] as String),
        );
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => context.go('${Routes.dashboardEvents}/${e['id']}'),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary500.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      time,
                      style: const TextStyle(
                        color: AppColors.primary500,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e['title'] as String? ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        if (e['location_name'] != null)
                          Text(
                            e['location_name'] as String,
                            style: const TextStyle(
                              color: AppColors.ink400,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrev),
          Expanded(
            child: Center(
              child: Text(
                DateFormat('MMMM yyyy', 'de').format(month),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
        ],
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.month,
    required this.eventsByDay,
    required this.selectedDay,
    required this.onDayTap,
  });
  final DateTime month;
  final Map<int, List<Map<String, dynamic>>> eventsByDay;
  final int? selectedDay;
  final ValueChanged<int> onDayTap;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month);
    final daysInMonth =
        DateTime(month.year, month.month + 1).subtract(const Duration(days: 1)).day;
    // Mon-So → Mon=0
    final startWeekday = (firstDay.weekday + 6) % 7;
    final cells = startWeekday + daysInMonth;
    final rows = (cells / 7).ceil();
    final today = DateTime.now();
    final isCurrentMonth = today.year == month.year && today.month == month.month;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Column(
        children: [
          Row(
            children: const ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: const TextStyle(
                          color: AppColors.ink400,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 4),
          for (var r = 0; r < rows; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: _DayCell(
                      day: () {
                        final idx = r * 7 + c;
                        final dayNum = idx - startWeekday + 1;
                        return (dayNum < 1 || dayNum > daysInMonth)
                            ? null
                            : dayNum;
                      }(),
                      selected: selectedDay,
                      isToday: isCurrentMonth,
                      todayDay: today.day,
                      hasEvents: (d) => eventsByDay.containsKey(d),
                      onTap: onDayTap,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.todayDay,
    required this.hasEvents,
    required this.onTap,
  });
  final int? day;
  final int? selected;
  final bool isToday;
  final int todayDay;
  final bool Function(int) hasEvents;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final d = day;
    if (d == null) return const SizedBox(height: 40);
    final isSelected = selected == d;
    final isCurrent = isToday && d == todayDay;
    final marker = hasEvents(d);
    return GestureDetector(
      onTap: () => onTap(d),
      child: Container(
        margin: const EdgeInsets.all(2),
        height: 40,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary500.withValues(alpha: 0.18)
              : isCurrent
                  ? AppColors.primary500.withValues(alpha: 0.06)
                  : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '$d',
              style: TextStyle(
                color: isSelected ? AppColors.primary500 : AppColors.ink800,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            if (marker)
              Positioned(
                bottom: 4,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
