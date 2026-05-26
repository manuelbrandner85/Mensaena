import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/supabase_service.dart';
import 'onboarding_tour_screen.dart';

/// SKILL: mensaena-design
/// Cinematic Splash-Screen — Konzept "Aurora":
/// Tageszeit-abhaengiger Hintergrund-Gradient, Logo schwebt ein,
/// Fireflies bewegen sich auf Lissajous-Kurven, Wortmarke erscheint
/// Buchstabe fuer Buchstabe, Lens-Flare + Bronze-Halo, Letterbox-Bars
/// animieren rein und raus. Gesamtdauer: ~2.6s.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // 5 Phasen:
  //   0.00-0.25: Letterbox-Bars schliessen + Hintergrund einblenden
  //   0.25-0.55: Logo erscheint (scale + opacity)
  //   0.55-0.85: Wortmarke "Mensaena." Buchstabe fuer Buchstabe
  //   0.85-0.95: Hold (Atmen)
  //   0.95-1.00: Slow zoom-out + fade to dashboard
  late final AnimationController _ctrl;
  late final AnimationController _fireflyCtrl;
  late final AnimationController _haloCtrl;
  Timer? _navTimer;

  static const _wordmark = 'Mensaena';
  static const _totalDurationMs = 2600;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _totalDurationMs),
    )..forward();
    _fireflyCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
    _haloCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _navTimer = Timer(
      const Duration(milliseconds: _totalDurationMs + 200),
      _navigate,
    );
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    if (!SupabaseService.isLoggedIn) {
      context.go('/auth');
      return;
    }
    // Erstlogin → Onboarding-Tour zeigen.
    final shouldOnboard = await OnboardingTourScreen.shouldShow();
    if (!mounted) return;
    context.go(shouldOnboard ? '/onboarding' : '/dashboard');
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _ctrl.dispose();
    _fireflyCtrl.dispose();
    _haloCtrl.dispose();
    super.dispose();
  }

  // ── Time-of-Day Aurora-Palette ───────────────────────────────
  _Palette _paletteForHour(int h) {
    if (h < 6) {
      // Nacht — tiefblau mit Bronze-Akzent
      return const _Palette(
        bg1: Color(0xFF0A0F1C),
        bg2: Color(0xFF1A2347),
        accent: Color(0xFF7DD3FC),
        halo: AppColors.bronze,
      );
    }
    if (h < 11) {
      // Morgen — Aurora-Pink + warmes Gold
      return const _Palette(
        bg1: Color(0xFF0F1628),
        bg2: Color(0xFF4A2940),
        accent: Color(0xFFFBBF24),
        halo: Color(0xFFFBBF24),
      );
    }
    if (h < 17) {
      // Tag — Cinema-Bronze + Teal
      return const _Palette(
        bg1: Color(0xFF0A0F1C),
        bg2: Color(0xFF1C2A42),
        accent: AppColors.tealSoft,
        halo: AppColors.bronze,
      );
    }
    if (h < 21) {
      // Abend — warmes Bronze + Rotorange
      return const _Palette(
        bg1: Color(0xFF0F1628),
        bg2: Color(0xFF5C2818),
        accent: Color(0xFFFB923C),
        halo: AppColors.bronze,
      );
    }
    // Spaeter Abend — gedaempftes Blau-Lila
    return const _Palette(
      bg1: Color(0xFF0A0F1C),
      bg2: Color(0xFF2D1B4E),
      accent: Color(0xFF818CF8),
      halo: AppColors.bronze,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final palette = _paletteForHour(DateTime.now().hour);

    return Scaffold(
      backgroundColor: AppColors.voidColor,
      body: AnimatedBuilder(
        animation: Listenable.merge([_ctrl, _fireflyCtrl, _haloCtrl]),
        builder: (_, __) {
          final t = _ctrl.value;
          // Phase Easing
          final bgT = _ease(t / 0.25);
          final logoT = _ease((t - 0.20) / 0.35);
          final wordT = ((t - 0.55) / 0.30).clamp(0.0, 1.0);
          final exitT = ((t - 0.92) / 0.08).clamp(0.0, 1.0);

          final logoScale = 0.80 + logoT * 0.20 - exitT * 0.04;
          final logoOpacity =
              logoT.clamp(0.0, 1.0) * (1.0 - exitT * 0.30);

          return Stack(
            children: [
              // ── Aurora-Hintergrund-Gradient ─────────────────────
              Container(
                width: size.width,
                height: size.height,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.0, -0.3),
                    radius: 1.2,
                    colors: [
                      Color.lerp(
                          AppColors.voidColor, palette.bg2, bgT * 0.85)!,
                      Color.lerp(
                          AppColors.voidColor, palette.bg1, bgT)!,
                    ],
                  ),
                ),
              ),
              // ── Atmospheric Aurora-Glow (animated breathing) ────
              Positioned(
                top: -size.width * 0.3,
                left: -size.width * 0.25,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 600),
                  opacity: bgT * 0.5,
                  child: Container(
                    width: size.width * 1.2,
                    height: size.width * 1.2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          palette.accent.withValues(alpha: 0.30),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -size.width * 0.35,
                right: -size.width * 0.3,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 600),
                  opacity: bgT * 0.4,
                  child: Container(
                    width: size.width * 1.1,
                    height: size.width * 1.1,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          palette.halo.withValues(alpha: 0.25),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Fireflies (12 Punkte auf Lissajous-Kurven) ──────
              ..._buildFireflies(size, palette, bgT),

              // ── Logo + Halo + Wortmarke (zentriert) ────────────
              Center(
                child: Transform.scale(
                  scale: logoScale,
                  child: Opacity(
                    opacity: logoOpacity,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Halo hinter Logo (atmender Glow)
                        SizedBox(
                          width: 180,
                          height: 180,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Innerer Halo
                              Container(
                                width: 180,
                                height: 180,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      palette.halo.withValues(
                                          alpha: 0.35 +
                                              0.15 *
                                                  math.sin(_haloCtrl
                                                          .value *
                                                      2 *
                                                      math.pi)),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                              // Mittlerer Glow-Ring (pulsiert)
                              Container(
                                width: 110 +
                                    8 *
                                        math.sin(_haloCtrl.value *
                                            2 *
                                            math.pi),
                                height: 110 +
                                    8 *
                                        math.sin(_haloCtrl.value *
                                            2 *
                                            math.pi),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: palette.halo.withValues(
                                        alpha: 0.30),
                                    width: 1,
                                  ),
                                ),
                              ),
                              // Logo
                              Container(
                                width: 96,
                                height: 96,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.voidColor
                                      .withValues(alpha: 0.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: palette.halo.withValues(
                                          alpha: 0.5),
                                      blurRadius: 36,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/images/mensaena-logo.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Wortmarke — Letter-by-Letter Reveal
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8),
                          child: _WordmarkReveal(
                            progress: wordT,
                            word: _wordmark,
                            dotColor: palette.halo,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Tagline
                        Opacity(
                          opacity: wordT,
                          child: Text(
                            'Nachbarschaftshilfe',
                            style: AppTypography.label(
                              size: 10,
                              color: AppColors.mute,
                              letterSpacing: 0.40,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Lens-Flare (subtler horizontaler Strahl) ────────
              if (logoT > 0.5)
                Positioned(
                  top: size.height * 0.42,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            palette.halo.withValues(
                                alpha: 0.5 * (logoT - 0.5) * 2),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Vignette (Eckabschattung) ───────────────────────
              IgnorePointer(
                child: Container(
                  width: size.width,
                  height: size.height,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.0,
                      colors: [
                        Colors.transparent,
                        AppColors.voidColor.withValues(
                            alpha: 0.40 + exitT * 0.30),
                      ],
                      stops: const [0.55, 1.0],
                    ),
                  ),
                ),
              ),

              // ── Letterbox Cinema-Bars ───────────────────────────
              _letterboxBar(
                  size: size, alignment: Alignment.topCenter, t: bgT),
              _letterboxBar(
                  size: size,
                  alignment: Alignment.bottomCenter,
                  t: bgT),

              // ── Exit-Fade (zum dashboard) ───────────────────────
              if (exitT > 0)
                Positioned.fill(
                  child: Container(
                    color: AppColors.voidColor
                        .withValues(alpha: exitT),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _letterboxBar({
    required Size size,
    required AlignmentGeometry alignment,
    required double t,
  }) {
    final h = 36.0 * t;
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          width: size.width,
          height: h,
          color: AppColors.voidColor,
        ),
      ),
    );
  }

  List<Widget> _buildFireflies(Size size, _Palette p, double appear) {
    final fireflies = <Widget>[];
    for (var i = 0; i < 14; i++) {
      final ax = 0.10 + (i % 5) * 0.16;
      final ay = 0.15 + (i % 4) * 0.18;
      final fx = 1.0 + (i % 3) * 0.5;
      final fy = 1.4 + ((i + 1) % 3) * 0.4;
      final phase = i * 0.45;
      final t = _fireflyCtrl.value * 2 * math.pi;
      final x = (ax + 0.05 * math.sin(t * fx + phase)) * size.width;
      final y =
          (ay + 0.05 * math.cos(t * fy + phase * 1.3)) * size.height;
      final s = 2.5 + (i % 4) * 0.8;
      final twinkle =
          0.45 + 0.40 * math.sin(t * (1.2 + i * 0.1) + i.toDouble());
      fireflies.add(Positioned(
        top: y,
        left: x,
        child: IgnorePointer(
          child: Container(
            width: s,
            height: s,
            decoration: BoxDecoration(
              color: p.halo.withValues(alpha: twinkle * appear),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: p.halo.withValues(alpha: 0.4 * twinkle * appear),
                  blurRadius: s * 2.4,
                ),
              ],
            ),
          ),
        ),
      ));
    }
    return fireflies;
  }

  // Cubic ease-out
  double _ease(double t) {
    final c = t.clamp(0.0, 1.0);
    return 1.0 - math.pow(1.0 - c, 3).toDouble();
  }
}

class _Palette {
  const _Palette({
    required this.bg1,
    required this.bg2,
    required this.accent,
    required this.halo,
  });

  final Color bg1;
  final Color bg2;
  final Color accent;
  final Color halo;
}

// ─────────────────────────────────────────────────────────────────────
// Wortmarke — Buchstabe fuer Buchstabe Reveal
// ─────────────────────────────────────────────────────────────────────
class _WordmarkReveal extends StatelessWidget {
  const _WordmarkReveal({
    required this.progress,
    required this.word,
    required this.dotColor,
  });

  final double progress; // 0..1
  final String word;
  final Color dotColor;

  @override
  Widget build(BuildContext context) {
    final letters = word.split('');
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        for (var i = 0; i < letters.length; i++)
          _Letter(
            letter: letters[i],
            visibility:
                ((progress * (letters.length + 1)) - i).clamp(0.0, 1.0),
          ),
        // Bronze Punkt
        _Letter(
          letter: '.',
          visibility:
              ((progress * (letters.length + 1)) - letters.length)
                  .clamp(0.0, 1.0),
          color: dotColor,
        ),
      ],
    );
  }
}

class _Letter extends StatelessWidget {
  const _Letter({
    required this.letter,
    required this.visibility,
    this.color,
  });

  final String letter;
  final double visibility;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: visibility,
      child: Transform.translate(
        offset: Offset(0, 6 * (1 - visibility)),
        child: Text(
          letter,
          style: AppTypography.display(
            size: 36,
            color: color ?? AppColors.ink,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
