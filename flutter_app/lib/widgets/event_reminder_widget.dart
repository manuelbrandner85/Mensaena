/// SKILL: mensaena-features
/// Reminder-Widget fuer Event-Detail. Nur sichtbar wenn User attending.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../config/theme/app_colors.dart';
import '../config/theme/app_typography.dart';
import '../repositories/events_repository.dart';
import '../services/event_reminder_service.dart';

class EventReminderWidget extends ConsumerStatefulWidget {
  const EventReminderWidget({
    required this.eventId,
    required this.initialReminderMinutes,
    required this.eventStart,
    required this.eventTitle,
    super.key,
  });

  final String eventId;

  /// Startzeitpunkt + Titel werden gebraucht, um die LOKALE Benachrichtigung
  /// tatsächlich einzuplanen (vorher nur DB-Persistenz → keine Erinnerung).
  final DateTime eventStart;
  final String eventTitle;

  /// Null if the user has not configured a reminder yet.
  final int? initialReminderMinutes;

  @override
  ConsumerState<EventReminderWidget> createState() => _EventReminderWidgetState();
}

class _EventReminderWidgetState extends ConsumerState<EventReminderWidget> {
  int? _minutes;
  bool _busy = false;

  static const List<int> _options = [15, 30, 60, 120, 1440];

  @override
  void initState() {
    super.initState();
    _minutes = widget.initialReminderMinutes;
  }

  @override
  Widget build(BuildContext context) {
    if (_minutes == null) {
      return OutlinedButton.icon(
        onPressed: _busy ? null : () => _setReminder(60),
        icon: const Icon(LucideIcons.bellPlus, size: 16, color: AppColors.amber),
        label: Text(
          'events.reminder.setBtn'.tr(),
          style: AppTypography.body(
            size: 13,
            color: AppColors.amber,
            weight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.amber.withValues(alpha: 0.6)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.bell, color: AppColors.amber, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'events.reminder.activeLabel'.tr(),
                  style: AppTypography.body(
                    size: 13,
                    color: AppColors.ink,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'common.close'.tr(),
                onPressed: _busy ? null : _removeReminder,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(LucideIcons.x, color: AppColors.mute, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButton<int>(
            value: _options.contains(_minutes) ? _minutes : _options.first,
            isExpanded: true,
            dropdownColor: AppColors.elevated,
            style: AppTypography.body(size: 13, color: AppColors.ink),
            underline: const SizedBox.shrink(),
            iconEnabledColor: AppColors.amber,
            items: [
              for (final m in _options)
                DropdownMenuItem<int>(
                  value: m,
                  child: Text(_labelFor(m)),
                ),
            ],
            onChanged: _busy
                ? null
                : (value) {
                    if (value == null) return;
                    _setReminder(value);
                  },
          ),
        ],
      ),
    );
  }

  String _labelFor(int minutes) {
    switch (minutes) {
      case 15:
        return 'events.reminder.min15'.tr();
      case 30:
        return 'events.reminder.min30'.tr();
      case 60:
        return 'events.reminder.min60'.tr();
      case 120:
        return 'events.reminder.min120'.tr();
      case 1440:
        return 'events.reminder.oneDay'.tr();
      default:
        return '$minutes';
    }
  }

  Future<void> _setReminder(int minutes) async {
    setState(() => _busy = true);
    final ok = await EventsRepository.setReminder(
      eventId: widget.eventId,
      minutes: minutes,
    );
    if (ok) {
      // BUGFIX: vorher wurde nur reminder_minutes in der DB gespeichert, die
      // lokale Benachrichtigung aber NIE eingeplant → keine Erinnerung kam an.
      await EventReminderService.schedule(
        eventId: widget.eventId,
        eventStart: widget.eventStart,
        minutesBefore: minutes,
        title: widget.eventTitle,
      );
    }
    if (!mounted) return;
    setState(() {
      if (ok) _minutes = minutes;
      _busy = false;
    });
  }

  Future<void> _removeReminder() async {
    setState(() => _busy = true);
    final ok = await EventsRepository.removeReminder(widget.eventId);
    if (ok) await EventReminderService.cancel(widget.eventId);
    if (!mounted) return;
    setState(() {
      if (ok) _minutes = null;
      _busy = false;
    });
  }
}
