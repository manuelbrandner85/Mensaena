import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/timebank_entry.dart';
import '../../repositories/timebank_repository.dart';
import '../../services/supabase_service.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features
/// Zeitbank-Screen: Stundenkonto + Eintraege-Historie + Bestaetigungs-System.
class TimebankScreen extends ConsumerWidget {
  const TimebankScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(timebankBalanceProvider);
    final entries = ref.watch(timebankEntriesProvider);
    return DashboardScaffold(
      title: 'Zeitbank',
      currentRoute: '/dashboard/timebank',
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.amber,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            ref.invalidate(timebankBalanceProvider);
            ref.invalidate(timebankEntriesProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _BalanceCard(balance: balance),
              const SizedBox(height: 16),
              Text('Historie', style: AppTypography.label(size: 10)),
              const SizedBox(height: 8),
              entries.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.amber),
                ),
                error: (e, _) => Text(
                  'Fehler: $e',
                  style: AppTypography.caption(),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.4),
                        border: Border.all(color: AppColors.line),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            LucideIcons.clock,
                            size: 28,
                            color: AppColors.mute,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Noch keine Eintraege. Sobald du Nachbar:innen '
                            'hilfst, kannst du die Stunden hier eintragen.',
                            textAlign: TextAlign.center,
                            style: AppTypography.body(
                              size: 13,
                              color: AppColors.inkSoft,
                              height: 1.55,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: list.map((e) => _EntryTile(entry: e)).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});
  final AsyncValue<TimebankBalance> balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: balance.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.amber),
        ),
        error: (e, _) =>
            Text('$e', style: AppTypography.caption()),
        data: (b) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.clock, color: AppColors.amber),
                const SizedBox(width: 8),
                Text(
                  'Stundenkonto',
                  style: AppTypography.label(size: 10),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  b.balance.toStringAsFixed(1),
                  style: AppTypography.display(
                    size: 38,
                    color: AppColors.ink,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'h',
                  style: AppTypography.mono(
                    size: 18,
                    color: AppColors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              b.balance >= 0
                  ? 'Du hast mehr Hilfe bekommen als gegeben.'
                  : 'Du hast mehr Hilfe gegeben als bekommen.',
              style: AppTypography.caption(),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Gegeben',
                    value: b.given,
                    color: AppColors.teal,
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Empfangen',
                    value: b.received,
                    color: AppColors.leben,
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Offen',
                    value: b.pendingAsReceiver + b.pendingAsGiver,
                    color: AppColors.amber,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.label(size: 9)),
        const SizedBox(height: 4),
        Text(
          '${value.toStringAsFixed(1)}h',
          style: AppTypography.mono(size: 16, color: color),
        ),
      ],
    );
  }
}

class _EntryTile extends ConsumerWidget {
  const _EntryTile({required this.entry});
  final TimebankEntry entry;

  static const Map<String, ({String label, Color color})> _status = {
    'pending': (label: 'Wartet', color: AppColors.amber),
    'confirmed': (label: 'Bestätigt', color: AppColors.leben),
    'rejected': (label: 'Abgelehnt', color: AppColors.herzrot),
    'cancelled': (label: 'Abgebrochen', color: AppColors.mute),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = SupabaseService.currentUser?.id;
    final isReceiver = entry.receiverId == me;
    final canConfirm = isReceiver && entry.status == 'pending';
    final s = _status[entry.status ?? 'pending'] ??
        (label: entry.status ?? 'pending', color: AppColors.mute);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: s.color.withValues(alpha: 0.18),
                  border: Border.all(color: s.color.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(s.label,
                    style: AppTypography.label(size: 9, color: s.color)),
              ),
              const SizedBox(width: 8),
              Text(
                isReceiver ? 'Du empfangen' : 'Du gegeben',
                style: AppTypography.label(size: 9),
              ),
              const Spacer(),
              Text(
                '${entry.hours.toStringAsFixed(1)}h',
                style: AppTypography.mono(size: 14, color: AppColors.amber),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            entry.description,
            style: AppTypography.body(
              size: 13,
              color: AppColors.inkSoft,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat('dd.MM.yyyy HH:mm').format(entry.createdAt),
            style: AppTypography.caption(),
          ),
          if (canConfirm) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.leben,
                      foregroundColor: AppColors.voidColor,
                    ),
                    onPressed: () async {
                      await TimebankRepository.confirm(entry.id);
                      ref.invalidate(timebankBalanceProvider);
                      ref.invalidate(timebankEntriesProvider);
                    },
                    child: const Text('Bestätigen'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await TimebankRepository.reject(entry.id);
                      ref.invalidate(timebankBalanceProvider);
                      ref.invalidate(timebankEntriesProvider);
                    },
                    child: const Text('Ablehnen'),
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
