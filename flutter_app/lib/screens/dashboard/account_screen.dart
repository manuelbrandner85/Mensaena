/// SKILL: mensaena-features (P12 GDPR) — Account-Verwaltung
/// Daten-Export (JSON) + Account-Löschung (14-Tage-Frist).
library;

import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../providers/wave_final_providers.dart';
import '../../services/supabase_service.dart';
import '../../widgets/effects/glass_card.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});
  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _exporting = false;
  bool _requesting = false;

  Future<void> _exportData() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    setState(() => _exporting = true);
    try {
      final dump = <String, dynamic>{
        'exported_at': DateTime.now().toIso8601String(),
        'user_id': uid,
      };
      for (final t in [
        'profiles',
        'posts',
        'messages',
        'conversations',
        'interactions',
        'saved_posts',
        'user_follows',
        'trust_ratings',
        'karma_log',
        'event_attendees',
        'group_members',
        'community_polls',
        'community_poll_votes',
      ]) {
        try {
          final col = (t == 'profiles') ? 'id' : 'user_id';
          final rows = await sb.from(t).select().eq(col, uid).limit(10000);
          dump[t] = rows;
        } catch (_) {
          dump[t] = <Map<String, dynamic>>[];
        }
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/mensaena_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';
      final file = File(path);
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(dump));
      await Share.shareXFiles([XFile(path)],
          text: 'account.export_subject'.tr());
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('account.export_failed'.tr())));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _requestDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('account.delete_title'.tr(),
            style: AppTypography.display(size: 18, color: AppColors.ink)),
        content: Text('account.delete_body'.tr(),
            style: AppTypography.body(size: 14, color: AppColors.inkSoft)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.herzrotWarm),
            child: Text('account.delete_confirm'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _requesting = true);
    await ref.read(accountDeletionRepoProvider).request();
    ref.invalidate(accountDeletionStatusProvider);
    if (mounted) setState(() => _requesting = false);
  }

  Future<void> _cancelDeletion() async {
    await ref.read(accountDeletionRepoProvider).cancel();
    ref.invalidate(accountDeletionStatusProvider);
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(accountDeletionStatusProvider);
    return DashboardScaffold(
      title: 'account.title'.tr(),
      currentRoute: '/dashboard/account',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(LucideIcons.download,
                      size: 18, color: AppColors.bronze),
                  const SizedBox(width: 8),
                  Text('account.export_title'.tr(),
                      style: AppTypography.display(
                          size: 16, color: AppColors.ink)),
                ]),
                const SizedBox(height: 8),
                Text('account.export_body'.tr(),
                    style:
                        AppTypography.body(size: 13, color: AppColors.inkSoft)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _exporting ? null : _exportData,
                  icon: _exporting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child:
                              CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(LucideIcons.fileJson, size: 16),
                  label: Text('account.export_button'.tr()),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.bronze,
                    foregroundColor: AppColors.voidColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          status.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (req) {
              if (req != null) {
                final scheduledStr = req['scheduled_for'] as String?;
                final scheduled =
                    scheduledStr != null ? DateTime.tryParse(scheduledStr) : null;
                return GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(LucideIcons.clock,
                            size: 18, color: AppColors.herzrotWarm),
                        const SizedBox(width: 8),
                        Text('account.delete_pending'.tr(),
                            style: AppTypography.display(
                                size: 16, color: AppColors.ink)),
                      ]),
                      const SizedBox(height: 8),
                      if (scheduled != null)
                        Text(
                          'account.delete_scheduled_for'.tr(namedArgs: {
                            'date':
                                DateFormat('dd.MM.yyyy').format(scheduled),
                          }),
                          style: AppTypography.body(
                              size: 13, color: AppColors.inkSoft),
                        ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _cancelDeletion,
                        icon: const Icon(LucideIcons.undo2, size: 16),
                        label: Text('account.delete_cancel'.tr()),
                      ),
                    ],
                  ),
                );
              }
              return GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(LucideIcons.trash2,
                          size: 18, color: AppColors.herzrotWarm),
                      const SizedBox(width: 8),
                      Text('account.delete_title'.tr(),
                          style: AppTypography.display(
                              size: 16, color: AppColors.ink)),
                    ]),
                    const SizedBox(height: 8),
                    Text('account.delete_intro'.tr(),
                        style: AppTypography.body(
                            size: 13, color: AppColors.inkSoft)),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _requesting ? null : _requestDeletion,
                      icon: const Icon(LucideIcons.trash2, size: 16),
                      label: Text('account.delete_button'.tr()),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.herzrotWarm,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
