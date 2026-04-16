import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/crisis_provider.dart';
import 'package:mensaena/models/crisis.dart';

class CrisisScreen extends ConsumerWidget {
  const CrisisScreen({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) {
    final crises = ref.watch(activeCrisesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('⚠️ Krisenmeldungen'), backgroundColor: AppColors.emergencyLight),
      body: crises.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (list) => list.isEmpty
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.check_circle_outline, size: 56, color: AppColors.success), SizedBox(height: 12),
              Text('Keine aktiven Krisen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              Text('Alles in Ordnung!', style: TextStyle(color: AppColors.textMuted))]))
          : ListView.builder(padding: const EdgeInsets.all(12), itemCount: list.length,
              itemBuilder: (_, i) => _CrisisCard(crisis: list[i], onTap: () => context.push('/dashboard/crisis/${list[i].id}'))),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/dashboard/crisis/create'),
        backgroundColor: AppColors.emergency, foregroundColor: Colors.white,
        icon: const Icon(Icons.warning), label: const Text('Krise melden')),
    );
  }
}

class _CrisisCard extends StatelessWidget {
  final Crisis crisis; final VoidCallback onTap;
  const _CrisisCard({required this.crisis, required this.onTap});
  @override Widget build(BuildContext context) {
    return Card(margin: const EdgeInsets.only(bottom: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: crisis.urgency == CrisisUrgency.critical ? AppColors.emergency : AppColors.border)),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16),
        child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(crisis.crisisCategory.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Expanded(child: Text(crisis.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(
              color: crisis.urgency == CrisisUrgency.critical ? AppColors.emergencyLight : AppColors.primary50,
              borderRadius: BorderRadius.circular(8)),
              child: Text(crisis.urgency.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: crisis.urgency == CrisisUrgency.critical ? AppColors.emergency : AppColors.primary500))),
          ]),
          if (crisis.address != null) ...[const SizedBox(height: 6), Row(children: [
            const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted), const SizedBox(width: 4),
            Text(crisis.address!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted))])],
          const SizedBox(height: 4),
          Text(timeago.format(crisis.createdAt, locale: 'de'), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ]))));
  }
}