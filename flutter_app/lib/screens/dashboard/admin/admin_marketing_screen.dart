/// SKILL: mensaena-features + mensaena-design
/// Marketing-Admin-Screen (Phase 1): Uebersicht, E-Mail-Kampagnen, Push-
/// Kampagnen, Segmente, globale Notbremse. NUR Admin (Router-Guard +
/// serverseitige RPCs/Functions pruefen role='admin').
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/marketing_repository.dart';
import '../../../services/haptics.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

class AdminMarketingScreen extends ConsumerStatefulWidget {
  const AdminMarketingScreen({super.key});
  @override
  ConsumerState<AdminMarketingScreen> createState() =>
      _AdminMarketingScreenState();
}

class _AdminMarketingScreenState extends ConsumerState<AdminMarketingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 8, vsync: this);
  final _repo = MarketingRepository();

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'marketing.title'.tr(),
      currentRoute: '/dashboard/admin/marketing',
      body: SafeArea(
        child: Column(
          children: [
            TabBar(
              controller: _tab,
              isScrollable: true,
              labelColor: AppColors.bronze,
              unselectedLabelColor: AppColors.mute,
              indicatorColor: AppColors.bronze,
              labelStyle: AppTypography.label(size: 11),
              tabs: [
                Tab(text: 'marketing.tab_overview'.tr()),
                Tab(text: 'marketing.tab_email'.tr()),
                Tab(text: 'marketing.tab_push'.tr()),
                Tab(text: 'marketing.tab_segments'.tr()),
                Tab(text: 'marketing.tab_templates'.tr()),
                Tab(text: 'marketing.tab_referrals'.tr()),
                Tab(text: 'marketing.tab_regions'.tr()),
                Tab(text: 'marketing.tab_settings'.tr()),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _OverviewTab(repo: _repo),
                  _EmailTab(repo: _repo),
                  _PushTab(repo: _repo),
                  _SegmentsTab(repo: _repo),
                  _TemplatesTab(repo: _repo),
                  _ReferralsTab(repo: _repo),
                  _RegionsTab(repo: _repo),
                  _SettingsTab(repo: _repo),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 1) Übersicht ────────────────────────────────────────────────────────────
class _OverviewTab extends StatefulWidget {
  const _OverviewTab({required this.repo});
  final MarketingRepository repo;
  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  late Future<MarketingDashboardStats> _f = widget.repo.stats();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.bronze,
      onRefresh: () async => setState(() => _f = widget.repo.stats()),
      child: FutureBuilder<MarketingDashboardStats>(
        future: _f,
        builder: (c, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.bronze));
          }
          final s = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (s.marketingPaused)
                _PausedBanner(),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.6,
                children: [
                  _StatTile(label: 'marketing.stat_new_week'.tr(), value: '${s.newUsersWeek}'),
                  _StatTile(label: 'marketing.stat_new_30d'.tr(), value: '${s.newUsers30d}'),
                  _StatTile(label: 'marketing.stat_referrals_30d'.tr(), value: '${s.referralsCompleted30d}'),
                  _StatTile(label: 'marketing.stat_email_subs'.tr(), value: '${s.emailOptIn}'),
                  _StatTile(label: 'marketing.stat_marketing_subs'.tr(), value: '${s.marketingOptIn}'),
                  _StatTile(label: 'marketing.stat_reactivation_subs'.tr(), value: '${s.reactivationOptIn}'),
                  _StatTile(label: 'marketing.stat_email_sent_30d'.tr(), value: '${s.emailSent30d}'),
                  _StatTile(label: 'marketing.stat_email_open_rate'.tr(), value: '${s.emailOpenRate30d}%'),
                  _StatTile(label: 'marketing.stat_email_click_rate'.tr(), value: '${s.emailClickRate30d}%'),
                  _StatTile(label: 'marketing.stat_push_sent_30d'.tr(), value: '${s.pushSent30d}'),
                ],
              ),
              const SizedBox(height: 18),
              Text('marketing.top_regions'.tr(),
                  style: AppTypography.label(size: 11, color: AppColors.mute)),
              const SizedBox(height: 8),
              ...s.topRegions.map((r) => ListTile(
                    dense: true,
                    leading: const Icon(LucideIcons.mapPin,
                        size: 16, color: AppColors.bronze),
                    title: Text(r['name']?.toString() ?? '–',
                        style: AppTypography.body(size: 13, color: AppColors.ink)),
                    trailing: Text('${r['users']} 👥',
                        style: AppTypography.label(size: 11)),
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: AppTypography.label(size: 10, color: AppColors.mute)),
          Text(value,
              style: AppTypography.display(size: 22, color: AppColors.ink)),
        ],
      ),
    );
  }
}

