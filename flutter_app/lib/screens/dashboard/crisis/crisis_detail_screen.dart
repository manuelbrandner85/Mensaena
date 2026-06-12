import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/crisis.dart';
import '../../../models/crisis_helper.dart';
import '../../../models/crisis_update.dart';
import '../../../repositories/ai_features_repository.dart';
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
      title: 'modules.crisisDetail'.tr(),
      currentRoute: '/dashboard/crisis',
      body: SafeArea(
        child: crisis.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.herzrot),
          ),
          error: (e, _) => Center(
            child: Text('crisis.error'.tr(namedArgs: {'error': '$e'}),
                style: AppTypography.caption()),
          ),
          data: (c) {
            if (c == null) {
              return Center(
                child: Text('crisis.notFound'.tr(),
                    style: AppTypography.caption()),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Header(crisis: c),
                const SizedBox(height: 16),
                // F) KI-Zusammenfassung (gecacht serverseitig in crises.ai_summary).
                _AiCrisisSummaryCard(crisisId: c.id),
                const SizedBox(height: 16),
                _ContactBlock(crisis: c),
                const SizedBox(height: 16),
                _HelperBlock(
                  crisis: c,
                  helpers: helpers.asData?.value ?? const [],
                  onOffer: () => _offerHelp(context, ref, c),
                  onShare: () => _shareCrisis(c),
                ),
                if (_NeedsBlock.hasContent(c)) ...[
                  const SizedBox(height: 16),
                  _NeedsBlock(crisis: c),
                ],
                const SizedBox(height: 16),
                _TeamTasksBlock(crisis: c),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text('crisis.updates'.tr(),
                          style: AppTypography.label(size: 10)),
                    ),
                    if (SupabaseService.currentUser?.id != null)
                      TextButton.icon(
                        onPressed: () =>
                            _openUpdateSheet(context, ref, c),
                        icon: const Icon(LucideIcons.plus,
                            size: 12, color: AppColors.bronze),
                        label: Text('crisis.postUpdate'.tr(),
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
      backgroundColor: AppColors.sheetBackground,
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
              Text('crisis.postStatusUpdate'.tr(),
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
                  hintText: 'crisis.whatChanged'.tr(),
                  hintStyle: AppTypography.body(
                      size: 13, color: AppColors.mute),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('crisis.severity'.tr(), style: AppTypography.label(size: 10)),
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
                        // BUGFIX: roher Insert nutzte user_id/severity —
                        // crisis_updates hat author_id/update_type (siehe
                        // CrisisUpdate-Modell). Chip-Werte mappen.
                        final ok = await CrisisRepository.addUpdate(
                          crisisId: c.id,
                          content: text,
                          updateType: switch (severity) {
                            'progress' => 'status_change',
                            'resolved' => 'resolution',
                            _ => 'info',
                          },
                        );
                        if (!sheetCtx.mounted) return;
                        if (ok) {
                          Navigator.pop(sheetCtx);
                          ref.invalidate(
                              crisisUpdatesStreamProvider(c.id));
                        } else {
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
                    : Text('crisis.post'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Deep-Link Share auf www.mensaena.de/dashboard/crisis/{id}.
  /// Verbreitet den Notruf an die Nachbarschaft (WhatsApp, Signal, ...).
  Future<void> _shareCrisis(Crisis c) async {
    final url = 'https://www.mensaena.de/dashboard/crisis/${c.id}';
    await Share.share(
      'crisis.shareBody'.tr(namedArgs: {'title': c.title, 'url': url}),
      subject:
          'crisis.shareSubject'.tr(namedArgs: {'title': c.title}),
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
      backgroundColor: AppColors.sheetBackground,
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
            Text('crisis.offerHelp'.tr(),
                style:
                    AppTypography.display(size: 22, color: AppColors.ink)),
            const SizedBox(height: 12),
            TextField(
              controller: messageCtrl,
              maxLines: 3,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: InputDecoration(
                labelText: 'crisis.whatCanYouDo'.tr(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: etaCtrl,
              keyboardType: TextInputType.number,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration:
                  InputDecoration(labelText: 'crisis.etaMinutes'.tr()),
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
              ? 'crisis.youAreRegistered'.tr()
              : 'crisis.couldNotRegister'.tr(),
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
    final phone = crisis.contactPhone;
    if (phone == null) return;
    // Vorher ungeschützt: tel:-Launch ohne Handler (z.B. Web) wirft eine
    // unbehandelte Exception. Jetzt tryParse + try/catch (best effort).
    final uri = Uri.tryParse('tel:$phone');
    if (uri == null) return;
    try {
      await launchUrl(uri);
    } catch (_) {/* kein tel:-Handler — still ignorieren */}
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
              label: Text('crisis.callBtn'.tr()),
            ),
        ],
      ),
    );
  }
}

/// Zeigt die krisen-spezifischen Bedarfe an, die im Create-Screen erfasst
/// werden: Fotos, Betroffenenzahl, benötigte Fähigkeiten & Ressourcen.
class _NeedsBlock extends StatelessWidget {
  const _NeedsBlock({required this.crisis});

  final Crisis crisis;

  // Stabile DB-Werte → Anzeige-i18n-Keys (Spiegel des Create-Screens).
  static const Map<String, String> _skillLabels = {
    'medical': 'crisisCreate.skillMedical',
    'transport': 'crisisCreate.skillTransport',
    'shelter': 'crisisCreate.skillShelter',
    'manpower': 'crisisCreate.skillManpower',
    'technical': 'crisisCreate.skillTechnical',
    'translation': 'crisisCreate.skillTranslation',
    'childcare': 'crisisCreate.skillChildcare',
    'animalcare': 'crisisCreate.skillAnimalcare',
  };
  static const Map<String, String> _resourceLabels = {
    'water': 'crisisCreate.resWater',
    'food': 'crisisCreate.resFood',
    'blankets': 'crisisCreate.resBlankets',
    'clothing': 'crisisCreate.resClothing',
    'medicine': 'crisisCreate.resMedicine',
    'power': 'crisisCreate.resPower',
    'tools': 'crisisCreate.resTools',
    'vehicle': 'crisisCreate.resVehicle',
  };

  static bool hasContent(Crisis c) =>
      c.imageUrls.isNotEmpty ||
      (c.affectedCount ?? 0) > 0 ||
      c.neededSkills.isNotEmpty ||
      c.neededResources.isNotEmpty;

  String _label(Map<String, String> map, String value) {
    final key = map[value];
    return key != null ? key.tr() : value;
  }

  @override
  Widget build(BuildContext context) {
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
          if (crisis.imageUrls.isNotEmpty) ...[
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: crisis.imageUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: crisis.imageUrls[i],
                    width: 160,
                    height: 120,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 160,
                      height: 120,
                      color: AppColors.elevated,
                      alignment: Alignment.center,
                      child: const Icon(LucideIcons.imageOff,
                          size: 18, color: AppColors.mute),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          if ((crisis.affectedCount ?? 0) > 0) ...[
            Row(
              children: [
                const Icon(LucideIcons.users,
                    size: 16, color: AppColors.inkSoft),
                const SizedBox(width: 8),
                Text(
                  'crisisCreate.affectedCount'.tr(),
                  style: AppTypography.caption(),
                ),
                const Spacer(),
                Text('${crisis.affectedCount}',
                    style: AppTypography.body(
                        size: 15,
                        color: AppColors.ink,
                        weight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (crisis.neededSkills.isNotEmpty) ...[
            Text('crisisCreate.neededSkills'.tr(),
                style: AppTypography.label(size: 10)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: crisis.neededSkills
                  .map((s) => _chip(_label(_skillLabels, s)))
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],
          if (crisis.neededResources.isNotEmpty) ...[
            Text('crisisCreate.neededResources'.tr(),
                style: AppTypography.label(size: 10)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: crisis.neededResources
                  .map((r) => _chip(_label(_resourceLabels, r)))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.bronze.withValues(alpha: 0.14),
          border: Border.all(color: AppColors.bronze.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: AppTypography.label(size: 11, color: AppColors.bronze)),
      );
}

class _HelperBlock extends StatelessWidget {
  const _HelperBlock({
    required this.crisis,
    required this.helpers,
    required this.onOffer,
    required this.onShare,
  });

  final Crisis crisis;
  final List<CrisisHelper> helpers;
  final VoidCallback onOffer;
  final VoidCallback onShare;

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
                'crisis.helpersActive'.tr(namedArgs: {'count': '$active'}),
                style: AppTypography.body(
                  size: 14,
                  color: AppColors.ink,
                  weight: FontWeight.w700,
                ),
              ),
              if (need > 0) ...[
                const SizedBox(width: 6),
                Text(
                  'crisis.helpersNeeded'.tr(namedArgs: {'count': '$need'}),
                  style: AppTypography.caption(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.leben,
                    foregroundColor: AppColors.voidColor,
                  ),
                  onPressed: onOffer,
                  icon: const Icon(LucideIcons.heart, size: 16),
                  label: Text('crisis.iHelp'.tr()),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onShare,
                icon: const Icon(LucideIcons.share2, size: 14),
                label: Text('crisis.share'.tr()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.leben,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// R2: Krisen-Team — koordinierte Aufgaben. Jede:r angemeldete Helfer:in
/// kann Aufgaben anlegen, freie Aufgaben übernehmen und erledigte abhaken.
/// Ersteller:in der Aufgabe bzw. der Krise darf löschen.
class _TeamTasksBlock extends ConsumerWidget {
  const _TeamTasksBlock({required this.crisis});
  final Crisis crisis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = SupabaseService.currentUser?.id;
    final isCrisisOwner = uid != null && uid == crisis.creatorId;
    final async = ref.watch(crisisTasksStreamProvider(crisis.id));
    final tasks = async.asData?.value ?? const [];
    final open = tasks.where((t) => t['status'] != 'done').toList();
    final done = tasks.where((t) => t['status'] == 'done').length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.4),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.users, size: 15, color: AppColors.bronze),
              const SizedBox(width: 6),
              Text('crisis.teamTitle'.tr(),
                  style: AppTypography.label(size: 10, color: AppColors.bronze)),
              const Spacer(),
              if (uid != null)
                TextButton.icon(
                  onPressed: () => _createTask(context, ref),
                  icon: const Icon(LucideIcons.plus,
                      size: 12, color: AppColors.bronze),
                  label: Text('crisis.addTask'.tr(),
                      style: AppTypography.label(
                          size: 10, color: AppColors.bronze)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 30),
                  ),
                ),
            ],
          ),
          if (done > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'crisis.tasksDoneCount'.tr(namedArgs: {'n': '$done'}),
                style: AppTypography.caption(),
              ),
            ),
          const SizedBox(height: 8),
          if (open.isEmpty)
            Text('crisis.noTasksYet'.tr(), style: AppTypography.caption())
          else
            for (final t in open)
              _taskRow(context, ref, t, uid, isCrisisOwner),
        ],
      ),
    );
  }

  Widget _taskRow(BuildContext context, WidgetRef ref,
      Map<String, dynamic> t, String? uid, bool isCrisisOwner) {
    final id = t['id'] as String;
    final title = (t['title'] ?? '').toString();
    final desc = (t['description'] ?? '').toString();
    final status = (t['status'] ?? 'open').toString();
    final assignedTo = t['assigned_to'] as String?;
    final mineAssigned = assignedTo != null && assignedTo == uid;
    final canDelete = isCrisisOwner || t['created_by'] == uid;
    final claimed = status == 'claimed';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              claimed ? LucideIcons.userCheck : LucideIcons.circleDashed,
              size: 15,
              color: claimed ? AppColors.amber : AppColors.mute,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTypography.body(
                        size: 13,
                        color: AppColors.ink,
                        weight: FontWeight.w600)),
                if (desc.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(desc,
                        style: AppTypography.body(
                            size: 12, color: AppColors.inkSoft),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (uid != null && status == 'open')
                      _action(LucideIcons.hand, 'crisis.taskClaim'.tr(),
                          AppColors.bronze, () async {
                        await CrisisRepository.claimTask(id);
                      }),
                    if (claimed && (mineAssigned || isCrisisOwner))
                      _action(LucideIcons.check, 'crisis.taskDone'.tr(),
                          AppColors.leben, () async {
                        await CrisisRepository.completeTask(id);
                      }),
                    if (claimed && mineAssigned)
                      _action(LucideIcons.undo2, 'crisis.taskRelease'.tr(),
                          AppColors.mute, () async {
                        await CrisisRepository.releaseTask(id);
                      }),
                    if (canDelete)
                      _action(LucideIcons.trash2, 'common.delete'.tr(),
                          AppColors.mute, () async {
                        await CrisisRepository.deleteTask(id);
                      }),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _action(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
            Text(label, style: AppTypography.label(size: 9, color: color)),
          ],
        ),
      ),
    );
  }

  Future<void> _createTask(BuildContext context, WidgetRef ref) async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool sending = false;
    await showDialog<void>(
      context: context,
      builder: (dlg) => StatefulBuilder(
        builder: (dlg, setLocal) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('crisis.addTask'.tr(),
              style: AppTypography.display(size: 18, color: AppColors.ink)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                autofocus: true,
                maxLength: 120,
                style: AppTypography.body(size: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'crisis.taskTitleHint'.tr(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                maxLength: 300,
                style: AppTypography.body(size: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'crisis.taskDescHint'.tr(),
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
                      final title = titleCtrl.text.trim();
                      if (title.isEmpty) return;
                      setLocal(() => sending = true);
                      await CrisisRepository.createTask(
                        crisisId: crisis.id,
                        title: title,
                        description: descCtrl.text,
                      );
                      if (!dlg.mounted) return;
                      Navigator.pop(dlg);
                    },
              child: sending
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.voidColor),
                    )
                  : Text('crisis.taskSave'.tr()),
            ),
          ],
        ),
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
        'crisis.noUpdatesYet'.tr(),
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

// ─────────────────────────────────────────────────────────────────────────
// F) KI-Krisen-Zusammenfassung — lädt die (serverseitig gecachte) Summary.
class _AiCrisisSummaryCard extends ConsumerStatefulWidget {
  const _AiCrisisSummaryCard({required this.crisisId});
  final String crisisId;
  @override
  ConsumerState<_AiCrisisSummaryCard> createState() =>
      _AiCrisisSummaryCardState();
}

class _AiCrisisSummaryCardState extends ConsumerState<_AiCrisisSummaryCard> {
  String? _summary;
  bool _loading = false;

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    String? s;
    try {
      s = await AiFeaturesRepository()
          .crisisSummary(widget.crisisId, context.locale.languageCode);
    } catch (_) {/* ignore */}
    if (!mounted) return;
    setState(() {
      _summary = s;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bronze.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.bronze.withValues(alpha: 0.30)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 15, color: AppColors.bronze),
              const SizedBox(width: 6),
              Text('assistant.crisis_summary_title'.tr(),
                  style: AppTypography.label(size: 10, color: AppColors.bronze)),
              const Spacer(),
              if (_summary != null && !_loading)
                InkWell(
                  onTap: _load,
                  child: const Icon(LucideIcons.refreshCw,
                      size: 13, color: AppColors.bronze),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(6),
                child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.bronze)),
              ),
            )
          else if (_summary != null)
            Text(_summary!,
                style: AppTypography.body(
                    size: 13, color: AppColors.ink, height: 1.4))
          else
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.auto_awesome,
                    size: 15, color: AppColors.bronze),
                label: Text('assistant.crisis_summary_generate'.tr(),
                    style:
                        AppTypography.label(size: 12, color: AppColors.bronze)),
              ),
            ),
        ],
      ),
    );
  }
}
