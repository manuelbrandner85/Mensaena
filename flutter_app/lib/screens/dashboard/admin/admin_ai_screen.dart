import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/ai_admin_repository.dart';
import '../../../widgets/effects/shimmer_skeleton.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features + mensaena-design
/// Zentrales KI-Steuerungs-Panel fürs Admin-Dashboard (Fundament).
///
/// Drei Bereiche:
///   1. KI-Tages-Zusammenfassung (Edge Function ai-admin-digest)
///   2. Feature-Flags — jedes KI-Feature einzeln an/aus (RPC set_ai_feature_flag)
///   3. KI-Audit — was die KI zuletzt getan/empfohlen hat
class AdminAiScreen extends ConsumerWidget {
  const AdminAiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DashboardScaffold(
      title: 'adminAi.title'.tr(),
      currentRoute: '/dashboard/admin/ai',
      onRefresh: () async {
        ref.invalidate(aiFlagsProvider);
        ref.invalidate(aiLatestDigestProvider);
        ref.invalidate(aiAuditProvider);
        await ref.read(aiFlagsProvider.future);
      },
      body: const SafeArea(
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _IntroCard(),
              SizedBox(height: 16),
              _DigestCard(),
              SizedBox(height: 16),
              _FlagsSection(),
              SizedBox(height: 16),
              _AuditCard(),
              SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Intro
// ---------------------------------------------------------------------------

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.teal.withValues(alpha: 0.16),
            AppColors.amber.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.30)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.sparkles, color: AppColors.teal, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('adminAi.title'.tr(),
                    style: AppTypography.display(
                        size: 18, color: AppColors.ink)),
                const SizedBox(height: 4),
                Text('adminAi.subtitle'.tr(),
                    style: AppTypography.body(
                        size: 13, color: AppColors.inkSoft, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tages-Zusammenfassung
// ---------------------------------------------------------------------------

class _DigestCard extends ConsumerStatefulWidget {
  const _DigestCard();

  @override
  ConsumerState<_DigestCard> createState() => _DigestCardState();
}

class _DigestCardState extends ConsumerState<_DigestCard> {
  bool _busy = false;

  Future<void> _generate() async {
    setState(() => _busy = true);
    final res = await AiAdminRepository.generateDigest(force: true);
    if (!mounted) return;
    setState(() => _busy = false);
    final err = res['error'] ?? (res['disabled'] == true ? 'disabled' : null);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['disabled'] == true
            ? 'adminAi.digestDisabled'.tr()
            : 'adminAi.digestFailed'.tr()),
      ));
      return;
    }
    ref.invalidate(aiLatestDigestProvider);
  }

