/// SKILL: mensaena-features (P4) — Geplante Livestreams.
/// Liste kommender Streams + "Erinnerung an" Button + Host-Erstell-FAB.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/effects/glass_card.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

final scheduledStreamsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final rows = await sb
        .from('scheduled_streams')
        .select()
        .eq('is_cancelled', false)
        .gte('scheduled_at', DateTime.now().toIso8601String())
        .order('scheduled_at', ascending: true)
        .limit(100);
    return (rows as List).whereType<Map<String, dynamic>>().toList();
  } catch (_) {
    return const [];
  }
});

final myStreamRemindersProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  final uid = SupabaseService.currentUser?.id;
  if (uid == null) return const {};
  try {
    final rows = await sb
        .from('scheduled_stream_reminders')
        .select('stream_id')
        .eq('user_id', uid);
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map((r) => r['stream_id'] as String)
        .toSet();
  } catch (_) {
    return const {};
  }
});

class ScheduledStreamsScreen extends ConsumerWidget {
  const ScheduledStreamsScreen({super.key});

  Future<void> _toggleReminder(WidgetRef ref, String streamId,
      Set<String> current) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    if (current.contains(streamId)) {
      await sb
          .from('scheduled_stream_reminders')
          .delete()
          .eq('stream_id', streamId)
          .eq('user_id', uid);
    } else {
      await sb.from('scheduled_stream_reminders').insert({
        'stream_id': streamId,
        'user_id': uid,
      });
    }
    ref.invalidate(myStreamRemindersProvider);
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime? when;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => StatefulBuilder(builder: (_, setSheet) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: 20 + MediaQuery.of(sheetCtx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('live.schedule_title'.tr(),
                    style: AppTypography.display(
                        size: 18, color: AppColors.ink)),
                const SizedBox(height: 14),
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                      labelText: 'live.schedule_title_field'.tr(),
                      border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                      labelText: 'live.schedule_description'.tr(),
                      border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(LucideIcons.calendarClock,
                      color: AppColors.bronze),
                  title: Text(when == null
                      ? 'live.pick_time'.tr()
                      : DateFormat('dd.MM.yyyy HH:mm').format(when!)),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: sheetCtx,
                      initialDate: DateTime.now().add(const Duration(hours: 1)),
                      firstDate: DateTime.now(),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d == null || !sheetCtx.mounted) return;
                    final t = await showTimePicker(
                      context: sheetCtx,
                      initialTime: TimeOfDay.now(),
                    );
                    if (t == null) return;
                    setSheet(() =>
                        when = DateTime(d.year, d.month, d.day, t.hour, t.minute));
                  },
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: when == null || titleCtrl.text.trim().isEmpty
                      ? null
                      : () => Navigator.pop(sheetCtx, true),
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
      }),
    );
    if (ok != true || when == null) return;
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    try {
      await sb.from('scheduled_streams').insert({
        'host_id': uid,
        'title': titleCtrl.text.trim(),
        'description':
            descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        'scheduled_at': when!.toIso8601String(),
      });
      ref.invalidate(scheduledStreamsProvider);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(scheduledStreamsProvider);
    final reminders =
        ref.watch(myStreamRemindersProvider).maybeWhen(
              data: (s) => s,
              orElse: () => const <String>{},
            );
    final df = DateFormat('EEE dd.MM. HH:mm', 'de');
    return DashboardScaffold(
      title: 'live.scheduled_title'.tr(),
      currentRoute: '/dashboard/live/scheduled',
      onRefresh: () async {
        ref.invalidate(scheduledStreamsProvider);
        ref.invalidate(myStreamRemindersProvider);
        await Future<void>.delayed(const Duration(milliseconds: 250));
      },
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.bronze)),
        error: (_, __) => const SizedBox.shrink(),
        data: (streams) {
          if (streams.isEmpty) {
            return Stack(children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(LucideIcons.video,
                        size: 32, color: AppColors.mute),
                    const SizedBox(height: 8),
                    Text('live.no_scheduled'.tr(),
                        style: AppTypography.caption()),
                  ]),
                ),
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: _createFab(context, ref),
              ),
            ]);
          }
          return Stack(children: [
            ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            itemCount: streams.length,
            itemBuilder: (_, i) {
              final s = streams[i];
              final id = s['id'] as String;
              final when = DateTime.tryParse(s['scheduled_at'] as String? ?? '');
              final reminded = reminders.contains(id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    if (s['cover_url'] != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: s['cover_url'] as String,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.elevated,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(LucideIcons.video,
                            color: AppColors.bronze),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s['title'] as String? ?? '',
                              style: AppTypography.body(
                                  size: 14,
                                  color: AppColors.ink,
                                  weight: FontWeight.w700)),
                          if (when != null)
                            Text(df.format(when),
                                style: AppTypography.caption()),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: reminded
                          ? 'live.reminder_off'.tr()
                          : 'live.reminder_on'.tr(),
                      onPressed: () =>
                          _toggleReminder(ref, id, reminders),
                      icon: Icon(
                        reminded ? LucideIcons.bellOff : LucideIcons.bell,
                        size: 18,
                        color:
                            reminded ? AppColors.bronze : AppColors.inkSoft,
                      ),
                    ),
                  ]),
                ),
              );
            },
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: _createFab(context, ref),
          ),
          ]);
        },
      ),
    );
  }

  Widget _createFab(BuildContext context, WidgetRef ref) =>
      FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        backgroundColor: AppColors.bronze,
        icon: const Icon(LucideIcons.calendarPlus,
            color: AppColors.voidColor),
        label: Text('live.schedule_button'.tr(),
            style: AppTypography.body(
                size: 13,
                color: AppColors.voidColor,
                weight: FontWeight.w700)),
      );
}