class _PausedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.herzrot.withValues(alpha: 0.10),
        border: Border.all(color: AppColors.herzrot.withValues(alpha: 0.40)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        const Icon(LucideIcons.alertOctagon,
            size: 18, color: AppColors.herzrot),
        const SizedBox(width: 10),
        Expanded(
          child: Text('marketing.paused_banner'.tr(),
              style: AppTypography.body(size: 13, color: AppColors.ink)),
        ),
      ]),
    );
  }
}

// ── 2) E-Mail-Kampagnen ────────────────────────────────────────────────────
class _EmailTab extends StatefulWidget {
  const _EmailTab({required this.repo});
  final MarketingRepository repo;
  @override
  State<_EmailTab> createState() => _EmailTabState();
}

class _EmailTabState extends State<_EmailTab> {
  late Future<List<Map<String, dynamic>>> _f = widget.repo.listEmailCampaigns();

  void _refresh() => setState(() => _f = widget.repo.listEmailCampaigns());

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      RefreshIndicator(
        color: AppColors.bronze,
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _f,
          builder: (c, snap) {
            final rows = snap.data ?? const <Map<String, dynamic>>[];
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: rows.isEmpty
                  ? [
                      Center(
                          child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text('marketing.email_empty'.tr(),
                            style: AppTypography.caption()),
                      ))
                    ]
                  : rows.map(_row).toList(),
            );
          },
        ),
      ),
      Positioned(
        right: 16,
        bottom: 16,
        child: FloatingActionButton.extended(
          backgroundColor: AppColors.bronze,
          foregroundColor: AppColors.voidColor,
          onPressed: () => _composeDialog(context),
          icon: const Icon(LucideIcons.mailPlus, size: 18),
          label: Text('marketing.email_compose'.tr()),
        ),
      ),
    ]);
  }

  Widget _row(Map<String, dynamic> r) {
    final id = r['id']?.toString() ?? '';
    final status = (r['status'] ?? 'draft').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(r['subject']?.toString() ?? '(ohne Betreff)',
                  style: AppTypography.body(
                      size: 14, color: AppColors.ink, weight: FontWeight.w700)),
            ),
            _StatusChip(status: status),
          ]),
          const SizedBox(height: 6),
          Text(
            'marketing.email_meta'.tr(namedArgs: {
              'sent': '${r['sent_count'] ?? 0}',
              'open': '${r['open_count'] ?? 0}',
              'click': '${r['click_count'] ?? 0}',
            }),
            style: AppTypography.label(size: 10, color: AppColors.mute),
          ),
          if (status == 'draft')
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _confirmSend(id),
                icon: const Icon(LucideIcons.send,
                    size: 14, color: AppColors.bronze),
                label: Text('marketing.email_send'.tr(),
                    style: AppTypography.label(size: 11, color: AppColors.bronze)),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _composeDialog(BuildContext context) async {
    final subjectCtrl = TextEditingController();
    final htmlCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('marketing.email_compose'.tr(),
            style: AppTypography.display(size: 16, color: AppColors.ink)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: subjectCtrl,
              decoration: InputDecoration(
                  labelText: 'marketing.email_subject'.tr()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: htmlCtrl,
              maxLines: 8,
              decoration: InputDecoration(
                  labelText: 'marketing.email_html'.tr()),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('common.cancel'.tr())),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('marketing.email_save_draft'.tr())),
        ],
      ),
    );
    if (ok == true) {
      final s = subjectCtrl.text.trim();
      final h = htmlCtrl.text.trim();
      if (s.isEmpty || h.isEmpty) return;
      Haptics.tap();
      await widget.repo.createEmailCampaign(subject: s, html: h);
      if (mounted) _refresh();
    }
  }

  Future<void> _confirmSend(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('marketing.email_send_confirm_title'.tr()),
        content: Text('marketing.email_send_confirm_body'.tr()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('common.cancel'.tr())),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.bronze),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('marketing.email_send'.tr())),
        ],
      ),
    );
    if (ok != true) return;
    final r = await widget.repo.sendEmailCampaign(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('marketing.sent_result'.tr(namedArgs: {
        'sent': '${r['sent'] ?? 0}',
        'failed': '${r['failed'] ?? 0}',
      })),
    ));
    _refresh();
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = status == 'sent' ? AppColors.leben : AppColors.amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(status, style: AppTypography.label(size: 9, color: color)),
    );
  }
}

