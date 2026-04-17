import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/providers/timebank_provider.dart';
import 'package:mensaena/models/timebank_entry.dart';
import 'package:mensaena/widgets/empty_state.dart';
import 'package:mensaena/widgets/loading_skeleton.dart';

class TimebankScreen extends ConsumerWidget {
  const TimebankScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(timebankBalanceProvider);
    final entriesAsync = ref.watch(timebankEntriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zeitbank'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(timebankBalanceProvider);
          ref.invalidate(timebankEntriesProvider);
        },
        color: AppColors.primary500,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Balance card
            balanceAsync.when(
              loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Text('Fehler: $e'),
              data: (balance) => Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary500, AppColors.primary700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppShadows.glow,
                ),
                child: Column(
                  children: [
                    const Text('Dein Zeitkonto', style: TextStyle(fontSize: 14, color: Colors.white70)),
                    const SizedBox(height: 8),
                    Text(
                      '${(balance['balance'] ?? 0).toStringAsFixed(1)} Std.',
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _BalanceItem(label: 'Gegeben', value: '${(balance['given'] ?? 0).toStringAsFixed(1)}h', icon: Icons.arrow_upward),
                        Container(width: 1, height: 40, color: Colors.white24),
                        _BalanceItem(label: 'Erhalten', value: '${(balance['received'] ?? 0).toStringAsFixed(1)}h', icon: Icons.arrow_downward),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Entries
            const Text('Verlauf', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),

            entriesAsync.when(
              loading: () => const LoadingSkeleton(type: SkeletonType.card),
              error: (e, _) => Center(child: Text('Fehler: $e')),
              data: (entries) {
                if (entries.isEmpty) {
                  return const EmptyState(
                    icon: Icons.access_time_outlined,
                    title: 'Noch keine Eintraege',
                    message: 'Hilf jemandem, um Zeitstunden zu sammeln!',
                  );
                }
                return Column(
                  children: entries.map((entry) => _EntryCard(entry: entry)).toList(),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateEntryDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Stunden eintragen'),
      ),
    );
  }

  void _showCreateEntryDialog(BuildContext context, WidgetRef ref) {
    final hoursCtrl = TextEditingController(text: '1.0');
    final descCtrl = TextEditingController();
    final receiverCtrl = TextEditingController();
    String category = 'general';

    final categories = ['general', 'food', 'everyday', 'moving', 'animals', 'housing', 'knowledge', 'skills', 'mental', 'mobility', 'sharing'];
    final categoryLabels = {'general': 'Allgemein', 'food': 'Essen', 'everyday': 'Alltag', 'moving': 'Umzug', 'animals': 'Tiere', 'housing': 'Wohnen', 'knowledge': 'Wissen', 'skills': 'Fähigkeiten', 'mental': 'Mental', 'mobility': 'Mobilität', 'sharing': 'Teilen'};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: StatefulBuilder(builder: (ctx, setBS) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Stunden eintragen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Trage geleistete Hilfe ein', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
            const SizedBox(height: 16),
            TextField(controller: receiverCtrl, decoration: const InputDecoration(labelText: 'Empfaenger-ID *', hintText: 'User-ID der Person')),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Beschreibung *'), maxLines: 2),
            const SizedBox(height: 12),
            TextField(controller: hoursCtrl, decoration: const InputDecoration(labelText: 'Stunden', suffixText: 'h'), keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: category,
              decoration: const InputDecoration(labelText: 'Kategorie'),
              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(categoryLabels[c] ?? c))).toList(),
              onChanged: (v) => setBS(() => category = v ?? 'general'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (descCtrl.text.trim().isEmpty || receiverCtrl.text.trim().isEmpty) return;
                  final userId = ref.read(currentUserIdProvider);
                  if (userId == null) return;
                  Navigator.pop(ctx);
                  try {
                    await ref.read(timebankServiceProvider).createEntry({
                      'giver_id': userId,
                      'receiver_id': receiverCtrl.text.trim(),
                      'hours': double.tryParse(hoursCtrl.text) ?? 1.0,
                      'description': descCtrl.text.trim(),
                      'category': category,
                      'status': 'pending',
                    });
                    ref.invalidate(timebankEntriesProvider);
                    ref.invalidate(timebankBalanceProvider);
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
                  }
                },
                child: const Text('Eintragen'),
              ),
            ),
          ],
        )),
      ),
    );
  }
}

class _BalanceItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _BalanceItem({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  final TimebankEntry entry;
  const _EntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: entry.isConfirmed ? AppColors.success.withValues(alpha: 0.1) : AppColors.primary50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              entry.isConfirmed ? Icons.check_circle_outline : Icons.access_time,
              color: entry.isConfirmed ? AppColors.success : AppColors.primary500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description ?? 'Hilfe',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  entry.category ?? 'Allgemein',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                Text(
                  timeago.format(entry.createdAt, locale: 'de'),
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.hours.toStringAsFixed(1)}h',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary500),
              ),
              Text(
                entry.isPending ? 'Ausstehend' : 'Bestätigt',
                style: TextStyle(
                  fontSize: 11,
                  color: entry.isPending ? AppColors.warning : AppColors.success,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
