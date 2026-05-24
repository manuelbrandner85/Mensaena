import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../config/theme/cinema_theme.dart';
import '../effects/glass_card.dart';
import '../effects/lens_flare.dart';

/// SKILL: mensaena-design
/// 6-Step Cinematic Onboarding-Tour mit Spotlight-Overlay, frosted-glass
/// Tooltip-Box, LensFlare auf dem Highlight und Bronze-Step-Dots.
///
/// Persistenz via flutter_secure_storage Flag `mensaena_onboarding_v2_done`.
class OnboardingTour {
  const OnboardingTour._();

  static const _key = 'mensaena_onboarding_v2_done';
  static const _storage = FlutterSecureStorage();

  /// Zeigt die Tour, falls noch nicht gesehen.
  static Future<void> maybeShow(BuildContext context) async {
    try {
      final done = await _storage.read(key: _key);
      if (done == '1') return;
    } catch (_) {}
    if (!context.mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierLabel: 'OnboardingTour',
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => const _OnboardingTourSheet(),
      transitionBuilder: (_, anim, __, child) => FadeTransition(
        opacity: anim,
        child: child,
      ),
    );
    try {
      await _storage.write(key: _key, value: '1');
    } catch (_) {}
  }

  /// Manuell erneut anzeigen (z. B. aus Settings).
  static Future<void> replay(BuildContext context) async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
    if (!context.mounted) return;
    return maybeShow(context);
  }
}

/// Statisches Step-Modell.
class _TourStep {
  const _TourStep({
    required this.icon,
    required this.titleKey,
    required this.bodyKey,
    required this.tint,
    required this.spotlight,
  });
  final IconData icon;
  final String titleKey;
  final String bodyKey;
  final Color tint;

  /// Position des Spotlight-Lochs (Alignment im Screen-Koordinatensystem).
  final Alignment spotlight;
}

class _OnboardingTourSheet extends StatefulWidget {
  const _OnboardingTourSheet();

  @override
  State<_OnboardingTourSheet> createState() => _OnboardingTourSheetState();
}

