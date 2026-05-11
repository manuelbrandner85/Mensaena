import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/atmosphere/cinema_scaffold.dart';
import '../../core/painters/lens_flare.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../providers/auth_provider.dart';

/// Cinema-Splash. Choreographie:
///   0.0s void + Shader
///   0.5s Laternen glimmen auf
///   1.5s Logo fadeIn + Glow-Shadow
///   2.0s LensFlare horizontal
///   2.5s Subtitle fadeIn
///   3.0s Fireflies erscheinen
///   4.5s Navigation: /dashboard wenn logged-in, sonst /auth
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoCtrl;
  late final AnimationController _subtitleCtrl;
  bool _showLensFlare = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _logoCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _subtitleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      _logoCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      setState(() => _showLensFlare = true);
    });
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      _subtitleCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 4500), _goNext);
  }

  void _goNext() {
    if (!mounted || _navigated) return;
    _navigated = true;
    final isAuthed = ref.read(isAuthenticatedProvider);
    GoRouter.of(context).go(isAuthed ? '/dashboard' : '/auth');
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _subtitleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _goNext,
      child: CinemaScaffold(
        level: AtmosphereLevel.immersive,
        body: Stack(
          children: [
            if (_showLensFlare)
              const Positioned.fill(
                child: LensFlare(widthFraction: 0.5, yPosition: 0.43),
              ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeTransition(
                    opacity: _logoCtrl,
                    child: Text(
                      'Mensaena',
                      style: MnTypography.display(
                        size: 42,
                        shadows: [
                          Shadow(
                            color: MnColors.amber.withValues(alpha: 0.6),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeTransition(
                    opacity: _subtitleCtrl,
                    child: Text(
                      'Nachbarschaft, neu gedacht.',
                      style: MnTypography.body(
                        size: 14,
                        color: MnColors.inkSoft,
                        weight: FontWeight.w300,
                        letterSpacing: 0.5,
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
