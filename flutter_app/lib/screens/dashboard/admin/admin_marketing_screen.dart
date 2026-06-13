/// SKILL: mensaena-features + mensaena-design
/// Marketing-Admin-Screen (Phase 1): Uebersicht, E-Mail-Kampagnen, Push-
/// Kampagnen, Segmente, globale Notbremse. NUR Admin (Router-Guard +
/// serverseitige RPCs/Functions pruefen role='admin').
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/marketing_repository.dart';
import '../../../services/haptics.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/admin/marketing_preview.dart';
import '../../../widgets/shared/error_state_card.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/app_snackbar.dart';

class AdminMarketingScreen extends ConsumerStatefulWidget {
  const AdminMarketingScreen({super.key});
  @override
  ConsumerState<AdminMarketingScreen> createState() =>
      _AdminMarketingScreenState();
}

class _AdminMarketingScreenState extends ConsumerState<AdminMarketingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 9, vsync: this);
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
                Tab(text: 'marketing.tab_content'.tr()),
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
                  _ContentTab(repo: _repo),
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
          if (snap.hasError) {
            return ErrorStateCard(
              onRetry: () => setState(() => _f = widget.repo.stats()),
            );
          }
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
  int? _audience; // Anzahl email_opt_in (Empfänger-Vorschau)

  @override
  void initState() {
    super.initState();
    widget.repo.segmentCounts().then((m) {
      if (mounted) setState(() => _audience = (m['email_subs'] as num?)?.toInt());
    });
  }

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
              children: [
                _AudienceBanner(
                  icon: LucideIcons.mail,
                  label: 'marketing.audience_email'.tr(
                      namedArgs: {'count': '${_audience ?? '…'}'}),
                ),
                const SizedBox(height: 12),
                if (rows.isEmpty)
                  Center(
                      child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('marketing.email_empty'.tr(),
                        style: AppTypography.caption()),
                  ))
                else
                  ...rows.map(_row),
              ],
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
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: () => _previewCampaign(id),
                  icon: const Icon(LucideIcons.eye,
                      size: 14, color: AppColors.mute),
                  label: Text('marketing.preview'.tr(),
                      style: AppTypography.label(size: 11, color: AppColors.mute)),
                ),
                TextButton.icon(
                  onPressed: () => _testSend(id),
                  icon: const Icon(LucideIcons.send,
                      size: 14, color: AppColors.teal),
                  label: Text('marketing.test_send'.tr(),
                      style: AppTypography.label(size: 11, color: AppColors.teal)),
                ),
                if (status == 'draft')
                  TextButton.icon(
                    onPressed: () => _confirmSend(id),
                    icon: const Icon(LucideIcons.megaphone,
                        size: 14, color: AppColors.bronze),
                    label: Text('marketing.email_send'.tr(),
                        style: AppTypography.label(
                            size: 11, color: AppColors.bronze)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _composeDialog(BuildContext context) async {
    final subjectCtrl = TextEditingController();
    final htmlCtrl = TextEditingController();
    bool preview = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Row(children: [
            Expanded(
              child: Text('marketing.email_compose'.tr(),
                  style: AppTypography.display(size: 16, color: AppColors.ink)),
            ),
            _PreviewToggle(
                preview: preview,
                onChanged: (v) => setLocal(() => preview = v)),
          ]),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: preview
                  ? EmailPreview(
                      subject: subjectCtrl.text, html: htmlCtrl.text)
                  : Column(mainAxisSize: MainAxisSize.min, children: [
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
                            labelText: 'marketing.email_html'.tr(),
                            hintText: '<h1>…</h1>  {vorname} {region}'),
                      ),
                    ]),
            ),
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

  /// Vollbild-Vorschau einer bestehenden Kampagne (lädt den Body nach).
  Future<void> _previewCampaign(String id) async {
    final c = await widget.repo.getEmailCampaign(id);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('marketing.preview'.tr(),
            style: AppTypography.display(size: 16, color: AppColors.ink)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: EmailPreview(
              subject: c['subject']?.toString() ?? '',
              html: (c['body_html'] ?? c['body_text'] ?? '').toString(),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('common.close'.tr())),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
            onPressed: () {
              Navigator.pop(ctx);
              _testSend(id);
            },
            icon: const Icon(LucideIcons.send, size: 16),
            label: Text('marketing.test_send'.tr()),
          ),
        ],
      ),
    );
  }

  /// Test-Versand an die eigene Admin-Adresse (Backend `test_to`).
  Future<void> _testSend(String id) async {
    final email = SupabaseService.currentUser?.email;
    if (email == null || email.isEmpty) {
      if (!mounted) return;
      AppSnackBar.info(context, 'marketing.test_no_email'.tr());
      return;
    }
    Haptics.tap();
    final r = await widget.repo.sendEmailCampaign(id, testTo: email);
    if (!mounted) return;
    final ok = r['ok'] == true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'marketing.test_sent'.tr(namedArgs: {'email': email})
          : 'marketing.test_failed'.tr()),
    ));
  }

  Future<void> _confirmSend(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('marketing.email_send_confirm_title'.tr()),
        content: Text('marketing.email_send_confirm_count'.tr(
            namedArgs: {'count': '${_audience ?? '…'}'})),
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

/// Banner, das vor dem Versand zeigt, wie viele Empfänger es betrifft.
class _AudienceBanner extends StatelessWidget {
  const _AudienceBanner({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bronze.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.bronze.withValues(alpha: 0.30)),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: AppColors.bronze),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: AppTypography.body(size: 12, color: AppColors.ink)),
        ),
      ]),
    );
  }
}

