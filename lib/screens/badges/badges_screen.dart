import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mensaena/config/theme.dart';

class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  static const _badges = [
    {'name': 'Erster Beitrag', 'icon': Icons.edit_outlined, 'desc': 'Erstelle deinen ersten Beitrag', 'color': AppColors.primary500},
    {'name': 'Helfer', 'icon': Icons.volunteer_activism, 'desc': 'Hilf 5 Personen', 'color': AppColors.success},
    {'name': 'Vertrauenswuerdig', 'icon': Icons.shield_outlined, 'desc': 'Erreiche Vertrauensscore 50', 'color': AppColors.trust},
    {'name': 'Netzwerker', 'icon': Icons.people_outline, 'desc': 'Tritt 3 Gruppen bei', 'color': AppColors.info},
    {'name': 'Eventmanager', 'icon': Icons.event_outlined, 'desc': 'Erstelle ein Event', 'color': AppColors.categoryMobility},
    {'name': 'Krisenhelfer', 'icon': Icons.warning_amber, 'desc': 'Hilf bei einer Krise', 'color': AppColors.emergency},
    {'name': 'Zeitspender', 'icon': Icons.access_time, 'desc': 'Spende 10 Stunden', 'color': AppColors.primary700},
    {'name': 'Challenge-Champion', 'icon': Icons.emoji_events_outlined, 'desc': 'Schliesse 5 Challenges ab', 'color': Color(0xFFFFB800)},
    {'name': 'Nachbar des Monats', 'icon': Icons.star_outline, 'desc': 'Werde zum Nachbar des Monats gewaehlt', 'color': Color(0xFFFFD700)},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Badges')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: _badges.length,
        itemBuilder: (context, index) {
          final badge = _badges[index];
          final earned = index < 2; // Placeholder: first 2 earned

          return GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(badge['name'] as String),
                  content: Text(badge['desc'] as String),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                  ],
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: earned ? (badge['color'] as Color).withValues(alpha: 0.08) : AppColors.borderLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: earned ? (badge['color'] as Color).withValues(alpha: 0.3) : AppColors.border,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: earned
                          ? (badge['color'] as Color).withValues(alpha: 0.15)
                          : AppColors.border,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      badge['icon'] as IconData,
                      color: earned ? badge['color'] as Color : AppColors.textMuted,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    badge['name'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: earned ? AppColors.textPrimary : AppColors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!earned)
                    const Icon(Icons.lock_outline, size: 12, color: AppColors.textMuted),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