  @override
  Widget build(BuildContext context) {
    final digest = ref.watch(aiLatestDigestProvider);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.fileText,
                  color: AppColors.amber, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('adminAi.digestTitle'.tr(),
                    style: AppTypography.display(
                        size: 16, color: AppColors.ink)),
              ),
              TextButton.icon(
                onPressed: _busy ? null : _generate,
                icon: _busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.amber))
                    : const Icon(LucideIcons.refreshCw, size: 14),
                label: Text(
                  _busy
                      ? 'adminAi.digestGenerating'.tr()
                      : 'adminAi.digestRefresh'.tr(),
                  style: AppTypography.body(
                      size: 12,
                      color: AppColors.amber,
                      weight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.amber,
                  minimumSize: const Size(0, 32),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          digest.when(
            loading: () => const ShimmerBox(height: 64, borderRadius: 10),
            error: (_, __) => Text('adminAi.digestEmpty'.tr(),
                style: AppTypography.caption()),
            data: (d) {
              final summary = (d?['summary'] ?? '').toString();
              if (summary.isEmpty) {
                return Text('adminAi.digestEmpty'.tr(),
                    style: AppTypography.body(
                        size: 13, color: AppColors.inkSoft, height: 1.4));
              }
              final stats = (d?['stats'] is Map)
                  ? Map<String, dynamic>.from(d!['stats'] as Map)
                  : <String, dynamic>{};
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(summary,
                      style: AppTypography.body(
                          size: 14, color: AppColors.ink, height: 1.5)),
                  if (stats.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _StatChips(stats: stats),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'adminAi.digestSource'.tr(namedArgs: {
                      'provider': (d?['provider'] ?? '—').toString(),
                    }),
                    style: AppTypography.caption(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatChips extends StatelessWidget {
  const _StatChips({required this.stats});
  final Map<String, dynamic> stats;

  static const _order = <String, String>{
    'new_users_24h': 'adminAi.stat.newUsers',
    'new_posts_24h': 'adminAi.stat.newPosts',
    'open_reports': 'adminAi.stat.openReports',
    'new_messages_24h': 'adminAi.stat.newMessages',
    'new_events_24h': 'adminAi.stat.newEvents',
    'active_crises': 'adminAi.stat.activeCrises',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in _order.entries)
          if (stats.containsKey(e.key))
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.elevated.withValues(alpha: 0.5),
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${stats[e.key] ?? 0}',
                      style: AppTypography.mono(
                          size: 13,
                          color: AppColors.ink,
                          weight: FontWeight.w800)),
                  const SizedBox(width: 6),
                  Text(e.value.tr(),
                      style: AppTypography.label(
                          size: 10, color: AppColors.mute)),
                ],
              ),
            ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Feature-Flags
// ---------------------------------------------------------------------------

class _FlagsSection extends ConsumerWidget {
  const _FlagsSection();

  static const _catIcons = <String, IconData>{
    'moderation': LucideIcons.shieldCheck,
    'growth': LucideIcons.trendingUp,
    'insights': LucideIcons.barChart3,
    'content': LucideIcons.penTool,
    'trust': LucideIcons.badgeCheck,
    'productivity': LucideIcons.zap,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(aiFlagsProvider);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('adminAi.featuresTitle'.tr(),
              style: AppTypography.display(size: 16, color: AppColors.ink)),
          const SizedBox(height: 2),
          Text('adminAi.featuresHint'.tr(), style: AppTypography.caption()),
          const SizedBox(height: 12),
          flags.when(
            loading: () => Column(
              children: List.generate(
                5,
                (_) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 5),
                  child: ShimmerBox(height: 56, borderRadius: 10),
                ),
              ),
            ),
            error: (_, __) => Text('adminAi.featuresEmpty'.tr(),
                style: AppTypography.caption()),
            data: (list) {
              if (list.isEmpty) {
                return Text('adminAi.featuresEmpty'.tr(),
                    style: AppTypography.caption());
              }
              // Nach Kategorie gruppieren (Reihenfolge via sort_order erhalten).
              final cats = <String, List<AiFeatureFlag>>{};
              for (final f in list) {
                cats.putIfAbsent(f.category, () => []).add(f);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final entry in cats.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 6),
                      child: Row(
                        children: [
                          Icon(
                            _catIcons[entry.key] ?? LucideIcons.sparkles,
                            size: 15,
                            color: AppColors.teal,
                          ),
                          const SizedBox(width: 8),
                          Text('adminAi.cat.${entry.key}'.tr(),
                              style: AppTypography.label(
                                  size: 11, color: AppColors.teal)),
                        ],
                      ),
                    ),
                    for (final f in entry.value) _FlagTile(flag: f),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FlagTile extends ConsumerStatefulWidget {
  const _FlagTile({required this.flag});
  final AiFeatureFlag flag;

  @override
  ConsumerState<_FlagTile> createState() => _FlagTileState();
}

class _FlagTileState extends ConsumerState<_FlagTile> {
  late bool _enabled = widget.flag.enabled;
  bool _busy = false;

  Future<void> _toggle(bool v) async {
    setState(() {
      _enabled = v;
      _busy = true;
    });
    final ok = await AiAdminRepository.toggleFlag(widget.flag.key, v);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      setState(() => _enabled = !v); // revert
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('adminAi.toggleFailed'.tr())),
      );
      return;
    }
    ref.invalidate(aiFlagsProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _enabled
            ? AppColors.teal.withValues(alpha: 0.07)
            : AppColors.surface.withValues(alpha: 0.4),
        border: Border.all(
          color: _enabled
              ? AppColors.teal.withValues(alpha: 0.30)
              : AppColors.line,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.flag.label,
                    style: AppTypography.body(
                        size: 13,
                        color: AppColors.ink,
                        weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(widget.flag.description,
                    style: AppTypography.caption()),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch.adaptive(
            value: _enabled,
            onChanged: _busy ? null : _toggle,
            activeTrackColor: AppColors.teal,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// KI-Audit
// ---------------------------------------------------------------------------

class _AuditCard extends ConsumerStatefulWidget {
  const _AuditCard();

  @override
  ConsumerState<_AuditCard> createState() => _AuditCardState();
}

class _AuditCardState extends ConsumerState<_AuditCard> {
  final Set<String> _deleting = {};
  bool _clearing = false;
  List<Map<String, dynamic>>? _localRows;

  String _relativeTime(DateTime? then) {
    if (then == null) return '';
    final diff = DateTime.now().difference(then);
    if (diff.inMinutes < 60) {
      return 'admin.relTime.minAgo'.tr(namedArgs: {'min': '${diff.inMinutes}'});
    }
    if (diff.inHours < 24) {
      return 'admin.relTime.hAgo'.tr(namedArgs: {'h': '${diff.inHours}'});
    }
    return 'admin.relTime.dAgo'.tr(namedArgs: {'d': '${diff.inDays}'});
  }

  Future<void> _deleteEntry(String id) async {
    setState(() => _deleting.add(id));
    final ok = await AiAdminRepository.deleteAuditEntry(id);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _localRows = (_localRows ?? []).where((r) => r['id'] != id).toList();
        _deleting.remove(id);
      });
    } else {
      setState(() => _deleting.remove(id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('adminAi.clearFailed'.tr())),
      );
    }
  }

  Future<void> _clearAll() async {
    setState(() => _clearing = true);
    final deleted = await AiAdminRepository.clearAudit();
    if (!mounted) return;
    setState(() => _clearing = false);
    if (deleted >= 0) {
      setState(() => _localRows = []);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('adminAi.clearFailed'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final audit = ref.watch(aiAuditProvider);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('adminAi.auditTitle'.tr(),
                    style:
                        AppTypography.display(size: 16, color: AppColors.ink)),
              ),
              audit.maybeWhen(
                data: (rows) {
                  final effective = _localRows ?? rows;
                  if (effective.isEmpty) return const SizedBox.shrink();
                  return TextButton.icon(
                    onPressed: _clearing ? null : _clearAll,
                    icon: _clearing
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.mute))
                        : const Icon(LucideIcons.trash2, size: 13),
                    label: Text('adminAi.auditClearAll'.tr(),
                        style: AppTypography.body(
                            size: 12,
                            color: AppColors.mute,
                            weight: FontWeight.w600)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.mute,
                      minimumSize: const Size(0, 28),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('adminAi.auditAutoDeleteNote'.tr(),
              style: AppTypography.caption()),
          const SizedBox(height: 8),
          audit.when(
            loading: () => Column(
              children: List.generate(
                3,
                (_) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: ShimmerBox(height: 40, borderRadius: 8),
                ),
              ),
            ),
            error: (_, __) => Text('adminAi.auditEmpty'.tr(),
                style: AppTypography.caption()),
            data: (rows) {
              if (_localRows == null) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => setState(() => _localRows = rows));
              }
              final effective = _localRows ?? rows;
              if (effective.isEmpty) {
                return Text('adminAi.auditEmpty'.tr(),
                    style: AppTypography.caption());
              }
              return Column(
                children: [
                  for (var i = 0; i < effective.length; i++) ...[
                    _auditRow(effective[i]),
                    if (i < effective.length - 1)
                      const Divider(
                          color: AppColors.line, height: 1, thickness: 1),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _auditRow(Map<String, dynamic> e) {
    final id = (e['id'] ?? '').toString();
    final feature = (e['feature'] ?? '').toString();
    final summary = (e['summary'] ?? '').toString();
    final createdRaw = e['created_at']?.toString();
    final created = createdRaw != null ? DateTime.tryParse(createdRaw)?.toUtc() : null;
    final isBusy = _deleting.contains(id);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(LucideIcons.sparkles, size: 15, color: AppColors.mute),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(feature.replaceAll('_', ' '),
                    style: AppTypography.body(
                        size: 12,
                        color: AppColors.inkSoft,
                        weight: FontWeight.w600)),
                if (summary.isNotEmpty)
                  Text(summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption()),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_relativeTime(created), style: AppTypography.caption()),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: isBusy || id.isEmpty ? null : () => _deleteEntry(id),
                child: isBusy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.mute))
                    : Icon(LucideIcons.x,
                        size: 14,
                        color: id.isEmpty
                            ? AppColors.line
                            : AppColors.mute.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
