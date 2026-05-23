import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../models/crisis.dart';
import '../../../repositories/crisis_repository.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features + mensaena-design
/// Krisen-Dashboard: aktive Krisen sortiert nach Urgency + Zeit.
class CrisisDashboardScreen extends ConsumerWidget {
  const CrisisDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activeCrisesProvider);
    return DashboardScaffold(
      title: 'Krisenmodus',
      currentRoute: '/dashboard/crisis',
      fab: FloatingActionButton.extended(
        backgroundColor: AppColors.herzrot,
        foregroundColor: AppColors.ink,
        onPressed: () => context.go('/dashboard/crisis/create'),
        icon: const Icon(LucideIcons.alertTriangle),
        label: const Text('Krise melden'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.herzrot,
          backgroundColor: AppColors.surface,
          onRefresh: () async => ref.refresh(activeCrisesProvider),
          child: async.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.herzrot),
            ),
            error: (e, _) => Center(
              child: Text('Fehler: $e', style: AppTypography.caption()),
            ),
            data: (list) {
              if (list.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 60),
                    _NoActive(),
                    const SizedBox(height: 24),
                    _ResourcesCta(),
                  ],
                );
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    '${list.length} aktive Krise${list.length == 1 ? "" : "n"}',
                    style: AppTypography.label(size: 10),
                  ),
                  const SizedBox(height: 10),
                  ...list.map((c) => _CrisisTile(crisis: c)),
                  const SizedBox(height: 16),
                  _ResourcesCta(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NoActive extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const Icon(LucideIcons.shieldCheck, size: 40, color: AppColors.leben),
            const SizedBox(height: 14),
            Text(
              'Aktuell keine aktiven Krisen in deiner Nähe.',
              textAlign: TextAlign.center,
              style: AppTypography.display(
                size: 22,
                color: AppColors.ink,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Im Notfall: 112 anrufen. Krise hier melden — sammelt schnelle '
              'Hilfsangebote aus deiner Nachbarschaft.',
              textAlign: TextAlign.center,
              style: AppTypography.body(
                size: 13,
                color: AppColors.inkSoft,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourcesCta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.phone, color: AppColors.herzrot),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notruf-Nummern',
                  style: AppTypography.body(
                    size: 14,
                    color: AppColors.ink,
                    weight: FontWeight.w600,
                  ),
                ),
                Text(
                  '112 · 110 · 116117 · Telefonseelsorge 0800 1110111',
                  style: AppTypography.caption(),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.chevronRight),
            color: AppColors.amber,
            onPressed: () =>
                context.go('/dashboard/crisis/resources'),
          ),
        ],
      ),
    );
  }
}

class _CrisisTile extends StatelessWidget {
  const _CrisisTile({required this.crisis});
  final Crisis crisis;

  static const Map<String, Color> _urgencyColors = {
    'critical': AppColors.herzrot,
    'high': Color(0xFFFB923C),
    'medium': AppColors.amber,
    'low': AppColors.teal,
  };

  static const Map<String, String> _urgencyLabel = {
    'critical': 'KRITISCH',
    'high': 'HOCH',
    'medium': 'MITTEL',
    'low': 'NIEDRIG',
  };

  @override
  Widget build(BuildContext context) {
    final color = _urgencyColors[crisis.urgency] ?? AppColors.amber;
    return InkWell(
      onTap: () => context.go('/dashboard/crisis/${crisis.id}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.4),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _urgencyLabel[crisis.urgency] ?? crisis.urgency.toUpperCase(),
                    style: AppTypography.label(
                      size: 9,
                      color: AppColors.voidColor,
                      letterSpacing: 0.15,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  crisis.category.toUpperCase(),
                  style: AppTypography.label(size: 9, color: color),
                ),
                const Spacer(),
                if (crisis.createdAt != null)
                  Text(
                    DateFormat('dd.MM. HH:mm').format(crisis.createdAt!),
                    style: AppTypography.caption(),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              crisis.title,
              style: AppTypography.display(
                size: 18,
                color: AppColors.ink,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              crisis.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(
                size: 13,
                color: AppColors.inkSoft,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(LucideIcons.helpingHand,
                    size: 12, color: AppColors.leben),
                const SizedBox(width: 4),
                Text(
                  '${crisis.helperCount ?? 0} Helfer:in',
                  style:
                      AppTypography.mono(size: 11, color: AppColors.lebenSoft),
                ),
                const Spacer(),
                if (crisis.locationText != null) ...[
                  const Icon(LucideIcons.mapPin,
                      size: 12, color: AppColors.mute),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      crisis.locationText!,
                      style: AppTypography.body(
                        size: 11,
                        color: AppColors.mute,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
