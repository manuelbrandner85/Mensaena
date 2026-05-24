import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/crisis.dart';
import '../../../models/crisis_helper.dart';
import '../../../models/crisis_update.dart';
import '../../../repositories/crisis_repository.dart';
import '../../../services/supabase_service.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features
/// Crisis-Detail mit Realtime-Helper-Count + Update-Feed.
class CrisisDetailScreen extends ConsumerWidget {
  const CrisisDetailScreen({required this.crisisId, super.key});

  final String crisisId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crisis = ref.watch(crisisDetailProvider(crisisId));
    final helpers = ref.watch(crisisHelpersStreamProvider(crisisId));
    final updates = ref.watch(crisisUpdatesStreamProvider(crisisId));

    return DashboardScaffold(
      title: 'Krise',
      currentRoute: '/dashboard/crisis',
      body: SafeArea(
        child: crisis.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.herzrot),
          ),
          error: (e, _) => Center(
            child: Text('Fehler: $e', style: AppTypography.caption()),
          ),
          data: (c) {
            if (c == null) {
              return Center(
                child: Text('Krise nicht gefunden.',
                    style: AppTypography.caption()),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Header(crisis: c),
                const SizedBox(height: 16),
                _ContactBlock(crisis: c),
                const SizedBox(height: 16),
                _HelperBlock(
                  crisis: c,
                  helpers: helpers.asData?.value ?? const [],
                  onOffer: () => _offerHelp(context, ref, c),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text('Updates',
                          style: AppTypography.label(size: 10)),
                    ),
                    if (SupabaseService.currentUser?.id != null)
                      TextButton.icon(
                        onPressed: () =>
                            _openUpdateSheet(context, ref, c),
                        icon: const Icon(LucideIcons.plus,
                            size: 12, color: AppColors.bronze),
                        label: Text('Update posten',
                            style: AppTypography.label(
                                size: 10,
                                color: AppColors.bronze)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _UpdatesFeed(updates: updates.asData?.value ?? const []),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openUpdateSheet(
      BuildContext context, WidgetRef ref, Crisis c) async {
    final ctrl = TextEditingController();
    String severity = 'info';
    bool sending = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setLocal) => Padding(
          padding: EdgeInsets.fromLTRB(
            20, 16, 20,
            16 + MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('Status-Update posten',
                  style: AppTypography.display(
                      size: 20, color: AppColors.ink)),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                maxLines: 4,
                minLines: 2,
                style: AppTypography.body(
                    size: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.elevated,
                  hintText: 'Was hat sich geaendert?',
                  hintStyle: AppTypography.body(
                      size: 13, color: AppColors.mute),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('Schwere', style: AppTypography.label(size: 10)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  for (final s in const [
                    ('info', 'ℹ️ Info', AppColors.tealSoft),
                    ('progress', '⏳ Fortschritt', AppColors.amber),
                    ('resolved', '✅ Geloest', AppColors.leben),
                  ])
                    ChoiceChip(
                      label: Text(s.$2,
                          style: AppTypography.label(size: 10)),
                      selected: severity == s.$1,
                      onSelected: (_) =>
                          setLocal(() => severity = s.$1),
                      selectedColor:
                          s.$3.withValues(alpha: 0.3),
                      backgroundColor: AppColors.elevated,
                    ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.bronze,
                  foregroundColor: AppColors.voidColor,
                  minimumSize: const Size(double.infinity, 48),
                ),
                onPressed: sending
                    ? null
                    : () async {
                        final text = ctrl.text.trim();
                        if (text.isEmpty) return;
                        setLocal(() => sending = true);
                        try {
                          await sb.from('crisis_updates').insert({
                            'crisis_id': c.id,
                            'user_id': SupabaseService
                                .currentUser!.id,
                            'content': text,
                            'severity': severity,
                          });
                          if (!sheetCtx.mounted) return;
                          Navigator.pop(sheetCtx);
                          ref.invalidate(
                              crisisUpdatesStreamProvider(c.id));
                        } catch (_) {
                          setLocal(() => sending = false);
                        }
                      },
                child: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.voidColor),
                      )
                    : const Text('Posten'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _offerHelp(
    BuildContext context,
    WidgetRef ref,
    Crisis crisis,
  ) async {
    final messageCtrl = TextEditingController();
    final etaCtrl = TextEditingController(text: '15');
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hilfe anbieten',
                style:
                    AppTypography.display(size: 22, color: AppColors.ink)),
            const SizedBox(height: 12),
            TextField(
              controller: messageCtrl,
              maxLines: 3,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: const InputDecoration(
                labelText: 'Was kannst du tun? (optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: etaCtrl,
              keyboardType: TextInputType.number,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration:
                  const InputDecoration(labelText: 'ETA in Minuten'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text('common.cancel'.tr()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.herzrot,
                      foregroundColor: AppColors.ink,
                    ),
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text('common.confirm'.tr()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final ok = await CrisisRepository.offerHelp(
      crisisId: crisis.id,
      message: messageCtrl.text.trim().isEmpty
          ? null
          : messageCtrl.text.trim(),
      etaMinutes: int.tryParse(etaCtrl.text.trim()),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Du bist eingetragen — die/der Ersteller:in sieht dich live.'
              : 'Konnte Hilfe nicht eintragen.',
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.crisis});
  final Crisis crisis;

  static const Map<String, Color> _urgencyColors = {
    'critical': AppColors.herzrot,
    'high': Color(0xFFFB923C),
    'medium': AppColors.amber,
    'low': AppColors.teal,
  };

  @override
  Widget build(BuildContext context) {
    final color = _urgencyColors[crisis.urgency] ?? AppColors.amber;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  crisis.urgency.toUpperCase(),
                  style: AppTypography.label(
                    size: 9,
                    color: AppColors.voidColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(crisis.category.toUpperCase(),
                  style: AppTypography.label(size: 9, color: color)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            crisis.title,
            style: AppTypography.display(
              size: 26,
              color: AppColors.ink,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            crisis.description,
            style: AppTypography.body(
              size: 14,
              color: AppColors.inkSoft,
              height: 1.55,
            ),
          ),
          if (crisis.locationText != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(LucideIcons.mapPin,
                    size: 13, color: AppColors.mute),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    crisis.locationText!,
                    style: AppTypography.body(size: 12, color: AppColors.mute),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactBlock extends StatelessWidget {
  const _ContactBlock({required this.crisis});
  final Crisis crisis;

  Future<void> _call() async {
    if (crisis.contactPhone == null) return;
    await launchUrl(Uri.parse('tel:${crisis.contactPhone}'));
  }

  @override
  Widget build(BuildContext context) {
    if (crisis.contactPhone == null && crisis.contactName == null) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.phone, color: AppColors.amber, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (crisis.contactName != null)
                  Text(crisis.contactName!,
                      style:
                          AppTypography.body(size: 14, color: AppColors.ink)),
                if (crisis.contactPhone != null)
                  Text(crisis.contactPhone!,
                      style: AppTypography.mono(
                          size: 13, color: AppColors.amber)),
              ],
            ),
          ),
          if (crisis.contactPhone != null)
            OutlinedButton.icon(
              onPressed: _call,
              icon: const Icon(LucideIcons.phone, size: 14),
              label: const Text('Anrufen'),
            ),
        ],
      ),
    );
  }
}

class _HelperBlock extends StatelessWidget {
  const _HelperBlock({
    required this.crisis,
    required this.helpers,
    required this.onOffer,
  });

  final Crisis crisis;
  final List<CrisisHelper> helpers;
  final VoidCallback onOffer;

  @override
  Widget build(BuildContext context) {
    final active = helpers
        .where((h) => h.status != 'withdrawn' && h.status != 'completed')
        .length;
    final need = crisis.neededHelpers ?? 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.leben.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.leben.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.helpingHand, color: AppColors.leben),
              const SizedBox(width: 8),
              Text(
                '$active Helfer:innen aktiv',
                style: AppTypography.body(
                  size: 14,
                  color: AppColors.ink,
                  weight: FontWeight.w700,
                ),
              ),
              if (need > 0) ...[
                const SizedBox(width: 6),
                Text(
                  '· benötigt: $need',
                  style: AppTypography.caption(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.leben,
                foregroundColor: AppColors.voidColor,
              ),
              onPressed: onOffer,
              icon: const Icon(LucideIcons.heart, size: 16),
              label: const Text('Ich helfe'),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpdatesFeed extends StatelessWidget {
  const _UpdatesFeed({required this.updates});
  final List<CrisisUpdate> updates;

  @override
  Widget build(BuildContext context) {
    if (updates.isEmpty) {
      return Text(
        'Noch keine Updates.',
        style: AppTypography.caption(),
      );
    }
    return Column(
      children: updates.map((u) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.4),
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (u.isPinned)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(LucideIcons.pin,
                          size: 12, color: AppColors.amber),
                    ),
                  Text(
                    u.updateType.toUpperCase(),
                    style: AppTypography.label(size: 9, color: AppColors.amber),
                  ),
                  const Spacer(),
                  if (u.createdAt != null)
                    Text(
                      DateFormat('dd.MM. HH:mm').format(u.createdAt!),
                      style: AppTypography.caption(),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                u.content,
                style: AppTypography.body(
                  size: 13,
                  color: AppColors.inkSoft,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
