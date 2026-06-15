import 'package:add_2_calendar/add_2_calendar.dart' as a2c;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/community_calendar_entry.dart';
import '../../providers/community_calendar_provider.dart';
import '../../services/haptics.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';
import '../../widgets/shared/empty_state_widget.dart';
import '../../widgets/shared/error_state_widget.dart';
import '../../widgets/effects/shimmer_skeleton.dart';

/// Community-Kalender: aggregierte Ansicht aller Events, Zeitbank-Slots,
/// Gruppen-Treffen und Skill-Zeitfenster im Radius um den Nutzer.
class CommunityCalendarScreen extends ConsumerStatefulWidget {
  final double lat;
  final double lng;
  final double radiusKm;

  const CommunityCalendarScreen({
    super.key,
    this.lat = 48.1351,
    this.lng = 11.5820,
    this.radiusKm = 10,
  });

  @override
  ConsumerState<CommunityCalendarScreen> createState() =>
      _CommunityCalendarScreenState();
}

class _CommunityCalendarScreenState
    extends ConsumerState<CommunityCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  CalendarParams get _params => CalendarParams(
        lat: widget.lat,
        lng: widget.lng,
        radiusKm: widget.radiusKm,
      );

  List<CommunityCalendarEntry> _eventsForDay(
    List<CommunityCalendarEntry> all,
    DateTime day,
  ) {
    return all.where((e) => isSameDay(e.startDate, day)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(communityCalendarProvider(_params));

    return DashboardScaffold(
      title: 'communityCalendar.screenTitle'.tr(),
      onRefresh: () async {
        Haptics.tap();
        ref.invalidate(communityCalendarProvider(_params));
      },
      fab: FloatingActionButton.extended(
        heroTag: 'community_calendar_fab',
        backgroundColor: AppColors.primary500,
        foregroundColor: AppColors.surface,
        icon: const Icon(LucideIcons.plus, size: 20),
        label: Text(
          'communityCalendar.createEvent'.tr(),
          style: AppTypography.body(
            size: 14,
            weight: FontWeight.w600,
            color: AppColors.surface,
          ),
        ),
        onPressed: () {
          Haptics.tap();
          context.push('/dashboard/events/create');
        },
      ),
      body: async.when(
        loading: () => _buildLoading(),
        error: (e, _) => ErrorStateWidget(
          title: 'errors.generic'.tr(),
          onRetry: () => ref.invalidate(communityCalendarProvider(_params)),
        ),
        data: (entries) => _buildContent(entries),
      ),
    );
  }

  Widget _buildLoading() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        ShimmerSkeleton(height: 320, borderRadius: 16),
        SizedBox(height: 16),
        ShimmerSkeleton(height: 80),
        SizedBox(height: 8),
        ShimmerSkeleton(height: 80),
        SizedBox(height: 8),
        ShimmerSkeleton(height: 80),
      ],
    );
  }

  Widget _buildContent(List<CommunityCalendarEntry> entries) {
    final selectedEntries = _selectedDay != null
        ? _eventsForDay(entries, _selectedDay!)
        : _eventsForDay(entries, _focusedDay);

    return Column(
      children: [
        _buildLegend(),
        _buildCalendar(entries),
        const Divider(color: AppColors.line, height: 1),
        Expanded(
          child: selectedEntries.isEmpty
              ? EmptyStateWidget(
                  icon: LucideIcons.calendarX,
                  title: 'communityCalendar.noEntriesDay'.tr(),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  itemCount: selectedEntries.length,
                  itemBuilder: (_, i) => _EntryCard(
                    entry: selectedEntries[i],
                    onExport: () => _exportToCalendar(selectedEntries[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCalendar(List<CommunityCalendarEntry> entries) {
    return TableCalendar<CommunityCalendarEntry>(
      firstDay: DateTime.utc(2020),
      lastDay: DateTime.utc(2030),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      calendarFormat: _calendarFormat,
      eventLoader: (day) => _eventsForDay(entries, day),
      startingDayOfWeek: StartingDayOfWeek.monday,
      availableCalendarFormats: const {
        CalendarFormat.month: '',
        CalendarFormat.twoWeeks: '',
        CalendarFormat.week: '',
      },
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        defaultTextStyle: AppTypography.body(size: 14, color: AppColors.ink),
        weekendTextStyle:
            AppTypography.body(size: 14, color: AppColors.inkSoft),
        selectedTextStyle:
            AppTypography.body(size: 14, color: AppColors.surface, weight: FontWeight.w700),
        todayTextStyle:
            AppTypography.body(size: 14, color: AppColors.amber, weight: FontWeight.w600),
        selectedDecoration: const BoxDecoration(
          color: AppColors.primary500,
          shape: BoxShape.circle,
        ),
        todayDecoration: BoxDecoration(
          color: AppColors.amber.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        markerDecoration: const BoxDecoration(
          color: AppColors.primary500,
          shape: BoxShape.circle,
        ),
        markersMaxCount: 4,
        cellMargin: const EdgeInsets.all(4),
      ),
      headerStyle: HeaderStyle(
        formatButtonVisible: true,
        titleCentered: true,
        formatButtonDecoration: BoxDecoration(
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(8),
        ),
        formatButtonTextStyle: AppTypography.label(size: 11, color: AppColors.inkSoft),
        titleTextStyle: AppTypography.body(size: 15, weight: FontWeight.w600, color: AppColors.ink),
        leftChevronIcon: const Icon(LucideIcons.chevronLeft, size: 18, color: AppColors.inkSoft),
        rightChevronIcon: const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.inkSoft),
        headerPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: const BoxDecoration(color: Colors.transparent),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        weekdayStyle: AppTypography.label(size: 11, color: AppColors.mute),
        weekendStyle: AppTypography.label(size: 11, color: AppColors.mute),
      ),
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, day, dayEntries) {
          if (dayEntries.isEmpty) return null;
          return Positioned(
            bottom: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: dayEntries.take(4).map((e) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: e.color,
                    shape: BoxShape.circle,
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
      onDaySelected: (selectedDay, focusedDay) {
        Haptics.select();
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      onFormatChanged: (format) {
        setState(() => _calendarFormat = format);
      },
      onPageChanged: (focusedDay) {
        setState(() {
          _focusedDay = focusedDay;
          _selectedDay = null;
        });
      },
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          _LegendDot(color: AppColors.primary500, label: 'communityCalendar.typeEvent'.tr()),
          _LegendDot(color: AppColors.leben, label: 'communityCalendar.typeTimebank'.tr()),
          _LegendDot(color: AppColors.teal, label: 'communityCalendar.typeGroup'.tr()),
          _LegendDot(color: AppColors.trust, label: 'communityCalendar.typeSkill'.tr()),
        ],
      ),
    );
  }

  Future<void> _exportToCalendar(CommunityCalendarEntry entry) async {
    try {
      Haptics.tap();
      final endDate = entry.endDate ?? entry.startDate.add(const Duration(hours: 1));
      final event = a2c.Event(
        title: entry.title,
        description: entry.description ?? '',
        location: entry.locationName ?? '',
        startDate: entry.startDate,
        endDate: endDate,
        allDay: false,
      );
      final added = await a2c.Add2Calendar.addEvent2Cal(event);
      if (!added && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('events.calendarNotOpened'.tr())),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('events.exportFailed'.tr())),
        );
      }
    }
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: AppTypography.label(size: 11, color: AppColors.inkSoft)),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  final CommunityCalendarEntry entry;
  final VoidCallback onExport;

  const _EntryCard({required this.entry, required this.onExport});

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(entry.startDate);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: entry.color, width: 3),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: entry.routePath != null
            ? () {
                Haptics.select();
                context.push(entry.routePath!);
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _TypeBadge(type: entry.type, color: entry.color),
                        const SizedBox(width: 8),
                        Text(
                          timeStr,
                          style: AppTypography.mono(size: 11, color: AppColors.mute),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.title,
                      style: AppTypography.body(size: 14, weight: FontWeight.w600, color: AppColors.ink),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (entry.locationName != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(LucideIcons.mapPin, size: 11, color: AppColors.mute),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              entry.locationName!,
                              style: AppTypography.label(size: 11, color: AppColors.mute),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.calendarPlus, size: 18, color: AppColors.mute),
                tooltip: 'events.addToCalendar'.tr(),
                onPressed: onExport,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _TypeBadge extends StatelessWidget {
  final CommunityCalendarType type;
  final Color color;

  const _TypeBadge({required this.type, required this.color});

  @override
  Widget build(BuildContext context) {
    String key;
    IconData icon;
    switch (type) {
      case CommunityCalendarType.event:
        key = 'communityCalendar.typeEvent';
        icon = LucideIcons.calendarDays;
        break;
      case CommunityCalendarType.timebankSlot:
        key = 'communityCalendar.typeTimebank';
        icon = LucideIcons.clock;
        break;
      case CommunityCalendarType.groupMeeting:
        key = 'communityCalendar.typeGroup';
        icon = LucideIcons.users;
        break;
      case CommunityCalendarType.skillWindow:
        key = 'communityCalendar.typeSkill';
        icon = LucideIcons.star;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            key.tr(),
            style: AppTypography.label(size: 10, color: color),
          ),
        ],
      ),
    );
  }
}
