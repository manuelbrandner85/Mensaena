import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import 'models.dart';

/// Pendant zur Web-`EventCalendar.tsx`. Custom Monatskalender ohne externe
/// Dependency: 7×6-Grid mit Tagen, Event-Dots pro Tag, Tap → Bottom-Sheet
/// mit den Events des gewählten Tages.
///
/// Holiday-Detection und HolidayCalendarOverlay folgen in einer separaten PR
/// (benötigt Bundesland-Lookup + Feiertags-API).
class EventCalendarView extends StatefulWidget {
  const EventCalendarView({
    super.key,
    required this.events,
    required this.onAttend,
    required this.onRemove,
    required this.attendances,
    required this.eventTileBuilder,
  });

  final List<EventItem> events;
  final Map<String, AttendeeStatus> attendances;
  final Future<bool> Function(String eventId, AttendeeStatus status) onAttend;
  final void Function(String eventId) onRemove;

  /// Wir delegieren das Rendern einer Event-Zeile zurück an die Page,
  /// damit das Calendar-View nicht 1:1 die Detail-UI duplizieren muss.
  final Widget Function(EventItem event, AttendeeStatus? myStatus)
      eventTileBuilder;

  @override
  State<EventCalendarView> createState() => _EventCalendarViewState();
}

class _EventCalendarViewState extends State<EventCalendarView> {
  late DateTime _activeMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _activeMonth = DateTime(now.year, now.month, 1);
  }

  /// Map "YYYY-MM-DD" → Events an diesem Tag (lokale Zeit).
  Map<String, List<EventItem>> get _eventsByDate {
    final map = <String, List<EventItem>>{};
    for (final e in widget.events) {
      final d = e.startDate.toLocal();
      final key = _key(d);
      map.putIfAbsent(key, () => []).add(e);
    }
    return map;
  }

  String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';

  void _prevMonth() {
    setState(() => _activeMonth =
        DateTime(_activeMonth.year, _activeMonth.month - 1, 1));
  }

  void _nextMonth() {
    setState(() => _activeMonth =
        DateTime(_activeMonth.year, _activeMonth.month + 1, 1));
  }

  void _goToday() {
    final now = DateTime.now();
    setState(() {
      _activeMonth = DateTime(now.year, now.month, 1);
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
    _maybeShowDaySheet(_selectedDate!);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isCurrentMonth(DateTime d) =>
      d.year == _activeMonth.year && d.month == _activeMonth.month;

  /// Liefert 42 Tage = 6 Wochen, Montag-startend. Auffüllung mit Tagen aus
  /// vorigem/nächstem Monat damit das Grid stabil bleibt.
  List<DateTime> _calendarDays() {
    final firstOfMonth = DateTime(_activeMonth.year, _activeMonth.month, 1);
    var startOffset = firstOfMonth.weekday - 1; // Monday = 1 → 0 offset
    if (startOffset < 0) startOffset = 6;
    final start = firstOfMonth.subtract(Duration(days: startOffset));
    return List<DateTime>.generate(42, (i) => start.add(Duration(days: i)));
  }

  void _onDayTap(DateTime date) {
    final events = _eventsByDate[_key(date)] ?? const [];
    if (events.isEmpty) return;
    setState(() => _selectedDate = date);
    _maybeShowDaySheet(date);
  }

  void _maybeShowDaySheet(DateTime date) {
    final events = _eventsByDate[_key(date)] ?? const [];
    if (events.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DaySheet(
        date: date,
        events: events,
        attendances: widget.attendances,
        eventTileBuilder: widget.eventTileBuilder,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = _calendarDays();
    final byDate = _eventsByDate;
    final today = DateTime.now();
    final isCurrentMonth =
        _activeMonth.year == today.year && _activeMonth.month == today.month;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _prevMonth,
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Vorheriger Monat',
              ),
              Expanded(
                child: Center(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        DateFormat('MMMM yyyy', 'de').format(_activeMonth),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!isCurrentMonth)
                        TextButton(
                          onPressed: _goToday,
                          child: const Text('Heute'),
                        ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: _nextMonth,
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Nächster Monat',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: const [
              _WeekdayCell('Mo'),
              _WeekdayCell('Di'),
              _WeekdayCell('Mi'),
              _WeekdayCell('Do'),
              _WeekdayCell('Fr'),
              _WeekdayCell('Sa'),
              _WeekdayCell('So'),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
                childAspectRatio: 0.85,
              ),
              itemCount: days.length,
              itemBuilder: (_, i) {
                final d = days[i];
                final events = byDate[_key(d)] ?? const [];
                return _DayCell(
                  date: d,
                  isCurrentMonth: _isCurrentMonth(d),
                  isToday: _isSameDay(d, today),
                  isSelected:
                      _selectedDate != null && _isSameDay(d, _selectedDate!),
                  events: events,
                  onTap: () => _onDayTap(d),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekdayCell extends StatelessWidget {
  const _WeekdayCell(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.ink400,
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.isCurrentMonth,
    required this.isToday,
    required this.isSelected,
    required this.events,
    required this.onTap,
  });

  final DateTime date;
  final bool isCurrentMonth;
  final bool isToday;
  final bool isSelected;
  final List<EventItem> events;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color textColor = AppColors.ink800;
    if (!isCurrentMonth) textColor = AppColors.ink400;
    if (isSelected || isToday) textColor = AppColors.primary500;

    Color? bg;
    Border? border;
    if (isSelected) {
      bg = AppColors.primary500.withValues(alpha: 0.12);
      border = Border.all(color: AppColors.primary500, width: 1.5);
    } else if (isToday) {
      border = Border.all(color: AppColors.primary500, width: 1);
    }

    return Material(
      color: bg ?? Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: border,
          ),
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 12,
                  color: textColor,
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              if (events.isNotEmpty)
                Expanded(
                  child: _EventDots(events: events),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventDots extends StatelessWidget {
  const _EventDots({required this.events});
  final List<EventItem> events;

  @override
  Widget build(BuildContext context) {
    final visible = events.take(3).toList();
    final extra = events.length - visible.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...visible.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: e.categoryConfig.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        if (extra > 0)
          Text(
            '+$extra',
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.ink400,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

class _DaySheet extends StatelessWidget {
  const _DaySheet({
    required this.date,
    required this.events,
    required this.attendances,
    required this.eventTileBuilder,
  });

  final DateTime date;
  final List<EventItem> events;
  final Map<String, AttendeeStatus> attendances;
  final Widget Function(EventItem event, AttendeeStatus? myStatus)
      eventTileBuilder;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              Container(
                color: AppColors.primary500.withValues(alpha: 0.08),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat('EEEE, d. MMMM', 'de').format(date),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary500,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final e = events[i];
                    return eventTileBuilder(e, attendances[e.id]);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
