import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/crisis_provider.dart';
import 'package:mensaena/providers/auth_provider.dart';

class CrisisDetailScreen extends ConsumerWidget {
  final String crisisId;
  const CrisisDetailScreen({super.key, required this.crisisId});
  @override Widget build(BuildContext context, WidgetRef ref) {
    final crisis = ref.watch(crisisDetailProvider(crisisId));
    return Scaffold(
      appBar: AppBar(title: const Text('Krisenmeldung'), backgroundColor: AppColors.emergencyLight),
      body: crisis.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (c) {
          if (c == null) return const Center(child: Text('Nicht gefunden'));
          return ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [Text(c.crisisCategory.emoji, style: const TextStyle(fontSize: 32)), const SizedBox(width: 12),
              Expanded(child: Text(c.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)))]),
            const SizedBox(height: 12),
            if (c.description != null) Text(c.description!, style: const TextStyle(fontSize: 15, height: 1.5)),
            const SizedBox(height: 16),
            if (c.address != null) ListTile(leading: const Icon(Icons.location_on), title: Text(c.address!), contentPadding: EdgeInsets.zero),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: () async {
                final userId = ref.read(currentUserIdProvider);
                if (userId == null) return;
                await ref.read(crisisServiceProvider).offerHelp(crisisId: crisisId, userId: userId);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hilfe angeboten!')));
              },
              icon: const Icon(Icons.volunteer_activism), label: const Text('Hilfe anbieten'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary500))),
          ]);
        },
      ),
    );
  }
}