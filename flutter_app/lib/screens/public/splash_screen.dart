import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/supabase_service.dart';

/// SKILL: mensaena-design
/// Splash-Screen — Logo-Lockup mit Bronze-Glow + Hero-Orb Hintergrund.
/// Wird beim App-Start angezeigt, navigiert nach ~1.6s entweder zum
/// Dashboard (wenn eingeloggt) oder zu /auth.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _navTimer = Timer(const Duration(milliseconds: 1600), _navigate);
  }

  void _navigate() {
    if (!mounted) return;
    final target =
        SupabaseService.isLoggedIn ? '/dashboard' : '/auth';
    context.go(target);
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.voidColor,
      body: Stack(
        children: [
          // Hero-Orb Bronze
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.bronze.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.teal.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Logo-Lockup zentriert
          Center(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                final scale = 0.85 + _ctrl.value * 0.15;
                return Opacity(
                  opacity: math.min(1.0, _ctrl.value * 2),
                  child: Transform.scale(
                    scale: scale,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.bronze,
                                AppColors.bronzeSoft,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.bronze
                                    .withValues(alpha: 0.45),
                                blurRadius: 30,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            LucideIcons.heart,
                            size: 40,
                            color: AppColors.voidColor,
                          ),
                        ),
                        const SizedBox(height: 18),
                        RichText(
                          text: TextSpan(
                            style: AppTypography.display(
                              size: 32,
                              color: AppColors.ink,
                            ),
                            children: const [
                              TextSpan(text: 'Mensaena'),
                              TextSpan(
                                text: '.',
                                style: TextStyle(
                                  color: AppColors.bronze,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Nachbarschaftshilfe',
                          style: AppTypography.label(
                            size: 10,
                            color: AppColors.mute,
                            letterSpacing: 0.30,
                          ),
                        ),
                        const SizedBox(height: 36),
                        // Loading indicator
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(
                              AppColors.bronze
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
