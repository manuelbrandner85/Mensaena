import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/admin_repository.dart';
import '../../../widgets/effects/shimmer_skeleton.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features (Admin Phase 5)
/// System overview: cleanup runner, platform stats, build info, audit log,
/// and external quick links. Stateful because the cleanup-runner stores its
/// last result + timestamp in widget-local state.
class AdminSystemScreen extends ConsumerStatefulWidget {
  const AdminSystemScreen({super.key});

  @override
  ConsumerState<AdminSystemScreen> createState() => _AdminSystemScreenState();
}

class _AdminSystemScreenState extends ConsumerState<AdminSystemScreen> {
  bool _cleanupRunning = false;
  Map<String, dynamic>? _lastCleanupResult;
  DateTime? _lastCleanupAt;

  Future<void> _runCleanup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('admin.system.cleanupConfirmTitle'.tr()),
        content: Text('admin.system.cleanupConfirmBody'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('common.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('admin.system.cleanupConfirmAction'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cleanupRunning = true);
    final result = await AdminRepository.runScheduledCleanup();
    if (!mounted) return;
    setState(() {
      _cleanupRunning = false;
      _lastCleanupResult = result;
      _lastCleanupAt = DateTime.now();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result != null
          ? 'admin.system.cleanupOk'.tr()
          : 'admin.system.cleanupFail'.tr()),
    ));
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // best-effort: silently ignore failures
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(adminStatsProvider);
    final auditAsync = ref.watch(adminAuditLogsProvider);
    return DashboardScaffold(
      title: 'admin.systemTitle'.tr(),
      currentRoute: '/dashboard/admin/system',
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _cleanupSection(),
            const SizedBox(height: 14),
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
                    child: CircularProgressIndicator(color: AppColors.amber),
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
            _section('Sicherheitsleitfaden', const [
              _NoteCard(
                icon: LucideIcons.shield,
                text:
                    'Anon-Posts (is_anonymous=true): keinerlei User-Infos im UI. '
                    'Block-Listen aus user_blocks vor Listen-Render anwenden. '
                    'Rate-Limit-Checks (check_rate_limit RPC) vor jedem Insert.',
              ),
            ]),
            const SizedBox(height: 14),
            _auditSection(auditAsync),
            const SizedBox(height: 14),
            _quickLinksSection(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Cleanup section
  // ---------------------------------------------------------------------------

  Widget _cleanupSection() {
    final result = _lastCleanupResult;
    final lastAt = _lastCleanupAt;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.sparkles, size: 20, color: AppColors.amber),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'admin.system.cleanupTitle'.tr(),
                  style: AppTypography.display(size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'admin.system.cleanupSubtitle'.tr(),
            style: AppTypography.caption(),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _cleanupRunning ? null : _runCleanup,
              icon: _cleanupRunning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.ink,
                      ),
                    )
                  : const Icon(LucideIcons.play, size: 16),
              label: Text(
                _cleanupRunning
                    ? 'admin.system.cleanupRunning'.tr()
                    : 'admin.system.cleanupStart'.tr(),
                style: AppTypography.body(
                  size: 14,
                  color: AppColors.ink,
                  weight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: AppColors.ink,
              ),
            ),
          ),
          if (lastAt != null) ...[
            const SizedBox(height: 10),
            Text(
              'admin.system.cleanupLastRun'.tr(namedArgs: {
                'time': DateFormat('dd.MM. HH:mm').format(lastAt.toLocal()),
              }),
              style: AppTypography.caption(),
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: result.entries.map(_resultChip).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _resultChip(MapEntry<String, dynamic> e) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(e.key, style: AppTypography.label(size: 9)),
          const SizedBox(width: 6),
          Text(
            '${e.value}',
            style: AppTypography.mono(
              size: 12,
              color: AppColors.ink,
              weight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Audit-log section
  // ---------------------------------------------------------------------------

  Widget _auditSection(AsyncValue<List<Map<String, dynamic>>> auditAsync) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.scrollText, size: 18, color: AppColors.tealSoft),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'admin.system.auditTitle'.tr(),
                  style: AppTypography.display(size: 16),
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.refreshCw, size: 16, color: AppColors.mute),
                onPressed: () => ref.invalidate(adminAuditLogsProvider),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 320,
            child: auditAsync.when(
              loading: () => ListView.separated(
                itemCount: 5,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, __) =>
                    const ShimmerBox(height: 44, borderRadius: 8),
              ),
              error: (_, __) => Center(
                child: Text(
                  'admin.system.auditError'.tr(),
                  style: AppTypography.caption(),
                ),
              ),
              data: (rows) {
                if (rows.isEmpty) {
                  return Center(
                    child: Text(
                      'admin.system.auditEmpty'.tr(),
                      style: AppTypography.caption(),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColors.line),
                  itemBuilder: (_, i) => _AuditRow(row: rows[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Quick-links section
  // ---------------------------------------------------------------------------

  Widget _quickLinksSection() {
    final links = <_QuickLink>[
      _QuickLink(
        icon: LucideIcons.database,
        label: 'admin.system.linkSupabase'.tr(),
        url: 'https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf',
      ),
      _QuickLink(
        icon: LucideIcons.terminal,
        label: 'admin.system.linkSql'.tr(),
        url: 'https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/sql/new',
      ),
      _QuickLink(
        icon: LucideIcons.cloud,
        label: 'admin.system.linkCloudflare'.tr(),
        url: 'https://dash.cloudflare.com',
      ),
      _QuickLink(
        icon: LucideIcons.github,
        label: 'admin.system.linkGitHub'.tr(),
        url: 'https://github.com/manuelbrandner85/Mensaena',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.externalLink, size: 18, color: AppColors.tealSoft),
              const SizedBox(width: 8),
              Text(
                'admin.system.quickLinks'.tr(),
                style: AppTypography.display(size: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...links.map(
            (l) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  hoverColor: AppColors.tealSoft.withValues(alpha: 0.08),
                  onTap: () => _openUrl(l.url),
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(l.icon, size: 18, color: AppColors.tealSoft),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.label,
                                style: AppTypography.body(
                                  size: 14,
                                  color: AppColors.ink,
                                  weight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l.url,
                                style: AppTypography.label(
                                  size: 10,
                                  color: AppColors.mute,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const Icon(LucideIcons.externalLink,
                            size: 14, color: AppColors.mute),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Generic helpers (preserved from previous StatelessWidget version)
  // ---------------------------------------------------------------------------

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

// =============================================================================
// Audit row + helpers
// =============================================================================

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.row});
  final Map<String, dynamic> row;

  static String _actionLabel(String? action) {
    switch (action) {
      case 'ban_user':
        return 'admin.system.act.banUser'.tr();
      case 'unban_user':
        return 'admin.system.act.unbanUser'.tr();
      case 'delete_user':
        return 'admin.system.act.deleteUser'.tr();
      case 'change_role':
        return 'admin.system.act.changeRole'.tr();
      case 'delete_post':
        return 'admin.system.act.deletePost'.tr();
      case 'resolve_report':
        return 'admin.system.act.resolveReport'.tr();
      case 'system_cleanup':
        return 'admin.system.act.cleanup'.tr();
      default:
        return action ?? '—';
    }
  }

  static IconData _iconForAction(String? action) {
    switch (action) {
      case 'ban_user':
      case 'unban_user':
        return LucideIcons.ban;
      case 'delete_user':
      case 'delete_post':
        return LucideIcons.trash2;
      case 'change_role':
        return LucideIcons.shieldCheck;
      case 'resolve_report':
        return LucideIcons.flag;
      case 'system_cleanup':
        return LucideIcons.sparkles;
      default:
        return LucideIcons.activity;
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = (row['action'] as String?);
    final profile = row['profiles'];
    final actor = (profile is Map && profile['name'] is String)
        ? profile['name'] as String
        : 'System';
    DateTime? created;
    final raw = row['created_at'];
    if (raw is String) {
      created = DateTime.tryParse(raw);
    }
    final stamp = created != null
        ? DateFormat('dd.MM. HH:mm').format(created.toLocal())
        : '—';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(_iconForAction(action), size: 14, color: AppColors.mute),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _actionLabel(action),
                  style: AppTypography.body(size: 12, color: AppColors.ink, height: 1.2),
                ),
                const SizedBox(height: 2),
                Text(actor, style: AppTypography.caption()),
              ],
            ),
          ),
          Text(stamp, style: AppTypography.caption()),
        ],
      ),
    );
  }
}

class _QuickLink {
  const _QuickLink({required this.icon, required this.label, required this.url});
  final IconData icon;
  final String label;
  final String url;
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
