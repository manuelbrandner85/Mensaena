import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/interaction.dart';
import '../../repositories/interactions_repository.dart';
import '../../services/supabase_service.dart';
import '../../widgets/effects/shimmer_skeleton.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';
import '../../widgets/shared/trust_rating_modal.dart';

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
                    const SizedBox(height: 120),
                    Center(
                      child: Column(
                        children: [
                          const Icon(
                            LucideIcons.helpingHand,
                            size: 32,
                            color: AppColors.mute,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Keine aktiven Interaktionen.',
                            style: AppTypography.body(
                              size: 14,
                              color: AppColors.mute,
                            ),
                          ),
                        ],
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
                  return Container(
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
        return (label: 'Wartet', color: AppColors.amber);
      case 'accepted':
        return (label: 'Angenommen', color: AppColors.leben);
      case 'on_way':
        return (label: 'Unterwegs', color: AppColors.teal);
      case 'arrived':
        return (label: 'Vor Ort', color: AppColors.tealSoft);
      case 'completed':
        return (label: 'Abgeschlossen', color: AppColors.leben);
      case 'cancelled':
        return (label: 'Abgebrochen', color: AppColors.mute);
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
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                backgroundColor: AppColors.surface,
                content: Text(
                  ok ? 'Status: ${step.label}' : 'Fehler.',
                  style:
                      AppTypography.body(size: 13, color: AppColors.ink),
                ),
              ));
              if (ok) onChanged();
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
          return const [
            _Step('accepted', 'Annehmen', LucideIcons.check, AppColors.leben),
            _Step('cancelled', 'Ablehnen', LucideIcons.x, AppColors.herzrot),
          ];
        }
        return const [
          _Step('cancelled', 'Anfrage zurueckziehen', LucideIcons.x,
              AppColors.mute),
        ];
      case 'accepted':
        if (isHelper) {
          return const [
            _Step('on_way', 'Unterwegs', LucideIcons.navigation,
                AppColors.tealSoft),
            _Step('cancelled', 'Absagen', LucideIcons.x, AppColors.herzrot),
          ];
        }
        return const [];
      case 'on_way':
        if (isHelper) {
          return const [
            _Step('arrived', 'Angekommen', LucideIcons.mapPin,
                AppColors.tealSoft),
          ];
        }
        return const [];
      case 'arrived':
        return const [
          _Step('completed', 'Abgeschlossen', LucideIcons.checkCircle,
              AppColors.leben),
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

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: AppTypography.label(size: 10, color: color)),
          ],
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
    try {
      final p = await sb
          .from('profiles')
          .select('name, display_name')
          .eq('id', widget.partnerId)
          .maybeSingle();
      if (!mounted) return;
      setState(() => _partnerName = (p?['display_name'] as String?) ??
          (p?['name'] as String?) ??
          'Nachbar:in');
    } catch (_) {
      if (mounted) setState(() => _partnerName = 'Nachbar:in');
    }
  }

  Future<void> _openRatingModal() async {
    final result = await TrustRatingModal.show(
      context,
      ratedUserId: widget.partnerId,
      ratedUserName: _partnerName ?? 'Nachbar:in',
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
