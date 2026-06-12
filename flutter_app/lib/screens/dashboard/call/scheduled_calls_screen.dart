/// SKILL: mensaena-features (P3) — Geplante Anrufe.
/// Liste eigener scheduled_calls + Cancel-Option.
library;

import 'package:add_2_calendar/add_2_calendar.dart' as a2c;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/calls_repository.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/effects/glass_card.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

final scheduledCallsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return CallsRepository.scheduledUpcoming();
});

class ScheduledCallsScreen extends ConsumerWidget {
  const ScheduledCallsScreen({super.key});

  Future<void> _cancel(WidgetRef ref, String id) async {
    final ok = await CallsRepository.scheduleCancel(id);
    if (ok) ref.invalidate(scheduledCallsProvider);
  }

  /// Öffnet das System-„Termin hinzufügen"-Dialog mit vorausgefüllten Daten.
  /// Keine CALENDAR-Permission nötig (Intent-basiert via add_2_calendar).
  Future<void> _addToCalendar(
    BuildContext context, {
    required String name,
    required DateTime when,
  }) async {
    final entry = a2c.Event(
      title: '${'call.videoAction'.tr()} — $name',
      startDate: when,
      endDate: when.add(const Duration(minutes: 30)),
      iosParams: const a2c.IOSParams(reminder: Duration(minutes: 15)),
      androidParams: const a2c.AndroidParams(emailInvites: <String>[]),
    );
    await a2c.Add2Calendar.addEvent2Cal(entry);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(scheduledCallsProvider);
    final me = SupabaseService.currentUser?.id;
    final df = DateFormat('EEE dd.MM. HH:mm', 'de');
    return DashboardScaffold(
      title: 'scheduled_calls.title'.tr(),
      currentRoute: '/dashboard/scheduled-calls',
      onRefresh: () async {
        ref.invalidate(scheduledCallsProvider);
        await Future<void>.delayed(const Duration(milliseconds: 250));
      },
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.bronze)),
        error: (_, __) => const SizedBox.shrink(),
        data: (rows) {
          if (rows.isEmpty || me == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(LucideIcons.phoneCall,
                      size: 32, color: AppColors.mute),
                  const SizedBox(height: 8),
                  Text('scheduled_calls.empty'.tr(),
                      style: AppTypography.caption()),
                ]),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: rows.length,
            itemBuilder: (_, i) {
              final r = rows[i];
              final partner = (r['caller_id'] == me)
                  ? r['callee'] as Map<String, dynamic>?
                  : r['caller'] as Map<String, dynamic>?;
              final name =
                  (partner?['display_name'] as String?) ?? 'mensaena';
              final avatar = partner?['avatar_url'] as String?;
              final when = DateTime.tryParse(r['scheduled_at'] as String)?.toUtc();
              final type = r['call_type'] as String? ?? 'audio';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    ClipOval(
                      child: avatar != null
                          ? CachedNetworkImage(
                              imageUrl: avatar,
                              width: 40,
                              height: 40,
                              memCacheWidth: 80,
                              memCacheHeight: 80,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 40,
                              height: 40,
                              color: AppColors.elevated,
                              alignment: Alignment.center,
                              child: Text(name[0].toUpperCase(),
                                  style: AppTypography.body(
                                      size: 14,
                                      color: AppColors.ink,
                                      weight: FontWeight.w700)),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(
                              type == 'video'
                                  ? LucideIcons.video
                                  : LucideIcons.phone,
                              size: 14,
                              color: AppColors.bronze,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(name,
                                  style: AppTypography.body(
                                      size: 14,
                                      color: AppColors.ink,
                                      weight: FontWeight.w700)),
                            ),
                          ]),
                          if (when != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(df.format(when),
                                  style: AppTypography.caption()),
                            ),
                        ],
                      ),
                    ),
                    if (when != null)
                      IconButton(
                        tooltip: 'contact.cta.add_calendar'.tr(),
                        onPressed: () =>
                            _addToCalendar(context, name: name, when: when),
                        icon: const Icon(LucideIcons.calendarPlus,
                            size: 18, color: AppColors.bronze),
                      ),
                    IconButton(
                      tooltip: 'common.cancel'.tr(),
                      onPressed: () => _cancel(ref, r['id'] as String),
                      icon: const Icon(LucideIcons.x,
                          size: 16, color: AppColors.herzrotWarm),
                    ),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ScheduleCallSheet extends ConsumerStatefulWidget {
  const ScheduleCallSheet({
    required this.calleeId,
    required this.calleeName,
    super.key,
  });
  final String calleeId;
  final String calleeName;

  static Future<bool?> show(
    BuildContext context, {
    required String calleeId,
    required String calleeName,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ScheduleCallSheet(
        calleeId: calleeId,
        calleeName: calleeName,
      ),
    );
  }

  @override
  ConsumerState<ScheduleCallSheet> createState() => _ScheduleCallSheetState();
}

class _ScheduleCallSheetState extends ConsumerState<ScheduleCallSheet> {
  DateTime? _when;
  String _type = 'audio';
  bool _saving = false;

  Future<void> _pick() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (t == null) return;
    setState(() => _when = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _save() async {
    if (_when == null) return;
    setState(() => _saving = true);
    final ok = await CallsRepository.scheduleCreate(
      calleeId: widget.calleeId,
      scheduledAt: _when!,
      callType: _type,
    );
    if (!mounted) return;
    if (ok) {
      ref.invalidate(scheduledCallsProvider);
      Navigator.pop(context, true);
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(LucideIcons.calendarClock,
                  size: 18, color: AppColors.bronze),
              const SizedBox(width: 8),
              Text('scheduled_calls.create_title'.tr(),
                  style: AppTypography.display(
                      size: 18, color: AppColors.ink)),
            ]),
            const SizedBox(height: 4),
            Text(widget.calleeName, style: AppTypography.caption()),
            const SizedBox(height: 14),
            Wrap(spacing: 6, children: [
              ChoiceChip(
                selected: _type == 'audio',
                label: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(LucideIcons.phone, size: 14),
                  const SizedBox(width: 6),
                  Text('call.audio'.tr()),
                ]),
                onSelected: (_) => setState(() => _type = 'audio'),
              ),
              ChoiceChip(
                selected: _type == 'video',
                label: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(LucideIcons.video, size: 14),
                  const SizedBox(width: 6),
                  Text('call.video'.tr()),
                ]),
                onSelected: (_) => setState(() => _type = 'video'),
              ),
            ]),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(LucideIcons.clock,
                  color: AppColors.bronze),
              title: Text(_when == null
                  ? 'live.pick_time'.tr()
                  : DateFormat('dd.MM.yyyy HH:mm').format(_when!)),
              onTap: _pick,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: (_when == null || _saving) ? null : _save,
              icon: const Icon(LucideIcons.send, size: 14),
              label: Text('common.save'.tr()),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.bronze,
                  foregroundColor: AppColors.voidColor,
                  minimumSize: const Size.fromHeight(44)),
            ),
          ],
        ),
      ),
    );
  }
}
