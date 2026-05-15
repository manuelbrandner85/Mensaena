import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/atmosphere/cinema_scaffold.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/dimensions.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/cinema_appbar.dart';
import '../../core/widgets/cinema_empty_state.dart';
import '../../core/widgets/cinema_input.dart';
import '../../core/widgets/cinema_loading_skeleton.dart';
import '../../core/widgets/cinema_select.dart';
import '../../core/widgets/cinema_sheet.dart';
import '../../core/widgets/cinema_toast.dart';
import '../../core/widgets/glow_button.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase/supabase_service.dart';

/// Stream aller Zeitbank-Eintraege des eingeloggten Users.
final timebankEntriesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  final res = await supabase.client
      .from('timebank_entries')
      .select()
      .eq('user_id', user.id)
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(res as List);
});

/// Gesamtsaldo: Summe aller hours, +earned, -spent.
final timebankBalanceProvider = Provider<double>((ref) {
  final entries = ref.watch(timebankEntriesProvider).asData?.value ?? const [];
  var sum = 0.0;
  for (final e in entries) {
    final h = (e['hours'] as num?)?.toDouble() ?? 0;
    final type = e['type'] as String?;
    sum += type == 'earned' ? h : -h;
  }
  return sum;
});

class TimebankScreen extends ConsumerWidget {
  const TimebankScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(timebankEntriesProvider);
    final balance = ref.watch(timebankBalanceProvider);

    return CinemaScaffold(
      appBar: const CinemaAppBar(title: 'ZEITBANK'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: MnColors.amber,
        foregroundColor: MnColors.voidColor,
        onPressed: () => _showAddEntry(context, ref),
        icon: const Icon(LucideIcons.plus, color: MnColors.voidColor),
        label: const Text('Zeit eintragen'),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gib Zeit, bekomme Zeit.',
                      style: MnTypography.display(size: 22),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tracke geleistete und erhaltene Stunden in deiner Nachbarschaft.',
                      style: MnTypography.body(color: MnColors.inkSoft),
                    ),
                    const SizedBox(height: 20),
                    _BalanceCard(balance: balance),
                  ],
                ),
              ),
            ),
            entries.when(
              loading: () => const SliverToBoxAdapter(
                child: CinemaLoadingSkeleton(variant: SkeletonVariant.list),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: CinemaEmptyState(
                  icon: LucideIcons.alertCircle,
                  title: 'Fehler',
                  message: e.toString(),
                ),
              ),
              data: (rows) {
                if (rows.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: CinemaEmptyState(
                      icon: LucideIcons.clock,
                      title: 'Noch keine Eintraege.',
                      message: 'Trage deine erste geleistete oder erhaltene Stunde ein.',
                    ),
                  );
                }
                return SliverList.builder(
                  itemCount: rows.length,
                  itemBuilder: (_, i) => _EntryTile(entry: rows[i]),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }

  void _showAddEntry(BuildContext context, WidgetRef ref) {
    final activity = TextEditingController();
    final hours = TextEditingController();
    String type = 'earned';

    CinemaSheet.show<void>(
      context,
      initialSize: 0.55,
      child: StatefulBuilder(
        builder: (ctx, setSt) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Zeit eintragen', style: MnTypography.display(size: 22)),
            const SizedBox(height: 16),
            CinemaInput(
              controller: activity,
              label: 'AKTIVITAET',
              placeholder: 'z.B. Einkaufen geholfen',
            ),
            const SizedBox(height: 12),
            CinemaInput(
              controller: hours,
              label: 'STUNDEN',
              placeholder: '1.5',
              variant: CinemaInputVariant.number,
            ),
            const SizedBox(height: 12),
            CinemaSelect<String>(
              label: 'TYP',
              value: type,
              options: const [
                CinemaSelectOption(value: 'earned', label: 'Gegeben (+)'),
                CinemaSelectOption(value: 'spent', label: 'Erhalten (−)'),
              ],
              onChanged: (v) => setSt(() => type = v),
            ),
            const SizedBox(height: 20),
            GlowButton(
              label: 'Eintragen',
              variant: GlowVariant.primary,
              fullWidth: true,
              onPressed: () async {
                final user = ref.read(currentUserProvider);
                if (user == null) return;
                final h = double.tryParse(hours.text.replaceAll(',', '.'));
                if (activity.text.trim().isEmpty || h == null || h <= 0) {
                  CinemaToast.show(
                    ctx,
                    variant: ToastVariant.warning,
                    message: 'Bitte Aktivitaet und gueltige Stundenzahl angeben.',
                  );
                  return;
                }
                try {
                  await supabase.client.from('timebank_entries').insert({
                    'user_id': user.id,
                    'activity': activity.text.trim(),
                    'hours': h,
                    'type': type,
                  });
                  ref.invalidate(timebankEntriesProvider);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (context.mounted) {
                    CinemaToast.show(
                      context,
                      variant: ToastVariant.success,
                      message: 'Eintrag gespeichert.',
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    CinemaToast.show(
                      ctx,
                      variant: ToastVariant.error,
                      message: 'Speichern fehlgeschlagen: $e',
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final double balance;
  const _BalanceCard({required this.balance});

  @override
  Widget build(BuildContext context) {
    final positive = balance >= 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MnColors.surface,
        borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
        border: Border.all(color: MnColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AKTUELLER SALDO',
            style: MnTypography.label(color: MnColors.mute),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${positive ? '+' : ''}${balance.toStringAsFixed(1)}',
                style: MnTypography.mono(
                  size: 40,
                  color: positive ? MnColors.leben : MnColors.amberWarm,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Stunden',
                  style: MnTypography.body(color: MnColors.mute, size: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _EntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final type = entry['type'] as String?;
    final earned = type == 'earned';
    final hours = (entry['hours'] as num?)?.toDouble() ?? 0;
    final created = entry['created_at'] as String?;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MnColors.elevated,
        borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
        border: Border.all(color: MnColors.line),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (earned ? MnColors.leben : MnColors.amber)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              earned ? LucideIcons.arrowUpRight : LucideIcons.arrowDownLeft,
              color: earned ? MnColors.leben : MnColors.amber,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (entry['activity'] as String?) ?? '',
                  style: MnTypography.body(
                    color: MnColors.ink,
                    weight: FontWeight.w600,
                  ),
                ),
                if (created != null)
                  Text(
                    created.substring(0, 10),
                    style: MnTypography.mono(size: 11, color: MnColors.mute),
                  ),
              ],
            ),
          ),
          Text(
            '${earned ? '+' : '−'}${hours.toStringAsFixed(1)}h',
            style: MnTypography.mono(
              color: earned ? MnColors.leben : MnColors.amber,
              size: 16,
              weight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
