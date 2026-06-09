import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/family_circle_repository.dart';
import '../../../services/haptics.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

/// R3: Familien-Kreis — vertrauenswürdiger Kreis aus nahen Kontakten, die im
/// Notfall sofort einen Sicherheits-Alarm bekommen. Mitglieder können
/// "SOS – ich brauche Hilfe" oder "Ich bin sicher" an den Kreis senden.
class FamilyCircleScreen extends ConsumerWidget {
  const FamilyCircleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circle = ref.watch(myCircleProvider);
    final incoming = ref.watch(circleIncomingProvider);
    final outgoing = ref.watch(circleOutgoingProvider);
    final alerts = ref.watch(circleAlertsProvider);
    final myUid = SupabaseService.currentUser?.id;

    final circleList = circle.asData?.value ?? const [];
    final incomingList = incoming.asData?.value ?? const [];
    final outgoingList = outgoing.asData?.value ?? const [];
    final alertList = alerts.asData?.value ?? const [];

    Future<void> refresh() async {
      ref
        ..invalidate(myCircleProvider)
        ..invalidate(circleIncomingProvider)
        ..invalidate(circleOutgoingProvider)
        ..invalidate(circleAlertsProvider);
    }

    return DashboardScaffold(
      title: 'circle.title'.tr(),
      currentRoute: '/dashboard/crisis',
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.herzrot,
          onRefresh: refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('circle.intro'.tr(),
                  style: AppTypography.body(
                      size: 13, color: AppColors.inkSoft, height: 1.5)),
              const SizedBox(height: 16),

              // SOS / Sicher-Buttons
              Row(
                children: [
                  Expanded(
                    child: _AlertButton(
                      icon: LucideIcons.siren,
                      label: 'circle.sosTitle'.tr(),
                      sub: 'circle.sosSub'.tr(),
                      color: AppColors.herzrot,
                      onTap: () => _sendAlert(context, ref, 'sos'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _AlertButton(
                      icon: LucideIcons.shieldCheck,
                      label: 'circle.safeTitle'.tr(),
                      sub: 'circle.safeSub'.tr(),
                      color: AppColors.leben,
                      onTap: () => _sendAlert(context, ref, 'safe'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Eingehende Anfragen
              if (incomingList.isNotEmpty) ...[
                Text('circle.incomingTitle'.tr(),
                    style: AppTypography.label(size: 10)),
                const SizedBox(height: 8),
                for (final r in incomingList)
                  _IncomingTile(request: r, onChanged: refresh, ref: ref),
                const SizedBox(height: 20),
              ],

              // Mein Kreis
              Row(
                children: [
                  Text('circle.membersTitle'.tr(),
                      style: AppTypography.label(size: 10)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _addContact(context, ref),
                    icon: const Icon(LucideIcons.userPlus,
                        size: 14, color: AppColors.bronze),
                    label: Text('circle.add'.tr(),
                        style: AppTypography.label(
                            size: 10, color: AppColors.bronze)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (circleList.isEmpty)
                Text('circle.empty'.tr(), style: AppTypography.caption())
              else
                for (final c in circleList)
                  _MemberTile(
                    contact: c,
                    myUid: myUid,
                    onRemoved: refresh,
                    ref: ref,
                  ),

              // Ausgehende Anfragen
              if (outgoingList.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('circle.outgoingTitle'.tr(),
                    style: AppTypography.label(size: 10)),
                const SizedBox(height: 8),
                for (final r in outgoingList)
                  _OutgoingTile(request: r, onChanged: refresh, ref: ref),
              ],

              // Letzte Alarme
              if (alertList.isNotEmpty) ...[
                const SizedBox(height: 22),
                Text('circle.recentAlerts'.tr(),
                    style: AppTypography.label(size: 10)),
                const SizedBox(height: 8),
                for (final a in alertList) _AlertTile(alert: a),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendAlert(
      BuildContext context, WidgetRef ref, String kind) async {
    final isSos = kind == 'sos';
    final messenger = ScaffoldMessenger.of(context);
    final msgCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dlg) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          isSos ? 'circle.sosConfirmTitle'.tr() : 'circle.safeConfirmTitle'.tr(),
          style: AppTypography.display(
              size: 18,
              color: isSos ? AppColors.herzrot : AppColors.leben),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSos ? 'circle.sosConfirmBody'.tr() : 'circle.safeConfirmBody'.tr(),
              style: AppTypography.body(size: 13, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: msgCtrl,
              maxLength: 200,
              maxLines: 2,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: 'circle.alertMessageHint'.tr(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlg, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: isSos ? AppColors.herzrot : AppColors.leben,
              foregroundColor: AppColors.voidColor,
            ),
            onPressed: () => Navigator.pop(dlg, true),
            child: Text(
                isSos ? 'circle.sosSend'.tr() : 'circle.safeSend'.tr()),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (isSos) {
      Haptics.heavyImpact();
    } else {
      Haptics.confirm();
    }
    final ok = await FamilyCircleRepository.sendAlert(
      kind: kind,
      message: msgCtrl.text,
    );
    ref.invalidate(circleAlertsProvider);
    messenger.showSnackBar(SnackBar(
      backgroundColor: AppColors.surface,
      content: Text(
        ok ? 'circle.alertSent'.tr() : 'circle.alertFailed'.tr(),
        style: AppTypography.body(size: 13, color: AppColors.ink),
      ),
    ));
  }

  Future<void> _addContact(BuildContext context, WidgetRef ref) async {
    final emailCtrl = TextEditingController();
    final relCtrl = TextEditingController();
    bool sending = false;
    await showDialog<void>(
      context: context,
      builder: (dlg) => StatefulBuilder(
        builder: (dlg, setLocal) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('circle.addTitle'.tr(),
              style: AppTypography.display(size: 18, color: AppColors.ink)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('circle.addHint'.tr(), style: AppTypography.caption()),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                style: AppTypography.body(size: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'circle.emailHint'.tr(),
                  prefixIcon: const Icon(LucideIcons.mail,
                      size: 16, color: AppColors.mute),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: relCtrl,
                maxLength: 40,
                style: AppTypography.body(size: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'circle.relationHint'.tr(),
                  prefixIcon: const Icon(LucideIcons.heart,
                      size: 16, color: AppColors.mute),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.pop(dlg),
              child: Text('common.cancel'.tr()),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.bronze,
                foregroundColor: AppColors.voidColor,
              ),
              onPressed: sending
                  ? null
                  : () async {
                      final email = emailCtrl.text.trim();
                      if (email.isEmpty || !email.contains('@')) return;
                      setLocal(() => sending = true);
                      final res = await FamilyCircleRepository.requestByEmail(
                          email, relCtrl.text);
                      if (!dlg.mounted) return;
                      Navigator.pop(dlg);
                      ref.invalidate(circleOutgoingProvider);
                      final msg = switch (res) {
                        'ok' => 'circle.requestSent'.tr(),
                        'not_found' => 'circle.notFound'.tr(),
                        'self' => 'circle.selfError'.tr(),
                        _ => 'circle.requestFailed'.tr(),
                      };
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        backgroundColor: AppColors.surface,
                        content: Text(msg,
                            style: AppTypography.body(
                                size: 13, color: AppColors.ink)),
                      ));
                    },
              child: sending
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.voidColor),
                    )
                  : Text('circle.sendRequest'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Liefert das "andere" Profil eines trusted_contacts-Eintrags relativ zu mir.
Map<String, dynamic>? _otherProfile(
    Map<String, dynamic> row, String? myUid) {
  final owner = row['owner'] as Map<String, dynamic>?;
  final contact = row['contact'] as Map<String, dynamic>?;
  if (row['owner_id'] == myUid) return contact;
  return owner;
}

String _displayName(Map<String, dynamic>? p) {
  if (p == null) return 'common.neighbour'.tr();
  return (p['display_name'] ?? p['name'] ?? 'common.neighbour'.tr()).toString();
}

class _AlertButton extends StatelessWidget {
  const _AlertButton({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, size: 26, color: color),
            const SizedBox(height: 6),
            Text(label,
                style: AppTypography.body(
                    size: 14, color: color, weight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(sub,
                textAlign: TextAlign.center,
                style: AppTypography.caption()),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.contact,
    required this.myUid,
    required this.onRemoved,
    required this.ref,
  });
  final Map<String, dynamic> contact;
  final String? myUid;
  final Future<void> Function() onRemoved;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final p = _otherProfile(contact, myUid);
    final name = _displayName(p);
    final rel = (contact['relation_label'] ?? '').toString();
    final avatar = p?['avatar_url'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.4),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _Avatar(url: avatar),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppTypography.body(
                        size: 14,
                        color: AppColors.ink,
                        weight: FontWeight.w700)),
                if (rel.isNotEmpty)
                  Text(rel, style: AppTypography.caption()),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              final ok = await FamilyCircleRepository.removeContact(
                  contact['id'] as String);
              if (ok) await onRemoved();
            },
            tooltip: 'circle.remove'.tr(),
            icon: const Icon(LucideIcons.userMinus,
                size: 16, color: AppColors.mute),
          ),
        ],
      ),
    );
  }
}

class _IncomingTile extends StatelessWidget {
  const _IncomingTile(
      {required this.request, required this.onChanged, required this.ref});
  final Map<String, dynamic> request;
  final Future<void> Function() onChanged;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final p = request['owner'] as Map<String, dynamic>?;
    final name = _displayName(p);
    final rel = (request['relation_label'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bronze.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.bronze.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _Avatar(url: p?['avatar_url'] as String?),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('circle.wantsToAdd'.tr(namedArgs: {'name': name}),
                    style: AppTypography.body(
                        size: 13, color: AppColors.ink)),
                if (rel.isNotEmpty)
                  Text('„$rel"', style: AppTypography.caption()),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              await FamilyCircleRepository.acceptRequest(
                  request['id'] as String);
              await onChanged();
            },
            icon: const Icon(LucideIcons.check,
                size: 18, color: AppColors.leben),
            tooltip: 'circle.accept'.tr(),
          ),
          IconButton(
            onPressed: () async {
              await FamilyCircleRepository.declineRequest(
                  request['id'] as String);
              await onChanged();
            },
            icon: const Icon(LucideIcons.x, size: 18, color: AppColors.mute),
            tooltip: 'circle.decline'.tr(),
          ),
        ],
      ),
    );
  }
}

class _OutgoingTile extends StatelessWidget {
  const _OutgoingTile(
      {required this.request, required this.onChanged, required this.ref});
  final Map<String, dynamic> request;
  final Future<void> Function() onChanged;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final p = request['contact'] as Map<String, dynamic>?;
    final name = _displayName(p);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.3),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.clock, size: 14, color: AppColors.mute),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                'circle.requestPending'.tr(namedArgs: {'name': name}),
                style: AppTypography.body(size: 13, color: AppColors.inkSoft)),
          ),
          GestureDetector(
            onTap: () async {
              await FamilyCircleRepository.removeContact(
                  request['id'] as String);
              await onChanged();
            },
            child: const Icon(LucideIcons.trash2,
                size: 14, color: AppColors.mute),
          ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert});
  final Map<String, dynamic> alert;

  @override
  Widget build(BuildContext context) {
    final isSos = (alert['kind'] ?? 'sos') == 'sos';
    final p = alert['sender'] as Map<String, dynamic>?;
    final name = _displayName(p);
    final msg = (alert['message'] ?? '').toString();
    final created = DateTime.tryParse(alert['created_at']?.toString() ?? '')?.toUtc()
        ?.toLocal();
    final color = isSos ? AppColors.herzrot : AppColors.leben;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isSos ? LucideIcons.siren : LucideIcons.shieldCheck,
              size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSos
                      ? 'circle.sosFrom'.tr(namedArgs: {'name': name})
                      : 'circle.safeFrom'.tr(namedArgs: {'name': name}),
                  style: AppTypography.body(
                      size: 13, color: AppColors.ink, weight: FontWeight.w700),
                ),
                if (msg.isNotEmpty)
                  Text(msg,
                      style: AppTypography.body(
                          size: 12, color: AppColors.inkSoft)),
                if (created != null)
                  Text(
                    DateFormat('dd.MM. HH:mm').format(created),
                    style: AppTypography.caption(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.elevated,
        child: Icon(LucideIcons.user, size: 16, color: AppColors.mute),
      );
    }
    return CachedNetworkImage(
      imageUrl: url!,
      memCacheWidth: 96,
      imageBuilder: (_, img) => CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.elevated,
        backgroundImage: img,
      ),
      placeholder: (_, __) => const CircleAvatar(
          radius: 18, backgroundColor: AppColors.elevated),
      errorWidget: (_, __, ___) => const CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.elevated,
        child: Icon(LucideIcons.user, size: 16, color: AppColors.mute),
      ),
    );
  }
}