// ── 3) Push-Kampagnen ──────────────────────────────────────────────────────
class _PushTab extends StatefulWidget {
  const _PushTab({required this.repo});
  final MarketingRepository repo;
  @override
  State<_PushTab> createState() => _PushTabState();
}

class _PushTabState extends State<_PushTab> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _link = TextEditingController(text: '/dashboard/settings');
  bool _sending = false;
  String? _result;

  Future<void> _send() async {
    if (_sending) return;
    final t = _title.text.trim();
    final b = _body.text.trim();
    if (t.isEmpty || b.isEmpty) return;
    setState(() => _sending = true);
    final r = await widget.repo.sendPushCampaign(title: t, body: b, link: _link.text.trim());
    if (!mounted) return;
    setState(() {
      _sending = false;
      _result = 'sent ${r['sent'] ?? 0} / skipped ${r['skipped'] ?? 0}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('marketing.push_hint'.tr(),
            style: AppTypography.caption()),
        const SizedBox(height: 12),
        TextField(
            controller: _title,
            decoration:
                InputDecoration(labelText: 'marketing.push_title'.tr())),
        const SizedBox(height: 8),
        TextField(
            controller: _body,
            maxLines: 3,
            decoration: InputDecoration(labelText: 'marketing.push_body'.tr())),
        const SizedBox(height: 8),
        TextField(
            controller: _link,
            decoration: InputDecoration(labelText: 'marketing.push_link'.tr())),
        const SizedBox(height: 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.bronze,
              foregroundColor: AppColors.voidColor,
              minimumSize: const Size.fromHeight(48)),
          onPressed: _sending ? null : _send,
          icon: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.voidColor))
              : const Icon(LucideIcons.send, size: 18),
          label: Text('marketing.push_send'.tr()),
        ),
        if (_result != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(_result!,
                style: AppTypography.body(size: 13, color: AppColors.lebenSoft)),
          ),
      ],
    );
  }
}

// ── 4) Segmente ─────────────────────────────────────────────────────────────
class _SegmentsTab extends StatefulWidget {
  const _SegmentsTab({required this.repo});
  final MarketingRepository repo;
  @override
  State<_SegmentsTab> createState() => _SegmentsTabState();
}

class _SegmentsTabState extends State<_SegmentsTab> {
  late Future<Map<String, dynamic>> _f = widget.repo.segmentCounts();
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.bronze,
      onRefresh: () async => setState(() => _f = widget.repo.segmentCounts()),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _f,
        builder: (c, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.bronze));
          }
          final s = snap.data!;
          final rows = [
            ('new_users_7d', 'marketing.seg_new_7d'.tr()),
            ('dormant_7d', 'marketing.seg_dormant_7d'.tr()),
            ('dormant_21d', 'marketing.seg_dormant_21d'.tr()),
            ('dormant_45d', 'marketing.seg_dormant_45d'.tr()),
            ('top_helpers', 'marketing.seg_top_helpers'.tr()),
            ('email_subs', 'marketing.seg_email_subs'.tr()),
            ('marketing_subs', 'marketing.seg_marketing_subs'.tr()),
          ];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: rows
                .map((e) => ListTile(
                      dense: true,
                      title: Text(e.$2,
                          style: AppTypography.body(
                              size: 13, color: AppColors.ink)),
                      trailing: Text('${s[e.$1] ?? 0}',
                          style: AppTypography.display(
                              size: 16, color: AppColors.bronze)),
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}

// ── 5) Notbremse + Einstellungen ────────────────────────────────────────────
class _SettingsTab extends StatefulWidget {
  const _SettingsTab({required this.repo});
  final MarketingRepository repo;
  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  bool? _paused;

  @override
  void initState() {
    super.initState();
    widget.repo.stats().then((s) {
      if (mounted) setState(() => _paused = s.marketingPaused);
    });
  }

  Future<void> _toggle(bool v) async {
    setState(() => _paused = v);
    try {
      await widget.repo.setPaused(v);
    } catch (_) {
      if (mounted) setState(() => _paused = !v);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.elevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.herzrot.withValues(alpha: 0.30)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(LucideIcons.alertOctagon,
                  size: 18, color: AppColors.herzrot),
              const SizedBox(width: 8),
              Text('marketing.kill_switch'.tr(),
                  style: AppTypography.display(size: 15, color: AppColors.ink)),
            ]),
            const SizedBox(height: 6),
            Text('marketing.kill_switch_hint'.tr(),
                style: AppTypography.caption()),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('marketing.kill_switch_label'.tr(),
                  style: AppTypography.body(size: 13, color: AppColors.ink)),
              value: _paused ?? false,
              onChanged: _paused == null ? null : _toggle,
            ),
          ]),
        ),
      ],
    );
  }
}