/// Editor/Vorschau-Umschalter (kleiner Segmented-Toggle).
class _PreviewToggle extends StatelessWidget {
  const _PreviewToggle({required this.preview, required this.onChanged});
  final bool preview;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStatePropertyAll(AppTypography.label(size: 10)),
      ),
      segments: [
        ButtonSegment(
            value: false,
            icon: const Icon(LucideIcons.pencil, size: 13),
            label: Text('marketing.editor'.tr())),
        ButtonSegment(
            value: true,
            icon: const Icon(LucideIcons.eye, size: 13),
            label: Text('marketing.preview'.tr())),
      ],
      selected: {preview},
      onSelectionChanged: (s) => onChanged(s.first),
    );
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
  int? _audience; // marketing_opt_in

  @override
  void initState() {
    super.initState();
    widget.repo.segmentCounts().then((m) {
      if (mounted) {
        setState(() => _audience = (m['marketing_subs'] as num?)?.toInt());
      }
    });
  }

  Future<void> _confirm() async {
    final t = _title.text.trim();
    final b = _body.text.trim();
    if (t.isEmpty || b.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('marketing.push_send'.tr()),
        content: Text('marketing.push_send_confirm'.tr(
            namedArgs: {'count': '${_audience ?? '…'}'})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('common.cancel'.tr())),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.bronze),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('marketing.push_send'.tr())),
        ],
      ),
    );
    if (ok == true) _send();
  }

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
        _AudienceBanner(
          icon: LucideIcons.bell,
          label: 'marketing.audience_push'.tr(
              namedArgs: {'count': '${_audience ?? '…'}'}),
        ),
        const SizedBox(height: 12),
        Text('marketing.push_hint'.tr(),
            style: AppTypography.caption()),
        const SizedBox(height: 12),
        // Live-Vorschau wie die Notification auf dem Gerät aussieht.
        Text('marketing.preview'.tr(),
            style: AppTypography.label(size: 11, color: AppColors.mute)),
        const SizedBox(height: 6),
        PushPreview(title: _title.text, body: _body.text),
        const SizedBox(height: 14),
        TextField(
            controller: _title,
            onChanged: (_) => setState(() {}),
            decoration:
                InputDecoration(labelText: 'marketing.push_title'.tr())),
        const SizedBox(height: 8),
        TextField(
            controller: _body,
            maxLines: 3,
            onChanged: (_) => setState(() {}),
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
          onPressed: _sending ? null : _confirm,
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
          if (snap.hasError) {
            return ErrorStateCard(
              onRetry: () => setState(() => _f = widget.repo.segmentCounts()),
            );
          }
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
    bool preview = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Row(children: [
            Expanded(
              child: Text(existing == null
                  ? 'marketing.tpl_new'.tr()
                  : 'marketing.tpl_edit'.tr()),
            ),
            _PreviewToggle(
                preview: preview,
                onChanged: (v) => setLocal(() => preview = v)),
          ]),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: preview
                  ? (kind == 'email'
                      ? EmailPreview(
                          subject: subjCtrl.text, html: bodyCtrl.text)
                      : PushPreview(
                          title: subjCtrl.text.isEmpty
                              ? nameCtrl.text
                              : subjCtrl.text,
                          body: bodyCtrl.text))
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: nameCtrl,
                          decoration: InputDecoration(
                              labelText: 'marketing.tpl_name'.tr())),
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
          if (snap.hasError) {
            return ErrorStateCard(
              onRetry: () =>
                  setState(() => _f = widget.repo.referralsOverview()),
            );
          }
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
          if (snap.hasError) {
            return ErrorStateCard(
              onRetry: () =>
                  setState(() => _f = widget.repo.regionsOverview()),
            );
          }
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

