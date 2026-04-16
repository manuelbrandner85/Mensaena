import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/widgets/avatar_widget.dart';
import 'package:mensaena/widgets/trust_score_badge.dart';

class PublicProfileScreen extends ConsumerWidget {
  final String userId;
  const PublicProfileScreen({super.key, required this.userId});

  @override Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider(userId));
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (p) {
          if (p == null) return const Center(child: Text('Profil nicht gefunden'));
          return ListView(padding: const EdgeInsets.all(16), children: [
            Center(child: AvatarWidget(imageUrl: p.avatarUrl, name: p.displayName, size: 80)),
            const SizedBox(height: 12),
            Center(child: Text(p.displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
            if (p.bio != null) ...[const SizedBox(height: 8), Center(child: Text(p.bio!, style: const TextStyle(color: AppColors.textMuted), textAlign: TextAlign.center))],
            const SizedBox(height: 16),
            Center(child: TrustScoreBadge(score: p.trustScore, size: TrustBadgeSize.large)),
            const SizedBox(height: 16),
            if (p.location != null) ListTile(leading: const Icon(Icons.location_on_outlined), title: Text(p.location!), contentPadding: EdgeInsets.zero),
            if (p.skills.isNotEmpty) Wrap(spacing: 6, runSpacing: 6, children: p.skills.map((s) => Chip(label: Text(s, style: const TextStyle(fontSize: 12)), backgroundColor: AppColors.primary50, side: BorderSide.none)).toList()),
          ]);
        },
      ),
    );
  }
}