// ── Phase 2: 5) Vorlagen-Editor ────────────────────────────────────────────
class _TemplatesTab extends StatefulWidget {
  const _TemplatesTab({required this.repo});
  final MarketingRepository repo;
  @override
  State<_TemplatesTab> createState() => _TemplatesTabState();
}

class _TemplatesTabState extends State<_TemplatesTab> {
  late Future<List<Map<String, dynamic>>> _f = widget.repo.listTemplates();
  void _refresh() => setState(() => _f = widget.repo.listTemplates());

  Future<void> _edit({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(
        text: existing?['name']?.toString() ?? '');
    final subjCtrl = TextEditingController(
        text: existing?['subject']?.toString() ?? '');
    final bodyCtrl = TextEditingController(
        text: (existing?['body_html'] ?? existing?['body_text'] ?? '').toString());
    String kind = existing?['kind']?.toString() ?? 'email';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(existing == null
              ? 'marketing.tpl_new'.tr()
              : 'marketing.tpl_edit'.tr()),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(labelText: 'marketing.tpl_name'.tr())),
              const SizedBox(height: 8),
              Row(children: [
                ChoiceChip(
                  label: const Text('E-Mail'),
                  selected: kind == 'email',
                  onSelected: (_) => setLocal(() => kind = 'email'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Push'),
                  selected: kind == 'push',
                  onSelected: (_) => setLocal(() => kind = 'push'),
                ),
              ]),
              const SizedBox(height: 8),
              TextField(
                  controller: subjCtrl,
                  decoration: InputDecoration(
                      labelText: 'marketing.tpl_subject'.tr())),
              const SizedBox(height: 8),
              TextField(
                  controller: bodyCtrl,
                  maxLines: 8,
                  decoration: InputDecoration(
                      labelText: 'marketing.tpl_body'.tr(),
                      hintText: '{vorname} {region} {karma}')),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('common.cancel'.tr())),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('common.save'.tr())),
          ],
        ),
      ),
    );
    if (ok == true) {
      final n = nameCtrl.text.trim();
      if (n.isEmpty) return;
      await widget.repo.upsertTemplate(
        id: existing?['id']?.toString(),
        name: n,
        kind: kind,
        subject: subjCtrl.text.trim(),
        bodyHtml: kind == 'email' ? bodyCtrl.text : null,
        bodyText: kind == 'push' ? bodyCtrl.text : null,
      );
      if (mounted) _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      RefreshIndicator(
        color: AppColors.bronze,
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _f,
          builder: (c, snap) {
            final rows = snap.data ?? const <Map<String, dynamic>>[];
            if (rows.isEmpty) {
              return ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                      child: Text('marketing.tpl_empty'.tr(),
                          style: AppTypography.caption())),
                ),
              ]);
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: rows.map((r) {
                final kind = (r['kind'] ?? 'email').toString();
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.elevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(children: [
                    Icon(
                        kind == 'email'
                            ? LucideIcons.mail
                            : LucideIcons.bell,
                        size: 18,
                        color: AppColors.bronze),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r['name']?.toString() ?? '–',
                                style: AppTypography.body(
                                    size: 14,
                                    color: AppColors.ink,
                                    weight: FontWeight.w700)),
                            if (r['subject'] != null)
                              Text(r['subject'].toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.label(
                                      size: 10, color: AppColors.mute)),
                          ]),
                    ),
                    IconButton(
                        onPressed: () => _edit(existing: r),
                        icon: const Icon(LucideIcons.pencil,
                            size: 16, color: AppColors.mute)),
                    IconButton(
                        onPressed: () async {
                          await widget.repo.deleteTemplate(r['id'].toString());
                          if (mounted) _refresh();
                        },
                        icon: const Icon(LucideIcons.trash2,
                            size: 16, color: AppColors.herzrot)),
                  ]),
                );
              }).toList(),
            );
          },
        ),
      ),
      Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            backgroundColor: AppColors.bronze,
            foregroundColor: AppColors.voidColor,
            onPressed: () => _edit(),
            icon: const Icon(LucideIcons.plus, size: 18),
            label: Text('marketing.tpl_new'.tr()),
          )),
    ]);
  }
}