class _OnboardingTourSheetState extends State<_OnboardingTourSheet>
    with SingleTickerProviderStateMixin {
  int _step = 0;

  static const List<_TourStep> _steps = [
    _TourStep(
      icon: LucideIcons.map,
      titleKey: 'onboarding.tour.step0.title',
      bodyKey: 'onboarding.tour.step0.body',
      tint: AppColors.teal,
      spotlight: Alignment.center,
    ),
    _TourStep(
      icon: LucideIcons.plusCircle,
      titleKey: 'onboarding.tour.step1.title',
      bodyKey: 'onboarding.tour.step1.body',
      tint: AppColors.bronze,
      spotlight: Alignment(0.0, 0.85),
    ),
    _TourStep(
      icon: LucideIcons.messageCircle,
      titleKey: 'onboarding.tour.step2.title',
      bodyKey: 'onboarding.tour.step2.body',
      tint: AppColors.leben,
      spotlight: Alignment(0.55, 0.85),
    ),
    _TourStep(
      icon: LucideIcons.userCircle,
      titleKey: 'onboarding.tour.step3.title',
      bodyKey: 'onboarding.tour.step3.body',
      tint: AppColors.tealSoft,
      spotlight: Alignment(0.85, 0.85),
    ),
    _TourStep(
      icon: LucideIcons.users,
      titleKey: 'onboarding.tour.step4.title',
      bodyKey: 'onboarding.tour.step4.body',
      tint: AppColors.amber,
      spotlight: Alignment(-0.6, -0.5),
    ),
    _TourStep(
      icon: LucideIcons.shieldAlert,
      titleKey: 'onboarding.tour.step5.title',
      bodyKey: 'onboarding.tour.step5.body',
      tint: AppColors.herzrot,
      spotlight: Alignment(0.9, -0.9),
    ),
  ];

  void _next() {
    if (_step >= _steps.length - 1) {
      _complete();
      return;
    }
    setState(() => _step++);
  }

  void _skip() => _complete();

  Future<void> _complete() async {
    try {
      await const FlutterSecureStorage()
          .write(key: OnboardingTour._key, value: '1');
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = _steps[_step];
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Spotlight-Overlay (dunkler Hintergrund mit Loch).
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 380),
              child: CustomPaint(
                key: ValueKey('spot-$_step'),
                painter: _SpotlightPainter(
                  alignment: s.spotlight,
                  holeRadius: 92,
                  haloColor: s.tint,
                ),
                size: Size.infinite,
              ),
            ),
          ),

          // LensFlare auf dem hervorgehobenen Element.
          Positioned.fill(
            child: LensFlare(
              key: ValueKey('flare-$_step'),
              spec: LensFlareSpec(
                alignment: s.spotlight,
                color: s.tint,
                intensity: 0.8,
              ),
              intensity: 0.8,
            ),
          ),

          // Frosted-Glass Tooltip-Box.
          SafeArea(
            child: Align(
              alignment: _tooltipAlignment(s.spotlight),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: GlassCard.strong(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                    borderColor: s.tint.withValues(alpha: 0.5),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: s.tint.withValues(alpha: 0.18),
                                border: Border.all(
                                    color: s.tint.withValues(alpha: 0.55)),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: s.tint.withValues(alpha: 0.35),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: Icon(s.icon, size: 18, color: s.tint),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                s.titleKey.tr(),
                                style: AppTypography.display(
                                  size: 18,
                                  color: AppColors.ink,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          s.bodyKey.tr(),
                          style: AppTypography.body(
                            size: 13,
                            color: AppColors.inkSoft,
                            height: 1.45,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            // Bronze-Dots
                            Expanded(
                              child: Row(
                                children: List.generate(
                                  _steps.length,
                                  (i) => Padding(
                                    padding:
                                        const EdgeInsets.only(right: 6),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                          milliseconds: 240),
                                      width: i == _step ? 18 : 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: i == _step
                                            ? AppColors.bronze
                                            : AppColors.bronzeSoft
                                                .withValues(alpha: 0.4),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _skip,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.mute,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10),
                              ),
                              child: Text('onboarding.skip'.tr(),
                                  style: AppTypography.label(
                                      size: 11, color: AppColors.mute)),
                            ),
                            const SizedBox(width: 6),
                            FilledButton.icon(
                              onPressed: _next,
                              style: FilledButton.styleFrom(
                                backgroundColor: s.tint,
                                foregroundColor: AppColors.voidColor,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                              ),
                              icon: Icon(
                                _step == _steps.length - 1
                                    ? LucideIcons.checkCircle
                                    : LucideIcons.arrowRight,
                                size: 14,
                              ),
                              label: Text(
                                _step == _steps.length - 1
                                    ? 'onboarding.start'.tr()
                                    : 'onboarding.next'.tr(),
                                style: AppTypography.label(
                                  size: 12,
                                  color: AppColors.voidColor,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tooltip soll moeglichst gegenueber dem Spotlight liegen, damit beides
  /// gleichzeitig sichtbar bleibt.
  Alignment _tooltipAlignment(Alignment spot) {
    // Wenn Spotlight unten → Tooltip oben, sonst unten.
    if (spot.y >= 0.5) return Alignment.topCenter;
    if (spot.y <= -0.5) return Alignment.bottomCenter;
    return Alignment.bottomCenter;
  }
}

/// CustomPainter: zeichnet einen dunklen Schleier mit einem runden Loch
/// um die Spotlight-Position. Zusaetzlich ein weicher tint-farbiger Halo
/// am Rand des Loches.
class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({
    required this.alignment,
    required this.holeRadius,
    required this.haloColor,
  });

  final Alignment alignment;
  final double holeRadius;
  final Color haloColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * (alignment.x + 1) / 2;
    final cy = size.height * (alignment.y + 1) / 2;
    final center = Offset(cx, cy);

    // 1) Dunkler Schleier mit Loch (BlendMode.dstOut).
    canvas.saveLayer(Offset.zero & size, Paint());
    final scrim = Paint()
      ..color = AppColors.voidColor.withValues(alpha: 0.78);
    canvas.drawRect(Offset.zero & size, scrim);

    final holePaint = Paint()..blendMode = BlendMode.dstOut;
    holePaint.shader = const RadialGradient(
      colors: [
        Colors.black,
        Colors.black,
        Colors.transparent,
      ],
      stops: [0.0, 0.65, 1.0],
    ).createShader(
      Rect.fromCircle(center: center, radius: holeRadius * 1.4),
    );
    canvas.drawCircle(center, holeRadius * 1.4, holePaint);
    canvas.restore();

    // 2) Halo-Ring (tint-farbig) am Rand des Loches.
    final haloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = haloColor.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center, holeRadius * 1.05, haloPaint);
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.alignment != alignment ||
      old.holeRadius != holeRadius ||
      old.haloColor != haloColor;
}
