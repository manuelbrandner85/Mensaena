import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/app_config.dart';
import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

/// SKILL: mensaena-design + flutter-build-responsive-layout
/// Landing — minimaler Cinema-Hero. Volle 9-Section-Variante kommt in
/// Phase 2 (Hero + Stats + Features + HowItWorks + Categories +
/// Testimonials + Map + Spenden + CTA).
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '— 01 / Deine Nachbarschaft',
                    style: AppTypography.label(
                      size: 11,
                      color: AppColors.amber,
                      letterSpacing: 0.15,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Nachbarschaft,\nneu gedacht.',
                    style: AppTypography.display(
                      size: 52,
                      height: 1.05,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    AppConfig.appTagline,
                    style: AppTypography.body(
                      size: 17,
                      color: AppColors.inkSoft,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kostenlos, gemeinnützig, von der Gemeinschaft getragen.',
                    style: AppTypography.body(
                      size: 16,
                      color: AppColors.mute,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 36),
                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => context.go('/auth?mode=register'),
                        icon: const Icon(LucideIcons.arrowRight, size: 16),
                        label: const Text('Kostenlos starten'),
                      ),
                      OutlinedButton(
                        onPressed: () => context.go('/auth?mode=login'),
                        child: const Text('Bereits dabei? Anmelden'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  const _Facts(),
                  const SizedBox(height: 64),
                  Center(
                    child: Text(
                      'Phase 1 — Setup\nVolle Landing folgt in Phase 2',
                      textAlign: TextAlign.center,
                      style: AppTypography.caption(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Facts extends StatelessWidget {
  const _Facts();

  static const List<({String k, String v})> _items = [
    (k: 'Preis', v: 'Kostenlos'),
    (k: 'Datenschutz', v: 'DSGVO-konform'),
    (k: 'Organisation', v: 'Gemeinnützig'),
    (k: 'Werbung', v: 'keine'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cross = c.maxWidth < 460 ? 2 : 4;
        return GridView.count(
          crossAxisCount: cross,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: _items.map(_factCard).toList(),
        );
      },
    );
  }

  Widget _factCard(({String k, String v}) f) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(f.k, style: AppTypography.label(size: 10)),
          const SizedBox(height: 4),
          Text(
            f.v,
            style: AppTypography.body(
              size: 14,
              color: AppColors.ink,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
