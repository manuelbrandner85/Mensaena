import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../services/supabase_service.dart';
import 'onboarding_tour_screen.dart';

/// SKILL: mensaena-design
/// Cinematic Splash-Screen — Konzept "Aurora" + "Tudum":
/// Tageszeit-abhaengiger Hintergrund-Gradient mit Ken-Burns-Zoom,
/// Logo schwebt ein, Fireflies bewegen sich auf Lissajous-Kurven,
/// Wortmarke erscheint Buchstabe fuer Buchstabe mit goldener Shimmer-
/// Sweep, anamorphotischer Lens-Streak (J.J.-Abrams-Style), Logo-Punch
/// im Höhepunkt ("Tudum"), Letterbox-Bars + Cinematic-Exit-Flash.
/// Gesamtdauer: ~4.4s.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Phasen (alles 0..1, Master-Controller):
  //   0.00-0.18: Letterbox-Bars schliessen + BG einblenden + Ken-Burns Start
  //   0.18-0.50: Logo erscheint (scale + opacity + Halo-Atmen)
  //   0.50-0.78: Wortmarke "Mensaena." Buchstabe fuer Buchstabe
  //   0.78-0.88: HÖHEPUNKT — Logo-Punch + Shimmer-Sweep + Lens-Streak peak
  //   0.88-0.96: Hold (volle Marke sichtbar, leichtes Atmen)
  //   0.96-1.00: Cinematic Cross-Fade (kurzer Weiß-Flash → Schwarz)
  late final AnimationController _ctrl;
  late final AnimationController _fireflyCtrl;
  late final AnimationController _haloCtrl;
  Timer? _navTimer;

  static const _wordmark = 'Mensaena';
  static const _totalDurationMs = 4400;

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
          final bgT = _ease(t / 0.18);
          final logoT = _ease((t - 0.18) / 0.32);
          final wordT = ((t - 0.50) / 0.28).clamp(0.0, 1.0);
          // "Tudum"-Höhepunkt: kurzer Spike-Curve 0..1..0 zwischen 0.78–0.88.
          final climaxT = _bump((t - 0.78) / 0.10);
          // Schockwelle: monotoner 0→1-Verlauf ab Höhepunkt-Start, treibt die
          // expandierenden Energie-Ringe (Radius wächst, Alpha verblasst).
          final ringT = ((t - 0.78) / 0.18).clamp(0.0, 1.0);
          final ringEased = 1.0 - math.pow(1.0 - ringT, 2).toDouble();
          // Shimmer-Sweep über die Wortmarke: einmaliger L→R-Lauf 0.78–0.92.
          final shimmerT = ((t - 0.78) / 0.14).clamp(0.0, 1.0);
          // Cinematic-Exit: kurzer Weiß-Flash (cross-cut) 0.96–0.99,
          // dann finaler Schwarz-Fade 0.97–1.00 zum Dashboard.
          final flashT = _bump((t - 0.96) / 0.03);
          final exitT = ((t - 0.97) / 0.03).clamp(0.0, 1.0);

          // Logo-Scale: Grund-Reveal + Tudum-Punch (kurzer Spike +0.08).
          // Exit ist ein „Zoom-Through": das Logo wächst stark und verblasst,
          // als würde man in die App hineintauchen (statt simplem Fade).
          final logoScale =
              0.80 + logoT * 0.20 + climaxT * 0.08 + exitT * 0.65;
          final logoOpacity =
              logoT.clamp(0.0, 1.0) * (1.0 - exitT);
          // Ken-Burns: BG zoomt 1.00 → 1.06 über den gesamten Verlauf.
          final bgScale = 1.0 + t * 0.06;

          return Stack(
            children: [
              // ── Aurora-Hintergrund-Gradient + Ken-Burns-Zoom ────
              Transform.scale(
                scale: bgScale,
                child: Container(
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

              // ── Volumetric God-Rays (rotierendes Licht hinter Logo) ──
              // Langsam drehende Strahlenkrone via SweepGradient. Beim
              // Höhepunkt schnellerer Spin + hellere Strahlen. GPU-leicht
              // (ein Transform + ein Gradient, kein Shader).
              if (logoT > 0)
                Center(
                  child: IgnorePointer(
                    child: Transform.rotate(
                      angle: _haloCtrl.value * 2 * math.pi * 0.06 +
                          climaxT * 0.35,
                      child: Opacity(
                        opacity:
                            (logoT * 0.40 + climaxT * 0.45).clamp(0.0, 0.9),
                        child: Container(
                          width: size.width * 0.95,
                          height: size.width * 0.95,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              colors: _rayColors(
                                  palette.halo, 0.12 + 0.10 * climaxT),
                              stops: _rayStops,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // ── Schockwellen-Ringe (Energie-Puls beim 'Tudum') ──
              if (ringT > 0 && ringT < 1) ...[
                Center(
                  child: IgnorePointer(
                    child: Container(
                      width: 80 + ringEased * 320,
                      height: 80 + ringEased * 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: palette.halo
                              .withValues(alpha: 0.55 * (1 - ringT)),
                          width: 2.5 * (1 - ringT) + 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
                // zweiter, nachlaufender Ring für mehr Tiefe
                Center(
                  child: IgnorePointer(
                    child: Container(
                      width: 80 + ringEased * 210,
                      height: 80 + ringEased * 210,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: palette.accent
                              .withValues(alpha: 0.40 * (1 - ringT)),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],

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
                              // Logo — fliegt mit 3D-Perspektive ein
                              // (Tilt-Settle), dann ruhig zentriert.
                              Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, 0.0012)
                                  ..rotateX((1 - logoT) * 0.6),
                                child: Container(
                                  width: 96,
                                  height: 96,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.voidColor
                                        .withValues(alpha: 0.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: palette.halo.withValues(
                                            alpha: 0.5 + 0.3 * climaxT),
                                        blurRadius: 36 + 24 * climaxT,
                                        spreadRadius: 4 + 6 * climaxT,
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
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Wortmarke — Letter-by-Letter Reveal +
                        // goldener Shimmer-Sweep (L→R) im Höhepunkt.
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8),
                          child: _WordmarkWithShimmer(
                            progress: wordT,
                            word: _wordmark,
                            dotColor: palette.halo,
                            shimmer: shimmerT,
                            shimmerColor: palette.halo,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Tagline
                        Opacity(
                          opacity: wordT,
                          child: Text(
                            'splash.tagline'.tr(),
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

              // ── Anamorphotischer Lens-Streak (J.J.-Abrams-Style) ──
              // Heller, breiterer Strahl quer durch die Mitte. Pulsiert
              // beim Reveal und peakt beim 'Tudum'-Höhepunkt (climaxT).
              if (logoT > 0.4)
                Positioned(
                  top: size.height * 0.46,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 4 + 14 * climaxT,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            palette.accent.withValues(
                                alpha: 0.10 +
                                    0.35 * (logoT - 0.4).clamp(0.0, 1.0) +
                                    0.45 * climaxT),
                            Colors.white.withValues(
                                alpha: 0.20 + 0.55 * climaxT),
                            palette.accent.withValues(
                                alpha: 0.10 +
                                    0.35 * (logoT - 0.4).clamp(0.0, 1.0) +
                                    0.45 * climaxT),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: palette.accent
                                .withValues(alpha: 0.4 * climaxT),
                            blurRadius: 30 + 30 * climaxT,
                          ),
                        ],
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

              // ── Cinematic-Cut: kurzer Weiß-Flash → Schwarz-Fade ──
              // Klassischer Film-Cut-Look: 80ms harter Weiß-Blitz, dann
              // sanft auf Schwarz. Wirkt wie ein Kamera-Schnitt.
              if (flashT > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color:
                          Colors.white.withValues(alpha: flashT * 0.85),
                    ),
                  ),
                ),
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

  // 0..1..0 Hump-Curve (sin) — für one-shot Spike-Animationen wie der
  // 'Tudum'-Logo-Punch und der Cinematic-Exit-Flash.
  double _bump(double t) {
    final c = t.clamp(0.0, 1.0);
    return math.sin(c * math.pi);
  }

  // ── God-Ray-Gradient ───────────────────────────────────────
  // 12 Strahlen über 360°: pro Segment transparent → Farbe → transparent.
  // 36 gleichmäßige Stops ergeben 12 helle „Speichen".
  static final List<double> _rayStops = [
    for (var i = 0; i <= 36; i++) i / 36,
  ];

  List<Color> _rayColors(Color c, double alpha) {
    final on = c.withValues(alpha: alpha);
    const off = Colors.transparent;
    final out = <Color>[];
    for (var i = 0; i < 12; i++) {
      out
        ..add(off)
        ..add(on)
        ..add(off);
    }
    out.add(off);
    return out;
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
// Wortmarke + goldener Shimmer-Sweep (Netflix-Style Highlight-Pass)
// ─────────────────────────────────────────────────────────────────────
class _WordmarkWithShimmer extends StatelessWidget {
  const _WordmarkWithShimmer({
    required this.progress,
    required this.word,
    required this.dotColor,
    required this.shimmer,
    required this.shimmerColor,
  });

  final double progress; // 0..1 — Letter-Reveal
  final String word;
  final Color dotColor;
  final double shimmer; // 0..1 — L→R Sweep
  final Color shimmerColor;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        alignment: Alignment.center,
        children: [
          _WordmarkReveal(
            progress: progress,
            word: word,
            dotColor: dotColor,
          ),
          if (shimmer > 0 && shimmer < 1)
            // Schmaler heller Streifen wandert über die Wortmarke. Width
            // wird per FractionallySizedBox auf 22 % beschränkt, Position
            // über Alignment-x (-1.4 → +1.4) interpoliert.
            Positioned.fill(
              child: IgnorePointer(
                child: Align(
                  alignment: Alignment(-1.4 + shimmer * 2.8, 0),
                  child: FractionallySizedBox(
                    widthFactor: 0.22,
                    heightFactor: 1.0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            shimmerColor.withValues(alpha: 0.55),
                            Colors.white.withValues(alpha: 0.75),
                            shimmerColor.withValues(alpha: 0.55),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                        ),
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
    // Spring-Overshoot: jeder Buchstabe „poppt" beim Erscheinen kurz auf
    // (+18 % in der Mitte des Reveals) und setzt sich dann auf 1.0.
    final pop = 1.0 + 0.18 * math.sin(visibility.clamp(0.0, 1.0) * math.pi);
    return Opacity(
      opacity: visibility,
      child: Transform.translate(
        offset: Offset(0, 8 * (1 - visibility)),
        child: Transform.scale(
          scale: pop,
          child: Text(
            letter,
            style: AppTypography.display(
              size: 36,
              color: color ?? AppColors.ink,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}
