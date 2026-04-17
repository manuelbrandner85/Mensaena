import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/crisis_provider.dart';
import 'package:mensaena/models/crisis.dart';

class CrisisScreen extends ConsumerStatefulWidget {
  const CrisisScreen({super.key});
  @override
  ConsumerState<CrisisScreen> createState() => _CrisisScreenState();
}

class _CrisisScreenState extends ConsumerState<CrisisScreen> {
  String? _selectedCategory;
  String _statusFilter = 'active';

  @override
  Widget build(BuildContext context) {
    final crises = ref.watch(activeCrisesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('⚠️ Krisenmeldungen'),
        backgroundColor: AppColors.emergencyLight,
      ),
      body: Column(
        children: [
          // Status filter
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                _StatusChip(label: 'Aktiv', value: 'active', selected: _statusFilter, onTap: (v) => setState(() => _statusFilter = v)),
                const SizedBox(width: 6),
                _StatusChip(label: 'In Bearbeitung', value: 'in_progress', selected: _statusFilter, onTap: (v) => setState(() => _statusFilter = v)),
                const SizedBox(width: 6),
                _StatusChip(label: 'Geloest', value: 'resolved', selected: _statusFilter, onTap: (v) => setState(() => _statusFilter = v)),
              ],
            ),
          ),
          // Category filter
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _CatChip(label: 'Alle', emoji: '📋', selected: _selectedCategory == null, onTap: () => setState(() => _selectedCategory = null)),
                ...CrisisCategory.values.map((cat) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _CatChip(label: cat.label, emoji: cat.emoji, selected: _selectedCategory == cat.value, onTap: () => setState(() => _selectedCategory = cat.value)),
                )),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Crisis list
          Expanded(
            child: crises.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Fehler: $e')),
              data: (list) {
                var filtered = list.where((c) {
                  if (_statusFilter == 'active') return c.status == 'active' || c.status == 'in_progress';
                  return c.status == _statusFilter;
                }).toList();
                if (_selectedCategory != null) {
                  filtered = filtered.where((c) => c.type == _selectedCategory).toList();
                }
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_statusFilter == 'active' ? Icons.check_circle_outline : Icons.history,
                            size: 56, color: _statusFilter == 'active' ? AppColors.success : AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(_statusFilter == 'active' ? 'Keine aktiven Krisen' : 'Keine Eintraege',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                        if (_statusFilter == 'active')
                          const Text('Alles in Ordnung!', style: TextStyle(color: AppColors.textMuted)),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(activeCrisesProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _CrisisCard(
                      crisis: filtered[i],
                      onTap: () => context.push('/dashboard/crisis/${filtered[i].id}'),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/dashboard/crisis/create'),
        backgroundColor: AppColors.emergency,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.warning),
        label: const Text('Krise melden'),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final void Function(String) onTap;
  const _StatusChip({required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sel = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? AppColors.emergency : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? AppColors.emergency : AppColors.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sel ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;
  const _CatChip({required this.label, required this.emoji, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.emergencyLight : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.emergency : AppColors.border),
        ),
        child: Text('$emoji $label', style: TextStyle(fontSize: 11, color: selected ? AppColors.emergency : AppColors.textSecondary)),
      ),
    );
  }
}

class _CrisisCard extends StatelessWidget {
  final Crisis crisis;
  final VoidCallback onTap;
  const _CrisisCard({required this.crisis, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final urgencyColor = _getUrgencyColor(crisis.urgency);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: crisis.urgency == CrisisUrgency.critical ? AppColors.emergency.withValues(alpha: 0.5) : AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(crisis.crisisCategory.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(crisis.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: urgencyColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(crisis.urgency.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: urgencyColor)),
                  ),
                ],
              ),
              if (crisis.description != null && crisis.description!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(crisis.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3)),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  if (crisis.address != null) ...[
                    const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 3),
                    Expanded(child: Text(crisis.address!, style: const TextStyle(fontSize: 11, color: AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                  if (crisis.helperCount != null && crisis.helperCount! > 0) ...[
                    const Icon(Icons.people_outline, size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 3),
                    Text('${crisis.helperCount} Helfer', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    const SizedBox(width: 8),
                  ],
                  Text(timeago.format(crisis.createdAt, locale: 'de'), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  if (crisis.verified) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, size: 14, color: AppColors.info),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getUrgencyColor(CrisisUrgency urgency) {
    switch (urgency) {
      case CrisisUrgency.critical: return AppColors.emergency;
      case CrisisUrgency.high: return const Color(0xFFF97316);
      case CrisisUrgency.medium: return AppColors.warning;
      case CrisisUrgency.low: return AppColors.success;
    }
  }
}
