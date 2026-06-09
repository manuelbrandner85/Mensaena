/// SKILL: mensaena-features (P12) — Admin-Übersicht aller Crash-Logs.
/// Liest crash_logs der letzten 7 Tage, gruppiert nach error_type.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../providers/role_provider.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/effects/glass_card.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

final _crashLogsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final since =
        DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
    // Liest aus error_logs (Live-Source aus main.dart) UND crash_logs.
    final results = await Future.wait([
      sb
          .from('error_logs')
          .select()
          .gte('created_at', since)
          .order('created_at', ascending: false)
          .limit(300)
          .then((r) => (r as List).whereType<Map<String, dynamic>>().toList()),
      sb
          .from('crash_logs')
          .select()
          .gte('created_at', since)
          .order('created_at', ascending: false)
          .limit(200)
          .then((r) => (r as List).whereType<Map<String, dynamic>>().toList()),
    ]);
    final merged = <Map<String, dynamic>>[
      ...results[0].map((r) => {
            ...r,
            'error_message': r['message'] ?? r['error_message'],
            'stack_trace': r['stack'] ?? r['stack_trace'],
            'build_number': r['build_number'] ?? 0,
          }),
      ...results[1],
    ];
    merged.sort((a, b) {
      final aT = DateTime.tryParse(a['created_at'] as String? ?? '')?.toUtc();
      final bT = DateTime.tryParse(b['created_at'] as String? ?? '')?.toUtc();
      if (aT == null || bT == null) return 0;
      return bT.compareTo(aT);
    });
    return merged.take(500).toList();
  } catch (_) {
    return const [];
  }
});

class AdminCrashLogsScreen extends ConsumerWidget {
  const AdminCrashLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(userRoleProvider) ?? 'user';
    if (role != 'admin' && role != 'super_admin' && role != 'moderator') {
      return DashboardScaffold(
        title: 'admin.crash_logs'.tr(),
        currentRoute: '/dashboard/admin/crash-logs',
        body: Center(
          child: Text('admin.no_access'.tr(),
              style: AppTypography.caption()),
        ),
      );
    }
    final async = ref.watch(_crashLogsProvider);
    final df = DateFormat('dd.MM. HH:mm:ss');
    return DashboardScaffold(
      title: 'admin.crash_logs'.tr(),
      currentRoute: '/dashboard/admin/crash-logs',
      onRefresh: () async {
        ref.invalidate(_crashLogsProvider);
        await Future<void>.delayed(const Duration(milliseconds: 250));
      },
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.bronze)),
        error: (_, __) => const SizedBox.shrink(),
        data: (rows) {
          if (rows.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(LucideIcons.checkCircle2,
                      size: 32, color: AppColors.leben),
                  const SizedBox(height: 8),
                  Text('admin.no_crashes'.tr(),
                      style: AppTypography.caption()),
                ]),
              ),
            );
          }
          // Group by error_type + error_message
          final groups = <String, List<Map<String, dynamic>>>{};
          for (final r in rows) {
            final key =
                '${r['error_type']}|${(r['error_message'] as String?)?.split('\n').first ?? '?'}';
            groups.putIfAbsent(key, () => []).add(r);
          }
          final sortedKeys = groups.keys.toList()
            ..sort((a, b) =>
                groups[b]!.length.compareTo(groups[a]!.length));
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: sortedKeys.length,
            itemBuilder: (_, i) {
              final key = sortedKeys[i];
              final group = groups[key]!;
              final parts = key.split('|');
              final type = parts.first;
              final msg = parts.skip(1).join('|');
              final last = group.first;
              final ts = DateTime.tryParse(
                      last['created_at'] as String? ?? '')?.toUtc() ??
                  DateTime.now();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.herzrotWarm
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(type,
                              style: AppTypography.label(
                                  size: 9, color: AppColors.herzrotWarm)),
                        ),
                        const SizedBox(width: 8),
                        Text('${group.length}x',
                            style: AppTypography.display(
                                size: 14, color: AppColors.bronze)),
                        const Spacer(),
                        Text(df.format(ts),
                            style: AppTypography.caption()),
                      ]),
                      const SizedBox(height: 6),
                      Text(
                        msg.length > 200 ? '${msg.substring(0, 200)}…' : msg,
                        style: AppTypography.body(
                            size: 12, color: AppColors.ink, height: 1.4),
                      ),
                      if (last['app_version'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'v${last['app_version']} (${last['build_number']}) · ${last['platform']}',
                            style: AppTypography.caption(),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
