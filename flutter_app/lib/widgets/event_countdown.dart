/// SKILL: mensaena-features
/// Countdown-Widget fuer upcoming Events.
/// Zeigt Tage/Stunden/Minuten in separaten Boxen, sub-Stunden auch Sekunden.
/// Nur sichtbar wenn 0 < diff <= 7 Tage. Timer-Tick je nach Naehe (60s oder 1s).
library;

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../config/theme/app_colors.dart';
import '../config/theme/app_typography.dart';

class EventCountdown extends StatefulWidget {
  const EventCountdown({required this.startsAt, super.key});

  final DateTime startsAt;

  @override
  State<EventCountdown> createState() => _EventCountdownState();
}

class _EventCountdownState extends State<EventCountdown> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _scheduleTick();
  }

  @override
  void didUpdateWidget(covariant EventCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startsAt != widget.startsAt) {
      _scheduleTick();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Recreate the periodic timer based on how close the event is.
  void _scheduleTick() {
    _timer?.cancel();
    final diff = widget.startsAt.difference(DateTime.now());
    final tickSeconds = diff.inMinutes < 60 ? 1 : 60;
    _timer = Timer.periodic(Duration(seconds: tickSeconds), (_) {
      if (!mounted) return;
      final newDiff = widget.startsAt.difference(DateTime.now());
      // Reschedule when crossing the 1h boundary.
      if ((newDiff.inMinutes < 60) != (tickSeconds == 1)) {
        _scheduleTick();
      }
      setState(() => _now = DateTime.now());
    });
  }

  @override
  Widget build(BuildContext context) {
    final diff = widget.startsAt.difference(_now);
    if (diff.isNegative || diff.inDays >= 7) {
      return const SizedBox.shrink();
    }

    final List<_CountdownCell> cells;
    if (diff.inHours < 1) {
      final minutes = diff.inMinutes;
      final seconds = diff.inSeconds - minutes * 60;
      cells = [
        _CountdownCell(value: diff.inHours, label: 'events.countdown.hours'.tr()),
        _CountdownCell(value: minutes, label: 'events.countdown.minutes'.tr()),
        _CountdownCell(value: seconds, label: 'events.countdown.seconds'.tr()),
      ];
    } else {
      final days = diff.inDays;
      final hours = diff.inHours - days * 24;
      final minutes = diff.inMinutes - diff.inHours * 60;
      cells = [
        _CountdownCell(value: days, label: 'events.countdown.days'.tr()),
        _CountdownCell(value: hours, label: 'events.countdown.hours'.tr()),
        _CountdownCell(value: minutes, label: 'events.countdown.minutes'.tr()),
      ];
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < cells.length; i++) ...[
          _buildBox(cells[i]),
          if (i < cells.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }

  Widget _buildBox(_CountdownCell cell) {
    return Container(
      width: 56,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.18),
        border: Border.all(color: AppColors.amber),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            cell.value.toString().padLeft(2, '0'),
            style: AppTypography.display(
              size: 24,
              color: AppColors.amber,
              weight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            cell.label,
            style: AppTypography.caption(color: AppColors.amber),
          ),
        ],
      ),
    );
  }
}

class _CountdownCell {
  const _CountdownCell({required this.value, required this.label});
  final int value;
  final String label;
}
