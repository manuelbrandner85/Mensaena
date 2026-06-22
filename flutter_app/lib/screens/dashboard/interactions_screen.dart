import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/interaction.dart';
import '../../repositories/interactions_repository.dart';
import '../../repositories/profiles_repository.dart';
import '../../services/supabase_service.dart';
import '../../widgets/effects/shimmer_skeleton.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';
import '../../widgets/effects/animated_entrance.dart';
import '../../widgets/shared/trust_rating_modal.dart';
import '../../widgets/shared/app_snackbar.dart';
import '../../widgets/shared/first_help_moment.dart';

/// SKILL: mensaena-features
/// Interactions-Screen: alle aktiven Hilfeanfragen des Users.
class InteractionsScreen extends ConsumerStatefulWidget {
  const InteractionsScreen({super.key});

  @override
  ConsumerState<InteractionsScreen> createState() => _InteractionsScreenState();
}

class _InteractionsScreenState extends ConsumerState<InteractionsScreen> {
  Future<List<Interaction>>? _future;

  @override
  void initState() {
    super.initState();
    _future = InteractionsRepository.getActive();
  }

  Future<void> _refresh() async {
    final fresh = InteractionsRepository.getActive();
    setState(() => _future = fresh);
    await fresh;
  }

  @override
  Widget build(BuildContext context) {
    return DashboardScaffold(
      title: 'misc.interactions'.tr(),
      currentRoute: '/dashboard/interactions',
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.amber,
          backgroundColor: AppColors.surface,
          onRefresh: _refresh,
          child: FutureBuilder<List<Interaction>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                // F7: Shimmer-Skeleton statt Spinner.
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                  itemCount: 6,
                  itemBuilder: (_, __) => const NotificationTileSkeleton(),
                );
              }
              final all = snap.data ?? const <Interaction>[];
              if (all.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 80),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          children: [
                            const Icon(LucideIcons.helpingHand,
                                size: 40, color: AppColors.bronze),
                            const SizedBox(height: 14),
                            Text('interactions.noneTitle'.tr(),
                                textAlign: TextAlign.center,
                                style: AppTypography.display(
                                    size: 18, color: AppColors.ink)),
                            const SizedBox(height: 8),
                            Text(
                              'interactions.noneBody'.tr(),
                              textAlign: TextAlign.center,
                              style: AppTypography.body(
                                  size: 13,
                                  color: AppColors.inkSoft,
                                  height: 1.5),
                            ),
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              onPressed: () =>
                                  context.go('/dashboard/posts'),
                              icon: const Icon(LucideIcons.search,
                                  size: 16),
                              label: Text('interactions.discover'.tr()),
                              style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.bronze,
                                  foregroundColor: AppColors.voidColor),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: all.length,
                itemBuilder: (context, i) {
                  final it = all[i];
                  return AnimatedEntrance(
                    index: i,
                    child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
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
                            _StatusBadge(status: it.status),
                            const Spacer(),
                            Text(
                              DateFormat('dd.MM.yyyy HH:mm')
                                  .format(it.updatedAt),
                              style: AppTypography.caption(),
                            ),
                          ],
                        ),
                        if (it.message != null && it.message!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            it.message!,
                            style: AppTypography.body(
                              size: 13,
                              color: AppColors.inkSoft,
                              height: 1.5,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        _StatusActions(
                          interactionId: it.id,
                          status: it.status,
                          isHelper:
                              it.helperId == SupabaseService.currentUser?.id,
                          // Partner = whoever is NOT me in this interaction
                          partnerId: it.helperId ==
                                  SupabaseService.currentUser?.id
                              ? it.helpedId
                              : it.helperId,
                          alreadyRated: (it.helperId ==
                                      SupabaseService.currentUser?.id)
                              ? it.helperRated
                              : it.helpedRated,
                          onChanged: () {
                            ref.invalidate(activeInteractionsCountProvider);
                            ref.invalidate(interactionsStreamProvider);
                          },
                        ),
                      ],
                    ),
                  ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final cfg = _config(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cfg.color.withValues(alpha: 0.18),
        border: Border.all(color: cfg.color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        cfg.label,
        style: AppTypography.label(size: 9, color: cfg.color),
      ),
    );
  }

  static ({String label, Color color}) _config(String s) {
    switch (s) {
      case 'pending':
        return (label: 'interactions.statusPending'.tr(), color: AppColors.amber);
      case 'accepted':
        return (label: 'interactions.statusAccepted'.tr(), color: AppColors.leben);
      case 'on_way':
        return (label: 'interactions.statusOnWay'.tr(), color: AppColors.teal);
      case 'arrived':
        return (label: 'interactions.statusArrived'.tr(), color: AppColors.tealSoft);
      case 'completed':
        return (label: 'interactions.statusCompleted'.tr(), color: AppColors.leben);
      case 'cancelled':
        return (label: 'interactions.statusCancelled'.tr(), color: AppColors.mute);
      default:
        return (label: s, color: AppColors.mute);
    }
  }
}

class _StatusActions extends ConsumerWidget {
  const _StatusActions({
    required this.interactionId,
    required this.status,
    required this.isHelper,
    required this.onChanged,
    this.partnerId,
    this.alreadyRated = false,
  });

