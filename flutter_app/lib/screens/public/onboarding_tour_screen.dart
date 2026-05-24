/// SKILL: mensaena-design + mensaena-features
/// Cinematic Onboarding-Tour — 5 fullscreen Cards die jedes Bottom-Nav-Item
/// vorstellen. PageView mit dramatischen Phase-Transitions + Bloom auf den
/// Icons. Wird nur beim allerersten Launch nach Auth gezeigt.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/haptics.dart';
import '../../widgets/effects/bloom.dart';
import '../../widgets/navigation/language_picker.dart';

const _onboardingShownKey = 'onboarding_tour_v1_shown';
const _storage = FlutterSecureStorage();

class OnboardingTourScreen extends ConsumerStatefulWidget {
  const OnboardingTourScreen({super.key});

  @override
  ConsumerState<OnboardingTourScreen> createState() =>
      _OnboardingTourScreenState();

  static Future<bool> shouldShow() async {
    try {
      final raw = await _storage.read(key: _onboardingShownKey);
      return raw != 'true';
    } catch (_) {
      return true;
    }
  }

  static Future<void> markShown() async {
    try {
      await _storage.write(key: _onboardingShownKey, value: 'true');
    } catch (_) {}
  }
}

class _OnboardingTourScreenState
    extends ConsumerState<OnboardingTourScreen> {
  final _page = PageController();
  int _index = 0;

  static const _steps = <_TourStep>[
    _TourStep(
      icon: LucideIcons.layoutDashboard,
      titleKey: 'onboarding.steps.dashboard.title',
      subtitleKey: 'onboarding.steps.dashboard.subtitle',
      bodyKey: 'onboarding.steps.dashboard.body',
      color: AppColors.amber,
    ),
    _TourStep(
      icon: LucideIcons.map,
      titleKey: 'onboarding.steps.map.title',
      subtitleKey: 'onboarding.steps.map.subtitle',
      bodyKey: 'onboarding.steps.map.body',
      color: AppColors.teal,
    ),
    _TourStep(
      icon: LucideIcons.plusCircle,
      titleKey: 'onboarding.steps.create.title',
      subtitleKey: 'onboarding.steps.create.subtitle',
      bodyKey: 'onboarding.steps.create.body',
      color: AppColors.bronze,
    ),
    _TourStep(
      icon: LucideIcons.messageCircle,
      titleKey: 'onboarding.steps.chat.title',
      subtitleKey: 'onboarding.steps.chat.subtitle',
      bodyKey: 'onboarding.steps.chat.body',
      color: AppColors.lebenSoft,
    ),
    _TourStep(
      icon: LucideIcons.bell,
      titleKey: 'onboarding.steps.notifications.title',
      subtitleKey: 'onboarding.steps.notifications.subtitle',
      bodyKey: 'onboarding.steps.notifications.body',
      color: AppColors.herzrotWarm,
    ),
    _TourStep(
      icon: LucideIcons.languages,
      titleKey: 'onboarding.steps.language.title',
      subtitleKey: 'onboarding.steps.language.subtitle',
      bodyKey: 'onboarding.steps.language.body',
      color: AppColors.tealSoft,
    ),
  ];

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    HapticFeedback.mediumImpact();
    await OnboardingTourScreen.markShown();
    if (!mounted) return;
    context.go('/dashboard');
  }

  void _next() {
    Haptics.select();
    if (_index < _steps.length - 1) {
      _page.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.voidColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Cinematic Hintergrund — radial-gradient pro Step
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 700),
              child: Container(
                key: ValueKey('bg_$_index'),
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.0, -0.4),
                    radius: 1.3,
                    colors: [
                      _steps[_index].color.withValues(alpha: 0.18),
                      AppColors.voidColor,
                      AppColors.voidColor,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),
            // PageView
            PageView.builder(
              controller: _page,
              onPageChanged: (i) {
                Haptics.tap();
                setState(() => _index = i);
              },
              itemCount: _steps.length,
              itemBuilder: (_, i) => _TourCard(step: _steps[i]),
            ),
            // Top-Right Skip
            const Positioned(
              top: 12,
              left: 12,
              child: LanguagePicker(),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: TextButton(
                onPressed: _finish,
                child: Text('onboarding.skip'.tr(),
                    style: AppTypography.label(
                        size: 11, color: AppColors.mute)),
              ),
            ),
            // Bottom: Dots + Next-Button
            Positioned(
              bottom: 32,
              left: 24,
              right: 24,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _steps.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _index ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: i == _index
                              ? _steps[_index].color
                              : AppColors.line,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  PulseBloom(
                    color: _steps[_index].color,
                    radius: 30,
                    minIntensity: 0.4,
                    maxIntensity: 0.8,
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _next,
                        style: FilledButton.styleFrom(
                          backgroundColor: _steps[_index].color,
                          foregroundColor: AppColors.voidColor,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _index < _steps.length - 1
                              ? 'onboarding.next'.tr()
                              : 'onboarding.start'.tr(),
                          style: AppTypography.body(
                            size: 15,
                            color: AppColors.voidColor,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TourCard extends StatelessWidget {
  const _TourCard({required this.step});
  final _TourStep step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 80, 28, 160),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          // Icon with bloom-glow
          Center(
            child: PulseBloom(
              color: step.color,
              radius: 60,
              minIntensity: 0.7,
              maxIntensity: 1.0,
              child: Container(
                width: 124,
                height: 124,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      step.color.withValues(alpha: 0.30),
                      step.color.withValues(alpha: 0.08),
                    ],
                  ),
                  border: Border.all(
                      color: step.color.withValues(alpha: 0.5),
                      width: 1.5),
                ),
                child: Icon(step.icon, size: 60, color: step.color),
              ),
            ),
          ),
          const SizedBox(height: 48),
          Text(step.titleKey.tr(),
              textAlign: TextAlign.center,
              style: AppTypography.display(
                size: 32,
                color: AppColors.ink,
                height: 1.15,
              )),
          const SizedBox(height: 8),
          Text(step.subtitleKey.tr(),
              textAlign: TextAlign.center,
              style: AppTypography.body(
                size: 16,
                color: step.color,
                weight: FontWeight.w600,
              )),
          const SizedBox(height: 18),
          Text(step.bodyKey.tr(),
              textAlign: TextAlign.center,
              style: AppTypography.body(
                size: 14,
                color: AppColors.inkSoft,
                height: 1.55,
              )),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _TourStep {
  const _TourStep({
    required this.icon,
    required this.titleKey,
    required this.subtitleKey,
    required this.bodyKey,
    required this.color,
  });

  final IconData icon;
  final String titleKey;
  final String subtitleKey;
  final String bodyKey;
  final Color color;
}