// ── Phase 4: 9) Content-Planer ──────────────────────────────────────────────
class _ContentTab extends StatefulWidget {
  const _ContentTab({required this.repo});
  final MarketingRepository repo;
  @override
  State<_ContentTab> createState() => _ContentTabState();
}

class _ContentTabState extends State<_ContentTab> {
  late Future<List<Map<String, dynamic>>> _f = widget.repo.listContentPlan();
  void _refresh() => setState(() => _f = widget.repo.listContentPlan());

  static const List<String> _kinds = ['announcement', 'recap', 'social', 'milestone'];

  IconData _kindIcon(String kind) {
    switch (kind) {
      case 'recap':
        return LucideIcons.calendarDays;
      case 'social':
        return LucideIcons.share2;
      case 'milestone':
        return LucideIcons.award;
      default:
        return LucideIcons.megaphone;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'published':
        return AppColors.leben;
      case 'scheduled':
        return AppColors.amber;
      default:
        return AppColors.mute;
    }
  }

  Future<void> _edit({Map<String, dynamic>? existing}) async {
    final titleCtrl =
        TextEditingController(text: existing?['title']?.toString() ?? '');
    final bodyCtrl =
        TextEditingController(text: existing?['body']?.toString() ?? '');
    final shareCtrl = TextEditingController(
        text: existing?['share_text']?.toString() ?? '');
    String kind = existing?['kind']?.toString() ?? 'announcement';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(existing == null
              ? 'marketing.cp_new'.tr()
              : 'marketing.cp_edit'.tr()),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Wrap(
                spacing: 6,
                children: _kinds
                    .map((k) => ChoiceChip(
                          label: Text('marketing.cp_kind_$k'.tr()),
                          selected: kind == k,
                          onSelected: (_) => setLocal(() => kind = k),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),
              TextField(
                  controller: titleCtrl,
                  decoration:
                      InputDecoration(labelText: 'marketing.cp_title'.tr())),
              const SizedBox(height: 8),
              TextField(
                  controller: bodyCtrl,
                  maxLines: 5,
                  decoration:
                      InputDecoration(labelText: 'marketing.cp_body'.tr())),
              const SizedBox(height: 8),
              TextField(
                  controller: shareCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                      labelText: 'marketing.cp_share_text'.tr())),
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
      final t = titleCtrl.text.trim();
      if (t.isEmpty) return;
      await widget.repo.upsertContentPlan(
        id: existing?['id']?.toString(),
        kind: kind,
        title: t,
        body: bodyCtrl.text.trim(),
        shareText: shareCtrl.text.trim().isEmpty ? null : shareCtrl.text.trim(),
      );
      if (mounted) _refresh();
    }
  }