  final String interactionId;
  final String status;
  final bool isHelper;
  final VoidCallback onChanged;
  final String? partnerId;
  final bool alreadyRated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Trust-Rating-CTA bei abgeschlossener Interaktion (Phase 5.4)
    if (status == 'completed' && partnerId != null && !alreadyRated) {
      return _RateButton(
        partnerId: partnerId!,
        interactionId: interactionId,
        onRated: onChanged,
      );
    }
    final next = _nextSteps(status, isHelper);
    if (next.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final step in next)
          _ActionPill(
            label: step.label,
            icon: step.icon,
            color: step.color,
            onTap: () async {
              final ok = await InteractionsRepository.setStatus(
                  interactionId, step.value);
              if (!context.mounted) return;
              AppSnackBar.info(
                  context,
                  ok
                      ? 'interactions.statusSet'
                          .tr(namedArgs: {'label': step.label})
                      : 'common.error'.tr());
              if (ok) onChanged();
              // D2 Stolz-Momente: erste abgeschlossene Hilfe als
              // Helfer:in → einmalige Dankes-Sequenz (Guard im Widget).
              if (ok && step.value == 'completed' && isHelper) {
                FirstHelpMoment.maybeShow(context, ref);
              }
            },
          ),
      ],
    );
  }

  List<_Step> _nextSteps(String s, bool isHelper) {
    // Helper-Flow: pending → accepted → on_way → arrived → completed
    // Helped-Flow: kann annehmen/ablehnen (pending), bewerten (completed)
    switch (s) {
      case 'pending':
        if (isHelper) {
          return [
            _Step('accepted', 'interactions.actAccept'.tr(), LucideIcons.check,
                AppColors.leben),
            _Step('cancelled', 'interactions.actReject'.tr(), LucideIcons.x,
                AppColors.herzrot),
          ];
        }
        return [
          _Step('cancelled', 'interactions.actWithdraw'.tr(), LucideIcons.x,
              AppColors.mute),
        ];
      case 'accepted':
        if (isHelper) {
          return [
            _Step('on_way', 'interactions.actOnWay'.tr(),
                LucideIcons.navigation, AppColors.tealSoft),
            _Step('cancelled', 'interactions.actCancel'.tr(), LucideIcons.x,
                AppColors.herzrot),
          ];
        }
        return const [];
      case 'on_way':
        if (isHelper) {
          return [
            _Step('arrived', 'interactions.actArrived'.tr(), LucideIcons.mapPin,
                AppColors.tealSoft),
          ];
        }
        return const [];
      case 'arrived':
        return [
          _Step('completed', 'interactions.actCompleted'.tr(),
              LucideIcons.checkCircle, AppColors.leben),
        ];
      case 'completed':
      case 'cancelled':
      default:
        return const [];
    }
  }
}

class _Step {
  const _Step(this.value, this.label, this.icon, this.color);
  final String value;
  final String label;
  final IconData icon;
  final Color color;
}

class _ActionPill extends StatefulWidget {
  const _ActionPill({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Future<void> Function() onTap;

  @override
  State<_ActionPill> createState() => _ActionPillState();
}

class _ActionPillState extends State<_ActionPill> {
  bool _busy = false;

  Future<void> _handle() async {
    // Doppel-Tap-Guard: ohne den konnte 'Annehmen' mehrfach gefeuert werden
    // (redundante Status-Updates / Notifications). Der Karma-Doppel-Credit
    // ist zusätzlich server-seitig per Trigger-Übergangsprüfung entschärft.
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onTap();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    return GestureDetector(
      onTap: _busy ? null : _handle,
      child: Opacity(
        opacity: _busy ? 0.5 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            border: Border.all(color: color.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 12, color: color),
              const SizedBox(width: 5),
              Text(widget.label,
                  style: AppTypography.label(size: 10, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Trust-Rating-CTA bei abgeschlossener Interaktion (Phase 5.4)
// ─────────────────────────────────────────────────────────────
class _RateButton extends StatefulWidget {
  const _RateButton({
    required this.partnerId,
    required this.interactionId,
    required this.onRated,
  });
  final String partnerId;
  final String interactionId;
  final VoidCallback onRated;

  @override
  State<_RateButton> createState() => _RateButtonState();
}

class _RateButtonState extends State<_RateButton> {
  String? _partnerName;

  @override
  void initState() {
    super.initState();
    _loadPartner();
  }

  Future<void> _loadPartner() async {
    final p = await ProfilesRepository.getById(widget.partnerId);
    if (!mounted) return;
    setState(() =>
        _partnerName = p?.displayName ?? p?.name ?? 'interactions.neighbor'.tr());
  }

  Future<void> _openRatingModal() async {
    final result = await TrustRatingModal.show(
      context,
      ratedUserId: widget.partnerId,
      ratedUserName: _partnerName ?? 'interactions.neighbor'.tr(),
      interactionId: widget.interactionId,
    );
    if (result == true) widget.onRated();
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _partnerName == null ? null : _openRatingModal,
      icon: const Icon(LucideIcons.star, size: 14),
      label: Text(_partnerName == null
          ? 'Lädt…'
          : 'Bewerten: ${_partnerName!}'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.voidColor,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
    );
  }
}
