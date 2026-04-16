import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Admin-Dashboard')),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Fehler: $e')),
        data: (p) {
          if (p == null || p.role != 'admin') {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 56, color: AppColors.textMuted),
                  SizedBox(height: 16),
                  Text('Kein Zugriff', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  SizedBox(height: 8),
                  Text('Du hast keine Admin-Berechtigung.', style: TextStyle(color: AppColors.textMuted)),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Stats overview
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.trust, Color(0xFF374151)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Admin-Bereich', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                    SizedBox(height: 4),
                    Text('Plattform verwalten', style: TextStyle(fontSize: 14, color: Colors.white70)),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Admin modules
              _AdminTile(
                icon: Icons.people_outline,
                title: 'Benutzer verwalten',
                subtitle: 'Profile, Rollen, Sperren',
                color: AppColors.primary500,
                onTap: () {},
              ),
              _AdminTile(
                icon: Icons.article_outlined,
                title: 'Beitraege moderieren',
                subtitle: 'Gemeldete Inhalte pruefen',
                color: AppColors.info,
                onTap: () => context.push('/dashboard/posts'),
              ),
              _AdminTile(
                icon: Icons.warning_amber,
                title: 'Krisenmeldungen',
                subtitle: 'Krisen verifizieren und verwalten',
                color: AppColors.emergency,
                onTap: () => context.push('/dashboard/crisis'),
              ),
              _AdminTile(
                icon: Icons.business_outlined,
                title: 'Organisationen',
                subtitle: 'Organisationen pruefen und freigeben',
                color: AppColors.trust,
                onTap: () => context.push('/dashboard/organizations'),
              ),
              _AdminTile(
                icon: Icons.analytics_outlined,
                title: 'Statistiken',
                subtitle: 'Plattform-Kennzahlen',
                color: AppColors.success,
                onTap: () {},
              ),
              _AdminTile(
                icon: Icons.flag_outlined,
                title: 'Meldungen',
                subtitle: 'Gemeldete Inhalte und Nutzer',
                color: AppColors.warning,
                onTap: () {},
              ),
              _AdminTile(
                icon: Icons.settings_outlined,
                title: 'Systemeinstellungen',
                subtitle: 'Plattform-Konfiguration',
                color: AppColors.textSecondary,
                onTap: () {},
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AdminTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _AdminTile({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