  Future<void> _share(Map<String, dynamic> r) async {
    final text = (r['share_text'] ?? r['body'] ?? r['title'] ?? '').toString();
    if (text.isEmpty) return;
    await Share.share(text);
  }

  Future<void> _previewContent(Map<String, dynamic> r) async {
    final title = sampleFill(r['title']?.toString() ?? '');
    final body = sampleFill(r['body']?.toString() ?? '');
    final share = sampleFill(r['share_text']?.toString() ?? '');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('marketing.preview'.tr(),
            style: AppTypography.display(size: 16, color: AppColors.ink)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: AppTypography.body(
                      size: 15, color: AppColors.ink, weight: FontWeight.w700)),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(body,
                    style: AppTypography.body(size: 13, color: AppColors.inkSoft)),
              ],
              if (share.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('marketing.cp_share_text'.tr(),
                    style: AppTypography.label(size: 10, color: AppColors.mute)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.elevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Text(share,
                      style: AppTypography.body(size: 13, color: AppColors.ink)),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('common.close'.tr())),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.bronze),
            onPressed: () {
              Navigator.pop(ctx);
              _share(r);
            },
            icon: const Icon(LucideIcons.share2, size: 16),
            label: Text('common.share'.tr()),
          ),
        ],
      ),
    );
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
                      child: Text('marketing.cp_empty'.tr(),
                          style: AppTypography.caption())),
                ),
              ]);
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: rows.map((r) {
                final kind = (r['kind'] ?? 'announcement').toString();
                final status = (r['status'] ?? 'draft').toString();
                final published = status == 'published';
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.elevated,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(_kindIcon(kind), size: 18, color: AppColors.bronze),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(r['title']?.toString() ?? '–',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.body(
                                  size: 14,
                                  color: AppColors.ink,
                                  weight: FontWeight.w700)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _statusColor(status).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('marketing.cp_status_$status'.tr(),
                              style: AppTypography.label(
                                  size: 9, color: _statusColor(status))),
                        ),
                      ]),
                      if ((r['body']?.toString() ?? '').isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(r['body'].toString(),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body(
                                size: 12, color: AppColors.inkSoft)),
                      ],
                      const SizedBox(height: 4),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        IconButton(
                            tooltip: 'marketing.preview'.tr(),
                            onPressed: () => _previewContent(r),
                            icon: const Icon(LucideIcons.eye,
                                size: 16, color: AppColors.mute)),
                        IconButton(
                            tooltip: 'common.share'.tr(),
                            onPressed: () => _share(r),
                            icon: const Icon(LucideIcons.share2,
                                size: 16, color: AppColors.bronze)),
                        IconButton(
                            onPressed: () => _edit(existing: r),
                            icon: const Icon(LucideIcons.pencil,
                                size: 16, color: AppColors.mute)),
                        if (!published)
                          IconButton(
                              tooltip: 'marketing.cp_publish'.tr(),
                              onPressed: () async {
                                await widget.repo
                                    .publishContentPlan(r['id'].toString());
                                if (mounted) _refresh();
                              },
                              icon: const Icon(LucideIcons.checkCircle2,
                                  size: 16, color: AppColors.leben)),
                        IconButton(
                            onPressed: () async {
                              await widget.repo
                                  .deleteContentPlan(r['id'].toString());
                              if (mounted) _refresh();
                            },
                            icon: const Icon(LucideIcons.trash2,
                                size: 16, color: AppColors.herzrot)),
                      ]),
                    ],
                  ),
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
            label: Text('marketing.cp_new'.tr()),
          )),
    ]);
  }
}
