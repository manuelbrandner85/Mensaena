import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/admin_repository.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features (Admin Phase 5)
/// System-Uebersicht: Plattform-Statistik, Build-Info, DB-Status.
class AdminSystemScreen extends ConsumerWidget {
  const AdminSystemScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminStatsProvider);
    return DashboardScaffold(
      title: 'admin.systemTitle'.tr(),
      currentRoute: '/dashboard/admin/system',
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('Backend', [
              _kv('Supabase Project', 'huaqldjkgyosefzfhjnf'),
              _kv('Region', 'EU (Frankfurt)'),
              _kv('Auth', 'JWT + RLS'),
              _kv('Storage', 'avatars · post-images · chat-images'),
            ]),
            const SizedBox(height: 14),
            _section('Plattform-Statistik', [
              statsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.amber),
                  ),
                ),
                error: (_, __) => Text('admin.statsLoadShort'.tr(),
                    style: AppTypography.caption()),
                data: (s) => Column(
                  children: [
                    _kv('Users', '${s.users}'),
                    _kv('Posts', '${s.posts}'),
                    _kv('Events', '${s.events}'),
                    _kv('Board-Einträge', '${s.boardPosts}'),
                    _kv('Krisen', '${s.crises}'),
                    _kv('Organisationen', '${s.organizations}'),
                    _kv('Farms', '${s.farms}'),
                    _kv('Offene Reports', '${s.reports}'),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 14),
            _section('Update-Kanaele', [
              _kv('Shorebird OTA',
                  'Auto-Patch bei jedem main-Push (Dart-only)'),
              _kv('APK-Release',
                  'GitHub Release + app_releases-Row (manueller mandatory-Flag)'),
              _kv('Mandatory-Trigger',
                  '[mandatory] / [force-update] / BREAKING:'),
            ]),
            const SizedBox(height: 14),
            _section('Sicherheitsleitfaden', [
              const _NoteCard(
                icon: LucideIcons.shield,
                text:
                    'Anon-Posts (is_anonymous=true): keinerlei User-Infos im UI. '
                    'Block-Listen aus user_blocks vor Listen-Render anwenden. '
                    'Rate-Limit-Checks (check_rate_limit RPC) vor jedem Insert.',
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.label(size: 10)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(k, style: AppTypography.caption()),
          ),
          Expanded(
            child: Text(
              v,
              style: AppTypography.mono(
                size: 12,
                color: AppColors.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppColors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTypography.body(
                size: 12,
                color: AppColors.inkSoft,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