// ── Phase 2: 7) Empfehlungs-Übersicht ──────────────────────────────────────
class _ReferralsTab extends StatefulWidget {
  const _ReferralsTab({required this.repo});
  final MarketingRepository repo;
  @override
  State<_ReferralsTab> createState() => _ReferralsTabState();
}

class _ReferralsTabState extends State<_ReferralsTab> {
  late Future<Map<String, dynamic>> _f = widget.repo.referralsOverview();
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.bronze,
      onRefresh: () async => setState(() => _f = widget.repo.referralsOverview()),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _f,
        builder: (c, snap) {
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.bronze));
          }
          final d = snap.data!;
          final totals = Map<String, dynamic>.from((d['totals'] as Map?) ?? const {});
          final top = ((d['top_referrers'] as List?) ?? const [])
              .whereType<Map<dynamic, dynamic>>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                Expanded(
                    child: _StatTile(
                        label: 'marketing.ref_completed_30d'.tr(),
                        value: '${totals['completed_30d'] ?? 0}')),
                const SizedBox(width: 10),
                Expanded(
                    child: _StatTile(
                        label: 'marketing.ref_pending_30d'.tr(),
                        value: '${totals['pending_30d'] ?? 0}')),
              ]),
              const SizedBox(height: 18),
              Text('marketing.top_referrers'.tr(),
                  style: AppTypography.label(size: 11, color: AppColors.mute)),
              const SizedBox(height: 8),
              ...top.map((r) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.elevated,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Row(children: [
                      const Icon(LucideIcons.userPlus,
                          size: 18, color: AppColors.bronze),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  (r['name'] ?? r['nickname'] ?? '–').toString(),
                                  style: AppTypography.body(
                                      size: 14, color: AppColors.ink)),
                              Text(
                                  'marketing.ref_meta'.tr(namedArgs: {
                                    'completed': '${r['completed'] ?? 0}',
                                    'total': '${r['total'] ?? 0}',
                                    'karma': '${r['karma_points'] ?? 0}',
                                  }),
                                  style: AppTypography.label(
                                      size: 10, color: AppColors.mute)),
                            ]),
                      ),
                    ]),
                  )),
            ],
          );
        },
      ),
    );
  }
}

// ── Phase 2: 8) Region-Manager ─────────────────────────────────────────────
class _RegionsTab extends StatefulWidget {
  const _RegionsTab({required this.repo});
  final MarketingRepository repo;
  @override
  State<_RegionsTab> createState() => _RegionsTabState();
}

class _RegionsTabState extends State<_RegionsTab> {
  late Future<List<Map<String, dynamic>>> _f = widget.repo.regionsOverview();
  Color _signal(String s) {
    switch (s) {
      case 'lebt':
        return AppColors.leben;
      case 'braucht_hilfe':
        return AppColors.herzrot;
      case 'klein':
        return AppColors.mute;
      default:
        return AppColors.bronze;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.bronze,
      onRefresh: () async => setState(() => _f = widget.repo.regionsOverview()),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _f,
        builder: (c, snap) {
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.bronze));
          }
          final rows = snap.data!;
          if (rows.isEmpty) {
            return ListView(children: [
              Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                    child: Text('marketing.reg_empty'.tr(),
                        style: AppTypography.caption())),
              ),
            ]);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: rows.map((r) {
              final signal = (r['signal'] ?? 'normal').toString();
              final color = _signal(signal);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.elevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Row(children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r['name']?.toString() ?? '–',
                              style: AppTypography.body(
                                  size: 14,
                                  color: AppColors.ink,
                                  weight: FontWeight.w700)),
                          Text(
                              'marketing.reg_meta'.tr(namedArgs: {
                                'users': '${r['users'] ?? 0}',
                                'new': '${r['new_users_7d'] ?? 0}',
                                'active': '${r['active_7d'] ?? 0}',
                              }),
                              style: AppTypography.label(
                                  size: 10, color: AppColors.mute)),
                        ]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: color.withValues(alpha: 0.40)),
                    ),
                    child: Text(
                        'marketing.reg_signal_$signal'.tr(),
                        style: AppTypography.label(size: 9, color: color)),
                  ),
                ]),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
