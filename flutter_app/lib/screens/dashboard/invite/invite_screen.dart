import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

const _baseUrl = 'https://www.mensaena.de';

class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key});

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  String? _code;
  int _accepted = 0;
  int _pending = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final pending = await sb
          .from('referrals')
          .select('invite_code')
          .eq('inviter_id', uid)
          .eq('status', 'pending')
          .limit(1)
          .maybeSingle();
      String? code = pending?['invite_code'] as String?;
      if (code == null) {
        final inserted = await sb
            .from('referrals')
            .insert({
              'inviter_id': uid,
              'status': 'pending',
            })
            .select('invite_code')
            .maybeSingle();
        code = inserted?['invite_code'] as String?;
      }
      final acceptedRes = await sb
          .from('referrals')
          .select('id')
          .eq('inviter_id', uid)
          .eq('status', 'accepted');
      final pendingRes = await sb
          .from('referrals')
          .select('id')
          .eq('inviter_id', uid)
          .eq('status', 'pending');
      if (!mounted) return;
      setState(() {
        _code = code;
        _accepted = (acceptedRes as List).length;
        _pending = (pendingRes as List).length;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _inviteUrl =>
      _code != null ? '$_baseUrl/auth?invite=$_code' : _baseUrl;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _inviteUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AppColors.surface,
      content: Text('invite.linkCopied'.tr(),
          style: AppTypography.body(size: 13, color: AppColors.ink)),
    ));
  }

  Future<void> _share() async {
    await Share.share(
      'invite.shareMessage'.tr(namedArgs: {'url': _inviteUrl}),
      subject: 'invite.shareSubject'.tr(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'invite.title'.tr(),
      currentRoute: '/dashboard/invite',
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.amber),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _header(),
                  const SizedBox(height: 16),
                  _statsRow(),
                  const SizedBox(height: 16),
                  _linkCard(),
                  const SizedBox(height: 16),
                  _benefits(),
                ],
              ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.amber.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(LucideIcons.share2,
              color: AppColors.amber, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('invite.header'.tr(),
                  style: AppTypography.display(
                    size: 22,
                    color: AppColors.ink,
                  )),
              Text(
                'invite.subtitle'.tr(),
                style: AppTypography.caption(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statsRow() {
    return Row(
      children: [
        Expanded(child: _stat('invite.accepted'.tr(), _accepted, AppColors.leben)),
        const SizedBox(width: 10),
        Expanded(child: _stat('invite.pending'.tr(), _pending, AppColors.amber)),
      ],
    );
  }

  Widget _stat(String label, int n, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$n',
              style: AppTypography.mono(size: 28, color: color)),
          const SizedBox(height: 4),
          Text(label, style: AppTypography.label(size: 10, color: color)),
        ],
      ),
    );
  }

  Widget _linkCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('invite.yourLink'.tr(),
              style: AppTypography.label(size: 10)),
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.elevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _inviteUrl,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.mono(
                size: 12,
                color: AppColors.amber,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.inkSoft,
                    side: const BorderSide(color: AppColors.line),
                  ),
                  onPressed: _copy,
                  icon: const Icon(LucideIcons.copy, size: 14),
                  label: Text('invite.copy'.tr()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: AppColors.voidColor,
                  ),
                  onPressed: _share,
                  icon: const Icon(LucideIcons.share2, size: 14),
                  label: Text('invite.share'.tr()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _benefits() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.award,
                  color: AppColors.tealSoft, size: 16),
              const SizedBox(width: 8),
              Text('invite.howItWorks'.tr(),
                  style: AppTypography.label(
                    size: 10,
                    color: AppColors.tealSoft,
                  )),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'invite.howItWorksBody'.tr(),
            style: AppTypography.body(
              size: 12,
              color: AppColors.inkSoft,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
